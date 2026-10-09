import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slide_design_controller.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_design_colors.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/ai_slides_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/ai_slides_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slides_controller.dart';

import 'support/ai_slides_editor_fakes.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_slides_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_page.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_design_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/original_slide_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/original_slide_template.dart';

const draft = AiSlideDraft(
  title: 'WARM UP',
  layout: 'numbered',
  lines: ['Squat 10 reps', '런지 12회', 'Jumping Jack 20 reps'],
  workSeconds: 300,
  restSeconds: 0,
  sets: 1,
);

class FakeAiSlidesRepository implements AiSlidesRepository {
  bool premium = true;
  int calls = 0;
  int accessCalls = 0;
  Object? accessFailure;
  Completer<AiSlidesResult>? pending;
  Object? failure;
  AiSlidesResult result = const AiSlidesResult(
    slides: [draft],
    warnings: [],
    remaining: 29,
  );
  @override
  Future<AiSlidesAccess> access() async {
    accessCalls++;
    if (accessFailure != null) throw accessFailure!;
    return AiSlidesAccess(
      premium: premium,
      enabled: true,
      remaining: 30,
      limit: 30,
    );
  }

  @override
  Future<AiSlidesResult> generate(String prompt) async {
    calls++;
    if (failure != null) throw failure!;
    return pending?.future ?? result;
  }
}

