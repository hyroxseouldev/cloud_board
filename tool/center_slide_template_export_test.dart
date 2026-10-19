import 'dart:convert';
import 'dart:io';

import 'package:cloud_board/src/app/feature/ai_slides/data/models/center_slide_catalog_model.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/renderers/center_slide_renderer.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_reference_design.dart';
import 'package:flutter_test/flutter_test.dart';

import 'center_slide_export_fonts.dart';

/// Operator-only local validation. No Firebase initialization or publication.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'validate center catalog with the app parser and image renderer',
    () async {
      final env = Platform.environment;
      final output = env['CENTER_CATALOG_OUTPUT'];
      final centerId = env['CENTER_CATALOG_CENTER_ID'];
      if (output == null || output.isEmpty || centerId == null) {
        throw StateError('Run register-center-slide-templates.mjs.');
      }
      final Map<String, dynamic> raw;
      if (env['CENTER_CATALOG_SEED'] == 'stationd') {
        raw = {
          'schemaVersion': 1,
          'revision': int.parse(env['CENTER_CATALOG_REVISION']!),
          'centerName': env['CENTER_CATALOG_CENTER_NAME'] ?? '',
          'templates': [
            for (final (index, design) in customerReferenceDesigns.indexed)
              {
                'id': design.id,
                'name': design.name,
                'description': design.description,
                'sortOrder': index,
                'published': true,
                'originalTemplateId':
                    design.theme.designStyle!.originalTemplate,
              },
          ],
        };
      } else {
        raw = Map<String, dynamic>.from(
          jsonDecode(await File(env['CENTER_CATALOG_INPUT']!).readAsString())
              as Map,
        );
      }
      final model = CenterSlideCatalogModel.fromJson(
        raw,
        centerId: centerId,
        rejectInvalidItems: true,
      );
      final imagePath = env['CENTER_CATALOG_IMAGE'];
      final imageManifestPath = env['CENTER_CATALOG_IMAGES'];
      final singleImage = imagePath != null && imagePath.isNotEmpty;
      final batchImages =
          imageManifestPath != null && imageManifestPath.isNotEmpty;
      if (singleImage && batchImages) {
        throw const FormatException('Choose one image input mode.');
      }
      final designs = {
        for (final design in model.toEntity().templates)
          if (design.theme.centerRecipe != null) design.id: design,
      };
      final images = <String, String>{};
      if (singleImage) {
        if (designs.length != 1) {
          throw const FormatException(
            'PNG validation needs one visible recipe.',
          );
        }
        images[designs.keys.single] = imagePath;
      } else if (batchImages) {
        final decoded = jsonDecode(
          await File(imageManifestPath).readAsString(),
        );
        if (decoded is! Map<String, dynamic> || decoded.isEmpty) {
          throw const FormatException('Invalid image manifest.');
        }
        for (final entry in decoded.entries) {
          final path = entry.value;
          if (path is! String || path.isEmpty) {
            throw const FormatException('Image paths must be strings.');
          }
          images[entry.key] = path;
        }
        if (images.length != designs.length ||
            images.keys.any((id) => !designs.containsKey(id))) {
          throw const FormatException(
            'Image manifest must match every visible recipe exactly.',
          );
        }
      }
      if (images.isNotEmpty) await loadCenterSlideExportFonts();
      for (final entry in images.entries) {
        final file = File(entry.value);
        if (await file.length() > 10 * 1024 * 1024) {
          throw const FormatException('PNG exceeds 10 MiB.');
        }
        final design = designs[entry.key]!;
        // The shared renderer validates PNG bytes/hash/geometry and supports
        // both v1 fixed fields and v2 flowing bodies without a CLI copy.
        await renderCenterSlide(
          design.theme.centerRecipe!,
          design.sample ?? initialAiSlideDesignDraft(design.theme),
          backgroundBytes: await file.readAsBytes(),
        );
      }
      await File(output).writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(model.toJson())}\n',
        flush: true,
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
