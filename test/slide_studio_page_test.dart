import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_catalog.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';
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
import 'support/template_jobs_fakes.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/template_job.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/template_jobs_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/template_job_image.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/template_jobs_actions.dart';

import 'support/ui_layout_evidence.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    FakeStudioRepository repository, {
    ValueChanged<List<WorkoutModule>?>? onResult,
    Stream<CenterSlideCatalog>? catalog,
    CenterSlideCatalogScope? scope,
    List<AiSlideDesign> savedDesigns = const [],
    FakeTemplateJobsRepository? jobs,
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
              builder: (_, _) => savedDesigns.isEmpty
                  ? AiSlidesPage(guard: guard)
                  : ProviderScope(
                      overrides: [
                        aiSlideDesignControllerProvider.overrideWith(
                          () => _SavedDesigns(savedDesigns),
                        ),
                      ],
                      child: SlideStudioPage(guard: guard),
                    ),
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
          centerSlideCatalogScopeProvider.overrideWithValue(scope),
          centerSlideCatalogProvider.overrideWith(
            (_) => catalog ?? Stream.value(emptyCenterSlideCatalog()),
          ),
          centerSlideBackgroundProvider(templateTestDesign.theme.centerRecipe!)
              .overrideWith((_) async => null),
          templateJobsActionsProvider.overrideWithValue(
            TemplateJobsActions(jobs ?? FakeTemplateJobsRepository()),
          ),
          slideStudioActionsProvider.overrideWithValue(
            SlideStudioActions(repository),
          ),
          aiRasterActionsProvider.overrideWith(
            (_) => throw StateError(
              'Template studio must not read raster actions',
            ),
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

  Future<void> details(WidgetTester tester) async {
    final toggle = find.byKey(const ValueKey('studio-expand-details'));
    await reveal(tester, toggle);
    if (find.byKey(const ValueKey('studio-subtitle')).evaluate().isEmpty) {
      await tester.tap(toggle);
      await tester.pumpAndSettle();
    }
  }

  Future<void> guidance(WidgetTester tester, [String value = '운동 안내']) async {
    await details(tester);
    final field = find.descendant(
      of: find.byKey(const ValueKey('studio-subtitle')),
      matching: find.byType(TextField),
    );
    await reveal(tester, field);
    await tester.enterText(field, value);
  }

  Future<void> enter(WidgetTester tester) async {
    if (container(tester)
        .read(slideStudioControllerProvider)
        .input
        .subtitle
        .trim()
        .isEmpty) {
      await guidance(tester);
    }
    await reveal(tester, find.byKey(const ValueKey('studio-wod')));
    await tester.enterText(
      find.byKey(const ValueKey('studio-wod')),
      'Run 800m\nSquat 22.5kg × 12',
    );
    await tester.tap(find.byKey(const ValueKey('studio-generate')));
    await tester.pumpAndSettle();
  }

  for (final center in [false, true]) {
    testWidgets(
      'blank guidance focuses inline error before ${center ? "center" : "basic"} generation',
      (tester) async {
        tester.view.physicalSize = const Size(834, 1194);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final repository = FakeStudioRepository(),
            jobs = FakeTemplateJobsRepository();
        await mount(
          tester,
          repository,
          jobs: jobs,
          scope: center
              ? const CenterSlideCatalogScope(
                  ownerId: 'local-owner',
                  centerId: 'local-center',
                )
              : null,
          catalog: center
              ? Stream.value(
                  CenterSlideCatalog(
                    revision: 1,
                    centerId: 'local-center',
                    centerName: 'local',
                    templates: [templateTestDesign],
                  ),
                )
              : null,
        );
        if (center) {
          await tester.tap(
            find.byKey(const ValueKey('studio-category-center')),
          );
          await tester.pumpAndSettle();
        }
        await guidance(tester, '   ');
        await reveal(
          tester,
          find.byKey(const ValueKey('studio-expand-details')),
        );
        await tester.tap(find.byKey(const ValueKey('studio-expand-details')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('studio-subtitle')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('studio-generate')));
        await tester.pumpAndSettle();
        expect(find.text('운동 안내 문구 (필수)'), findsOneWidget);
        expect(find.text('운동 안내 문구를 입력해 주세요. 공백만 입력할 수 없어요.'), findsOneWidget);
        final field = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const ValueKey('studio-subtitle')),
            matching: find.byType(TextField),
          ),
        );
        expect(field.focusNode!.hasFocus, true);
        expect(repository.validations, 0);
        expect(jobs.enqueues, 0);
      },
    );
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
    'template-only controls keep title guidance and raw text with no paid or raster requests',
    (tester) async {
      tester.view.physicalSize = const Size(834, 1194);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = FakeStudioRepository();
      await mount(tester, repository);
      for (final key in [
        'studio-reference',
        'studio-options',
        'studio-brief',
        'studio-usage-tokens',
        'studio-completed-operation',
      ]) {
        expect(find.byKey(ValueKey(key)), findsNothing);
      }
      for (final label in ['AI 내용 정리', 'AI 스타일 제안', 'AI 배경 이미지']) {
        expect(find.text(label), findsNothing);
      }
      Future<void> edit(String key, String value) async {
        await details(tester);
        final field = find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(TextField),
        );
        await reveal(tester, field);
        await tester.enterText(field, value);
      }

      await edit('studio-title', '아침 수업');
      await edit('studio-subtitle', '5mins On / 90s Off');
      await enter(tester);
      final result = container(tester)
          .read(slideStudioControllerProvider)
          .result!;
      expect(result.draft!.title, '아침 수업');
      expect(result.draft!.designSubtitle, '5mins On / 90s Off');
      expect(result.draft!.lines, ['Run 800m', 'Squat 22.5kg × 12']);
      expect(result.input.mode, StudioMode.template);
      expect(repository.generations, 0);
      expect(repository.statuses, 0);
      expect(repository.usageReads, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'center catalog and basic saved sources stay separate including more and late loading',
    (tester) async {
      tester.view.physicalSize = const Size(834, 1194);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final catalog = StreamController<CenterSlideCatalog>();
      addTearDown(catalog.close);
      catalog.add(emptyCenterSlideCatalog('center-a'));
      final center = aiSlideDesignCatalog.first.copyWith(
        id: 'center-only',
        name: '센터 원본',
      );
      final personal = aiSlideDesignCatalog.first.copyWith(
        id: 'personal',
        name: '내 저장 디자인',
      );
      final stalePrivate = personal.copyWith(
        id: 'stale-private',
        theme: personal.theme.copyWith(
          centerRecipe: const CenterSlideRecipe(
            templateId: 'private',
            revision: 1,
            centerId: 'other',
            width: 1920,
            height: 1080,
            backgroundColor: 0xff000000,
            fields: [],
          ),
        ),
      );
      final repository = FakeStudioRepository();
      await mount(
        tester,
        repository,
        catalog: catalog.stream,
        scope: const CenterSlideCatalogScope(
          ownerId: 'local-owner',
          centerId: 'center-a',
        ),
        savedDesigns: [personal, stalePrivate],
      );
      expect(find.text('센터 전용'), findsOneWidget);
      expect(find.text('기본 템플릿'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('studio-design-catalog-focus')),
      );
      await tester.pumpAndSettle();
      catalog.add(
        CenterSlideCatalog(
          revision: 1,
          centerId: 'center-a',
          centerName: '센터',
          templates: [center],
        ),
      );
      await tester.pumpAndSettle();
      expect(
        container(tester).read(slideStudioControllerProvider).input.design.id,
        'catalog-focus',
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('studio-category-basic')),
            )
            .selected,
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('studio-design-center-only')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('studio-more')));
      await tester.pumpAndSettle();
      expect(find.text('기본 템플릿 더보기'), findsOneWidget);
      final grid = find.byType(GridView);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('studio-design-personal')),
        300,
        scrollable: find.descendant(
          of: grid,
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('내 저장 디자인'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('studio-design-stale-private')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('studio-design-center-only')),
        findsNothing,
      );
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('studio-category-center')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('studio-design-catalog-banner')),
        findsNothing,
      );
      expect(find.text('센터 원본'), findsOneWidget);
      await enter(tester);
      expect(
        container(tester)
            .read(slideStudioControllerProvider)
            .result!
            .input
            .design,
        center,
      );
      await reveal(tester, find.byKey(const ValueKey('studio-more')));
      expect(
        container(tester).read(slideStudioControllerProvider).input.design,
        center,
      );
      await tester.tap(find.byKey(const ValueKey('studio-more')));
      await tester.pumpAndSettle();
      expect(find.text('센터 전용 더보기'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GridView),
          matching: find.byKey(const ValueKey('studio-design-center-only')),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('studio-design-personal')),
        findsNothing,
      );
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      catalog.addError(Exception('permission denied'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('studio-design-center-only')),
        findsNothing,
      );
      expect(find.textContaining('센터 전용 템플릿을 불러오지 못했어요'), findsOneWidget);
      expect(find.textContaining('현재 사용할 수 있는 센터 전용'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('studio-generate')))
            .onPressed,
        isNull,
      );
      expect(
        container(tester).read(slideStudioControllerProvider).input.design,
        center,
      );
      await reveal(tester, find.byKey(const ValueKey('studio-category-basic')));
      await tester.tap(find.byKey(const ValueKey('studio-category-basic')));
      await tester.pumpAndSettle();
      expect(
        container(tester).read(slideStudioControllerProvider).input.design.id,
        'catalog-focus',
      );
      expect(repository.generations, 0);
      expect(repository.usageReads, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'center loading is not an empty catalog and cannot generate a hidden basic design',
    (tester) async {
      final catalog = StreamController<CenterSlideCatalog>();
      addTearDown(catalog.close);
      await mount(
        tester,
        FakeStudioRepository(),
        catalog: catalog.stream,
        scope: const CenterSlideCatalogScope(
          ownerId: 'local-owner',
          centerId: 'center-a',
        ),
      );
      await tester.tap(find.byKey(const ValueKey('studio-category-center')));
      await tester.pump();
      expect(find.text('센터 전용 템플릿을 불러오는 중이에요.'), findsOneWidget);
      expect(find.textContaining('현재 사용할 수 있는 센터 전용'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('studio-generate')))
            .onPressed,
        isNull,
      );
      catalog.add(emptyCenterSlideCatalog('center-a'));
      await tester.pumpAndSettle();
      expect(find.textContaining('현재 사용할 수 있는 센터 전용'), findsOneWidget);
      expect(find.text('센터 전용 템플릿을 불러오는 중이에요.'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('studio-category-basic')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('studio-generate')))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
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
      expect(tester.widget<TextField>(field).maxLines, 3);
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
      expect(find.text('미저장'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('studio-save')));
      await tester.pumpAndSettle();
      expect(find.text('저장됨'), findsOneWidget);
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
    'server usage shows loading failure remaining exhausted and unlimited without charging template',
    (tester) async {
      final repository = _DelayedUsage();
      await mount(tester, repository);
      expect(find.text('AI 남은 횟수 조회 중…'), findsOneWidget);
      expect(find.textContaining('0회 남음'), findsNothing);
      repository.usageFailure = Exception('offline');
      repository.ready.complete();
      await tester.pumpAndSettle();
      expect(find.text('AI 남은 횟수 미확인'), findsOneWidget);
      expect(find.textContaining('사용량을 불러오지 못했어요'), findsOneWidget);
      repository.usageFailure = null;
      await tester.tap(find.byTooltip('사용량 새로고침'));
      await tester.pumpAndSettle();
      expect(find.text('AI 8회 남음 · 2/10회 사용'), findsOneWidget);
      repository.currentUsage = repository.currentUsage.copyWith(
        remaining: 0,
        used: 10,
      );
      await tester.tap(find.byTooltip('사용량 새로고침'));
      await tester.pumpAndSettle();
      expect(find.text('AI 0회 남음 · 10/10회 사용'), findsOneWidget);
      expect(find.text('기본 템플릿은 AI 없이 무료로 생성해요.'), findsOneWidget);
      await enter(tester);
      expect(repository.generations, 0);
      expect(
        container(tester).read(slideStudioControllerProvider).result,
        isNotNull,
      );
      repository.usageFailure = Exception('offline');
      await tester.tap(find.byTooltip('사용량 새로고침'));
      await tester.pumpAndSettle();
      expect(find.text('AI 0회 남음 · 10/10회 사용'), findsOneWidget);
      expect(find.text('사용량 갱신 실패 · 마지막 확인 값'), findsOneWidget);
      repository.usageFailure = null;
      repository.currentUsage = repository.currentUsage.copyWith(
        unlimited: true,
        remaining: null,
        limit: null,
      );
      await tester.tap(find.byTooltip('사용량 새로고침'));
      await tester.pumpAndSettle();
      expect(find.text('AI 생성 횟수 무제한'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'old paid mode and exhausted quota still generate only a free template',
    (tester) async {
      final repository = FakeStudioRepository()
        ..usageFailure = Exception('offline');
      await mount(tester, repository);
      final c = container(tester);
      c
          .read(slideStudioControllerProvider.notifier)
          .edit(
            c
                .read(slideStudioControllerProvider)
                .input
                .copyWith(mode: StudioMode.artwork, brief: 'old paid request'),
          );
      await enter(tester);
      expect(
        c.read(slideStudioControllerProvider).result!.input.mode,
        StudioMode.template,
      );
      expect(repository.generations, 0);
      expect(repository.usageReads, 1);
      expect(repository.validations, 1);
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
      await tester.tap(find.byTooltip('AI 생성 슬라이드 관리'));
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
    'center enqueue releases input and navigation, completion opens exact server PNG without replacing draft',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final jobs = FakeTemplateJobsRepository()
        ..enqueueWait = Completer<TemplateJobsReply>();
      final repository = FakeStudioRepository();
      await mount(
        tester,
        repository,
        jobs: jobs,
        scope: const CenterSlideCatalogScope(
          ownerId: 'local-owner',
          centerId: 'local-center',
        ),
        catalog: Stream.value(
          CenterSlideCatalog(
            revision: 1,
            centerId: 'local-center',
            centerName: 'local',
            templates: [templateTestDesign],
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('studio-category-center')));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('studio-wod')));
      await tester.enterText(
        find.byKey(const ValueKey('studio-wod')),
        'Run 800m',
      );
      await guidance(tester);
      await tester.tap(find.byKey(const ValueKey('studio-generate')));
      await tester.pump();
      expect(jobs.enqueues, 1);
      expect(find.text('생성 접수 중…'), findsOneWidget);
      final job = templateTestJob(jobs.lastId!).copyWith(rawWod: 'Run 800m');
      jobs.enqueueWait!.complete(TemplateJobsReply([job], templateTestUsage));
      await tester.pumpAndSettle();
      expect(
        container(tester).read(templateJobsControllerProvider).submitting,
        false,
      );
      await reveal(tester, find.byKey(const ValueKey('studio-current-job')));
      expect(find.text('슬라이드를 만들고 있어요.'), findsOneWidget);
      expect(find.textContaining('화면을 나가도 계속 생성돼요'), findsOneWidget);
      expect(find.text('입력 내용 보기'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('studio-generate')))
            .onPressed,
        isNull,
      );
      expect(repository.validations, 0);
      expect(repository.generations, 0);
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      expect(find.text('저장하지 않고 나갈까요?'), findsNothing);
      jobs.jobs = [
        templateTestJob('newer-history', status: 'complete', time: 10),
        job.copyWith(status: 'processing'),
      ];
      jobs.enqueueWait = null;
      jobs.assetFailure = const AiSlidesFailure('이미지 읽기 실패');
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        container(tester).read(templateJobsControllerProvider).currentRequestId,
        job.requestId,
      );
      expect(jobs.assets, 0); // Skip newer finished history on re-entry.
      await reveal(tester, find.byKey(const ValueKey('studio-wod')));
      await tester.enterText(
        find.byKey(const ValueKey('studio-wod')),
        '새 수업 5km',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      jobs.jobs = [
        jobs.jobs.first,
        job.copyWith(
          status: 'complete',
          sha256: templateTestJob('one', status: 'complete').sha256,
        ),
      ];
      jobs.events.add(jobs.jobs);
      await tester.pumpAndSettle();
      expect(
        jobs.assets,
        1,
      ); // Only the resumed current job is opened when it completes.
      await reveal(tester, find.text('이미지 다시 불러오기'));
      expect(find.text('이미지 읽기 실패'), findsOneWidget);
      await container(tester)
          .read(templateJobsControllerProvider.notifier)
          .refresh();
      await tester.pumpAndSettle();
      expect(jobs.assets, 1); // No automatic retry after an asset failure.
      jobs.assetFailure = null;
      await tester.tap(find.text('이미지 다시 불러오기'));
      await tester.pumpAndSettle();
      expect(jobs.assets, 2);
      expect(
        container(tester)
            .read(slideStudioControllerProvider)
            .result!
            .templateJob!
            .requestId,
        job.requestId,
      );
      expect(
        container(tester).read(slideStudioControllerProvider).input.raw,
        '새 수업 5km',
      );
      await reveal(tester, find.byKey(const ValueKey('studio-save')));
      expect(find.byType(TemplateJobImage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('studio-save')));
      await tester.pumpAndSettle();
      expect(repository.saves, 1);
      expect(repository.prepares, 0);
      expect(repository.saved.values.single.text, 'Run 800m');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'basic card enlargement preserves selection, source and never generates',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = FakeStudioRepository();
      await mount(tester, repository);
      final before = container(tester)
          .read(slideStudioControllerProvider)
          .input;
      await tester.tap(
        find.byKey(ValueKey('studio-enlarge-${before.design.id}')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byTooltip('확대 보기 닫기'), findsOneWidget);
      await tester.tap(find.byTooltip('확대 보기 닫기'));
      await tester.pumpAndSettle();
      expect(
        container(tester).read(slideStudioControllerProvider).input,
        before,
      );
      expect(repository.generations, 0);
      expect(repository.validations, 0);
    },
  );

  testWidgets(
    'center card enlargement uses selected recipe with pinch and close but no AI request',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final jobs = FakeTemplateJobsRepository(),
          repository = FakeStudioRepository();
      await mount(
        tester,
        repository,
        jobs: jobs,
        scope: const CenterSlideCatalogScope(
          ownerId: 'local-owner',
          centerId: 'local-center',
        ),
        catalog: Stream.value(
          CenterSlideCatalog(
            revision: 1,
            centerId: 'local-center',
            centerName: 'local',
            templates: [templateTestDesign],
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('studio-category-center')));
      await tester.pumpAndSettle();
      final before = container(tester)
          .read(slideStudioControllerProvider)
          .input;
      await reveal(
        tester,
        find.byKey(ValueKey('studio-enlarge-${before.design.id}')),
      );
      await tester.tap(
        find.byKey(ValueKey('studio-enlarge-${before.design.id}')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(
        find.byKey(const ValueKey('center-slide-direct-canvas')),
        findsOneWidget,
      );
      expect(find.byTooltip('확대 보기 닫기'), findsOneWidget);
      await tester.tap(find.byTooltip('확대 보기 닫기'));
      await tester.pumpAndSettle();
      expect(
        container(tester).read(slideStudioControllerProvider).input,
        before,
      );
      expect(jobs.enqueues, 0);
      expect(repository.validations, 0);
    },
  );

  for (final status in ['complete', 'failed']) {
    testWidgets(
      '$status history stays unselected on pristine entry and re-entry',
      (tester) async {
        final history = templateTestJob('history', status: status);
        final jobs = FakeTemplateJobsRepository()..jobs = [history];
        await mount(
          tester,
          FakeStudioRepository(),
          jobs: jobs,
          scope: const CenterSlideCatalogScope(
            ownerId: 'local-owner',
            centerId: 'local-center',
          ),
        );
        for (var entry = 0; entry < 2; entry++) {
          final c = container(tester);
          expect(c.read(templateJobsControllerProvider).jobs, [history]);
          expect(
            c.read(templateJobsControllerProvider).currentRequestId,
            isNull,
          );
          expect(c.read(slideStudioControllerProvider).input.raw, isEmpty);
          expect(c.read(slideStudioControllerProvider).result, isNull);
          expect(jobs.assets, 0);
          expect(jobs.enqueues, 0);
          expect(find.byType(TemplateJobImage), findsNothing);
          if (entry == 0) {
            await tester.tap(find.byTooltip('뒤로'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('open'));
            await tester.pumpAndSettle();
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'failed current job appears in result area without top history cards or automatic retries',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final failed = templateTestJob('failed', status: 'failed');
      final jobs = FakeTemplateJobsRepository()
        ..jobs = [failed.copyWith(status: 'pending')];
      await mount(
        tester,
        FakeStudioRepository(),
        jobs: jobs,
        scope: const CenterSlideCatalogScope(
          ownerId: 'local-owner',
          centerId: 'local-center',
        ),
      );
      expect(
        container(tester).read(templateJobsControllerProvider).currentRequestId,
        failed.requestId,
      );
      jobs.jobs = [failed];
      jobs.events.add(jobs.jobs);
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('studio-current-job')));
      expect(find.text('이미지를 만들지 못했어요.'), findsOneWidget);
      expect(find.text('입력 내용 보기'), findsNothing);
      expect(find.text('센터 생성 이미지'), findsNothing);
      expect(find.text('다시 생성 (AI 1회)'), findsNothing);
      expect(jobs.enqueues, 0);
      expect(jobs.assets, 0);
      jobs.events.addError(
        const AiSlidesFailure('revoked', code: 'permission-denied'),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('template-source-failed')),
        findsNothing,
      );
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

class _SavedDesigns extends AiSlideDesignController {
  _SavedDesigns(this.designs);
  final List<AiSlideDesign> designs;
  @override
  AiSlideDesignStudioState build() =>
      AiSlideDesignStudioState(templates: designs);
}

class _DelayedUsage extends FakeStudioRepository {
  final ready = Completer<void>();
  @override
  Future<StudioUsage> usage({String? requestId, bool raster = false}) async {
    await ready.future;
    return super.usage(requestId: requestId, raster: raster);
  }
}
