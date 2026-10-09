import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_design_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/starter_workouts.dart';

import 'dart:async';

import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_firestore_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_storage_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';

import 'package:cloud_board/src/app/core/utils/async_value_cache.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_catalog_page.dart';
part 'workout_repository_impl.g.dart';

class WorkoutRepositoryImpl
    implements WorkoutRepository, PagedWorkoutCatalog, StarterWorkoutImporter {
  WorkoutRepositoryImpl(
    this._auth,
    this._firestore,
    this._storage,
    this._local,
  );

  final FirebaseAuth _auth;
  final WorkoutFirestoreDataSource _firestore;
  final WorkoutStorageDataSource _storage;
  final WorkoutLocalDataSource _local;

  final _details = AsyncValueCache<({String owner, String id}), Workout?>();
  final _versions = <String, DateTime>{};
  String? _cacheOwner;

  String _owner() {
    final uid = _requireUser().uid;
    if (_cacheOwner != uid) {
      _cacheOwner = uid;
      _details.clear();
      _versions.clear();
    }
    return uid;
  }

  void _rememberVersions(
    String uid,
    List<WorkoutSummary> items, {
    bool complete = false,
  }) {
    if (_cacheOwner != uid || _auth.currentUser?.uid != uid) return;
    if (complete) {
      final ids = items.map((item) => item.id).toSet();
      // Include details opened before their first catalog read, and pending
      // reads for records that have since been deleted.
      for (final key in _details.keys) {
        if (key.owner == uid && !ids.contains(key.id)) {
          _details.invalidate(key);
        }
      }
      _versions.removeWhere((id, _) => !ids.contains(id));
    }
    for (final item in items) {
      if (_versions[item.id] != item.updatedAt) {
        _details.invalidate((owner: uid, id: item.id));
        _versions[item.id] = item.updatedAt;
      }
    }
  }

  @override
  Future<Workout?> loadOne(String workoutId) {
    final uid = _owner();
    return _details.load((
      owner: uid,
      id: workoutId,
    ), () async => (await _firestore.loadOne(uid, workoutId))?.toEntity());
  }

  @override
  Stream<List<WorkoutSummary>> watchSummaries({bool requireServer = false}) =>
      watchCatalog(requireServer: requireServer).map((page) => page.items);

  @override
  Stream<WorkoutCatalogPage> watchCatalog({bool requireServer = false}) async* {
    final userId = _owner();
    // Retain full cached details already used by earlier app versions for offline
    // playback. Do not download every detail just to construct this catalog.
    final cached = await _firestore.loadCachedSummaries(userId);
    final visible = {for (final item in cached) item.id: item.toEntity()};
    if (visible.isNotEmpty) {
      yield WorkoutCatalogPage(_sortedSummaries(visible.values), cached: true);
    }
    try {
      if (!await _firestore.hasSummaryCatalog(userId)) {
        var cached = true;
        var complete = false;
        await for (final items in _watch(
          requireServer: requireServer,
          onServerPage: (finished) {
            cached = false;
            complete = finished;
          },
        )) {
          final summaries = items.map(summarizeWorkout).toList();
          if (!cached) {
            _rememberVersions(userId, summaries, complete: complete);
          }
          yield WorkoutCatalogPage(
            summaries,
            cached: cached,
            complete: complete,
          );
        }
        return;
      }
      await for (final page in _firestore.loadSummaryPages(userId)) {
        if (page.complete) {
          final ids = page.items.map((item) => item.id).toSet();
          visible.removeWhere((id, _) => !ids.contains(id));
        }
        for (final item in page.items) {
          visible[item.id] = item.toEntity();
        }
        final summaries = _sortedSummaries(visible.values);
        _rememberVersions(userId, summaries, complete: page.complete);
        // Warm only the two most recent details, not the entire library.
        if (page.items.length <= WorkoutFirestoreDataSource.pageSize) {
          unawaited(_warmOfflineDetails(userId, summaries.take(2).toList()));
        }
        yield WorkoutCatalogPage(summaries, complete: page.complete);
      }
    } catch (_) {
      // An explicit refresh must not report success after serving only cache.
      if (requireServer) rethrow;
      if (visible.isNotEmpty) return;
      // Old detail caches remain usable even before the first summary sync.
      final legacyCache = await _firestore.loadCached(userId);
      if (legacyCache.isEmpty) rethrow;
      yield WorkoutCatalogPage(
        legacyCache.map((item) => summarizeWorkout(item.toEntity())).toList(),
        cached: true,
      );
    }
  }

  int _warmGeneration = 0;
  Future<void> _warmOfflineDetails(
    String uid,
    List<WorkoutSummary> items,
  ) async {
    final generation = ++_warmGeneration;
    var next = 0;
    Future<void> worker() async {
      while (next < items.length &&
          generation == _warmGeneration &&
          _auth.currentUser?.uid == uid) {
        final item = items[next++];
        try {
          await loadOne(item.id);
        } catch (_) {
          return;
        } // Offline: existing cached details remain usable.
      }
    }

    await Future.wait([worker(), worker()]);
  }

  List<WorkoutSummary> _sortedSummaries(Iterable<WorkoutSummary> items) =>
      items.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<List<Workout>> load() => watch().last;

  @override
  Stream<List<Workout>> watch() => _watch();

  Stream<List<Workout>> _watch({
    bool requireServer = false,
    void Function(bool complete)? onServerPage,
  }) async* {
    final user = _requireUser();
    final cached = await _firestore.loadCached(user.uid);
    final visible = {for (final item in cached) item.id: item.toEntity()};
    if (visible.isNotEmpty) yield _sorted(visible.values);
    try {
      await for (final page in _firestore.loadPages(user.uid)) {
        if (page.complete && page.items.isEmpty) {
          final legacy = _local.load();
          if (legacy.isNotEmpty) {
            for (final workout in legacy) {
              await _saveForUser(workout.toEntity(), user);
            }
            await _local.clear();
            onServerPage?.call(true);
            yield (await _firestore.load(user.uid))
                .map((item) => item.toEntity())
                .toList();
            return;
          }
        }
        // Retain cached rows while later pages are still arriving. A complete
        // server result removes rows deleted on other devices.
        if (page.complete) {
          final ids = page.items.map((item) => item.id).toSet();
          visible.removeWhere((id, _) => !ids.contains(id));
        }
        for (final item in page.items) {
          final previous = visible[item.id];
          visible[item.id] =
              previous != null && previous.updatedAt == item.updatedAt
              ? previous
              : item.toEntity();
        }
        onServerPage?.call(page.complete);
        yield _sorted(visible.values);
      }
    } catch (error, stack) {
      if (requireServer) rethrow;
      if (visible.isEmpty) rethrow;
      // Cached workouts remain usable offline, including search and schedules.
      debugPrint(
        'Workout refresh failed; retaining available data: $error\n$stack',
      );
    }
  }

  List<Workout> _sorted(Iterable<Workout> values) =>
      values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<Workout> save(
    Workout workout, {
    void Function(int completed, int total)? onProgress,
  }) => _saveForUser(workout, _requireUser(), onProgress: onProgress);

  @override
  Future<Workout> importStarter(Workout workout) async {
    if (!isStarterWorkout(workout.id)) {
      throw ArgumentError('Invalid starter ID');
    }
    final user = _requireUser();
    // Avoid rendering/uploading assets again on a retry. The create transaction
    // below still arbitrates simultaneous imports from two controllers.
    final existing = await _firestore.loadOne(
      user.uid,
      workout.id,
      requireServer: true,
    );
    if (existing != null) return existing.toEntity();
    final modules = <WorkoutModule>[];
    for (final module in workout.modules) {
      modules.add(await prepareSlideDesign(module));
    }
    if (_auth.currentUser?.uid != user.uid) {
      throw StateError('로그인 계정이 변경되었습니다.');
    }
    return _saveForUser(
      workout.copyWith(modules: modules),
      user,
      ifAbsent: true,
    );
  }

  Future<Workout> _saveForUser(
    Workout workout,
    User user, {
    bool ifAbsent = false,
    void Function(int completed, int total)? onProgress,
  }) async {
    for (final module in workout.modules) {
      final error = timingValidationError(module);
      if (error != null) throw FormatException(error);
    }
    final author = WorkoutAuthor(
      id: user.uid,
      displayName: user.displayName ?? '사용자',
      photoUrl: user.photoURL,
    );
    final ownedWorkout = workout.copyWith(
      ownerId: user.uid,
      author: author,
      updatedAt: DateTime.now(),
    );
    final uploaded = await _storage.syncImages(
      user.uid,
      ownedWorkout,
      onProgress: onProgress,
    );
    final stored = await _firestore.save(
      user.uid,
      WorkoutModel.fromEntity(uploaded),
      ifAbsent: ifAbsent,
    );
    final saved = stored.toEntity();
    if (_auth.currentUser?.uid == user.uid && _cacheOwner == user.uid) {
      _details.put((owner: user.uid, id: saved.id), saved);
      _versions[saved.id] = saved.updatedAt;
    }
    return saved;
  }

  @override
  Future<void> delete(String workoutId) async {
    final user = _requireUser();
    // Images may also belong to copied workouts or active playback snapshots.
    // Delete only the document; assets require reference-aware garbage collection.
    await _firestore.delete(user.uid, workoutId);
    _details.invalidate((owner: user.uid, id: workoutId));
    _versions.remove(workoutId);
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) throw StateError('로그인이 필요합니다.');
    return user;
  }
}

@riverpod
Future<WorkoutRepository> workoutRepository(Ref ref) async =>
    WorkoutRepositoryImpl(
      FirebaseAuth.instance,
      WorkoutFirestoreDataSource(FirebaseFirestore.instance),
      WorkoutStorageDataSource(FirebaseStorage.instance),
      await ref.watch(workoutLocalDataSourceProvider.future),
    );
