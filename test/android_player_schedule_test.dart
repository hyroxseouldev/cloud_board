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
    'manual start survives same-revision rebuild, but is cancelled by next/pause/recovery',
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
      container.read(provider);
      await tester.pump();
      await tester.pump();
      final immediateCount = audio.calls
          .where((c) => c.startsWith('immediate:'))
          .length;
      final next = initial.copyWith(
        revision: 2,
        anchorServerMs: 20000,
        stepIndex: 1,
        remainingMs: 4000,
        startDelayMs: 0,
      );
      now = 20100;
      session.set(next);
      container.read(provider);
      await tester.pump();
      await tester.pump();
      final startId = '${next.ownerId}/${next.id}/2/start/1';
      expect(
        audio.cues.singleWhere((c) => c['id'] == startId)['localDeadlineMs'],
        20750,
      );
      now = 20600;
      session.set(next.copyWith(updatedByDeviceId: 'metadata-update'));
      container.read(provider);
      await tester.pump();
      await tester.pump();
      expect(
        audio.cues.singleWhere((c) => c['id'] == startId)['localDeadlineMs'],
        20750,
      );
      final rapidNext = next.copyWith(
        revision: 3,
        anchorServerMs: 20600,
        stepIndex: 0,
        remainingMs: 5000,
      );
      session.set(rapidNext);
      container.read(provider);
      await tester.pump();
      await tester.pump();
      expect(audio.cues.where((c) => c['id'] == startId), isEmpty);
      expect(audio.cues.any((c) => c['localDeadlineMs'] == 21350), isTrue);
      session.set(
        rapidNext.copyWith(status: PlaybackStatus.paused, revision: 4),
      );
      container.read(provider);
      await tester.pump();
      expect(audio.calls.last, startsWith('cancel:'));
      container.read(tvPlaybackVisibleProvider.notifier).setVisible(false);
      await tester.pump();
      session.set(rapidNext.copyWith(revision: 5));
      container.read(provider);
      await tester.pump();
      container.read(tvPlaybackVisibleProvider.notifier).setVisible(true);
      container.read(provider);
      await tester.pump();
      await tester.pump();
      expect(
        audio.cues.any((c) => (c['id'] as String).contains('/5/start/0')),
        isFalse,
      );
      expect(
        audio.calls.where((c) => c.startsWith('immediate:')).length,
        immediateCount,
      );
      sub.close();
      container.dispose();
      await tester.pump();
    },
  );

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
      container.read(provider);
      await tester.pump();
      await tester.pump();
      expect(audio.cues.any((c) => c['localDeadlineMs'] == 13000), isTrue);
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
      container.read(provider);
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
      container.read(provider);
      await tester.pump();
      await tester.pump();
      final beforeRecoveryImmediateCount = audio.calls
          .where((c) => c.startsWith('immediate'))
          .length;
      container.read(tvPlaybackVisibleProvider.notifier).setVisible(false);
      expect(audio.calls.last, startsWith('cancel:'));
      now = 16000;
      container.read(tvPlaybackVisibleProvider.notifier).setVisible(true);
      container.read(provider);
      await tester.pump();
      await tester.pump();
      expect(
        audio.cues.every((c) => (c['localDeadlineMs'] as int) > now),
        isTrue,
      );
      expect(
        audio.calls.where((c) => c.startsWith('immediate')).length,
        beforeRecoveryImmediateCount,
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
