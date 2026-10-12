import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';

/// Prepared is emitted only after every image and native audio source succeeds.
/// Cancellation (including a new class) must never publish a stale success.
Future<({bool ready, int imageCount, bool audioReady})?> prepareDisplayMedia(
  DisplayPreparation request, {
  required Future<int> Function(List<String>) images,
  required Future<void> Function(List<String>) audio,
  required bool Function() cancelled,
}) async {
  var count = 0;
  var audioReady = false;
  try {
    if (cancelled()) return null;
    count = await images(request.images).timeout(const Duration(seconds: 30));
    if (cancelled()) return null;
    if (count != request.images.length) throw StateError('Incomplete images');
    await audio(request.sounds).timeout(const Duration(seconds: 12));
    if (cancelled()) return null;
    audioReady = true;
    return (ready: true, imageCount: count, audioReady: true);
  } catch (_) {
    if (cancelled()) return null;
    return (ready: false, imageCount: count, audioReady: audioReady);
  }
}
