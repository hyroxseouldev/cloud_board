import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_board/src/app/feature/ai_slides/data/renderers/center_slide_renderer.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/center_slide_creation.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';
import 'package:flutter_test/flutter_test.dart';

const recipe = CenterSlideRecipe(
  templateId: 'three-stations',
  revision: 2,
  centerId: 'center-one',
  width: 1920,
  height: 1080,
  backgroundColor: 0xfff5f0e5,
  fields: [
    CenterSlideField(
      binding: 'line',
      lineIndex: 0,
      x: .1,
      y: .3,
      width: .8,
      height: .1,
      fontSize: 40,
      color: 0xff000000,
      fontFamily: 'Pretendard',
      fontWeight: 700,
    ),
    CenterSlideField(
      binding: 'line',
      lineIndex: 2,
      x: .1,
      y: .6,
      width: .8,
      height: .1,
      fontSize: 40,
      color: 0xff000000,
      fontFamily: 'Pretendard',
      fontWeight: 700,
    ),
  ],
);

const draft = AiSlideDraft(
  title: 'Team of 3',
  layout: 'list',
  lines: ['Ski 250m', '', 'Row 200m'],
  centerRecipe: recipe,
  designHeaderLabel: 'Monday',
  designSubtitle: '5 min ON / 100 sec OFF',
  workSeconds: 300,
  restSeconds: 100,
  sets: 2,
  showTimer: true,
  timerX: .8,
  timerY: .6,
  timerSize: .9,
  designTextColor: 0xff123456,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List png;
  setUpAll(() async {
    png = await renderCenterSlide(recipe, draft);
  });

  test('confirm returns the existing plain image module contract', () {
    final module = confirmCenterSlide(draft, 'new-slide', png);
    final image = WorkoutImageSource.decode(module.imageSource);
    expect(module.id, 'new-slide');
    expect(module.name, draft.title);
    expect(module.text, 'Ski 250m\n\nRow 200m');
    expect(image.contentType, 'image/png');
    expect(image.bytes, png);
    expect(hasSlideDesign(module), isFalse);
    expect(module.designTemplate, isNull);
    expect(module.designStyle, isNull);
    expect(module.designFingerprint, isNull);
    expect(module.appearance.showTitle, isFalse);
    expect(module.appearance.showBody, isFalse);
    expect(module.coverImage, isFalse);
    expect(draft.centerRecipe, recipe);
  });

  test('JSON round trip needs no recipe or new display fields', () {
    final module = confirmCenterSlide(draft, 'saved-slide', png);
    final json = jsonDecode(
      jsonEncode(WorkoutModuleModel.fromEntity(module).toJson()),
    ) as Map<String, dynamic>;
    expect(json['imageUrl'], module.imageSource);
    expect(json.containsKey('centerRecipe'), isFalse);
    expect(json.containsKey('backgroundPath'), isFalse);
    expect(json.containsKey('designTemplate'), isFalse);
    expect(json.containsKey('designStyle'), isFalse);
    expect(json.containsKey('designFingerprint'), isFalse);
    final restored = WorkoutModuleModel.fromJson(json).toEntity();
    expect(restored, module);
    expect(hasSlideDesign(restored), isFalse);
  });

  test('timings and timer placement survive baking', () {
    final module = confirmCenterSlide(draft, 'timed-slide', png);
    expect(module.workSeconds, 300);
    expect(module.restSeconds, 100);
    expect(module.sets, 2);
    expect(module.showTimer, isTrue);
    expect(module.showSets, isTrue);
    expect(module.appearance.timerX, .8);
    expect(module.appearance.timerY, .6);
    expect(module.appearance.timerSize, .9);
    expect(module.timerMode, WorkoutTimerMode.custom);
    expect(module.timingVersion, WorkoutModule.empty('defaults').timingVersion);
    final noTimer = confirmCenterSlide(
      draft.copyWith(showTimer: false),
      'no-timer',
      png,
    );
    expect(noTimer.showTimer, isFalse);
    expect(noTimer.showSets, isFalse);
    expect(noTimer.workSeconds, 300);
  });

  test('unspecified timings retain normal new-slide defaults', () {
    final module = confirmCenterSlide(
      draft.copyWith(workSeconds: null, restSeconds: null, sets: null),
      'default-timing',
      png,
    );
    final defaults = WorkoutModule.empty('defaults');
    expect(module.workSeconds, defaults.workSeconds);
    expect(module.restSeconds, defaults.restSeconds);
    expect(module.sets, defaults.sets);
  });

  test(
    'sparse line slots permit blank placeholders but never discard content',
    () {
      expect(centerSlideDraftError(draft), isNull);
      expect(
        centerSlideDraftError(
          draft.copyWith(lines: ['Ski', 'Unmapped', 'Row']),
        ),
        isNotNull,
      );
      expect(
        centerSlideDraftError(
          draft.copyWith(lines: ['Ski', '', 'Row', 'Lost']),
        ),
        isNotNull,
      );
    },
  );

  test('invalid recipe, content and timing fail before module creation', () {
    for (final invalid in [
      draft.copyWith(centerRecipe: null),
      draft.copyWith(centerRecipe: recipe.copyWith(revision: 0)),
      draft.copyWith(title: '  '),
      draft.copyWith(title: List.filled(61, 'x').join()),
      draft.copyWith(designSubtitle: List.filled(121, 'x').join()),
      draft.copyWith(workSeconds: 0),
      draft.copyWith(workSeconds: 3601),
      draft.copyWith(restSeconds: -1),
      draft.copyWith(restSeconds: 3601),
      draft.copyWith(sets: 0),
      draft.copyWith(sets: 101),
    ]) {
      expect(centerSlideDraftError(invalid), isNotNull);
      expect(
        () => confirmCenterSlide(invalid, 'invalid', png),
        throwsA(isA<AiSlidesFailure>()),
      );
    }
  });

  test('non-PNG bytes cannot be returned as a saved slide', () {
    for (final invalid in [
      Uint8List(0),
      Uint8List.fromList([0xff, 0xd8, 0xff]),
    ]) {
      expect(
        () => confirmCenterSlide(draft, 'invalid-image', invalid),
        throwsA(isA<AiSlidesFailure>()),
      );
    }
  });
}
