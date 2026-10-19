import 'dart:convert';
import 'dart:io';

import 'package:cloud_board/src/app/feature/ai_slides/data/models/center_slide_catalog_model.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/renderers/center_slide_renderer.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_reference_design.dart';
import 'package:flutter_test/flutter_test.dart';

/// Operator-only local validation. No Firebase initialization or publication.
void main() {
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
      if (imagePath != null && imagePath.isNotEmpty) {
        final bytes = await File(imagePath).readAsBytes();
        final designs = model
            .toEntity()
            .templates
            .where((design) => design.theme.centerRecipe != null)
            .toList();
        if (designs.length != 1) {
          throw const FormatException(
            'PNG validation needs one visible recipe.',
          );
        }
        final design = designs.single;
        await renderCenterSlide(
          design.theme.centerRecipe!,
          design.sample ?? initialAiSlideDesignDraft(design.theme),
          backgroundBytes: bytes,
        );
      }
      await File(output).writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(model.toJson())}\n',
        flush: true,
      );
    },
  );
}
