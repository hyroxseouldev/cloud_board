import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/home_workout_loading_test.dart' as fixture;

// Captures production widgets with deterministic repository responses. These
// frames demonstrate timing and layout, not device frame-rate performance.
void main() {
  testWidgets('capture home feedback with normal and reduced motion', (
    tester,
  ) async {
    final previousShadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = previousShadows);
    await (FontLoader('Pretendard')..addFont(
          rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();

    for (final reduced in [false, true]) {
      final key = GlobalKey();
      final repository = fixture.ControlledHomeCatalog();
      final directory = Directory(
        'build/motion-capture/${reduced ? 'reduced' : 'normal'}',
      )..createSync(recursive: true);
      var frame = 0;
      Future<void> frames(int count) async {
        for (var i = 0; i < count; i++) {
          await tester.pump(const Duration(milliseconds: 40));
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '${directory.path}/${(frame++).toString().padLeft(3, '0')}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          expect(tester.takeException(), isNull);
        }
      }

      final container = await fixture.mountLoadingHome(
        tester,
        repository,
        captureKey: key,
        reducedMotion: reduced,
        padding: const EdgeInsets.only(top: 62, bottom: 34),
      );
      final catalog = fixture.homeCatalog(6);
      repository.respond(0, catalog);
      await tester.pumpAndSettle();
      await frames(12);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byTooltip('워크아웃 추가')),
      );
      await frames(5);
      await gesture.cancel();
      await frames(10);
      final removal = container
          .read(workoutControllerProvider.notifier)
          .refresh();
      await tester.pump();
      repository.respond(1, catalog.sublist(1));
      await removal;
      await frames(20);
      expect(find.text('워크아웃 5개'), findsOneWidget);
      final addition = container
          .read(workoutControllerProvider.notifier)
          .refresh();
      await tester.pump();
      repository.respond(2, catalog);
      await addition;
      await frames(25);
      expect(find.text('워크아웃 6개'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
    debugDisableShadows = previousShadows;
  });
}
