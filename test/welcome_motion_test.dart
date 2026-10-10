import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/core/widgets/welcome_motion.dart';

void main() {
  testWidgets(
    'reduced motion renders form immediately and retains text across step animation',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      Widget form(int step, bool reduced) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(
            body: WelcomeMotion(
              motionKey: step,
              horizontal: true,
              child: TextField(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpWidget(form(0, true));
      final transition = find.descendant(
        of: find.byType(WelcomeMotion),
        matching: find.byType(FadeTransition),
      );
      expect(tester.widget<FadeTransition>(transition).opacity.value, 1);
      final fieldBefore = tester.element(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '센터 이름');
      await tester.pumpWidget(form(1, false));
      await tester.pump(const Duration(milliseconds: 180));
      expect(controller.text, '센터 이름');
      expect(tester.element(find.byType(TextField)), same(fieldBefore));
      expect(find.byType(TextField), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
