import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/slide_editor_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';

part 'slide_templates_controller.g.dart';

@riverpod
class SlideTemplatesController extends _$SlideTemplatesController {
  @override
  Future<List<WorkoutModule>> build(String scope) =>
      ref.watch(slideEditorActionsProvider).loadTemplates(scope);

  Future<bool> save(WorkoutModule module, String name) => _write([
    ...?state.value,
    module.copyWith(id: newId(), name: name.trim()),
  ]);

  Future<bool> updateTemplate(WorkoutModule updated) async {
    if (updated.name.trim().isEmpty ||
        updated.name.trim().length > 60 ||
        updated.category.trim().length > 40) {
      return false;
    }
    if (!(state.value?.any((item) => item.id == updated.id) ?? false)) {
      return false;
    }
    return _write([
      for (final item in state.value!)
        item.id == updated.id
            ? updated.copyWith(
                name: updated.name.trim(),
                category: updated.category.trim(),
              )
            : item,
    ]);
  }

  Future<bool> remove(String id) =>
      _write([...?state.value?.where((module) => module.id != id)]);

  Future<bool> _write(List<WorkoutModule> templates) async {
    if (state.isLoading || !state.hasValue) return false;
    final previous = state;
    final actions = ref.read(slideEditorActionsProvider);
    state = const AsyncLoading<List<WorkoutModule>>();
    final result = await AsyncValue.guard(() async {
      await actions.saveTemplates(scope, templates);
      return templates;
    });
    if (ref.mounted) state = result.hasError ? previous : result;
    return !result.hasError;
  }
}
