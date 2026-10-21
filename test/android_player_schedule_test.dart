import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/core/services/tv_playback_lifecycle.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/display_playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'android_workout_cues_test.dart' show FakeAudio;
import 'playback_audio_cues_test.dart' show audioSession;

class LocalSession extends DisplayPlaybackSession {
  LocalSession(this.initial);
  final PlaybackSession initial;
  @override
  PlaybackSession? build() => initial;
  void set(PlaybackSession? value) => state = value;
}

void main() {
  testWidgets(
    'real player cancels on pause/revision/visibility/scope and uses latest remote volume',
    (tester) async {
      final initial = audioSession();
      final session = LocalSession(initial);
      final audio = FakeAudio();
      var now = 10000;
      final container = ProviderContainer(
        overrides: [
          displayPlaybackSessionProvider.overrideWith(() => session),
          androidCueAudioProvider.overrideWithValue(audio),
          serverTimeOffsetProvider.overrideWith((_) => Stream.value(0)),
          playerClockProvider.overrideWith(
            (_) =>
                () => DateTime.fromMillisecondsSinceEpoch(now),
          ),
        ],
      );
      final provider = playerControllerProvider(
        initial.workout,
        sessionId: initial.id,
        canControl: false,
      );
      final sub = container.listen(provider, (_, _) {});
      await tester.pump();
      await tester.pump();
      expect(audio.cues.any((c) => c['localDeadlineMs'] == 13000), isTrue);
      final initialImmediateCount = audio.calls
          .where((c) => c.startsWith('immediate'))
          .length;
      final beforePause = audio.calls
          .where((c) => c.startsWith('cancel:'))
          .length;
      session.set(initial.copyWith(status: PlaybackStatus.paused, revision: 2));
      await tester.pump();
      expect(
        audio.calls.where((c) => c.startsWith('cancel:')).length,
        greaterThan(beforePause),
      );
      now = 12000;
      session.set(
        initial.copyWith(
          revision: 3,
          anchorServerMs: 12000,
          remainingMs: 3000,
          startDelayMs: 0,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        audio.cues.every((c) => (c['id'] as String).contains('/3/')),
        isTrue,
      );
      expect(audio.cues.any((c) => c['localDeadlineMs'] == 15000), isTrue);
      final activeCount = audio.calls
          .where((c) => c.startsWith('activate'))
          .length;
      session.set(
        initial.copyWith(
          revision: 4,
          workout: initial.workout.copyWith(soundVolume: 0),
        ),
      );
      await tester.pump();
      expect(
        audio.calls.where((c) => c.startsWith('activate')).length,
        activeCount,
      );
      expect(audio.calls.last, startsWith('cancel:'));
      session.set(initial.copyWith(revision: 5, anchorServerMs: 12000));
      await tester.pump();
      await tester.pump();
      container.read(tvPlaybackVisibleProvider.notifier).setVisible(false);
      expect(audio.calls.last, startsWith('cancel:'));
      now = 16000;
      container.read(tvPlaybackVisibleProvider.notifier).setVisible(true);
      await tester.pump();
      await tester.pump();
      expect(
        audio.cues.every((c) => (c['localDeadlineMs'] as int) > now),
        isTrue,
      );
      expect(
        audio.calls.where((c) => c.startsWith('immediate')).length,
        initialImmediateCount,
      );
      session.set(null);
      await tester.pump();
      expect(audio.calls.last, startsWith('cancel:'));
      sub.close();
      container.dispose();
      await tester.pump();
    },
  );
}
