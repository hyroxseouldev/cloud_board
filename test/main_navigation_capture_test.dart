// Real router/screens with isolated local providers; no external service writes.
// Opt-in: NAV_CAPTURE_DIR points outside the repository.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'main_navigation_test.dart' show mountNavigation, navigationTest;

void main() {
  const output = String.fromEnvironment('NAV_CAPTURE_DIR');
  const phase = String.fromEnvironment(
    'NAV_CAPTURE_PHASE',
    defaultValue: 'after',
  );
  if (output.isEmpty) return;

  navigationTest('capture navigation at 390, 320 and enlarged text', (
    tester,
  ) async {
    for (final (family, asset) in [
      ('Pretendard', 'assets/fonts/pretendard/Pretendard-Regular.otf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      (
        'packages/lucide_icons_flutter/Lucide',
        'packages/lucide_icons_flutter/assets/lucide.ttf',
      ),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
    for (final (size, scale, name) in [
      (const Size(390, 844), 1.0, '390'),
      (const Size(320, 568), 1.0, '320'),
      (const Size(320, 568), 2.0, '320-large-text'),
    ]) {
      final captureKey = GlobalKey();
      await mountNavigation(
        tester,
        size: size,
        textScale: scale,
        captureKey: captureKey,
      );
      tester.view.padding = const FakeViewPadding(bottom: 24);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$output/$phase-$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
