import 'dart:convert';
import 'dart:io';

import 'package:cloud_board/src/app/feature/ai_slides/data/models/center_slide_catalog_model.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/models/slide_studio_model.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/renderers/center_slide_renderer.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_raster.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/slide_studio.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/slide_studio_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _catalogPath = String.fromEnvironment('STA203_CATALOG_FIXTURE');
const _receiptPath = String.fromEnvironment('STA203_OPERATION_FIXTURE');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('Pretendard');
    for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
      fonts.addFont(
        rootBundle.load('assets/fonts/pretendard/Pretendard-$weight.otf'),
      );
    }
    await fonts.load();
  });

  test('basic designs apply completed groups through existing sections without altering source values', () {
    const groups = [
      AiRasterGroup(
        heading: 'A',
        lines: ['Row 1,000 m', 'DB Row 22.5 kg × 12'],
      ),
      AiRasterGroup(heading: 'B', lines: ['Plank 60 sec', 'Sled Pull 1 lap']),
      AiRasterGroup(
        heading: 'C',
        lines: ['Bike 8/6 cal', 'KB Goblet Squat 8/6 → Rest'],
      ),
    ];
    final lines = groups.expand((group) => group.lines).toList();
    final draft = studioDraft(
      StudioInput(design: aiSlideDesignCatalog[3], raw: lines.join('\n')),
      groups: groups,
    );
    final sections = parseSlideDesignSections(previewAiSlide(draft).text);
    expect(sections.map((section) => section.heading), ['A', 'B', 'C']);
    expect(sections.expand((section) => section.lines), lines);
  });

  test('explicit exercise guidance roundtrips without importing sample time or changing timer values', () {
    final input = StudioInput(
      design: aiSlideDesignCatalog.first,
      raw: 'Row 1,000 m',
      subtitle: '5mins On / 90s Off',
    );
    final empty = studioDraft(input.copyWith(subtitle: ''));
    expect(empty.designSubtitle, isEmpty);
    final draft = studioDraft(input);
    expect(draft.designSubtitle, input.subtitle);
    expect(draft.workSeconds, isNull);
    expect(draft.restSeconds, isNull);
    expect(draft.sets, isNull);
    final module = confirmAiSlide(draft, 'guidance');
    final restored = WorkoutModuleModel.fromJson(
      WorkoutModuleModel.fromEntity(module).toJson(),
    ).toEntity();
    expect(restored.text, input.raw);
    expect(restored.designSubtitle, input.subtitle);
    final defaults = WorkoutModule.empty('defaults');
    expect(restored.workSeconds, defaults.workSeconds);
    expect(restored.restSeconds, defaults.restSeconds);
    expect(restored.sets, defaults.sets);
  });

  test('recorded completed response parses and restored fixed recipe reproduces overflow locally', () {
    // Optional private evidence stays outside the repository and is read only.
    final catalog = jsonDecode(
      File(_catalogPath).readAsStringSync(),
    ) as Map<String, dynamic>;
    final entries = catalog['templates'] as List;
    final rawDesign = entries.cast<Map<String, dynamic>>().singleWhere(
      (entry) => entry['id'] == 'sweatmonday-team-of-3-v1',
    );
    final center = (rawDesign['recipe'] as Map)['centerId'] as String;
    final design =
        CenterSlideCatalogModel.fromJson(
          catalog,
          centerId: center,
          rejectInvalidItems: true,
        ).toEntity().templates.singleWhere(
          (entry) => entry.theme.centerRecipe?.templateId == rawDesign['id'],
        );
    final receipt = jsonDecode(
      File(_receiptPath).readAsStringSync(),
    ) as Map<String, dynamic>;
    final job = (receipt['operations'] as List)
        .cast<Map<String, dynamic>>()
        .first;
    final operation = readStudioOperation({
      'job': {...job, 'requestId': job['id']},
    }, reference: false);
    expect(operation.status, 'completed');
    expect(operation.groups.map((group) => group.heading), ['A', 'B', 'C']);
    final lines = operation.groups.expand((group) => group.lines).toList();
    expect(lines, hasLength(9));
    final input = StudioInput(
      design: design,
      raw: lines.join('\n'),
      mode: StudioMode.organize,
    );
    final recipe = design.theme.centerRecipe!;
    expect(recipe.revision, 3);
    expect(recipe.body, isNull);
    expect(studioSupportsGroups(input), isFalse);
    final draft = studioDraft(input);
    expect(draft.lines, lines);
    expect(
      () => prepareCenterSlideLayout(recipe, draft),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'specific overflow',
          contains('문구가 넘쳐요'),
        ),
      ),
    );
    final overflowingSlots = <int>[];
    for (var i = 0; i < lines.length; i++) {
      final field = recipe.fields.singleWhere(
        (field) => field.binding == 'line' && field.lineIndex == i,
      );
      final isolated = recipe.copyWith(fields: [field]);
      try {
        prepareCenterSlideLayout(
          isolated,
          draft.copyWith(lines: [...List.filled(i, ''), lines[i]]),
        ).dispose();
      } on FormatException {
        overflowingSlots.add(i);
      }
    }
    expect(overflowingSlots, contains(1));
    // No account IDs, storage paths, tokens or private assets in the log.
    // ignore: avoid_print
    print(
      'Recorded response parsed; overflowing zero-based slots: $overflowingSlots',
    );
  }, skip: _catalogPath.isEmpty || _receiptPath.isEmpty);
}
