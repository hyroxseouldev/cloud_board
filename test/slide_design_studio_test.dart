import 'dart:convert';
import 'dart:io';

import 'package:cloud_board/src/app/feature/ai_slides/data/models/ai_slide_design_model.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_design_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/slide_design_style.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/slide_editor_actions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

List<Map<String, dynamic>> referenceCases() => (jsonDecode(
  File('test/fixtures/slide_design_reference_cases.json').readAsStringSync(),
) as List).cast<Map<String, dynamic>>();

WorkoutModule referenceModule(Map<String, dynamic> fixture) {
  final poster = fixture['id'] == 'dolpa-brick';
  return WorkoutModule.empty(fixture['id'] as String).copyWith(
    name: fixture['header'] as String,
    text: (fixture['rows'] as List).join('\n'),
    designTemplate: poster ? 'studio-v1-list' : 'studio-v1-numbered',
    designHeaderLabel: fixture['programLabel'] as String? ?? '',
    designSubtitle: fixture['timingText'] as String,
    designStyle: SlideDesignStyle(
      family: poster ? 'editorial' : 'banner',
      fontFamily: poster ? 'serif' : 'sans',
      titleWeight: poster ? 700 : 900,
      motif: poster ? fixture['decorationText'] as String : '',
    ),
    designBackgroundColor: poster ? 0xFF000000 : 0xFFFFFFFF,
    designTextColor: poster ? 0xFFFFFFFF : 0xFF111111,
    designAccentColor: poster
        ? 0xFFFF0048
        : switch (fixture['id']) {
            'wod-tue' => 0xFF074679,
            'wod-wed' => 0xFF4DED00,
            'wod-thu' => 0xFF53B8F2,
            'wod-fri' || 'wod-sat' => 0xFFD30000,
            _ => 0xFFFF6800,
          },
    designFontWeight: poster ? 400 : 700,
    designItalic: false,
    showTimer: false,
    showSets: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Pretendard')
          ..addFont(
            rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'),
          )
          ..addFont(
            rootBundle.load('assets/fonts/pretendard/Pretendard-Bold.otf'),
          )
          ..addFont(
            rootBundle.load('assets/fonts/pretendard/Pretendard-Black.otf'),
          ))
        .load();
    await (FontLoader('NotoSerifKR')..addFont(
          rootBundle.load(
            'assets/fonts/noto_serif_kr/NotoSerifKR-Variable.ttf',
          ),
        ))
        .load();
  });

  test('all seven reference layouts preserve exact content, order and readable sizes', () {
    var count = 0;
    for (final fixture in referenceCases()) {
      final module = referenceModule(fixture);
      final metrics = measureSlideDesign(module);
      final rows = (fixture['rows'] as List).cast<String>();
      count += rows.length;
      expect(slideDesignError(module), isNull);
      expect(
        metrics.readable,
        isTrue,
        reason: '${module.id}: ${metrics.warning}, ${metrics.minFontSize}',
      );
      expect(
        metrics.minFontSize,
        greaterThanOrEqualTo(slideDesignMinimumFontSize),
      );
      expect(metrics.sections.expand((section) => section.lines), rows);
      expect(
        metrics.textRuns
            .where((run) => run.role == 'body')
            .map((run) => run.value),
        rows,
      );
      expect(
        metrics.textRuns.singleWhere((run) => run.role == 'title').value,
        fixture['header'],
      );
      expect(
        metrics.textRuns.singleWhere((run) => run.role == 'subtitle').value,
        fixture['timingText'],
      );
      expect(
        metrics.textRuns
            .where((run) => run.role == 'headerLabel')
            .map((run) => run.value),
        fixture['programLabel'] == null
            ? <String>[]
            : [fixture['programLabel']],
      );
      for (final run in metrics.textRuns) {
        expect(
          metrics.textBounds.contains(run.rect.topLeft),
          isTrue,
          reason: '${module.id} ${run.value}',
        );
        expect(
          run.rect.bottom,
          lessThanOrEqualTo(metrics.textBounds.bottom + .01),
        );
        expect(
          run.rect.right,
          lessThanOrEqualTo(metrics.textBounds.right + .01),
        );
      }
      if (module.id == 'dolpa-brick') {
        expect(metrics.textRuns.where((run) => run.role == 'number'), isEmpty);
        expect(
          metrics.textRuns.every((run) => run.fontFamily == 'NotoSerifKR'),
          isTrue,
        );
        expect(metrics.textRuns.map((run) => run.value), isNot(contains('突破')));
      } else {
        expect(
          metrics.textRuns.where((run) => run.role == 'number'),
          hasLength(rows.length),
        );
      }
    }
    expect(count, 36);
  });

  test('all families support repeated notes without changing saved design', () {
    final source = referenceModule(referenceCases().first);
    for (final family in slideDesignFamilies.keys) {
      final style = SlideDesignStyle(
        family: family,
        fontFamily: family == 'editorial' ? 'serif' : 'sans',
        titleWeight: 800,
      );
      final module = source.copyWith(
        designStyle: style,
        designTemplate: 'studio-v1-list',
        designHeaderLabel: 'DAY 01',
      );
      for (final text in [
        'Run 250m\nSki 250m',
        source.text,
        '## WARM UP\nRun 200m\nSquat 10\n## MAIN\nRow 500m\nLunge 20\n## FINISH\nWalk 200m',
      ]) {
        final daily = module.copyWith(text: text);
        final metrics = measureSlideDesign(daily);
        expect(metrics.readable, isTrue, reason: '$family: ${metrics.warning}');
        expect(
          metrics.sections.expand((section) => section.lines),
          parseSlideDesignSections(text).expand((section) => section.lines),
        );
        expect(daily.designStyle, style);
        expect(
          metrics.textRuns.singleWhere((run) => run.role == 'title').fontWeight,
          800,
        );
        expect(
          metrics.textRuns
              .where((run) => run.role == 'body')
              .every((run) => run.fontWeight == source.designFontWeight),
          isTrue,
        );
      }
    }
  });

  test('layout controls affect studio body layouts while preserving their design family', () {
    final source = referenceModule(referenceCases().first);
    for (final family in slideDesignFamilies.keys) {
      final module = source.copyWith(
        designStyle: SlideDesignStyle(family: family),
      );
      final columns = measureSlideDesign(
        module.copyWith(designLayout: 'columns'),
      );
      expect(columns.columns, 2);
      final cards = measureSlideDesign(module.copyWith(designLayout: 'cards'));
      expect(cards.readable, isTrue, reason: family);
      expect(cards.columns, greaterThan(1));
      expect(cards.sections.length, slideDesignLines(source.text).length);
      expect(
        cards.sections.expand((section) => section.lines),
        slideDesignLines(source.text),
      );
    }
  });

  test(
    'actual catalog previews use readable poster scale and fill the slide body',
    () {
      for (final design in aiSlideDesignCatalog) {
        final module = previewAiSlide(
          applyAiSlideTheme(aiSlideDesignSample, design.theme),
        );
        final metrics = measureSlideDesign(module);
        final body = metrics.textRuns
            .where((run) => run.role == 'body')
            .toList();
        expect(metrics.readable, isTrue, reason: design.id);
        expect(body.map((run) => run.value), aiSlideDesignSample.lines);
        expect(
          body.every((run) => run.fontSize >= 80),
          isTrue,
          reason: '${design.id} should remain legible in a catalog thumbnail',
        );
        if (module.designStyle!.family == 'cards' ||
            module.designLayout == 'cards') {
          final cards = metrics.sections;
          expect(cards, hasLength(4));
          expect(cards[0].rect.top, closeTo(cards[1].rect.top, .01));
          expect(cards[2].rect.top, closeTo(cards[3].rect.top, .01));
          expect(cards[2].rect.top, greaterThan(cards[0].rect.bottom));
          expect(cards.last.rect.bottom, greaterThan(960));
          expect(
            cards.every(
              (card) =>
                  (card.rect.height - cards.first.rect.height).abs() < .01,
            ),
            isTrue,
          );
        } else if (module.designLayout == 'columns') {
          expect(metrics.columns, 2);
          expect(metrics.sections, hasLength(2));
          expect(
            metrics.sections.first.lines,
            aiSlideDesignSample.lines.take(2),
          );
          expect(
            metrics.sections.last.lines,
            aiSlideDesignSample.lines.skip(2),
          );
          expect(
            metrics.sections.first.rect.right,
            lessThan(metrics.sections.last.rect.left),
          );
          expect(
            metrics.sections.first.rect.top,
            closeTo(metrics.sections.last.rect.top, .01),
          );
        } else {
          expect(body.last.rect.bottom, greaterThan(950));
          expect(body.last.rect.bottom - body.first.rect.top, greaterThan(540));
        }
        for (final motif in metrics.decorationRuns) {
          expect(motif.value, isNot(contains('\n')));
          expect(motif.rect.height, lessThan(motif.fontSize * 1.5));
        }
      }
      final dolpa = measureSlideDesign(referenceModule(referenceCases().last));
      expect(dolpa.decorationRuns.single.value, '突\n破');
    },
  );

  test('timer geometry is excluded from every painted content role in every family', () {
    final source = referenceModule(referenceCases().last).copyWith(
      designStyle: const SlideDesignStyle(),
      designHeaderLabel: 'CLASS',
    );
    for (final family in slideDesignFamilies.keys) {
      for (final x in [.12, .5, .87]) {
        final module = source.copyWith(
          showTimer: true,
          showSets: true,
          designStyle: SlideDesignStyle(family: family),
          appearance: SlideAppearance(
            timerX: x,
            timerY: .3,
            timerSize: 1.1,
            setsSize: 1.3,
            setsOffsetY: .2,
          ),
        );
        final metrics = measureSlideDesign(module);
        final exclusion = slideTimerGeometry(
          module,
          SlideDesignPainter.size,
        ).exclusion!;
        expect(metrics.timerExclusion, exclusion);
        expect(metrics.textBounds.overlaps(exclusion), isFalse);
        for (final run in metrics.textRuns) {
          expect(
            run.rect.overlaps(exclusion),
            isFalse,
            reason: '$family, $x: ${run.role} ${run.value}',
          );
        }
      }
    }
  });

  test('dense content warns without deleting or reordering any source row', () {
    final rows = List.generate(
      24,
      (i) => 'Exercise ${i + 1} ${List.filled(15, 'LONG').join(' ')}',
    );
    for (final family in slideDesignFamilies.keys) {
      final module = referenceModule(referenceCases().first).copyWith(
        text: rows.join('\n'),
        designStyle: SlideDesignStyle(family: family),
        showTimer: true,
        showSets: true,
      );
      final metrics = measureSlideDesign(module);
      expect(metrics.readable, isFalse);
      expect(
        metrics.textRuns
            .where((run) => run.role == 'body')
            .map((run) => run.value),
        rows,
      );
      expect(metrics.sections.expand((section) => section.lines), rows);
    }
  });

  test('studio styles and display metadata roundtrip and do not change legacy defaults', () {
    final module = referenceModule(referenceCases().last).copyWith(
      designStyle: const SlideDesignStyle(
        family: 'editorial',
        fontFamily: 'serif',
        titleColor: 0xFFFF0048,
        titleWeight: 700,
        motif: '突破',
      ),
    );
    final json = WorkoutModuleModel.fromEntity(module).toJson();
    expect(WorkoutModuleModel.fromJson(json).toEntity(), module);
    expect(
      SlideDesignStyle.fromJson(module.designStyle!.toJson()),
      module.designStyle,
    );
    expect(SlideDesignStyle.fromJson({}), const SlideDesignStyle());
    for (final name in ['designStyle', 'designHeaderLabel', 'designSubtitle']) {
      json.remove(name);
    }
    final legacy = WorkoutModuleModel.fromJson(json).toEntity();
    expect(legacy.designStyle, isNull);
    expect(legacy.designHeaderLabel, isEmpty);
    expect(legacy.designSubtitle, isEmpty);
    expect(slideDesigns, hasLength(3));
    expect(legacySlideDesigns, hasLength(3));
    expect(slideDesignOptions(module), studioSlideDesigns);
    for (final kind in ['numbered', 'list', 'interval']) {
      expect(
        hasSlideDesign(module.copyWith(designTemplate: 'studio-v1-$kind')),
        isTrue,
      );
      expect(slideDesigns.containsKey('studio-v1-$kind'), isFalse);
      expect(legacySlideDesigns.containsKey('studio-v1-$kind'), isFalse);
    }
    expect(
      slideDesignError(
        module.copyWith(designStyle: const SlideDesignStyle(family: 'unknown')),
      ),
      isNotNull,
    );
    expect(
      slideDesignError(
        module.copyWith(designStyle: const SlideDesignStyle(version: 2)),
      ),
      isNotNull,
    );
  });

  test('saved studio styles transfer design while keeping lesson content and legacy styles compatible', () {
    final target = referenceModule(referenceCases().first)
        .copyWith(imageSource: 'existing-png');
    final source = referenceModule(referenceCases().last)
        .copyWith(designTemplate: null);
    final applied = applySlideStyle(target, source);
    expect(applied.designStyle, source.designStyle);
    expect(applied.designTemplate, 'studio-v1-list');
    expect(applied.designFontWeight, source.designFontWeight);
    expect(applied.name, target.name);
    expect(applied.text, target.text);
    expect(applied.designHeaderLabel, target.designHeaderLabel);
    expect(applied.designSubtitle, target.designSubtitle);
    expect(applied.imageSource, target.imageSource);
    expect(applied.workSeconds, target.workSeconds);
    final savedStyle = applySlideStyle(WorkoutModule.empty('style'), source);
    expect(savedStyle.text, isEmpty);
    expect(savedStyle.designHeaderLabel, isEmpty);
    expect(savedStyle.designSubtitle, isEmpty);
    final legacyApplied = applySlideStyle(
      target,
      WorkoutModule.empty('legacy'),
    );
    expect(legacyApplied.designStyle, target.designStyle);
    expect(legacyApplied.designTemplate, target.designTemplate);
  });

  test('unknown studio contracts retain the baked PNG instead of being reinterpreted', () async {
    final source = referenceModule(referenceCases().last)
        .copyWith(imageSource: 'https://example.com/saved.png');
    for (final style in [
      const SlideDesignStyle(version: 2),
      const SlideDesignStyle(family: 'future-family'),
      const SlideDesignStyle(fontFamily: 'future-font'),
    ]) {
      final module = source.copyWith(designStyle: style);
      expect(hasSlideDesign(module), isFalse);
      expect(slideDesignError(module), isNotNull);
      expect(await renderSlideDesign(module), source.imageSource);
      expect(await prepareSlideDesign(module), module);
      expect(
        WorkoutModuleModel.fromJson(
          WorkoutModuleModel.fromEntity(module).toJson(),
        ).toEntity(),
        module,
      );
    }
  });

  test('accent-colored display copy stays visible when the accent matches its background', () {
    for (final family in slideDesignFamilies.keys) {
      final module = referenceModule(referenceCases().first).copyWith(
        designStyle: SlideDesignStyle(family: family),
        designBackgroundColor: 0xFFFFFFFF,
        designTextColor: 0xFF111111,
        designAccentColor: 0xFFFFFFFF,
        text: '## WARM UP\nRun 200m\n## MAIN\nRow 500m',
      );
      final metrics = measureSlideDesign(module);
      final displayCopy = metrics.textRuns.where(
        (run) => run.role == 'subtitle' || run.role == 'section',
      );
      expect(displayCopy, isNotEmpty);
      expect(
        displayCopy.every((run) => run.color == 0xFF111111),
        isTrue,
        reason: family,
      );
    }
  });

  testWidgets(
    'studio export uses the same plan and invalidates every new visual input',
    (tester) async {
      await tester.runAsync(() async {
        final module = referenceModule(referenceCases().last);
        final original = await renderSlideDesign(module);
        final decoded = img.decodePng(base64Decode(original.split(',').last))!;
        expect([decoded.width, decoded.height], [1920, 1080]);
        expect(
          await renderSlideDesign(
            module.copyWith(id: 'next', workSeconds: 240),
          ),
          original,
        );
        for (final changed in [
          module.copyWith(designLayout: 'cards'),
          module.copyWith(designSubtitle: '9mins On / 2mins Off'),
          module.copyWith(designHeaderLabel: 'SATURDAY'),
          module.copyWith(
            designStyle: module.designStyle!.copyWith(titleColor: 0xFF77CCFF),
          ),
          module.copyWith(
            designStyle: module.designStyle!.copyWith(titleWeight: 900),
          ),
          module.copyWith(designStyle: module.designStyle!.copyWith(motif: '')),
          module.copyWith(
            designStyle: module.designStyle!.copyWith(fontFamily: 'sans'),
          ),
        ]) {
          expect(
            await renderSlideDesign(changed) == original,
            isFalse,
            reason:
                'Visual change was not reflected: ${changed.designStyle?.toJson()}, ${changed.designHeaderLabel}, ${changed.designSubtitle}',
          );
        }
        final familyImages = <String>{};
        for (final family in slideDesignFamilies.keys) {
          familyImages.add(
            await renderSlideDesign(
              module.copyWith(
                designStyle: module.designStyle!.copyWith(family: family),
              ),
            ),
          );
        }
        expect(familyImages.length, 4);
        final exported = await prepareSlideDesign(module);
        expect(exported.imageSource, original);
        expect(exported.appearance.showTitle, isFalse);
        expect(exported.appearance.showBody, isFalse);
        expect(exported.designStyle, module.designStyle);
        if (const bool.fromEnvironment('AI_SLIDES_CAPTURE')) {
          for (final design in aiSlideDesignCatalog) {
            final value = previewAiSlide(
              applyAiSlideTheme(aiSlideDesignSample, design.theme),
            );
            final source = await renderSlideDesign(value);
            final bytes = base64Decode(source.split(',').last);
            await File('/tmp/cloudboard-studio-${design.id}.png')
                .writeAsBytes(bytes);
            final decoded = img.decodePng(bytes)!;
            await File(
              '/tmp/cloudboard-studio-${design.id}-thumb.png',
            ).writeAsBytes(img.encodePng(img.copyResize(decoded, width: 480)));
          }

          for (final (path, reference, prefix, lesson) in [
            (
              '/tmp/cloudboard-dolpa-style.json',
              true,
              'dolpa-actual-ai',
              module,
            ),
            (
              '/tmp/cloudboard-design-proposals.json',
              false,
              'actual-proposal',
              referenceModule(referenceCases().first),
            ),
          ]) {
            final probeFile = File(path);
            if (!probeFile.existsSync()) continue;
            final result = parseAiSlideDesignResult({
              'result': jsonDecode(probeFile.readAsStringSync()),
            }, reference: reference);
            for (final (index, design) in result.designs.indexed) {
              // Exercise the actual API adapter, persisted template DTO, theme
              // application, preview conversion and PNG renderer together.
              final saved = AiSlideDesignModel.fromJson(
                AiSlideDesignModel.fromEntity(design).toJson(),
              ).toEntity(design.id);
              final draft = AiSlideDraft(
                title: lesson.name,
                layout: 'numbered',
                lines: slideDesignLines(lesson.text),
                designHeaderLabel: lesson.designHeaderLabel,
                designSubtitle: lesson.designSubtitle,
                showTimer: false,
              );
              final value = previewAiSlide(
                applyAiSlideTheme(draft, saved.theme),
              );
              final metrics = measureSlideDesign(value);
              expect(
                metrics.readable,
                isTrue,
                reason: '$prefix-$index: ${metrics.warning}',
              );
              expect(
                metrics.textRuns
                    .where((run) => run.role == 'body')
                    .map((run) => run.value),
                draft.lines,
              );
              final source = await renderSlideDesign(value);
              await File(
                '/tmp/cloudboard-studio-$prefix${reference ? '' : '-$index'}.png',
              ).writeAsBytes(base64Decode(source.split(',').last));
            }
          }
          for (final fixture in referenceCases()) {
            final value = referenceModule(fixture);
            final source = await renderSlideDesign(value);
            await File('/tmp/cloudboard-studio-${value.id}.png')
                .writeAsBytes(base64Decode(source.split(',').last));
          }
          for (final family in slideDesignFamilies.keys) {
            final value = referenceModule(referenceCases().first).copyWith(
              designStyle: SlideDesignStyle(
                family: family,
                fontFamily: family == 'editorial' ? 'serif' : 'sans',
              ),
              designTemplate: 'studio-v1-list',
              designBackgroundColor: null,
              designTextColor: null,
            );
            final source = await renderSlideDesign(value);
            await File('/tmp/cloudboard-studio-family-$family.png')
                .writeAsBytes(base64Decode(source.split(',').last));
          }
        }
      });
    },
  );
}
