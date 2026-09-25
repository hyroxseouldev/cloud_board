import 'dart:async';

import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_countdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final workout =
    Workout.empty(
      'skip',
      const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
    ).copyWith(
      countdownSeconds: 30,
      modules: [WorkoutModule.empty('first').copyWith(workSeconds: 60)],
    );

void main() {
  testWidgets(
    'skip starts full first interval once and cancels preparation deadline',
    (tester) async {
      var now = DateTime(2026, 9, 25);
      final audio = _Audio();
      final container = ProviderContainer(
        overrides: [
          serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
          playerClockProvider.overrideWith(
            (ref) =>
                () => now,
          ),
          beepPlayerProvider.overrideWith((ref) => audio),
        ],
      );
      final provider = playerControllerProvider(workout);
      container.listen(provider, (_, _) {});
      await tester.pump();
      now = now.add(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 100));
      final controller = container.read(provider.notifier);
      await controller.skipCountdown();
      await controller.skipCountdown();
      expect(container.read(provider).countdownMs, 0);
      expect(container.read(provider).index, 0);
      expect(container.read(provider).remainingMs, 60000);
      expect(audio.starts, 1);
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(container.read(provider).remainingMs, 59000);
      expect(audio.starts, 1);
      container.dispose();
    },
  );

  for (final success in [true, false]) {
    testWidgets(
      'remote skip dispatches once and restores countdown on failure=$success',
      (tester) async {
        final now = DateTime(2026, 9, 25);
        final session =
            PlaybackSessionModel.fromWorkout(
              id: 'session',
              ownerId: 'u',
              zoneId: 'main',
              targetDeviceIds: ['tv'],
              workout: workout,
              stepIndex: 0,
              durationMs: 60000,
              deviceId: 'controller',
            ).toEntity().copyWith(
              anchorServerMs: now.millisecondsSinceEpoch,
              startDelayMs: 30000,
            );
        final commands = _Commands();
        final container = ProviderContainer(
          overrides: [
            activePlaybackSessionProvider.overrideWith(
              (ref) => Stream.value(session),
            ),
            playbackConnectionProvider.overrideWith(
              (ref) => Stream.value(true),
            ),
            serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
            playerClockProvider.overrideWith(
              (ref) =>
                  () => now,
            ),
            beepPlayerProvider.overrideWith((ref) => _Audio()),
            playbackActionControllerProvider.overrideWith(() => commands),
          ],
        );
        final provider = playerControllerProvider(
          workout,
          sessionId: 'session',
        );
        final display = playerControllerProvider(
          workout,
          sessionId: 'session',
          canControl: false,
        );
        container.listen(provider, (_, _) {});
        container.listen(display, (_, _) {});
        container.listen(playbackConnectionProvider, (_, _) {});
        await tester.pump();
        await container.read(display.notifier).skipCountdown();
        expect(commands.calls, isEmpty);
        final controller = container.read(provider.notifier);
        final pending = controller.skipCountdown();
        await controller.skipCountdown();
        expect(commands.calls, [(0, 60000)]);
        commands.result.complete(success);
        await pending;
        expect(container.read(provider).countdownMs, success ? 0 : 30000);
        expect(container.read(provider).index, 0);
        expect(container.read(provider).remainingMs, 60000);
        container.dispose();
      },
    );
  }

  testWidgets('skip action is optional and supports disabled state', (
    tester,
  ) async {
    var calls = 0;
    Future<void> render(VoidCallback? skip, {bool enabled = true}) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WorkoutCountdown(
                workout: workout,
                seconds: 3,
                onSkip: skip,
                skipEnabled: enabled,
              ),
            ),
          ),
        );
    final button = find.byKey(const ValueKey('skip-countdown'));
    await render(null);
    expect(button, findsNothing);
    await render(() => calls++);
    await tester.tap(button);
    expect(calls, 1);
    await render(() => calls++, enabled: false);
    await tester.tap(button);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });
}

class _Commands extends PlaybackActionController {
  final calls = <(int, int)>[];
  final result = Completer<bool>();
  @override
  AsyncValue<String?> build() => const AsyncData(null);
  @override
  Future<bool> seek({required int stepIndex, required int durationMs}) {
    calls.add((stepIndex, durationMs));
    return result.future;
  }
}

class _Audio implements BeepPlayer {
  int starts = 0;
  @override
  Future<void> play([
    WorkoutSound sound = WorkoutSound.classicBeep,
    double volume = 1,
  ]) async {
    starts++;
  }

  @override
  Future<void> playCountdown(WorkoutSound sound, double volume) async {}
  @override
  Future<void> dispose() async {}
}
