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
  Future<Workout> save(Workout workout) =>
      _saveForUser(workout, _requireUser());

  Future<Workout> _saveForUser(Workout workout, User user) async {
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
    final uploaded = await _storage.syncImages(user.uid, ownedWorkout);
    await _firestore.save(user.uid, WorkoutModel.fromEntity(uploaded));
    return uploaded;
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
