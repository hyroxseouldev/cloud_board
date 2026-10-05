import 'dart:convert';
import 'dart:io';

import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_design_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/data/models/workout_model.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

WorkoutModule sample() => WorkoutModule.empty('slide').copyWith(
  name: 'SATURDAY SESSION',
  text: '## WARM UP\nSquat 10 reps\nRun 200m\n## MAIN\nRow 500m\nLunge 20 reps\n## FINISHER\nBurpee 10 reps\nWalk 200m',
  designTemplate: 'stationd-v2-list',
  showTimer: false,
  showSets: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await (FontLoader('Pretendard')..addFont(
          rootBundle.load('assets/fonts/pretendard/Pretendard-Bold.otf'),
        ))
        .load();
  });

  test('section text roundtrip keeps headings, exercise order, and empty edit sections', () {
    final sections = parseSlideDesignSections(
      '## WARM UP\nRun 200m\n##\n## MAIN\nSquat 10 reps',
    );
    expect(sections, hasLength(3));
    expect(sections[1].heading, isEmpty);
    expect(sections[1].lines, isEmpty);
    expect(
      serializeSlideDesignSections(
        parseSlideDesignSections(serializeSlideDesignSections(sections)),
      ),
      '## WARM UP\nRun 200m\n##\n## MAIN\nSquat 10 reps',
    );
    expect(
      parseSlideDesignSections('Run 1km\nSki 1km').single.heading,
      isEmpty,
    );
    expect(
      serializeSlideDesignSections(
        parseSlideDesignSections('Run 1km\nSki 1km'),
      ),
      'Run 1km\nSki 1km',
    );
  });

  test('all local layouts keep named sections intact and in reading order', () {
    for (final layout in slideDesignLayouts.keys) {
      final module = sample().copyWith(designLayout: layout);
      final metrics = measureSlideDesign(module);
      expect(metrics.readable, isTrue, reason: '$layout: ${metrics.warning}');
      expect(
        metrics.minFontSize,
        greaterThanOrEqualTo(slideDesignMinimumFontSize),
      );
      expect(metrics.sections.map((s) => s.heading), [
        'WARM UP',
        'MAIN',
        'FINISHER',
      ]);
      expect(metrics.sections.map((s) => s.lines.length), [2, 2, 2]);
      for (final section in metrics.sections) {
        expect(metrics.textBounds.contains(section.rect.topLeft), isTrue);
        expect(
          section.rect.bottom,
          lessThanOrEqualTo(metrics.textBounds.bottom + 0.01),
        );
        expect(
          section.rect.right,
          lessThanOrEqualTo(metrics.textBounds.right + 0.01),
        );
      }
    }
  });

  test(
    'timer position, size, and moved set label all affect reserved bounds',
    () {
      for (final x in [0.12, 0.5, 0.87]) {
        final module = sample().copyWith(
          showTimer: true,
          showSets: true,
          appearance: SlideAppearance(
            timerX: x,
            timerY: 0.3,
            timerSize: 1.2,
            setsSize: 1.3,
            setsOffsetY: 0.3,
          ),
        );
        final geometry = slideTimerGeometry(module, SlideDesignPainter.size);
        final metrics = measureSlideDesign(module);
        expect(metrics.timerExclusion, geometry.exclusion);
        expect(metrics.textBounds.overlaps(geometry.timer!), isFalse);
        expect(metrics.textBounds.overlaps(geometry.sets!), isFalse);
        for (final section in metrics.sections) {
          expect(section.rect.overlaps(geometry.exclusion!), isFalse);
        }
      }
    },
  );

  test('overloaded content reports readability failure without deleting source lines', () {
    final lines = List.generate(
      24,
      (i) => 'Exercise ${i + 1} ${List.filled(15, 'LONG').join(' ')}',
    );
    final module = sample().copyWith(
      text: lines.join('\n'),
      showTimer: true,
      showSets: true,
    );
    final metrics = measureSlideDesign(module);
    expect(metrics.readable, isFalse);
    expect(metrics.warning, contains('글씨'));
    expect(metrics.sections.expand((section) => section.lines), lines);
    expect(
      measureSlideDesign(module.copyWith(text: '## EMPTY')).readable,
      isFalse,
    );
  });

  test('explicit timed intervals need no invented exercise text', () {
    final module = sample().copyWith(
      name: 'REST',
      text: '',
      designTemplate: 'stationd-v2-interval',
      showTimer: true,
      workSeconds: 120,
    );
    final metrics = measureSlideDesign(module);
    expect(metrics.readable, isTrue);
    expect(metrics.sections, isEmpty);
    expect(
      measureSlideDesign(module.copyWith(showTimer: false)).readable,
      isFalse,
    );
  });

  test(
    'v2 designs use three options and keep legacy v1 layouts recognizable',
    () {
      final module = sample();
      expect(slideDesignOptions(module), hasLength(3));
      for (final kind in ['numbered', 'list', 'interval']) {
        final modern = module.copyWith(designTemplate: 'stationd-v2-$kind');
        final old = module.copyWith(designTemplate: 'stationd-v1-$kind');
        expect(hasSlideDesign(modern), isTrue);
        expect(hasSlideDesign(old), isTrue);
        expect(slideDesignKind(modern), kind);
        expect(slideDesignKind(old), kind);
        expect(slideDesignOptions(old), hasLength(3));
        expect(slideDesignOptions(old).containsKey(old.designTemplate), isTrue);
        expect(
          legacySlideDesigns.containsKey(modern.designTemplate),
          isFalse,
          reason: 'An installed v1 client must fall back to the baked PNG.',
        );
        expect(measureSlideDesign(modern).readable, isTrue);
        expect(measureSlideDesign(old).readable, isTrue);
      }
      expect(
        hasSlideDesign(module.copyWith(designTemplate: 'stationd-v99-list')),
        isFalse,
      );
    },
  );

  test('new typography and layout fields roundtrip while absent legacy fields default', () {
    final module = sample().copyWith(
      designLayout: 'cards',
      designFontWeight: 600,
      designItalic: false,
      designSpacing: 1.2,
    );
    final json = WorkoutModuleModel.fromEntity(module).toJson();
    expect(WorkoutModuleModel.fromJson(json).toEntity(), module);
    for (final field in [
      'designLayout',
      'designFontWeight',
      'designItalic',
      'designSpacing',
    ]) {
      json.remove(field);
    }
    final legacy = WorkoutModuleModel.fromJson(json).toEntity();
    expect(legacy.designLayout, 'auto');
    expect(legacy.designFontWeight, 900);
    expect(legacy.designItalic, isTrue);
    expect(legacy.designSpacing, 1);
  });

  testWidgets(
    'live timer and set label use the same exclusion geometry as artwork',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = SlideDesignPainter.size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final module = sample().copyWith(
        showTimer: true,
        showSets: true,
        appearance: const SlideAppearance(
          timerX: 0.2,
          timerSize: 1.1,
          setsOffsetY: 0.15,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutSlideCanvas(
            module: module,
            isRest: false,
            secondsLeft: 60,
            remainingMs: 60000,
            durationMs: 60000,
            set: 1,
            totalSets: 1,
            isPaused: true,
            brandL: '',
            brandR: '',
            scale: 1.5,
          ),
        ),
      );
      final geometry = slideTimerGeometry(module, SlideDesignPainter.size);
      expect(
        tester.getRect(find.byKey(const ValueKey('slide-timer'))),
        geometry.timer,
      );
      final sets = tester.getRect(find.byKey(const ValueKey('slide-sets')));
      expect(geometry.sets!.inflate(1).contains(sets.center), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'v2 exports a complete PNG with duplicate legacy overlays disabled',
    (tester) async {
      await tester.runAsync(() async {
        final exported = await prepareSlideDesign(
          sample().copyWith(
            designLayout: 'cards',
            designItalic: false,
            designFontWeight: 600,
            appearance: const SlideAppearance(showTitle: true, showBody: true),
          ),
        );
        expect(exported.designTemplate, 'stationd-v2-list');
        expect(exported.imageSource, startsWith('data:image/png;base64,'));
        expect(exported.appearance.showTitle, isFalse);
        expect(exported.appearance.showBody, isFalse);
        expect(
          legacySlideDesigns.containsKey(exported.designTemplate),
          isFalse,
        );
      });
    },
  );

  testWidgets(
    'PNG artwork responds to local typography and layout changes without timer text',
    (tester) async {
      await tester.runAsync(() async {
        final module = sample();
        final original = await renderSlideDesign(module);
        if (const bool.fromEnvironment('AI_SLIDES_CAPTURE')) {
          for (final layout in slideDesignLayouts.keys) {
            final source = await renderSlideDesign(
              module.copyWith(designLayout: layout),
            );
            await File('/tmp/cloudboard-ai-slide-layout-$layout.png')
                .writeAsBytes(base64Decode(source.split(',').last));
          }
        }
        final image = img.decodePng(base64Decode(original.split(',').last))!;
        expect([image.width, image.height], [1920, 1080]);
        expect(
          await renderSlideDesign(
            module.copyWith(id: 'another', workSeconds: 120),
          ),
          original,
        );
        expect(
          await renderSlideDesign(module.copyWith(designItalic: false)),
          isNot(original),
        );
        expect(
          await renderSlideDesign(module.copyWith(designLayout: 'cards')),
          isNot(original),
        );
        expect(
          await renderSlideDesign(module.copyWith(designSpacing: 1.2)),
          isNot(original),
        );
      });
    },
  );
}
