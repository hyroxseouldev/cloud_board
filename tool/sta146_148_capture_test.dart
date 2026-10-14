// Real production editing widgets with local repositories; no Firebase writes.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/ai_slide_design_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/ai_slides_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/repositories/ai_slides_repository_impl.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_slide_design_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/repositories/ai_slides_repository.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slide_design_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slides_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_page.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/workout_editor_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_rehearsal_screen.dart';

import '../test/support/ai_slides_editor_fakes.dart';
import '../test/timer_editor_test.dart' as timer_fixture;
import '../test/support/main_navigation_fixture.dart';

import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_templates_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_rehearsal_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';

class _Templates extends SlideTemplatesController {
  _Templates(this.modules);
  final List<WorkoutModule> modules;
  @override
  Stream<List<WorkoutModule>> build(String scope) => Stream.value(modules);
}

class _LocalDrafts extends SlideEditorLocalDataSource {
  final values = <String, String>{};
  final drafts = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> readDraft(String key) async => drafts[key];
  @override
  Future<void> writeDraft(String key, Map<String, dynamic> value) async {
    drafts[key] = value;
  }

  @override
  Future<void> clearDraft(String key) async {
    drafts.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String? value) async {
    value == null ? values.remove(key) : values[key] = value;
  }
}

class _Content implements AiSlidesRepository {
  bool failAccess = false;
  Completer<AiSlidesResult>? pending;
  @override
  Future<AiSlidesAccess> access() async {
    if (failAccess) throw const AiSlidesFailure('사용량 조회 실패');
    return const AiSlidesAccess(
      premium: true,
      enabled: true,
      remaining: 17,
      limit: 30,
    );
  }

  @override
  Future<AiSlidesResult> generate(String prompt) => pending!.future;
}

class _Designs implements AiSlideDesignRepository {
  @override
  Future<AiSlidesAccess> access(String ownerId) async => const AiSlidesAccess(
    premium: true,
    enabled: true,
    remaining: 17,
    limit: 30,
  );
  @override
  Future<AiSlideDesignResult> generate(
    String ownerId,
    String prompt, {
    Uint8List? reference,
  }) async => const AiSlideDesignResult(designs: [], remaining: 16);
  @override
  Stream<List<AiSlideDesign>> watchTemplates(String ownerId, String? storeId) =>
      Stream.value([]);
  @override
  Future<AiSlideDesign?> loadSelected(String ownerId, String? storeId) async =>
      null;
  @override
  Future<void> saveSelected(
    String ownerId,
    String? storeId,
    AiSlideDesign design,
  ) async {}
  @override
  Future<void> saveTemplate(String ownerId, AiSlideDesign design) async {}
}

