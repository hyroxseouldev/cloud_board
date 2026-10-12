// Test doubles exercise Firestore query bounds without network.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_board/src/app/feature/workouts/data/datasources/library_folder_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/library_folder_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/library_folder_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/library_folder_controller.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'late cache cannot hide an earlier compatibility lookup failure',
    () async {
      final source = _Source()..cacheGate = Completer<List<String>>();
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              const AuthUser(
                id: 'owner',
                email: '',
                displayName: '',
                photoUrl: null,
              ),
            ),
          ),
          libraryFolderActionsProvider.overrideWith(
            (ref) => LibraryFolderActions(LibraryFolderRepository(source)),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(libraryFoldersProvider, (_, _) {});
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      expect(source.requests, 1);
      source.result.completeError(StateError('offline'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(libraryFoldersProvider).hasError, isTrue);
      source.cacheGate!.complete(['cached']);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(libraryFoldersProvider).hasError, isTrue);
      expect(container.read(libraryFoldersProvider).value, ['cached']);
      source.explicit.add(['explicit']);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(libraryFoldersProvider).hasError, isTrue);
      expect(container.read(libraryFoldersProvider).value, [
        'cached',
        'explicit',
      ]);
      await source.explicit.close();
    },
  );

  test(
    'folder error remains visible with cached names and retry can recover',
    () async {
      final source = _Source()..cached = ['cached'];
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              const AuthUser(
                id: 'owner',
                email: '',
                displayName: '',
                photoUrl: null,
              ),
            ),
          ),
          libraryFolderActionsProvider.overrideWith(
            (ref) => LibraryFolderActions(LibraryFolderRepository(source)),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(libraryFoldersProvider, (_, _) {});
      expect(await container.read(libraryFoldersProvider.future), ['cached']);
      source.result.completeError(StateError('offline'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(libraryFoldersProvider).hasError, isTrue);
      expect(container.read(libraryFoldersProvider).value, ['cached']);
      source.result = Completer<List<String>>()..complete(['server']);
      container.invalidate(libraryFoldersProvider);
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(libraryFoldersProvider).hasError, isFalse);
      expect(container.read(libraryFoldersProvider).value, ['server']);
      await source.explicit.close();
    },
  );

  test(
    'initial empty metadata does not claim complete folder discovery',
    () async {
      final source = _Source();
      final events = <List<String>>[];
      final subscription = source.watch('owner').listen(events.add);
      await Future<void>.delayed(Duration.zero);
      source.explicit.add([]);
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
      source.result.complete([]);
      await Future<void>.delayed(Duration.zero);
      expect(events, [[]]);
      await subscription.cancel();
      await source.explicit.close();
    },
  );

  test(
    'valid cached summary folders survive a failed legacy cache query',
    () async {
      final firestore = _CachedFirestore()..failDetails = true;
      final source = LibraryFolderDataSource(firestore, _Functions());
      expect(await source.loadCachedFolders('owner'), ['summary-only']);
    },
  );

  test('upgraded offline cache reads one detail per distinct folder', () async {
    final firestore = _CachedFirestore();
    final source = LibraryFolderDataSource(firestore, _Functions());
    expect(await source.loadCachedFolders('owner'), ['A', 'B', 'summary-only']);
    expect(firestore.detailDocumentsRead, 2);
    expect(firestore.detailQueries, 3);
    expect(firestore.summaryQueries, 1);
  });

  test(
    'closing during offline fallback stops subsequent cached queries',
    () async {
      final firestore = _CachedFirestore();
      var active = true;
      firestore.afterDetail = () => active = false;
      final source = LibraryFolderDataSource(firestore, _Functions());
      await source.loadCachedFolders('owner', isActive: () => active);
      expect(firestore.detailQueries, 1);
    },
  );

  test('cached/current folders emit before legacy discovery and offline cache survives', () async {
    final source = _Source()..cached = ['기존 폴더'];
    final events = <List<String>>[];
    final errors = <Object>[];
    final subscription = source
        .watch('owner')
        .listen(events.add, onError: errors.add);
    await Future<void>.delayed(Duration.zero);
    source.explicit.add(['빈 폴더']);
    await Future<void>.delayed(Duration.zero);
    expect(events.last, ['기존 폴더', '빈 폴더']);
    expect(source.requests, 1);
    source.result.completeError(StateError('offline'));
    await Future<void>.delayed(Duration.zero);
    expect(events.last, ['기존 폴더', '빈 폴더']);
    expect(errors.single, isStateError);
    await subscription.cancel();
    await source.explicit.close();
  });

  test(
    'legacy names merge without detail decoding and cache is account-scoped',
    () async {
      final source = _Source();
      final events = <List<String>>[];
      final subscription = source.watch('owner').listen(events.add);
      await Future<void>.delayed(Duration.zero);
      source.explicit.add(['현재 폴더']);
      source.result.complete(['오래된 폴더']);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(events.last, ['오래된 폴더', '현재 폴더']);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getStringList('library.folderCatalog.owner'), [
        '오래된 폴더',
      ]);
      expect(preferences.getStringList('library.folderCatalog.other'), isNull);
      await subscription.cancel();
      await source.explicit.close();
    },
  );

  test(
    'closing before cache resolves prevents network requests and late results',
    () async {
      final source = _Source()..cacheGate = Completer<List<String>>();
      final subscription = source
          .watch('owner')
          .listen((_) => fail('closed stream emitted'));
      await subscription.cancel();
      source.cacheGate!.complete(['cached']);
      await Future<void>.delayed(Duration.zero);
      expect(source.requests, 0);
      await source.explicit.close();
    },
  );

  test('closing during discovery ignores result and does not start subsequent work', () async {
    final source = _Source();
    final events = <List<String>>[];
    final subscription = source.watch('owner').listen(events.add);
    await Future<void>.delayed(Duration.zero);
    expect(source.requests, 1);
    await subscription.cancel();
    source.result.complete(['late']);
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getStringList('library.folderCatalog.owner'), isNull);
    await source.explicit.close();
  });
}

