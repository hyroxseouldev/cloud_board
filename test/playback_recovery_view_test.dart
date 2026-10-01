import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/widgets/playback_recovery_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// Match the shell: the recovery overlay is above, not inside, the page Scaffold.
Widget harness(Widget view, {double scale = 1, bool reduceMotion = false}) =>
    ProviderScope(
      child: MaterialApp(
        theme: XonTheme.light,
        home: Stack(
          fit: StackFit.expand,
          children: [
            const Scaffold(body: Center(child: Text('수업 화면'))),
            Positioned.fill(child: view),
          ],
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
      ),
    );

void main() {
  testWidgets('shell overlay owns its style without a parent Material', (
    tester,
  ) async {
    await tester.pumpWidget(harness(PlaybackRecoveryView(onRetry: () {})));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    final label = tester.widget<RichText>(
      find.descendant(
        of: find.text('수업 동기화 중'),
        matching: find.byType(RichText),
      ),
    );
    expect(label.text.style?.fontFamily, 'Pretendard');
    expect(label.text.style?.fontSize, 14);
    expect(label.text.style?.color, AppColors.muted);
    expect(label.text.style?.decoration, TextDecoration.none);
    expect(
      tester.getSize(find.byType(CircularProgressIndicator)),
      const Size.square(22),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('slow recovery is distinct from failure and retry resets it', (
    tester,
  ) async {
    final error = ValueNotifier<Object?>(null);
    addTearDown(error.dispose);
    var retries = 0;
    await tester.pumpWidget(
      harness(
        ValueListenableBuilder<Object?>(
          valueListenable: error,
          builder: (_, value, _) => PlaybackRecoveryView(
            error: value,
            stackTrace: StackTrace.current,
            onRetry: () {
              retries++;
              error.value = null;
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('연결을 확인하고 있어요. 잠시만 기다려 주세요.'), findsOneWidget);
    error.value = StateError('server confirmation unavailable');
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('수업 동기화 중'), findsNothing);
    expect(find.text('다시 연결'), findsOneWidget);
    await tester.tap(find.text('오류 상세'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.textContaining(
        'server confirmation unavailable',
        findRichText: true,
      ),
      findsWidgets,
    );
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다시 연결'));
    await tester.pump();
    expect(retries, 1);
    expect(find.text('연결을 확인하고 있어요. 잠시만 기다려 주세요.'), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('수업 동기화 중'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'reduced motion uses a static status without a perpetual ticker',
    (tester) async {
      await tester.pumpWidget(
        harness(PlaybackRecoveryView(onRetry: () {}), reduceMotion: true),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('TV retry is reachable immediately with a remote select', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      harness(
        PlaybackRecoveryView(
          displayMode: true,
          error: StateError('offline'),
          onRetry: () => retries++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(retries, 1);
    await tester.tap(find.text('오류 상세'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(AlertDialog))).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final (size, display) in [
    (const Size(320, 568), false),
    (const Size(844, 390), false),
    (const Size(834, 1194), false),
    (const Size(960, 540), true), // 1080p TV at 2x.
    (const Size(1920, 1080), true), // 4K TV at 2x.
  ]) {
    testWidgets('large text, loading and errors fit $size, TV=$display', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        harness(
          PlaybackRecoveryView(displayMode: display, onRetry: () {}),
          scale: 2,
        ),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
      expect(find.text('CloudBoard'), display ? findsNothing : findsOneWidget);
      await tester.pumpWidget(
        harness(
          PlaybackRecoveryView(
            displayMode: display,
            error: StateError('offline'),
            onRetry: () {},
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('다시 연결'));
      if (display) {
        final retry = tester.widget<TextButton>(
          find.widgetWithText(TextButton, '다시 연결'),
        );
        expect(retry.autofocus, isTrue);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('dismissing a fast recovery cancels pending UI timers', (
    tester,
  ) async {
    await tester.pumpWidget(harness(PlaybackRecoveryView(onRetry: () {})));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
  });
}
