import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/workout_model.dart';

class WorkoutFirestoreDataSource {
  WorkoutFirestoreDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _workouts(String userId) =>
      _firestore.collection('users').doc(userId).collection('workouts');

  Future<List<WorkoutModel>> load(String userId) async {
    final snapshot = await _workouts(userId)
        .orderBy('updatedAt', descending: true)
        .get();
    return snapshot.docs
        .map(
          (document) =>
              WorkoutModel.fromJson({...document.data(), 'id': document.id}),
        )
        .toList();
  }

  Future<void> save(String userId, WorkoutModel workout) =>
      _workouts(userId)
          .doc(workout.id)
          .set(workout.toJson(), SetOptions(merge: true));

  Future<void> delete(String userId, String workoutId) =>
      _workouts(userId).doc(workoutId).delete();
}
