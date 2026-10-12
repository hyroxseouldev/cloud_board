import 'package:cloud_board/src/app/feature/workouts/data/repositories/workout_recovery_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_recovery_repository.dart';

/// UI tests exercise recovery through the real controller without filesystem
/// plugin calls. Native/IndexedDB durability is covered by repository tests.
final memoryWorkoutRecovery = workoutRecoveryRepositoryProvider.overrideWith(
  (ref) => MemoryWorkoutRecoveryRepository(),
);

class MemoryWorkoutRecoveryRepository implements WorkoutRecoveryRepository {
  final _drafts = <(String, String), WorkoutRecoveryDraft>{};
  @override
  Future<WorkoutRecoveryDraft?> load(String ownerId, String slot) async =>
      _drafts[(ownerId, slot)];
  @override
  Future<void> save(
    String ownerId,
    String slot,
    WorkoutRecoveryDraft draft,
  ) async {
    _drafts[(ownerId, slot)] = draft;
  }

  @override
  Future<void> clear(String ownerId, String slot) async {
    _drafts.remove((ownerId, slot));
  }
}
