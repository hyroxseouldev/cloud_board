import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_audio_cues.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';
import 'package:flutter_test/flutter_test.dart';

Workout audioFixture({
  WorkoutTimerMode mode = WorkoutTimerMode.interval,
  int seconds = 5,
}) =>
    Workout.empty(
      'fixture',
      const WorkoutAuthor(id: 'local', displayName: 'Local', photoUrl: null),
    ).copyWith(
      workStartSound: WorkoutSound.sharpBeep,
      restStartSound: WorkoutSound.lowPulse,
      countdownSound: WorkoutSound.videoBeep,
      workoutEndSound: WorkoutSound.longFinish,
      modules: [
        WorkoutModule.empty('m').copyWith(
          workSeconds: seconds,
          restSeconds: 4,
          sets: 1,
          includeFinalRest: true,
          timerMode: mode,
          beep: true,
        ),
      ],
    );
PlaybackSession audioSession({Workout? workout}) => PlaybackSession(
  id: 'local-class',
  ownerId: 'local',
  zoneId: 'fixture',
  workout: workout ?? audioFixture(),
  status: PlaybackStatus.playing,
  stepIndex: 0,
  remainingMs: 5000,
  startDelayMs: 3000,
  anchorServerMs: 10000,
  revision: 1,
  updatedByDeviceId: 'local',
);

void main() {
  test('polling phase never shifts shared deadlines, preparation and phase cues use one anchor', () {
    final plan = PlaybackAudioPlan(audioSession());
    final a = plan.upcoming(10011, horizonMs: 20000);
    final b = plan.upcoming(10089, horizonMs: 20000);
    expect(
      a.map((c) => (c.id, c.serverTimeMs)),
      b.map((c) => (c.id, c.serverTimeMs)),
    );
    expect(a.map((c) => (c.serverTimeMs, c.sound, c.countdown)), [
      (11000, WorkoutSound.videoBeep, true),
      (12000, WorkoutSound.videoBeep, true),
      (13000, WorkoutSound.sharpBeep, false),
      (15000, WorkoutSound.videoBeep, true),
      (16000, WorkoutSound.videoBeep, true),
      (17000, WorkoutSound.videoBeep, true),
      (18000, WorkoutSound.lowPulse, false),
      (19000, WorkoutSound.videoBeep, true),
      (20000, WorkoutSound.videoBeep, true),
      (21000, WorkoutSound.videoBeep, true),
      (22000, WorkoutSound.longFinish, false),
    ]);
  });
  test('late attachment only contains future cues, capped bounded horizon', () {
    final plan = PlaybackAudioPlan(audioSession());
    expect(plan.upcoming(17999).first.serverTimeMs, 18000);
    expect(plan.upcoming(18000).every((c) => c.serverTimeMs > 18000), isTrue);
    expect(plan.upcoming(23000), isEmpty);
    expect(plan.upcoming(10000).every((c) => c.serverTimeMs <= 15000), isTrue);
  });
  test('pause, briefing, completion and volume off schedule nothing', () {
    final s = audioSession();
    for (final disabled in [
      s.copyWith(status: PlaybackStatus.paused),
      s.copyWith(briefing: true),
      s.copyWith(timerCompleted: true),
      s.copyWith(status: PlaybackStatus.completed),
      s.copyWith(workout: s.workout.copyWith(soundVolume: 0)),
    ]) {
      expect(PlaybackAudioPlan(disabled).upcoming(10000), isEmpty);
    }
  });
  test('seek/resume uses new anchor/remaining, not old elapsed timeline', () {
    final s = audioSession().copyWith(
      revision: 2,
      stepIndex: 1,
      remainingMs: 2000,
      anchorServerMs: 20000,
      startDelayMs: 0,
    );
    final cues = PlaybackAudioPlan(s).upcoming(20001);
    expect(cues.map((c) => c.serverTimeMs), [21000, 22000]);
    expect(cues.every((c) => c.id.contains('/2/')), isTrue);
    expect(PlaybackAudioPlan(s).recentCommand(20001), isNull);
  });
  test(
    'ForTime cap emits end once and does not automatically start next module',
    () {
      final workout = audioFixture(mode: WorkoutTimerMode.forTime).copyWith(
        modules: [
          audioFixture(mode: WorkoutTimerMode.forTime).modules.first,
          WorkoutModule.empty('next').copyWith(workSeconds: 5, beep: true),
        ],
      );
      final cues = PlaybackAudioPlan(audioSession(workout: workout))
          .upcoming(10000, horizonMs: 30000);
      expect(cues.last.serverTimeMs, 18000);
      expect(cues.last.sound, WorkoutSound.longFinish);
      expect(cues.where((c) => c.id.contains('start/1')), isEmpty);
    },
  );
  test(
    'open timer has only preparation/start, never an invented end or loop',
    () {
      final s = audioSession(
        workout: audioFixture(mode: WorkoutTimerMode.forTime, seconds: 0),
      ).copyWith(remainingMs: 0);
      final cues = PlaybackAudioPlan(s).upcoming(10000, horizonMs: 30000);
      expect(cues.map((c) => c.serverTimeMs), [11000, 12000, 13000]);
    },
  );
  test('fresh zero-delay start and manual cap/end use bounded explicit cue; resume does not', () {
    final start = audioSession().copyWith(startDelayMs: 0);
    expect(
      PlaybackAudioPlan(start).recentCommand(10100)?.sound,
      WorkoutSound.sharpBeep,
    );
    expect(PlaybackAudioPlan(start).recentCommand(10501), isNull);
    expect(
      PlaybackAudioPlan(start).recentCommand(
        10100,
        previous: start.copyWith(status: PlaybackStatus.paused),
      ),
      isNull,
    );
    final completed = start.copyWith(
      timerCompleted: true,
      revision: 2,
      anchorServerMs: 12000,
    );
    expect(
      PlaybackAudioPlan(completed).recentCommand(12100, previous: start)?.sound,
      WorkoutSound.longFinish,
    );
    final natural = start.copyWith(
      status: PlaybackStatus.completed,
      revision: 2,
      anchorServerMs: 19000,
    );
    expect(
      PlaybackAudioPlan(natural).recentCommand(19100, previous: start),
      isNull,
    );
  });
}
