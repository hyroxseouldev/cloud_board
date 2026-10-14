import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';

/// Center calendar dates use Asia/Seoul, independently of the viewing device.
const centerTimeZone = 'Asia/Seoul';
const centerUtcOffset = Duration(hours: 9);

DateTime centerDateTime(int milliseconds) =>
    DateTime.fromMillisecondsSinceEpoch(
      milliseconds,
      isUtc: true,
    ).add(centerUtcOffset);

int centerDayStartMs(DateTime calendarDate) => DateTime.utc(
  calendarDate.year,
  calendarDate.month,
  calendarDate.day,
).subtract(centerUtcOffset).millisecondsSinceEpoch;

class OperationEventRange {
  const OperationEventRange({
    required this.startAtMs,
    required this.endBeforeMs,
  }) : assert(startAtMs < endBeforeMs);
  final int startAtMs, endBeforeMs;
  bool contains(int timestamp) =>
      timestamp >= startAtMs && timestamp < endBeforeMs;
  @override
  bool operator ==(Object other) =>
      other is OperationEventRange &&
      startAtMs == other.startAtMs &&
      endBeforeMs == other.endBeforeMs;
  @override
  int get hashCode => Object.hash(startAtMs, endBeforeMs);
}

/// A complete query means all stored events were read, not that every real-world
/// occurrence was collected. Historical telemetry cannot prove missing events.
class OperationEventBatch {
  const OperationEventBatch({required this.events, required this.isComplete});
  final List<OperationEvent> events;
  final bool isComplete;
}

class OperationIncident {
  const OperationIncident({required this.event, this.recovery});
  final OperationEvent event;
  final OperationEvent? recovery;
  Duration? get duration => recovery == null
      ? null
      : Duration(milliseconds: recovery!.occurredAtMs - event.occurredAtMs);
  String get recoveryLabel => recovery != null ? '복구 확인' : '복구 기록 없음';
  String get impactLabel => event.playbackImpact == 'interrupted'
      ? '재생 중단 확인'
      : event.playbackImpact == 'none'
      ? '재생 영향 없음 확인'
      : '재생 영향 확인 불가';
}

List<OperationEvent> uniqueOperationEvents(Iterable<OperationEvent> events) {
  final unique = <String, OperationEvent>{};
  for (final event in events) {
    unique.putIfAbsent(event.eventId ?? event.id, () => event);
  }
  return unique.values.toList()..sort((a, b) {
    final time = b.occurredAtMs.compareTo(a.occurredAtMs);
    return time == 0 ? a.id.compareTo(b.id) : time;
  });
}

List<OperationIncident> buildOperationIncidents(
  Iterable<OperationEvent> events,
) {
  final ordered = uniqueOperationEvents(events).reversed.toList();
  return [
    for (final event in ordered)
      if (event.type == 'device_offline' ||
          event.type.endsWith('_failed') ||
          event.type == 'playback_interrupted')
        OperationIncident(event: event, recovery: _recoveryFor(event, ordered)),
  ];
}

OperationEvent? _recoveryFor(
  OperationEvent event,
  List<OperationEvent> events,
) {
  for (final candidate in events) {
    if (candidate.occurredAtMs < event.occurredAtMs ||
        candidate.deviceId != event.deviceId) {
      continue;
    }
    final expectedRecovery = switch (event.type) {
      'device_offline' => 'device_online',
      'connection_failed' => 'connection_recovered',
      'playback_interrupted' => 'playback_restored',
      _ => null,
    };
    if (expectedRecovery == null || candidate.type != expectedRecovery) {
      continue;
    }
    if (event.type == 'playback_interrupted' &&
        candidate.sessionId != event.sessionId) {
      continue;
    }
    // Temporal proximity, matching workout names and shared device IDs alone
    // never prove recovery. Only an explicit incident/event reference does.
    if (candidate.recoveryOfEventId == (event.eventId ?? event.id) ||
        (event.incidentId != null &&
            candidate.incidentId == event.incidentId)) {
      return candidate;
    }
  }
  return null;
}

class OperationsRangeReport {
  const OperationsRangeReport({
    required this.playbackCount,
    required this.completedCount,
    required this.disconnectCount,
    required this.interruptionCount,
    required this.scheduledPlaybackCount,
    required this.onTimePlaybackCount,
    required this.onlineDurationByDevice,
    required this.hasUnknownConnectionTime,
    required this.hasLegacyEvents,
    required this.incidents,
  });
  final int playbackCount, completedCount, disconnectCount, interruptionCount;
  final int scheduledPlaybackCount, onTimePlaybackCount;
  final Map<String, Duration> onlineDurationByDevice;
  final bool hasUnknownConnectionTime, hasLegacyEvents;
  final List<OperationIncident> incidents;
  Duration get onlineDuration => Duration(
    milliseconds: onlineDurationByDevice.values.fold(
      0,
      (sum, value) => sum + value.inMilliseconds,
    ),
  );
}
