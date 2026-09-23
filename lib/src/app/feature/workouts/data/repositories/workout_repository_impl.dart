import 'dart:async';

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

part 'workout_repository_impl.g.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
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

  @override
  Future<Workout?> loadOne(String workoutId) async =>
      (await _firestore.loadOne(_requireUser().uid, workoutId))?.toEntity();

  @override
  Stream<List<WorkoutSummary>> watchSummaries() async* {
    final userId = _requireUser().uid;
    // Retain full cached details already used by earlier app versions for offline
    // playback. Do not download every detail just to construct this catalog.
    final cached = await _firestore.loadCachedSummaries(userId);
    final visible = {for (final item in cached) item.id: item.toEntity()};
    if (visible.isNotEmpty) yield _sortedSummaries(visible.values);
    try {
      if (!await _firestore.hasSummaryCatalog(userId)) {
        await for (final items in watch()) {
          yield items.map(summarizeWorkout).toList();
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
        yield _sortedSummaries(visible.values);
        if (page.complete) {
          // Preserve the previous offline catalog behavior without keeping every
          // decoded workout in Riverpod or blocking the first usable list.
          unawaited(_warmOfflineDetails(userId, visible.values.toList()));
        }
      }
    } catch (_) {
      if (visible.isNotEmpty) return;
      // Old detail caches remain usable even before the first summary sync.
      final legacyCache = await _firestore.loadCached(userId);
      if (legacyCache.isEmpty) rethrow;
      yield legacyCache
          .map((item) => summarizeWorkout(item.toEntity()))
          .toList();
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
          await _firestore.ensureOfflineDetail(uid, item.id, item.updatedAt);
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
  Stream<List<Workout>> watch() async* {
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
        yield _sorted(visible.values);
      }
    } catch (error, stack) {
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

  Future<Workout> _saveForUser(
    Workout workout,
    User user, {
    void Function(int completed, int total)? onProgress,
  }) async {
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
    );
    return stored.toEntity();
  }

  @override
  Future<void> delete(String workoutId) async {
    final user = _requireUser();
    // Images may also belong to copied workouts or active playback snapshots.
    // Delete only the document; assets require reference-aware garbage collection.
    await _firestore.delete(user.uid, workoutId);
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
