import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';

Workout workout(int delay, {bool beep = true}) =>
    Workout.empty(
      'w',
      const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
    ).copyWith(
      countdownSeconds: delay,
      modules: [
        WorkoutModule.empty('m')
            .copyWith(workSeconds: 10, restSeconds: 5, sets: 2, beep: beep),
      ],
    );

void main() {
  for (final delay in [0, 1, 2, 3, 10, 60]) {
    testWidgets(
      'preparation $delay seconds only sounds at 3/2/1 and starts once',
      (tester) async {
        var now = DateTime(2026, 9, 22);
        final audio = _Audio();
        final container = ProviderContainer(
          overrides: [
            serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
            beepPlayerProvider.overrideWith((ref) => audio),
            playerClockProvider.overrideWith(
              (ref) =>
                  () => now,
            ),
          ],
        );
        final p = playerControllerProvider(workout(delay));
        container.listen(p, (_, _) {});
        await tester.pump();
        expect(audio.ticks.length, delay > 0 && delay <= 3 ? 1 : 0);
        for (var second = delay - 1; second >= 0; second--) {
          now = now.add(const Duration(seconds: 1));
          final count = audio.ticks.length;
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            audio.ticks.length - count,
            second >= 1 && second <= 3 ? 1 : 0,
            reason: 'remaining $second',
          );
        }
        expect(audio.ticks.length, delay.clamp(0, 3));
        expect(audio.starts, [WorkoutSound.videoBeep]);
        // The first work/rest boundary keeps the three countdowns separate from start.
        for (var i = 0; i < 10; i++) {
          now = now.add(const Duration(seconds: 1));
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(audio.ticks.length, delay.clamp(0, 3) + 3);
        expect(audio.starts, hasLength(2));
        expect(container.read(p).steps[container.read(p).index].isRest, isTrue);
        container.dispose();
      },
    );
  }

  testWidgets(
    'display rebuild during same preparation second does not repeat cue',
    (tester) async {
      var now = DateTime(2026, 9, 22);
      final offset = StreamController<int>();
      final audio = _Audio();
      final w = workout(60);
      final session =
          PlaybackSessionModel.fromWorkout(
            id: 's',
            ownerId: 'u',
            zoneId: 'main',
            targetDeviceIds: ['tv'],
            workout: w,
            stepIndex: 0,
            durationMs: 10000,
            deviceId: 'c',
          ).toEntity().copyWith(
            anchorServerMs: now.millisecondsSinceEpoch,
            startDelayMs: 60000,
          );
      final container = ProviderContainer(
        overrides: [
          serverTimeOffsetProvider.overrideWith((ref) => offset.stream),
          activePlaybackSessionProvider.overrideWith(
            (ref) => Stream.value(session),
          ),
          beepPlayerProvider.overrideWith((ref) => audio),
          playerClockProvider.overrideWith(
            (ref) =>
                () => now,
          ),
        ],
      );
      final p = playerControllerProvider(w, sessionId: 's', canControl: false);
      container.listen(p, (_, _) {});
      await tester.pump();
      now = now.add(const Duration(seconds: 57));
      await tester.pump(const Duration(milliseconds: 100));
      expect(audio.ticks, hasLength(1));
      offset.add(1);
      await tester.pump();
      expect(audio.ticks, hasLength(1));
      // Delayed tick: do not queue missed 2-second and 1-second cues.
      now = now.add(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 100));
      expect(audio.ticks, hasLength(1));
      expect(audio.starts, hasLength(1));
      container.dispose();
      unawaited(offset.close());
    },
  );

  testWidgets('late preparation tick skips expired interval start', (
    tester,
  ) async {
    var now = DateTime(2026, 9, 22);
    final audio = _Audio();
    final container = ProviderContainer(
      overrides: [
        serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
        beepPlayerProvider.overrideWith((ref) => audio),
        playerClockProvider.overrideWith(
          (ref) =>
              () => now,
        ),
      ],
    );
    final p = playerControllerProvider(
      workout(60).copyWith(
        workStartSound: WorkoutSound.classicBeep,
        restStartSound: WorkoutSound.gentleBeep,
      ),
    );
    container.listen(p, (_, _) {});
    await tester.pump();
    now = now.add(const Duration(seconds: 71));
    await tester.pump(const Duration(milliseconds: 100));
    expect(audio.ticks, isEmpty);
    expect(audio.starts, [WorkoutSound.gentleBeep]);
    expect(container.read(p).steps[container.read(p).index].isRest, isTrue);
    container.dispose();
  });

  testWidgets(
    'disabled module remains silent during preparation and transition',
    (tester) async {
      var now = DateTime(2026, 9, 22);
      final audio = _Audio();
      final container = ProviderContainer(
        overrides: [
          serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
          beepPlayerProvider.overrideWith((ref) => audio),
          playerClockProvider.overrideWith(
            (ref) =>
                () => now,
          ),
        ],
      );
      container.listen(
        playerControllerProvider(workout(3, beep: false)),
        (_, _) {},
      );
      await tester.pump();
      for (var i = 0; i < 13; i++) {
        now = now.add(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(audio.ticks, isEmpty);
      expect(audio.starts, isEmpty);
      container.dispose();
    },
  );
}

class _Audio implements BeepPlayer {
  final ticks = <WorkoutSound>[];
  final starts = <WorkoutSound>[];
  @override
  Future<void> play([
    WorkoutSound sound = WorkoutSound.classicBeep,
    double volume = 1,
  ]) async => starts.add(sound);
  @override
  Future<void> playCountdown(WorkoutSound sound, double volume) async =>
      ticks.add(sound);
  @override
  Future<void> dispose() async {}
}
