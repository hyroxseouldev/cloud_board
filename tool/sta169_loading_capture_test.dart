import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/app_startup_screen.dart';
import 'package:cloud_board/src/app/core/widgets/soft_rhythm_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('capture shared startup mark and real Flutter breathing frames', (
    tester,
  ) async {
    final directory = Directory('docs/design/sta169');
    directory.createSync(recursive: true);
    final frames = Directory('build/sta169-motion');
    frames.createSync(recursive: true);
    await (FontLoader('Pretendard')..addFont(
          rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'),
        ))
        .load();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Future<GlobalKey> mount(
      Size size, {
      bool reduced = false,
      bool error = false,
      double textScale = 1,
    }) async {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = size * 2;
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: XonTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reduced,
              textScaler: TextScaler.linear(textScale),
            ),
            child: RepaintBoundary(key: key, child: child),
          ),
          home: AppStartupScreen(onRetry: error ? () {} : null),
        ),
      );
      await tester.runAsync(() async {
        final element = find.byType(SoftRhythmMark).evaluate().single;
        await precacheImage(
          SoftRhythmMark.imageProvider(element, 128),
          element,
        );
      });
      await tester.pump();
      return key;
    }

    Future<void> capture(GlobalKey key, String path) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(path).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    final phone = await mount(const Size(390, 844));
    await capture(phone, '${directory.path}/flutter-phone.png');
    for (var frame = 0; frame < 24; frame++) {
      await capture(
        phone,
        '${frames.path}/frame-${frame.toString().padLeft(2, '0')}.png',
      );
      await tester.pump(const Duration(milliseconds: 75));
    }
    for (final (name, size, reduced, error, textScale) in [
      ('flutter-desktop', const Size(1440, 900), false, false, 1.0),
      ('flutter-reduced-motion', const Size(390, 844), true, false, 1.0),
      ('flutter-error', const Size(390, 844), false, true, 1.0),
      ('flutter-error-large-text', const Size(568, 320), true, true, 2.0),
    ]) {
      final key = await mount(
        size,
        reduced: reduced,
        error: error,
        textScale: textScale,
      );
      await capture(key, '${directory.path}/$name.png');
      if (error && size.height < 400) {
        await tester.ensureVisible(find.text('다시 시도'));
        await tester.pump(const Duration(milliseconds: 300));
        await capture(key, '${directory.path}/$name-scrolled.png');
      }
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
