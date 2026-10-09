import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_position.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_command.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_failure.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_modes.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_rehearsal.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_canvas.dart';

Workout clockWorkout(List<WorkoutModule> modules, {int preparation = 0}) =>
    Workout.empty(
      'w',
      const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
    ).copyWith(modules: modules, countdownSeconds: preparation);
WorkoutModule clockModule(WorkoutTimerMode mode, int seconds) =>
    createContinuousTimer(
      WorkoutModule.empty('clock'),
      mode: mode,
      seconds: seconds,
      direction: TimerDirection.up,
    );
PlaybackSession clockSession(Workout w) => PlaybackSessionModel.fromWorkout(
  id: 's',
  ownerId: 'u',
  zoneId: 'main',
  targetDeviceIds: [],
  workout: w,
  stepIndex: 0,
  durationMs: playbackDurations(w).first,
  deviceId: 'c',
).toEntity().copyWith(anchorServerMs: 1000);

void main() {
  test('mode factories preserve slide content and round-trip independent timer settings', () {
    final source = WorkoutModule.empty('m')
        .copyWith(name: '제목', text: '운동 내용', rounds: 6, roundRestSeconds: 30);
    final modes = [
      createContinuousTimer(
        source,
        mode: WorkoutTimerMode.amrap,
        seconds: 720,
        direction: TimerDirection.down,
      ),
      createContinuousTimer(
        source,
        mode: WorkoutTimerMode.forTime,
        seconds: 600,
        direction: TimerDirection.up,
      ),
      createContinuousTimer(
        source,
        mode: WorkoutTimerMode.forTime,
        seconds: 0,
        direction: TimerDirection.up,
      ),
      createIntervalTimer(
        source,
        workSeconds: 20,
        restSeconds: 10,
        repeats: 8,
        includeFinalRest: true,
        tabata: true,
      ),
      createIntervalTimer(
        source,
        workSeconds: 45,
        restSeconds: 15,
        repeats: 10,
        includeFinalRest: false,
      ),
    ];
    expect(modes.map(workoutModuleDuration), [720, 600, 0, 240, 585]);
    for (final m in modes) {
      expect(timingValidationError(m), isNull);
      expect(m.name, source.name);
      expect(m.text, source.text);
      expect(m.rounds, 1);
      expect(m.roundRestSeconds, 0);
      expect(
        WorkoutModuleModel.fromJson(WorkoutModuleModel.fromEntity(m).toJson())
            .toEntity(),
        m,
      );
      expect(requiredTimingProtocol(clockWorkout([m])), 5);
    }
    expect(workoutModuleTimeline(modes[2]), hasLength(1));
    expect(moduleDurationText(modes[2]), '제한시간 없음');
    expect(moduleDurationText(modes[1]), '최대 10:00');
    expect(
      summarizeWorkout(clockWorkout([modes[2], modes[0]])).durationKind,
      'open',
    );
    expect(
      workoutDurationText(clockWorkout([modes[2], modes[0]])),
      '12:00 + 제한시간 없음',
    );
    expect(
      timingValidationError(modes[2].copyWith(timingVersion: 2)),
      isNotNull,
    );
    expect(timingValidationError(modes[2].copyWith(rounds: 2)), isNotNull);
    expect(
      timingValidationError(
        modes[2].copyWith(timerDirection: TimerDirection.down),
      ),
      isNotNull,
    );
    expect(() => clockModule(WorkoutTimerMode.amrap, 0), throwsFormatException);
    expect(
      () => clockModule(WorkoutTimerMode.forTime, -1),
      throwsFormatException,
    );
    expect(
      timingValidationError(
        modes[0].copyWith(
          intervalBlocks: [
            const WorkoutIntervalBlock(
              id: 'b',
              workSeconds: 20,
              restSeconds: 0,
              sets: 1,
            ),
          ],
        ),
      ),
      isNotNull,
    );
  });

  test('open clock, preparation, pause and late reconnect use elapsed time without auto-advance', () {
    final w = clockWorkout([
      clockModule(WorkoutTimerMode.forTime, 0),
    ], preparation: 3);
    final session = clockSession(w);
    expect(playbackPosition(session, playbackDurations(w), 2000), (
      index: 0,
      remainingMs: 0,
      countdownMs: 2000,
    ));
    expect(playbackPosition(session, playbackDurations(w), 5500), (
      index: 0,
      remainingMs: 1500,
      countdownMs: 0,
    ));
    final paused = session.copyWith(
      status: PlaybackStatus.paused,
      startDelayMs: 0,
      remainingMs: 1500,
    );
    expect(
      playbackPosition(paused, playbackDurations(w), 100000).remainingMs,
      1500,
    );
    final resumed = paused.copyWith(
      status: PlaybackStatus.playing,
      anchorServerMs: 100000,
    );
    expect(
      playbackPosition(resumed, playbackDurations(w), 102000).remainingMs,
      3500,
    );
    expect(rehearsalFrame(w.modules.first, 3500).remainingMs, 3500);
    final mixed = clockWorkout([
      WorkoutModule.empty('warmup').copyWith(workSeconds: 10),
      w.modules.first,
    ]);
    expect(
      playbackPosition(clockSession(mixed), playbackDurations(mixed), 31000),
      (index: 1, remainingMs: 20000, countdownMs: 0),
    );
  });

  test(
    'AMRAP advances at its deadline; For Time time cap holds its result',
    () {
      for (final mode in [WorkoutTimerMode.amrap, WorkoutTimerMode.forTime]) {
        final w = clockWorkout([
          clockModule(mode, 10),
          WorkoutModule.empty('next'),
        ]);
        final position = playbackPosition(
          clockSession(w),
          playbackDurations(w),
          11000,
        );
        expect(position.index, mode == WorkoutTimerMode.amrap ? 1 : 0);
        expect(
          position.remainingMs,
          mode == WorkoutTimerMode.amrap ? 60000 : 0,
        );
      }
    },
  );

  test('manual finish freezes authoritative elapsed time; completed clocks cannot resume', () {
    final w = clockWorkout([
      clockModule(WorkoutTimerMode.forTime, 0),
      WorkoutModule.empty('next'),
    ]);
    final session = clockSession(w);
    final command = resolvePlaybackCommand(
      session: session,
      expectedSessionId: 's',
      expectedRevision: 1,
      serverNowMs: 8432,
      expiresAtMs: 12000,
      status: 'paused',
      finishTimer: true,
    );
    expect(command.remainingMs, 7432);
    final finished = session.copyWith(
      status: PlaybackStatus.paused,
      remainingMs: command.remainingMs,
      timerCompleted: true,
    );
    expect(
      playbackPosition(finished, playbackDurations(w), 30000).remainingMs,
      7432,
    );
    expect(
      () => resolvePlaybackCommand(
        session: finished,
        expectedSessionId: 's',
        expectedRevision: 1,
        serverNowMs: 9000,
        expiresAtMs: 12000,
        status: 'playing',
      ),
      throwsA(isA<PlaybackFailure>()),
    );
    final next = resolvePlaybackCommand(
      session: finished,
      expectedSessionId: 's',
      expectedRevision: 1,
      serverNowMs: 9000,
      expiresAtMs: 12000,
      status: null,
      stepIndex: 1,
      remainingMs: 60000,
    );
    expect(next.status, 'playing');
    expect(next.stepIndex, 1);
    final json =
        PlaybackSessionModel.fromWorkout(
            id: 's',
            ownerId: 'u',
            zoneId: 'main',
            targetDeviceIds: [],
            workout: w,
            stepIndex: 0,
            durationMs: 7432,
            deviceId: 'c',
          ).toJson()
          ..['timerCompleted'] = true
          ..['status'] = 'paused';
    expect(
      PlaybackSessionModel.fromJson(json).toEntity().timerCompleted,
      isTrue,
    );
  });

  for (final cap in [0, 10]) {
    testWidgets(
      'For Time local clock pause/resume/finish/cap at $cap seconds',
      (tester) async {
        var now = DateTime(2026, 10, 9);
        final audio = _Audio();
        final w = clockWorkout([
          clockModule(WorkoutTimerMode.forTime, cap),
          WorkoutModule.empty('next'),
        ]);
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
        final provider = playerControllerProvider(w);
        container.listen(provider, (_, _) {});
        await tester.pump();
        final actions = container.read(provider.notifier);
        now = now.add(const Duration(milliseconds: 3500));
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          timerElapsedMs(
            w.modules.first,
            cap * 1000,
            container.read(provider).remainingMs,
          ),
          3500,
        );
        await actions.pause();
        now = now.add(const Duration(seconds: 60));
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          timerElapsedMs(
            w.modules.first,
            cap * 1000,
            container.read(provider).remainingMs,
          ),
          3500,
        );
        await actions.play();
        now = now.add(const Duration(seconds: 20));
        await tester.pump(const Duration(milliseconds: 100));
        if (cap == 0) {
          expect(await actions.finishTimer(), isTrue);
          expect(container.read(provider).remainingMs, 23500);
          expect(container.read(provider).timerCompleted, isTrue);
        } else {
          expect(container.read(provider).index, 0);
          expect(container.read(provider).remainingMs, 0);
          expect(container.read(provider).timerCompleted, isFalse);
        }
        expect(container.read(provider).isPaused, isTrue);
        final cues = audio.starts.length;
        await actions.play();
        now = now.add(const Duration(minutes: 5));
        await tester.pump(const Duration(milliseconds: 100));
        expect(container.read(provider).isPaused, isTrue);
        expect(audio.starts.length, cues);
        await actions.next();
        expect(container.read(provider).index, 1);
        expect(container.read(provider).isPaused, isFalse);
        expect(container.read(provider).timerCompleted, isFalse);
        container.dispose();
      },
    );
  }

  testWidgets(
    'count-up clock displays elapsed whole seconds and no fake unlimited gauge',
    (tester) async {
      final m = clockModule(WorkoutTimerMode.forTime, 0);
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutSlideTimer(
            module: m,
            isRest: false,
            secondsLeft: 6,
            remainingMs: 5500,
            durationMs: 0,
            isPaused: true,
            scale: 1,
          ),
        ),
      );
      expect(find.text('0:05'), findsOneWidget);
      expect(find.byKey(const ValueKey('slide-gauge')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('경과 시간 0:05')), findsOneWidget);
      final capped = createContinuousTimer(
        m,
        mode: WorkoutTimerMode.forTime,
        seconds: 600,
        direction: TimerDirection.down,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutSlideTimer(
            module: capped,
            isRest: false,
            secondsLeft: 15,
            remainingMs: 15000,
            durationMs: 600000,
            isPaused: true,
            finished: true,
            scale: 1,
          ),
        ),
      );
      expect(find.text('9:45'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('경과 시간 9:45')), findsOneWidget);
    },
  );
}

class _Audio extends BeepPlayer {
  final starts = <WorkoutSound>[];
  @override
  Future<void> play([
    WorkoutSound sound = WorkoutSound.classicBeep,
    double volume = 1,
  ]) async {
    starts.add(sound);
  }

  @override
  Future<void> playCountdown(WorkoutSound sound, double volume) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}
