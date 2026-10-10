import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/home_workout_loading_test.dart' as fixture;

void main() {
  testWidgets('capture first-entry loading and recovery with native Flutter', (
    tester,
  ) async {
    final previousShadows = debugDisableShadows;
    debugDisableShadows = false;
    final font = FontLoader('Pretendard')
      ..addFont(
        rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'),
      );
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final directory = Directory('docs/design/home-loading-2026-10-09');
    directory.createSync(recursive: true);

    Future<void> capture(GlobalKey key, String name) =>
        tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 3);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('${directory.path}/implementation-$name.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });

    final key = GlobalKey();
    final repository = fixture.ControlledHomeCatalog();
    await fixture.mountLoadingHome(
      tester,
      repository,
      captureKey: key,
      padding: const EdgeInsets.only(top: 62, bottom: 34),
    );
    await tester.pump(const Duration(milliseconds: 151));
    await tester.pump(const Duration(milliseconds: 650));
    await capture(key, 'loading');
    repository.requests.first.addError(StateError('offline'));
    await tester.pumpAndSettle();
    await capture(key, 'error');
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    repository.respond(1, fixture.homeCatalog());
    await tester.pumpAndSettle();
    await capture(key, 'loaded');
    await tester.pumpWidget(const SizedBox.shrink());

    for (final (name, size, scale) in [
      ('large-text', const Size(320, 568), 2.0),
      ('tablet', const Size(1194, 834), 1.0),
    ]) {
      final key = GlobalKey();
      await fixture.mountLoadingHome(
        tester,
        fixture.ControlledHomeCatalog(),
        captureKey: key,
        size: size,
        textScale: scale,
        reducedMotion: true,
      );
      await tester.pump(const Duration(milliseconds: 151));
      await tester.pump();
      await capture(key, name);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    debugDisableShadows = previousShadows;
  });
}
