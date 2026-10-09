import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_reference_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/original_slide_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/original_slide_template.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_editor_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  for (final design in customerReferenceDesigns) {
    testWidgets(
      '${design.id}: generated slide uses the common editor and saves timer, content and sound together',
      (tester) async {
        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.empty();
        tester.view.physicalSize = const Size(834, 1194);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(
          () => loadOriginalSlideImage(
            design.theme.designStyle!.originalTemplate!,
          ),
        );
        final original = previewAiSlide(
          applyAiSlideTheme(
            initialAiSlideDesignDraft(design.theme),
            design.theme,
          ),
          'original',
        );
        final saved = <WorkoutModule>[];
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              slideEditorRepositoryProvider.overrideWithValue(
                LocalSlideEditorRepository(SlideEditorLocalDataSource()),
              ),
            ],
            child: MaterialApp(
              home: SlideEditorScreen(
                workoutId: 'original-workout',
                moduleId: original.id,
                guard: ExitGuard(),
                request: SlideEditRequest(
                  module: original,
                  onSave: (value) async {
                    saved.add(value);
                    return true;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SlideEditorScreen)),
        );
        final provider = slideEditorControllerProvider(
          'original-workout',
          original,
          'local',
        );
        expect(find.byKey(const ValueKey('slide-editor-tabs')), findsOneWidget);
        for (final tab in ['타이머', '배경', '소리', '라이브러리']) {
          expect(find.text(tab), findsOneWidget);
        }
        expect(find.textContaining('AI로 타이머'), findsNothing);
        await tester.ensureVisible(find.text('숫자만'));
        await tester.tap(find.text('숫자만'));
        await tester.pumpAndSettle();
        expect(container.read(provider).module.showTimer, isTrue);
        expect(find.byType(WorkoutSlideTimer), findsOneWidget);
        // Use the very same timer builder as a basic slide.
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('slide-timer-summary')),
          -200,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('slide-editor-settings')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(find.byKey(const ValueKey('slide-timer-summary')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('open-timer-builder')),
        );
        await tester.tap(find.byKey(const ValueKey('open-timer-builder')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('timer-mode-forTime')));
        await tester.pumpAndSettle();
        final confirmReplacement = find.byKey(
          const ValueKey('confirm-timer-replacement'),
        );
        await tester.ensureVisible(confirmReplacement);
        await tester.tap(confirmReplacement);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('apply-timer-editor')));
        await tester.pumpAndSettle();
        expect(
          container.read(provider).module.timerMode,
          WorkoutTimerMode.forTime,
        );
        await tester.tap(find.text('배경'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('slide-body-text')),
        );
        await tester.enterText(
          find.byKey(const ValueKey('slide-body-text')),
          'Ski 300m\nRun 250m',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('소리'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(SwitchListTile).first);
        await tester.pumpAndSettle();
        expect(container.read(provider).module.beep, !original.beep);
        final current = container.read(provider).module;
        expect(
          current.showTimer,
          isTrue,
          reason: 'Content and sound edits must not disable the timer',
        );
        expect(originalSlideValidationError(current), isNull);
        await tester.tap(find.byKey(const ValueKey('slide-save-button')));
        await tester.pumpAndSettle();
        expect(saved.single.showTimer, isTrue);
        expect(saved.single.workSeconds, 0);
        expect(saved.single.text, 'Ski 300m\nRun 250m');
        expect(saved.single.designStyle, original.designStyle);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
