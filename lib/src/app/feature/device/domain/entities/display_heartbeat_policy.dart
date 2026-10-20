/// Presence freshness only; never used to advance or synchronize a class.
class DisplayHeartbeatPolicy {
  const DisplayHeartbeatPolicy({
    required this.revision,
    required this.heartbeatIntervalSeconds,
    required this.noResponseTimeoutSeconds,
  });

  static const legacy = DisplayHeartbeatPolicy(
    revision: 0,
    heartbeatIntervalSeconds: 20,
    noResponseTimeoutSeconds: 75,
  );
  static const target = DisplayHeartbeatPolicy(
    revision: 0,
    heartbeatIntervalSeconds: 60,
    noResponseTimeoutSeconds: 180,
  );

  final int revision, heartbeatIntervalSeconds, noResponseTimeoutSeconds;
  Duration get interval => Duration(seconds: heartbeatIntervalSeconds);
  int get timeoutMs => noResponseTimeoutSeconds * 1000;

  factory DisplayHeartbeatPolicy.fromJson(Map<Object?, Object?> value) {
    final revision = value['revision'];
    final interval = value['heartbeatIntervalSeconds'];
    final timeout = value['noResponseTimeoutSeconds'];
    if (value['schemaVersion'] != 1 ||
        revision is! int ||
        revision < 0 ||
        interval is! int ||
        interval < 10 ||
        interval > 120 ||
        timeout is! int ||
        timeout < interval * 3 ||
        timeout > 600) {
      throw const FormatException('Invalid display heartbeat policy');
    }
    return DisplayHeartbeatPolicy(
      revision: revision,
      heartbeatIntervalSeconds: interval,
      noResponseTimeoutSeconds: timeout,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'revision': revision,
    'heartbeatIntervalSeconds': heartbeatIntervalSeconds,
    'noResponseTimeoutSeconds': noResponseTimeoutSeconds,
  };

  static DisplayHeartbeatPolicy fromDevice(
    Object? value, {
    required String? connectionId,
  }) {
    // A policy from a previous transport cannot describe this connection.
    if (connectionId == null ||
        value is! Map ||
        value['connectionId'] != connectionId) {
      return legacy;
    }
    try {
      return DisplayHeartbeatPolicy.fromJson(value);
    } on FormatException {
      return legacy;
    }
  }
}

/// Select at standby boundaries. A class, including its paused state, keeps the
/// choice made before it started even if a fetch or heartbeat finishes later.
class DisplayHeartbeatSelection {
  DisplayHeartbeatSelection(this.applied);
  DisplayHeartbeatPolicy applied;
  DisplayHeartbeatPolicy? pending, _sending, _locked;
  bool _standby = true;

  void setStandby(bool value) {
    if (_standby && !value) _locked = _sending ?? applied;
    if (value) _locked = null;
    _standby = value;
  }

  DisplayHeartbeatPolicy begin() {
    final next = pending;
    // A fresh install/offline cache may lag the policy already on this connection.
    return _sending =
        _standby && next != null && next.revision >= applied.revision
        ? next
        : _standby
        ? applied
        : _locked ?? applied;
  }

  void accepted(DisplayHeartbeatPolicy value) {
    applied = value;
    _sending = null;
  }

  void failed() => _sending = null;
}
