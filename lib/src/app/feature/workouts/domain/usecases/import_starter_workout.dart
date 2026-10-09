import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/workout_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/starter_workouts.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

part 'import_starter_workout.g.dart';

class ImportStarterWorkout {
  const ImportStarterWorkout(this.importer);
  final StarterWorkoutImporter importer;
  Future<Workout> call(StarterWorkout template, WorkoutAuthor author) =>
      importer.importStarter(template.create(author));
}

@riverpod
Future<ImportStarterWorkout> importStarterWorkout(Ref ref) async {
  final repository = await ref.watch(workoutRepositoryProvider.future);
  if (repository is! StarterWorkoutImporter) {
    throw StateError('예시 수업 가져오기를 지원하지 않습니다.');
  }
  return ImportStarterWorkout(repository as StarterWorkoutImporter);
}
