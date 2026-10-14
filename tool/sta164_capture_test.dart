// Reproducible production-widget evidence, synthetic account only.
// flutter test tool/sta164_capture_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/feature/onboarding/domain/entities/center_onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../test/support/onboarding_fixture.dart';

void main() {
  for (final fixture in [
    (name: 'phone-verification', value: const CenterOnboarding(), error: false),
    (
      name: 'activation-retry',
      value: confirmedFree.copyWith(activationReady: false),
      error: true,
    ),
    (name: 'free-confirmed', value: confirmedFree, error: false),
  ]) {
    testWidgets('capture ${fixture.name}', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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

      final boundary = GlobalKey();
      final repo = FakeOnboarding(fixture.value);
      await tester.pumpWidget(
        RepaintBoundary(key: boundary, child: onboardingApp(repo)),
      );
      await tester.pumpAndSettle();
      if (fixture.error) {
        repo.loadError = StateError('연결을 확인한 뒤 다시 시도해 주세요.');
        await tester.tap(find.text('이용 상태 다시 확인'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('docs/design/sta164/${fixture.name}.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