void main() {
  final directory = Directory('docs/design/todo-2026-10-13/implemented');
  Future<void> setup(WidgetTester tester, Size size) async {
    directory.createSync(recursive: true);
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = size * 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    for (final (family, assets) in [
      (
        'Pretendard',
        [
          'assets/fonts/pretendard/Pretendard-Regular.otf',
          'assets/fonts/pretendard/Pretendard-Medium.otf',
          'assets/fonts/pretendard/Pretendard-SemiBold.otf',
        ],
      ),
      ('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']),
    ]) {
      final font = FontLoader(family);
      for (final asset in assets) {
        font.addFont(rootBundle.load(asset));
      }
      await font.load();
    }
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('${directory.path}/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Widget app(Widget child, {double scale = 1}) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: XonTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: child,
  );

  testWidgets('capture creation input, generation, errors and result', (
    tester,
  ) async {
    await setup(tester, const Size(390, 844));
    final key = GlobalKey();
    final content = _Content();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: [
            aiSlidesOwnerIdProvider.overrideWithValue('preview'),
            aiSlideDesignOwnerIdProvider.overrideWithValue('preview'),
            aiSlideDesignStoreIdProvider.overrideWithValue('preview'),
            aiSlidesEditorRepositoryProvider.overrideWithValue(
              MemoryAiSlidesEditorRepository(),
            ),
            aiSlidesRepositoryProvider.overrideWithValue(content),
            aiSlideDesignRepositoryProvider.overrideWithValue(_Designs()),
          ],
          child: app(const AiSlidesPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ai-nav-create')));
    await tester.pumpAndSettle();
    await capture(tester, key, 'sta146-empty');
    await tester.enterText(
      find.byKey(const ValueKey('ai-slides-prompt')),
      'WARM UP\n스쿼트 10회 · 런지 10회\n\nMAIN\nRUN 1km\nROW 500m',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await capture(tester, key, 'sta146-input');
    content.pending = Completer<AiSlidesResult>();
    await tester.ensureVisible(
      find.byKey(const ValueKey('ai-slides-generate')),
    );
    await tester.tap(find.byKey(const ValueKey('ai-slides-generate')));
    await tester.pump(const Duration(milliseconds: 200));
    await capture(tester, key, 'sta146-generating');
    content.pending!.complete(
      const AiSlidesResult(slides: [], warnings: [], remaining: 16),
    );
    await tester.pumpAndSettle();
    await capture(tester, key, 'sta146-empty-result');
    final scope = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('ai-slides-prompt'))),
    );
    content.failAccess = true;
    scope.invalidate(aiSlidesAccessProvider);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('ai-generation-usage')),
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('ai-slides-generate')),
          )
          .onPressed,
      isNull,
    );
    await capture(tester, key, 'sta146-usage-error');
    content.failAccess = false;
    scope.invalidate(aiSlidesAccessProvider);
    scope
        .read(aiSlidesControllerProvider.notifier)
        .applyDesign(aiSlideDesignCatalog.first.theme);
    await tester.tap(find.byKey(const ValueKey('ai-nav-content')));
    await tester.pumpAndSettle();
    await capture(tester, key, 'sta146-result');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'capture slide status, responsive preview and timer transaction',
    (tester) async {
      await setup(tester, const Size(390, 844));
      final key = GlobalKey();
      final module = WorkoutModule.empty('warmup').copyWith(
        name: '워밍업',
        text: 'WARM UP\nSQUAT 10\nLUNGE 10',
        workSeconds: 60,
        restSeconds: 30,
        sets: 4,
      );
      final source = _LocalDrafts();
      final container = ProviderContainer(
        overrides: [
          slideEditorRepositoryProvider.overrideWithValue(
            LocalSlideEditorRepository(source),
          ),
        ],
      );
      addTearDown(container.dispose);
      Completer<bool>? pendingSave;
      bool failSave = true;
      Future<void> mount(Size size, double scale) async {
        tester.view.physicalSize = size * 2;
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: UncontrolledProviderScope(
              container: container,
              child: app(
                SlideEditorScreen(
                  workoutId: 'preview',
                  moduleId: module.id,
                  guard: ExitGuard(),
                  request: SlideEditRequest(
                    module: module,
                    needsInitialSave: true,
                    onSave: (_) =>
                        pendingSave?.future ?? Future.value(!failSave),
                  ),
                ),
                scale: scale,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await mount(const Size(390, 844), 1);
      await capture(tester, key, 'sta147-slide');
      pendingSave = Completer<bool>();
      await tester.tap(find.byKey(const ValueKey('slide-save-button')));
      await tester.pump(const Duration(milliseconds: 200));
      await capture(tester, key, 'sta147-saving');
      pendingSave.complete(false);
      await tester.pumpAndSettle();
      await capture(tester, key, 'sta147-save-error');
      await mount(const Size(320, 568), 2);
      await capture(tester, key, 'sta147-error-large-text');
      final settingsScroll = find
          .descendant(
            of: find.byKey(const ValueKey('slide-editor-settings')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('편집'),
        80,
        scrollable: settingsScroll,
      );
      await tester.pumpAndSettle();
      expect(find.text('편집').hitTestable(), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('slide-save-button')))
            .onPressed,
        isNotNull,
      );
      tester.state<ScrollableState>(settingsScroll).position.jumpTo(0);
      await tester.pump();
      await mount(const Size(390, 844), 1);
      pendingSave = null;
      failSave = false;
      await tester.tap(find.byKey(const ValueKey('slide-save-button')));
      await tester.pumpAndSettle();
      await capture(tester, key, 'sta147-saved');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('slide-timer-summary')),
      );
      await tester.tap(find.byKey(const ValueKey('slide-timer-summary')));
      await tester.pumpAndSettle();
      if (find
          .byKey(const ValueKey('timer-mode-interval'))
          .evaluate()
          .isNotEmpty) {
        await tester.ensureVisible(
          find.byKey(const ValueKey('timer-mode-interval')),
        );
        await tester.tap(find.byKey(const ValueKey('timer-mode-interval')));
        await tester.pumpAndSettle();
      }
      await capture(tester, key, 'sta147-timer');
      await timer_fixture.input(tester, 'timer-work', '01:00');
      await timer_fixture.reveal(tester, 'timer-repeats');
      await tester.enterText(find.byKey(const ValueKey('timer-repeats')), '2');
      tester.view.viewInsets = const FakeViewPadding(bottom: 480);
      await tester.pumpAndSettle();
      await capture(tester, key, 'sta147-keyboard');
      tester.view.resetViewInsets();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('close-timer-editor')));
      await tester.pumpAndSettle();
      await mount(const Size(844, 390), 1);
      await capture(tester, key, 'sta147-landscape');
      await mount(const Size(320, 568), 2);
      await capture(tester, key, 'sta147-large-text');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('capture workout composition, empty and local rehearsal', (
    tester,
  ) async {
    await setup(tester, const Size(390, 844));
    final key = GlobalKey();
    for (final empty in [false, true]) {
      final data = NavigationPreviewData(active: false);
      final workout = data.repository.items.first.copyWith(
        modules: empty
            ? []
            : [
                WorkoutModule.empty('warmup').copyWith(
                  name: '워밍업',
                  workSeconds: 60,
                  restSeconds: 30,
                  sets: 4,
                ),
                WorkoutModule.empty('main').copyWith(
                  name: '메인 수업',
                  workSeconds: 180,
                  restSeconds: 30,
                  sets: 3,
                ),
              ],
      );
      data.repository.items[0] = workout;
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: UncontrolledProviderScope(
            container: data.container,
            child: ProviderScope(
              overrides: [
                slideTemplatesControllerProvider.overrideWith2(
                  (_) => _Templates(workout.modules),
                ),
              ],
              child: app(const WorkoutEditorScreen(workoutId: 'preview-0')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, key, empty ? 'sta148-empty' : 'sta148-class');
      if (!empty) {
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: UncontrolledProviderScope(
              container: data.container,
              child: app(WorkoutRehearsalScreen(workout: workout)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await capture(tester, key, 'sta148-rehearsal');
        await tester.ensureVisible(find.text('다음 슬라이드'));
        await tester.tap(find.text('다음 슬라이드'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('연습 종료'));
        await tester.tap(find.text('연습 종료'));
        await tester.pumpAndSettle();
        await capture(tester, key, 'sta148-finished');
        await tester.tap(find.text('처음부터 다시 연습'));
        await tester.pumpAndSettle();
        for (final (index, module) in workout.modules.indexed) {
          data.container
              .read(
                slideRehearsalControllerProvider(module.copyWith(beep: false))
                    .notifier,
              )
              .seek(workoutModuleDuration(module) * 1000);
          await tester.pumpAndSettle();
          if (index < workout.modules.length - 1) {
            await tester.ensureVisible(find.text('다음 슬라이드'));
            await tester.tap(find.text('다음 슬라이드'));
            await tester.pumpAndSettle();
          }
        }
        expect(find.text('연습을 마쳤어요'), findsOneWidget);
        expect(data.commands.transports, 0);
        await capture(tester, key, 'sta148-completed');
      }
      await tester.pumpWidget(const SizedBox.shrink());
      data.dispose();
    }
  });
}
