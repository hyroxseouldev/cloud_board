// Actual DisplayModeScreen with isolated transport; no live TV, network or ACK writes.
// flutter test tool/sta167_capture_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/feature/device/presentation/widgets/display_identification_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/audience_branding_fixture.dart' show audiencePumpUntil;
import '../test/support/display_identification_fixture.dart';

void main() {
  for (final item in [
    (
      file: 'tv-720p',
      size: const Size(1280, 720),
      scale: 1.0,
      id: 'tv-a',
      name: '메인 디스플레이',
      code: '0584',
      tv: true,
    ),
    (
      file: 'tv-1080p',
      size: const Size(1920, 1080),
      scale: 1.0,
      id: 'tv-b',
      name: '북쪽 스튜디오',
      code: '2196',
      tv: true,
    ),
    (
      file: 'tv-4k',
      size: const Size(3840, 2160),
      scale: 1.0,
      id: 'tv-c',
      name: '3층 스트레칭 공간',
      code: '8740',
      tv: true,
    ),
    (
      file: 'tv-720p-long-name-2x',
      size: const Size(1280, 720),
      scale: 2.0,
      id: 'tv-d',
      name: identificationLongName,
      code: '0584',
      tv: true,
    ),
    (
      file: 'web-1080p',
      size: const Size(1920, 1080),
      scale: 1.0,
      id: 'web',
      name: '웹 디스플레이',
      code: '4912',
      tv: false,
    ),
  ]) {
    testWidgets('capture ${item.file}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = item.size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final fonts = FontLoader('Pretendard');
      for (final weight in ['Regular', 'Medium', 'SemiBold']) {
        fonts.addFont(
          rootBundle.load('assets/fonts/pretendard/Pretendard-$weight.otf'),
        );
      }
      await fonts.load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final fixture = IdentificationFixture(
        tester,
        deviceId: item.id,
        isTv: item.tv,
      );
      addTearDown(fixture.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: fixture.app(textScale: item.scale),
        ),
      );
      await tester.pump();
      fixture.start([
        identificationDevice(item.id, item.name, 'nonce-${item.code}'),
      ]);
      await audiencePumpUntil(
        tester,
        () => find.byType(DisplayIdentificationOverlay).evaluate().isNotEmpty,
        'identification visible',
      );
      await tester.pump();
      expect(fixture.actions.acknowledgements, [
        '${item.id}:nonce-${item.code}',
      ]);
      expect(fixture.sound.calls, 0);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory('docs/design/sta167/screenshots')
          ..createSync(recursive: true);
        await File('${directory.path}/${item.file}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      await fixture.dispose();
    });
  }
}
