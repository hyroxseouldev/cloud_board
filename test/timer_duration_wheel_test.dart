import 'dart:ui' show PointerDeviceKind, SemanticsAction;

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_editing.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/timer_editor_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/timer_duration_wheel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'timer_editor_test.dart' as fixture;

CupertinoPicker _picker(WidgetTester tester, String field, String unit) =>
    tester.widget<CupertinoPicker>(find.byKey(ValueKey('$field-$unit-wheel')));

Future<void> _jump(
  WidgetTester tester,
  String field,
  int minutes,
  int seconds,
) async {
  _picker(tester, field, 'minutes').scrollController!.jumpToItem(minutes);
  await tester.pumpAndSettle();
  _picker(tester, field, 'seconds').scrollController!.jumpToItem(seconds);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    '00:30, 02:00, 02:30, 10:05 are seconds without any time keyboard',
    (tester) async {
      final values = await _mount(tester);
      for (final entry in [
        (0, 30, 30),
        (2, 0, 120),
        (2, 30, 150),
        (10, 5, 605),
      ]) {
        await _jump(tester, 'work', entry.$1, entry.$2);
        expect(values.value['work'], entry.$3);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('work')),
            matching: find.text(formatSlideTime(entry.$3)),
          ),
          findsOneWidget,
        );
        expect(tester.testTextInput.isVisible, isFalse);
        expect(find.byType(EditableText), findsNothing);
      }
    },
  );

  testWidgets(
    'finite endpoints and semantics expose target, unit, current value and actions',
    (tester) async {
      final values = await _mount(tester);
      final semantics = tester.ensureSemantics();
      try {
        await _jump(tester, 'work', 999, 59);
        final minutes = tester.getSemantics(
          find.byKey(const ValueKey('work-minutes-semantics')),
        );
        final seconds = tester.getSemantics(
          find.byKey(const ValueKey('work-seconds-semantics')),
        );
        expect(minutes.label, '운동 시간 분');
        expect(minutes.value, '999분');
        expect(seconds.label, '운동 시간 초');
        expect(seconds.value, '59초');
        expect(
          minutes.getSemanticsData().hasAction(SemanticsAction.increase),
          isFalse,
        );
        expect(
          seconds.getSemanticsData().hasAction(SemanticsAction.increase),
          isFalse,
        );
        seconds.owner!.performAction(seconds.id, SemanticsAction.decrease);
        await tester.pumpAndSettle();
        expect(values.value['work'], 59998);
        await _jump(tester, 'work', 0, 0);
        expect(
          tester
              .getSemantics(
                find.byKey(const ValueKey('work-seconds-semantics')),
              )
              .getSemanticsData()
              .hasAction(SemanticsAction.decrease),
          isFalse,
        );
        await tester.fling(
          find.byKey(const ValueKey('work-seconds-wheel')),
          const Offset(0, 180),
          1200,
        );
        await tester.pumpAndSettle();
        expect(values.value['work'], 0);
        final rest = tester.getSemantics(find.byKey(const ValueKey('rest')));
        expect(rest.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        rest.owner!.performAction(rest.id, SemanticsAction.tap);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('rest-minutes-wheel')),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'mouse wheel, mouse drag and hardware arrows change the focused column',
    (tester) async {
      final values = await _mount(tester);
      final seconds = find.byKey(const ValueKey('work-seconds-wheel'));
      await tester.ensureVisible(seconds);
      await tester.tap(seconds);
      await tester.pumpAndSettle();
      final original = values.value['work']!;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(values.value['work'], original + 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(values.value['work']! % 60, 59);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(values.value['work']! % 60, 59);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(values.value['work']! % 60, 0);
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(seconds),
          scrollDelta: const Offset(0, 80),
        ),
      );
      await tester.pumpAndSettle();
      expect(values.value['work']! % 60, greaterThan(0));
      final beforeDrag = values.value['work']!;
      await tester.drag(
        seconds,
        const Offset(0, -80),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(values.value['work'], greaterThan(beforeDrag));
    },
  );

  testWidgets(
    'switching fields during inertia commits the old center and rejects stale callbacks',
    (tester) async {
      final values = await _mount(tester);
      final old = _picker(tester, 'work', 'seconds');
      await tester.fling(
        find.byKey(const ValueKey('work-seconds-wheel')),
        const Offset(0, -80),
        1000,
      );
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(find.byKey(const ValueKey('rest')));
      await tester.pump();
      final committed = values.value['work'];
      old.onSelectedItemChanged!(55);
      await tester.pumpAndSettle();
      expect(values.value['work'], committed);
      expect(values.value['rest'], 30);
      expect(find.byType(TimerDurationWheel), findsOneWidget);
      await _jump(tester, 'rest', 0, 0);
      await tester.tap(find.byKey(const ValueKey('work')));
      await tester.pumpAndSettle();
      expect(values.value['work'], committed);
      expect(values.value['rest'], 0);
      expect(
        _picker(tester, 'work', 'seconds').scrollController!.selectedItem,
        committed! % 60,
      );
    },
  );

  testWidgets(
    'wheel drag stays in its column and outside drag scrolls the page',
    (tester) async {
      final values = await _mount(tester, trailingSpace: true);
      final page = tester.state<ScrollableState>(find.byType(Scrollable).first);
      await tester.drag(
        find.byKey(const ValueKey('work')),
        const Offset(0, -60),
      );
      await tester.pumpAndSettle();
      expect(page.position.pixels, greaterThan(0));
      final seconds = find.byKey(const ValueKey('work-seconds-wheel'));
      await tester.ensureVisible(seconds);
      await tester.pumpAndSettle();
      final beforePage = page.position.pixels;
      final beforeValue = values.value['work']!;
      await tester.drag(seconds, const Offset(0, -60));
      await tester.pumpAndSettle();
      expect(values.value['work'], greaterThan(beforeValue));
      expect(page.position.pixels, beforePage);
    },
  );

  testWidgets(
    'custom zero work keeps a valid rest-only block and round rest uses the same wheel',
    (tester) async {
      final container = await fixture.openEditor(tester, (_) async => true);
      final custom = fixture.original.copyWith(
        timerMode: WorkoutTimerMode.custom,
        intervalBlocks: const [
          WorkoutIntervalBlock(
            id: 'one',
            workSeconds: 120,
            restSeconds: 30,
            sets: 1,
          ),
        ],
      );
      container.read(fixture.provider.notifier).update(custom);
      await tester.pumpAndSettle();
      await fixture.tap(tester, 'slide-timer-summary');
      await fixture.tap(tester, 'timer-detail-toggle');
      _picker(tester, 'one-work', 'minutes').scrollController!.jumpToItem(0);
      await tester.pumpAndSettle();
      final state = container.read(timerEditorControllerProvider(custom));
      expect(state.valid, isTrue);
      expect(state.module.intervalBlocks.single.workSeconds, 0);
      expect(state.module.intervalBlocks.single.restSeconds, 30);
      await fixture.input(tester, 'one-rest', '00:30');
      await fixture.tap(tester, 'timer-round-settings');
      await fixture.input(tester, 'timer-roundRest', '00:15');
      expect(
        container
            .read(timerEditorControllerProvider(custom))
            .module
            .roundRestSeconds,
        15,
      );
      await fixture.tap(tester, 'apply-timer-editor');
      expect(
        container
            .read(fixture.provider)
            .module
            .intervalBlocks
            .single
            .workSeconds,
        0,
      );
      expect(container.read(fixture.provider).module.roundRestSeconds, 15);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  for (final mode in [
    WorkoutTimerMode.amrap,
    WorkoutTimerMode.forTime,
    WorkoutTimerMode.emom,
  ]) {
    testWidgets('$mode keeps its one-second minimum and shared inline input', (
      tester,
    ) async {
      final container = await fixture.openEditor(tester, (_) async => true);
      var module = timerModeCandidate(fixture.original, mode);
      if (mode == WorkoutTimerMode.forTime) {
        module = module.copyWith(workSeconds: 60);
      }
      container.read(fixture.provider.notifier).update(module);
      await tester.pumpAndSettle();
      await fixture.tap(tester, 'slide-timer-summary');
      final field = mode == WorkoutTimerMode.emom
          ? 'timer-interval'
          : 'timer-work';
      await _jump(tester, field, 0, 0);
      final state = container.read(timerEditorControllerProvider(module));
      expect(state.valid, isTrue);
      expect(effectiveIntervalBlocks(state.module).first.workSeconds, 1);
      expect(
        _picker(tester, field, 'seconds').scrollController!.selectedItem,
        1,
      );
      if (mode == WorkoutTimerMode.emom) {
        await fixture.input(tester, 'timer-roundRest', '00:00');
        expect(
          container
              .read(timerEditorControllerProvider(module))
              .module
              .roundRestSeconds,
          0,
        );
      }
      await fixture.tap(tester, 'apply-timer-editor');
      expect(
        timingValidationError(container.read(fixture.provider).module),
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }

  testWidgets(
    'inertial apply reads current centers once and old callbacks cannot mutate applied timing',
    (tester) async {
      final container = await fixture.openEditor(tester, (_) async => true);
      await fixture.tap(tester, 'slide-timer-summary');
      final minutes = _picker(tester, 'timer-work', 'minutes');
      final seconds = _picker(tester, 'timer-work', 'seconds');
      await tester.ensureVisible(
        find.byKey(const ValueKey('timer-work-seconds-wheel')),
      );
      await tester.fling(
        find.byKey(const ValueKey('timer-work-seconds-wheel')),
        const Offset(0, -85),
        1200,
      );
      await tester.pump(const Duration(milliseconds: 30));
      final expected =
          minutes.scrollController!.selectedItem * 60 +
          seconds.scrollController!.selectedItem;
      // No intervening frame: Apply must commit, rather than trust its build closure.
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('apply-timer-editor')),
          )
          .onPressed!();
      seconds.onSelectedItemChanged!(1);
      await tester.pumpAndSettle();
      expect(container.read(fixture.provider).module.workSeconds, expected);
      expect(container.read(fixture.provider).saved, fixture.original);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'block collapse, expansion and replacement ignore removed wheel events',
    (tester) async {
      final container = await fixture.openEditor(tester, (_) async => true);
      final custom = fixture.original.copyWith(
        timerMode: WorkoutTimerMode.custom,
        intervalBlocks: [
          const WorkoutIntervalBlock(
            id: 'one',
            workSeconds: 150,
            restSeconds: 30,
            sets: 1,
          ),
          const WorkoutIntervalBlock(
            id: 'two',
            workSeconds: 120,
            restSeconds: 0,
            sets: 1,
          ),
        ],
      );
      container.read(fixture.provider.notifier).update(custom);
      await tester.pumpAndSettle();
      await fixture.tap(tester, 'slide-timer-summary');
      final old = _picker(tester, 'one-work', 'seconds');
      await fixture.tap(tester, 'timer-block-one');
      old.onSelectedItemChanged!(55);
      await tester.pumpAndSettle();
      expect(find.byType(TimerDurationWheel), findsNothing);
      await fixture.tap(tester, 'timer-block-two');
      old.onSelectedItemChanged!(56);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('two-work-minutes-wheel')),
        findsOneWidget,
      );
      expect(
        container
            .read(timerEditorControllerProvider(custom))
            .module
            .intervalBlocks
            .first
            .workSeconds,
        150,
      );
      final second = _picker(tester, 'two-work', 'seconds');
      container
          .read(timerEditorControllerProvider(custom).notifier)
          .replace(timerModeCandidate(custom, WorkoutTimerMode.amrap));
      await tester.pumpAndSettle();
      final replaced = container
          .read(timerEditorControllerProvider(custom))
          .module;
      second.onSelectedItemChanged!(52);
      await tester.pumpAndSettle();
      expect(
        container.read(timerEditorControllerProvider(custom)).module,
        replaced,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  for (final scene in [
    (size: const Size(320, 568), scale: 1.0),
    (size: const Size(320, 844), scale: 2.0),
    (size: const Size(844, 390), scale: 1.0),
    (size: const Size(1440, 900), scale: 1.0),
  ]) {
    testWidgets(
      'page scroll, wheel gestures and fixed apply fit ${scene.size} x${scene.scale}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = scene.size;
        tester.platformDispatcher.textScaleFactorTestValue = scene.scale;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final container = await fixture.openEditor(tester, (_) async => true);
        await fixture.tap(tester, 'slide-timer-summary');
        await fixture.input(tester, 'timer-work', '999:59');
        expect(find.byType(TimerDurationWheel), findsOneWidget);
        expect(tester.testTextInput.isVisible, isFalse);
        final apply = find.byKey(const ValueKey('apply-timer-editor'));
        expect(apply.hitTestable(), findsOneWidget);
        await fixture.reveal(tester, 'timer-repeats');
        expect(
          find.byKey(const ValueKey('timer-repeats')).hitTestable(),
          findsOneWidget,
        );
        await fixture.input(tester, 'timer-repeats', '1');
        await fixture.tap(tester, 'apply-timer-editor');
        expect(container.read(fixture.provider).module.workSeconds, 59999);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}

Future<ValueNotifier<Map<String, int>>> _mount(
  WidgetTester tester, {
  bool trailingSpace = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final selection = TimerWheelSelection('work');
  final values = ValueNotifier({'work': 120, 'rest': 30});
  addTearDown(selection.dispose);
  addTearDown(values.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: XonTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                ValueListenableBuilder(
                  valueListenable: values,
                  builder: (context, current, _) => TimerDurationGroup(
                    selection: selection,
                    options: [
                      for (final field in ['work', 'rest'])
                        TimerDurationOption(
                          fieldKey: field,
                          label: field == 'work' ? '운동 시간' : '휴식 시간',
                          seconds: current[field]!,
                          onChanged: (value) =>
                              values.value = {...values.value, field: value},
                        ),
                    ],
                  ),
                ),
                if (trailingSpace) const SizedBox(height: 700),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return values;
}
