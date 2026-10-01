// Production Flutter widget renders; no live class, account, or network needed.
// fvm flutter test --no-pub tool/playback_recovery_capture_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/widgets/playback_recovery_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  testWidgets('render the accepted recovery design on phone and TV', (
    tester,
  ) async {
    await (FontLoader('Pretendard')
          ..addFont(
            rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'),
          )
          ..addFont(
            rootBundle.load('assets/fonts/pretendard/Pretendard-ExtraBold.otf'),
          ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final (name, size, display, failed, scale) in [
      ('android', const Size(390, 844), false, false, 1.0),
      ('android-error', const Size(390, 844), false, true, 1.0),
      ('android-landscape-large-text', const Size(844, 390), false, true, 2.0),
      ('tv-1080p', const Size(960, 540), true, false, 1.0),
      ('tv-4k', const Size(1920, 1080), true, false, 1.0),
      ('tv-error', const Size(960, 540), true, true, 1.0),
    ]) {
      tester.view.physicalSize = size;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          child: RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: XonTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: PlaybackRecoveryView(
                displayMode: display,
                error: failed
                    ? StateError('Preview: network unavailable')
                    : null,
                onRetry: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          'docs/design/resume-sync-2026-10-01/evidence/$name.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    }
  });
}
