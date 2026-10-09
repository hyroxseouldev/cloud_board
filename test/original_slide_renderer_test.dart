import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/feature/workouts/data/datasources/original_slide_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_design_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/slide_design_style.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/original_slide_template.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutModule baseline() => WorkoutModule.empty('dolpa-original').copyWith(
  name: dolpaBrickOriginalTitle,
  designSubtitle: dolpaBrickOriginalSubtitle,
  text: dolpaBrickOriginalLines.join('\n'),
  designTemplate: 'studio-v1-list',
  designStyle: const SlideDesignStyle(
    family: 'editorial',
    fontFamily: 'serif',
    originalTemplate: dolpaBrickOriginalTemplateId,
  ),
  showTimer: false,
  showSets: false,
);

Future<ui.Image> render(
  WorkoutModule module,
  ui.Image source, {
  Size size = originalSlideSourceSize,
}) async {
  final recorder = ui.PictureRecorder();
  paintOriginalSlide(Canvas(recorder), size, module, source);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  picture.dispose();
  return image;
}

Future<Uint8List> rgba(ui.Image image) async {
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
}

/// Independent baseline: Flutter color-manages the source Display P3 profile
/// into its PNG output. Compare painted pixels in the same color space.
Future<ui.Image> drawSource(ui.Image source, Size size) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
  final target = originalSlideImageRect(size);
  canvas.translate(target.left, target.top);
  canvas.scale(target.width / source.width);
  canvas.drawImage(
    source,
    Offset.zero,
    Paint()..filterQuality = FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  picture.dispose();
  return image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ui.Image source;
  setUpAll(() async {
    await (FontLoader('NotoSerifKR')..addFont(
          rootBundle.load(
            'assets/fonts/noto_serif_kr/NotoSerifKR-Variable.ttf',
          ),
        ))
        .load();
    source = await loadOriginalSlideImage(dolpaBrickOriginalTemplateId);
  });

  test('bundled source is the unmodified user PNG', () async {
    final bytes = await rootBundle.load(dolpaBrickOriginalAsset);
    expect(
      sha256.convert(bytes.buffer.asUint8List()).toString(),
      'ce7c27c594298b1886f0a5de7f645232118ff22bed99b0fa1d1f8c97c6685a83',
    );
    expect(source.width, 2316);
    expect(source.height, 1262);
  });

  test(
    'baseline PNG has exact source pixels including every calligraphy stroke',
    () async {
      final painted = await render(baseline(), source);
      final png = (await painted.toByteData(format: ui.ImageByteFormat.png))!;
      final codec = await ui.instantiateImageCodec(png.buffer.asUint8List());
      final exported = (await codec.getNextFrame()).image;
      final reference = await drawSource(source, originalSlideSourceSize);
      expect(
        sha256.convert(await rgba(exported)),
        sha256.convert(await rgba(reference)),
      );
      File('/tmp/cloudboard-dolpa-original-baseline.png')
          .writeAsBytesSync(png.buffer.asUint8List());
      exported.dispose();
      reference.dispose();
      codec.dispose();
      painted.dispose();
    },
  );

  test(
    '1920x1080 baseline preserves aspect and matches direct contain painting',
    () async {
      final actual = await render(
        baseline(),
        source,
        size: originalSlideOutputSize,
      );
      final target = originalSlideImageRect(originalSlideOutputSize);
      expect(target.width / target.height, closeTo(2316 / 1262, 1e-10));
      expect(target.left, closeTo(0, 1e-10));
      expect(target.top, greaterThan(0));
      final expected = await drawSource(source, originalSlideOutputSize);
      expect(
        sha256.convert(await rgba(actual)),
        sha256.convert(await rgba(expected)),
      );
      final png = (await actual.toByteData(format: ui.ImageByteFormat.png))!;
      File('/tmp/cloudboard-dolpa-original-1920.png')
          .writeAsBytesSync(png.buffer.asUint8List());
      expected.dispose();
      actual.dispose();
    },
  );

  test('one edited row leaves every pixel outside that text slot untouched', () async {
    final module = baseline().copyWith(
      text: [
        'Ski 300m + Sled Pull 1 Way',
        ...dolpaBrickOriginalLines.skip(1),
      ].join('\n'),
    );
    final painted = await render(module, source);
    final reference = await drawSource(source, originalSlideSourceSize);
    final original = await rgba(reference), actual = await rgba(painted);
    final allowed = originalSlideExerciseBounds.first;
    var insideChanges = 0, outsideChanges = 0;
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final i = (y * source.width + x) * 4;
        if (original[i] == actual[i] &&
            original[i + 1] == actual[i + 1] &&
            original[i + 2] == actual[i + 2] &&
            original[i + 3] == actual[i + 3]) {
          continue;
        }
        if (allowed.contains(Offset(x.toDouble(), y.toDouble()))) {
          insideChanges++;
        } else {
          outsideChanges++;
        }
      }
    }
    expect(insideChanges, greaterThan(100));
    expect(
      outsideChanges,
      0,
      reason:
          'Original title, timing, three rows and all graphics must stay exact',
    );
    painted.dispose();
    reference.dispose();
  });

  test(
    'title is fixed and an invalid edited draft preserves the exact original',
    () async {
      final module = baseline().copyWith(name: 'Run');
      expect(originalSlideValidationError(module), contains('Brick Session'));
      expect(measureOriginalSlide(module).readable, false);
      await expectLater(renderSlideDesign(module), throwsFormatException);
      final painted = await render(module, source);
      final reference = await drawSource(source, originalSlideSourceSize);
      expect(
        sha256.convert(await rgba(painted)),
        sha256.convert(await rgba(reference)),
      );
      final png = (await painted.toByteData(format: ui.ImageByteFormat.png))!;
      File('/tmp/cloudboard-dolpa-original-edited-title.png')
          .writeAsBytesSync(png.buffer.asUint8List());
      painted.dispose();
      reference.dispose();
    },
  );

  test('fixed recipe rejects overflow and timer overlays instead of dropping content', () async {
    final overflow = baseline().copyWith(text: '${baseline().text}\nRun 1km');
    expect(originalSlideValidationError(overflow), contains('4줄'));
    expect(measureOriginalSlide(overflow).readable, false);
    await expectLater(renderSlideDesign(overflow), throwsFormatException);
    // Partial editing still previews safely; applying/exporting remains blocked.
    final draft = await render(overflow, source);
    draft.dispose();
    final untitled = await render(baseline().copyWith(name: ''), source);
    untitled.dispose();
    expect(overflow.text, endsWith('Run 1km'));
    expect(
      originalSlideValidationError(baseline().copyWith(showTimer: true)),
      contains('타이머'),
    );
    expect(
      originalSlideValidationError(baseline().copyWith(showSets: true)),
      contains('세트'),
    );
    expect(
      originalSlideValidationError(
        baseline().copyWith(text: '## Main\nRun 1km'),
      ),
      contains('섹션'),
    );
    expect(
      measureOriginalSlide(baseline().copyWith(text: '매우긴운동설명' * 18)).readable,
      false,
    );
    expect(measureOriginalSlide(baseline()).readable, true);
    expect(measureOriginalSlide(baseline()).textRuns.map((r) => r.value), [
      dolpaBrickOriginalTitle,
      dolpaBrickOriginalSubtitle,
      ...dolpaBrickOriginalLines,
    ]);
  });
}
