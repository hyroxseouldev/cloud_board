import 'package:flutter_test/flutter_test.dart';

import 'package:cloud_board/src/app/feature/ai_slides/data/models/ai_slides_model.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_reference_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/slide_design_style.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/starter_workouts.dart';

const _author = WorkoutAuthor(
  id: 'owner',
  displayName: 'Coach',
  photoUrl: null,
);

void main() {
  test('fresh AI responses use current defaults and saved themes still take priority', () {
    final draft = AiSlideModel.fromJson({
      'title': 'WARM UP',
      'layout': 'list',
      'lines': ['Squat 10', 'Run 200m', 'Walk 30s'],
    }).toEntity();
    final preview = previewAiSlide(draft, 'generated');
    final added = confirmAiSlide(draft, 'generated');
    expect(added, preview);
    expect(added.designFontWeight, 700);
    expect(added.designItalic, isFalse);
    expect(added.text, 'Squat 10\nRun 200m\nWalk 30s');
    final savedTheme = applyAiSlideTheme(
      draft,
      const AiSlideTheme(
        designFontWeight: 900,
        designItalic: true,
        showTimer: false,
      ),
    );
    final styled = confirmAiSlide(savedTheme, 'generated');
    expect(styled, previewAiSlide(savedTheme, 'generated'));
    expect(styled.designFontWeight, 900);
    expect(styled.designItalic, isTrue);
    expect(styled.text, added.text);
  });

  test('all general catalog choices keep readable defaults through preview and add', () {
    expect(aiSlideDesignCatalog, hasLength(12));
    for (final design in aiSlideDesignCatalog) {
      final draft = applyAiSlideTheme(
        initialAiSlideDesignDraft(design.theme),
        design.theme,
      );
      final preview = previewAiSlide(draft, design.id);
      final added = confirmAiSlide(draft, design.id);
      expect(added, preview, reason: design.id);
      expect(
        added.designFontWeight,
        inInclusiveRange(600, 700),
        reason: design.id,
      );
      expect(added.designItalic, isFalse, reason: design.id);
      expect(
        added.designStyle!.titleWeight,
        inInclusiveRange(600, 700),
        reason: design.id,
      );
      expect(added.designStyle, design.theme.designStyle);
      expect(added.designAccentColor, design.theme.designAccentColor);
      expect(added.designBackgroundColor, design.theme.designBackgroundColor);
      expect(added.designTextColor, design.theme.designTextColor);
      expect(added.text.split('\n'), aiSlideDesignSample.lines);
      expect(added.designSubtitle, aiSlideDesignSample.designSubtitle);
      final restored = WorkoutModuleModel.fromJson(
        WorkoutModuleModel.fromEntity(added).toJson(),
      ).toEntity();
      expect(
        restored,
        added,
        reason: 'New defaults survive saving ${design.id}',
      );
    }
  });

  test(
    'all nine starter slides share clean sample, demo and owned artwork',
    () {
      var slides = 0;
      for (final starter in StarterWorkout.values) {
        final sample = starter.create(_author);
        final demo = starter.createDemo();
        final owned = starter.createOwned(_author);
        expect(sample.modules, hasLength(3));
        for (var index = 0; index < sample.modules.length; index++) {
          slides++;
          for (final module in [
            sample.modules[index],
            demo.modules[index],
            owned.modules[index],
          ]) {
            expect(module.designSubtitle, sample.modules[index].designSubtitle);
            expect(module.text, isNot(contains('자유롭게 수정하세요')));
            expect(module.designFontWeight, inInclusiveRange(600, 700));
            expect(module.designItalic, isFalse);
            expect(module.designStyle!.titleWeight, inInclusiveRange(600, 700));
            expect(module.designAccentColor, starter.color);
            expect(module.text, sample.modules[index].text);
          }
          expect(
            owned.modules[index].workSeconds,
            sample.modules[index].workSeconds,
          );
          expect(
            owned.modules[index].restSeconds,
            sample.modules[index].restSeconds,
          );
          expect(owned.modules[index].sets, sample.modules[index].sets);
          expect(demo.modules[index].workSeconds, 8);
          expect(demo.modules[index].restSeconds, 4);
        }
      }
      expect(slides, 9);
    },
  );

  test('new manual slides use current defaults while saved and legacy styles survive', () {
    final fresh = WorkoutModule.empty('new');
    expect(fresh.designFontWeight, 700);
    expect(fresh.designItalic, isFalse);
    final authored = fresh.copyWith(
      designTemplate: 'studio-v1-numbered',
      designFontWeight: 900,
      designItalic: true,
      designStyle: const SlideDesignStyle(titleWeight: 900),
      designSubtitle: '코치가 작성한 부제',
    );
    final json = WorkoutModuleModel.fromEntity(authored).toJson();
    expect(WorkoutModuleModel.fromJson(json).toEntity(), authored);
    json.remove('designFontWeight');
    json.remove('designItalic');
    final legacy = WorkoutModuleModel.fromJson(json).toEntity();
    expect(legacy.designFontWeight, 900);
    expect(legacy.designItalic, isTrue);
    expect(legacy.designSubtitle, authored.designSubtitle);
  });
}
