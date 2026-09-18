import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/data/datasources/workout_preferences_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_preferences_repository.dart';
part 'workout_preferences_repository_impl.g.dart';

class WorkoutPreferencesRepositoryImpl implements WorkoutPreferencesRepository {
  WorkoutPreferencesRepositoryImpl(this.source);
  final WorkoutPreferencesDataSource source;
  @override
  Future<WorkoutPreferences?> load(String ownerId, {bool fresh = false}) =>
      source.load(ownerId, fresh: fresh);
  @override
  Future<WorkoutPreferences> loadForEditing(String ownerId) =>
      source.loadForEditing(ownerId);
  @override
  Future<WorkoutPreferences> save(String ownerId, WorkoutPreferences value) =>
      source.save(ownerId, value);
}

@Riverpod(keepAlive: true)
WorkoutPreferencesRepository workoutPreferencesRepository(Ref ref) {
  final source = WorkoutPreferencesDataSource(
    FirebaseFirestore.instance,
    FirebaseStorage.instance,
    FirebaseAuth.instance,
  );
  final subscription = FirebaseAuth.instance.authStateChanges().listen(
    (_) => source.clear(),
  );
  ref.onDispose(() {
    subscription.cancel();
    source.clear();
  });
  return WorkoutPreferencesRepositoryImpl(source);
}
