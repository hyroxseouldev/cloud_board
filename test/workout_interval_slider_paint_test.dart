import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_interval_slider_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _active = AppColors.accent;
const _remaining = AppColors.selected;
const _disabled = AppColors.muted;
const _activeMarker = Color(0xffaabbcc);
const _remainingMarker = Color(0xff778899);

void main() {
  // Rasterize the real Slider and production track painter, with only its thumb
  // hidden so the exact fill boundary can be checked rather than obscured.
  for (final direction in TextDirection.values) {
    for (final fraction in [0.0, 11 / 180, .5, 1.0]) {
      for (final enabled in [true, false]) {
        testWidgets('paint $direction $fraction enabled=$enabled', (
          tester,
        ) async {
          final raster = await _render(
            tester,
            fraction: fraction,
            direction: direction,
            enabled: enabled,
          );
          expect(
            raster.track.thumbX,
            closeTo(
              raster.rect.left +
                  raster.rect.width *
                      (direction == TextDirection.ltr
                          ? fraction
                          : 1 - fraction),
              .01,
            ),
          );
          _expectFill(raster, direction, enabled ? _active : _disabled);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final direction in TextDirection.values) {
    for (final position in [12000, 15000, 18000]) {
      testWidgets('work/rest marks stay secondary at $position $direction', (
        tester,
      ) async {
        final raster = await _render(
          tester,
          fraction: position / 30000,
          direction: direction,
          maxMs: 30000,
          segments: const [
            (startMs: 0, endMs: 10000, isRest: false),
            (startMs: 10000, endMs: 15000, isRest: true),
            (startMs: 15000, endMs: 25000, isRest: false),
            (startMs: 25000, endMs: 30000, isRest: true),
          ],
        );
        for (final boundary in [10000, 15000, 25000]) {
          final x =
              raster.rect.left +
              raster.rect.width *
                  (direction == TextDirection.ltr
                      ? boundary / 30000
                      : 1 - boundary / 30000);
          // The 1px marker may straddle two pixels; require a visible change,
          // then verify that nearby pixels still express progress, not phase.
          final colors = [
            raster.color(x.floor(), raster.y),
            raster.color(x.ceil(), raster.y),
          ];
          expect(colors.any((c) => c != _active && c != _remaining), isTrue);
          for (final sample in [x.floor() - 3, x.ceil() + 3]) {
            final elapsed = direction == TextDirection.ltr
                ? sample + .5 < raster.track.thumbX
                : sample + .5 > raster.track.thumbX;
            expect(
              raster.color(sample, raster.y),
              elapsed ? _active : _remaining,
            );
          }
        }
      });
    }
  }

  testWidgets('zero duration and empty intervals paint an unfilled track', (
    tester,
  ) async {
    final raster = await _render(
      tester,
      fraction: 0,
      maxMs: 0,
      enabled: false,
      segments: const [],
    );
    _expectFill(raster, TextDirection.ltr, _disabled);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reverse seek repaints previously elapsed pixels as remaining', (
    tester,
  ) async {
    final before = await _render(tester, fraction: .8);
    final after = await _render(tester, fraction: 11 / 180);
    final middle = after.rect.center.dx.floor();
    expect(before.color(middle, before.y), _active);
    expect(after.color(middle, after.y), _remaining);
    _expectFill(after, TextDirection.ltr, _active);
  });

  testWidgets(
    'disabled transition keeps a readable split while colors animate',
    (tester) async {
      final key = GlobalKey();
      final track = _ObservedTrack(maxMs: 180000);
      await tester.pumpWidget(_slider(key, track, .5, true, TextDirection.ltr));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _slider(key, track, .5, false, TextDirection.ltr),
      );
      await tester.pump(const Duration(milliseconds: 75));
      final raster = await _raster(tester, key, track);
      final active = Color.lerp(_disabled, _active, track.enableValue)!;
      _expectFill(raster, TextDirection.ltr, active);
    },
  );
}

void _expectFill(_Raster raster, TextDirection direction, Color active) {
  for (
    var x = raster.rect.left.ceil() + 3;
    x < raster.rect.right.floor() - 3;
    x++
  ) {
    if ((x + .5 - raster.track.thumbX).abs() < 1) continue;
    final elapsed = direction == TextDirection.ltr
        ? x + .5 < raster.track.thumbX
        : x + .5 > raster.track.thumbX;
    final expected = elapsed ? active : _remaining;
    final actual = raster.color(x, raster.y);
    // Canvas may quantize interpolated float colors by one channel value.
    for (final shift in [0, 8, 16, 24]) {
      expect(
        ((actual.toARGB32() >> shift) & 255) -
            ((expected.toARGB32() >> shift) & 255),
        inInclusiveRange(-1, 1),
        reason: 'pixel $x, expected $expected; actual $actual',
      );
    }
  }
}

Future<_Raster> _render(
  WidgetTester tester, {
  required double fraction,
  TextDirection direction = TextDirection.ltr,
  bool enabled = true,
  double maxMs = 180000,
  List<WorkoutIntervalSegment> segments = const [
    (startMs: 0, endMs: 180000, isRest: false),
  ],
}) async {
  final key = GlobalKey();
  final track = _ObservedTrack(maxMs: maxMs, segments: segments);
  await tester.pumpWidget(_slider(key, track, fraction, enabled, direction));
  await tester.pumpAndSettle();
  return _raster(tester, key, track);
}

Widget _slider(
  GlobalKey key,
  _ObservedTrack track,
  double fraction,
  bool enabled,
  TextDirection direction,
) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: Directionality(
        textDirection: direction,
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 400,
            height: 48,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 6,
                trackShape: track,
                thumbShape: const _InvisibleThumb(),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                activeTrackColor: _active,
                inactiveTrackColor: _remaining,
                disabledActiveTrackColor: _disabled,
                disabledInactiveTrackColor: _remaining,
                activeTickMarkColor: _activeMarker,
                inactiveTickMarkColor: _remainingMarker,
                disabledActiveTickMarkColor: _activeMarker,
                disabledInactiveTickMarkColor: _remainingMarker,
              ),
              child: Slider(
                value: fraction,
                onChanged: enabled ? (_) {} : null,
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<_Raster> _raster(
  WidgetTester tester,
  GlobalKey key,
  _ObservedTrack track,
) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final rect = track.rect.shift(-boundary.localToGlobal(Offset.zero));
    final raster = _Raster(
      data!.buffer.asUint8List(),
      image.width,
      rect,
      track,
    );
    track.thumbX -= boundary.localToGlobal(Offset.zero).dx;
    image.dispose();
    return raster;
  }))!;
}

class _Raster {
  _Raster(this.bytes, this.width, this.rect, this.track);
  final Uint8List bytes;
  final int width;
  final Rect rect;
  final _ObservedTrack track;
  int get y => rect.center.dy.floor();
  Color color(int x, int y) {
    final i = (y * width + x) * 4;
    return Color.fromARGB(bytes[i + 3], bytes[i], bytes[i + 1], bytes[i + 2]);
  }
}

class _ObservedTrack extends WorkoutIntervalSliderTrack {
  _ObservedTrack({required super.maxMs, super.segments = const []});
  late Rect rect;
  late double thumbX;
  late double enableValue;
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    rect = getPreferredRect(
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    ).shift(parentBox.localToGlobal(Offset.zero));
    thumbX = parentBox.localToGlobal(thumbCenter - offset).dx;
    enableValue = enableAnimation.value;
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: additionalActiveTrackHeight,
    );
  }
}

// Preserve production thumb geometry: noThumb would shrink it to zero and make
// Flutter inset rounded-track endpoints, changing the behavior under test.
class _InvisibleThumb extends RoundSliderThumbShape {
  const _InvisibleThumb() : super(enabledThumbRadius: 6);
  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {}
}
