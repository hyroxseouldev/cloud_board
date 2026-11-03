/// A transport reset is a last resort after two failed heartbeat cycles.
/// Keep this budget across connection changes; reset it only on a good beat.
class HeartbeatRecoveryBudget {
  HeartbeatRecoveryBudget({DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final DateTime Function() clock;
  int _failures = 0, _attempts = 0;
  DateTime? _lastAttempt;

  void succeeded() {
    _failures = 0;
    _attempts = 0;
  }

  bool failed({required bool standby, required bool permissionStopped}) {
    _failures++;
    final now = clock();
    if (!standby ||
        permissionStopped ||
        _failures < 2 ||
        _attempts >= 3 ||
        (_lastAttempt != null &&
            now.difference(_lastAttempt!) < const Duration(minutes: 2))) {
      return false;
    }
    _attempts++;
    _lastAttempt = now;
    return true;
  }
}
