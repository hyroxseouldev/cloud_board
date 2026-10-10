import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/starter_workouts.dart';

import 'package:cloud_board/src/app/feature/onboarding/data/repositories/exploration_repository_impl.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/exploration_progress.dart';

part 'exploration_controller.g.dart';

@Riverpod(keepAlive: true)
class ExplorationController extends _$ExplorationController {
  int _generation = 0;
  Future<void> _queue = Future.value();
  String? _userId;

  @override
  Future<ExplorationProgress> build() {
    _generation++;
    _userId = ref.watch(authStateProvider.select((s) => s.value?.id));
    return ref.watch(explorationRepositoryProvider).load(_userId);
  }

  Future<void> _change(
    ExplorationProgress Function(ExplorationProgress) update,
  ) {
    final generation = _generation, userId = _userId;
    final repository = ref.read(explorationRepositoryProvider);
    final task = _queue.then((_) async {
      final current = await future;
      if (!ref.mounted || generation != _generation) return;
      final next = update(current);
      // Keep the current selection usable even if device storage is unavailable.
      state = AsyncData(next);
      await repository.save(userId, next);
    });
    _queue = task.catchError((Object _) {});
    return task;
  }

  Future<void> select(StarterWorkout template) =>
      _change((s) => s.copyWith(templateKey: template.key));
  Future<void> purpose(String value) =>
      _change((s) => s.copyWith(purpose: value));
  Future<void> beginImport(StarterWorkout template, {String? purpose}) =>
      _change(
        (s) => s.copyWith(
          templateKey: template.key,
          purpose: purpose ?? s.purpose,
          pendingImport: true,
        ),
      );
  Future<void> imported(StarterWorkout template) => _change(
    (s) => s.templateKey == template.key ? s.copyWith(pendingImport: false) : s,
  );
  Future<void> event(String event) =>
      _change((s) => s.copyWith(events: {...s.events, event}.toList()));
  Future<void> completed(StarterWorkout template) => _change(
    (s) => s.copyWith(
      templateKey: template.key,
      completedTemplates: {...s.completedTemplates, template.key}.toList(),
      events: {...s.events, 'demo_completed'}.toList(),
    ),
  );
}
