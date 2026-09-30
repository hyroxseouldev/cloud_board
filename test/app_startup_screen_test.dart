import 'package:cloud_board/src/app/core/widgets/app_startup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(402, 874),
    const Size(1024, 1366),
    const Size(1920, 1080),
    const Size(568, 320),
  ]) {
    testWidgets('startup mark stays centered and bounded at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: AppStartupScreen()));
      final mark = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is StartupMarkPainter,
      );
      expect(tester.getSize(mark), const Size.square(128));
      expect(tester.getCenter(mark), Offset(size.width / 2, size.height / 2));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'retry is accessible with large text and does not move the mark',
    (tester) async {
      tester.view.physicalSize = const Size(568, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: AppStartupScreen(onRetry: () => retries++),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final mark = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is StartupMarkPainter,
      );
      expect(tester.getCenter(mark), const Offset(284, 160));
      await tester.ensureVisible(find.text('다시 시도'));
      await tester.tap(find.text('다시 시도'));
      expect(retries, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
