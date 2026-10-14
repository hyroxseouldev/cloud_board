import 'package:cloud_board/src/app/core/widgets/soft_rhythm_loading_mark.dart';
import 'package:cloud_board/src/app/core/widgets/soft_rhythm_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  double scale(WidgetTester tester) =>
      tester.widget<ScaleTransition>(find.byType(ScaleTransition)).scale.value;
  double opacity(WidgetTester tester) =>
      tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value;
  Widget loading({
    bool reduced = false,
    bool accessible = false,
    bool visible = true,
  }) => MediaQuery(
    data: MediaQueryData(
      disableAnimations: reduced,
      accessibleNavigation: accessible,
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: TickerMode(enabled: visible, child: const SoftRhythmLoadingMark()),
    ),
  );

  testWidgets(
    'original mark breathes without moving its center or repeating semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(loading());
      final center = tester.getCenter(find.byType(SoftRhythmMark));
      expect(scale(tester), 1);
      expect(opacity(tester), 1);
      await tester.pump(const Duration(milliseconds: 900));
      expect(scale(tester), closeTo(.97, .00001));
      expect(opacity(tester), closeTo(.80, .00001));
      expect(tester.getCenter(find.byType(SoftRhythmMark)), center);
      expect(find.bySemanticsLabel('앱 준비 중'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 900));
      expect(scale(tester), closeTo(1, .00001));
      expect(opacity(tester), closeTo(1, .00001));
      expect(find.bySemanticsLabel('앱 준비 중'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      semantics.dispose();
    },
  );

  testWidgets(
    'reduced motion and accessible navigation are static, including live changes',
    (tester) async {
      final semantics = tester.ensureSemantics();
      for (final accessible in [false, true]) {
        await tester.pumpWidget(
          loading(reduced: !accessible, accessible: accessible),
        );
        await tester.pump(const Duration(seconds: 4));
        expect(scale(tester), 1);
        expect(opacity(tester), 1);
        expect(tester.binding.transientCallbackCount, 0);
        expect(find.bySemanticsLabel('앱 준비 중'), findsOneWidget);
      }
      await tester.pumpWidget(loading());
      await tester.pump(const Duration(milliseconds: 450));
      expect(scale(tester), lessThan(1));
      await tester.pumpWidget(loading(reduced: true));
      await tester.pump();
      expect(scale(tester), 1);
      expect(tester.binding.transientCallbackCount, 0);
      semantics.dispose();
    },
  );

  testWidgets(
    'background and covered route stop ticks; foreground resumes and dispose releases them',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      await tester.pumpWidget(loading());
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
        expect(scale(tester), 1);
        expect(tester.binding.transientCallbackCount, 0);
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(scale(tester), lessThan(1));
      await tester.pumpWidget(loading(visible: false));
      await tester.pump();
      expect(scale(tester), 1);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(loading());
      await tester.pump(const Duration(milliseconds: 450));
      expect(scale(tester), lessThan(1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
