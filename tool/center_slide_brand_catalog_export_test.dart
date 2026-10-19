import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'center_slide_export_fonts.dart';

import 'package:cloud_board/src/app/feature/ai_slides/data/models/center_slide_catalog_model.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/renderers/center_slide_renderer.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_reference_design.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/original_slide_template.dart';

/// Explicit, local-only operator export. This file never initializes Firebase.
///
/// CENTER_BRAND_EXPORT=1 CENTER_BRAND_INPUT=/tmp/sta193-sweatmonday-catalog.json
/// CENTER_BRAND_SWEAT_IMAGE=/absolute/path/to/source.png
/// CENTER_BRAND_OUTPUT=/tmp/sta193-brand-export
/// flutter test tool/center_slide_brand_catalog_export_test.dart
///
/// Run after recipe-v2 code generation. All eight backgrounds and samples are
/// validated/rendered before output is written; review previews before publishing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final env = Platform.environment;
  test(
    'export eight brand backgrounds and the matching server catalog',
    () async {
      final inputPath = _required(env, 'CENTER_BRAND_INPUT');
      final sweatPath = _required(env, 'CENTER_BRAND_SWEAT_IMAGE');
      final outputPath = _required(env, 'CENTER_BRAND_OUTPUT');
      final output = Directory(outputPath).absolute;
      if (!output.isAbsolute ||
          output.path == Directory.current.path ||
          output.path.startsWith('${Directory.current.path}/assets/')) {
        throw StateError(
          'Choose a separate export directory, never source assets.',
        );
      }
      final input = Map<String, dynamic>.from(
        jsonDecode(await File(inputPath).readAsString()) as Map,
      );
      final previous = <String, Map<String, dynamic>>{
        for (final value in input['templates'] as List)
          (value as Map)['id'] as String: Map<String, dynamic>.from(value),
      };
      const sweatId = 'sweatmonday-team-of-3-v1';
      final sweatEntry = previous[sweatId];
      if (sweatEntry == null ||
          sweatEntry['recipe'] is! Map ||
          sweatEntry['sample'] is! Map) {
        throw const FormatException(
          'The current SWEATMONDAY recipe and explicit sample are required.',
        );
      }
      final centerId = (sweatEntry['recipe'] as Map)['centerId'] as String;
      if (!RegExp(r'^[A-Za-z0-9_-]{1,120}$').hasMatch(centerId)) {
        throw const FormatException('Invalid existing center identifier.');
      }
      await loadCenterSlideExportFonts();
      final sourcePaths = <String>[
        for (final original in originalSlideTemplates) original.asset,
        sweatPath,
      ];
      final originalDigests = <String, String>{
        for (final path in sourcePaths)
          path: sha256.convert(await File(path).readAsBytes()).toString(),
      };
      final backgrounds = <String, Uint8List>{};
      final entries = <Map<String, dynamic>>[];
      final defaults = WorkoutModule.empty('brand-export-defaults');

      for (final (index, design) in customerReferenceDesigns.indexed) {
        final original = originalSlideTemplate(
          design.theme.designStyle!.originalTemplate,
        )!;
        final isDolpa = original.id == dolpaBrickOriginalTemplateId;
        final source = await _readImage(original.asset);
        late Uint8List background;
        try {
          if (source.width != original.sourceSize.width.toInt() ||
              source.height != original.sourceSize.height.toInt()) {
            throw FormatException('Source dimensions changed: ${design.id}');
          }
          background = await (isDolpa
              ? _dolpaBackground(source)
              : _stationBackground(source, original));
        } finally {
          source.dispose();
        }
        backgrounds[design.id] = background;
        final prior = previous[design.id];
        final sample = prior?['sample'] is Map
            ? Map<String, dynamic>.from(prior!['sample'] as Map)
            : <String, dynamic>{
                'title': original.title,
                'subtitle': original.subtitle,
                'headerLabel': original.programLabel,
                'lines': original.lines,
              };
        sample.putIfAbsent('workSeconds', () => defaults.workSeconds);
        sample.putIfAbsent('restSeconds', () => defaults.restSeconds);
        sample.putIfAbsent('sets', () => defaults.sets);
        final digest = sha256.convert(background).toString();
        final recipe = _recipe(
          centerId: centerId,
          id: design.id,
          revision: 1,
          digest: digest,
          backgroundColor: original.backgroundColor,
          fields: isDolpa ? _dolpaFields() : _stationFields(original),
          body: isDolpa
              ? _body(
                  const Rect.fromLTWH(80, 350, 1760, 650),
                  fontSize: 54,
                  color: 0xffffffff,
                  headingColor: 0xffea3458,
                  fontFamily: 'NotoSerifKR',
                  weight: 400,
                )
              : _body(
                  const Rect.fromLTWH(84, 325, 1752, 675),
                  fontSize: 56,
                  color: 0xff000000,
                  headingColor: original.accentColor,
                ),
        );
        entries.add({
          'id': design.id,
          'name': (prior?['name'] as String? ?? design.name).replaceAll(
            ' 원본',
            '',
          ),
          'description': '브랜드 색감 · 내용에 맞춰 자동 배치',
          'sortOrder': prior?['sortOrder'] ?? index,
          'published': prior?['published'] ?? true,
          'recipe': recipe,
          'sample': sample,
        });
      }

      final sweatImage = await _readImage(sweatPath);
      late Uint8List sweatBackground;
      try {
        if (sweatImage.width != 1672 || sweatImage.height != 941) {
          throw const FormatException(
            'Expected the reviewed 1672×941 SWEATMONDAY source.',
          );
        }
        sweatBackground = await _sweatBackground(sweatImage);
      } finally {
        sweatImage.dispose();
      }
      backgrounds[sweatId] = sweatBackground;
      final sweatSample = Map<String, dynamic>.from(
        sweatEntry['sample'] as Map,
      );
      final sourceLines = List<String>.from(sweatSample['lines'] as List);
      if (sourceLines.length != 18) {
        throw const FormatException(
          'Expected the original eighteen SWEATMONDAY text lines.',
        );
      }
      sweatSample['lines'] = [
        for (var section = 0; section < 3; section++) ...[
          '## ${String.fromCharCode(65 + section)}',
          ...sourceLines.skip(section * 6).take(6),
        ],
      ];
      // Preserve the original explicit timer contract (300 / 100 / 2).
      for (final entry in {
        'workSeconds': 300,
        'restSeconds': 100,
        'sets': 2,
      }.entries) {
        if (sweatSample[entry.key] != entry.value) {
          throw FormatException('Unexpected SWEATMONDAY timing: ${entry.key}');
        }
      }
      entries.add({
        'id': sweatId,
        'name': sweatEntry['name'],
        'description': '로고와 크림색 배경 · 내용에 맞춰 자동 배치',
        'sortOrder': sweatEntry['sortOrder'] ?? -1,
        'published': sweatEntry['published'] ?? true,
        'recipe': _recipe(
          centerId: centerId,
          id: sweatId,
          revision: 2,
          digest: sha256.convert(sweatBackground).toString(),
          backgroundColor: 0xfff6f0e5,
          fields: [
            _field(
              'title',
              const Rect.fromLTWH(72, 225, 1768, 100),
              fontSize: 84,
              color: 0xff080706,
              weight: 800,
              italic: true,
            ),
            _field(
              'subtitle',
              const Rect.fromLTWH(72, 340, 1768, 70),
              fontSize: 48,
              color: 0xffdb4b00,
              weight: 700,
            ),
            _field(
              'header',
              const Rect.fromLTWH(650, 75, 1190, 80),
              fontSize: 46,
              color: 0xffdb4b00,
              weight: 700,
              align: 'right',
            ),
          ],
          body: _body(
            const Rect.fromLTWH(72, 455, 1768, 575),
            fontSize: 56,
            color: 0xff17130f,
            headingColor: 0xffdb4b00,
          ),
        ),
        'sample': sweatSample,
      });

      final model = CenterSlideCatalogModel.fromJson(
        {
          'schemaVersion': 1,
          'revision': 3,
          'centerName': input['centerName'] ?? '',
          'templates': entries,
        },
        centerId: centerId,
        rejectInvalidItems: true,
      );
      final expectedIds = {
        ...customerReferenceDesigns.map((design) => design.id),
        sweatId,
      };
      expect(model.entries.map((entry) => entry.id).toSet(), expectedIds);
      expect(model.entries, hasLength(8));
      final previews = <String, Uint8List>{};
      final wodPath = env['CENTER_BRAND_PREVIEW_WOD'];
      final exampleLines = wodPath == null
          ? null
          : (await File(
              wodPath,
            ).readAsString()).replaceAll('\r\n', '\n').split('\n');
      for (final design in model.toEntity().templates) {
        previews[design.id] = await renderCenterSlide(
          design.theme.centerRecipe!,
          design.sample!,
          backgroundBytes: backgrounds[design.id],
        );
        if (exampleLines != null) {
          previews['${design.id}-wod'] = await renderCenterSlide(
            design.theme.centerRecipe!,
            design.sample!.copyWith(
              title: 'RUN + STRENGTH',
              designSubtitle: '',
              lines: exampleLines,
            ),
            backgroundBytes: backgrounds[design.id],
          );
        }
      }
      for (final path in sourcePaths) {
        expect(
          sha256.convert(await File(path).readAsBytes()).toString(),
          originalDigests[path],
          reason: 'Source artwork must remain unchanged: $path',
        );
      }
      await Directory('${output.path}/backgrounds').create(recursive: true);
      await Directory('${output.path}/previews').create(recursive: true);
      final imagePaths = <String, String>{};
      for (final entry in backgrounds.entries) {
        final file = File('${output.path}/backgrounds/${entry.key}.png');
        await file.writeAsBytes(entry.value, flush: true);
        imagePaths[entry.key] = file.absolute.path;
      }
      for (final entry in previews.entries) {
        await File('${output.path}/previews/${entry.key}.png')
            .writeAsBytes(entry.value, flush: true);
      }
      const encoder = JsonEncoder.withIndent('  ');
      await File('${output.path}/catalog.json')
          .writeAsString('${encoder.convert(model.toJson())}\n', flush: true);
      await File('${output.path}/images.json')
          .writeAsString('${encoder.convert(imagePaths)}\n', flush: true);
      await File('${output.path}/source-digests.json')
          .writeAsString('${encoder.convert(originalDigests)}\n', flush: true);
      // No network, Firebase calls, source edits, or publication occur here.
    },
    skip: env['CENTER_BRAND_EXPORT'] != '1',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

String _required(Map<String, String> env, String name) {
  final value = env[name];
  if (value == null || value.isEmpty) throw StateError('$name is required.');
  return value;
}

Map<String, dynamic> _recipe({
  required String centerId,
  required String id,
  required int revision,
  required String digest,
  required int backgroundColor,
  required List<Map<String, dynamic>> fields,
  required Map<String, dynamic> body,
}) => {
  'schemaVersion': 2,
  'templateId': id,
  'revision': revision,
  'centerId': centerId,
  'width': 1920,
  'height': 1080,
  'backgroundColor': backgroundColor,
  'backgroundPath': 'center-templates/$centerId/$id/$digest.png',
  'backgroundSha256': digest,
  'fields': fields,
  'body': body,
};

Map<String, dynamic> _field(
  String binding,
  Rect bounds, {
  required double fontSize,
  required int color,
  String fontFamily = 'Pretendard',
  int weight = 700,
  bool italic = false,
  String align = 'left',
  String? originalText,
  int? clearColor,
}) => {
  'binding': binding,
  'x': bounds.left / 1920,
  'y': bounds.top / 1080,
  'width': bounds.width / 1920,
  'height': bounds.height / 1080,
  'fontSize': fontSize,
  'color': color,
  'fontFamily': fontFamily,
  'fontWeight': weight,
  'italic': italic,
  'align': align,
  'originalText': ?originalText,
  'clearColor': ?clearColor,
};

Map<String, dynamic> _body(
  Rect bounds, {
  required double fontSize,
  required int color,
  required int headingColor,
  String fontFamily = 'Pretendard',
  int weight = 600,
}) => {
  'x': bounds.left / 1920,
  'y': bounds.top / 1080,
  'width': bounds.width / 1920,
  'height': bounds.height / 1080,
  'fontSize': fontSize,
  'color': color,
  'headingColor': headingColor,
  'fontFamily': fontFamily,
  'fontWeight': weight,
  'layout': 'auto',
  'maxColumns': 3,
};

List<Map<String, dynamic>> _stationFields(OriginalSlideTemplate original) => [
  _field(
    'title',
    const Rect.fromLTWH(72, 25, 1150, 112),
    fontSize: 80,
    color: 0xffffffff,
    fontFamily: 'RacingSansOne',
    weight: 400,
  ),
  _field(
    'subtitle',
    const Rect.fromLTWH(84, 195, 1752, 90),
    fontSize: 60,
    color: original.accentColor,
    weight: 800,
  ),
  _field(
    'header',
    const Rect.fromLTWH(1300, 25, 560, 112),
    fontSize: 60,
    color: 0xffffffff,
    fontFamily: 'RacingSansOne',
    weight: 400,
    align: 'right',
    originalText: original.programLabel,
    clearColor: original.accentColor,
  ),
];

List<Map<String, dynamic>> _dolpaFields() => [
  _field(
    'title',
    const Rect.fromLTWH(80, 40, 1320, 112),
    fontSize: 84,
    color: 0xffea3458,
    fontFamily: 'NotoSerifKR',
    weight: 700,
  ),
  _field(
    'subtitle',
    const Rect.fromLTWH(80, 180, 1320, 70),
    fontSize: 50,
    color: 0xffffffff,
    fontFamily: 'NotoSerifKR',
    weight: 400,
  ),
  _field(
    'header',
    const Rect.fromLTWH(80, 280, 1760, 42),
    fontSize: 32,
    color: 0xffea3458,
    weight: 600,
  ),
];

Future<ui.Image> _readImage(String path) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  try {
    if (codec.frameCount != 1) {
      throw FormatException('Still PNG required: $path');
    }
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

Future<Uint8List> _stationBackground(
  ui.Image source,
  OriginalSlideTemplate original,
) => _paintPng((canvas) {
  canvas.drawColor(const Color(0xffffffff), BlendMode.src);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 1920, 156),
    Paint()..color = Color(original.accentColor),
  );
  // Crop only the original right-hand program identity. Neither the old
  // editable title nor any body text/number badges enters the new background.
  canvas.drawImageRect(
    source,
    const Rect.fromLTWH(2600, 0, 1240, 312),
    const Rect.fromLTWH(1300, 0, 620, 156),
    Paint()..filterQuality = FilterQuality.high,
  );
});

