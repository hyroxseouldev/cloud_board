import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:cloud_board/src/app/feature/operations/data/models/store_operations_models.dart';

class StoreOperationsRealtimeDataSource {
  const StoreOperationsRealtimeDataSource(this._database, this._auth);

  final FirebaseDatabase _database;
  final FirebaseAuth _auth;

  DatabaseReference get _operations =>
      _database.ref('users/${_requireUserId()}/operations');

  Stream<BrandTemplateModel> watchBrandTemplate() =>
      _operations.child('brand').onValue.map((event) {
        final value = event.snapshot.value;
        if (value is! Map) {
          return BrandTemplateModel.fromJson(const <String, dynamic>{});
        }
        return BrandTemplateModel.fromJson(_stringMap(value));
      });

  Stream<List<WorkoutScheduleModel>> watchSchedules() =>
      _operations.child('schedules').onValue.map((event) {
        final value = event.snapshot.value;
        if (value is! Map) return const <WorkoutScheduleModel>[];
        final schedules =
            value.entries
                .where((entry) => entry.value is Map)
                .map(
                  (entry) => WorkoutScheduleModel.fromJson(
                    _stringMap(entry.value)
                      ..putIfAbsent('id', () => entry.key.toString()),
                  ),
                )
                .toList()
              ..sort((a, b) {
                final time = (a.hour * 60 + a.minute).compareTo(
                  b.hour * 60 + b.minute,
                );
                return time != 0
                    ? time
                    : a.workoutName.compareTo(b.workoutName);
              });
        return schedules;
      });

  Stream<List<OperationEventModel>> watchEvents() => _operations
      .child('events')
      .orderByChild('occurredAtMs')
      .limitToLast(1000)
      .onValue
      .map((event) {
        final value = event.snapshot.value;
        if (value is! Map) return const <OperationEventModel>[];
        final events =
            value.entries
                .where((entry) => entry.value is Map)
                .map(
                  (entry) => OperationEventModel.fromJson(
                    _stringMap(entry.value)
                      ..putIfAbsent('id', () => entry.key.toString()),
                  ),
                )
                .toList()
              ..sort((a, b) => b.occurredAtMs.compareTo(a.occurredAtMs));
        return events;
      });

  Future<void> saveBrandTemplate(BrandTemplateModel model) =>
      _operations.child('brand').set(model.toJson());

  Future<void> saveSchedule(WorkoutScheduleModel model) =>
      _operations.child('schedules/${model.id}').set(model.toJson());

  Future<void> deleteSchedule(String scheduleId) =>
      _operations.child('schedules/$scheduleId').remove();

  Future<bool> claimOccurrence(String scheduleId, String occurrenceKey) async {
    final reference = _operations.child(
      'schedules/$scheduleId/lastOccurrenceKey',
    );
    final result = await reference.runTransaction((current) {
      if (current == occurrenceKey) return Transaction.abort();
      return Transaction.success(occurrenceKey);
    });
    return result.committed;
  }

  Future<void> recordEvent({
    required String type,
    String? deviceId,
    String? workoutId,
    String? workoutName,
    bool scheduled = false,
    int? scheduledAtMs,
  }) {
    final reference = _operations.child('events').push();
    return reference.set({
      'id': reference.key,
      'type': type,
      'occurredAtMs': ServerValue.timestamp,
      'deviceId': deviceId,
      'workoutId': workoutId,
      'workoutName': workoutName,
      'scheduled': scheduled,
      'scheduledAtMs': scheduledAtMs,
    });
  }

  String _requireUserId() {
    final user = _auth.currentUser;
    if (user == null) throw StateError('로그인이 필요합니다.');
    return user.uid;
  }
}

Map<String, dynamic> _stringMap(Object? value) {
  if (value is! Map) return <String, dynamic>{};
  return value.map(
    (key, item) => MapEntry(key.toString(), _normalizeValue(item)),
  );
}

Object? _normalizeValue(Object? value) {
  if (value is Map) return _stringMap(value);
  if (value is List) return value.map(_normalizeValue).toList();
  return value;
}
