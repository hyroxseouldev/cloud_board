import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workout duration expands work and rest sets', () {
    final workout = Workout.empty('workout').copyWith(
      modules: [
        WorkoutModule.empty('module')
            .copyWith(workSeconds: 60, sets: 3, restSeconds: 20),
      ],
    );
    expect(workoutDuration(workout), 220);
  });
}
