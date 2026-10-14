import 'package:cloud_board/src/app/feature/device/domain/usecases/prepare_display_media.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/retry_display_preparation.dart';

enum DisplayPreparationOutcome { ready, failed, cancelled }

/// Media completion, accepted response and current-connection heartbeat are
/// separate stages. Retrying a receipt never repeats native media preparation.
Future<DisplayPreparationOutcome> completeDisplayPreparation({
  required Future<DisplayMediaPreparationResult?> Function() prepare,
  required Future<void> Function(DisplayMediaPreparationResult, bool ready)
  respond,
  required Future<void> Function() heartbeat,
  required bool Function() cancelled,
  required void Function(String stage, String? code, int attempt) health,
  Future<void> Function(Duration)? delay,
}) async {
  DisplayMediaPreparationResult? media;
  var permissionStopped = false;
  void failed(String stage, String code, int attempt) {
    permissionStopped =
        code == 'permission-denied' || code == 'unauthenticated';
    health(stage, code, attempt);
  }

  final prepared = await retryDisplayPreparation<bool>(
    cancelled: cancelled,
    delay: delay,
    onFailure: (code, attempt) => failed('media', code, attempt),
    operation: () async {
      media = await prepare();
      if (media == null) return false;
      if (!media!.ready) throw media!.failureCode ?? 'unexpected';
      return true;
    },
  );
  if (cancelled()) return DisplayPreparationOutcome.cancelled;
  if (permissionStopped) return DisplayPreparationOutcome.failed;
  if (media == null) return DisplayPreparationOutcome.failed;
  if (prepared == true) health('media', null, 1);
  final saved = await retryDisplayPreparation<bool>(
    cancelled: cancelled,
    delay: delay,
    onFailure: (code, attempt) => failed('response_write', code, attempt),
    operation: () async {
      await respond(media!, prepared == true);
      return true;
    },
  );
  if (cancelled()) return DisplayPreparationOutcome.cancelled;
  if (saved != true || permissionStopped) {
    return DisplayPreparationOutcome.failed;
  }
  health('response_write', null, 1);
  if (prepared != true) return DisplayPreparationOutcome.failed;
  final ready = await retryDisplayPreparation<bool>(
    cancelled: cancelled,
    delay: delay,
    onFailure: (code, attempt) => failed('heartbeat', code, attempt),
    operation: () async {
      await heartbeat();
      return true;
    },
  );
  if (cancelled()) return DisplayPreparationOutcome.cancelled;
  if (ready != true) return DisplayPreparationOutcome.failed;
  health('heartbeat', null, 1);
  return DisplayPreparationOutcome.ready;
}
