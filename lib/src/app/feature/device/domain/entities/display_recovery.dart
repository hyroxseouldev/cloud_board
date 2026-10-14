enum DisplayRecoveryStatus {
  requested,
  received,
  recovering,
  succeeded,
  failed,
  expired,
}

class DisplayRecoveryRequest {
  const DisplayRecoveryRequest({
    required this.operationId,
    required this.deviceId,
    required this.status,
    required this.requestedAtMs,
    required this.expiresAtMs,
    this.errorCode,
    this.errorId,
    this.verifiedAtMs,
    this.sessionId,
    this.revision,
  });
  final String operationId, deviceId;
  final DisplayRecoveryStatus status;
  final int requestedAtMs, expiresAtMs;
  final String? errorCode, errorId, sessionId;
  final int? verifiedAtMs, revision;
  bool get pending => switch (status) {
    DisplayRecoveryStatus.requested ||
    DisplayRecoveryStatus.received ||
    DisplayRecoveryStatus.recovering => true,
    _ => false,
  };
  bool get terminal => !pending;
  bool expired(int nowMs) => nowMs >= expiresAtMs;
  DisplayRecoveryRequest expire() => DisplayRecoveryRequest(
    operationId: operationId,
    deviceId: deviceId,
    status: DisplayRecoveryStatus.expired,
    requestedAtMs: requestedAtMs,
    expiresAtMs: expiresAtMs,
    errorCode: 'recovery_timeout',
    errorId: errorId,
  );
}
