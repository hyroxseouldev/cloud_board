import 'package:cloud_board/src/app/core/router/app_page_transitions.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/async_action_overlay.dart';
import 'package:cloud_board/src/app/core/widgets/motion/app_animated_sliver_list.dart';
import 'package:cloud_board/src/app/core/widgets/motion/app_content_transition.dart';
import 'package:cloud_board/src/app/core/widgets/motion/app_press_feedback.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget motionApp(
  Widget child, {
  bool reduced = false,
  bool accessible = false,
}) => MaterialApp(
  theme: XonTheme.light,
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: reduced,
      accessibleNavigation: accessible,
    ),
    child: Scaffold(body: child),
  ),
);

void main() {
  testWidgets(
    'state reveal retains input, selection and focus through settings',
    (tester) async {
      Widget form(int state, {bool reduced = false}) => motionApp(
        AppContentTransition(transitionKey: state, child: const TextField()),
        reduced: reduced,
      );
      await tester.pumpWidget(form(0));
      final field = tester.element(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '새 수업 초안');
      final editing = tester.widget<EditableText>(find.byType(EditableText));
      final selection = editing.controller.selection;
      await tester.pumpWidget(form(1));
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.element(find.byType(TextField)), same(field));
      expect(editing.controller.text, '새 수업 초안');
      expect(editing.controller.selection, selection);
      expect(editing.focusNode.hasFocus, isTrue);
      await tester.pumpWidget(form(1, reduced: true));
      expect(tester.element(find.byType(TextField)), same(field));
      expect(editing.focusNode.hasFocus, isTrue);
      final fade = find.descendant(
        of: find.byType(AppContentTransition),
        matching: find.byType(FadeTransition),
      );
      expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
      await tester.pumpWidget(form(1));
      expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
      expect(tester.element(find.byType(TextField)), same(field));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  for (final accessible in [false, true]) {
    testWidgets(
      'reduced policy stops decorative feedback, accessible=$accessible',
      (tester) async {
        await tester.pumpWidget(
          motionApp(
            AppContentTransition(
              transitionKey: 1,
              animateOnMount: true,
              child: AppPressFeedback(
                child: FilledButton(onPressed: () {}, child: const Text('만들기')),
              ),
            ),
            reduced: !accessible,
            accessible: accessible,
          ),
        );
        await tester.pumpAndSettle();
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('만들기')),
        );
        await tester.pump(const Duration(milliseconds: 120));
        final transform = tester.widget<Transform>(
          find.descendant(
            of: find.byType(AppPressFeedback),
            matching: find.byType(Transform),
          ),
        );
        expect(transform.transform.entry(0, 0), 1);
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );
  }

  testWidgets(
    'press cancellation and disabling restore scale without invoking action',
    (tester) async {
      var calls = 0;
      Widget button(bool enabled) => motionApp(
        AppPressFeedback(
          enabled: enabled,
          child: SizedBox(
            width: 100,
            height: 60,
            child: FilledButton(
              onPressed: enabled ? () => calls++ : null,
              child: const Text('저장'),
            ),
          ),
        ),
      );
      double scale() => tester
          .widget<Transform>(
            find.descendant(
              of: find.byType(AppPressFeedback),
              matching: find.byType(Transform),
            ),
          )
          .transform
          .entry(0, 0);
      await tester.pumpWidget(button(true));
      var gesture = await tester.startGesture(
        tester.getCenter(find.text('저장')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(scale(), closeTo(.98, .001));
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(scale(), 1);
      expect(calls, 0);
      gesture = await tester.startGesture(tester.getCenter(find.text('저장')));
      await tester.pumpWidget(button(false));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(scale(), 1);
      expect(calls, 0);
      await tester.pumpWidget(button(true));
      await tester.tap(find.text('저장'));
      expect(calls, 1);
    },
  );

  testWidgets(
    'press wrapper preserves keyboard activation and original hit target',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var calls = 0;
      await tester.pumpWidget(
        motionApp(
          AppPressFeedback(
            child: SizedBox(
              width: 100,
              height: 60,
              child: FilledButton(
                focusNode: focus,
                onPressed: () => calls++,
                child: const Text('만들기'),
              ),
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.byType(FilledButton));
      final gesture = await tester.startGesture(
        Offset(rect.left + .5, rect.center.dy),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await gesture.up();
      expect(calls, 1);
      focus.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(calls, 2);
    },
  );

  testWidgets(
    'busy overlay blocks immediately and releases before its fade ends',
    (tester) async {
      var calls = 0;
      Widget screen(bool busy) => motionApp(
        AsyncActionOverlay(
          isLoading: busy,
          child: Center(
            child: FilledButton(
              onPressed: () => calls++,
              child: const Text('실행'),
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen(false));
      final button = tester.element(find.byType(FilledButton));
      await tester.pumpWidget(screen(true));
      await tester.tap(find.text('실행'), warnIfMissed: false);
      expect(calls, 0);
      await tester.pumpWidget(screen(false));
      expect(tester.element(find.byType(FilledButton)), same(button));
      await tester.tap(find.text('실행'));
      expect(calls, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'busy status remains accessible without spinning under reduced motion',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          motionApp(
            const AsyncActionOverlay(isLoading: true, child: SizedBox.expand()),
            reduced: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('처리 중'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(tester.binding.hasScheduledFrame, isFalse);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'list preserves existing row identity and removed rows cannot act',
    (tester) async {
      final tapped = <String>[];
      Widget list(
        List<String> items, {
        Object scope = 'all',
        bool reduced = false,
      }) => motionApp(
        CustomScrollView(
          slivers: [
            AppAnimatedSliverList<String>(
              items: items,
              idOf: (item) => item,
              scope: scope,
              itemBuilder: (_, item) => SizedBox(
                height: 60,
                child: TextButton(
                  onPressed: () => tapped.add(item),
                  child: Text(item),
                ),
              ),
            ),
          ],
        ),
        reduced: reduced,
      );
      await tester.pumpWidget(list(['a', 'b']));
      await tester.pumpAndSettle();
      final before = tester.element(find.text('a'));
      await tester.pumpWidget(list(['a', 'c', 'b']));
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.element(find.text('a')), same(before));
      await tester.pumpWidget(list(['a', 'c']));
      expect(find.text('b'), findsOneWidget);
      await tester.tap(find.text('b'), warnIfMissed: false);
      expect(tapped, isEmpty);
      await tester.pumpAndSettle();
      expect(find.text('b'), findsNothing);
      expect(tester.element(find.text('a')), same(before));
      await tester.pumpWidget(
        list(['a', 'c', for (var i = 0; i < 12; i++) 'page-$i']),
      );
      expect(tester.element(find.text('a')), same(before));
      await tester.pumpWidget(list(['z'], scope: 'search'));
      expect(find.text('a'), findsNothing);
      expect(find.text('z').hitTestable(), findsOneWidget);
      await tester.pumpWidget(list(['z', 'y'], scope: 'search'));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpWidget(list(['z', 'y'], scope: 'search', reduced: true));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rapid snapshots and sort changes leave the latest list in order',
    (tester) async {
      Widget list(List<String> items) => motionApp(
        CustomScrollView(
          slivers: [
            AppAnimatedSliverList<String>(
              items: items,
              idOf: (item) => item,
              scope: 'all',
              itemBuilder: (_, item) => SizedBox(height: 60, child: Text(item)),
            ),
          ],
        ),
      );
      await tester.pumpWidget(list(['a', 'b']));
      await tester.pumpWidget(list(['a', 'c', 'b']));
      await tester.pumpWidget(list(['a', 'c']));
      await tester.pumpWidget(list(['c', 'a', 'd']));
      await tester.pumpAndSettle();
      expect(find.text('b'), findsNothing);
      expect(
        tester.getTopLeft(find.text('c')).dy,
        lessThan(tester.getTopLeft(find.text('a')).dy),
      );
      expect(find.text('d'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'native navigation keeps platform delegates; web uses the lightweight fade',
    () {
      final base = ThemeData();
      final theme = AppTheme.apply(base);
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        if (kIsWeb) {
          expect(
            theme.pageTransitionsTheme.builders[platform],
            isA<AppWebPageTransitions>(),
          );
        } else {
          expect(
            theme.pageTransitionsTheme.builders[platform],
            same(base.pageTransitionsTheme.builders[platform]),
          );
        }
      }
    },
  );
}
