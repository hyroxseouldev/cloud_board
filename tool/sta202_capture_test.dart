import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_reference_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_design_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';

import 'center_slide_export_fonts.dart';

/// Explicit local artifacts using bundled real fonts. Not a browser/app E2E.
/// STA202_CAPTURE_OUTPUT=<new directory> flutter test --no-pub tool/sta202_capture_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final output = Platform.environment['STA202_CAPTURE_OUTPUT'];
  test(
    'capture source / fixed creation / final PNG at identical 1920x1080',
    () async {
      final root = Directory(output!).absolute;
      if (await root.exists())
        throw StateError('Choose a new output directory.');
      await loadCenterSlideExportFonts();
      final modules = <String, WorkoutModule>{
        for (final design in aiSlideDesignCatalog)
          design.id: previewAiSlide(
            applyAiSlideTheme(aiSlideDesignSample, design.theme),
          ),
        for (final design in customerReferenceDesigns)
          design.id: previewAiSlide(
            applyAiSlideTheme(
              initialAiSlideDesignDraft(design.theme),
              design.theme,
            ),
          ),
        for (final kind in ['numbered', 'list', 'interval'])
          'general-$kind': WorkoutModule.empty(kind).copyWith(
            name: '오늘의 클래스',
            text: '스쿼트 10회\nRun 200m\nWall Ball 20',
            designTemplate: 'stationd-v2-$kind',
            designItalic: false,
            showTimer: false,
            showSets: false,
          ),
      };
      final inventory = <Map<String, dynamic>>[];
      for (final entry in modules.entries) {
        for (final fixed in [false, true]) {
          final group = fixed ? 'after' : 'before';
          await Directory('${root.path}/$group').create(recursive: true);
          final png = await renderSlideDesign(
            entry.value,
            creationTypography: fixed,
          );
          await File('${root.path}/$group/${entry.key}.png')
              .writeAsBytes(base64Decode(png.split(',').last));
          final metrics = measureSlideDesign(
            entry.value,
            creationTypography: fixed,
          );
          inventory.add({
            'id': entry.key,
            'variant': group,
            'width': 1920,
            'height': 1080,
            'warning': metrics.warning,
            'columns': metrics.columns,
            'runs': [
              for (final run in metrics.textRuns)
                {
                  'role': run.role,
                  'text': run.value,
                  'fontSize': run.fontSize,
                  'weight': run.fontWeight,
                  'fontFamily': run.fontFamily,
                  'bounds': [
                    run.rect.left,
                    run.rect.top,
                    run.rect.width,
                    run.rect.height,
                  ],
                },
            ],
          });
        }
        final finalModule = await prepareCreatedSlideDesign(entry.value);
        await Directory('${root.path}/final').create(recursive: true);
        await File(
          '${root.path}/final/${entry.key}.png',
        ).writeAsBytes(base64Decode(finalModule.imageSource.split(',').last));
        expect(isCreationSlideDesign(finalModule), isTrue);
        expect(finalModule.designStyle, entry.value.designStyle);
      }
      await File('${root.path}/inventory.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(inventory));
    },
    skip: output == null,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
