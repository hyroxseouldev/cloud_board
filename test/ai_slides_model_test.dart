import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/models/ai_slides_model.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/slide_editor_actions.dart';

void main() {
  Map<String, dynamic> response(Map<String, dynamic> slide) => {
    'premium': true,
    'enabled': true,
    'remaining': 29,
    'limit': 30,
    'result': {
      'slides': [slide],
      'warnings': <String>[],
    },
  };
  test('structured response retains sections/units, flat installed response remains compatible', () {
    final common = {
      'title': 'CIRCUIT',
      'layout': 'list',
      'lines': ['legacy flat line'],
    };
    final draft = AiSlidesModel.fromJson(
      response({
        ...common,
        'sections': [
          {
            'heading': 'WARM UP',
            'lines': ['Squat 10 reps'],
            'sourceLineIds': [1, 2],
          },
          {
            'heading': 'MAIN',
            'lines': ['RUN 1km', 'ROW 500m'],
            'sourceLineIds': [3, 4, 5],
          },
        ],
      }),
    ).toResult().slides.single;
    final sections = parseSlideDesignSections(draft.lines.join('\n'));
    expect(sections.map((section) => section.heading), ['WARM UP', 'MAIN']);
    expect(sections.last.lines, ['RUN 1km', 'ROW 500m']);
    expect(draft.showTimer, false);
    final module = confirmAiSlide(draft, 'slide');
    expect(module.showTimer, false);
    expect(module.showSets, false);
    expect(
      AiSlidesModel.fromJson(response(common)).toResult().slides.single.lines,
      ['legacy flat line'],
    );
  });
  test('only explicit work duration initially displays the timer', () {
    final draft = AiSlidesModel.fromJson(
      response({
        'title': 'WARM UP',
        'layout': 'list',
        'lines': ['Squat 10 reps'],
        'workSeconds': 300,
        'restSeconds': 0,
        'sets': 1,
      }),
    ).toResult().slides.single;
    expect(draft.showTimer, true);
    expect(confirmAiSlide(draft, 'slide').workSeconds, 300);
  });
  test('single-slide contract rejects unexpected multiple slides', () {
    final body = response({
      'title': 'A',
      'layout': 'list',
      'lines': ['Run'],
    });
    final content = body['result'] as Map<String, Object>;
    final slides = content['slides'] as List;
    slides.add(slides.first);
    expect(
      () => AiSlidesModel.fromJson(body).toResult(),
      throwsA(isA<AiSlidesFailure>()),
    );
  });
  test('saved style application retains new typography and layout fields', () {
    const draft = AiSlideDraft(
      title: 'Warmup',
      layout: 'list',
      lines: ['Squat 10 reps'],
    );
    final original = confirmAiSlide(draft, 'original');
    final style = original.copyWith(
      designLayout: 'cards',
      designItalic: false,
      designFontWeight: 700,
      designSpacing: 1.15,
    );
    final applied = applySlideStyle(original, style);
    expect(applied.designLayout, 'cards');
    expect(applied.designFontWeight, 700);
    expect(applied.designItalic, false);
    expect(applied.designSpacing, 1.15);
    expect(applied.text, original.text);
  });
}
