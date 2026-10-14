import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/operations/data/models/store_operations_models.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/domain/operation_history.dart';
import 'package:cloud_board/src/app/feature/operations/domain/operations_metrics.dart';

OperationEvent row(
  String id,
  String type,
  int at, {
  String device = 'tv',
  String? session,
  String? incident,
  String? recovery,
  String? impact,
  String? role = 'display',
}) => OperationEventModel.fromJson({
  'id': id,
  'eventId': id,
  'schemaVersion': 2,
  'type': type,
  'occurredAtMs': at,
  'deviceId': device,
  'deviceRole': role,
  'deviceName': '이름 변경 전 TV',
  'zoneName': '1층',
  'appVersion': '1.1.1',
  'sessionId': session,
  'workoutId': 'w',
  'workoutName': '수업',
  'incidentId': incident,
  'recoveryOfEventId': recovery,
  'playbackImpact': impact,
}).toEntity();

void main() {
  const range = OperationEventRange(startAtMs: 1000, endBeforeMs: 10000);
  test('Seoul day and month boundary do not depend on viewer timezone', () {
    final start = centerDayStartMs(DateTime.utc(2026, 10, 1));
    expect(start, DateTime.utc(2026, 9, 30, 15).millisecondsSinceEpoch);
    expect(centerDateTime(start - 1).month, 9);
    expect(centerDateTime(start).day, 1);
    expect(centerDateTime(start).hour, 0);
  });

  test(
    'full range counts >1000 unique sessions and deduplicates retry events',
    () {
      final events = List.generate(
        1205,
        (i) => row('e$i', 'playback_started', 2000 + i, session: 's$i'),
      );
      events.add(events.first);
      events.add(events.first.copyWith(id: 'other', eventId: 'other'));
      events.add(row('before', 'playback_started', 999, session: 'before'));
      events.add(row('after', 'playback_started', 10000, session: 'after'));
      final report = buildOperationsRangeReport(
        events,
        range: range,
        nowMs: 10000,
      );
      expect(report.playbackCount, 1205);
      expect(report.completedCount, 0);
    },
  );

  test(
    'three TVs sum confirmed intervals, duplicate connects keep first start',
    () {
      final events = <OperationEvent>[];
      for (final id in ['a', 'b', 'c']) {
        events.add(row('$id-on', 'device_online', 1000, device: id));
        events.add(row('$id-on-duplicate', 'device_online', 2000, device: id));
        events.add(row('$id-off', 'device_offline', 5000, device: id));
      }
      events.add(
        row(
          'phone-on',
          'device_online',
          1000,
          device: 'phone',
          role: 'controller',
        ),
      );
      events.add(
        row(
          'phone-off',
          'device_offline',
          5000,
          device: 'phone',
          role: 'controller',
        ),
      );
      final report = buildOperationsRangeReport(
        events.reversed,
        range: range,
        nowMs: 10000,
      );
      expect(report.onlineDuration, const Duration(seconds: 12));
      expect(report.onlineDurationByDevice.length, 3);
      expect(report.hasUnknownConnectionTime, isFalse);
    },
  );

  test(
    'missing boundary and open interval remain unknown rather than inflated',
    () {
      final report = buildOperationsRangeReport(
        [
          row('prior-off', 'device_offline', 4000),
          row('online', 'device_online', 5000),
        ],
        range: range,
        nowMs: 10000,
      );
      expect(report.onlineDuration, Duration.zero);
      expect(report.hasUnknownConnectionTime, isTrue);
    },
  );

  test('normal shutdown, server disconnect and actual interruption differ', () {
    final report = buildOperationsRangeReport(
      [
        row('shutdown', 'device_shutdown', 2000),
        row('disconnect', 'device_offline', 3000, incident: 'disconnect'),
        row(
          'interruption',
          'playback_interrupted',
          4000,
          session: 'class',
          impact: 'interrupted',
        ),
      ],
      range: range,
      nowMs: 10000,
    );
    expect(report.disconnectCount, 1);
    expect(report.interruptionCount, 1);
    expect(report.incidents.length, 2);
    expect(report.incidents.first.impactLabel, '재생 영향 확인 불가');
  });

  test(
    'explicit recovery references require same device and compatible phase',
    () {
      final offline = row('off', 'device_offline', 2000, incident: 'incident');
      final interrupted = row(
        'stop',
        'playback_interrupted',
        2500,
        session: 's',
        incident: 'incident',
      );
      final recovered = row(
        'on',
        'device_online',
        5000,
        incident: 'incident',
        recovery: 'off',
      );
      final incidents = buildOperationIncidents([
        offline,
        interrupted,
        row('nearby', 'device_online', 3000),
        row(
          'wrong-device',
          'device_online',
          4000,
          device: 'other',
          recovery: 'off',
        ),
        recovered,
        row(
          'wrong-session',
          'playback_restored',
          6000,
          session: 'other',
          recovery: 'stop',
        ),
      ]);
      expect(incidents.first.recovery?.id, 'on');
      expect(incidents.first.duration, const Duration(seconds: 3));
      expect(incidents.last.recovery, isNull);
    },
  );

  test(
    'old data retains unknown details and snapshots survive rename/deletion',
    () {
      final old = OperationEventModel.fromJson({
        'id': 'legacy',
        'type': 'device_offline',
        'occurredAtMs': 2000,
      }).toEntity();
      expect(old.sessionId, isNull);
      expect(old.deviceName, isNull);
      expect(old.appVersion, isNull);
      expect(old.schemaVersion, 1);
      final stored = row('new', 'device_offline', 3000);
      final decoded = OperationEventModel.fromJson(
        OperationEventModel.fromEntity(stored).toJson(),
      ).toEntity();
      expect(decoded.deviceName, '이름 변경 전 TV');
      expect(decoded.zoneName, '1층');
      expect(
        buildOperationsRangeReport([old, stored], range: range).hasLegacyEvents,
        isTrue,
      );
    },
  );

  test(
    'completion is unique by session and future delayed rows do not count yet',
    () {
      final report = buildOperationsRangeReport(
        [
          row('done', 'playback_completed', 2000, session: 's'),
          row('duplicate-done', 'playback_completed', 2100, session: 's'),
          row('future', 'playback_started', 9000, session: 'future'),
        ],
        range: range,
        nowMs: 5000,
      );
      expect(report.completedCount, 1);
      expect(report.playbackCount, 0);
    },
  );
}
