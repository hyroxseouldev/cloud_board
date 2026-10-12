import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_briefing_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final workout =
      Workout.empty(
        'class',
        const WorkoutAuthor(id: 'coach', displayName: '코치', photoUrl: null),
      ).copyWith(
        name: '오늘의 수업',
        brandL: '사용자 센터',
        brandR: '사용자 안내',
        modules: [
          WorkoutModule.empty('exercise')
              .copyWith(name: '스쿼트', text: '천천히 내려가요'),
        ],
      );

  for (final display in [false, true]) {
    testWidgets('management theme preserves broadcast briefing, TV=$display', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: XonTheme.light,
          home: WorkoutBriefingBoard(workout: workout, displayMode: display),
        ),
      );
      TextStyle renderedStyle(String label) => tester
          .widget<RichText>(
            find.descendant(
              of: find.text(label),
              matching: find.byType(RichText),
            ),
          )
          .text
          .style!;

      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        display ? Colors.white : AppColors.canvas,
      );
      expect(
        renderedStyle('오늘의 수업').fontWeight,
        display ? FontWeight.w700 : FontWeight.w600,
      );
      expect(
        renderedStyle('오늘의 수업').color,
        display ? const Color(0xFF202028) : AppColors.ink,
      );
      if (display) {
        expect(renderedStyle('오늘의 수업').fontSize, 44);
        expect(renderedStyle('오늘의 수업').letterSpacing, -2.2);
        expect(renderedStyle('1. 스쿼트').fontSize, 28);
        expect(renderedStyle('사용자 센터').fontSize, 24);
        expect(renderedStyle('사용자 안내').color, const Color(0xFF777683));
      }
      final card = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>()
          .where(
            (decoration) =>
                decoration.borderRadius == BorderRadius.circular(24),
          );
      expect(
        card.any(
          (decoration) =>
              decoration.color ==
              (display ? const Color(0xFFF5F4F8) : AppColors.surface),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
