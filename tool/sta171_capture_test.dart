// Actual support screen, fake transport. Never sends a real ticket or email.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/feature/support/domain/entities/support_ticket.dart';
import 'package:cloud_board/src/app/feature/support/presentation/controllers/support_controller.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/support_ticket_fixture.dart';

void main() {
  for (final item in [
    (file: 'form-mobile', size: const Size(390, 844)),
    (file: 'attachment-mobile', size: const Size(390, 844)),
    (file: 'retry-mobile', size: const Size(390, 844)),
    (file: 'received-desktop', size: const Size(1280, 900)),
  ]) {
    testWidgets('capture ${item.file}', (tester) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = item.size * 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final font = FontLoader('Pretendard');
      for (final weight in ['Regular', 'Medium', 'SemiBold']) {
        font.addFont(
          rootBundle.load('assets/fonts/pretendard/Pretendard-$weight.otf'),
        );
      }
      await font.load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final fixture = SupportFixture();
      addTearDown(fixture.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: fixture.app(
            initialDiagnostics: {
              'errorId': 'example-error-20261014',
              'occurredAtMs': 1791986400000,
              'action': 'playback.start',
            },
          ),
        ),
      );
      await tester.pump();
      fixture.users.add(supportUser);
      await tester.pumpAndSettle();
      final controller = fixture.container.read(
        supportControllerProvider.notifier,
      );
      controller.message('TV 3대가 준비됐다는 안내 후 수업 시작을 눌렀는데, 시작하지 못했다는 안내가 나왔어요.');
      if (item.file == 'attachment-mobile') {
        controller.attachment(
          SupportAttachment(
            bytes: (await tester.runAsync(
              () =>
                  File('docs/design/sta164/activation-retry.png').readAsBytes(),
            ))!,
            contentType: 'image/png',
            fileId: 'fixture-screenshot',
          ),
        );
      }
      if (item.file == 'retry-mobile') {
        fixture.repository.handler = (_) async =>
            throw FirebaseFunctionsException(
              code: 'unavailable',
              message: 'Fixture unavailable',
            );
        await controller.submit(fixture.available);
      }
      if (item.file == 'received-desktop') {
        await controller.submit(fixture.available);
      }
      await tester.pumpAndSettle();
      if (item.file == 'attachment-mobile') {
        for (final element in find.byType(Image).evaluate()) {
          await tester.runAsync(
            () => precacheImage((element.widget as Image).image, element),
          );
        }
        await tester.ensureVisible(
          find.byKey(const ValueKey('support-screenshot-preview')),
        );
        await tester.pumpAndSettle();
      }
      if (item.file == 'retry-mobile') {
        await tester.ensureVisible(
          find.byKey(const ValueKey('support-submit')),
        );
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory('docs/design/sta171/screenshots')
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
