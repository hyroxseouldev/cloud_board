import 'dart:convert';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _body() => {
  'x': .05,
  'y': .3,
  'width': .9,
  'height': .65,
  'fontSize': 64,
  'color': 0xff111111,
  'headingColor': 0xffe06010,
  'fontFamily': 'Pretendard',
};
Map<String, dynamic> _recipe() => {
  'schemaVersion': 2,
  'templateId': 'flow',
  'revision': 1,
  'centerId': 'center-one',
  'width': 1920,
  'height': 1080,
  'backgroundColor': 0xffffffff,
  'fields': [
    <String, dynamic>{
      'binding': 'title',
      'x': .05,
      'y': .05,
      'width': .9,
      'height': .15,
      'fontSize': 64,
      'color': 0xff000000,
      'fontFamily': 'Pretendard',
      'fontWeight': 700,
    },
  ],
  'body': _body(),
};

void main() {
  test('v2 body defaults and canonical JSON round trip', () {
    final recipe = CenterSlideRecipe.fromJson(_recipe());
    expect(recipe.body!.fontWeight, 600);
    expect(recipe.body!.layout, 'auto');
    expect(recipe.body!.maxColumns, 3);
    expect(
      CenterSlideRecipe.fromJson(
        jsonDecode(jsonEncode(recipe.toJson())) as Map<String, dynamic>,
      ),
      recipe,
    );
  });

  test('v1 remains fixed slots while v2 requires flowing body', () {
    expect(
      () => CenterSlideRecipe.fromJson({..._recipe(), 'schemaVersion': 1}),
      throwsFormatException,
    );
    expect(
      () => CenterSlideRecipe.fromJson({..._recipe(), 'body': null}),
      throwsFormatException,
    );
    expect(
      () => CenterSlideRecipe.fromJson({..._recipe(), 'schemaVersion': 3}),
      throwsFormatException,
    );
    expect(
      CenterSlideRecipe.fromJson({
        ..._recipe(),
        'schemaVersion': 1,
        'body': null,
      }).body,
      isNull,
    );
  });

  test('body raw types and defaults cannot coerce invalid values', () {
    for (final change in <Map<String, dynamic>>[
      {'fontWeight': 600.5},
      {'maxColumns': 2.5},
      {'color': 123.5},
      {'headingColor': 'black'},
      {'fontWeight': null},
      {'maxColumns': null},
      {'layout': null},
      {'x': '0.05'},
      {'height': double.nan},
      {'fontSize': double.infinity},
      {'fontFamily': null},
      {'originalText': ''},
    ]) {
      expect(
        () => CenterSlideRecipe.fromJson({
          ..._recipe(),
          'body': {..._body(), ...change},
        }),
        throwsFormatException,
        reason: change.toString(),
      );
    }
  });

  test('body semantic bounds, typography and layout are strict', () {
    for (final change in <Map<String, dynamic>>[
      {'width': 0},
      {'x': .9},
      {'height': 1.0},
      {'color': -1},
      {'headingColor': 0x100000000},
      {'fontWeight': 650},
      {'fontFamily': 'remote-font'},
      {'layout': 'masonry'},
      {'maxColumns': 0},
      {'maxColumns': 4},
    ]) {
      expect(
        () => CenterSlideRecipe.fromJson({
          ..._recipe(),
          'body': {..._body(), ...change},
        }),
        throwsFormatException,
        reason: change.toString(),
      );
    }
  });

  test('v2 forbids fixed line fields and overlap with body', () {
    final recipe = CenterSlideRecipe.fromJson(_recipe());
    final field = recipe.fields.single;
    expect(
      validateCenterSlideRecipe(
        recipe.copyWith(
          fields: [field.copyWith(binding: 'line', lineIndex: 0)],
        ),
      ),
      isNotNull,
    );
    expect(
      validateCenterSlideRecipe(
        recipe.copyWith(fields: [field.copyWith(y: .29)]),
      ),
      isNotNull,
    );
    expect(
      validateCenterSlideRecipe(
        recipe.copyWith(fields: [field.copyWith(y: .15, height: .15)]),
      ),
      isNull,
      reason: 'Touching edges do not overlap.',
    );
  });
}
