import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';

import 'support/ui_layout_evidence.dart';

import 'dart:async';

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_editor_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_rehearsal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

final _module = WorkoutModule.empty('bottom-tabs')
    .copyWith(name: '스트레칭', text: '원래 본문', workSeconds: 180, beep: false);
final _provider = slideEditorControllerProvider(
  'bottom-tabs',
  _module,
  'local',
);
final _tabs = find.byKey(const ValueKey('slide-editor-tabs'));
final _settings = find.byKey(const ValueKey('slide-editor-settings'));

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('STA-190 evidence slide editor', (tester) async {
    await loadLayoutFonts(tester);
    await _mount(tester);
    await captureLayout(
      tester,
      find.byKey(const ValueKey('layout-evidence')),
      'editor-390',
    );
    expect(tester.takeException(), isNull);
  }, skip: layoutEvidenceDirectory.isEmpty);

  testWidgets('landscape editor respects side safe areas', (tester) async {
    tester.view.padding = const FakeViewPadding(left: 44, right: 44);
    tester.view.viewPadding = const FakeViewPadding(left: 44, right: 44);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await _mount(tester, size: const Size(844, 390));
    expect(
      tester.getRect(find.byKey(const ValueKey('slide-preview-card'))).left,
      64,
    );
    expect(tester.getRect(_settings).right, 800);
    for (final label in ['타이머', '배경', '소리', '라이브러리']) {
      final rect = tester.getRect(
        find.descendant(of: _tabs, matching: find.text(label)),
      );
      expect(rect.left, greaterThanOrEqualTo(44));
      expect(rect.right, lessThanOrEqualTo(800));
    }
    expect(tester.takeException(), isNull);
  });

  for (final scene in uiLayoutScenes) {
    testWidgets(
      'editor preview alignment, ratio and final controls ${scene.size} x${scene.scale}',
      (tester) async {
        await loadLayoutFonts(tester);
        final container = await _mount(
          tester,
          size: scene.size,
          scale: scene.scale,
        );
        final card = find.byKey(const ValueKey('slide-preview-card'));
        if (card.evaluate().isNotEmpty) {
          final preview = find.descendant(
            of: card,
            matching: find.byType(WorkoutSlidePreview),
          );
          final image = tester.getRect(preview);
          final outer = tester.getRect(card);
          expect(image.width / image.height, closeTo(16 / 9, .001));
          expect(image.left - outer.left, greaterThanOrEqualTo(12));
          expect(outer.right - image.right, greaterThanOrEqualTo(12));
          expect(image.top - outer.top, greaterThanOrEqualTo(12));
          expect(outer.bottom - image.bottom, greaterThanOrEqualTo(12));
          if (scene.size.height > 540) {
            final inset = scene.size.width < 360 ? 16.0 : 20.0;
            expect(outer.left, inset);
            expect(
              tester
                  .getRect(find.byKey(const ValueKey('slide-title-text')))
                  .left,
              inset,
            );
            expect(
              tester
                  .getRect(find.byKey(const ValueKey('slide-save-status')))
                  .left,
              inset,
            );
            expect(
              tester
                  .getRect(find.byKey(const ValueKey('slide-timer-summary')))
                  .left,
              inset,
            );
          }
        }
        final settingsScroll = find
            .descendant(of: _settings, matching: find.byType(Scrollable))
            .first;
        final last = find.byKey(const ValueKey('세트 세로 위치'));
        await tester.scrollUntilVisible(last, 120, scrollable: settingsScroll);
        await tester.pumpAndSettle();
        expect(last.hitTestable(), findsOneWidget);
        expect(
          tester.getRect(last).bottom,
          lessThanOrEqualTo(tester.getRect(_tabs).top),
        );
        final slider = tester.widget<Slider>(last);
        slider.onChanged!(.2);
        await tester.pumpAndSettle();
        expect(container.read(_provider).module.appearance.setsOffsetY, .2);
        final reset = find.byTooltip('배치 초기화');
        await tester.ensureVisible(reset);
        await tester.pumpAndSettle();
        expect(tester.getSize(reset).height, greaterThanOrEqualTo(48));
        await tester.tap(reset);
        await tester.pumpAndSettle();
        expect(container.read(_provider).module.appearance, _module.appearance);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }

  for (final scene in [
    (size: const Size(320, 568), scale: 1.0),
    (size: const Size(320, 568), scale: 2.0),
    (size: const Size(390, 844), scale: 1.0),
    (size: const Size(844, 390), scale: 1.0),
    (size: const Size(844, 390), scale: 2.0),
    (size: const Size(834, 1194), scale: 1.0),
    (size: const Size(1440, 900), scale: 1.0),
  ]) {
    testWidgets(
      'tabs stay at safe bottom after settings/library scrolling ${scene.size} x${scene.scale}',
      (tester) async {
        await _mount(tester, size: scene.size, scale: scene.scale);
        void checkBottom() {
          expect(_tabs, findsOneWidget);
          final rect = tester.getRect(_tabs);
          expect(rect.bottom, closeTo(scene.size.height, .01));
          expect(rect.width, scene.size.width);
          for (final label in ['타이머', '배경', '소리', '라이브러리']) {
            final target = find.descendant(
              of: _tabs,
              matching: find.text(label),
            );
            expect(target.hitTestable(), findsOneWidget);
            expect(
              tester.getRect(target).bottom,
              lessThanOrEqualTo(scene.size.height - 34),
            );
            final touch = find
                .ancestor(of: target, matching: find.byType(InkWell))
                .first;
            expect(tester.getSize(touch).height, greaterThanOrEqualTo(48));
          }
          expect(tester.takeException(), isNull);
        }

        checkBottom();
        final rect = tester.getRect(_tabs);
        await tester.drag(_settings, const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.getRect(_tabs), rect);
        checkBottom();
        for (final label in ['배경', '소리', '라이브러리', '타이머']) {
          await tester.tap(
            find.descendant(of: _tabs, matching: find.text(label)),
          );
          await tester.pumpAndSettle();
          checkBottom();
          if (label == '라이브러리') {
            final library = find.byKey(const ValueKey('slide-library-picker'));
            expect(tester.getSize(library).height, greaterThan(0));
            await tester.drag(library, const Offset(0, -300));
            await tester.pumpAndSettle();
            checkBottom();
          }
        }
      },
    );
  }

  for (final scene in [
    (size: const Size(320, 568), scale: 1.0),
    (size: const Size(320, 568), scale: 2.0),
    (size: const Size(390, 844), scale: 1.0),
  ]) {
    testWidgets(
      'keyboard preserves focus, selection, draft and bottom tabs ${scene.size} x${scene.scale}',
      (tester) async {
        final container = await _mount(
          tester,
          size: scene.size,
          scale: scene.scale,
        );
        await tester.tap(find.text('배경'));
        await tester.pumpAndSettle();
        final field = find.byKey(const ValueKey('slide-body-text'));
        await tester.scrollUntilVisible(
          field,
          120,
          scrollable: find
              .descendant(of: _settings, matching: find.byType(Scrollable))
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(field);
        await tester.enterText(field, '키보드 전환 후에도 유지할 본문');
        await tester.pump();
        EditableText editable() => tester.widget<EditableText>(
          find.descendant(of: field, matching: find.byType(EditableText)),
        );
        final focus = editable().focusNode;
        final controller = editable().controller;
        controller.selection = const TextSelection(
          baseOffset: 2,
          extentOffset: 6,
        );
        expect(focus.hasFocus, isTrue);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(editable().focusNode, same(focus));
        expect(focus.hasFocus, isTrue);
        expect(
          controller.selection,
          const TextSelection(baseOffset: 2, extentOffset: 6),
        );
        expect(controller.text, '키보드 전환 후에도 유지할 본문');
        expect(
          tester.getRect(_tabs).bottom,
          closeTo(scene.size.height - 300, .01),
        );
        expect(
          find.byKey(const ValueKey('slide-title-button')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('slide-preview-card')), findsNothing);
        expect(tester.getSize(_settings).height, greaterThan(0));
        for (final label in ['타이머', '배경', '소리', '라이브러리']) {
          expect(
            find
                .descendant(of: _tabs, matching: find.text(label))
                .hitTestable(),
            findsOneWidget,
          );
        }
        // Same-tab selection preserves the section. Native touch keeps focus;
        // web's standard EditableText.onTapOutside dismisses it even on touch.
        await tester.tap(find.descendant(of: _tabs, matching: find.text('배경')));
        await tester.pump();
        expect(focus.hasFocus, !kIsWeb);
        await tester.tap(find.descendant(of: _tabs, matching: find.text('소리')));
        await tester.pumpAndSettle();
        expect(
          FocusManager.instance.primaryFocus?.context?.widget,
          isNot(isA<EditableText>()),
        );
        expect(container.read(_provider).module.text, controller.text);
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        await tester.tap(find.text('배경'));
        await tester.pumpAndSettle();
        expect(container.read(_provider).module.text, '키보드 전환 후에도 유지할 본문');
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scene in [
    (size: const Size(320, 568), scale: 2.0, inset: 300.0),
    (size: const Size(844, 390), scale: 1.0, inset: 0.0),
  ]) {
    testWidgets(
      'recovery and storage notices leave tabs/settings reachable ${scene.size}',
      (tester) async {
        final repository = _NoticeRepository();
        await _mount(
          tester,
          size: scene.size,
          scale: scene.scale,
          repository: repository,
        );
        tester.view.viewInsets = FakeViewPadding(bottom: scene.inset);
        await tester.pumpAndSettle();
        expect(find.text('이 기기에 저장하지 않은 편집 내용이 있습니다.'), findsOneWidget);
        expect(
          tester.getRect(_tabs).bottom,
          closeTo(scene.size.height - scene.inset, .01),
        );
        expect(tester.getSize(_settings).height, greaterThan(0));
        await tester.tap(
          find.descendant(of: _tabs, matching: find.text('라이브러리')),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .getSize(find.byKey(const ValueKey('slide-library-picker')))
              .height,
          greaterThan(0),
        );
        final notices = find.byKey(const ValueKey('slide-editor-notices'));
        await tester.drag(notices, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(
          find
              .text('스타일 동기화에 실패했습니다. 연결을 확인한 뒤 다시 열어 주세요.')
              .hitTestable(at: const Alignment(0, .9)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'single accessible rehearsal action uses local draft and returns without TV commands',
    (tester) async {
      final container = await _mount(tester);
      final semantics = tester.ensureSemantics();
      final action = find.byKey(const ValueKey('slide-preview-rehearse'));
      try {
        await tester.pump();
        expect(find.byTooltip('이 기기에서 연습'), findsOneWidget);
        expect(tester.getSemantics(action).tooltip, '이 기기에서 연습');
      } finally {
        semantics.dispose();
      }
      expect(find.text('이 기기에서 연습'), findsNothing);
      expect(find.text('이 기기에서만 재생되며 TV에는 반영되지 않아요.'), findsNothing);
      container
          .read(_provider.notifier)
          .update(_module.copyWith(text: '저장 전 연습'));
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.byType(SlideRehearsalScreen), findsOneWidget);
      expect(
        tester
            .widget<SlideRehearsalScreen>(find.byType(SlideRehearsalScreen))
            .module
            .text,
        '저장 전 연습',
      );
      expect(find.textContaining('TV'), findsWidgets);
      await tester.tap(find.text('재생'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(container.exists(playbackActionControllerProvider), isFalse);
      expect(container.exists(workoutActionControllerProvider), isFalse);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(container.read(_provider).module.text, '저장 전 연습');
      expect(container.read(_provider).dirty, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'save failure keeps draft, busy blocks tabs/back, successful save can exit',
    (tester) async {
      final gate = Completer<bool>();
      var attempts = 0;
      final saved = <WorkoutModule>[];
      final container = await _mount(
        tester,
        onSave: (module) {
          saved.add(module);
          return ++attempts == 1 ? Future.value(false) : gate.future;
        },
      );
      container
          .read(_provider.notifier)
          .update(_module.copyWith(text: '저장할 내용'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('저장하지 않고 나갈까요?'), findsOneWidget);
      await tester.tap(find.text('계속 편집'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('slide-save-button')));
      await tester.pumpAndSettle();
      expect(container.read(_provider).dirty, isTrue);
      expect(find.text('다시 저장'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('slide-save-button')));
      await tester.pump();
      await tester.tap(
        find.descendant(of: _tabs, matching: find.text('배경')),
        warnIfMissed: false,
      );
      await tester.pageBack();
      await tester.pump();
      expect(find.byType(SlideEditorScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey('timer-display-toggle')),
        findsOneWidget,
      );
      gate.complete(true);
      await tester.pumpAndSettle();
      expect(container.read(_provider).dirty, isFalse);
      expect(saved.map((value) => value.text), ['저장할 내용', '저장할 내용']);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('편집 열기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _NoticeRepository extends LocalSlideEditorRepository {
  _NoticeRepository() : super(SlideEditorLocalDataSource());
  @override
  Future<WorkoutModule?> loadDraft(String key) async =>
      _module.copyWith(text: '복구할 초안');
  @override
  Stream<List<WorkoutModule>> watchStyles(String scope) =>
      Stream.error(StateError('test-only storage failure'));
}

Future<ProviderContainer> _mount(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  LocalSlideEditorRepository? repository,
  Future<bool> Function(WorkoutModule)? onSave,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        slideEditorRepositoryProvider.overrideWithValue(
          repository ??
              LocalSlideEditorRepository(SlideEditorLocalDataSource()),
        ),
      ],
      child: MaterialApp(
        theme: XonTheme.light,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(scale),
              padding: media.padding.copyWith(
                bottom: media.viewInsets.bottom > 0 ? 0 : 34,
              ),
              viewPadding: media.viewPadding.copyWith(bottom: 34),
            ),
            child: RepaintBoundary(
              key: const ValueKey('layout-evidence'),
              child: child!,
            ),
          );
        },
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SlideEditorScreen(
                      workoutId: 'bottom-tabs',
                      moduleId: _module.id,
                      guard: ExitGuard(),
                      request: SlideEditRequest(
                        module: _module,
                        onSave: onSave ?? (_) async => true,
                      ),
                    ),
                  ),
                ),
                child: const Text('편집 열기'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('편집 열기'));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(SlideEditorScreen)),
  );
}
