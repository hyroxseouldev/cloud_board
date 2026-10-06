import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/library_failure.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/slide_editor_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';

part 'slide_templates_controller.g.dart';

@riverpod
class SlideTemplateWrites extends _$SlideTemplateWrites {
  @override
  Set<String> build(String scope) => const {};
  void update(Set<String> ids) => state = ids;
}

/// Merge only our accepted changes. Preserve unrelated/newer stream updates.
List<WorkoutModule> mergeSavedTemplates(
  List<WorkoutModule> before,
  List<WorkoutModule> saved,
  List<WorkoutModule> latest,
) {
  final baseline = {for (final item in before) item.id: item};
  final committed = {for (final item in saved) item.id: item};
  final merged = {for (final item in latest) item.id: item};
  for (final id in {...baseline.keys, ...committed.keys}) {
    if (baseline[id] == committed[id]) continue;
    if (merged[id] != baseline[id] && merged[id] != committed[id]) continue;
    final item = committed[id];
    if (item == null) {
      merged.remove(id);
    } else {
      merged[id] = item;
    }
  }
  return merged.values.toList();
}

@riverpod
class SlideTemplatesController extends _$SlideTemplatesController {
  bool _writing = false;
  String? lastError;
  Object? lastFailure;
  WorkoutModule? pendingDraft;
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

  Future<bool> createTemplate(WorkoutModule module) =>
      _write([...?state.value, module]);

  Future<bool> updateTemplate(
    WorkoutModule updated, {
    WorkoutModule? base,
  }) async {
    if (updated.name.trim().isEmpty ||
        updated.name.trim().length > 60 ||
        updated.category.trim().length > 40) {
      return false;
    }
    if (!(state.value?.any((item) => item.id == updated.id) ?? false)) {
      return false;
    }
    pendingDraft = updated;
    final previous = [
      for (final item in state.value!)
        item.id == updated.id ? base ?? item : item,
    ];
    final success = await _write([
      for (final item in state.value!)
        item.id == updated.id
            ? updated.copyWith(
                name: updated.name.trim(),
                category: updated.category.trim(),
              )
            : item,
    ], previous: previous);
    if (success) pendingDraft = null;
    return success;
  }

  Future<bool> remove(String id) =>
      _write([...?state.value?.where((module) => module.id != id)]);

  Future<bool> _write(
    List<WorkoutModule> templates, {
    List<WorkoutModule>? previous,
  }) async {
    if (_writing || state.isLoading || !state.hasValue) return false;
    _writing = true;
    lastError = null;
    lastFailure = null;
    final baseline = state;
    final actions = ref.read(slideEditorActionsProvider);
    final lifetime = ref.keepAlive();
    final before = previous ?? baseline.requireValue;
    final oldItems = {for (final item in before) item.id: item};
    final newItems = {for (final item in templates) item.id: item};
    ref.read(slideTemplateWritesProvider(scope).notifier).update({
      for (final id in {...oldItems.keys, ...newItems.keys})
        if (oldItems[id] != newItems[id]) id,
    });
    final result = await AsyncValue.guard(() async {
      return actions.saveTemplates(
        scope,
        templates,
        previous: previous ?? baseline.requireValue,
      );
    });
    _writing = false;
    lifetime.close();
    if (!ref.mounted) return !result.hasError;
    ref.read(slideTemplateWritesProvider(scope).notifier).update(const {});
    if (result.hasError) {
      lastFailure = result.error;
      if (ref.mounted) {
        final cause = result.error is LibraryFailure
            ? (result.error as LibraryFailure).cause
            : null;
        ref
            .read(errorReporterProvider)
            .capture(
              cause ?? result.error!,
              result.stackTrace ?? StackTrace.current,
              action: 'library.save',
            );
      }
      lastError = result.error is LibraryFailure
          ? result.error.toString()
          : '동기화하지 못했습니다. 연결을 확인하고 다시 시도해 주세요.';
    }
    if (result.hasError) {
      final fresh = await AsyncValue.guard(() => actions.loadTemplates(scope));
      if (ref.mounted) state = fresh.hasValue ? fresh : baseline;
    } else if (ref.mounted) {
      state = AsyncData(
        mergeSavedTemplates(
          before,
          result.requireValue,
          state.value ?? baseline.requireValue,
        ),
      );
    }
    return !result.hasError;
  }
}
