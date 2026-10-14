import 'dart:async';

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_control_panel.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_interval_slider_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

final _module = WorkoutModule.empty('warmup')
    .copyWith(name: '웜업', workSeconds: 180);
final _slider = find.byKey(const ValueKey('slide-detail-timeline'));

void main() {
  for (final viewport in [
    (320.0, 2.0),
    (390.0, 1.0),
    (834.0, 1.0),
    (1200.0, 1.0),
  ]) {
    testWidgets('detail touch/labels use full duration at $viewport', (
      tester,
    ) async {
      tester.view.physicalSize = Size(viewport.$1, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <int>[];
      await tester.pumpWidget(
        _app(
          elapsed: 11000,
          scale: viewport.$2,
          onSeek: (_, elapsed) async => calls.add(elapsed),
        ),
      );
      expect(find.text('0:11 / 3:00'), findsOneWidget);
      expect(find.text('2:49 남음'), findsOneWidget);
      final slider = tester.widget<Slider>(_slider);
      expect(slider.value / slider.max, closeTo(11 / 180, .00001));
      expect(slider.semanticFormatterCallback!(180000), contains('2:59'));
      final theme = SliderTheme.of(tester.element(_slider));
      expect(theme.trackShape, isA<WorkoutIntervalSliderTrack>());
      expect(tester.getSize(_slider).height, greaterThanOrEqualTo(40));
      final rect = tester.getRect(_slider);
      final drag = await tester.startGesture(rect.center);
      await drag.moveTo(Offset(rect.right - 1, rect.center.dy));
      await tester.pump();
      expect(calls, isEmpty);
      expect(find.text('2:59 / 3:00'), findsOneWidget);
      expect(find.text('0:01 남음'), findsOneWidget);
      await drag.up();
      await tester.pumpAndSettle();
      expect(calls, [179000]);
      // Canceled reverse drag cannot send a command.
      final canceled = await tester.startGesture(rect.center);
      await canceled.moveTo(Offset(rect.left + 1, rect.center.dy));
      await canceled.cancel();
      await tester.pumpAndSettle();
      expect(calls, [179000]);
      expect(tester.widget<Slider>(_slider).value, 11000);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pending and rejected seek restore confirmed position', (
    tester,
  ) async {
    final pending = Completer<void>();
    final calls = <int>[];
    await tester.pumpWidget(
      _app(
        elapsed: 11000,
        onSeek: (_, elapsed) {
          calls.add(elapsed);
          return pending.future;
        },
      ),
    );
    var slider = tester.widget<Slider>(_slider);
    slider.onChangeStart!(90000);
    slider.onChanged!(90000);
    await tester.pump();
    expect(tester.widget<Slider>(_slider).value, 90000);
    expect(find.text('1:30 / 3:00'), findsOneWidget);
    slider.onChangeEnd!(90000);
    await tester.pump();
    expect(find.text('이동 중…'), findsOneWidget);
    slider = tester.widget<Slider>(_slider);
    expect(slider.onChanged, isNull);
    expect(slider.value, 11000);
    await tester.tap(_slider);
    expect(calls, [90000]);
    // A rejected remote command keeps its previous parent-confirmed value.
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(_slider).value, 11000);
    expect(find.text('0:11 / 3:00'), findsOneWidget);
    expect(find.text('이동 중…'), findsNothing);
  });

  testWidgets('completed and zero-length states stay bounded and readable', (
    tester,
  ) async {
    await tester.pumpWidget(_app(elapsed: 180000, onSeek: (_, _) async {}));
    var slider = tester.widget<Slider>(_slider);
    expect(slider.value, slider.max);
    expect(slider.semanticFormatterCallback!(180000), contains('3:00'));
    expect(find.text('3:00 / 3:00'), findsOneWidget);
    await tester.pumpWidget(_app(elapsed: 1000, duration: 0));
    slider = tester.widget<Slider>(_slider);
    expect(slider.value, 0);
    expect(slider.onChanged, isNull);
    expect(find.text('0:00 / 0:00'), findsOneWidget);
    await tester.tap(_slider);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard and semantics keep native Slider seeking', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final calls = <int>[];
      await tester.pumpWidget(
        _app(elapsed: 90000, onSeek: (_, elapsed) async => calls.add(elapsed)),
      );
      expect(
        _semanticsValues(tester.getSemantics(_slider)),
        contains('웜업 내 1:30, 1세트 운동'),
      );
      // Popup first, then the detail slider: preserve native focus traversal.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(calls, isNotEmpty);
      expect(calls.last, greaterThan(90000));
      calls.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(calls.last, lessThan(90000));
      await tester.pumpWidget(_app(elapsed: 90000));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
    } finally {
      semantics.dispose();
    }
  });
}

Widget _app({
  required int elapsed,
  int duration = 180,
  double scale = 1,
  Future<void> Function(int, int)? onSeek,
}) => MaterialApp(
  theme: XonTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: WorkoutControlTimeline(
          section: WorkoutTimelineSection.detail,
          modules: [_module],
          durations: [duration],
          currentModule: 0,
          elapsedMs: elapsed,
          onSeek: onSeek,
        ),
      ),
    ),
  ),
);

Iterable<String> _semanticsValues(SemanticsNode node) sync* {
  yield node.value;
  final children = <SemanticsNode>[];
  node.visitChildren((child) {
    children.add(child);
    return true;
  });
  for (final child in children) {
    yield* _semanticsValues(child);
  }
}
