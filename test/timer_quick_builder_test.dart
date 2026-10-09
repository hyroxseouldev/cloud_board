import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/timer_quick_builder_screen.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
    const Size(834, 1194),
  ]) {
    for (final mode in [
      WorkoutTimerMode.amrap,
      WorkoutTimerMode.forTime,
      WorkoutTimerMode.tabata,
      WorkoutTimerMode.interval,
    ]) {
      testWidgets('${mode.name} creation and apply at $size', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final original = WorkoutModule.empty(
          'm',
        ).copyWith(name: '수업', text: '운동 설명', rounds: 6, roundRestSeconds: 30);
        WorkoutModule? applied;
        await tester.pumpWidget(
          MaterialApp(
            theme: XonTheme.light,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  child: const Text('열기'),
                  onPressed: () async {
                    applied = await Navigator.push<WorkoutModule>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TimerQuickBuilderScreen(module: original),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        final choice = find.byKey(ValueKey('timer-mode-${mode.name}'));
        await tester.scrollUntilVisible(choice, 150);
        await tester.pumpAndSettle();
        await tester.tap(choice);
        await tester.pumpAndSettle();
        expect(applied, isNull);
        final expected = switch (mode) {
          WorkoutTimerMode.tabata => '4:00',
          WorkoutTimerMode.forTime => '제한시간 없음',
          _ => '10:00',
        };
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('preset-total'))).data,
          expected,
        );
        if (mode == WorkoutTimerMode.forTime) {
          await tester.tap(find.byKey(const ValueKey('preset-time-cap')));
          await tester.pumpAndSettle();
          expect(find.text('최대 10:00'), findsOneWidget);
        }
        await tester.ensureVisible(find.byKey(const ValueKey('preset-work')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('preset-work')),
          '00:00',
        );
        await tester.pump();
        expect(
          tester
              .widget<TextButton>(
                find.byKey(const ValueKey('apply-timer-preset')),
              )
              .onPressed,
          isNull,
        );
        expect(find.text('00:01~999:59로 입력해 주세요.'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('preset-work')),
          mode == WorkoutTimerMode.tabata ? '00:20' : '02:00',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('apply-timer-preset')));
        await tester.pumpAndSettle();
        expect(applied, isNotNull);
        expect(applied!.timerMode, mode);
        expect(applied!.name, original.name);
        expect(applied!.text, original.text);
        expect(applied!.rounds, 1);
        expect(applied!.roundRestSeconds, 0);
        if (mode == WorkoutTimerMode.tabata) {
          expect(workoutModuleDuration(applied!), 240);
        }
        if (mode == WorkoutTimerMode.amrap ||
            mode == WorkoutTimerMode.forTime) {
          expect(workoutModuleDuration(applied!), 120);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'editing a Tabata preset produces an interval and cancel leaves source intact',
    (tester) async {
      final original = WorkoutModule.empty('m');
      await tester.pumpWidget(
        MaterialApp(
          home: TimerPresetEditor(
            module: original,
            mode: WorkoutTimerMode.tabata,
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('preset-work')),
        '00:30',
      );
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('시간·반복을 바꾼 구성은 인터벌로 저장합니다.'),
        150,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('시간·반복을 바꾼 구성은 인터벌로 저장합니다.'), findsOneWidget);
      expect(find.text('5:20'), findsOneWidget);
      expect(original.workSeconds, 60);
    },
  );
}
