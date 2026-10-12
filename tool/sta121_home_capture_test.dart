import 'package:cloud_board/src/app/feature/workouts/presentation/services/workout_image_loader.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../test/support/main_navigation_fixture.dart';
import '../test/home_workout_loading_test.dart' as loading_fixture;

void main() {
  testWidgets(
    'capture v5 home and navigation at mobile, tablet and desktop sizes',
    (tester) async {
      Directory('docs/design/sta121-v5').createSync(recursive: true);
      await (FontLoader('Pretendard')
            ..addFont(
              rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'),
            )
            ..addFont(
              rootBundle.load('assets/fonts/pretendard/Pretendard-Medium.otf'),
            )
            ..addFont(
              rootBundle.load(
                'assets/fonts/pretendard/Pretendard-SemiBold.otf',
              ),
            ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final boundary = GlobalKey();
      tester.view.devicePixelRatio = 2;
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
          await File('docs/design/sta121-v5/$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      for (final (size, scale, name) in [
        (const Size(390, 844), 1.0, 'home-390-active'),
        (const Size(320, 568), 1.0, 'home-320-active'),
        (const Size(320, 568), 2.0, 'home-320-large-text'),
        (const Size(844, 390), 1.0, 'home-landscape'),
        (const Size(834, 1194), 1.0, 'home-ipad-portrait'),
        (const Size(1194, 834), 1.0, 'home-ipad-landscape'),
        (const Size(1440, 900), 1.0, 'home-desktop'),
      ]) {
        tester.view.physicalSize = size * 2;
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
        if (name == 'home-390-active') {
          data.setSession(null);
          await capture('home-390-idle');
        }
        await tester.pumpWidget(const SizedBox.shrink());
        data.dispose();
        await tester.pump();
      }
    },
  );

  testWidgets('capture v5 home loading, empty and recovery states', (
    tester,
  ) async {
    final font = FontLoader('Pretendard')
      ..addFont(
        rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'),
      )
      ..addFont(
        rootBundle.load('assets/fonts/pretendard/Pretendard-SemiBold.otf'),
      );
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final directory = Directory('docs/design/sta121-v5')
      ..createSync(recursive: true);
    final key = GlobalKey();
    final repository = loading_fixture.ControlledHomeCatalog();
    Future<void> capture(String name) => tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('${directory.path}/home-$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await loading_fixture.mountLoadingHome(
      tester,
      repository,
      captureKey: key,
      size: const Size(390, 844),
      reducedMotion: true,
    );
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    await tester.pump(const Duration(milliseconds: 151));
    await tester.pump();
    await capture('loading');
    repository.requests.first.addError(StateError('offline'));
    await tester.pumpAndSettle();
    await capture('error');
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    repository.respond(1, []);
    await tester.pumpAndSettle();
    await capture('empty');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
