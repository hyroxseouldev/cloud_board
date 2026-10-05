import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';

/// Shared preview/export painter. Editing and playback never call AI.
class SlideDesignPainter extends CustomPainter {
  const SlideDesignPainter(this.module);
  final WorkoutModule module;
  static const size = Size(1920, 1080);

  @override
  void paint(Canvas canvas, Size viewport) {
    canvas.save();
    canvas.scale(viewport.width / size.width, viewport.height / size.height);
    final background = Color(module.designBackgroundColor ?? 0xFF000000);
    final foreground = Color(module.designTextColor ?? 0xFFFFFFFF);
    final accent = Color(module.designAccentColor ?? 0xFFFF343A);
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    // Reserve the right side for the independently positioned live timer.
    final width = module.showTimer ? 1180.0 : 1660.0;
    _text(canvas, module.name, Rect.fromLTWH(120, 75, width, 145), 114, accent);
    final lines = slideDesignLines(module.text);
    final numbered = module.designTemplate == 'stationd-v1-numbered';
    final interval = module.designTemplate == 'stationd-v1-interval';
    // Fill columns top-to-bottom. Long notes stay together on one slide;
    // the right-hand live timer keeps its own reserved area.
    final columns = lines.length <= 8
        ? 1
        : (module.showTimer || lines.length <= 16 ? 2 : 3);
    final rows = (lines.length / columns).ceil();
    const top = 245.0;
    final columnWidth = (width - (columns - 1) * 48) / columns;
    final rowHeight = rows == 0
        ? 0.0
        : ((1005 - top) / rows).clamp(12.0, 155.0);
    for (final (index, line) in lines.indexed) {
      final column = index ~/ rows;
      final y = top + (index % rows) * rowHeight;
      var x = 125.0 + column * (columnWidth + 48);
      final numberWidth = columns == 1 ? 92.0 : 56.0;
      final numberGap = columns == 1 ? 30.0 : 12.0;
      if (numbered) {
        final h = (rowHeight - 16).clamp(12.0, columns == 1 ? 78.0 : 52.0);
        final badgeY = y + (rowHeight - 14 - h) / 2;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, badgeY, numberWidth, h),
            const Radius.circular(10),
          ),
          Paint()..color = accent,
        );
        _text(
          canvas,
          '${index + 1}',
          Rect.fromLTWH(x + 4, badgeY + 2, numberWidth - 8, h - 4),
          columns == 1 ? 56 : 36,
          background,
          align: TextAlign.center,
        );
        x += numberWidth + numberGap;
      }
      _text(
        canvas,
        line,
        Rect.fromLTWH(
          x,
          y,
          columnWidth - (numbered ? numberWidth + numberGap : 0),
          (rowHeight - 14).clamp(8.0, 200.0),
        ),
        columns > 1 ? 52 : (interval ? 86 : 70),
        numbered || index.isEven ? accent : foreground,
      );
    }
    canvas.restore();
  }

  void _text(
    Canvas canvas,
    String value,
    Rect box,
    double fontSize,
    Color color, {
    bool italic = true,
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: align,
    );
    try {
      // Fit complete text, keeping repetitions and units visible.
      do {
        painter.text = TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            color: color,
            height: 1.12,
          ),
        );
        painter.layout(maxWidth: box.width);
        if (painter.height <= box.height || fontSize <= 8) break;
        fontSize -= 2;
      } while (true);
      painter.paint(
        canvas,
        Offset(box.left, box.top + (box.height - painter.height) / 2),
      );
    } finally {
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(SlideDesignPainter oldDelegate) =>
      module != oldDelegate.module;
}

Future<String> renderSlideDesign(WorkoutModule module) async {
  if (!hasSlideDesign(module)) return module.imageSource;
  final error = slideDesignError(module);
  if (error != null) throw FormatException(error);
  final recorder = ui.PictureRecorder();
  SlideDesignPainter(module).paint(Canvas(recorder), SlideDesignPainter.size);
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(1920, 1080);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw const FormatException('슬라이드 이미지를 만들지 못했습니다.');
      return 'data:image/png;base64,${base64Encode(bytes.buffer.asUint8List())}';
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}

Future<WorkoutModule> prepareSlideDesign(WorkoutModule module) async {
  if (!hasSlideDesign(module)) return module;
  return module.copyWith(
    imageSource: await renderSlideDesign(module),
    // Styles from older slides may enable these overlays. Keep exported images
    // readable on old clients that do not know about designTemplate.
    appearance: module.appearance.copyWith(showTitle: false, showBody: false),
  );
}
