import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Small, local vector illustrations. Labels and timing never live in the art.
enum StarterExercise {
  walk,
  shoulderCircles,
  squat,
  stepUp,
  plank,
  breathe,
  calfStretch,
  shoulderStretch,
}

/// Match only supported exercise names, not arbitrary substrings in user text.
/// Edited/unrecognised movements retain their text without a misleading pose.
StarterExercise? starterExerciseForLine(String line) {
  final name = line
      .replaceFirst(RegExp(r'^[AB]\s*·\s*'), '')
      .replaceFirst(RegExp(r'\s+\d+(회|초)$'), '')
      .trim();
  return switch (name) {
    '걷기' || '가볍게 걷기' || '제자리 걷기' => StarterExercise.walk,
    '어깨 돌리기' => StarterExercise.shoulderCircles,
    '스쿼트' || '맨몸 스쿼트' => StarterExercise.squat,
    '스텝업' => StarterExercise.stepUp,
    '플랭크' => StarterExercise.plank,
    '호흡 정리' => StarterExercise.breathe,
    '종아리 스트레칭' => StarterExercise.calfStretch,
    '어깨 스트레칭' => StarterExercise.shoulderStretch,
    _ => null,
  };
}

/// Art is drawn in a 200 × 160 field so every pose shares a visual language.
void paintStarterExercise(Canvas canvas, Rect rect, StarterExercise exercise) {
  const skin = Color(0xFFE4B89C);
  const hair = Color(0xFF2B3933);
  const shirt = Color(0xFF91A497);
  const trousers = Color(0xFF435B50);
  const shoe = Color(0xFFFFFDF8);
  const line = Color(0xFF758C7F);
  canvas.save();
  canvas.translate(rect.left, rect.top);
  canvas.scale(rect.width / 200, rect.height / 160);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 200, 160),
      const Radius.circular(18),
    ),
    Paint()..color = const Color(0xFFF0F1E9),
  );
  canvas.drawOval(
    const Rect.fromLTWH(38, 143, 126, 8),
    Paint()..color = const Color(0xFFDCE2D8),
  );

  void limb(List<Offset> points, Color color, double width) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void head(Offset center, {bool front = false}) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 21, height: 27),
        const Radius.circular(10),
      ),
      Paint()..color = skin,
    );
    final cap = Path()
      ..moveTo(center.dx - 11, center.dy + 1)
      ..cubicTo(
        center.dx - 16,
        center.dy - 20,
        center.dx + 15,
        center.dy - 20,
        center.dx + 12,
        center.dy - 4,
      )
      ..lineTo(center.dx + (front ? 2 : 6), center.dy - 8)
      ..lineTo(center.dx - 4, center.dy - 5)
      ..close();
    canvas.drawPath(cap, Paint()..color = hair);
    canvas.drawCircle(
      center + Offset(front ? -4 : 7, 0),
      1.1,
      Paint()..color = hair,
    );
    if (front) {
      canvas.drawCircle(
        center + const Offset(5, 0),
        1.1,
        Paint()..color = hair,
      );
    }
  }

  void foot(Offset heel, Offset toe) {
    limb([heel, toe], line, 10);
    limb([heel + const Offset(0, -2), toe + const Offset(0, -2)], shoe, 7);
  }

  void torso(Offset shoulder, Offset hip, {double width = 25}) {
    limb([shoulder, hip], shirt, width);
    limb([hip + const Offset(-7, 2), hip + const Offset(8, 2)], trousers, 9);
  }

  void arrow(Rect bounds, double start, double sweep) {
    canvas.drawArc(
      bounds,
      start,
      sweep,
      false,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final end = Offset(
      bounds.center.dx + bounds.width / 2 * math.cos(start + sweep),
      bounds.center.dy + bounds.height / 2 * math.sin(start + sweep),
    );
    final direction = start + sweep + (sweep > 0 ? math.pi / 2 : -math.pi / 2);
    final p = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - 7 * math.cos(direction - .5),
        end.dy - 7 * math.sin(direction - .5),
      )
      ..lineTo(
        end.dx - 7 * math.cos(direction + .5),
        end.dy - 7 * math.sin(direction + .5),
      )
      ..close();
    canvas.drawPath(p, Paint()..color = line);
  }

  switch (exercise) {
    case StarterExercise.walk:
      limb(
        [const Offset(98, 88), const Offset(84, 114), const Offset(70, 140)],
        trousers.withValues(alpha: .7),
        13,
      );
      foot(const Offset(68, 141), const Offset(79, 143));
      limb(
        [const Offset(99, 89), const Offset(114, 115), const Offset(128, 141)],
        trousers,
        14,
      );
      foot(const Offset(126, 142), const Offset(139, 142));
      limb(
        [const Offset(100, 52), const Offset(117, 76), const Offset(132, 82)],
        skin,
        8,
      );
      torso(const Offset(100, 51), const Offset(97, 88));
      limb([const Offset(95, 55), const Offset(84, 80)], shirt, 12);
      limb([const Offset(84, 80), const Offset(77, 98)], skin, 8);
      head(const Offset(104, 31));
    case StarterExercise.shoulderCircles:
      limb([const Offset(91, 100), const Offset(86, 142)], trousers, 16);
      limb([const Offset(108, 100), const Offset(115, 142)], trousers, 16);
      foot(const Offset(85, 144), const Offset(76, 144));
      foot(const Offset(114, 144), const Offset(124, 144));
      torso(const Offset(100, 57), const Offset(100, 100), width: 38);
      limb([const Offset(83, 60), const Offset(61, 73)], shirt, 14);
      limb(
        [const Offset(61, 73), const Offset(58, 45), const Offset(69, 44)],
        skin,
        9,
      );
      limb([const Offset(117, 60), const Offset(139, 73)], shirt, 14);
      limb(
        [const Offset(139, 73), const Offset(142, 45), const Offset(131, 44)],
        skin,
        9,
      );
      head(const Offset(100, 34), front: true);
      arrow(const Rect.fromLTWH(30, 42, 22, 48), 1, 3.7);
      arrow(const Rect.fromLTWH(148, 42, 22, 48), 2.1, -3.7);
    case StarterExercise.squat:
      limb(
        [const Offset(83, 94), const Offset(120, 108), const Offset(108, 140)],
        trousers.withValues(alpha: .7),
        15,
      );
      foot(const Offset(107, 142), const Offset(125, 142));
      limb(
        [const Offset(79, 96), const Offset(112, 111), const Offset(91, 140)],
        trousers,
        17,
      );
      foot(const Offset(89, 142), const Offset(106, 143));
      torso(const Offset(102, 58), const Offset(81, 93), width: 29);
      limb([const Offset(102, 62), const Offset(114, 83)], shirt, 13);
      limb([const Offset(114, 83), const Offset(129, 57)], skin, 9);
      head(const Offset(110, 38));
    case StarterExercise.stepUp:
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(112, 117, 57, 30),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFFBECBBC),
      );
      limb(
        [const Offset(91, 87), const Offset(78, 114), const Offset(71, 142)],
        trousers.withValues(alpha: .7),
        13,
      );
      foot(const Offset(68, 144), const Offset(81, 144));
      limb(
        [const Offset(94, 87), const Offset(126, 90), const Offset(129, 112)],
        trousers,
        15,
      );
      foot(const Offset(127, 114), const Offset(143, 114));
      torso(const Offset(95, 48), const Offset(91, 85));
      limb([const Offset(96, 52), const Offset(112, 71)], shirt, 12);
      limb([const Offset(112, 71), const Offset(128, 60)], skin, 8);
      head(const Offset(98, 27));
      arrow(const Rect.fromLTWH(151, 65, 18, 40), .7, -2.4);
    case StarterExercise.plank:
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(22, 133, 157, 6),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFFB5C4B6),
      );
      limb(
        [const Offset(92, 98), const Offset(65, 110), const Offset(35, 128)],
        trousers,
        15,
      );
      foot(const Offset(32, 131), const Offset(43, 131));
      torso(const Offset(134, 87), const Offset(93, 99), width: 24);
      limb([const Offset(134, 91), const Offset(138, 122)], shirt, 12);
      limb([const Offset(138, 122), const Offset(159, 128)], skin, 9);
      head(const Offset(154, 82));
    case StarterExercise.breathe:
      limb(
        [const Offset(98, 102), const Offset(66, 131), const Offset(119, 137)],
        trousers,
        16,
      );
      limb(
        [const Offset(104, 104), const Offset(136, 132), const Offset(83, 137)],
        trousers,
        16,
      );
      torso(const Offset(100, 57), const Offset(100, 101), width: 33);
      limb([const Offset(84, 62), const Offset(72, 92)], shirt, 12);
      limb([const Offset(72, 92), const Offset(93, 99)], skin, 8);
      limb([const Offset(116, 62), const Offset(127, 92)], shirt, 12);
      limb([const Offset(127, 92), const Offset(106, 99)], skin, 8);
      head(const Offset(100, 34), front: true);
      arrow(const Rect.fromLTWH(39, 59, 23, 43), 1.4, 2.8);
      arrow(const Rect.fromLTWH(140, 59, 23, 43), 1.7, -2.8);
    case StarterExercise.calfStretch:
      limb(
        [const Offset(97, 88), const Offset(73, 114), const Offset(47, 140)],
        trousers.withValues(alpha: .7),
        14,
      );
      foot(const Offset(44, 142), const Offset(60, 142));
      limb(
        [const Offset(98, 89), const Offset(123, 107), const Offset(119, 141)],
        trousers,
        15,
      );
      foot(const Offset(117, 143), const Offset(133, 143));
      torso(const Offset(113, 53), const Offset(98, 88));
      limb([const Offset(115, 57), const Offset(133, 72)], shirt, 12);
      limb([const Offset(133, 72), const Offset(157, 69)], skin, 8);
      limb(
        [const Offset(163, 34), const Offset(163, 143)],
        const Color(0xFFBCC7B9),
        4,
      );
      head(const Offset(120, 32));
    case StarterExercise.shoulderStretch:
      limb([const Offset(91, 101), const Offset(86, 142)], trousers, 15);
      limb([const Offset(108, 101), const Offset(116, 142)], trousers, 15);
      foot(const Offset(85, 144), const Offset(75, 144));
      foot(const Offset(116, 144), const Offset(127, 144));
      torso(const Offset(100, 56), const Offset(100, 100), width: 35);
      limb([const Offset(82, 60), const Offset(105, 68)], shirt, 13);
      limb([const Offset(105, 68), const Offset(134, 68)], skin, 9);
      limb([const Offset(117, 61), const Offset(118, 87)], shirt, 12);
      limb([const Offset(118, 87), const Offset(108, 63)], skin, 8);
      head(const Offset(100, 33), front: true);
  }
  canvas.restore();
}
