import 'package:cloud_board/src/app/feature/workouts/domain/library_failure.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/slide_editor_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';

part 'slide_templates_controller.g.dart';

@riverpod
class SlideTemplatesController extends _$SlideTemplatesController {
  bool _writing = false;
  String? lastError;
  @override
  Stream<List<WorkoutModule>> build(String scope) =>
      ref.watch(slideEditorActionsProvider).watchTemplates(scope);

  Future<bool> save(
    WorkoutModule module,
    String name, {
    bool favorite = false,
  }) => _write([
    ...?state.value,
    module.copyWith(id: newId(), name: name.trim(), favorite: favorite),
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
    if (_writing || state.isLoading || !state.hasValue) return false;
    _writing = true;
    lastError = null;
    final previous = state;
    final actions = ref.read(slideEditorActionsProvider);
    state = const AsyncLoading<List<WorkoutModule>>();
    final result = await AsyncValue.guard(() async {
      await actions.saveTemplates(
        scope,
        templates,
        previous: previous.requireValue,
      );
      return actions.loadTemplates(scope);
    });
    _writing = false;
    if (result.hasError) {
      lastError = result.error is LibraryFailure
          ? result.error.toString()
          : '동기화하지 못했습니다. 연결을 확인하고 다시 시도해 주세요.';
    }
    if (ref.mounted) {
      state = result.hasError
          ? AsyncData(state.value ?? previous.requireValue)
          : result;
    }
    return !result.hasError;
  }
}
