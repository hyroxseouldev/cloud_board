import 'package:cloud_board/src/app/feature/ai_slides/data/models/center_slide_catalog_model.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/center_slide_creation.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_content_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const requestedWod = '''A. VO₂ Max Running Interval
• 3% Incline Run 90s Sp 12-20
• Warm-up: 1 set
• 90–100% 5 set

B. Strength
1. Bench Press
• 40% – 1 set
• 80% – 5 set

2. Barbell Overhead Press
• 40% – 1 set
• 80% – 5 set''';

CenterSlideRecipe flowRecipe() => const CenterSlideRecipe(
  schemaVersion: 2,
  templateId: 'flow-test',
  revision: 1,
  centerId: 'center-one',
  width: 1920,
  height: 1080,
  backgroundColor: 0xffffffff,
  fields: [],
  body: CenterSlideBody(
    x: .05,
    y: .25,
    width: .9,
    height: .7,
    fontSize: 54,
    color: 0xff222222,
    headingColor: 0xffff5500,
    fontFamily: 'Pretendard',
  ),
);

void main() {
  testWidgets(
    'full WOD paste preserves section labels, exercise notes and blanks',
    (tester) async {
      var draft = AiSlideDraft(
        title: 'Mixed class',
        layout: 'list',
        lines: const ['Initial'],
        centerRecipe: flowRecipe(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => AiSlidesContentEditor(
                  draft: draft,
                  warnings: const [],
                  validationMessage: centerSlideDraftError(draft),
                  onChanged: (next) => setState(() => draft = next),
                ),
              ),
            ),
          ),
        ),
      );
      final input = find.byKey(const ValueKey('ai-center-wod'));
      expect(input, findsOneWidget);
      expect(find.byKey(const ValueKey('ai-center-column-0')), findsNothing);
      await tester.enterText(input, requestedWod);
      await tester.pump();
      expect(draft.lines.join('\n'), requestedWod);
      expect(centerSlideDraftError(draft), isNull);
      expect(draft.workSeconds, isNull);
      expect(draft.restSeconds, isNull);
      expect(draft.sets, isNull);

      final tooLong = List.filled(61, 'Bench Press 5 sets').join('\n');
      await tester.enterText(input, tooLong);
      await tester.pump();
      expect(tester.widget<TextField>(input).controller!.text, tooLong);
      expect(draft.lines, hasLength(61));
      expect(centerSlideDraftError(draft), isNotNull);
      await tester.enterText(input, requestedWod);
      await tester.pump();
      expect(centerSlideDraftError(draft), isNull);
    },
  );

  for (final textWithBlank in ['Ski\n', '\nSki']) {
    testWidgets('undo restores exact WOD whitespace before next typing: '
        '${textWithBlank.startsWith('\n') ? 'leading' : 'trailing'}', (
      tester,
    ) async {
      var draft = AiSlideDraft(
        title: 'Mixed class',
        layout: 'list',
        lines: const ['Ski'],
        centerRecipe: flowRecipe(),
      );
      final history = <AiSlideDraft>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => Column(
                  children: [
                    TextButton(
                      onPressed: () =>
                          setState(() => draft = history.removeLast()),
                      child: const Text('Undo WOD'),
                    ),
                    AiSlidesContentEditor(
                      draft: draft,
                      warnings: const [],
                      onChanged: (next) => setState(() {
                        history.add(draft);
                        draft = next;
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final input = find.byKey(const ValueKey('ai-center-wod'));
      await tester.enterText(input, textWithBlank);
      await tester.pump();
      expect(draft.lines.join('\n'), textWithBlank);
      await tester.tap(find.text('Undo WOD'));
      await tester.pump();
      final controller = tester.widget<TextField>(input).controller!;
      expect(draft.lines, ['Ski']);
      expect(controller.text, 'Ski');
      await tester.enterText(input, '${controller.text} + Row');
      await tester.pump();
      expect(draft.lines, ['Ski + Row']);
    });
  }

  test(
    'flow catalog accepts longer content only with the v2 recipe contract',
    () {
      final raw = <String, dynamic>{
        'schemaVersion': 1,
        'revision': 3,
        'centerName': '',
        'templates': [
          <String, dynamic>{
            'id': 'flow-test',
            'name': 'Flow',
            'description': '',
            'sortOrder': 1,
            'published': true,
            'recipe': flowRecipe().toJson(),
            'sample': <String, dynamic>{
              'title': 'Flow',
              'lines': List.filled(30, 'Exercise 1'),
            },
          },
        ],
      };
      final model = CenterSlideCatalogModel.fromJson(
        raw,
        centerId: 'center-one',
        rejectInvalidItems: true,
      );
      expect(model.toEntity().templates.single.sample!.lines, hasLength(30));
      final entry = (raw['templates'] as List).single as Map<String, dynamic>;
      final sample = entry['sample'] as Map<String, dynamic>;
      sample['lines'] = List.filled(61, 'Exercise 1');
      expect(
        () => CenterSlideCatalogModel.fromJson(
          raw,
          centerId: 'center-one',
          rejectInvalidItems: true,
        ),
        throwsFormatException,
      );
      entry.remove('sample');
      expect(
        () => CenterSlideCatalogModel.fromJson(
          raw,
          centerId: 'center-one',
          rejectInvalidItems: true,
        ),
        throwsFormatException,
      );
    },
  );
}
