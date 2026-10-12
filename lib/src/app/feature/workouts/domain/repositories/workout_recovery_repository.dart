import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

class WorkoutRecoveryDraft {
  const WorkoutRecoveryDraft({required this.workout, required this.isNew});
  final Workout workout;
  final bool isNew;
}

abstract interface class WorkoutRecoveryRepository {
  Future<WorkoutRecoveryDraft?> load(String ownerId, String slot);
  Future<void> save(String ownerId, String slot, WorkoutRecoveryDraft draft);
  Future<void> clear(String ownerId, String slot);
}
