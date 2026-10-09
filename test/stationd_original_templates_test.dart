import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_reference_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/original_slide_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_design_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/original_slide_template.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Uint8List> _rgba(ui.Image image) async {
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
}

Future<ui.Image> _paint(
  ui.Image source,
  Size size, [
  WorkoutModule? module,
]) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (module == null) {
    canvas.scale(size.width / source.width);
    canvas.drawImage(
      source,
      Offset.zero,
      Paint()..filterQuality = FilterQuality.medium,
    );
  } else {
    paintOriginalSlide(canvas, size, module, source);
  }
  final picture = recorder.endRecording();
  final result = await picture.toImage(size.width.toInt(), size.height.toInt());
  picture.dispose();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const sourceHashes = [
    '79e7b055b2399d7dd0a6e9447b75cd93d7531962b3c140c9acad68fb97041ae0',
    '46ebcd3dcbb215d0cc71a8ee1154e2592ddd4325f8970be7de7c92c001d418f0',
    'af35dee799a02a6a9bb7f0735a53e455cf138a9741e7b9b90fb6b3728a403f61',
    'c5fc8f7bf3a1d34e67014a40f6425069e138bda5d11e2d39cd7e1ede74d8e8e6',
    '4855cd1027ef5081393c4141351eadc531440f333ed638ce62c0e0be82b89296',
    'a7d96c529829e734a807c6fd9356af08843e377708e37de80cb2a3ddfab8d026',
  ];

  setUpAll(() async {
    await (FontLoader('Pretendard')..addFont(
          rootBundle.load('assets/fonts/pretendard/Pretendard-Bold.otf'),
        ))
        .load();
  });

  for (var index = 0; index < stationDOriginalTemplates.length; index++) {
    final template = stationDOriginalTemplates[index];
    final theme = stationDReferenceDesigns[index].theme;
    final draft = applyAiSlideTheme(initialAiSlideDesignDraft(theme), theme);
    final module = previewAiSlide(draft);

    test(
      '${template.id}: original asset and exported PNG preserve the source',
      () async {
        final asset = await rootBundle.load(template.asset);
        expect(
          sha256.convert(asset.buffer.asUint8List()).toString(),
          sourceHashes[index],
        );
        final source = await loadOriginalSlideImage(template.id);
        expect(
          Size(source.width.toDouble(), source.height.toDouble()),
          const Size(3840, 2160),
        );
        expect(originalSlideValidationError(module), isNull);
        final png = base64Decode(
          (await renderSlideDesign(module)).split(',').last,
        );
        final codec = await ui.instantiateImageCodec(png);
        final actual = (await codec.getNextFrame()).image;
        final expected = await _paint(source, const Size(1920, 1080));
        expect(
          sha256.convert(await _rgba(actual)),
          sha256.convert(await _rgba(expected)),
        );
        File('/tmp/cloudboard-${template.id}-baseline.png')
            .writeAsBytesSync(png);
        actual.dispose();
        expected.dispose();
        codec.dispose();
      },
    );

    test(
      '${template.id}: editing a row and removing the last row preserves all other pixels',
      () async {
        final source = await loadOriginalSlideImage(template.id);
        final edited = module.copyWith(
          text: [
            'Run 300m + Sled Pull 1 Way',
            ...template.lines.skip(1).take(template.lines.length - 2),
          ].join('\n'),
        );
        final actual = await _paint(source, template.sourceSize, edited);
        final expected = await _paint(source, template.sourceSize);
        final pixels = await _rgba(actual), original = await _rgba(expected);
        final allowed = [
          template.exerciseBounds.first,
          template.exerciseBounds.last,
          template.numberBounds.last,
        ];
        var changes = 0, outsideChanges = 0;
        for (var y = 0; y < source.height; y++) {
          for (var x = 0; x < source.width; x++) {
            final offset = (y * source.width + x) * 4;
            if (pixels[offset] == original[offset] &&
                pixels[offset + 1] == original[offset + 1] &&
                pixels[offset + 2] == original[offset + 2] &&
                pixels[offset + 3] == original[offset + 3]) {
              continue;
            }
            changes++;
            if (!allowed.any(
              (rect) => rect.contains(Offset(x.toDouble(), y.toDouble())),
            )) {
              outsideChanges++;
            }
          }
        }
        expect(changes, greaterThan(100));
        expect(
          outsideChanges,
          0,
          reason: 'Header, class mark, time, other rows and numbers must remain original pixels',
        );
        final badge = template.numberBounds.last;
        for (var y = badge.top.toInt(); y < badge.bottom; y++) {
          for (var x = badge.left.toInt(); x < badge.right; x++) {
            final offset = (y * source.width + x) * 4;
            expect(pixels.sublist(offset, offset + 4), [255, 255, 255, 255]);
          }
        }
        expect(measureOriginalSlide(edited).readable, true);
        final png = base64Decode(
          (await renderSlideDesign(edited)).split(',').last,
        );
        File('/tmp/cloudboard-${template.id}-edited.png').writeAsBytesSync(png);
        actual.dispose();
        expected.dispose();
        final overflow = module.copyWith(
          text: '${module.text}\nExtra exercise',
        );
        await expectLater(renderSlideDesign(overflow), throwsFormatException);
        expect(overflow.text, endsWith('Extra exercise'));
      },
    );
  }

  test('explicit generated timing goes into the original timing slot without inventing values', () {
    const draft = AiSlideDraft(
      title: '수업',
      layout: 'list',
      lines: ['Run 200m', 'Ski 300m'],
      workSeconds: 360,
      restSeconds: 90,
    );
    expect(
      originalSlideGeneratedContent(draft).designSubtitle,
      '6mins On / 90s Off',
    );
    final movement = originalSlideGeneratedContent(
      draft.copyWith(lines: ['6mins On / 30s move', ...draft.lines]),
    );
    expect(movement.designSubtitle, '6mins On / 30s move');
    expect(movement.lines, draft.lines);
    expect(
      originalSlideGeneratedContent(
        draft.copyWith(workSeconds: null, restSeconds: null),
      ).designSubtitle,
      isEmpty,
    );
    expect(
      originalSlideGeneratedContent(draft.copyWith(restSeconds: null))
          .designSubtitle,
      '6mins On',
    );
  });
}
