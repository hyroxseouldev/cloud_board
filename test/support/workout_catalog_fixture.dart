import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';

/// UI fixtures supply summary and detail through separate production boundaries.
abstract class FixtureWorkoutController extends WorkoutController {
  final details = <String, Workout>{};
  Stream<List<Workout>> fullBuild();
  @override
  Stream<List<WorkoutSummary>> build() async* {
    await for (final items in fullBuild()) {
      details.addAll({for (final item in items) item.id: item});
      yield items.map(summarizeWorkout).toList();
    }
  }

  @override
  void upsert(Workout workout) {
    details[workout.id] = workout;
    super.upsert(workout);
  }
}

class FixtureWorkoutDetail extends WorkoutDetail {
  @override
  Future<Workout?> build(String id) async {
    ref.listen(workoutControllerProvider, (_, _) {});
    await ref.read(workoutControllerProvider.future);
    return (ref.read(
      workoutControllerProvider.notifier,
    ) as FixtureWorkoutController).details[id];
  }
}

final fixtureWorkoutDetails = workoutDetailProvider.overrideWith2(
  (_) => FixtureWorkoutDetail(),
);
