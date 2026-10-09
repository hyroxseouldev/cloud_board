import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_rehearsal_screen.dart';

import 'timer_editor_test.dart' as fixture;

void main() {
  testWidgets(
    'a new timer chooses a mode first, while existing timers open directly',
    (tester) async {
      final container = await fixture.openEditor(
        tester,
        (_) async => true,
        creating: true,
      );
      await fixture.tap(tester, 'slide-timer-summary');
      expect(find.text('운동 방식을 선택하세요'), findsOneWidget);
      await fixture.tap(tester, 'timer-mode-amrap');
      expect(
        find.byKey(const ValueKey('confirm-timer-replacement')),
        findsNothing,
      );
      expect(container.read(fixture.provider).module, fixture.original);
      await fixture.tap(tester, 'apply-timer-editor');
      await fixture.tap(tester, 'slide-timer-summary');
      expect(find.text('운동 방식을 선택하세요'), findsNothing);
      expect(find.byKey(const ValueKey('timer-work')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('repeat buttons and typed input share the same draft', (
    tester,
  ) async {
    final container = await fixture.openEditor(tester, (_) async => true);
    await fixture.tap(tester, 'slide-timer-summary');
    await fixture.tap(tester, 'timer-repeats-increase');
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('timer-repeats')))
          .controller!
          .text,
      '6',
    );
    await fixture.input(tester, 'timer-repeats', '2');
    await fixture.tap(tester, 'timer-repeats-decrease');
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('timer-repeats-decrease')),
          )
          .onPressed,
      isNull,
    );
    await fixture.tap(tester, 'apply-timer-editor');
    expect(container.read(fixture.provider).module.sets, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(834, 1194),
    const Size(844, 390),
  ]) {
    for (final mode in [
      WorkoutTimerMode.amrap,
      WorkoutTimerMode.forTime,
      WorkoutTimerMode.tabata,
      WorkoutTimerMode.emom,
    ]) {
      testWidgets('$mode opens existing form and applies once at $size', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = await fixture.openEditor(tester, (_) async => true);
        await fixture.tap(tester, 'slide-timer-summary');
        await fixture.tap(tester, 'open-timer-builder');
        await fixture.tap(tester, 'timer-mode-${mode.name}');
        await fixture.tap(tester, 'confirm-timer-replacement');
        expect(container.read(fixture.provider).module, fixture.original);
        await fixture.tap(tester, 'apply-timer-editor');
        final applied = container.read(fixture.provider).module;
        expect(applied.timerMode, mode);
        expect(timingValidationError(applied), isNull);
        await fixture.tap(tester, 'slide-timer-summary');
        expect(find.byKey(const ValueKey('timer-mode-emom')), findsNothing);
        await fixture.tap(tester, 'close-timer-editor');
        expect(find.text('반영하지 않고 닫을까요?'), findsNothing);
        expect(container.read(fixture.provider).module, applied);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
  }

  testWidgets(
    'cancel replacement keeps edited values and parent draft untouched',
    (tester) async {
      final container = await fixture.openEditor(tester, (_) async => true);
      await fixture.tap(tester, 'slide-timer-summary');
      await fixture.input(tester, 'timer-work', '02:30');
      await fixture.tap(tester, 'open-timer-builder');
      await fixture.tap(tester, 'timer-mode-amrap');
      await tester.ensureVisible(find.text('취소'));
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('timer-work')))
            .controller!
            .text,
        '02:30',
      );
      expect(container.read(fixture.provider).module, fixture.original);
      await fixture.tap(tester, 'apply-timer-editor');
      expect(container.read(fixture.provider).module.workSeconds, 150);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'keyboard and large text keep validation and apply reachable on small phone',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = await fixture.openEditor(tester, (_) async => true);
      await fixture.tap(tester, 'slide-timer-summary');
      await fixture.input(tester, 'timer-work', '10:99');
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.pumpAndSettle();
      final apply = find.byKey(const ValueKey('apply-timer-editor'));
      expect(tester.widget<FilledButton>(apply).onPressed, isNull);
      expect(tester.getRect(apply).bottom, lessThanOrEqualTo(348));
      expect(container.read(fixture.provider).module, fixture.original);
      tester.view.resetViewInsets();
      await fixture.input(tester, 'timer-work', '02:00');
      expect(tester.widget<FilledButton>(apply).onPressed, isNotNull);
      await fixture.tap(tester, 'apply-timer-editor');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('trial playback returns to the same draft without applying', (
    tester,
  ) async {
    final container = await fixture.openEditor(tester, (_) async => true);
    await fixture.tap(tester, 'slide-timer-summary');
    await fixture.input(tester, 'timer-work', '02:00');
    await fixture.tap(tester, 'timer-rehearse');
    expect(find.byType(SlideRehearsalScreen), findsOneWidget);
    expect(container.read(fixture.provider).module, fixture.original);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await fixture.tap(tester, 'apply-timer-editor');
    expect(container.read(fixture.provider).module.workSeconds, 120);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
