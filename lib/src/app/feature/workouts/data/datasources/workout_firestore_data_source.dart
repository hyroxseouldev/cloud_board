import 'package:cloud_board/src/app/feature/workouts/data/models/workout_document.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_save_documents.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';

import 'package:cloud_board/src/app/feature/workouts/data/models/workout_summary_model.dart';

class WorkoutFirestoreDataSource {
  WorkoutFirestoreDataSource(this._firestore, {FirebaseFunctions? functions})
    : _functions = functions; // ignore: prefer_initializing_formals

  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _functions;

  CollectionReference<Map<String, dynamic>> _workouts(String userId) =>
      _firestore.collection('users').doc(userId).collection('workouts');

  static const pageSize = 24;

  CollectionReference<Map<String, dynamic>> _summaries(String userId) =>
      _firestore.collection('users').doc(userId).collection('workoutSummaries');

  // Marker is set only after a complete, verified backfill. Older accounts and
  // cached installs can safely fall back to full documents during rollout.
  Future<bool> hasSummaryCatalog(String userId) async {
    final marker = await _firestore.doc('users/$userId/catalog/schema').get();
    return marker.data()?['version'] == 2 &&
        marker.data()?['restPolicyVersion'] == 1;
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

  /// Each emission contains only the newly fetched page, never earlier DTOs.
  Stream<({List<WorkoutSummaryModel> items, bool complete})> loadSummaryPages(
    String userId,
  ) async* {
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      Query<Map<String, dynamic>> query = _summaries(userId)
          .orderBy('updatedAt', descending: true)
          .limit(pageSize);
      if (cursor != null) query = query.startAfterDocument(cursor);
      final snapshot = await query.get(const GetOptions(source: Source.server));
      final items = snapshot.docs
          .map(
            (doc) =>
                WorkoutSummaryModel.fromJson({...doc.data(), 'id': doc.id}),
          )
          .toList(growable: false);
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

  Future<WorkoutModel?> loadOne(
    String userId,
    String workoutId, {
    bool requireServer = false,
  }) async {
    // Default SDK source refreshes online and retains existing detail cache offline.
    final snapshot = await _workouts(userId)
        .doc(workoutId)
        .get(
          GetOptions(
            source: requireServer ? Source.server : Source.serverAndCache,
          ),
        );
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

  /// Detail fallback uses the same delta contract as summary pages.
  Stream<({List<WorkoutModel> items, bool complete})> loadPages(
    String userId,
  ) async* {
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      Query<Map<String, dynamic>> query = _workouts(userId)
          .orderBy('updatedAt', descending: true)
          .limit(pageSize);
      if (cursor != null) query = query.startAfterDocument(cursor);
      final snapshot = await query.get(const GetOptions(source: Source.server));
      final items = _decode(snapshot);
      final complete = snapshot.docs.length < pageSize;
      yield (items: List.unmodifiable(items), complete: complete);
      if (complete) return;
      cursor = snapshot.docs.last;
    }
  }

  Future<List<WorkoutModel>> load(String userId) async {
    final items = <String, WorkoutModel>{};
    await for (final page in loadPages(userId)) {
      for (final item in page.items) {
        items[item.id] = item;
      }
    }
    return List.unmodifiable(items.values);
  }

  List<WorkoutModel> _decode(QuerySnapshot<Map<String, dynamic>> snapshot) =>
      snapshot.docs
          .map(
            (document) =>
                WorkoutDocument.decode({...document.data(), 'id': document.id}),
          )
          .toList();

  Future<WorkoutModel> save(
    String userId,
    WorkoutModel workout, {
    bool ifAbsent = false,
    DateTime? expectedUpdatedAt,
    bool requireExisting = false,
  }) async {
    // Explicit saves overwrite the same workout, even when its editor revision
    // is stale or another device deleted it. Read the latest document only to
    // preserve unknown fields and legacy settings; the server still enforces
    // account access and quota in its atomic commit.
    final settings =
        (await _firestore
                .doc('users/$userId/settings/workout')
                .get(const GetOptions(source: Source.server)))
            .data();
    final reference = _workouts(userId).doc(workout.id);
    final previous = (await reference.get(
      const GetOptions(source: Source.server),
    )).data();
    if (ifAbsent && previous != null) {
      return WorkoutDocument.decode({...previous, 'id': workout.id});
    }
    final documents = WorkoutSaveDocuments(
      workout,
      contentOnly: settings?['contentOnly'] == true,
      previous: previous,
    );
    final result =
        await (_functions ??
                FirebaseFunctions.instanceFor(region: 'asia-northeast3'))
            .httpsCallable('saveWorkout')
            .call({
              'ownerId': userId,
              'workout': {
                ..._callableValue(documents.workout) as Map<String, dynamic>,
                'createdAt': workout.createdAt.millisecondsSinceEpoch,
                'updatedAt': workout.updatedAt.millisecondsSinceEpoch,
              },
              'ifAbsent': ifAbsent,
              'requireExisting': requireExisting,
              'settingsContentOnly': settings?['contentOnly'] == true,
              'expectedUpdatedAt': previous == null
                  ? null
                  : const FirestoreTimestampConverter()
                        .fromJson(previous['updatedAt'])
                        .millisecondsSinceEpoch,
            });
    return WorkoutDocument.decode(
      _documentValue((result.data as Map)['workout']) as Map<String, dynamic>,
    );
  }

  Future<void> delete(String userId, String workoutId) async {
    final batch = _firestore.batch();
    batch.delete(_workouts(userId).doc(workoutId));
    batch.delete(_summaries(userId).doc(workoutId));
    await batch.commit();
  }
}

Object? _callableValue(Object? value) => switch (value) {
  Timestamp timestamp => {
    '__timestampMillis': timestamp.millisecondsSinceEpoch,
  },
  Map map => <String, dynamic>{
    for (final entry in map.entries)
      entry.key as String: _callableValue(entry.value),
  },
  List list => list.map(_callableValue).toList(),
  _ => value,
};

Object? _documentValue(Object? value) => switch (value) {
  Map map when map.length == 1 && map['__timestampMillis'] is int =>
    Timestamp.fromMillisecondsSinceEpoch(map['__timestampMillis'] as int),
  Map map => <String, dynamic>{
    for (final entry in map.entries)
      entry.key as String: _documentValue(entry.value),
  },
  List list => list.map(_documentValue).toList(),
  _ => value,
};
