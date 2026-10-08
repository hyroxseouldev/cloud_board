import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/emom_builder_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Pretendard')
      ..addFont(
        rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'),
      )
      ..addFont(rootBundle.load('assets/fonts/pretendard/Pretendard-Bold.otf'));
    await fonts.load();
  });
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
    const Size(834, 1194),
  ]) {
    testWidgets('EMOM input, validation and preview at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: XonTheme.light,
          home: EmomBuilderScreen(module: WorkoutModule.empty('m')),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('emom-preset-rounds')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('emom-total')));
      expect(find.text('총 39:00'), findsOneWidget);
      expect(find.text('운동 18구간 · 휴식 6구간'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('emom-final-rest')),
        180,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('emom-builder')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('emom-final-rest')));
      await tester.pumpAndSettle();
      expect(find.text('총 38:30'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('emom-rounds')),
        -150,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('emom-builder')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('emom-rounds')), '0');
      await tester.pump();
      expect(find.text('1~999회로 입력해 주세요.'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('apply-emom')))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byKey(const ValueKey('emom-rounds')), '6');
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('apply-emom')))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'custom mixed configuration is not overwritten by opening or closing the builder',
    (tester) async {
      final emom = createEmom(WorkoutModule.empty('m'), (
        seconds: 120,
        intervals: 3,
        rounds: 6,
        restSeconds: 30,
        includeFinalRest: true,
      ));
      final mixed = emom.copyWith(
        intervalBlocks: [
          emom.intervalBlocks.first.copyWith(workSeconds: 90),
          ...emom.intervalBlocks.skip(1),
        ],
      );
      WorkoutModule? applied;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  applied = await Navigator.push<WorkoutModule>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EmomBuilderScreen(module: mixed),
                    ),
                  );
                },
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('현재는 사용자 지정 구성'), findsOneWidget);
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(applied, isNull);
      expect(mixed.intervalBlocks.first.workSeconds, 90);
    },
  );
}
