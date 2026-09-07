import 'package:flutter_test/flutter_test.dart';

import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/domain/operations_metrics.dart';

void main() {
  test('예약은 해당 요일과 시작 후 5분 안에만 실행 대상이다', () {
    const schedule = WorkoutSchedule(
      id: 'morning',
      workoutId: 'workout',
      workoutName: '아침 수업',
      weekdays: [1],
      hour: 9,
      minute: 0,
      targetDeviceIds: [],
      enabled: true,
      lastOccurrenceKey: null,
      createdAtMs: 0,
    );

    expect(isScheduleDue(schedule, DateTime(2026, 9, 7, 9, 0)), isTrue);
    expect(isScheduleDue(schedule, DateTime(2026, 9, 7, 9, 5)), isTrue);
    expect(isScheduleDue(schedule, DateTime(2026, 9, 7, 9, 6)), isFalse);
    expect(isScheduleDue(schedule, DateTime(2026, 9, 8, 9, 0)), isFalse);
  });

  test('자정을 넘기는 영업 종료 검은 화면 시간을 계산한다', () {
    final template = BrandTemplate.initial().copyWith(
      blackScreenStartMinutes: 22 * 60,
      blackScreenEndMinutes: 6 * 60,
    );

    expect(isBlackScreenTime(template, DateTime(2026, 9, 7, 23)), isTrue);
    expect(isBlackScreenTime(template, DateTime(2026, 9, 8, 5, 59)), isTrue);
    expect(isBlackScreenTime(template, DateTime(2026, 9, 8, 6)), isFalse);
    expect(isBlackScreenTime(template, DateTime(2026, 9, 8, 14)), isFalse);
  });

  test('운영 이벤트에서 월간 수업과 정시 시작, 온라인 시간을 계산한다', () {
    final now = DateTime(2026, 9, 7, 12);
    final scheduledAt = DateTime(2026, 9, 7, 9).millisecondsSinceEpoch;
    final events = [
      OperationEvent(
        id: '1',
        type: 'device_online',
        occurredAtMs: DateTime(2026, 9, 7, 8).millisecondsSinceEpoch,
        deviceId: 'tv',
        workoutId: null,
        workoutName: null,
        scheduled: false,
        scheduledAtMs: null,
      ),
      OperationEvent(
        id: '2',
        type: 'playback_started',
        occurredAtMs: scheduledAt + const Duration(seconds: 30).inMilliseconds,
        deviceId: 'controller',
        workoutId: 'w1',
        workoutName: '모닝 루틴',
        scheduled: true,
        scheduledAtMs: scheduledAt,
      ),
      OperationEvent(
        id: '3',
        type: 'device_offline',
        occurredAtMs: DateTime(2026, 9, 7, 10).millisecondsSinceEpoch,
        deviceId: 'tv',
        workoutId: null,
        workoutName: null,
        scheduled: false,
        scheduledAtMs: null,
      ),
    ];

    final report = buildOperationsReport(events, now: now);
    expect(report.todayPlaybackCount, 1);
    expect(report.monthPlaybackCount, 1);
    expect(report.scheduledPlaybackCount, 1);
    expect(report.onTimePlaybackCount, 1);
    expect(report.disconnectCount, 1);
    expect(report.onlineDuration, const Duration(hours: 2));
    expect(report.mostPlayedWorkoutName, '모닝 루틴');
  });
}
