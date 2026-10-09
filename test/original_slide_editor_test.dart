import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_reference_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/original_slide_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/original_slide_template.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_editor_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets(
    'saved original edits content without conflicting timer or layout controls',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      tester.view.physicalSize = const Size(834, 1194);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(
        () => loadOriginalSlideImage(dolpaBrickOriginalTemplateId),
      );
      final original = previewAiSlide(
        applyAiSlideTheme(
          initialAiSlideDesignDraft(dolpaReferenceDesign.theme),
          dolpaReferenceDesign.theme,
        ),
        'original',
      );
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
                onSave: (_) async => false,
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('original-slide-editor-tabs')),
        findsOneWidget,
      );
      expect(find.text('타이머'), findsNothing);
      expect(find.byKey(const ValueKey('timer-display-toggle')), findsNothing);
      expect(find.byKey(const ValueKey('studio-class-label')), findsNothing);
      expect(
        find.byKey(const ValueKey('original-slide-title')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('original-slide-subtitle')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('original-slide-lines')),
        findsOneWidget,
      );
      expect(find.text('다른 스타일 불러오기'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const ValueKey('original-slide-title')),
                matching: find.byType(TextField),
              ),
            )
            .readOnly,
        isTrue,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('slide-title-button')),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('original-slide-lines')),
        'Ski 300m + Sled Pull 1 Way\nRun 250m + FMCTP 30\nSki 250m + Wall Ball 30\nDV Press 8 + BTP 10',
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SlideEditorScreen)),
      );
      final current = container
          .read(
            slideEditorControllerProvider(
              'original-workout',
              original,
              'local',
            ),
          )
          .module;
      expect(current.text.startsWith('Ski 300m'), isTrue);
      expect(current.showTimer, isFalse);
      expect(current.showSets, isFalse);
      expect(current.designStyle, original.designStyle);
      expect(tester.takeException(), isNull);
    },
  );
}
