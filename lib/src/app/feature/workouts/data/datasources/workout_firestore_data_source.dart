import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';

class WorkoutFirestoreDataSource {
  WorkoutFirestoreDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _workouts(String userId) =>
      _firestore.collection('users').doc(userId).collection('workouts');

  static const pageSize = 24;

  Future<List<WorkoutModel>> loadCached(String userId) async {
    try {
      final snapshot = await _workouts(userId)
          .orderBy('updatedAt', descending: true)
          .get(const GetOptions(source: Source.cache));
      return _decode(snapshot);
    } on FirebaseException {
      return const [];
    }
  }

  Stream<({List<WorkoutModel> items, bool complete})> loadPages(
    String userId,
  ) async* {
    final items = <String, WorkoutModel>{};
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      Query<Map<String, dynamic>> query = _workouts(userId)
          .orderBy('updatedAt', descending: true)
          .limit(pageSize);
      if (cursor != null) query = query.startAfterDocument(cursor);
      final snapshot = await query.get(const GetOptions(source: Source.server));
      for (final item in _decode(snapshot)) {
        items[item.id] = item;
      }
      final complete = snapshot.docs.length < pageSize;
      yield (items: List.unmodifiable(items.values), complete: complete);
      if (complete) return;
      cursor = snapshot.docs.last;
    }
  }

  Future<List<WorkoutModel>> load(String userId) async =>
      (await loadPages(userId).last).items;

  List<WorkoutModel> _decode(QuerySnapshot<Map<String, dynamic>> snapshot) =>
      snapshot.docs
          .map(
            (document) =>
                WorkoutModel.fromJson({...document.data(), 'id': document.id}),
          )
          .toList();

  Future<void> save(String userId, WorkoutModel workout) =>
      _workouts(userId)
          .doc(workout.id)
          .set(workout.toJson(), SetOptions(merge: true));

  Future<void> delete(String userId, String workoutId) =>
      _workouts(userId).doc(workoutId).delete();
}
