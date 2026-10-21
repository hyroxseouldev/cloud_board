import 'package:cloud_board/src/app/core/observability/operation_telemetry.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';

typedef DisplayMediaPreparationResult = ({
  bool ready,
  int imageCount,
  bool audioReady,
  String? failureCode,
});

/// Prepared is emitted only after every image and native audio source succeeds.
/// Cancellation (including a new class) must never publish a stale success.
Future<DisplayMediaPreparationResult?> prepareDisplayMedia(
  DisplayPreparation request, {
  required Future<int> Function(List<String>) images,
  required Future<void> Function(List<String>) audio,
  required bool Function() cancelled,
  void Function(String stage, Object error, StackTrace stack)? onError,
}) async {
  if (cancelled()) return null;
  var count = 0;
  var audioReady = false;
  String? failureCode;
  Future<void> prepare(String stage, Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error, stack) {
      failureCode ??= operationFailureCode(error);
      if (!cancelled()) onError?.call(stage, error, stack);
    }
  }

  // Both independent branches start now. Wait for both bounded operations before
  // returning so a failed image branch cannot race audio disposal or a retry.
  await Future.wait([
    prepare('images', () async {
      count = await images(request.images).timeout(const Duration(seconds: 30));
      if (count != request.images.length) throw StateError('Incomplete images');
    }),
    prepare('audio', () async {
      await audio(request.sounds).timeout(const Duration(seconds: 12));
      audioReady = true;
    }),
  ]);
  if (cancelled()) return null;
  return (
    ready: failureCode == null,
    imageCount: count,
    audioReady: audioReady,
    failureCode: failureCode,
  );
}
