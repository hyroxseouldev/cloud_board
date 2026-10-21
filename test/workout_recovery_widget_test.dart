import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/library_folder_controller.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/workout_recovery_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/repositories/workout_recovery_repository.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_templates_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/workout_catalog_fixture.dart' show fixtureSavedSlideOrder;

final original =
    Workout.empty(
      'w',
      const WorkoutAuthor(id: 'a', displayName: 'Coach', photoUrl: null),
    ).copyWith(
      name: 'Server lesson',
      updatedAt: DateTime.utc(2026, 10, 12),
      modules: [WorkoutModule.empty('m')],
    );

void main() {
  for (final conflict in [false, true]) {
    testWidgets(
      'explicit recovery ${conflict ? 'copies changed server version' : 'retains same-version edit'} and failed save persists draft',
      (tester) async {
        final local = _Recovery()
          ..draft = WorkoutRecoveryDraft(
            workout: original.copyWith(name: 'Unsaved lesson'),
            isNew: false,
          );
        final saves = <Workout>[];
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            fixtureSavedSlideOrder,
            authStateProvider.overrideWith(
              (ref) => Stream.value(
                const AuthUser(
                  id: 'a',
                  email: 'a@example.invalid',
                  displayName: 'Coach',
                  photoUrl: null,
                ),
              ),
            ),
            workoutDetailProvider('w').overrideWith(
              () => _Detail(
                conflict
                    ? original.copyWith(
                        updatedAt: original.updatedAt.add(
                          const Duration(minutes: 1),
                        ),
                      )
                    : original,
              ),
            ),
            libraryFoldersProvider.overrideWith((ref) => Stream.value([])),
            workoutRecoveryRepositoryProvider.overrideWithValue(local),
            workoutActionControllerProvider.overrideWith(
              () => _FailSave(saves),
            ),
            slideTemplatesControllerProvider.overrideWith2((_) => _Templates()),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: XonTheme.light,
              home: const WorkoutEditorScreen(workoutId: 'w'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('저장하지 못한 편집 내용'), findsOneWidget);
        expect(saves, isEmpty);
        await tester.tap(find.text(conflict ? '새 워크아웃으로 복구' : '편집 내용 복구'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('workout-save-button')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('workout-save-button')));
        await tester.pumpAndSettle();
        expect(saves, hasLength(1));
        expect(saves.single.id, conflict ? isNot('w') : 'w');
        expect(local.draft!.workout.id, saves.single.id);
        expect(
          local.draft!.workout.name,
          conflict ? 'Unsaved lesson 복구' : 'Unsaved lesson',
        );
        expect(find.textContaining('변경사항은 유지됩니다'), findsNothing);
        expect(find.text('저장 실패 · 변경사항 유지됨'), findsOneWidget);
        expect(find.text('다시 저장'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await tester.pump();
      },
    );
  }
}

class _Recovery implements WorkoutRecoveryRepository {
  WorkoutRecoveryDraft? draft;
  @override
  Future<WorkoutRecoveryDraft?> load(String ownerId, String slot) async =>
      draft;
  @override
  Future<void> save(
    String ownerId,
    String slot,
    WorkoutRecoveryDraft value,
  ) async {
    draft = value;
  }

  @override
  Future<void> clear(String ownerId, String slot) async {
    draft = null;
  }
}

class _Detail extends WorkoutDetail {
  _Detail(this.value);
  final Workout value;
  @override
  Future<Workout?> build(String id) async => value;
}

class _Templates extends SlideTemplatesController {
  @override
  Stream<List<WorkoutModule>> build(String scope) => Stream.value([]);
}

class _FailSave extends WorkoutActionController {
  _FailSave(this.saved);
  final List<Workout> saved;
  @override
  Future<Workout?> save(Workout workout) async {
    saved.add(workout);
    state = AsyncError(StateError('offline'), StackTrace.current);
    return null;
  }
}
