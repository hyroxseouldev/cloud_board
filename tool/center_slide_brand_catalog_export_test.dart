import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/models/center_slide_catalog_model.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/renderers/center_slide_renderer.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_reference_design.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/original_slide_template.dart';

import 'center_slide_export_fonts.dart';

/// Local-only: never initializes Firebase or publishes a catalog.
/// CENTER_BRAND_EXPORT=1 CENTER_BRAND_INPUT=`<existing SWEAT catalog.json>`
/// CENTER_BRAND_SWEAT_IMAGE=`<approved 1672x941 PNG>`
/// CENTER_BRAND_LOGO_IMAGE=`<latest 1672x941 waiting-screen PNG>`
/// CENTER_BRAND_OUTPUT=`<new output directory>` flutter test --no-pub `<this file>`
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final env = Platform.environment;
  test(
    'export exact source layouts with private thumbnails',
    () async {
      final input = Map<String, dynamic>.from(
        jsonDecode(
          await File(_required(env, 'CENTER_BRAND_INPUT')).readAsString(),
        ) as Map,
      );
      final sweatPath = _required(env, 'CENTER_BRAND_SWEAT_IMAGE');
      final logoPath = _required(env, 'CENTER_BRAND_LOGO_IMAGE');
      final output = Directory(_required(env, 'CENTER_BRAND_OUTPUT')).absolute;
      if (await output.exists() || output.path.contains('/assets/')) {
        throw StateError(
          'Choose a new artifact directory, never source assets.',
        );
      }
      final previous = <String, Map<String, dynamic>>{
        for (final entry in input['templates'] as List)
          (entry as Map)['id'] as String: Map<String, dynamic>.from(entry),
      };
      const sweatId = 'sweatmonday-team-of-3-v1';
      final sweat = previous[sweatId]!;
      final centerId = (sweat['recipe'] as Map)['centerId'] as String;
      final revision = (input['revision'] as int) + 1;
      await loadCenterSlideExportFonts();
      final sources = <String, String>{
        for (final design in customerReferenceDesigns)
          design.id: originalSlideTemplate(
            design.theme.designStyle!.originalTemplate,
          )!.asset,
        sweatId: sweatPath,
        'latest-logo': logoPath,
      };
      final sourceDigests = <String, String>{
        for (final entry in sources.entries)
          entry.key: sha256
              .convert(await File(entry.value).readAsBytes())
              .toString(),
      };
      final entries = <Map<String, dynamic>>[];
      final backgrounds = <String, Uint8List>{};
      for (final (index, design) in customerReferenceDesigns.indexed) {
        final original = originalSlideTemplate(
          design.theme.designStyle!.originalTemplate,
        )!;
        final image = await _read(original.asset);
        final target = originalSlideImageRect(
          const Size(1920, 1080),
          sourceSize: original.sourceSize,
        );
        final scale = target.width / original.sourceSize.width;
        Rect scaled(Rect rect) => Rect.fromLTWH(
          target.left + rect.left * scale,
          target.top + rect.top * scale,
          rect.width * scale,
          rect.height * scale,
        );
        try {
          backgrounds[design.id] = await _png((canvas) {
            canvas.drawColor(Color(original.backgroundColor), BlendMode.src);
            canvas.drawImageRect(
              image,
              Offset.zero & original.sourceSize,
              target,
              Paint(),
            );
          });
        } finally {
          image.dispose();
        }
        final fields = <Map<String, dynamic>>[
          // Brick's title intersects its calligraphy in the approved flattened
          // source. Keep those exact pixels; the lesson title remains metadata.
          if (!original.fixedTitle)
            _field(
              'title',
              scaled(original.titleBounds),
              original.titleFontSize * scale,
              original.title,
              color: 0xffffffff,
              font: 'RacingSansOne',
              weight: 400,
              clear: original.accentColor,
            ),
          _field(
            'subtitle',
            scaled(original.subtitleBounds),
            original.subtitleFontSize * scale,
            original.subtitle,
            color: original.fixedTitle
                ? original.textColor
                : original.accentColor,
            font: original.fontFamily,
            weight: original.fixedTitle ? 400 : 800,
            clear: original.backgroundColor,
          ),
          for (var i = 0; i < original.maxLines; i++)
            _field(
              'line',
              scaled(original.exerciseBounds[i]),
              original.bodyFontSize * scale,
              original.lines[i],
              line: i,
              color: original.textColor,
              font: original.fontFamily,
              weight: original.bodyWeight,
              clear: original.backgroundColor,
            ),
        ];
        entries.add(
          _entry(
            previous[design.id],
            design.id,
            design.name,
            centerId,
            index,
            revision,
            backgrounds[design.id]!,
            original.backgroundColor,
            fields,
            {
              'title': original.title,
              'subtitle': original.subtitle,
              'headerLabel': original.programLabel,
              'lines': original.lines,
            },
          ),
        );
      }
      final source = await _read(sweatPath);
      final logo = await _read(logoPath);
      try {
        if (source.width != 1672 ||
            source.height != 941 ||
            logo.width != 1672 ||
            logo.height != 941) {
          throw const FormatException(
            'Reviewed SWEAT source and latest logo use must both be 1672x941.',
          );
        }
        backgrounds[sweatId] = await _png((canvas) {
          canvas.scale(1920 / 1672, 1080 / 941);
          canvas.drawImage(source, Offset.zero, Paint());
          // Cover only the old mark using the original blank cream texture.
          canvas.drawImageRect(
            source,
            const Rect.fromLTWH(1100, 0, 500, 215),
            const Rect.fromLTWH(0, 0, 500, 215),
            Paint(),
          );
          // Exact horizontal symbol + wordmark + EST.2026; excludes the message.
          canvas.drawImageRect(
            logo,
            const Rect.fromLTWH(535, 300, 615, 265),
            const Rect.fromLTWH(60, 34, 410, 176.67),
            Paint()..filterQuality = FilterQuality.high,
          );
        });
      } finally {
        source.dispose();
        logo.dispose();
      }
      final sample = Map<String, dynamic>.from(sweat['sample'] as Map);
      final lines = List<String>.from(sample['lines'] as List);
      if (lines.length != 18) {
        throw const FormatException(
          'Use the original eighteen-line SWEAT sample.',
        );
      }
      Rect sweatBounds(double x, double y, double w, double h) => Rect.fromLTWH(
        x * 1920 / 1672,
        y * 1080 / 941,
        w * 1920 / 1672,
        h * 1080 / 941,
      );
      final fields = <Map<String, dynamic>>[
        _field(
          'title',
          sweatBounds(58, 220, 840, 78),
          66 * 1920 / 1672,
          sample['title'] as String,
          weight: 800,
          italic: true,
          clear: 0xfff6f0e5,
        ),
        _field(
          'subtitle',
          sweatBounds(60, 302, 850, 48),
          32 * 1920 / 1672,
          sample['subtitle'] as String,
          color: 0xffdb4b00,
          weight: 700,
          clear: 0xfff6f0e5,
        ),
        for (var column = 0; column < 3; column++)
          for (var row = 0; row < 6; row++)
            _field(
              'line',
              sweatBounds(
                [60.0, 315.0, 590.0][column],
                462 + (row ~/ 2) * 102 + (row.isOdd ? 44 : 0),
                [235.0, 255.0, 345.0][column],
                row.isOdd ? 39 : 47,
              ),
              (row.isOdd ? 28 : 36) * 1920 / 1672,
              lines[column * 6 + row],
              line: column * 6 + row,
              color: row.isOdd ? 0xffa29487 : 0xff080706,
              weight: row.isOdd ? 600 : 800,
              italic: row.isEven,
              clear: 0xfff6f0e5,
            ),
      ];
      entries.add(
        _entry(
          sweat,
          sweatId,
          sweat['name'] as String,
          centerId,
          -1,
          revision,
          backgrounds[sweatId]!,
          0xfff6f0e5,
          fields,
          sample,
        ),
      );

      // Generate each final sample once, then downsample to the catalog thumbnail.
      final previews = <String, Uint8List>{};
      final thumbnails = <String, Uint8List>{};
      for (final entry in entries) {
        final single = CenterSlideCatalogModel.fromJson(
          {
            'schemaVersion': 1,
            'revision': revision,
            'centerName': input['centerName'] ?? '',
            'templates': [entry],
          },
          centerId: centerId,
          rejectInvalidItems: true,
        ).toEntity().templates.single;
        final recipe = single.theme.centerRecipe!;
        final png = await renderCenterSlide(
          recipe,
          single.sample!,
          backgroundBytes: backgrounds[single.id],
        );
        previews[single.id] = png;
        final codec = await ui.instantiateImageCodec(
          png,
          targetWidth: 640,
          targetHeight: 360,
        );
        final image = (await codec.getNextFrame()).image;
        codec.dispose();
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          thumbnails[single.id] = bytes!.buffer.asUint8List(
            bytes.offsetInBytes,
            bytes.lengthInBytes,
          );
        } finally {
          image.dispose();
        }
        final hash = sha256.convert(thumbnails[single.id]!).toString();
        (entry['recipe'] as Map)['thumbnail'] = {
          'path': 'center-templates/$centerId/${single.id}/$hash.png',
          'sha256': hash,
          'revision': recipe.revision,
          'width': 640,
          'height': 360,
        };
      }
      final model = CenterSlideCatalogModel.fromJson(
        {
          'schemaVersion': 1,
          'revision': revision,
          'centerName': input['centerName'] ?? '',
          'templates': entries,
        },
        centerId: centerId,
        rejectInvalidItems: true,
      );
      final manifests = <String, Map<String, String>>{};
      for (final group in {
        'backgrounds': backgrounds,
        'previews': previews,
        'thumbnails': thumbnails,
      }.entries) {
        await Directory('${output.path}/${group.key}').create(recursive: true);
        manifests[group.key] = {};
        for (final entry in group.value.entries) {
          final path = '${output.path}/${group.key}/${entry.key}.png';
          await File(path).writeAsBytes(entry.value);
          manifests[group.key]![entry.key] = path;
        }
      }
      const encoder = JsonEncoder.withIndent('  ');
      for (final entry in {
        'catalog': model.toJson(),
        'images': manifests['backgrounds'],
        'thumbnails': manifests['thumbnails'],
        'source-digests': sourceDigests,
        'sources': sources,
      }.entries) {
        await File('${output.path}/${entry.key}.json')
            .writeAsString('${encoder.convert(entry.value)}\n');
      }
    },
    skip: env['CENTER_BRAND_EXPORT'] != '1',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Map<String, dynamic> _entry(
  Map<String, dynamic>? prior,
  String id,
  String name,
  String centerId,
  int order,
  int catalogRevision,
  Uint8List background,
  int color,
  List<Map<String, dynamic>> fields,
  Map<String, dynamic> sample,
) {
  final hash = sha256.convert(background).toString();
  return {
    'id': id,
    'name': name.replaceAll(' 원본', ''),
    'description': '원본 배치와 글자 크기 유지 · 운동 문구 편집',
    'sortOrder': prior?['sortOrder'] ?? order,
    'published': prior?['published'] ?? true,
    'recipe': {
      'schemaVersion': 1,
      'templateId': id,
      'revision': ((prior?['recipe'] as Map?)?['revision'] as int? ?? 0) + 1,
      'centerId': centerId,
      'width': 1920,
      'height': 1080,
      'backgroundColor': color,
      'backgroundPath': 'center-templates/$centerId/$id/$hash.png',
      'backgroundSha256': hash,
      'fields': fields,
    },
    'sample': sample,
  };
}

Map<String, dynamic> _field(
  String binding,
  Rect bounds,
  double size,
  String original, {
  int? line,
  int color = 0xff000000,
  String font = 'Pretendard',
  int weight = 700,
  bool italic = false,
  int? clear,
}) => {
  'binding': binding,
  'lineIndex': ?line,
  'x': bounds.left / 1920,
  'y': bounds.top / 1080,
  'width': bounds.width / 1920,
  'height': bounds.height / 1080,
  'fontSize': size,
  'fontFamily': font,
  'fontWeight': weight,
  'italic': italic,
  'color': color,
  'originalText': original,
  'clearColor': ?clear,
};
String _required(Map<String, String> env, String key) =>
    env[key] ?? (throw StateError('$key is required.'));
Future<ui.Image> _read(String path) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

Future<Uint8List> _png(void Function(Canvas) draw) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(1920, 1080);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}
