import 'package:cloud_board/src/app/feature/device/domain/entities/display_preferences.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_heartbeat_policy.dart';

import 'dart:math';

class DisplayPreparationHealth {
  const DisplayPreparationHealth({
    this.stage = '',
    this.code = '',
    this.attempt = 0,
    this.checkedAtMs = 0,
    this.requestId,
  });
  final String stage, code;
  final int attempt, checkedAtMs;
  final String? requestId;
}

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
    this.pairingCode = '',
    this.identificationId,
    this.identificationExpiresAtMs = 0,
    this.identificationAck,
    this.displayState = 'auto',
    this.preferences = const DisplayPreferences(),
    this.lastCommandAtMs = 0,
    this.onlineSinceMs = 0,
    this.appVersion = '',
    this.appBuild = '',
    this.appPlatform = '',
    this.playbackProtocol = 1,
    this.preparationProtocol = 0,
    this.recoveryProtocol = 0,
    this.connectionId,
    this.verifiedConnectionId,
    this.verifiedAtMs = 0,
    this.readyAtMs = 0,
    this.preparationHealth = const DisplayPreparationHealth(),
    this.heartbeatPolicy = DisplayHeartbeatPolicy.legacy,
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
  final String pairingCode;
  final String? identificationId;
  final int identificationExpiresAtMs;
  final String? identificationAck;
  final String displayState;
  final DisplayPreferences preferences;
  final int lastCommandAtMs;
  final int onlineSinceMs;
  final String appVersion, appBuild, appPlatform;
  final int playbackProtocol, preparationProtocol, recoveryProtocol;
  final String? connectionId, verifiedConnectionId;
  final int verifiedAtMs, readyAtMs;
  final DisplayPreparationHealth preparationHealth;
  final DisplayHeartbeatPolicy heartbeatPolicy;
  bool connectionAuthenticated(int nowMs) =>
      recentlySeen(nowMs) &&
      connectionId != null &&
      connectionId == verifiedConnectionId &&
      verifiedAtMs > 0 &&
      verifiedAtMs <= nowMs + 5000;
  bool playbackReady(int nowMs) =>
      preparationHealth.code.isEmpty &&
      connectionAuthenticated(nowMs) &&
      readyAtMs >= verifiedAtMs &&
      readyAtMs <= nowMs + 5000;
  bool recentlySeen(int nowMs) =>
      online &&
      lastSeenAtMs > 0 &&
      nowMs - lastSeenAtMs < heartbeatPolicy.timeoutMs &&
      lastSeenAtMs <= nowMs + 5000;
  String get installedVersion => appVersion.isEmpty || appBuild.isEmpty
      ? '설치 버전 확인 불가'
      : '$appPlatform $appVersion+$appBuild';
}

String generatePairingCode([Random? random]) {
  final value = (random ?? Random.secure()).nextInt(1000000);
  return value.toString().padLeft(6, '0');
}
