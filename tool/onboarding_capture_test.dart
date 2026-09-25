import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/onboarding_test.dart' as fixture;

import 'package:cloud_board/src/app/feature/onboarding/domain/entities/center_onboarding.dart';

void main() {
  testWidgets('capture native onboarding design', (tester) async {
    await (FontLoader('Pretendard')..addFont(
          rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final phone in [false, true]) {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: fixture.app(
            fixture.FakeOnboarding(
              CenterOnboarding(phoneRequired: phone, storeId: 'center'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (!phone) {
        await tester.tap(find.text('운영 중인 센터에 연결하기'));
        await tester.pumpAndSettle();
      }
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/onboarding-${phone ? 'phone' : 'purpose'}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
