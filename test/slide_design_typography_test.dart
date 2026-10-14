import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_design_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/slide_design_style.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutModule shortSlide(String family) =>
    WorkoutModule.empty('short').copyWith(
      name: 'WARM UP',
      text: 'Squat 10\nRun 200m\nWalk 30s',
      designTemplate: 'studio-v1-list',
      designStyle: SlideDesignStyle(family: family, titleWeight: 700),
      designSubtitle: '6 min ON / 90 sec OFF',
      designHeaderLabel: 'CLASS',
      designFontWeight: 700,
      designItalic: false,
      showTimer: false,
      showSets: false,
    );

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

  test('all four families use smaller role sizes at 1920 by 1080', () {
    for (final entry in {
      'banner': 84.0,
      'focus': 94.0,
      'editorial': 110.0,
      'cards': 76.0,
    }.entries) {
      final metrics = measureSlideDesign(shortSlide(entry.key));
      expect(metrics.readable, isTrue, reason: entry.key);
      expect(
        metrics.textRuns.singleWhere((r) => r.role == 'title').fontSize,
        entry.value,
      );
      expect(
        metrics.textRuns.singleWhere((r) => r.role == 'subtitle').fontSize,
        entry.key == 'cards' ? 44 : 48,
      );
      expect(
        metrics.textRuns.singleWhere((r) => r.role == 'headerLabel').fontSize,
        entry.key == 'banner' ? 40 : 38,
      );
      expect(
        metrics.textRuns.where((r) => r.role == 'body').map((r) => r.fontSize),
        everyElement(entry.key == 'cards' ? 86 : 92),
      );
      expect(metrics.textRuns.map((r) => r.italic), everyElement(isFalse));
    }
  });

  test('all 12 catalog samples retain text and obey role caps and explicit defaults', () {
    expect(aiSlideDesignCatalog, hasLength(12));
    for (final design in aiSlideDesignCatalog) {
      final module = previewAiSlide(
        applyAiSlideTheme(aiSlideDesignSample, design.theme),
      );
      final metrics = measureSlideDesign(module);
      final body = metrics.textRuns.where((r) => r.role == 'body');
      final cardLayout =
          module.designStyle!.family == 'cards' ||
          module.designLayout == 'cards';
      expect(metrics.readable, isTrue, reason: design.id);
      expect(body.map((r) => r.value), aiSlideDesignSample.lines);
      expect(
        body.map((r) => r.fontSize),
        everyElement(inInclusiveRange(36, cardLayout ? 86 : 92)),
        reason: design.id,
      );
      expect(
        body.map((r) => r.fontWeight),
        everyElement(inInclusiveRange(600, 700)),
        reason: design.id,
      );
      expect(
        metrics.textRuns.singleWhere((r) => r.role == 'title').fontWeight,
        700,
        reason: design.id,
      );
      expect(
        body.map((r) => r.italic),
        everyElement(isFalse),
        reason: design.id,
      );
    }
  });

  test(
    'short list spacing honors the saved preference within a 48 px ceiling',
    () {
      for (final entry in {.8: 32.0, 1.0: 40.0, 1.1: 44.0, 1.5: 48.0}.entries) {
        final metrics = measureSlideDesign(
          shortSlide('banner').copyWith(designSpacing: entry.key),
        );
        final body = metrics.textRuns.where((r) => r.role == 'body').toList();
        for (var i = 1; i < body.length; i++) {
          expect(
            body[i].rect.top - body[i - 1].rect.bottom,
            closeTo(entry.value, .01),
          );
        }
        expect(body.last.rect.bottom, lessThan(metrics.textBounds.bottom - 20));
      }
    },
  );

  test('number badges shrink with the body while keeping every source row', () {
    final metrics = measureSlideDesign(
      shortSlide('banner').copyWith(designTemplate: 'studio-v1-numbered'),
    );
    final numbers = metrics.textRuns.where((r) => r.role == 'number').toList();
    final body = metrics.textRuns.where((r) => r.role == 'body').toList();
    expect(numbers.map((r) => r.value), ['1', '2', '3']);
    expect(numbers.map((r) => r.fontSize), everyElement(closeTo(69.92, .001)));
    expect(
      numbers.map((r) => r.rect.width),
      everyElement(closeTo(106.72, .001)),
    );
    for (var i = 0; i < body.length; i++) {
      expect(body[i].rect.left - numbers[i].rect.right, closeTo(28, .001));
    }
  });

  test(
    'v1 and v2 legacy paths reduce title and single or multi column caps',
    () {
      for (final version in ['v1', 'v2']) {
        for (final kind in ['list', 'numbered', 'interval']) {
          for (final layout in ['auto', 'columns', 'cards']) {
            final module = shortSlide('banner').copyWith(
              designTemplate: 'stationd-$version-$kind',
              designLayout: layout,
            );
            final metrics = measureSlideDesign(module);
            expect(metrics.readable, isTrue, reason: '$version $kind $layout');
            expect(
              metrics.textRuns.singleWhere((r) => r.role == 'title').fontSize,
              86,
            );
            expect(
              metrics.textRuns
                  .where((r) => r.role == 'body')
                  .map((r) => r.fontSize),
              everyElement(metrics.columns == 1 ? 64 : 52),
            );
            expect(metrics.sections.expand((s) => s.lines), [
              'Squat 10',
              'Run 200m',
              'Walk 30s',
            ]);
          }
        }
      }
    },
  );

  test(
    'saved weight and italic remain explicit choices in both renderer paths',
    () {
      for (final template in [
        'studio-v1-list',
        'stationd-v1-list',
        'stationd-v2-list',
      ]) {
        for (final weight in [500, 900]) {
          for (final italic in [false, true]) {
            final module = shortSlide('banner').copyWith(
              designTemplate: template,
              designFontWeight: weight,
              designItalic: italic,
              designStyle: const SlideDesignStyle(
                family: 'banner',
                titleWeight: 800,
              ),
            );
            final metrics = measureSlideDesign(module);
            final body = metrics.textRuns.where((r) => r.role == 'body');
            expect(body.map((r) => r.fontWeight), everyElement(weight));
            expect(body.map((r) => r.italic), everyElement(italic));
            final title = metrics.textRuns.singleWhere(
              (r) => r.role == 'title',
            );
            expect(title.italic, italic);
            expect(
              title.fontWeight,
              template.startsWith('studio') ? 800 : weight,
            );
            expect(module.designFontWeight, weight);
            expect(module.designItalic, italic);
          }
        }
      }
    },
  );

  test(
    'already fitted 24 rows are remeasured without a second percentage cut',
    () {
      final rows = List.generate(24, (i) => '운동 ${i + 1} · 10회');
      final module = shortSlide('banner').copyWith(
        name: '오늘의 클래스',
        text: rows.join('\n'),
        designTemplate: 'studio-v1-numbered',
        designHeaderLabel: 'DAILY TRAINING',
        designStyle: const SlideDesignStyle(family: 'banner', titleWeight: 900),
      );
      final metrics = measureSlideDesign(module);
      // Baseline 322d985, same frozen stress-studio-24 fixture: 16 px body.
      final body = metrics.textRuns.where((r) => r.role == 'body');
      expect(body.map((r) => r.value), rows);
      expect(
        body.map((r) => r.fontSize),
        everyElement(greaterThanOrEqualTo(16)),
      );
      expect(slideDesignMinimumFontSize, 36);
      expect(metrics.readable, isFalse);
      expect(metrics.warning, contains('글씨'));
    },
  );

  test('timer and set label keep baseline geometry at HD and 4K', () {
    final module = shortSlide('banner').copyWith(
      showTimer: true,
      showSets: true,
      appearance: const SlideAppearance(
        timerX: .5,
        timerY: .3,
        timerSize: 1.2,
        setsSize: 1.3,
        setsOffsetY: .2,
      ),
    );
    for (final multiplier in [1.0, 2.0]) {
      final geometry = slideTimerGeometry(
        module,
        SlideDesignPainter.size * multiplier,
      );
      expect(geometry.timer!.left, closeTo(751.2 * multiplier, .001));
      expect(geometry.timer!.top, closeTo(115.2 * multiplier, .001));
      expect(geometry.timer!.width, closeTo(417.6 * multiplier, .001));
      expect(geometry.timer!.height, closeTo(417.6 * multiplier, .001));
      expect(geometry.sets!.top, closeTo(748.8 * multiplier, .001));
      expect(geometry.sets!.height, closeTo(93.6 * multiplier, .001));
    }
    final metrics = measureSlideDesign(module);
    for (final run in metrics.textRuns) {
      expect(run.rect.overlaps(metrics.timerExclusion!), isFalse);
    }
  });
}
