import 'dart:async';

import 'package:cloud_board/src/app/core/utils/async_value_cache.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class LibraryFolderDataSource {
  LibraryFolderDataSource(this.firestore, this.functions);
  final _catalog = AsyncValueCache<String, List<String>>(capacity: 1);
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  /// Live explicit folders plus a small compatibility result for legacy folders.
  /// Closing the last subscriber stops follow-up work; an already dispatched
  /// callable cannot be cancelled, but its response cannot update a closed UI.
  Stream<List<String>> watch(String owner) {
    late final StreamController<List<String>> output;
    StreamSubscription<List<String>>? subscription;
    var cancelled = false;
    var legacy = <String>[];
    var explicit = <String>[];
    var request = 0;
    var serverResolved = false;
    Object? failure;
    StackTrace? failureStack;
    void fail(Object error, StackTrace stack) {
      failure = error;
      failureStack = stack;
      output.addError(error, stack);
    }

    void emit() {
      if (cancelled) return;
      final names = {...legacy, ...explicit}.toList()..sort();
      if (names.isNotEmpty || serverResolved) {
        output.add(names);
        // Cache/metadata can finish after discovery failed. Keep the usable
        // names, but only a successful authoritative lookup clears the error.
        if (failure != null) output.addError(failure!, failureStack);
      }
    }

    Future<void> discover() async {
      final current = ++request;
      try {
        final names = await loadLegacyFolders(owner);
        if (cancelled || current != request) return;
        serverResolved = true;
        failure = null;
        failureStack = null;
        legacy = names;
        emit();
        final preferences = await SharedPreferences.getInstance();
        if (!cancelled && current == request) {
          await preferences.setStringList(_cacheKey(owner), names);
        }
      } catch (error, stack) {
        if (!cancelled && current == request) {
          fail(error, stack);
        }
      }
    }

    output = StreamController<List<String>>(
      onListen: () async {
        try {
          // A synchronously closed screen starts no work at all. Disk cache,
          // explicit metadata and compatibility discovery then run independently.
          await Future<void>.value();
          if (cancelled) return;
          unawaited(() async {
            try {
              final cached = await loadCachedFolders(
                owner,
                isActive: () => !cancelled,
              );
              if (cancelled || serverResolved) return;
              legacy = cached;
              if (legacy.isNotEmpty) emit();
            } catch (_) {
              // Cache failure must not prevent the authoritative lookup.
            }
          }());
          // Subscribe without waiting for the compatibility query. Existing and
          // empty folders stay visible while older folder names are discovered.
          List<String>? previousExplicit;
          subscription = watchExplicitFolders(owner).listen(
            (names) {
              if (cancelled) return;
              final previous = previousExplicit;
              explicit = names;
              previousExplicit = names;
              emit();
              if (previous != null &&
                  previous.join('\u0000') != names.join('\u0000')) {
                _catalog.invalidate(owner);
                unawaited(discover());
              }
            },
            onError: (Object error, StackTrace stack) {
              if (!cancelled) fail(error, stack);
            },
          );
          unawaited(discover());
        } catch (error, stack) {
          if (!cancelled) fail(error, stack);
        }
      },
      onCancel: () async {
        cancelled = true;
        request++;
        await subscription?.cancel();
      },
    );
    return output.stream;
  }

  Stream<List<String>> watchExplicitFolders(String owner) => firestore
      .collection('users/$owner/libraryFolders')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs
                .map((doc) => doc.data()['name'])
                .whereType<String>()
                .toList()
              ..sort(),
      );

  String _cacheKey(String owner) => 'library.folderCatalog.$owner';

  Future<List<String>> loadCachedFolders(
    String owner, {
    bool Function()? isActive,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final names = preferences.getStringList(_cacheKey(owner));
    if (names != null) return names;
    if (isActive?.call() == false) return const [];
    final folders = <String>{};
    try {
      final summaries = await firestore
          .collection('users/$owner/workoutSummaries')
          .get(const GetOptions(source: Source.cache));
      folders.addAll(
        summaries.docs
            .map((doc) => doc.data()['folder'])
            .whereType<String>()
            .where((name) => name.isNotEmpty),
      );
      // Older installs can have detail-only disk caches. Skip over equal folder
      // values so compatibility reads at most one cached document per distinct
      // folder, never all the modules in a large same-folder library. Summary
      // caches can be partial too, so union both cache sources for offline use.
      String? cursor;
      while (isActive?.call() != false) {
        Query<Map<String, dynamic>> query = firestore
            .collection('users/$owner/workouts')
            .orderBy('folder')
            .limit(1);
        if (cursor != null) query = query.startAfter([cursor]);
        final cached = await query.get(const GetOptions(source: Source.cache));
        if (cached.docs.isEmpty) break;
        final name = cached.docs.single.data()['folder'];
        if (name is! String || name == cursor) break;
        cursor = name;
        if (name.isNotEmpty) folders.add(name);
      }
      return folders.toList()..sort();
    } on FirebaseException {
      return folders.toList()..sort();
    }
  }

  Future<List<String>> loadLegacyFolders(String owner) => _catalog.load(
    owner,
    () async {
      final result = await functions
          .httpsCallable(
            'listLibraryFolders',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          )
          .call<Object?>({'owner': owner});
      final data = result.data;
      if (data is! Map || data['folders'] is! List) {
        throw const FormatException('폴더 목록을 불러오지 못했습니다.');
      }
      final names =
          (data['folders'] as List)
              .whereType<String>()
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      return names;
    },
  );

  Future<void> mutate(String action, String name, {String? newName}) async {
    await functions
        .httpsCallable(
          'manageLibraryFolder',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
        )
        .call({'action': action, 'name': name, 'newName': ?newName});
    _catalog.clear();
  }
}
