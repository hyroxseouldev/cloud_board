import 'package:cloud_board/src/app/core/widgets/keyboard_dismiss_region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
  builder: (context, navigator) => KeyboardDismissRegion(child: navigator!),
  home: Scaffold(body: child),
);

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform dismisses numeric keyboard without losing input', (
      tester,
    ) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetViewInsets);
      final focus = FocusNode();
      final controller = TextEditingController();
      addTearDown(focus.dispose);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          TextField(
            focusNode: focus,
            controller: controller,
            keyboardType: TextInputType.number,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '123');
      expect(focus.hasFocus, isTrue);
      expect(
        find.widgetWithIcon(IconButton, Icons.keyboard_hide_outlined),
        findsOneWidget,
      );
      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.keyboard_hide_outlined),
      );
      await tester.pump();
      expect(focus.hasFocus, isFalse);
      expect(controller.text, '123');
      tester.view.resetViewInsets();
      await tester.pump();
      expect(
        find.widgetWithIcon(IconButton, Icons.keyboard_hide_outlined),
        findsNothing,
      );
    }, variant: TargetPlatformVariant.only(platform));

    testWidgets('$platform outside tap dismisses but multiline keeps newline', (
      tester,
    ) async {
      final focus = FocusNode();
      final controller = TextEditingController();
      addTearDown(focus.dispose);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              TextField(focusNode: focus, controller: controller, maxLines: 3),
              const Expanded(child: SizedBox.expand(key: ValueKey('outside'))),
            ],
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '첫 줄\n둘째 줄');
      expect(
        tester.testTextInput.setClientArgs?['inputAction'],
        'TextInputAction.newline',
      );
      expect(focus.hasFocus, isTrue);
      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('outside'))),
      );
      await tester.pump();
      expect(focus.hasFocus, isFalse);
      expect(controller.text, '첫 줄\n둘째 줄');
    }, variant: TargetPlatformVariant.only(platform));

    testWidgets('$platform toolbar works above dialog and modal sheet', (
      tester,
    ) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetViewInsets);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        AlertDialog(content: TextField(focusNode: focus)),
                  ),
                  child: const Text('Dialog'),
                ),
                TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      child: TextField(focusNode: focus),
                    ),
                  ),
                  child: const Text('Sheet'),
                ),
              ],
            ),
          ),
        ),
      );
      for (final label in ['Dialog', 'Sheet']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(TextField));
        await tester.pump();
        expect(focus.hasFocus, isTrue);
        final field = tester.getRect(find.byType(TextField));
        final dismiss = tester.getRect(
          find.widgetWithIcon(IconButton, Icons.keyboard_hide_outlined),
        );
        expect(field.bottom, lessThanOrEqualTo(dismiss.top));
        await tester.tap(
          find.widgetWithIcon(IconButton, Icons.keyboard_hide_outlined),
        );
        await tester.pump();
        expect(focus.hasFocus, isFalse);
        Navigator.of(tester.element(find.byType(TextField))).pop();
        await tester.pumpAndSettle();
      }
    }, variant: TargetPlatformVariant.only(platform));
  }
}
