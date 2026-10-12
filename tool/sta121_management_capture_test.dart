// Production management widgets with local fixtures; no account/network needed.
// flutter test --no-pub tool/sta121_management_capture_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/core/platform/device_form_factor.dart';
import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/app_startup_screen.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/views/login_screen.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_mode.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_mode_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/views/display_settings_screen.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/widgets/playback_recovery_view.dart';
import 'package:cloud_board/src/app/feature/profile/presentation/views/more_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class _ControllerMode extends DeviceModeController {
  @override
  Future<DeviceMode> build() async => DeviceMode.controller;
}

void main() {
  testWidgets('capture sage management surfaces', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    // Match the export density so ResizeImage decodes at the captured size.
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

    for (final (name, screen) in <(String, Widget)>[
      ('startup', const AppStartupScreen()),
      ('startup-retry', AppStartupScreen(onRetry: () {})),
      ('login', const LoginScreen()),
      ('recovery', PlaybackRecoveryView(onRetry: () {})),
      (
        'recovery-error',
        PlaybackRecoveryView(
          error: StateError('Preview offline'),
          onRetry: () {},
        ),
      ),
      ('displays', const DisplaySettingsScreen(asMainTab: true)),
      ('more', const MoreScreen()),
    ]) {
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: ProviderScope(
            key: ValueKey(name),
            overrides: [
              androidTvProvider.overrideWith((_) async => false),
              authStateProvider.overrideWith(
                (_) => Stream.value(
                  screen is LoginScreen
                      ? null
                      : const AuthUser(
                          id: 'preview',
                          email: '',
                          displayName: '코치',
                          photoUrl: null,
                        ),
                ),
              ),
              deviceModeControllerProvider.overrideWith(_ControllerMode.new),
              displayDevicesProvider.overrideWith(
                (_) => Stream.value([
                  const DisplayDevice(
                    id: 'display',
                    name: '메인 TV',
                    zoneId: 'main',
                    zoneName: '운동 공간',
                    online: true,
                    lastSeenAtMs: 0,
                    currentSessionId: null,
                    acknowledgedRevision: 0,
                    paired: true,
                  ),
                ]),
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: XonTheme.light,
              builder: XonTheme.responsiveBuilder,
              home: screen,
            ),
          ),
        ),
      );
      // Use the widgets' exact providers, including ResizeImage/cacheWidth and
      // the provider login icon; AssetImage alone can warm a different key.
      final images = tester.elementList(find.byType(Image)).toList();
      await tester.runAsync(() async {
        await Future.wait(
          images.map(
            (element) =>
                precacheImage((element.widget as Image).image, element),
          ),
        );
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 600));
      if (screen is LoginScreen) {
        final scroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(LoginScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        scroll.position.jumpTo(0);
        await tester.pump();
        expect(scroll.position.pixels, 0);
      }
      final renderedImages = tester.widgetList<RawImage>(find.byType(RawImage));
      expect(renderedImages.length, images.length);
      expect(renderedImages.every((image) => image.image != null), isTrue);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('docs/design/sta121-v5/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
