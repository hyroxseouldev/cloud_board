import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_readiness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const author = WorkoutAuthor(
    id: 'coach',
    displayName: 'Coach',
    photoUrl: null,
  );

  test('valid workout is ready for class', () {
    final workout = Workout.empty('workout', author).copyWith(
      name: 'Morning class',
      modules: [WorkoutModule.empty('module').copyWith(name: 'Warm up')],
    );

    expect(evaluateWorkoutReadiness(workout).isReady, isTrue);
  });

  test('invalid slide and image are reported before class', () {
    final workout = Workout.empty('workout', author).copyWith(
      name: 'Class',
      modules: [
        WorkoutModule.empty('module')
            .copyWith(workSeconds: 0, imageSource: 'not-an-image'),
      ],
    );
    final result = evaluateWorkoutReadiness(workout);

    expect(result.isReady, isFalse);
    expect(result.issues, hasLength(3));
  });
}
