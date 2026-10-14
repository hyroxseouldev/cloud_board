import 'package:cloud_board/src/app/feature/operations/domain/operation_history.dart';

import 'dart:async';

import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:cloud_board/src/app/feature/operations/data/models/store_operations_models.dart';
import 'package:cloud_board/src/app/feature/operations/data/models/audience_branding_model.dart';

class StoreOperationsRealtimeDataSource {
  const StoreOperationsRealtimeDataSource(this._database, this._ownerId);

  final FirebaseDatabase _database;
  final String? _ownerId;

  DatabaseReference get _operations =>
      _database.ref('users/${_requireOwnerId()}/operations');

  Stream<AudienceBrandingModel?> watchAudienceBranding() {
    if (_ownerId == null) return Stream.value(null);
    return _operations
        .child('brandProjection')
        .onValue
        .map(
          (event) =>
              AudienceBrandingModel.parse(event.snapshot.value, _ownerId),
        );
  }

  Stream<BrandTemplateModel> watchBrandTemplate({bool effective = false}) {
    if (_ownerId == null) {
      return Stream.value(
        BrandTemplateModel.fromEntity(BrandTemplate.initial()),
      );
    }
    final brands = _operations
        .child('brand')
        .onValue
        .map((event) => event.snapshot.value);
    final values = effective
        ? brands
        : configuredBrandValues(
            _operations
                .child('brandConfig')
                .onValue
                .map((event) => event.snapshot.value),
            () => brands,
          );
    return values.map((value) {
      if (value == null) {
        return BrandTemplateModel.fromEntity(BrandTemplate.initial());
      }
      return BrandTemplateModel.fromJson(_stringMap(value));
    });
  }

  Stream<List<WorkoutScheduleModel>> watchSchedules() {
    if (_ownerId == null) return Stream.value(const []);
    return _operations.child('schedules').onValue.map((event) {
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
              return time != 0 ? time : a.workoutName.compareTo(b.workoutName);
            });
      return schedules;
    });
  }

  Stream<List<OperationEventModel>> watchEvents() {
    if (_ownerId == null) return Stream.value(const []);
    return _operations
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
  }

  /// Query the entire selected interval using the occurredAtMs index. UI pages
  /// are slices of this complete range, never a last-1,000 approximation.
  Stream<List<OperationEventModel>> watchEventsInRange(
    OperationEventRange range,
  ) {
    if (_ownerId == null) return Stream.error(StateError('연결된 매장을 확인해 주세요.'));
    return _operations
        .child('events')
        .orderByChild('occurredAtMs')
        .startAt(range.startAtMs)
        .endBefore(range.endBeforeMs)
        .onValue
        .map((event) {
          final value = event.snapshot.value;
          if (value == null) return const <OperationEventModel>[];
          if (value is! Map || value.values.any((item) => item is! Map)) {
            throw const FormatException('일부 운영 기록을 읽지 못했습니다. 다시 조회해 주세요.');
          }
          return value.entries
              .map(
                (entry) => OperationEventModel.fromJson(
                  _stringMap(entry.value)
                    ..putIfAbsent('id', () => entry.key.toString()),
                ),
              )
              .toList();
        });
  }

  Future<void> recordDetailedEvent(OperationEventModel event) => _operations
      .child('events/${event.eventId ?? event.id}')
      .set(event.toJson());

  Future<void> saveBrandTemplate(BrandTemplateModel model) async {
    _requireOwnerId();
    await FirebaseFunctions.instanceFor(region: 'asia-northeast3')
        .httpsCallable('cloudboardSaveBrandConfig')
        .call({'brand': model.toJson()});
  }

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

  String _requireOwnerId() {
    final ownerId = _ownerId;
    if (ownerId == null) throw StateError('연결된 매장을 찾을 수 없습니다.');
    return ownerId;
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

/// Legacy clients still write `brand`. Keep that subscription live until a
/// server-owned original exists, then stop reading the effective projection.
Stream<Object?> configuredBrandValues(
  Stream<Object?> configured,
  Stream<Object?> Function() legacy,
) {
  late StreamController<Object?> output;
  StreamSubscription<Object?>? configSubscription;
  StreamSubscription<Object?>? legacySubscription;
  var hasConfig = false;
  output = StreamController<Object?>(
    onListen: () {
      configSubscription = configured.listen((value) {
        hasConfig = value != null;
        if (hasConfig) {
          final previous = legacySubscription;
          legacySubscription = null;
          if (previous != null) unawaited(previous.cancel());
          output.add(value);
        } else {
          legacySubscription ??= legacy().listen((value) {
            if (!hasConfig && !output.isClosed) output.add(value);
          }, onError: output.addError);
        }
      }, onError: output.addError);
    },
    onCancel: () async {
      await configSubscription?.cancel();
      await legacySubscription?.cancel();
    },
  );
  return output.stream;
}
