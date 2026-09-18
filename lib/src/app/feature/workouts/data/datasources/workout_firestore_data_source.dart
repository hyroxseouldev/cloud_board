import 'package:cloud_board/src/app/feature/workouts/data/models/workout_document.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_content.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';

import 'package:cloud_board/src/app/feature/workouts/data/models/workout_summary_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';

class WorkoutFirestoreDataSource {
  WorkoutFirestoreDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _workouts(String userId) =>
      _firestore.collection('users').doc(userId).collection('workouts');

  static const pageSize = 24;

  CollectionReference<Map<String, dynamic>> _summaries(String userId) =>
      _firestore.collection('users').doc(userId).collection('workoutSummaries');

  // Marker is set only after a complete, verified backfill. Older accounts and
  // cached installs can safely fall back to full documents during rollout.
  Future<bool> hasSummaryCatalog(String userId) async {
    final marker = await _firestore.doc('users/$userId/catalog/schema').get();
    return marker.data()?['version'] == 2;
  }

  Future<List<WorkoutSummaryModel>> loadCachedSummaries(String userId) async {
    try {
      final snapshot = await _summaries(userId)
          .orderBy('updatedAt', descending: true)
          .get(const GetOptions(source: Source.cache));
      return snapshot.docs
          .map(
            (doc) =>
                WorkoutSummaryModel.fromJson({...doc.data(), 'id': doc.id}),
          )
          .toList();
    } on FirebaseException {
      return [];
    }
  }

  Stream<({List<WorkoutSummaryModel> items, bool complete})> loadSummaryPages(
    String userId,
  ) async* {
    final items = <WorkoutSummaryModel>[];
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      Query<Map<String, dynamic>> query = _summaries(userId)
          .orderBy('updatedAt', descending: true)
          .limit(pageSize);
      if (cursor != null) query = query.startAfterDocument(cursor);
      final snapshot = await query.get(const GetOptions(source: Source.server));
      items.addAll(
        snapshot.docs.map(
          (doc) => WorkoutSummaryModel.fromJson({...doc.data(), 'id': doc.id}),
        ),
      );
      final complete = snapshot.docs.length < pageSize;
      yield (items: List.unmodifiable(items), complete: complete);
      if (complete) return;
      cursor = snapshot.docs.last;
    }
  }

  Future<void> ensureOfflineDetail(
    String userId,
    String id,
    DateTime version,
  ) async {
    try {
      final cached = await _workouts(userId)
          .doc(id)
          .get(const GetOptions(source: Source.cache));
      final timestamp = cached.data()?['updatedAt'];
      if (timestamp is Timestamp && timestamp.toDate() == version) return;
    } on FirebaseException {
      /* Not cached yet. */
    }
    await _workouts(userId)
        .doc(id)
        .get(const GetOptions(source: Source.server));
  }

  Future<WorkoutModel?> loadOne(String userId, String workoutId) async {
    // Default SDK source refreshes online and retains existing detail cache offline.
    final snapshot = await _workouts(userId).doc(workoutId).get();
    return snapshot.exists
        ? WorkoutDocument.decode({...snapshot.data()!, 'id': snapshot.id})
        : null;
  }

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
                WorkoutDocument.decode({...document.data(), 'id': document.id}),
          )
          .toList();

  Future<WorkoutModel> save(String userId, WorkoutModel workout) async {
    // Never persist settings composed for a preview. Preserve existing legacy
    // values during rollout; switch to content-only only after admin activation.
    final content = WorkoutContent.fromWorkout(workout.toEntity());
    return _firestore.runTransaction((transaction) async {
      final settings = (await transaction.get(
        _firestore.doc('users/$userId/settings/workout'),
      )).data();
      final reference = _workouts(userId).doc(workout.id);
      final previous = (await transaction.get(reference)).data();
      final contentOnly = settings?['contentOnly'] == true;
      final json = WorkoutDocument.encode(content);
      if (!contentOnly) {
        json.remove('schemaVersion');
        final defaults = workout.toJson();
        for (final key in WorkoutDocument.legacySettingKeys) {
          json[key] = previous != null ? previous[key] : defaults[key];
        }
      }
      // Return the actual persisted representation, not a composed caller value.
      final stored = WorkoutDocument.decode(json);
      transaction.set(reference, json);
      transaction.set(
        _summaries(userId).doc(workout.id),
        WorkoutSummaryModel.fromEntity(summarizeWorkout(workout.toEntity()))
            .toJson(),
      );
      return stored;
    });
  }

  Future<void> delete(String userId, String workoutId) async {
    final batch = _firestore.batch();
    batch.delete(_workouts(userId).doc(workoutId));
    batch.delete(_summaries(userId).doc(workoutId));
    await batch.commit();
  }
}
