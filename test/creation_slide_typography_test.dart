import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_design_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/slide_editor_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';

import '../tool/center_slide_export_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCenterSlideExportFonts);
  test('all twelve general samples use fixed role sizes without changing saved rendering', () {
    for (final design in aiSlideDesignCatalog) {
      final module = previewAiSlide(
        applyAiSlideTheme(aiSlideDesignSample, design.theme),
      );
      final existing = measureSlideDesign(module);
      final revised = measureSlideDesign(module, creationTypography: true);
      final shorter = measureSlideDesign(
        module.copyWith(text: 'Squat 10'),
        creationTypography: true,
      );
      expect(revised.readable, isTrue, reason: design.id);
      final card =
          design.theme.designStyle!.family == 'cards' ||
          module.designLayout == 'cards';
      for (final candidate in [revised, shorter]) {
        expect(candidate.columns, revised.columns);
        expect(
          candidate.textRuns
              .where((run) => run.role == 'body')
              .map((run) => run.fontSize),
          everyElement(card ? 42.0 : 48.0),
          reason: design.id,
        );
      }
      expect(
        revised.textRuns
            .singleWhere((run) => run.role == 'headerLabel')
            .fontSize,
        32,
      );
      expect(
        revised.textRuns.singleWhere((run) => run.role == 'subtitle').fontSize,
        38,
      );
      // Opt-in has not changed the legacy plan/fingerprint or caller's module.
      expect(
        measureSlideDesign(module).textRuns.first.fontSize,
        existing.textRuns.first.fontSize,
      );
    }
  });
  test('new fixed layout overflows explicitly instead of shrinking or selecting new columns', () {
    final module = previewAiSlide(
      applyAiSlideTheme(aiSlideDesignSample, aiSlideDesignCatalog.first.theme),
    );
    final long = module.copyWith(
      text: List.filled(24, '긴 운동 안내와 수치 25회 / 100m').join('\n'),
    );
    final plan = measureSlideDesign(long, creationTypography: true);
    expect(plan.warning, isNotNull);
    expect(plan.columns, 1);
    expect(
      plan.textRuns
          .where((run) => run.role == 'body')
          .map((run) => run.fontSize),
      everyElement(48.0),
    );
    expect(long.text.split('\n'), hasLength(24));
  });
  test(
    'three general legacy template families opt in without altering old plans',
    () {
      for (final layout in ['numbered', 'list', 'interval']) {
        final module = WorkoutModule.empty(layout).copyWith(
          name: 'WARM UP',
          text: 'Squat 10\nRun 200m',
          designTemplate: 'stationd-v2-$layout',
          showTimer: false,
          showSets: false,
        );
        final before = measureSlideDesign(module);
        final fixed = measureSlideDesign(module, creationTypography: true);
        expect(fixed.columns, 1);
        expect(
          fixed.textRuns
              .where((run) => run.role == 'body')
              .map((run) => run.fontSize),
          everyElement(48.0),
        );
        expect(measureSlideDesign(module).minFontSize, before.minFontSize);
      }
    },
  );
  test('section columns stay fixed when only wording grows or shrinks', () {
    for (final template in ['studio-v1-list', 'stationd-v2-list']) {
      final module =
          previewAiSlide(
            applyAiSlideTheme(
              aiSlideDesignSample,
              aiSlideDesignCatalog.first.theme,
            ),
          ).copyWith(
            designTemplate: template,
            designLayout: 'columns',
            text: '## A\nSquat 10\n## B\nRow 20\n## C\nRun 100m\n## D\nBike 30',
          );
      final before = measureSlideDesign(module, creationTypography: true);
      final after = measureSlideDesign(
        module.copyWith(
          text: module.text.replaceFirst('Squat 10', 'Squat 10 반복 안내 ' * 25),
        ),
        creationTypography: true,
      );
      final beforeColumns = {
        for (final section in before.sections)
          section.heading: section.rect.left,
      };
      expect(
        {
          for (final section in after.sections)
            section.heading: section.rect.left,
        },
        beforeColumns,
        reason: template,
      );
      expect(after.columns, before.columns);
    }
  });

  test(
    'final creation keeps editable source and a versioned reusable PNG',
    () async {
      final module = confirmAiSlide(
        applyAiSlideTheme(
          aiSlideDesignSample,
          aiSlideDesignCatalog.first.theme,
        ),
        'created',
      );
      final created = await prepareCreatedSlideDesign(module);
      expect(created.imageSource, startsWith('data:image/png;base64,'));
      expect(created.designTemplate, 'studio-v2-numbered');
      expect(created.designStyle, module.designStyle);
      expect(hasSlideDesign(created), isTrue);
      expect(isCreationSlideDesign(created), isTrue);
      expect(created.appearance.showTitle, isFalse);
      expect(created.appearance.showBody, isFalse);
      expect(created.name, module.name);
      expect(created.text, module.text);
      expect(created.workSeconds, module.workSeconds);
      expect(created.sets, module.sets);
      expect(await prepareSlideDesign(created), created);
      final restored = WorkoutModuleModel.fromJson(
        WorkoutModuleModel.fromEntity(created).toJson(),
      ).toEntity();
      expect(restored, created);
      expect(
        slideDesignOptions(restored).keys,
        everyElement(startsWith('studio-v2-')),
      );
      final edited = restored.copyWith(text: 'Squat 20\nRun 300m');
      expect(
        measureSlideDesign(edited).textRuns
            .where((run) => run.role == 'body')
            .map((run) => run.fontSize),
        everyElement(48.0),
      );
      expect(slideDesignFingerprint(edited), isNot(created.designFingerprint));
      expect(
        (await prepareSlideDesign(edited)).imageSource,
        isNot(created.imageSource),
      );
      final styled = applySlideStyle(edited, module);
      expect(styled.designTemplate, startsWith('studio-v2-'));
      expect(
        applySlideStyle(module, module).designTemplate,
        startsWith('studio-v1-'),
      );
    },
  );
}
