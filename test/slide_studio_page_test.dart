import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_catalog.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/slide_studio.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/slide_studio_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_raster_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/center_slide_catalog_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slide_design_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slides_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/slide_studio_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_page.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/slide_studio_page.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

import 'support/slide_studio_fakes.dart';
import 'support/ai_raster_fakes.dart';
import 'support/ui_layout_evidence.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    FakeStudioRepository repository, {
    ValueChanged<List<WorkoutModule>?>? onResult,
  }) async {
    final guard = ExitGuard();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final result = await showAiSlidesPage(context);
                onResult?.call(result);
              },
              child: const Text('open'),
            ),
          ),
          routes: [
            GoRoute(
              path: 'images/create',
              builder: (_, _) => AiSlidesPage(guard: guard),
              onExit: (_, _) => guard.confirm(),
              routes: [
                GoRoute(
                  path: 'library',
                  builder: (_, _) =>
                      const Scaffold(body: Text('saved library route')),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiSlidesOwnerIdProvider.overrideWithValue('local-owner'),
          aiSlideDesignOwnerIdProvider.overrideWithValue(null),
          aiSlideDesignStoreIdProvider.overrideWithValue(null),
          centerSlideCatalogScopeProvider.overrideWithValue(null),
          centerSlideCatalogProvider.overrideWith(
            (_) => Stream.value(emptyCenterSlideCatalog()),
          ),
          slideStudioActionsProvider.overrideWithValue(
            SlideStudioActions(repository),
          ),
          aiRasterActionsProvider.overrideWithValue(
            AiRasterActions(FakeRasterRepository()),
          ),
        ],
        child: RepaintBoundary(
          key: const ValueKey('studio-capture'),
          child: MaterialApp.router(
            routerConfig: router,
            debugShowCheckedModeBanner: false,
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(SlideStudioPage)));
  Future<void> reveal(WidgetTester tester, Finder target) async {
    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('studio-body')),
          matching: find.byType(Scrollable),
        )
        .first;
    if (target.evaluate().isEmpty) {
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(target, 180, scrollable: scrollable);
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester) async {
    await reveal(tester, find.byKey(const ValueKey('studio-wod')));
    await tester.enterText(
      find.byKey(const ValueKey('studio-wod')),
      'Run 800m\nSquat 22.5kg × 12',
    );
    await tester.tap(find.byKey(const ValueKey('studio-generate')));
    await tester.pumpAndSettle();
  }

  for (final scene in [
    (size: const Size(390, 844), scale: 1.0),
    (size: const Size(834, 1194), scale: 1.0),
    (size: const Size(1440, 1000), scale: 1.0),
    (size: const Size(320, 568), scale: 2.0),
    (size: const Size(844, 390), scale: 2.0),
  ]) {
    testWidgets(
      'unified creation and fixed action area ${scene.size} x${scene.scale}',
      (tester) async {
        tester.view.physicalSize = scene.size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scene.scale;
        tester.view.padding = const FakeViewPadding(bottom: 20);
        tester.view.viewPadding = const FakeViewPadding(bottom: 20);
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final repository = FakeStudioRepository();
        await loadLayoutFonts(tester);
        await mount(tester, repository);
        expect(find.byKey(const ValueKey('ai-creation-tabs')), findsNothing);
        expect(find.byKey(const ValueKey('studio-more')), findsOneWidget);
        expect(find.byKey(const ValueKey('studio-generate')), findsOneWidget);
        expect(
          tester.getRect(find.byKey(const ValueKey('studio-generate'))).bottom,
          lessThanOrEqualTo(scene.size.height - 20),
        );
        expect(repository.generations, 0);
        expect(repository.prepares, 0);
        expect(
          container(tester).read(slideStudioControllerProvider).result,
          isNull,
        );
        await captureLayout(
          tester,
          find.byKey(const ValueKey('studio-capture')),
          'sta203-${scene.size.width.toInt()}-${scene.scale}',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'local result visual evidence keeps the current text and 16:9 preview',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1550);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await loadLayoutFonts(tester);
      final repository = FakeStudioRepository();
      await mount(tester, repository);
      await enter(tester);
      await reveal(tester, find.byKey(const ValueKey('studio-save')));
      final scrollable = find
          .descendant(
            of: find.byKey(const ValueKey('studio-body')),
            matching: find.byType(Scrollable),
          )
          .first;
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      await captureLayout(
        tester,
        find.byKey(const ValueKey('studio-capture')),
        'sta203-local-result',
      );
      expect(
        container(tester)
            .read(slideStudioControllerProvider)
            .result!
            .draft!
            .lines,
        ['Run 800m', 'Squat 22.5kg × 12'],
      );
      expect(tester.takeException(), isNull);
    },
    skip: layoutEvidenceDirectory.isEmpty,
  );
  testWidgets(
    'input IME/cursor survives expand/collapse and more selection preserves draft',
    (tester) async {
      tester.view.physicalSize = const Size(834, 1194);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = FakeStudioRepository();
      await mount(tester, repository);
      final field = find.byKey(const ValueKey('studio-wod'));
      await reveal(tester, field);
      await tester.tap(field);
      await tester.showKeyboard(field);
      const editing = TextEditingValue(
        text: '스쿼트 10회\n한',
        selection: TextSelection.collapsed(offset: 9),
        composing: TextRange(start: 8, end: 9),
      );
      tester.testTextInput.updateEditingValue(editing);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('studio-expand-input')));
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.value, editing);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '스쿼트 10회\n한국어 5회',
          selection: TextSelection.collapsed(offset: 14),
        ),
      );
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('studio-more')));
      await tester.tap(find.byKey(const ValueKey('studio-more')));
      await tester.pumpAndSettle();
      final last = find.descendant(
        of: find.byType(GridView),
        matching: find.byKey(
          const ValueKey('studio-design-catalog-red-impact'),
        ),
      );
      await tester.scrollUntilVisible(
        last,
        300,
        scrollable: find.descendant(
          of: find.byType(GridView),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      await tester.tap(last);
      await tester.pumpAndSettle();
      final state = container(tester).read(slideStudioControllerProvider);
      expect(state.input.design.id, 'catalog-red-impact');
      expect(state.input.raw, '스쿼트 10회\n한국어 5회');
      expect(
        tester.widget<TextField>(field).controller!.selection.baseOffset,
        14,
      );
      expect(repository.generations, 0);
      expect(repository.prepares, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'local generation, independent save, dirty guard, and add return only reviewed result',
    (tester) async {
      tester.view.physicalSize = const Size(834, 1194);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = FakeStudioRepository();
      List<WorkoutModule>? added;
      await mount(tester, repository, onResult: (value) => added = value);
      await enter(tester);
      await reveal(tester, find.byKey(const ValueKey('studio-save')));
      expect(find.text('아직 저장되지 않았어요'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('studio-save')));
      await tester.pumpAndSettle();
      expect(find.text('라이브러리에 저장됨'), findsOneWidget);
      expect(repository.saves, 1);
      expect(repository.generations, 0);
      await reveal(tester, find.byKey(const ValueKey('studio-wod')));
      await tester.enterText(
        find.byKey(const ValueKey('studio-wod')),
        'Run 200m',
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('studio-add')));
      final add = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('studio-add')),
      );
      expect(add.onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('studio-generate')));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('studio-add')));
      await tester.tap(find.byKey(const ValueKey('studio-add')));
      await tester.pumpAndSettle();
      expect(added!.single.text, 'Run 200m');
      expect(repository.saves, 1);
    },
  );
  testWidgets(
    'usage failure is unknown, retry recovers; exhausted AI remains distinct from free template',
    (tester) async {
      final repository = FakeStudioRepository()
        ..usageFailure = Exception('offline');
      await mount(tester, repository);
      expect(find.text('사용량 미확인'), findsOneWidget);
      expect(find.textContaining('0회 남음'), findsNothing);
      repository.usageFailure = null;
      await tester.tap(find.byTooltip('사용량 새로고침'));
      await tester.pumpAndSettle();
      expect(find.textContaining('8회 남음'), findsOneWidget);
      final controller = container(tester)
          .read(slideStudioControllerProvider.notifier);
      repository.currentUsage = repository.currentUsage.copyWith(
        remaining: 0,
        used: 10,
      );
      await controller.refreshUsage();
      controller.edit(
        container(tester)
            .read(slideStudioControllerProvider)
            .input
            .copyWith(mode: StudioMode.organize),
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('studio-generate')))
            .onPressed,
        isNull,
      );
      controller.edit(
        container(tester)
            .read(slideStudioControllerProvider)
            .input
            .copyWith(mode: StudioMode.template),
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('studio-generate')))
            .onPressed,
        isNotNull,
      );
    },
  );
  testWidgets(
    'keyboard keeps the action above its inset and library visit preserves input',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = FakeStudioRepository();
      await mount(tester, repository);
      final field = find.byKey(const ValueKey('studio-wod'));
      await reveal(tester, field);
      await tester.enterText(field, 'Run 5km');
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('studio-generate'))).bottom,
        lessThanOrEqualTo(524),
      );
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('저장된 슬라이드'));
      await tester.pumpAndSettle();
      expect(find.text('saved library route'), findsOneWidget);
      GoRouter.of(tester.element(find.text('saved library route'))).pop();
      await tester.pumpAndSettle();
      expect(
        container(tester).read(slideStudioControllerProvider).input.raw,
        'Run 5km',
      );
      expect(repository.generations, 0);
    },
  );
  testWidgets(
    'discard cancel retains input and confirmed discard creates fresh session',
    (tester) async {
      final repository = FakeStudioRepository();
      await mount(tester, repository);
      await reveal(tester, find.byKey(const ValueKey('studio-wod')));
      await tester.enterText(
        find.byKey(const ValueKey('studio-wod')),
        'Run 5km',
      );
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('계속 편집'));
      await tester.pumpAndSettle();
      expect(
        container(tester).read(slideStudioControllerProvider).input.raw,
        'Run 5km',
      );
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장 안 하고 나가기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        container(tester).read(slideStudioControllerProvider).input.raw,
        isEmpty,
      );
      expect(repository.generations, 0);
    },
  );
}
