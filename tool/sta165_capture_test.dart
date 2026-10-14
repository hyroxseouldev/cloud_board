// Production display-mode evidence; run with `flutter test tool/sta165_capture_test.dart`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/feature/device/domain/entities/display_preferences.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/widgets/store_welcome_board.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_countdown.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/audience_branding_fixture.dart';

void main() {
  final scenes = [
    ('standby', const Size(1920, 1080)),
    ('countdown', const Size(1920, 1080)),
    ('exercise-dark', const Size(1920, 1080)),
    ('exercise-light', const Size(1920, 1080)),
    ('uploaded-image', const Size(1920, 1080)),
    ('rest', const Size(1920, 1080)),
    ('pause', const Size(1920, 1080)),
    ('plus-hidden', const Size(1920, 1080)),
    ('black', const Size(1920, 1080)),
    ('safe-area-cover', const Size(1920, 1080)),
    ('phone-portrait', const Size(390, 844)),
    ('tablet', const Size(1024, 768)),
    ('tv-4k', const Size(3840, 2160)),
  ];
  for (final (name, size) in scenes) {
    testWidgets('capture $name', (tester) async {
      final dpr = size.width < 500 ? 2.0 : 1.0;
      tester.view.devicePixelRatio = dpr;
      tester.view.physicalSize = size * dpr;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final fonts = FontLoader('Pretendard');
      for (final weight in [
        'Regular',
        'Medium',
        'SemiBold',
        'Bold',
        'ExtraBold',
        'Black',
      ]) {
        fonts.addFont(
          rootBundle.load('assets/fonts/pretendard/Pretendard-$weight.otf'),
        );
      }
      await fonts.load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final fixture = AudienceFixture(
        tester,
        isTv: size.width >= 1920,
        policy: name == 'plus-hidden'
            ? audienceFree.copyWith(showCloudBoardLogo: false)
            : audienceFree,
        preferences: name == 'safe-area-cover'
            ? const DisplayPreferences(
                enabled: true,
                cover: true,
                zoom: 1.4,
                offsetX: .05,
                offsetY: .05,
                safeInset: .08,
              )
            : const DisplayPreferences(),
      );
      addTearDown(fixture.dispose);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: boundary, child: fixture.app()),
      );
      await tester.pump();
      fixture.start();
      await audiencePumpUntil(
        tester,
        () => find.byType(StoreWelcomeBoard).evaluate().isNotEmpty,
        'standby ready',
      );
      if (name == 'black') {
        fixture.display('black');
        await audiencePumpUntil(
          tester,
          () => find.byType(StoreWelcomeBoard).evaluate().isEmpty,
          'black ready',
        );
      } else if (name != 'standby') {
        fixture.sessions.add(
          audienceSession(
            tester,
            workout: audienceWorkout(
              image: name == 'uploaded-image',
              bright:
                  name == 'exercise-light' ||
                  name == 'safe-area-cover' ||
                  name == 'tv-4k',
            ),
            delay: name == 'countdown' ? 10000 : 0,
            step: name == 'rest' ? 1 : 0,
            paused: name == 'pause',
          ),
        );
        await audiencePumpUntil(
          tester,
          () => find
              .byType(
                name == 'countdown' ? WorkoutCountdown : WorkoutSlideCanvas,
              )
              .evaluate()
              .isNotEmpty,
          'audience scene ready',
        );
      }
      final images = tester.elementList(find.byType(Image)).toList();
      await tester.runAsync(
        () => Future.wait(
          images.map(
            (element) =>
                precacheImage((element.widget as Image).image, element),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull, reason: name);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: dpr);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory('docs/design/sta165/screenshots')
          ..createSync(recursive: true);
        await File('${directory.path}/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      await fixture.dispose();
    });
  }
}