void main() {
  test('confirmation preserves explicit timings and uses normal defaults for missing values', () {
    for (final incomplete in [
      draft.copyWith(sets: 0),
      draft.copyWith(workSeconds: 3601),
    ]) {
      expect(
        () => confirmAiSlide(incomplete, 'slide'),
        throwsA(isA<AiSlidesFailure>()),
      );
    }
    final module = confirmAiSlide(draft, 'slide');
    expect(module.workSeconds, 300);
    expect(module.restSeconds, 0);
    expect(module.sets, 1);
    final defaults = WorkoutModule.empty('defaults');
    expect(module.includeFinalRest, defaults.includeFinalRest);
    final untimed = confirmAiSlide(
      draft.copyWith(workSeconds: null, restSeconds: null, sets: null),
      'untimed',
    );
    expect(untimed.workSeconds, defaults.workSeconds);
    expect(untimed.restSeconds, defaults.restSeconds);
    expect(untimed.sets, defaults.sets);
    final partial = confirmAiSlide(
      draft.copyWith(restSeconds: null),
      'partial',
    );
    expect(partial.workSeconds, 300);
    expect(partial.restSeconds, defaults.restSeconds);
    expect(module.text, contains('Squat 10 reps'));
    expect(module.designTemplate, 'stationd-v2-numbered');
    expect(
      module.appearance.showTitle,
      false,
      reason: 'Old clients must not duplicate baked text',
    );
    expect(
      () => confirmAiSlide(
        draft.copyWith(lines: List.filled(25, 'Squat')),
        'slide',
      ),
      throwsA(isA<AiSlidesFailure>()),
    );
  });
  test('theme and edits survive Firestore/library DTO roundtrips; old slides omit optional field', () {
    final original = WorkoutModule.empty('old');
    final oldJson = WorkoutModuleModel.fromEntity(original).toJson();
    expect(oldJson.containsKey('designTemplate'), false);
    expect(oldJson.containsKey('designAccentColor'), false);
    expect(WorkoutModuleModel.fromJson(oldJson).toEntity(), original);
    final edited = confirmAiSlide(
      draft.copyWith(
        designBackgroundColor: 0xFFF6F5F0,
        designTextColor: 0xFF151515,
        designAccentColor: 0xFF2876E8,
      ),
      'slide',
    ).copyWith(name: '새 제목', text: '런지 15회', workSeconds: 45);
    expect(
      WorkoutModuleModel.fromJson(
        WorkoutModuleModel.fromEntity(edited).toJson(),
      ).toEntity(),
      edited,
    );
  });
  test('free users never make a generation request', () async {
    final repository = FakeAiSlidesRepository()..premium = false;
    await expectLater(
      AiSlidesActions(repository).generate('수업 내용'),
      throwsA(isA<AiSlidesFailure>()),
    );
    expect(repository.calls, 0);
  });

  Future<void> mount(
    WidgetTester tester,
    FakeAiSlidesRepository repository,
    ValueChanged<List<WorkoutModule>?> onResult,
  ) async {
    await tester.runAsync(
      () => Future.wait(
        originalSlideTemplates.map(
          (template) => loadOriginalSlideImage(template.id),
        ),
      ),
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () async => onResult(await showAiSlidesPage(context)),
              child: const Text('open'),
            ),
          ),
          routes: [
            GoRoute(
              path: 'images/create',
              builder: (_, _) => const AiSlidesPage(),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiSlideDesignOwnerIdProvider.overrideWithValue(null),
          aiSlideDesignStoreIdProvider.overrideWithValue(null),
          aiSlidesRepositoryProvider.overrideWithValue(repository),
          aiSlidesOwnerIdProvider.overrideWithValue('test-owner'),
          aiSlidesEditorRepositoryProvider.overrideWithValue(
            MemoryAiSlidesEditorRepository(),
          ),
        ],
        child: RepaintBoundary(
          key: const ValueKey('capture'),
          child: MaterialApp.router(
            routerConfig: router,
            debugShowCheckedModeBanner: false,
            theme: XonTheme.light,
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    final scrollable = find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(target, 160, scrollable: scrollable);
    await tester.pumpAndSettle();
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> generate(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('ai-nav-create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('ai-slides-prompt')),
      'WARM UP 스쿼트 10회, 운동 5분, 휴식 없음, 1세트',
    );
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const ValueKey('ai-slides-generate')));
    await tester.tap(find.byKey(const ValueKey('ai-slides-generate')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shared usage recovers with retry and survives generation mode changes',
    (tester) async {
      final repository = FakeAiSlidesRepository()
        ..accessFailure = const AiSlidesFailure('연결 실패');
      await mount(tester, repository, (_) {});
      await tester.tap(find.byKey(const ValueKey('ai-nav-create')));
      await tester.pumpAndSettle();
      expect(find.text('사용량을 불러오지 못했어요.'), findsOneWidget);
      expect(find.byKey(const ValueKey('ai-generation-usage')), findsOneWidget);
      repository.accessFailure = null;
      await tester.tap(find.text('새로고침'));
      await tester.pumpAndSettle();
      expect(find.text('30/30회 남음'), findsOneWidget);
      final reads = repository.accessCalls;
      for (final mode in ['스타일 제안', '이미지로 시작', '수업 메모']) {
        await tester.tap(find.text(mode).first);
        await tester.pumpAndSettle();
        expect(find.text('30/30회 남음'), findsOneWidget);
      }
      expect(repository.accessCalls, reads);
      expect(repository.calls, 0);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(834, 1194),
  ]) {
    testWidgets('review/edit/add remains responsive at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      if (const bool.fromEnvironment('AI_SLIDES_CAPTURE')) {
        await (FontLoader('Pretendard')..addFont(
              rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'),
            ))
            .load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      }
      final repository = FakeAiSlidesRepository();
      List<WorkoutModule>? added;
      await mount(tester, repository, (value) => added = value);
      expect(repository.calls, 0);
      expect(find.text('beta'), findsOneWidget);
      expect(find.text('수업 이미지 생성'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      await generate(tester);
      expect(repository.calls, 1);
      expect(added, isNull);
      await tester.tap(find.byKey(const ValueKey('ai-nav-templates')));
      await tester.pumpAndSettle();
      final palette = find.byType(SlideDesignColors);
      await reveal(tester, palette);
      final colors = tester.widget<SlideDesignColors>(palette);
      colors.onChanged(
        colors.module.copyWith(
          designBackgroundColor: 0xFFF6F5F0,
          designTextColor: 0xFF151515,
          designAccentColor: 0xFF2876E8,
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.calls, 1, reason: 'Theme changes must never call AI');
      expect(find.text('운동(초)'), findsNothing);
      expect(find.text('휴식(초)'), findsNothing);
      expect(find.text('마지막 세트의 휴식 포함'), findsNothing);
      if (const bool.fromEnvironment('AI_SLIDES_CAPTURE')) {
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('capture')),
          );
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/cloudboard-ai-slides-${size.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      final add = find.byKey(const ValueKey('ai-slides-add'));
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(added?.single.workSeconds, 300);
      expect(added?.single.designAccentColor, 0xFF2876E8);
      expect(slideColor(added!.single, rest: false, text: true), 0xFF151515);
      expect(repository.calls, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'missing timing can be added immediately; closing a later draft does not apply it',
    (tester) async {
      final repository = FakeAiSlidesRepository()
        ..result = AiSlidesResult(
          slides: [
            draft.copyWith(workSeconds: null, restSeconds: null, sets: null),
          ],
          warnings: [],
          remaining: 29,
        );
      List<WorkoutModule>? added;
      await mount(tester, repository, (value) => added = value);
      await generate(tester);
      expect(find.textContaining('시간 · 세트 확인 필요'), findsNothing);
      final add = find.byKey(const ValueKey('ai-slides-add'));
      await tester.tap(add);
      await tester.pumpAndSettle();
      final defaults = WorkoutModule.empty('defaults');
      expect(added?.single.workSeconds, defaults.workSeconds);
      expect(added?.single.restSeconds, defaults.restSeconds);
      expect(added?.single.sets, defaults.sets);
      added = null;
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      await generate(tester);
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      expect(added, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'nonpremium opening/typing stays free; pending generation ignores duplicate taps and closes safely',
    (tester) async {
      final repository = FakeAiSlidesRepository()..premium = false;
      await mount(tester, repository, (_) {});
      await tester.tap(find.byKey(const ValueKey('ai-nav-create')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('ai-slides-prompt')),
        'notes',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('ai-slides-generate')),
            )
            .onPressed,
        isNull,
      );
      expect(repository.calls, 0);
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      repository.premium = true;
      repository.pending = Completer<AiSlidesResult>();
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ai-nav-create')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('ai-slides-prompt')),
        'notes',
      );
      await tester.pump();
      await reveal(tester, find.byKey(const ValueKey('ai-slides-generate')));
      await tester.tap(find.byKey(const ValueKey('ai-slides-generate')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('ai-slides-generate')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.byKey(const ValueKey('ai-slides-generate')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(repository.calls, 1);
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pump(const Duration(seconds: 1));
      repository.pending!.complete(repository.result);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'edited sections survive close and failed regeneration without extra generation',
    (tester) async {
      final repository = FakeAiSlidesRepository()
        ..result = const AiSlidesResult(
          slides: [
            AiSlideDraft(
              title: 'CIRCUIT',
              layout: 'list',
              lines: ['## WARM UP', 'Squat 10 reps', '## MAIN', 'RUN 1km'],
              showTimer: false,
            ),
          ],
          warnings: [],
          remaining: 29,
        );
      await mount(tester, repository, (_) {});
      await generate(tester);
      expect(find.byType(CheckboxListTile), findsNothing);
      await reveal(tester, find.byKey(const ValueKey('ai-slide-title')));
      await tester.enterText(
        find.byKey(const ValueKey('ai-slide-title')),
        '수정한 수업',
      );
      await tester.pumpAndSettle();
      final lines = find.byKey(const ValueKey('ai-section-0-lines'));
      await reveal(tester, lines);
      await tester.enterText(lines, 'Squat 10 reps\nRun 200m');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(lines).controller!.text,
        'Squat 10 reps\nRun 200m',
      );
      await tester.tap(find.byTooltip('뒤로'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('ai-slide-title')))
            .controller!
            .text,
        '수정한 수업',
      );
      await reveal(tester, lines);
      expect(
        tester.widget<TextField>(lines).controller!.text,
        contains('Run 200m'),
      );
      await tester.tap(find.byKey(const ValueKey('ai-nav-create')));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('ai-slides-generate')));
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('ai-slides-generate')),
            )
            .onPressed,
        isNull,
      );
      repository.failure = const AiSlidesFailure('연결을 확인해 주세요.');
      await tester.enterText(
        find.byKey(const ValueKey('ai-slides-prompt')),
        '변경한 수업 내용',
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('ai-slides-generate')));
      await tester.tap(find.byKey(const ValueKey('ai-slides-generate')));
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      expect(find.text('연결을 확인해 주세요.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ai-nav-content')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('ai-slide-title')))
            .controller!
            .text,
        '수정한 수업',
      );
      await reveal(tester, lines);
      expect(
        tester.widget<TextField>(lines).controller!.text,
        'Squat 10 reps\nRun 200m',
      );
      expect(repository.calls, 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('keyboard and large text keep editor usable on narrow phone', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repository = FakeAiSlidesRepository();
    await mount(tester, repository, (_) {});
    await generate(tester);
    await reveal(tester, find.byKey(const ValueKey('ai-slide-title')));
    await tester.tap(find.byKey(const ValueKey('ai-slide-title')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    final title = find.byKey(const ValueKey('ai-slide-title'));
    await tester.enterText(title, '');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(title).decoration!.errorText,
      '제목을 입력해 주세요.',
    );
    expect(find.textContaining('1~60자'), findsNothing);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('ai-slides-add')))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey('ai-slide-title')),
      '휴대폰 편집',
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(title).decoration!.errorText, isNull);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('ai-slides-add')))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai-slides-add')), findsOneWidget);
  });
  testWidgets(
    'PNG export is 16:9, changes after edits, and supports every layout',
    (tester) async {
      await tester.runAsync(() async {
        await (FontLoader('Pretendard')..addFont(
              rootBundle.load('assets/fonts/pretendard/Pretendard-Bold.otf'),
            ))
            .load();
        for (final layout in ['numbered', 'list', 'interval']) {
          final module = confirmAiSlide(
            draft.copyWith(layout: layout),
            'export',
          );
          final source = await renderSlideDesign(module);
          expect(
            await renderSlideDesign(
              module.copyWith(
                workSeconds: 45,
                restSeconds: 15,
                sets: 8,
                intervalBlocks: const [
                  WorkoutIntervalBlock(
                    id: 'custom',
                    workSeconds: 30,
                    restSeconds: 10,
                    sets: 3,
                  ),
                ],
              ),
            ),
            source,
            reason: 'Timer settings must not add text to the slide artwork',
          );
          final bytes = base64Decode(source.split(',').last);
          final decoded = img.decodePng(bytes)!;
          expect(decoded.width, 1920);
          expect(decoded.height, 1080);
          expect(
            await renderSlideDesign(
              module.copyWith(text: '다른 운동 12회', workSeconds: 60),
            ),
            isNot(source),
          );
          if (const bool.fromEnvironment('AI_SLIDES_CAPTURE')) {
            await File('/tmp/cloudboard-slide-$layout.png').writeAsBytes(bytes);
          }
        }
        final dense = confirmAiSlide(
          draft.copyWith(
            layout: 'list',
            title: 'WAVE ZONE · FULL SESSION',
            lines: [
              'CASH IN',
              'RUN 1km',
              'SKI 1km',
              'SLED PUSH 50m',
              'MAIN · 6 STATION',
              'RUN 400m',
              'ROW 500m',
              'DUMBBELL SNATCH (ALTER) 20 reps',
              'DUMBBELL LUNGE 20 reps',
              'BOX JUMP OVER (STEP DOWN) 15 reps',
              'BURPEE OVER THE WAVE 10 reps',
              'CASH OUT',
              'RUN 1km',
              'SKI 1km',
              'SLED PULL 50m',
              'REST 2min',
              'ROUND 2',
              'ROW 500m',
              'LUNGE 20 reps',
              'PUSH UP 15 reps',
              'AIR SQUAT 20 reps',
              'BURPEE 10 reps',
              'WALK 200m',
              'COOL DOWN',
            ],
            designBackgroundColor: 0xFFF6F5F0,
            designTextColor: 0xFF151515,
            designAccentColor: 0xFF2876E8,
          ),
          'dense',
        );
        for (final showTimer in [true, false]) {
          final data = await renderSlideDesign(
            dense.copyWith(showTimer: showTimer),
          );
          final bytes = base64Decode(data.split(',').last);
          final decoded = img.decodePng(bytes)!;
          final background = decoded.getPixel(0, 0);
          expect([background.r, background.g, background.b], [246, 245, 240]);
          expect(dense.text.split('\n'), hasLength(24));
          if (const bool.fromEnvironment('AI_SLIDES_CAPTURE')) {
            await File('/tmp/cloudboard-slide-dense-$showTimer.png')
                .writeAsBytes(bytes);
          }
        }
        expect(
          await renderSlideDesign(
            WorkoutModule.empty('legacy')
                .copyWith(imageSource: 'https://example.com/old.png'),
          ),
          'https://example.com/old.png',
        );
      });
    },
  );
}
