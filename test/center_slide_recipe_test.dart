import 'dart:convert';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> validRecipeJson() => {
  'schemaVersion': 1,
  'templateId': 'team-of-three',
  'revision': 1,
  'centerId': 'center-one',
  'width': 1672,
  'height': 941,
  'backgroundColor': 0xfff5f0e5,
  'fields': [
    <String, dynamic>{
      'binding': 'title',
      'x': .03,
      'y': .2,
      'width': .5,
      'height': .1,
      'fontSize': 64,
      'color': 0xff000000,
      'fontFamily': 'Pretendard',
      'fontWeight': 700,
      'italic': true,
      'align': 'left',
      'originalText': 'Team of 3',
      'clearColor': 0xfff5f0e5,
    },
  ],
};

Map<String, dynamic> firstField(Map<String, dynamic> json) =>
    (json['fields'] as List).first as Map<String, dynamic>;

void main() {
  test('rounded 16:9 recipe survives canonical JSON round trip', () {
    final recipe = CenterSlideRecipe.fromJson(validRecipeJson());
    expect(validateCenterSlideRecipe(recipe), isNull);
    final canonical = jsonDecode(jsonEncode(recipe.toJson()));
    expect(
      CenterSlideRecipe.fromJson(canonical as Map<String, dynamic>),
      recipe,
    );
    expect(recipe.fields.single.originalText, 'Team of 3');
  });

  test('background path is bound to its center, template and digest', () {
    final json = validRecipeJson();
    final digest = List.filled(64, 'a').join();
    json['backgroundSha256'] = digest;
    json['backgroundPath'] =
        'center-templates/center-one/team-of-three/$digest.png';
    expect(CenterSlideRecipe.fromJson(json).backgroundSha256, digest);
    for (final path in [
      'center-templates/other-center/team-of-three/$digest.png',
      'center-templates/center-one/other-template/$digest.png',
      'center-templates/center-one/team-of-three/../$digest.png',
      'https://example.invalid/$digest.png',
      'center-templates/center-one/team-of-three/$digest.png?token=secret',
    ]) {
      expect(
        () => CenterSlideRecipe.fromJson({...json, 'backgroundPath': path}),
        throwsFormatException,
      );
    }
    expect(
      () => CenterSlideRecipe.fromJson({...json, 'backgroundSha256': null}),
      throwsFormatException,
    );
  });

  for (final key in [
    'schemaVersion',
    'revision',
    'width',
    'height',
    'backgroundColor',
  ]) {
    test('rejects fractional $key before generated integer coercion', () {
      final json = validRecipeJson();
      json[key] = (json[key] as int) + .5;
      expect(() => CenterSlideRecipe.fromJson(json), throwsFormatException);
    });
  }

  test('rejects unknown schema, unsafe identifiers and invalid dimensions', () {
    for (final change in <Map<String, dynamic>>[
      {'schemaVersion': 2},
      {'revision': 0},
      {'templateId': '../template'},
      {'centerId': 'center/one'},
      {'width': 0},
      {'width': 4097},
      {'width': 1000, 'height': 1000},
      {'backgroundColor': -1},
      {'backgroundColor': 0x100000000},
    ]) {
      expect(
        () => CenterSlideRecipe.fromJson({...validRecipeJson(), ...change}),
        throwsFormatException,
        reason: change.toString(),
      );
    }
  });

  test('raw field numbers and booleans are strictly typed', () {
    for (final change in <Map<String, dynamic>>[
      {'fontWeight': 700.5},
      {'color': 0xff000000 + .5},
      {'clearColor': 100.5},
      {'italic': 'true'},
      {'align': null},
      {'x': '.03'},
      {'y': double.nan},
      {'fontSize': double.infinity},
    ]) {
      final json = validRecipeJson();
      firstField(json).addAll(change);
      expect(
        () => CenterSlideRecipe.fromJson(json),
        throwsFormatException,
        reason: change.toString(),
      );
    }
  });

  test(
    'rejects unsupported typography, invalid rectangles and multiline text',
    () {
      for (final change in <Map<String, dynamic>>[
        {'width': 0},
        {'x': .9, 'width': .2},
        {'y': -.1},
        {'fontFamily': 'ExternalFont'},
        {'fontWeight': 350},
        {'align': 'justify'},
        {'originalText': 'first\nsecond'},
        {'originalText': List.filled(61, '가').join()},
      ]) {
        final json = validRecipeJson();
        firstField(json).addAll(change);
        expect(() => CenterSlideRecipe.fromJson(json), throwsFormatException);
      }
    },
  );

  test(
    'line indices are required, bounded and distinct from named bindings',
    () {
      final json = validRecipeJson();
      final field = firstField(json);
      field['binding'] = 'line';
      for (final index in [null, -1, 24, .5]) {
        field['lineIndex'] = index;
        expect(() => CenterSlideRecipe.fromJson(json), throwsFormatException);
      }
      field['lineIndex'] = 23;
      expect(CenterSlideRecipe.fromJson(json).fields.single.lineIndex, 23);
      field['binding'] = 'subtitle';
      expect(() => CenterSlideRecipe.fromJson(json), throwsFormatException);
    },
  );

  test('rejects duplicate bindings, excessive fields and non-map entries', () {
    final json = validRecipeJson();
    final field = firstField(json);
    for (final fields in [
      [field, Map<String, dynamic>.from(field)],
      List.filled(33, field),
      [null],
      ['field'],
    ]) {
      expect(
        () => CenterSlideRecipe.fromJson({...json, 'fields': fields}),
        throwsFormatException,
      );
    }
  });

  test('programmatic recipes receive the same semantic validation', () {
    final valid = CenterSlideRecipe.fromJson(validRecipeJson());
    expect(validateCenterSlideRecipe(valid.copyWith(revision: 0)), isNotNull);
    expect(
      validateCenterSlideRecipe(
        valid.copyWith(fields: [valid.fields.single.copyWith(width: 2)]),
      ),
      isNotNull,
    );
    expect(validateCenterSlideRecipe(valid.copyWith(fields: [])), isNull);
  });
}