Future<Uint8List> _dolpaBackground(ui.Image source) => _paintPng((canvas) {
  canvas.drawColor(const Color(0xff000000), BlendMode.src);
  // This reviewed source region contains only the large dark-red calligraphy,
  // entirely to the right of the original Brick Session / workout text.
  _drawContained(
    canvas,
    source,
    const Rect.fromLTWH(1135, 100, 1170, 1050),
    const Rect.fromLTWH(1480, 16, 360, 240),
  );
  canvas.drawRect(
    const Rect.fromLTWH(80, 263, 1760, 3),
    Paint()..color = const Color(0xffea3458),
  );
});

Future<Uint8List> _sweatBackground(ui.Image source) => _paintPng((canvas) {
  // The source's unused right side supplies the cream texture without any
  // exercises, headings or rep counts. Preserve the actual logo as a crop.
  canvas.drawImageRect(
    source,
    const Rect.fromLTWH(950, 0, 722, 941),
    const Rect.fromLTWH(0, 0, 1920, 1080),
    Paint()..filterQuality = FilterQuality.high,
  );
  canvas.drawImageRect(
    source,
    const Rect.fromLTWH(45, 45, 410, 145),
    const Rect.fromLTWH(68, 40, 451, 159.5),
    Paint()..filterQuality = FilterQuality.high,
  );
});

void _drawContained(
  Canvas canvas,
  ui.Image image,
  Rect source,
  Rect destination,
) {
  final fitted = applyBoxFit(BoxFit.contain, source.size, destination.size);
  final target = Alignment.center.inscribe(fitted.destination, destination);
  canvas.drawImageRect(
    image,
    source,
    target,
    Paint()..filterQuality = FilterQuality.high,
  );
}

Future<Uint8List> _paintPng(void Function(Canvas) draw) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(1920, 1080);
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw StateError('PNG export failed.');
      return Uint8List.fromList(
        png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}
