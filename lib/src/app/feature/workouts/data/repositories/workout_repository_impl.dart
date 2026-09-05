import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/entities/workout.dart';
import '../../domain/repositories/workout_repository.dart';
import '../datasources/workout_firestore_data_source.dart';
import '../datasources/workout_local_data_source.dart';
import '../datasources/workout_storage_data_source.dart';
import '../models/workout_model.dart';

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
  Future<List<Workout>> load() async {
    final user = _requireUser();
    var values = await _firestore.load(user.uid);
    final legacy = _local.load();
    if (values.isEmpty && legacy.isNotEmpty) {
      for (final workout in legacy) {
        await _saveForUser(workout.toEntity(), user);
      }
      await _local.clear();
      values = await _firestore.load(user.uid);
    }
    return values.map((item) => item.toEntity()).toList();
  }

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
    await _storage.deleteWorkout(user.uid, workoutId);
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