class _Source extends LibraryFolderDataSource {
  _Source() : super(_Firestore(), _Functions());
  List<String> cached = [];
  Completer<List<String>>? cacheGate;
  var result = Completer<List<String>>();
  final explicit = StreamController<List<String>>.broadcast();
  int requests = 0;
  @override
  Future<List<String>> loadCachedFolders(
    String owner, {
    bool Function()? isActive,
  }) async => cacheGate == null ? cached : await cacheGate!.future;
  @override
  Future<List<String>> loadLegacyFolders(String owner) {
    requests++;
    return result.future;
  }

  @override
  Stream<List<String>> watchExplicitFolders(String owner) => explicit.stream;
}

class _Firestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Functions implements FirebaseFunctions {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CachedFirestore implements FirebaseFirestore {
  int detailDocumentsRead = 0, detailQueries = 0, summaryQueries = 0;
  void Function()? afterDetail;
  bool failDetails = false;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _CachedCollection(this, path);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CachedQuery implements Query<Map<String, dynamic>> {
  _CachedQuery(this.source, this.path, {this.pageLimit, this.cursor});
  final _CachedFirestore source;
  final String path;
  final int? pageLimit;
  final String? cursor;
  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) {
    expect(field, 'folder');
    return this;
  }

  @override
  Query<Map<String, dynamic>> limit(int value) =>
      _CachedQuery(source, path, pageLimit: value, cursor: cursor);
  @override
  Query<Map<String, dynamic>> startAfter(Iterable<Object?> values) =>
      _CachedQuery(
        source,
        path,
        pageLimit: pageLimit,
        cursor: values.single as String,
      );
  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    expect(options?.source, Source.cache);
    if (path.endsWith('/workoutSummaries')) {
      source.summaryQueries++;
      return _CachedSnapshot([
        _CachedDocument({'folder': 'summary-only'}),
      ]);
    }
    if (source.failDetails) {
      throw FirebaseException(plugin: 'firestore', code: 'unavailable');
    }
    expect(path, 'users/owner/workouts');
    expect(pageLimit, 1);
    source.detailQueries++;
    final names = [...List.filled(499, 'A'), 'B']
        .where((name) => cursor == null || name.compareTo(cursor!) > 0)
        .take(pageLimit!);
    final docs = names
        .map((name) => _CachedDocument({'folder': name}))
        .toList();
    source.detailDocumentsRead += docs.length;
    source.afterDetail?.call();
    return _CachedSnapshot(docs);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CachedCollection extends _CachedQuery
    implements CollectionReference<Map<String, dynamic>> {
  _CachedCollection(super.source, super.path);
}

class _CachedSnapshot implements QuerySnapshot<Map<String, dynamic>> {
  _CachedSnapshot(this.docs);
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CachedDocument implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _CachedDocument(this.value);
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
