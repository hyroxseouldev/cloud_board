import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/center_slide_creation.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/center_slide_line_groups.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_content_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CenterSlideRecipe recipe() => CenterSlideRecipe(
  templateId: 'three-columns',
  revision: 1,
  centerId: 'center-one',
  width: 1920,
  height: 1080,
  backgroundColor: 0xffffffff,
  fields: [
    for (var column = 0; column < 3; column++)
      for (var row = 0; row < 6; row++)
        CenterSlideField(
          binding: 'line',
          lineIndex: column * 6 + row,
          x: .04 + column * .3 + (row.isOdd ? .004 : 0),
          y: .1 + row * .1,
          width: .25,
          height: .08,
          fontSize: 40,
          color: 0xff000000,
          fontFamily: 'Pretendard',
          fontWeight: 700,
        ),
  ],
);

void main() {
  test(
    'groups nearby x positions while keeping each column lineIndex order',
    () {
      final original = recipe();
      final shuffled = original.copyWith(
        fields: original.fields.reversed.toList(),
      );
      expect(centerSlideLineGroups(shuffled), [
        [0, 1, 2, 3, 4, 5],
        [6, 7, 8, 9, 10, 11],
        [12, 13, 14, 15, 16, 17],
      ]);
    },
  );

  test('paste preserves internal blank lines and other columns', () {
    final original = List.generate(18, (index) => 'original $index');
    final changed = replaceCenterSlideGroup(original, [
      0,
      1,
      2,
      3,
      4,
      5,
    ], 'Ski\r\n\r\nRow');
    expect(changed.take(6), ['Ski', '', 'Row', '', '', '']);
    expect(changed.skip(6), original.skip(6));
    expect(original.first, 'original 0');
  });

  test(
    'overflow remains in its own column and blocks creation until corrected',
    () {
      final original = List.generate(18, (index) => 'original $index');
      final groups = centerSlideLineGroups(recipe());
      final pasted = List.generate(8, (index) => 'pasted $index').join('\n');
      final overflow = replaceCenterSlideGroup(original, groups.first, pasted);
      expect(centerSlideGroupValues(overflow, groups.first).join('\n'), pasted);
      expect(overflow[5], 'pasted 5\npasted 6\npasted 7');
      expect(overflow.skip(6), original.skip(6));
      final draft = AiSlideDraft(
        title: 'Class',
        layout: 'list',
        lines: overflow,
        centerRecipe: recipe(),
      );
      expect(centerSlideDraftError(draft), isNotNull);
      final corrected = replaceCenterSlideGroup(
        overflow,
        groups.first,
        'one\n\nthree',
      );
      expect(centerSlideDraftError(draft.copyWith(lines: corrected)), isNull);
    },
  );

  test('sparse indices do not overwrite another column', () {
    final result = replaceCenterSlideGroup(
      ['A0', 'B0', 'A1', 'B1'],
      [0, 2],
      'new0\nnew1\nextra',
    );
    expect(result, ['new0', 'B0', 'new1\nextra', 'B1']);
  });

  testWidgets(
    'shows three multiline areas and keeps pasted overflow editable',
    (tester) async {
      var draft = AiSlideDraft(
        title: 'Class',
        layout: 'list',
        lines: List.generate(18, (index) => 'original $index'),
        centerRecipe: recipe(),
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
                  onChanged: (value) => setState(() => draft = value),
                ),
              ),
            ),
          ),
        ),
      );
      for (var column = 0; column < 3; column++) {
        expect(
          find.byKey(ValueKey('ai-center-column-$column')),
          findsOneWidget,
        );
      }
      expect(find.byKey(const ValueKey('ai-center-line-0')), findsNothing);
      final field = find.byKey(const ValueKey('ai-center-column-0'));
      final pasted = List.generate(7, (index) => 'line $index').join('\n');
      await tester.enterText(field, pasted);
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, pasted);
      expect(find.textContaining('입력한 내용은 그대로 보관'), findsOneWidget);
      expect(centerSlideDraftError(draft), isNotNull);
      expect(draft.lines[6], 'original 6');
      await tester.enterText(field, 'one\n');
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, 'one\n');
      expect(centerSlideDraftError(draft), isNull);
      expect(draft.lines.take(6), ['one', '', '', '', '', '']);
    },
  );
}
