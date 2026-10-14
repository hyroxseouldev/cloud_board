import 'package:cloud_board/src/app/feature/device/domain/entities/display_recovery.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/display_recovery_actions.dart';

/// Success is reported only after local fresh-stream recovery. The server then
/// independently verifies that the submitted session/revision is still current.
Future<void> executeDisplayRecovery({
  required DisplayRecoveryRequest request,
  required DisplayRecoveryActions actions,
  required bool Function() cancelled,
  required int Function() now,
  required Future<bool> Function() recover,
  required ({String? sessionId, int? revision}) Function() currentSession,
}) async {
  bool valid() => !cancelled() && !request.expired(now());
  if (!valid() || request.terminal) return;
  try {
    if (request.status == DisplayRecoveryStatus.requested) {
      await actions.report(request, DisplayRecoveryStatus.received);
    }
    if (!valid()) return;
    await actions.report(request, DisplayRecoveryStatus.recovering);
    if (!valid()) return;
    final restored = await recover();
    if (!valid()) return;
    if (!restored) {
      await actions.report(
        request,
        DisplayRecoveryStatus.failed,
        errorCode: 'subscription_recovery_failed',
      );
      return;
    }
    final session = currentSession();
    await actions.report(
      request,
      DisplayRecoveryStatus.succeeded,
      sessionId: session.sessionId,
      revision: session.revision,
    );
  } catch (_) {
    if (!valid()) return;
    try {
      await actions.report(
        request,
        DisplayRecoveryStatus.failed,
        errorCode: 'recovery_verification_failed',
      );
    } catch (_) {
      // A disconnected TV cannot manufacture a successful acknowledgement.
      // The manager expires the request using the server deadline.
    }
  }
}
