import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/center_slide_flow.dart';

const centerSlideFlowMinimumOutputFontSize = 32.0;
const _overflowMessage =
    '선택한 글자 크기와 배치에 내용이 넘쳐요. 문구를 줄이거나 슬라이드를 나눠 주세요. 자동 맞춤은 직접 선택할 수 있어요.';

/// Caller-owned measured layout. Every section has one placement and is never
/// split between columns. [dispose] releases all native TextPainter handles.
class CenterSlideFlowLayout {
  CenterSlideFlowLayout._({
    required this.bounds,
    required this.fontSize,
    required this.columns,
    required List<CenterSlideFlowPlacement> placements,
  }) : placements = List.unmodifiable(placements);

  final Rect bounds;
  final double fontSize;
  final int columns;
  final List<CenterSlideFlowPlacement> placements;

  void paint(Canvas canvas) {
    canvas.save();

    for (final placement in placements) {
      placement._painter.paint(canvas, placement.bounds.topLeft);
    }
    canvas.restore();
  }

  void dispose() {
    for (final placement in placements) {
      placement._painter.dispose();
    }
  }
}

class CenterSlideFlowPlacement {
  const CenterSlideFlowPlacement._(
    this._painter, {
    required this.sectionIndex,
    required this.columnIndex,
    required this.text,
    required this.bounds,
  });

  final int sectionIndex;
  final int columnIndex;
  final String text;
  final Rect bounds;
  final TextPainter _painter;
}

/// A selected template keeps its columns and font size even for shorter text.
/// Only the explicit Auto fit action may reduce the body size.
CenterSlideFlowLayout layoutCenterSlideFlow({
  required CenterSlideRecipe recipe,
  required List<String> lines,
  required double outputScale,
  int? fixedColumns,
  double? fontSize,
  bool autoFit = false,
}) {
  final error = validateCenterSlideRecipe(recipe);
  if (error != null) throw FormatException(error);
  final body = recipe.body;
  if (recipe.schemaVersion != 2 ||
      body == null ||
      !outputScale.isFinite ||
      outputScale <= 0) {
    throw const FormatException('센터 템플릿의 본문 배치를 확인해 주세요.');
  }
  final sections = parseCenterSlideSections(lines);
  final bounds = Rect.fromLTWH(
    body.x * recipe.width,
    body.y * recipe.height,
    body.width * recipe.width,
    body.height * recipe.height,
  );
  final columns =
      fixedColumns ?? (body.layout == 'columns' ? body.maxColumns : 1);
  final size = fontSize ?? body.fontSize;
  if (columns < 1 ||
      columns > body.maxColumns ||
      !size.isFinite ||
      size <= 0 ||
      size > body.fontSize ||
      size * outputScale < centerSlideFlowMinimumOutputFontSize) {
    throw const FormatException(_overflowMessage);
  }
  var candidateSize = size;
  while (true) {
    final measured = _measure(body, sections, bounds, columns, candidateSize);
    if (measured != null) return measured;
    candidateSize -= 1 / outputScale;
    if (!autoFit ||
        candidateSize * outputScale < centerSlideFlowMinimumOutputFontSize) {
      throw const FormatException(_overflowMessage);
    }
  }
}

CenterSlideFlowLayout? _measure(
  CenterSlideBody body,
  List<CenterSlideSection> sections,
  Rect bounds,
  int columns,
  double fontSize,
) {
  final gutter = fontSize * .8;
  final inset = fontSize * .08;
  final sectionGap = fontSize * .45;
  final columnWidth = (bounds.width - gutter * (columns - 1)) / columns;
  final textWidth = columnWidth - inset * 2;
  if (textWidth <= 0) return null;
  final painters = <TextPainter>[];
  var retained = false;
  try {
    for (final section in sections) {
      final style = TextStyle(
        fontFamily: body.fontFamily,
        fontSize: fontSize,
        fontWeight: FontWeight.values[body.fontWeight ~/ 100 - 1],
        color: Color(body.color),
        height: 1.2,
      );
      final painter = TextPainter(
        text: TextSpan(
          style: style,
          children: [
            if (section.heading.isNotEmpty)
              TextSpan(
                text: section.heading,
                style: TextStyle(
                  color: Color(body.headingColor),
                  fontWeight: FontWeight
                      .values[math.max(700, body.fontWeight) ~/ 100 - 1],
                ),
              ),
            if (section.heading.isNotEmpty && section.lines.isNotEmpty)
              const TextSpan(text: '\n'),
            if (section.lines.isNotEmpty)
              TextSpan(
                text: section.lines.join('\n').isEmpty
                    ? ' '
                    : section.lines.join('\n'),
              ),
          ],
        ),
        textDirection: TextDirection.ltr,
        textWidthBasis: TextWidthBasis.longestLine,
      );
      painters.add(painter);
      painter.layout(maxWidth: textWidth);
      if (painter.didExceedMaxLines ||
          !painter.height.isFinite ||
          painter.computeLineMetrics().any(
            (line) => !line.width.isFinite || line.width > textWidth + .01,
          )) {
        return null;
      }
    }
    // Stable section-to-column assignment, never balanced again on keystrokes.
    final ends = List.generate(
      columns,
      (column) => column == columns - 1
          ? sections.length
          : math.min(column + 1, sections.length),
    );
    var begin = 0;
    for (final end in ends) {
      final height =
          painters
              .skip(begin)
              .take(end - begin)
              .fold<double>(0, (sum, painter) => sum + painter.height) +
          math.max(0, end - begin - 1) * sectionGap;
      if (height > bounds.height + .01) return null;
      begin = end;
    }
    final placements = <CenterSlideFlowPlacement>[];
    var start = 0;
    for (var column = 0; column < columns; column++) {
      var top = bounds.top;
      for (var index = start; index < ends[column]; index++) {
        final painter = painters[index];
        placements.add(
          CenterSlideFlowPlacement._(
            painter,
            sectionIndex: index,
            columnIndex: column,
            text: sections[index].text,
            bounds: Rect.fromLTWH(
              bounds.left + column * (columnWidth + gutter) + inset,
              top,
              painter.width,
              painter.height,
            ),
          ),
        );
        top += painter.height + sectionGap;
      }
      start = ends[column];
    }
    retained = true;
    return CenterSlideFlowLayout._(
      bounds: bounds,
      fontSize: fontSize,
      columns: columns,
      placements: placements,
    );
  } finally {
    if (!retained) {
      for (final painter in painters) {
        painter.dispose();
      }
    }
  }
}
