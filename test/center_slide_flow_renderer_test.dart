import 'dart:ui' as ui;

import 'package:cloud_board/src/app/feature/ai_slides/data/renderers/center_slide_flow_renderer.dart';
import 'package:cloud_board/src/app/feature/ai_slides/data/renderers/center_slide_renderer.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/center_slide_flow.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _body = CenterSlideBody(
  x: .05,
  y: .25,
  width: .9,
  height: .65,
  fontSize: 80,
  color: 0xff111111,
  headingColor: 0xffdd5500,
  fontFamily: 'Pretendard',
);
const _recipe = CenterSlideRecipe(
  schemaVersion: 2,
  templateId: 'flow',
  revision: 1,
  centerId: 'center-one',
  width: 1920,
  height: 1080,
  backgroundColor: 0xffffffff,
  fields: [],
  body: _body,
);
final _threeSections = [
  for (final heading in ['A. Ski', 'B. Row', 'C. Bike']) ...[
    heading,
    for (var i = 0; i < 6; i++) '8 reps',
  ],
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Pretendard')..addFont(
          rootBundle.load('assets/fonts/pretendard/Pretendard-Bold.otf'),
        ))
        .load();
  });

  test(
    'auto selects larger readable three columns without splitting sections',
    () {
      final layout = layoutCenterSlideFlow(
        recipe: _recipe,
        lines: _threeSections,
        outputScale: 1,
      );
      try {
        expect(layout.columns, 3);
        expect(layout.fontSize, 80);
        expect(layout.placements.map((entry) => entry.sectionIndex), [0, 1, 2]);
        expect(layout.placements.map((entry) => entry.columnIndex), [0, 1, 2]);
        expect(
          layout.placements.map((entry) => entry.text),
          parseCenterSlideSections(_threeSections)
              .map((section) => section.text),
        );
        for (final placement in layout.placements) {
          expect(
            placement.bounds.left,
            greaterThanOrEqualTo(layout.bounds.left),
          );
          expect(placement.bounds.top, greaterThanOrEqualTo(layout.bounds.top));
          expect(
            placement.bounds.right,
            lessThanOrEqualTo(layout.bounds.right + .01),
          );
          expect(
            placement.bounds.bottom,
            lessThanOrEqualTo(layout.bounds.bottom + .01),
          );
        }
      } finally {
        layout.dispose();
      }
    },
  );

  test('stack policy preserves order and uses readable smaller type', () {
    final layout = layoutCenterSlideFlow(
      recipe: _recipe.copyWith(
        body: _body.copyWith(layout: 'stack', height: .7),
      ),
      lines: ['A. First', 'Ski', 'B. Second', 'Row', 'C. Last', 'Bike'],
      outputScale: 1,
    );
    try {
      expect(layout.columns, 1);
      expect(layout.fontSize, greaterThanOrEqualTo(32));
      expect(layout.placements.map((entry) => entry.columnIndex), [0, 0, 0]);
      expect(
        layout.placements[1].bounds.top,
        greaterThan(layout.placements[0].bounds.bottom),
      );
    } finally {
      layout.dispose();
    }
  });

  test('columns policy falls back to a full-width unsplit long block', () {
    final lines = ['A. Main', '1. Bench Press 8 reps; rest 30 seconds. ' * 4];
    final layout = layoutCenterSlideFlow(
      recipe: _recipe.copyWith(body: _body.copyWith(layout: 'columns')),
      lines: lines,
      outputScale: 1,
    );
    try {
      expect(layout.columns, 1);
      expect(layout.placements.single.text, lines.join('\n'));
      expect(layout.fontSize, greaterThanOrEqualTo(32));
    } finally {
      layout.dispose();
    }
  });

  test(
    'unreadable overflow suggests splitting and preserves source content',
    () {
      final lines = ['A. Main', 'Ski 250m', '', 'Row 250m'];
      final before = List.of(lines);
      expect(
        () => layoutCenterSlideFlow(
          recipe: _recipe.copyWith(body: _body.copyWith(height: .03)),
          lines: lines,
          outputScale: 1,
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('여러 슬라이드'),
          ),
        ),
      );
      expect(lines, before);
    },
  );

  test('v2 exports a PNG through the same creation-only renderer', () async {
    final bytes = await renderCenterSlide(
      _recipe,
      AiSlideDraft(title: 'WOD', layout: 'list', lines: _threeSections),
    );
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final image = (await codec.getNextFrame()).image;
      try {
        expect(image.width, 1920);
        expect(image.height, 1080);
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  });

  test('output-scaled minimum is 32px independent of source dimensions', () {
    final recipe = _recipe.copyWith(
      width: 3840,
      height: 2160,
      body: _body.copyWith(fontSize: 64),
    );
    final layout = layoutCenterSlideFlow(
      recipe: recipe,
      lines: ['Ski'],
      outputScale: .5,
    );
    try {
      expect(layout.fontSize * .5, 32);
    } finally {
      layout.dispose();
    }
    expect(
      () => layoutCenterSlideFlow(
        recipe: recipe.copyWith(body: recipe.body!.copyWith(fontSize: 63)),
        lines: ['Ski'],
        outputScale: .5,
      ),
      throwsFormatException,
    );
  });
}
