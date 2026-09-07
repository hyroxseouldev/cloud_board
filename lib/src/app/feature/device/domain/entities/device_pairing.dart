import 'dart:math';

class DevicePairing {
  const DevicePairing({
    required this.code,
    required this.deviceId,
    required this.expiresAtMs,
  });

  final String code;
  final String deviceId;
  final int expiresAtMs;

  bool get isExpired => DateTime.now().millisecondsSinceEpoch >= expiresAtMs;
}

class DisplayDevice {
  const DisplayDevice({
    required this.id,
    required this.name,
    required this.zoneId,
    required this.zoneName,
    required this.online,
    required this.lastSeenAtMs,
    required this.currentSessionId,
    required this.acknowledgedRevision,
    required this.paired,
    this.displayState = 'auto',
    this.lastCommandAtMs = 0,
    this.onlineSinceMs = 0,
  });

  final String id;
  final String name;
  final String zoneId;
  final String zoneName;
  final bool online;
  final int lastSeenAtMs;
  final String? currentSessionId;
  final int acknowledgedRevision;
  final bool paired;
  final String displayState;
  final int lastCommandAtMs;
  final int onlineSinceMs;
}

String generatePairingCode([Random? random]) {
  final value = (random ?? Random.secure()).nextInt(1000000);
  return value.toString().padLeft(6, '0');
}
