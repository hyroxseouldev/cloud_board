@TestOn('browser')
library;

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const _origin = String.fromEnvironment('WORKOUT_IMAGE_TEST_ORIGIN');
const _capture = bool.fromEnvironment('WORKOUT_IMAGE_TEST_CAPTURE');
const _rect = Rect.fromLTWH(399.11334228515625, 154, 402.765625, 226.5546875);

void main() {
  // The fixture server is deliberately a different origin, so these exercise
  // browser CORS/HTML loading, unlike MemoryImage/widget-only pixel fixtures.
  group(
    'HTTP preview rendering',
    () {
      for (final tone in ['light', 'dark']) {
        testWidgets(
          'CORS $tone PNG uses canvas without dark fractional edges',
          (tester) async {
            final source = '$_origin/cors/exact-$tone.png';
            final key = await _mount(tester, source);
            await _until(tester, () => _rawImage(tester) != null);
            expect(find.byType(HtmlElementView), findsNothing);
            expect(tester.getRect(find.byType(WorkoutSlidePreview)), _rect);
            final rendered = _rawImage(tester)!;
            expect((rendered.width, rendered.height), (1920, 1080));
            expect(
              tester.widget<RawImage>(find.byType(RawImage)).fit,
              BoxFit.contain,
            );
            final raster = await _captureRaster(tester, key, tone);
            final color = tone == 'light' ? [248, 240, 224] : [32, 40, 48];
            for (final point in [
              (399, 200),
              (801, 200),
              (500, 154),
              (500, 380),
            ]) {
              expect(
                raster.getPixel(point.$1, point.$2).toList().take(3),
                color,
                reason:
                    'HTTP image edge $point must not blend with black backing',
              );
            }
            for (final corner in [
              (.03, .03, [255, 0, 0]),
              (.97, .03, [0, 255, 0]),
              (.03, .97, [0, 0, 255]),
              (.97, .97, [255, 255, 0]),
            ]) {
              expect(
                raster
                    .getPixel(
                      (_rect.left + _rect.width * corner.$1).round(),
                      (_rect.top + _rect.height * corner.$2).round(),
                    )
                    .toList()
                    .take(3),
                corner.$3,
              );
            }
            expect(tester.takeException(), isNull);
          },
        );
      }

      testWidgets('CORS-denied PNG decodes into the existing HTML fallback', (
        tester,
      ) async {
        final source = '$_origin/no-cors/exact-light.png';
        await _mount(tester, source);
        await _until(
          tester,
          () => find.byType(HtmlElementView).evaluate().isNotEmpty,
        );
        final info = await _decodedInfo(tester);
        expect(info.sizeBytes, 4 * 1920 * 1080);
        expect(() => info.image, throwsUnsupportedError);
        expect(_rawImage(tester), isNull);
        expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
        final rect = tester.getRect(find.byType(HtmlElementView));
        expect(rect.left, closeTo(_rect.left, .02));
        expect(rect.top, closeTo(_rect.top, .02));
        expect(rect.width, closeTo(_rect.width, .02));
        expect(rect.height, closeTo(_rect.height, .02));
        // This checks compatibility, not resolution of the HTML edge artifact.
        expect(tester.takeException(), isNull);
      });

      testWidgets('rounded CORS preview shares the canvas-first path', (
        tester,
      ) async {
        final source = '$_origin/cors/near-dark.png';
        await _mount(tester, source, radius: 12);
        await _until(tester, () => _rawImage(tester) != null);
        expect(find.byType(HtmlElementView), findsNothing);
        final image = _rawImage(tester)!;
        expect((image.width, image.height), (1672, 941));
        expect(
          tester.widget<RawImage>(find.byType(RawImage)).fit,
          BoxFit.contain,
        );
        expect(tester.getRect(find.byType(WorkoutSlidePreview)), _rect);
        expect(tester.takeException(), isNull);
      });

      testWidgets('missing remote image retains the error UI', (tester) async {
        await _mount(tester, '$_origin/cors/missing.png');
        await _until(
          tester,
          () => find
              .byKey(const ValueKey('workout-image-retry'))
              .evaluate()
              .isNotEmpty,
        );
        expect(
          find.byKey(const ValueKey('workout-image-retry')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    },
    skip: _origin.isEmpty
        ? 'Start test/support/workout_image_http_fixture.py and pass WORKOUT_IMAGE_TEST_ORIGIN'
        : false,
  );
}

ui.Image? _rawImage(WidgetTester tester) =>
    find.byType(RawImage).evaluate().isEmpty
    ? null
    : tester.renderObject<RenderImage>(find.byType(RawImage)).image;

// Widget tests build a platform-view placeholder, not a mounted DOM image.
// Resolve the real HTTP provider to verify HTML decode; actual presentation is
// deliberately left to the coordinator's app E2E.
Future<ImageInfo> _decodedInfo(WidgetTester tester) async {
  final stream = tester
      .widget<Image>(find.byType(Image))
      .image
      .resolve(ImageConfiguration.empty);
  ImageInfo? decoded;
  final listener = ImageStreamListener((value, _) => decoded = value);
  stream.addListener(listener);
  try {
    await _until(tester, () => decoded != null);
  } finally {
    stream.removeListener(listener);
  }
  addTearDown(() => decoded?.dispose());
  return decoded!;
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 100 && !ready(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(
    ready(),
    isTrue,
    reason: 'HTTP image did not reach the expected renderer',
  );
}

Future<GlobalKey> _mount(
  WidgetTester tester,
  String source, {
  double radius = 0,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1201, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final key = GlobalKey();
  final module = WorkoutModule.empty('http-fixture')
      .copyWith(imageSource: source, showTimer: false, showSets: false);
  await tester.pumpWidget(
    MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: Colors.white,
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: _rect,
                child: WorkoutSlidePreview(
                  module: module,
                  isRest: false,
                  borderRadius: radius,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return key;
}

Future<img.Image> _captureRaster(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async => (await tester.runAsync(() async {
  final image =
      await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
          .toImage();
  try {
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    if (_capture) {
      debugPrintSynchronously('HTTP_PREVIEW_PNG:$name:${base64Encode(bytes)}');
    }
    return img.decodePng(bytes)!;
  } finally {
    image.dispose();
  }
}))!;
