import 'package:cloud_board/src/app/feature/workouts/presentation/services/workout_image_loader.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../test/support/main_navigation_fixture.dart';

void main() {
  testWidgets(
    'capture production main navigation at mobile, tablet and desktop sizes',
    (tester) async {
      await (FontLoader('Pretendard')..addFont(
            rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final boundary = GlobalKey();
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('docs/design/home-bottom-navigation-2026-10-10/$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      for (final (size, scale, name) in [
        (const Size(390, 844), 1.0, 'home-implemented'),
        (const Size(320, 568), 1.0, 'compact-implemented'),
        (const Size(320, 568), 2.0, 'large-text-implemented'),
        (const Size(844, 390), 1.0, 'landscape-implemented'),
        (const Size(834, 1194), 1.0, 'tablet-implemented'),
        (const Size(1440, 900), 1.0, 'desktop-implemented'),
      ]) {
        tester.view.physicalSize = size;
        final imageSource = await tester.runAsync(navigationPreviewImage);
        final data = NavigationPreviewData(imageSource: imageSource!);
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: UncontrolledProviderScope(
              container: data.container,
              child: MainNavigationPreview(textScale: scale),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => precacheImage(
            workoutImageProvider(imageSource, (width: 128, height: 128)),
            boundary.currentContext!,
          ),
        );
        await capture(name);
        if (name == 'home-implemented') {
          data.container.read(appRouterProvider).go('/slides');
          await capture('library-implemented');
          data.container.read(appRouterProvider).go('/more');
          await capture('more-implemented');
          data.container.read(appRouterProvider).go('/');
          data.setSession(null);
          await capture('idle-implemented');
        }
        await tester.pumpWidget(const SizedBox.shrink());
        data.dispose();
        await tester.pump();
      }
    },
  );
}
