import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_editor_local_data_source.dart';
import 'package:cloud_board/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart';

import 'dart:async';

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_editor_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final original = WorkoutModule.empty('timer-test').copyWith(
  name: '수업',
  workSeconds: 90,
  restSeconds: 45,
  sets: 5,
  showTimer: false,
);
final provider = slideEditorControllerProvider(
  'timer-workout',
  original,
  'local',
);

Future<ProviderContainer> openEditor(
  WidgetTester tester,
  Future<bool> Function(WorkoutModule) save, {
  bool creating = false,
}) async {
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
          guard: ExitGuard(),
          workoutId: 'timer-workout',
          moduleId: original.id,
          request: SlideEditRequest(
            module: original,
            onSave: save,
            needsInitialSave: creating,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(SlideEditorScreen)),
  );
}

Future<void> input(WidgetTester tester, String key, String value) async {
  final field = find.byKey(ValueKey(key));
  await reveal(tester, key);
  await tester.enterText(field, value);
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

Finder targetFor(String key) => key == 'slide-timer-summary'
    ? find.descendant(of: find.byKey(ValueKey(key)), matching: find.text('편집'))
    : find.byKey(ValueKey(key));

Future<void> reveal(WidgetTester tester, String key) async {
  final target = targetFor(key);
  if (target.evaluate().isEmpty) {
    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('timer-editor-settings')),
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      target,
      140,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('timer-editor-settings')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String key) async {
  await reveal(tester, key);
  await tester.tap(targetFor(key));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('unlimited For Time uses one apply, then slide save', (
    tester,
  ) async {
    final saved = <WorkoutModule>[];
    final container = await openEditor(tester, (module) async {
      saved.add(module);
      return true;
    });
    await tap(tester, 'slide-timer-summary');
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('open-timer-builder')),
    );
    await tester.tap(find.byKey(const ValueKey('open-timer-builder')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('timer-mode-forTime')));
    await tester.pumpAndSettle();
    expect(container.read(provider).module, original);
    await tap(tester, 'confirm-timer-replacement');
    await tester.pumpAndSettle();
    expect(container.read(provider).module, original);
    await tester.tap(find.byKey(const ValueKey('apply-timer-editor')));
    await tester.pumpAndSettle();
    expect(container.read(provider).module.timerMode, WorkoutTimerMode.forTime);
    expect(saved, isEmpty);
    expect(find.textContaining('제한시간 없음'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('slide-save-button')));
    await tester.pumpAndSettle();
    expect(saved.single.workSeconds, 0);
    expect(saved.single.name, original.name);
    expect(saved.single.timerDirection, TimerDirection.up);
    expect(timingValidationError(saved.single), isNull);
    expect(workoutModuleTimeline(saved.single), hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'EMOM example stays a draft until applied and slide save preserves rounds',
    (tester) async {
      final saved = <WorkoutModule>[];
      final container = await openEditor(tester, (module) async {
        saved.add(module);
        return true;
      });
      await tap(tester, 'slide-timer-summary');
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('open-timer-builder')),
      );
      await tester.tap(find.byKey(const ValueKey('open-timer-builder')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('timer-mode-emom')));
      await tester.pumpAndSettle();
      await tap(tester, 'confirm-timer-replacement');
      await tap(tester, 'emom-preset-rounds');
      await tap(tester, 'confirm-timer-replacement');
      expect(container.read(provider).module, original);
      await reveal(tester, 'timer-editor-total');
      expect(find.text('39:00'), findsOneWidget);
      await tap(tester, 'emom-final-rest');
      await reveal(tester, 'timer-editor-total');
      expect(find.text('38:30'), findsOneWidget);
      expect(container.read(provider).module, original);
      await tester.tap(find.byKey(const ValueKey('apply-timer-editor')));
      await tester.pumpAndSettle();
      expect(container.read(provider).module.rounds, 6);
      expect(container.read(provider).module.includeFinalRoundRest, isFalse);
      expect(workoutModuleDuration(container.read(provider).module), 2310);
      expect(saved, isEmpty);
      await tester.tap(find.byKey(const ValueKey('slide-save-button')));
      await tester.pumpAndSettle();
      expect(saved.single.rounds, 6);
      expect(saved.single.intervalBlocks, hasLength(3));
      expect(saved.single.name, original.name);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('rest-only block is editable and survives apply', (tester) async {
    final container = await openEditor(tester, (_) async => true);
    await tap(tester, 'slide-timer-summary');
    await tester.pumpAndSettle();
    await tap(tester, 'timer-detail-toggle');
    await tester.ensureVisible(find.text('구간 추가'));
    await tester.tap(find.text('구간 추가'));
    await tester.pumpAndSettle();
    await tap(tester, 'add-rest-block');
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('apply-timer-editor')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('apply-timer-editor')));
    await tester.pumpAndSettle();
    final module = container.read(provider).module;
    expect(module.intervalBlocks.last.workSeconds, 0);
    expect(module.intervalBlocks.last.restSeconds, 30);
    expect(workoutModuleTimeline(module).last.isRest, isTrue);
    expect(workoutModuleDuration(module), 705);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  for (final size in [
    const Size(834, 1194),
    const Size(390, 844),
    const Size(320, 568),
    const Size(844, 390),
  ]) {
    testWidgets(
      'apply changes draft only; slide save persists all changes at $size',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final saved = <WorkoutModule>[];
        final container = await openEditor(tester, (module) async {
          saved.add(module);
          return true;
        });
        container
            .read(provider.notifier)
            .update(original.copyWith(name: '수정 이름', text: '본문 초안'));
        await tester.pump();
        expect(find.text('운동 01:30 → 휴식 00:45'), findsOneWidget);
        expect(find.text('위 순서를 5회 반복'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('timer-unsaved-status')),
          findsNothing,
        );
        await tap(tester, 'slide-timer-summary');
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        final sheet = tester.getRect(
          find.byKey(const ValueKey('timer-editor-sheet')),
        );
        expect(sheet.top, greaterThan(0));
        expect(sheet.width, lessThanOrEqualTo(720));
        await input(tester, 'timer-work', '02:10');
        await input(tester, 'timer-repeats', '3');
        // Editing the sheet must not leak into the parent draft or storage.
        expect(container.read(provider).module.workSeconds, 90);
        expect(container.read(provider).module.sets, 5);
        await reveal(tester, 'timer-editor-total');
        expect(find.text('8:45'), findsWidgets);
        expect(saved, isEmpty);
        await tester.tap(find.byKey(const ValueKey('apply-timer-editor')));
        await tester.pumpAndSettle();
        expect(find.text('타이머 편집'), findsNothing);
        expect(saved, isEmpty);
        expect(container.read(provider).saved.workSeconds, 90);
        expect(container.read(provider).module.workSeconds, 130);
        expect(container.read(provider).module.sets, 3);
        expect(container.read(provider).module.text, '본문 초안');
        expect(container.read(provider).dirty, isTrue);
        expect(find.text('운동 02:10 → 휴식 00:45'), findsOneWidget);
        expect(find.text('위 순서를 3회 반복'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('timer-unsaved-status')),
          findsOneWidget,
        );
        // Reopening sees the applied draft; closing an untouched sheet is clean.
        await tap(tester, 'slide-timer-summary');
        await tester.pumpAndSettle();
        await reveal(tester, 'timer-editor-total');
        expect(find.text('8:45'), findsWidgets);
        await tester.tap(find.byKey(const ValueKey('close-timer-editor')));
        await tester.pumpAndSettle();
        expect(find.text('반영하지 않고 닫을까요?'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('slide-save-button')));
        await tester.pumpAndSettle();
        expect(saved, hasLength(1));
        expect(saved.single.workSeconds, 130);
        expect(saved.single.name, '수정 이름');
        expect(saved.single.text, '본문 초안');
        expect(container.read(provider).dirty, isFalse);
        expect(
          tester
              .widget<IconButton>(
                find.byKey(const ValueKey('slide-save-button')),
              )
              .onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'summary shows per-set timings, keeping total and mixed blocks accurate',
    (tester) async {
      final container = await openEditor(tester, (_) async => true);
      final summary = find.byKey(const ValueKey('slide-timer-summary'));
      void expectSummary(String label) => expect(
        find.descendant(of: summary, matching: find.text(label)),
        findsOneWidget,
      );
      final single = original.copyWith(
        workSeconds: 420,
        restSeconds: 60,
        sets: 3,
      );
      container.read(provider.notifier).update(single);
      await tester.pump();
      expectSummary('운동 07:00 → 휴식 01:00');
      expectSummary('위 순서를 3회 반복');
      expectSummary('24:00');

      // Older classes can omit the final rest. The total reflects playback, while
      // the per-set setting remains one minute rather than showing an average.
      container
          .read(provider.notifier)
          .update(single.copyWith(includeFinalRest: false));
      await tester.pump();
      expectSummary('운동 07:00 → 휴식 01:00');
      expectSummary('23:00');

      const first = WorkoutIntervalBlock(
        id: 'a',
        workSeconds: 420,
        restSeconds: 60,
        sets: 3,
      );
      container
          .read(provider.notifier)
          .update(
            single.copyWith(
              intervalBlocks: [
                first,
                first.copyWith(id: 'b', sets: 2),
              ],
            ),
          );
      await tester.pump();
      expectSummary('운동 2구간');
      expectSummary('구간별 반복 후 다음 구간으로 이동');
      expectSummary('40:00');

      container
          .read(provider.notifier)
          .update(
            single.copyWith(
              intervalBlocks: [
                first,
                first.copyWith(
                  id: 'b',
                  workSeconds: 30,
                  restSeconds: 0,
                  sets: 2,
                ),
              ],
            ),
          );
      await tester.pump();
      expectSummary('운동 2구간');
      expectSummary('구간별 반복 후 다음 구간으로 이동');
      expectSummary('25:00');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'discard returns to sheet entry timing, preserving applied draft',
    (tester) async {
      final saved = <WorkoutModule>[];
      final container = await openEditor(tester, (module) async {
        saved.add(module);
        return true;
      });
      await tap(tester, 'slide-timer-summary');
      await tester.pumpAndSettle();
      await input(tester, 'timer-work', '02:30');
      await tester.tap(find.byKey(const ValueKey('apply-timer-editor')));
      await tester.pumpAndSettle();
      final applied = container.read(provider).module;
      expect(applied.workSeconds, 150);
      await tap(tester, 'slide-timer-summary');
      await tester.pumpAndSettle();
      await input(tester, 'timer-work', '04:30');
      await tester.tap(find.byKey(const ValueKey('close-timer-editor')));
      await tester.pumpAndSettle();
      expect(find.text('반영하지 않고 닫을까요?'), findsOneWidget);
      await tester.tap(find.text('계속 편집'));
      await tester.pumpAndSettle();
      expect(container.read(provider).module, applied);
      await tester.tap(find.byKey(const ValueKey('close-timer-editor')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('반영 안 하고 닫기'));
      await tester.pumpAndSettle();
      expect(find.text('타이머 편집'), findsNothing);
      expect(container.read(provider).module, applied);
      expect(container.read(provider).saved, original);
      expect(saved, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('failed slide save preserves applied timing and supports retry', (
    tester,
  ) async {
    final pending = Completer<bool>();
    var calls = 0;
    final container = await openEditor(tester, (_) {
      calls++;
      return calls == 1 ? pending.future : Future.value(true);
    });
    await tap(tester, 'slide-timer-summary');
    await tester.pumpAndSettle();
    await input(tester, 'timer-work', '02:30');
    await tester.tap(find.byKey(const ValueKey('apply-timer-editor')));
    await tester.pumpAndSettle();
    expect(calls, 0);
    final save = find.byKey(const ValueKey('slide-save-button'));
    await tester.tap(save);
    await tester.pump();
    expect(tester.widget<IconButton>(save).onPressed, isNull);
    expect(calls, 1);
    pending.complete(false);
    await tester.pumpAndSettle();
    expect(container.read(provider).module.workSeconds, 150);
    expect(container.read(provider).saved.workSeconds, 90);
    expect(container.read(provider).dirty, isTrue);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(container.read(provider).saved.workSeconds, 150);
    expect(container.read(provider).dirty, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
