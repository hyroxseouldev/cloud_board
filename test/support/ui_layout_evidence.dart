import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const layoutEvidenceDirectory = String.fromEnvironment('STA190_EVIDENCE');

final uiLayoutScenes = [
  for (final size in const [
    Size(320, 568),
    Size(390, 844),
    Size(430, 932),
    Size(834, 1194),
    Size(844, 390),
  ])
    for (final scale in [1.0, 1.3, 2.0]) (size: size, scale: scale),
];

Future<void> loadLayoutFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    await (FontLoader('Pretendard')..addFont(
          rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
}

/// Optional local widget screenshots, never evidence of a running app/E2E.
Future<void> captureLayout(
  WidgetTester tester,
  Finder boundary,
  String name,
) async {
  if (layoutEvidenceDirectory.isEmpty) return;
  // Native image decoding completes outside the widget test's fake clock.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 250)),
  );
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final image = await tester
        .renderObject<RenderRepaintBoundary>(boundary)
        .toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$layoutEvidenceDirectory/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
