import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const _origin = Offset(30.3, 30.3);
const _evidence = String.fromEnvironment('STA194_EVIDENCE');

void main() {
  // Fractional bounds expose the black backing bleeding through an AA clip.
  // DPR 1.25/2.5 exercise the raster scale of 125% at base DPR 1/2;
  // they do not claim to drive a browser's zoom control or run the app E2E.
  for (final width in [707.3, 311.3]) {
    for (final dpr in [1.0, 1.25, 2.0, 2.5]) {
      for (final near in [false, true]) {
        for (final color in [
          const Color(0xfff8f0e0),
          const Color(0xff202830),
        ]) {
          final label =
              '${near ? 'near' : 'exact'}-'
              '${color.r > .5 ? 'light' : 'dark'}-${width.toInt()}-$dpr';
          testWidgets('square preview has no dark seam: $label', (
            tester,
          ) async {
            final key = await _mount(tester, width, dpr, _fixture(near, color));
            final image = tester.widget<Image>(find.byType(Image));
            expect(image.fit, BoxFit.contain);
            final rect = tester.getRect(find.byType(WorkoutSlidePreview));
            expect(
              rect,
              Rect.fromLTWH(_origin.dx, _origin.dy, width, width * 9 / 16),
            );
            final raster = await _raster(tester, key, dpr, label);
            final left = (rect.left * dpr).round();
            final right = (rect.right * dpr).round() - 1;
            final top = (rect.top * dpr).round();
            final bottom = (rect.bottom * dpr).round() - 1;
            for (final point in [
              (left, (top + bottom) ~/ 2),
              (right, (top + bottom) ~/ 2),
              ((left + right) ~/ 2, top),
              ((left + right) ~/ 2, bottom),
            ]) {
              expect(
                raster.getPixel(point.$1, point.$2).toList().take(3),
                [
                  (color.r * 255).round(),
                  (color.g * 255).round(),
                  (color.b * 255).round(),
                ],
                reason:
                    'image edge $point must not blend with the black backing',
              );
            }
            // All four corner markers remain visible in their original order.
            for (final corner in [
              (.03, .03, [255, 0, 0]),
              (.97, .03, [0, 255, 0]),
              (.03, .97, [0, 0, 255]),
              (.97, .97, [255, 255, 0]),
            ]) {
              final x = ((rect.left + rect.width * corner.$1) * dpr).round();
              final y = ((rect.top + rect.height * corner.$2) * dpr).round();
              expect(raster.getPixel(x, y).toList().take(3), corner.$3);
            }
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }

  testWidgets(
    'rounded previews keep clipped corners and empty slides stay black',
    (tester) async {
      final key = await _mount(
        tester,
        311.3,
        1,
        _fixture(false, Colors.white),
        radius: 12,
      );
      final raster = await _raster(tester, key, 1, 'rounded');
      expect(raster.getPixel(31, 31).toList().take(3), [255, 255, 255]);
      expect(raster.getPixel(45, 45).toList().take(3), [255, 0, 0]);
      final emptyKey = await _mount(tester, 311.3, 1, '');
      final empty = await _raster(tester, emptyKey, 1, 'empty');
      expect(empty.getPixel(180, 110).toList().take(3), [0, 0, 0]);
    },
  );
}

String _fixture(bool near, Color color) {
  final image = img.Image(width: near ? 1672 : 1920, height: near ? 941 : 1080);
  img.fill(
    image,
    color: img.ColorRgb8(
      (color.r * 255).round(),
      (color.g * 255).round(),
      (color.b * 255).round(),
    ),
  );
  final size = (image.height * .1).round();
  for (final corner in [
    (0, 0, img.ColorRgb8(255, 0, 0)),
    (image.width - size, 0, img.ColorRgb8(0, 255, 0)),
    (0, image.height - size, img.ColorRgb8(0, 0, 255)),
    (image.width - size, image.height - size, img.ColorRgb8(255, 255, 0)),
  ]) {
    img.fillRect(
      image,
      x1: corner.$1,
      y1: corner.$2,
      x2: corner.$1 + size - 1,
      y2: corner.$2 + size - 1,
      color: corner.$3,
    );
  }
  return 'data:image/png;base64,${base64Encode(img.encodePng(image))}';
}

Future<GlobalKey> _mount(
  WidgetTester tester,
  double width,
  double dpr,
  String source, {
  double radius = 0,
}) async {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(800 * dpr, 500 * dpr);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final key = GlobalKey();
  final module = WorkoutModule.empty('edge-fixture')
      .copyWith(imageSource: source, showTimer: false, showSets: false);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RepaintBoundary(
          key: key,
          child: SizedBox.expand(
            child: ColoredBox(
              color: Colors.white,
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: _origin.dx, top: _origin.dy),
                  child: SizedBox(
                    width: width,
                    height: width * 9 / 16,
                    child: WorkoutSlidePreview(
                      module: module,
                      isRest: false,
                      borderRadius: radius,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  if (source.isNotEmpty) {
    if (kIsWeb) {
      // Web decoding needs frames while loading; awaiting precacheImage alone
      // stalls the widget test's fake clock. Bound the wait to expose failures.
      for (var attempt = 0; attempt < 50; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
        if (find.byType(RawImage).evaluate().isNotEmpty &&
            tester.renderObject<RenderImage>(find.byType(RawImage)).image !=
                null) {
          break;
        }
      }
      expect(
        tester.renderObject<RenderImage>(find.byType(RawImage)).image,
        isNotNull,
      );
    } else {
      final provider = tester
          .widget<Image>(
            find.descendant(
              of: find.byType(WorkoutImage),
              matching: find.byType(Image),
            ),
          )
          .image;
      await tester.runAsync(() => precacheImage(provider, key.currentContext!));
    }
  }
  await tester.pumpAndSettle();
  return key;
}

Future<img.Image> _raster(
  WidgetTester tester,
  GlobalKey key,
  double dpr,
  String label,
) async => (await tester.runAsync(() async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: dpr);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = data!.buffer.asUint8List();
    if (_evidence.isNotEmpty && !kIsWeb) {
      final file = File('$_evidence/$label.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
    }
    return img.decodePng(bytes)!;
  } finally {
    image.dispose();
  }
}))!;
