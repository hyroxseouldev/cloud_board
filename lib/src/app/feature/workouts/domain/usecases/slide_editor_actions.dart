import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/slide_editor_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
part 'slide_editor_actions.g.dart';

class SlideEditorActions {
  const SlideEditorActions(this.repository);
  final SlideEditorRepository repository;
  Future<WorkoutModule?> loadDraft(String key) => repository.loadDraft(key);
  Future<void> saveDraft(String key, WorkoutModule module) =>
      repository.saveDraft(key, module);
  Future<void> clearDraft(String key) => repository.clearDraft(key);
  Future<List<WorkoutModule>> loadStyles(String scope) =>
      repository.loadStyles(scope);
  Future<void> saveStyles(String scope, List<WorkoutModule> styles) =>
      repository.saveStyles(scope, styles);
}

@riverpod
SlideEditorActions slideEditorActions(Ref ref) =>
    SlideEditorActions(ref.watch(slideEditorRepositoryProvider));

WorkoutModule applySlideStyle(WorkoutModule target, WorkoutModule style) =>
    target.copyWith(
      appearance: style.appearance,
      showTimer: style.showTimer,
      showTimerGauge: style.showTimerGauge,
      showSets: style.showSets,
      workGaugeColor: style.workGaugeColor,
      restGaugeColor: style.restGaugeColor,
      workTextColor: style.workTextColor,
      restTextColor: style.restTextColor,
      timerColorValue: style.timerColorValue,
    );
