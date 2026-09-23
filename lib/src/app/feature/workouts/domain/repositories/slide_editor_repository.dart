import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

abstract interface class SlideEditorRepository {
  Future<WorkoutModule?> loadDraft(String key);
  Future<void> saveDraft(String key, WorkoutModule module);
  Future<void> clearDraft(String key);
  Stream<List<WorkoutModule>> watchTemplates(String scope);
  Stream<List<WorkoutModule>> watchStyles(String scope);
  Future<List<WorkoutModule>> loadTemplates(String scope);
  Future<void> saveTemplates(
    String scope,
    List<WorkoutModule> templates, {
    List<WorkoutModule>? previous,
  });
  Future<List<WorkoutModule>> loadStyles(String scope);
  Future<void> saveStyles(
    String scope,
    List<WorkoutModule> styles, {
    List<WorkoutModule>? previous,
  });
}
