import 'dart:async';

import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/feature/device/data/datasources/device_pairing_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_command.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_position.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_control_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final workout =
    Workout.empty(
      'w',
      const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
    ).copyWith(
      countdownSeconds: 0,
      modules: [
        WorkoutModule.empty('a')
            .copyWith(workSeconds: 10, restSeconds: 5, sets: 2),
        WorkoutModule.empty('b').copyWith(workSeconds: 20),
      ],
    );
PlaybackSession session() => PlaybackSessionModel.fromWorkout(
  id: 's',
  ownerId: 'u',
  zoneId: 'main',
  targetDeviceIds: ['tv'],
  workout: workout,
  stepIndex: 0,
  durationMs: 10000,
  deviceId: 'c',
).toEntity().copyWith(anchorServerMs: 1000);

void main() {
  test(
    'sleeping controller resolves across work/rest/slides, paused stays frozen',
    () {
      final durations = playbackDurations(workout);
      expect(durations, [10000, 5000, 10000, 20000]);
      final position = playbackPosition(session(), durations, 31000);
      expect(position, (index: 3, remainingMs: 15000, countdownMs: 0));
      expect(
        playbackPosition(session(), durations, 901000).index,
        durations.length,
      );
      expect(
        playbackPosition(
          session().copyWith(
            status: PlaybackStatus.paused,
            stepIndex: 2,
            remainingMs: 6000,
          ),
          durations,
          901000,
        ),
        (index: 2, remainingMs: 6000, countdownMs: 0),
      );
    },
  );

  test(
    'pause checkpoints elapsed interval; navigation preserves paused status',
    () {
      final paused = resolvePlaybackCommand(
        session: session(),
        expectedSessionId: 's',
        expectedRevision: 1,
        serverNowMs: 31000,
        expiresAtMs: 37000,
        status: 'paused',
        remainingMs: 9999,
      );
      expect(paused, (status: 'paused', stepIndex: 3, remainingMs: 15000));
      final seek = resolvePlaybackCommand(
        session: session().copyWith(status: PlaybackStatus.paused),
        expectedSessionId: 's',
        expectedRevision: 1,
        serverNowMs: 31000,
        expiresAtMs: 37000,
        status: null,
        stepIndex: 2,
        remainingMs: 10000,
      );
      expect(seek, (status: 'paused', stepIndex: 2, remainingMs: 10000));
    },
  );

  test('expired, duplicate, conflicting and replaced commands cannot revive a class', () {
    for (final current in [
      session().copyWith(id: 'new'),
      session().copyWith(revision: 2),
      session().copyWith(status: PlaybackStatus.completed),
    ]) {
      expect(
        () => resolvePlaybackCommand(
          session: current,
          expectedSessionId: 's',
          expectedRevision: 1,
          serverNowMs: 5000,
          expiresAtMs: 11000,
          status: null,
          stepIndex: 1,
          remainingMs: 5000,
        ),
        throwsStateError,
      );
    }
    expect(
      () => resolvePlaybackCommand(
        session: session(),
        expectedSessionId: 's',
        expectedRevision: 1,
        serverNowMs: 11000,
        expiresAtMs: 11000,
        status: null,
      ),
      throwsStateError,
    );
    expect(
      () => resolvePlaybackCommand(
        session: session(),
        expectedSessionId: 's',
        expectedRevision: 1,
        serverNowMs: 5000,
        expiresAtMs: 11000,
        status: 'playing',
      ),
      throwsStateError,
    );
  });

  test('pending, failed and revoked pairing stays hidden; paired offline remains registered', () {
    expect(
      isRegisteredDisplay({'online': true, 'pairingCode': '123456'}),
      isFalse,
    );
    expect(isRegisteredDisplay({'paired': false, 'pairedAtMs': 1000}), isFalse);
    expect(isRegisteredDisplay({'paired': true, 'online': false}), isTrue);
    expect(isRegisteredDisplay({'pairedAtMs': 1000, 'online': false}), isTrue);
    expect(isRegisteredDisplay({'pairedAtMs': 0}), isFalse);
  });

  testWidgets('paused local next/previous/slide move never resumes or sounds', (
    tester,
  ) async {
    final audio = _Audio();
    final container = ProviderContainer(
      overrides: [
        serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
        beepPlayerProvider.overrideWith((ref) => audio),
      ],
    );
    final provider = playerControllerProvider(workout);
    final sub = container.listen(provider, (_, _) {});
    await tester.pump();
    final controller = container.read(provider.notifier);
    await controller.pause();
    audio.sounds.clear();
    await controller.next();
    await controller.previous();
    await controller.selectModule(1);
    await tester.pump(const Duration(seconds: 5));
    expect(container.read(provider).isPaused, isTrue);
    expect(container.read(provider).remainingMs, 20000);
    expect(audio.sounds, isEmpty);
    sub.close();
    container.dispose();
  });

  testWidgets(
    'remote controller never emits audio or writes automatic step transitions',
    (tester) async {
      final audio = _Audio();
      final commands = _Commands();
      var now = DateTime.now();
      final active = session().copyWith(
        anchorServerMs: now.millisecondsSinceEpoch,
      );
      final container = ProviderContainer(
        overrides: [
          activePlaybackSessionProvider.overrideWith(
            (ref) => Stream.value(active),
          ),
          serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
          beepPlayerProvider.overrideWith((ref) => audio),
          playbackActionControllerProvider.overrideWith(() => commands),
          playerClockProvider.overrideWith(
            (ref) =>
                () => now,
          ),
        ],
      );
      final provider = playerControllerProvider(workout, sessionId: 's');
      final sub = container.listen(provider, (_, _) {});
      await tester.pump();
      now = now.add(const Duration(seconds: 30));
      await tester.pump(const Duration(milliseconds: 100));
      expect(container.read(provider).index, 3);
      expect(container.read(provider).remainingMs, 15000);
      expect(audio.sounds, isEmpty);
      expect(commands.seeks, 0);
      sub.close();
      container.dispose();
    },
  );

  testWidgets(
    'timeline drag commits once on release and disabled timeline ignores taps',
    (tester) async {
      final calls = <int>[];
      final pending = Completer<void>();
      Widget ui(bool enabled) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: WorkoutControlTimeline(
                durations: const [1, 100, 1],
                currentModule: 1,
                elapsedMs: 1000,
                onSelectModule: enabled
                    ? (i) {
                        calls.add(i);
                        return pending.future;
                      }
                    : null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(ui(true));
      final rect = tester.getRect(find.byKey(const ValueKey('class-timeline')));
      final drag = await tester.startGesture(
        Offset(rect.left + 5, rect.center.dy),
      );
      await drag.moveTo(Offset(rect.right - 5, rect.center.dy));
      await tester.pump();
      expect(calls, isEmpty);
      await drag.up();
      await tester.pump();
      expect(calls, [2]);
      await tester.tapAt(rect.center);
      expect(calls, [2]);
      pending.complete();
      await tester.pump();
      await tester.pumpWidget(ui(false));
      await tester.tapAt(rect.center);
      expect(calls, [2]);
      expect(tester.takeException(), isNull);
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
  int seeks = 0;
  @override
  AsyncValue<String?> build() => const AsyncData(null);
  @override
  Future<bool> syncStep({
    required int stepIndex,
    required int durationMs,
  }) async {
    seeks++;
    return true;
  }
}
