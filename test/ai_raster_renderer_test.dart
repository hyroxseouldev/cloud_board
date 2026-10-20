import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/renderers/ai_raster_renderer.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_raster.dart';

import 'support/ai_raster_fakes.dart';

Future<Uint8List> solidPng(int width, int height, Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Pretendard')
          ..addFont(
            rootBundle.load('assets/fonts/pretendard/Pretendard-SemiBold.otf'),
          )
          ..addFont(
            rootBundle.load('assets/fonts/pretendard/Pretendard-Bold.otf'),
          ))
        .load();
  });
  test(
    'fixed real-font layout reports overflow rather than shrinking/clipping',
    () {
      expect(rasterLayoutError(rasterTestDraft, rasterTestBrand), isNull);
      final oversized = rasterTestDraft.copyWith(
        rawWod: List.filled(60, '스쿼트 22.5 kg × 12').join('\n'),
        groups: [
          AiRasterGroup(
            heading: 'A',
            lines: List.filled(60, '스쿼트 22.5 kg × 12'),
          ),
        ],
      );
      expect(
        rasterLayoutError(oversized, rasterTestBrand),
        contains('내용이 넘쳐요'),
      );
      expect(oversized.bodyFontSize, 42);
      expect(
        rasterLayoutError(
          rasterTestDraft.copyWith(bodyFontSize: 32),
          rasterTestBrand,
        ),
        isNull,
      );
    },
  );
  test('final 16:9 PNG preserves artwork area, clears timer and composites source-logo pixels', () async {
    final artwork = await solidPng(1536, 864, const Color(0xff1976d2));
    final logo = await solidPng(1672, 941, const Color(0xffd32f2f));
    final png = await composeRasterSlide(
      rasterTestDraft,
      rasterTestBrand,
      artwork,
      logo,
    );
    final image = await decodeRasterImage(png);
    try {
      expect(image.width, 1920);
      expect(image.height, 1080);
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      List<int> colorAt(int x, int y) => [
        for (var i = 0; i < 4; i++)
          pixels.getUint8((y * image.width + x) * 4 + i),
      ];
      expect(colorAt(800, 1020), [
        25,
        118,
        210,
        255,
      ], reason: 'Artwork is visible, not covered by an opaque generic board');
      expect(colorAt(1600, 500), [
        255,
        248,
        238,
        255,
      ], reason: 'Timer area has no generated clock or numbers');
      expect(colorAt(200, 100), [
        211,
        47,
        47,
        255,
      ], reason: 'Exact source crop pixels replace any model-drawn brand');
    } finally {
      image.dispose();
    }
  });
}
