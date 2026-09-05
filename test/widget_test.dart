import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workout duration expands work and rest sets', () {
    final workout =
        Workout.empty(
          'workout',
          const WorkoutAuthor(
            id: 'user',
            displayName: 'Tester',
            photoUrl: null,
          ),
        ).copyWith(
          modules: [
            WorkoutModule.empty('module')
                .copyWith(workSeconds: 60, sets: 3, restSeconds: 20),
          ],
        );
    expect(workoutDuration(workout), 220);
  });

  test('player steps use a static workout snapshot', () {
    final workout = _workout().copyWith(
      modules: [
        WorkoutModule.empty('one')
            .copyWith(workSeconds: 60, sets: 2, restSeconds: 15),
        WorkoutModule.empty('two').copyWith(workSeconds: 30),
      ],
    );

    final steps = buildPlayerSteps(workout);

    expect(steps.map((step) => step.duration), [60, 15, 60, 30]);
    expect(playerStepIndexForModule(workout, 1), 3);
  });

  test('running session derives remaining time from server clock', () {
    final session = PlaybackSession(
      id: 'session',
      ownerId: 'user',
      workout: _workout(),
      status: PlaybackStatus.playing,
      stepIndex: 0,
      remainingMs: 60000,
      anchorServerMs: 100000,
      revision: 1,
      updatedByDeviceId: 'device-a',
    );

    expect(
      synchronizedRemainingMs(
        session: session,
        localNowMs: 104500,
        serverTimeOffsetMs: 500,
      ),
      55000,
    );
    expect(
      synchronizedRemainingMs(
        session: session.copyWith(status: PlaybackStatus.paused),
        localNowMs: 150000,
        serverTimeOffsetMs: 500,
      ),
      60000,
    );
  });

  test('device mode falls back to controller', () {
    expect(DeviceMode.fromStorage(null), DeviceMode.controller);
    expect(DeviceMode.fromStorage('display'), DeviceMode.display);
  });

  test('playback session keeps an immutable workout snapshot', () {
    final workout = _workout();
    final model = PlaybackSessionModel.fromWorkout(
      id: 'session',
      ownerId: 'user',
      workout: workout,
      stepIndex: 0,
      durationMs: 60000,
      deviceId: 'device-a',
    );

    final restored = PlaybackSessionModel.fromJson(model.toJson()).toEntity();

    expect(restored.workout, workout);
    expect(restored.remainingMs, 60000);
    expect(restored.status, PlaybackStatus.playing);
  });
}

Workout _workout() => Workout.empty(
  'workout',
  const WorkoutAuthor(id: 'user', displayName: 'Tester', photoUrl: null),
).copyWith(modules: [WorkoutModule.empty('module')]);
