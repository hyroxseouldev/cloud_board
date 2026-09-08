import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';

OperationsReport buildOperationsReport(
  List<OperationEvent> events, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final startOfToday = DateTime(current.year, current.month, current.day);
  final startOfMonth = DateTime(current.year, current.month);
  final playbackEvents = events.where(
    (event) => event.type == 'playback_started',
  );
  final today = playbackEvents
      .where(
        (event) => DateTime.fromMillisecondsSinceEpoch(event.occurredAtMs)
            .isAfter(startOfToday.subtract(const Duration(milliseconds: 1))),
      )
      .toList();
  final month = playbackEvents
      .where(
        (event) => DateTime.fromMillisecondsSinceEpoch(event.occurredAtMs)
            .isAfter(startOfMonth.subtract(const Duration(milliseconds: 1))),
      )
      .toList();
  final scheduled = month.where((event) => event.scheduled).toList();
  final onTime = scheduled.where((event) {
    final scheduledAt = event.scheduledAtMs;
    if (scheduledAt == null) return false;
    return (event.occurredAtMs - scheduledAt).abs() <=
        const Duration(minutes: 2).inMilliseconds;
  }).length;
  final counts = <String, int>{};
  for (final event in month) {
    final name = event.workoutName;
    if (name != null && name.isNotEmpty) counts[name] = (counts[name] ?? 0) + 1;
  }
  final top = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return OperationsReport(
    todayPlaybackCount: today.length,
    monthPlaybackCount: month.length,
    scheduledPlaybackCount: scheduled.length,
    onTimePlaybackCount: onTime,
    disconnectCount: events
        .where((event) => event.type == 'device_offline')
        .length,
    onlineDuration: _onlineDuration(events, current),
    mostPlayedWorkoutName: top.isEmpty ? null : top.first.key,
    mostPlayedWorkoutCount: top.isEmpty ? 0 : top.first.value,
  );
}

Duration _onlineDuration(List<OperationEvent> events, DateTime now) {
  final ascending = events.toList()
    ..sort((a, b) => a.occurredAtMs.compareTo(b.occurredAtMs));
  final onlineAt = <String, int>{};
  var totalMs = 0;
  for (final event in ascending) {
    final deviceId = event.deviceId;
    if (deviceId == null) continue;
    if (event.type == 'device_online') {
      onlineAt[deviceId] = event.occurredAtMs;
    } else if (event.type == 'device_offline') {
      final start = onlineAt.remove(deviceId);
      if (start != null && event.occurredAtMs >= start) {
        totalMs += event.occurredAtMs - start;
      }
    }
  }
  for (final start in onlineAt.values) {
    if (now.millisecondsSinceEpoch >= start) {
      totalMs += now.millisecondsSinceEpoch - start;
    }
  }
  return Duration(milliseconds: totalMs);
}

DateTime scheduledDateTime(WorkoutSchedule schedule, DateTime day) =>
    DateTime(day.year, day.month, day.day, schedule.hour, schedule.minute);

String scheduleOccurrenceKey(WorkoutSchedule schedule, DateTime day) =>
    '${schedule.id}:${day.year.toString().padLeft(4, '0')}'
    '${day.month.toString().padLeft(2, '0')}'
    '${day.day.toString().padLeft(2, '0')}';

bool isScheduleDue(
  WorkoutSchedule schedule,
  DateTime now, {
  Duration grace = const Duration(minutes: 5),
}) {
  if (!schedule.enabled || !schedule.weekdays.contains(now.weekday)) {
    return false;
  }
  final start = scheduledDateTime(schedule, now);
  return !now.isBefore(start) && now.difference(start) <= grace;
}

WorkoutSchedule? nextSchedule(List<WorkoutSchedule> schedules, DateTime now) {
  final candidates = <({WorkoutSchedule schedule, DateTime date})>[];
  for (var offset = 0; offset < 8; offset++) {
    final day = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: offset));
    for (final schedule in schedules) {
      if (!schedule.enabled || !schedule.weekdays.contains(day.weekday)) {
        continue;
      }
      final date = scheduledDateTime(schedule, day);
      if (date.isAfter(now)) candidates.add((schedule: schedule, date: date));
    }
  }
  candidates.sort((a, b) => a.date.compareTo(b.date));
  return candidates.isEmpty ? null : candidates.first.schedule;
}

bool isBlackScreenTime(BrandTemplate template, DateTime now) {
  final start = template.blackScreenStartMinutes;
  final end = template.blackScreenEndMinutes;
  if (start == end) return false;
  final current = now.hour * 60 + now.minute;
  return start < end
      ? current >= start && current < end
      : current >= start || current < end;
}
