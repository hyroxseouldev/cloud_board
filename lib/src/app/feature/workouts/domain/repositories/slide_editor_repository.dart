import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

abstract interface class SlideEditorRepository {
  Future<WorkoutModule?> loadDraft(String key);
  Future<void> saveDraft(String key, WorkoutModule module);
  Future<void> clearDraft(String key);
  Future<List<WorkoutModule>> loadTemplates(String scope);
  Future<void> saveTemplates(String scope, List<WorkoutModule> templates);
  Future<List<WorkoutModule>> loadStyles(String scope);
  Future<void> saveStyles(String scope, List<WorkoutModule> styles);
}
