import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Presentation only. These stages never authorize or repeat an operation.
class PlaybackProgress extends Notifier<String?> {
  @override
  String? build() => null;
  void show(String? label) => state = label;
}

final playbackStartProgressProvider =
    NotifierProvider<PlaybackProgress, String?>(PlaybackProgress.new);
final playbackRecoveryProgressProvider =
    NotifierProvider<PlaybackProgress, String?>(PlaybackProgress.new);
final workoutMaterialProgressProvider =
    NotifierProvider<PlaybackProgress, String?>(PlaybackProgress.new);
