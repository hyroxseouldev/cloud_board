import 'dart:async';

import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_control_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final _workout =
    Workout.empty(
      'w',
      const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
    ).copyWith(
      countdownSeconds: 0,
      modules: [
        WorkoutModule.empty('a')
            .copyWith(workSeconds: 10, restSeconds: 5, sets: 2),
        WorkoutModule.empty('b').copyWith(workSeconds: 60),
      ],
    );

void main() {
  testWidgets('local seek maps work/rest/set boundaries and clamps endpoints', (
    tester,
  ) async {
    final audio = _Audio();
    final container = ProviderContainer(
      overrides: [
        serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
        beepPlayerProvider.overrideWith((ref) => audio),
      ],
    );
    final provider = playerControllerProvider(_workout);
    container.listen(provider, (_, _) {});
    await tester.pump();
    final controller = container.read(provider.notifier);
    await controller.pause();
    audio.sounds.clear();
    for (final target in [
      (module: 0, elapsed: -1000, index: 0, remaining: 10000),
      (module: 0, elapsed: 4000, index: 0, remaining: 6000),
      (module: 0, elapsed: 10000, index: 1, remaining: 5000),
      (module: 0, elapsed: 12000, index: 1, remaining: 3000),
      (module: 0, elapsed: 15000, index: 2, remaining: 10000),
      (module: 0, elapsed: 18000, index: 2, remaining: 7000),
      (module: 0, elapsed: 25000, index: 2, remaining: 1000),
      (module: 1, elapsed: 30000, index: 3, remaining: 30000),
      (module: 1, elapsed: 999999, index: 3, remaining: 1000),
    ]) {
      await controller.seekModulePosition(target.module, target.elapsed);
      await tester.pump(const Duration(milliseconds: 200));
      final state = container.read(provider);
      expect(state.index, target.index);
      expect(state.remainingMs, target.remaining);
      expect(state.isPaused, isTrue);
    }
    final before = container.read(provider);
    await controller.seekModulePosition(999, 0);
    expect(container.read(provider), before);
    expect(audio.sounds, isEmpty);
    container.dispose();
  });

  for (final paused in [true, false]) {
    testWidgets(
      'remote partial seek preserves paused=$paused and rolls back failure',
      (tester) async {
        final now = DateTime(2026, 9, 18);
        final active =
            PlaybackSessionModel.fromWorkout(
              id: 's',
              ownerId: 'u',
              zoneId: 'main',
              targetDeviceIds: ['tv'],
              workout: _workout,
              stepIndex: 0,
              durationMs: 10000,
              deviceId: 'c',
            ).toEntity().copyWith(
              status: paused ? PlaybackStatus.paused : PlaybackStatus.playing,
              anchorServerMs: now.millisecondsSinceEpoch,
            );
        final commands = _Commands();
        final container = ProviderContainer(
          overrides: [
            activePlaybackSessionProvider.overrideWith(
              (ref) => Stream.value(active),
            ),
            playbackConnectionProvider.overrideWith(
              (ref) => Stream.value(true),
            ),
            serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
            beepPlayerProvider.overrideWith((ref) => _Audio()),
            playbackActionControllerProvider.overrideWith(() => commands),
            playerClockProvider.overrideWith(
              (ref) =>
                  () => now,
            ),
          ],
        );
        final provider = playerControllerProvider(_workout, sessionId: 's');
        container.listen(provider, (_, _) {});
        container.listen(playbackConnectionProvider, (_, _) {});
        await tester.pump();
        final controller = container.read(provider.notifier);
        await controller.seekModulePosition(0, 12000);
        expect(commands.calls, [(index: 1, remaining: 3000)]);
        expect(container.read(provider).index, 1);
        expect(container.read(provider).remainingMs, 3000);
        expect(container.read(provider).isPaused, paused);
        commands.success = false;
        await controller.seekModulePosition(1, 45000);
        expect(commands.calls.last, (index: 3, remaining: 15000));
        expect(container.read(provider).index, 0);
        expect(container.read(provider).remainingMs, 10000);
        expect(container.read(provider).isPaused, paused);
        container.dispose();
      },
    );
  }

  testWidgets(
    'single-slide handle follows drag; release seeks inside slide once',
    (tester) async {
      final calls = <({int module, int elapsed})>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: WorkoutControlTimeline(
                  durations: const [60],
                  currentModule: 0,
                  elapsedMs: 0,
                  onSeek: (module, elapsed) async =>
                      calls.add((module: module, elapsed: elapsed)),
                ),
              ),
            ),
          ),
        ),
      );
      final timeline = find.byKey(const ValueKey('class-timeline'));
      final rect = tester.getRect(timeline);
      final handle = find.descendant(
        of: timeline,
        matching: find.byIcon(Icons.circle),
      );
      final start = tester.getCenter(handle).dx;
      final gesture = await tester.startGesture(
        Offset(rect.left + 3, rect.center.dy),
      );
      await gesture.moveTo(rect.center);
      await tester.pump();
      expect(tester.getCenter(handle).dx, greaterThan(start + 150));
      expect(calls, isEmpty);
      await gesture.up();
      await tester.pump();
      expect(calls, [(module: 0, elapsed: 30000)]);
      await tester.tapAt(
        Offset(rect.left + 3 + (rect.width - 6) * .25, rect.center.dy),
      );
      await tester.pump();
      expect(calls.last, (module: 0, elapsed: 15000));
      final canceled = await tester.startGesture(rect.center);
      await canceled.moveTo(Offset(rect.right - 3, rect.center.dy));
      await canceled.cancel();
      await tester.pump();
      expect(calls, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unequal segment widths map to each slide time rather than total time',
    (tester) async {
      final calls = <({int module, int elapsed})>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: WorkoutControlTimeline(
                  durations: const [1, 100, 1],
                  currentModule: 1,
                  elapsedMs: 0,
                  onSeek: (module, elapsed) async =>
                      calls.add((module: module, elapsed: elapsed)),
                ),
              ),
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.byKey(const ValueKey('class-timeline')));
      await tester.tapAt(rect.center);
      await tester.pump();
      expect(calls.single, (module: 1, elapsed: 50000));
      await tester.tapAt(Offset(rect.right - 1, rect.center.dy));
      await tester.pump();
      expect(calls.last, (module: 2, elapsed: 0));
    },
  );
}

class _Audio implements BeepPlayer {
  final sounds = <WorkoutSound>[];
  @override
  Future<void> play([
    WorkoutSound sound = WorkoutSound.classicBeep,
    double volume = 1,
  ]) async {
    sounds.add(sound);
  }

  @override
  Future<void> dispose() async {}
}

class _Commands extends PlaybackActionController {
  bool success = true;
  final calls = <({int index, int remaining})>[];
  @override
  AsyncValue<String?> build() => const AsyncData(null);
  @override
  Future<bool> seek({required int stepIndex, required int durationMs}) async {
    calls.add((index: stepIndex, remaining: durationMs));
    return success;
  }
}
