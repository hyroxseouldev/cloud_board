import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preferences.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_canvas.dart';

void main() {
  testWidgets(
    'set label shares timer anchor and stays above brand footer at screen edges',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final position in [
        const Offset(0, 0),
        const Offset(.5, .5),
        const Offset(1, 1),
      ]) {
        for (final showTimer in [true, false]) {
          final initial = WorkoutModule.empty('m');
          final module = initial.copyWith(
            showTimer: showTimer,
            showSets: true,
            appearance: initial.appearance.copyWith(
              timerX: position.dx,
              timerY: position.dy,
              timerSize: 1.6,
            ),
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: WorkoutSlideCanvas(
                  module: module,
                  isRest: false,
                  secondsLeft: 60,
                  remainingMs: 60000,
                  durationMs: 60000,
                  set: 1,
                  totalSets: 3,
                  isPaused: false,
                  brandL: 'LEFT',
                  brandR: 'RIGHT',
                  scale: 1,
                  displayPreferences: const DisplayPreferences(
                    enabled: true,
                    safeInset: .1,
                  ),
                ),
              ),
            ),
          );
          final sets = tester.getRect(find.byKey(const ValueKey('slide-sets')));
          expect(sets.left, greaterThanOrEqualTo(128));
          expect(sets.right, lessThanOrEqualTo(1152));
          expect(sets.top, greaterThanOrEqualTo(72));
          expect(sets.bottom, lessThanOrEqualTo(720 - 72 - 64));
          if (showTimer) {
            final timer = tester.getRect(
              find.byKey(const ValueKey('slide-timer')),
            );
            expect(sets.center.dx, closeTo(timer.center.dx, .1));
            expect(sets.top, greaterThan(timer.bottom));
          } else {
            expect(find.byKey(const ValueKey('slide-timer')), findsNothing);
          }
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
}
