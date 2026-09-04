import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/entities/workout.dart';
import '../../domain/repositories/workout_repository.dart';
import '../datasources/workout_local_data_source.dart';
import '../models/workout_model.dart';

part 'workout_repository_impl.g.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  WorkoutRepositoryImpl(this._dataSource);
  final WorkoutLocalDataSource _dataSource;

  @override
  Future<List<Workout>> load() async {
    final values = _dataSource.load().map((item) => item.toEntity()).toList();
    values.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return values;
  }

  @override
  Future<void> save(Workout workout) async {
    final values = await load();
    final index = values.indexWhere((item) => item.id == workout.id);
    if (index == -1) {
      values.add(workout);
    } else {
      values[index] = workout;
    }
    await _dataSource.save(values.map(WorkoutModel.fromEntity).toList());
  }

  @override
  Future<void> delete(String workoutId) async {
    final values = await load()
      ..removeWhere((item) => item.id == workoutId);
    await _dataSource.save(values.map(WorkoutModel.fromEntity).toList());
  }
}

@riverpod
Future<WorkoutRepository> workoutRepository(Ref ref) async =>
    WorkoutRepositoryImpl(
      await ref.watch(workoutLocalDataSourceProvider.future),
    );
