import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_design_section_editor.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<void> mountSections(
    WidgetTester tester,
    ValueNotifier<String> text,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: XonTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ValueListenableBuilder<String>(
              valueListenable: text,
              builder: (context, value, _) => SlideDesignSectionEditor(
                text: value,
                keyPrefix: 'test-section',
                onChanged: (value) => text.value = value,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  TextEditingController field(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(ValueKey(key))).controller!;

  testWidgets(
    'canonical parent echoes retain newline, cursor and composing text while editing',
    (tester) async {
      final text = ValueNotifier('## WARM UP\nRun 200m');
      addTearDown(text.dispose);
      await mountSections(tester, text);
      final lines = find.byKey(const ValueKey('test-section-0-lines'));
      await tester.enterText(lines, 'Run 200m\n\n');
      await tester.pumpAndSettle();
      expect(text.value, '## WARM UP\nRun 200m');
      expect(field(tester, 'test-section-0-lines').text, 'Run 200m\n\n');
      expect(field(tester, 'test-section-0-lines').selection.extentOffset, 10);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '런지 20회\n',
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump();
      final controller = field(tester, 'test-section-0-lines');
      expect(controller.text, '런지 20회\n');
      expect(controller.selection.extentOffset, 1);
      expect(controller.value.composing, const TextRange(start: 0, end: 2));
      expect(text.value, '## WARM UP\n런지 20회');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'adding blank sections and deleting a neighbor preserves remaining text',
    (tester) async {
      final text = ValueNotifier('## WARM UP\nRun 200m');
      addTearDown(text.dispose);
      await mountSections(tester, text);
      final add = find.byKey(const ValueKey('test-section-add'));
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(parseSlideDesignSections(text.value), hasLength(2));
      expect(field(tester, 'test-section-1-heading').text, isEmpty);
      final heading = find.byKey(const ValueKey('test-section-1-heading'));
      await tester.ensureVisible(heading);
      await tester.enterText(heading, 'MAIN');
      final body = find.byKey(const ValueKey('test-section-1-lines'));
      await tester.ensureVisible(body);
      await tester.enterText(body, 'Squat 10 reps\n');
      await tester.pumpAndSettle();
      final delete = find.byKey(const ValueKey('test-section-0-delete'));
      await tester.ensureVisible(delete);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      expect(field(tester, 'test-section-0-heading').text, 'MAIN');
      expect(field(tester, 'test-section-0-lines').text, 'Squat 10 reps\n');
      expect(text.value, '## MAIN\nSquat 10 reps');
      await tester.ensureVisible(
        find.byKey(const ValueKey('test-section-0-heading')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('test-section-0-heading')),
        '',
      );
      await tester.pumpAndSettle();
      expect(field(tester, 'test-section-0-lines').text, 'Squat 10 reps\n');
      expect(find.textContaining('##'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('external replacement or undo refreshes displayed sections', (
    tester,
  ) async {
    final text = ValueNotifier('## FIRST\nRun 200m');
    addTearDown(text.dispose);
    await mountSections(tester, text);
    await tester.enterText(
      find.byKey(const ValueKey('test-section-0-heading')),
      'EDITED',
    );
    await tester.pumpAndSettle();
    final lastLocalEdit = text.value;
    text.value = '## NEW\nRow 500m\n## END\nWalk 100m';
    await tester.pumpAndSettle();
    expect(field(tester, 'test-section-0-heading').text, 'NEW');
    expect(field(tester, 'test-section-1-lines').text, 'Walk 100m');
    text.value = lastLocalEdit;
    await tester.pumpAndSettle();
    expect(field(tester, 'test-section-0-heading').text, 'EDITED');
    expect(find.byKey(const ValueKey('test-section-1-lines')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  Future<void> mountEditor(WidgetTester tester, WorkoutModule module) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          slideEditorRepositoryProvider.overrideWithValue(
            LocalSlideEditorRepository(SlideEditorLocalDataSource()),
          ),
        ],
        child: MaterialApp(
          theme: XonTheme.light,
          builder: XonTheme.responsiveBuilder,
          home: SlideEditorScreen(
            workoutId: 'design-workout',
            moduleId: module.id,
            guard: ExitGuard(),
            request: SlideEditRequest(
              module: module,
              onSave: (_) async => true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('배경'));
    await tester.pumpAndSettle();
  }

  Future<void> revealEditor(WidgetTester tester, Finder target) async {
    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('slide-editor-settings')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(target, 240, scrollable: scrollable);
    await tester.pumpAndSettle();
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'saved v2 slide editor exposes visual layout and structured section editing',
    (tester) async {
      final module = WorkoutModule.empty('saved-v2').copyWith(
        name: 'SESSION',
        designTemplate: 'stationd-v2-list',
        text: '## WARM UP\nRun 200m\n## MAIN\nSquat 10 reps',
        showTimer: false,
        showSets: false,
      );
      await mountEditor(tester, module);
      final dropdown = find.byKey(const ValueKey('slide-design-layout-auto'));
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('섹션 카드').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WorkoutSlidePreview>(find.byType(WorkoutSlidePreview))
            .module
            .designLayout,
        'cards',
      );
      final heading = find.byKey(const ValueKey('slide-section-0-heading'));
      await revealEditor(tester, heading);
      await tester.enterText(heading, 'PREPARE');
      await tester.pumpAndSettle();
      final edited = tester
          .widget<WorkoutSlidePreview>(find.byType(WorkoutSlidePreview))
          .module;
      expect(edited.text, '## PREPARE\nRun 200m\n## MAIN\nSquat 10 reps');
      expect(find.widgetWithText(TextFormField, '화면 텍스트'), findsNothing);
      expect(find.textContaining('##'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('ordinary slide keeps the existing free text editor', (
    tester,
  ) async {
    await mountEditor(
      tester,
      WorkoutModule.empty('plain').copyWith(name: 'PLAIN', text: '일반 화면 문구'),
    );
    await revealEditor(tester, find.widgetWithText(TextFormField, '화면 텍스트'));
    expect(find.byType(SlideDesignSectionEditor), findsNothing);
    expect(find.widgetWithText(TextFormField, '화면 텍스트'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
