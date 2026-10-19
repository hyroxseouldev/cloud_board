import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/center_slide_recipe.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/center_slide_flow.dart';

const centerSlideFlowMinimumOutputFontSize = 32.0;
const _overflowMessage = '읽기 좋은 글자 크기로 한 장에 담기 어려워요. 내용을 여러 슬라이드로 나눠 주세요.';

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
    canvas.clipRect(bounds, doAntiAlias: false);
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

/// Tries contiguous, balanced partitions at each allowed column count. The
/// largest readable output font wins; stack is preferred on an auto-mode tie.
/// A columns preference still allows a wider stacked fallback for long blocks.
CenterSlideFlowLayout layoutCenterSlideFlow({
  required CenterSlideRecipe recipe,
  required List<String> lines,
  required double outputScale,
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
  final maximum = math
      .min(body.fontSize * outputScale, bounds.height * outputScale / 1.2)
      .floor();
  final minimum = centerSlideFlowMinimumOutputFontSize.toInt();
  if (maximum < minimum) throw const FormatException(_overflowMessage);
  final columns = body.layout == 'stack'
      ? 1
      : math.min(body.maxColumns, sections.length);
  CenterSlideFlowLayout? best;
  CenterSlideFlowLayout? candidate;
  try {
    for (var count = 1; count <= columns; count++) {
      var low = minimum;
      var high = maximum;
      candidate = null;
      while (low <= high) {
        final size = (low + high) ~/ 2;
        final measured = _measure(
          body,
          sections,
          bounds,
          count,
          size / outputScale,
        );
        if (measured == null) {
          high = size - 1;
        } else {
          candidate?.dispose();
          candidate = measured;
          low = size + 1;
        }
      }
      if (candidate == null) continue;
      if (best == null ||
          candidate.fontSize > best.fontSize ||
          (candidate.fontSize == best.fontSize &&
              body.layout == 'columns' &&
              candidate.columns > best.columns)) {
        best?.dispose();
        best = candidate;
      } else {
        candidate.dispose();
      }
      candidate = null;
    }
    if (best == null) throw const FormatException(_overflowMessage);
    return best;
  } catch (_) {
    candidate?.dispose();
    best?.dispose();
    rethrow;
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
    final ends = _balancedPartition(
      painters.map((painter) => painter.height).toList(),
      columns,
      sectionGap,
      bounds.height,
    );
    if (ends == null) return null;
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

/// Minimax partition of ordered section heights. DP keeps order and chooses
/// deterministic early boundaries on ties, rather than splitting a section.
List<int>? _balancedPartition(
  List<double> heights,
  int columns,
  double gap,
  double maxHeight,
) {
  final count = heights.length;
  final prefix = <double>[0];
  for (final height in heights) {
    prefix.add(prefix.last + height);
  }
  double height(int start, int end) =>
      prefix[end] - prefix[start] + gap * (end - start - 1);
  final costs = List.generate(
    columns + 1,
    (_) => List<double>.filled(count + 1, double.infinity),
  );
  final previous = List.generate(
    columns + 1,
    (_) => List<int>.filled(count + 1, -1),
  );
  costs[0][0] = 0;
  for (var column = 1; column <= columns; column++) {
    for (var end = column; end <= count; end++) {
      for (var start = column - 1; start < end; start++) {
        final cost = math.max(costs[column - 1][start], height(start, end));
        if (cost < costs[column][end]) {
          costs[column][end] = cost;
          previous[column][end] = start;
        }
      }
    }
  }
  if (costs[columns][count] > maxHeight + .01) return null;
  final ends = List<int>.filled(columns, count);
  var end = count;
  for (var column = columns; column > 0; column--) {
    ends[column - 1] = end;
    end = previous[column][end];
    if (end < 0) return null;
  }
  return ends;
}
