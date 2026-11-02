/// Strict, content-free dimensions shared with the telemetry server validator.
/// Request IDs are ephemeral correlation keys, never workout/device/user data.
Map<String, Object> safePreparationTrace(Map<String, Object?> value) {
  const counters = {
    'targetCount': 32,
    'targetIndex': 31,
    'pendingWrites': 1000,
    'connectionChanges': 1000000,
    'observerAgeMs': 2592000000,
    'connectionAgeMs': 2592000000,
    'lifecycleAgeMs': 2592000000,
    'writeElapsedMs': 86400000,
    'mediaElapsedMs': 86400000,
    'responseElapsedMs': 86400000,
    'heartbeatElapsedMs': 86400000,
    'httpStatus': 599,
  };
  const enums = {
    'connection': {'unknown', 'connected', 'disconnected', 'error'},
    'lifecycle': {
      'unknown',
      'resumed',
      'inactive',
      'hidden',
      'paused',
      'detached',
    },
    'requestMatch': {'same', 'different', 'absent'},
    'probeStage': {'auth', 'http'},
    'stage': {'request', 'images', 'audio', 'response', 'heartbeat'},
    'transportCode': {
      'permission-denied',
      'unauthenticated',
      'unavailable',
      'deadline-exceeded',
      'resource-exhausted',
      'aborted',
      'not-found',
      'failed-precondition',
      'timeout',
      'unexpected',
    },
  };
  return {
    for (final entry in value.entries)
      if ((counters.containsKey(entry.key) &&
              entry.value is int &&
              (entry.value as int) >= 0 &&
              (entry.value as int) <= counters[entry.key]!) ||
          (enums[entry.key]?.contains(entry.value) ?? false) ||
          (entry.key == 'superseded' && entry.value is bool) ||
          (entry.key == 'requestId' &&
              entry.value is String &&
              RegExp(r'^prepare-[a-z0-9-]{1,80}$')
                  .hasMatch(entry.value as String)) ||
          (entry.key == 'parentOperationId' &&
              entry.value is String &&
              RegExp(r'^[a-f0-9]{32}$').hasMatch(entry.value as String)))
        entry.key: entry.value!,
  };
}
