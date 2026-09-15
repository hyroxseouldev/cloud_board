import 'package:cloud_board/src/app/core/theme/app_dialog_theme.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:cloud_board/src/app/core/services/recent_color_store.dart';
import 'package:cloud_board/src/app/core/utils/hex_color.dart';

class HexColorField extends HookWidget {
  const HexColorField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.recentColorStore,
  });
  final String label, initialValue;
  final ValueChanged<String> onChanged;
  final RecentColorStore? recentColorStore;
  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: initialValue);
    final color = useState(Color(parseHexColor(initialValue) ?? 0xFFFFFFFF));
    useEffect(() {
      if (controller.text != initialValue) {
        controller.value = TextEditingValue(
          text: initialValue,
          selection: TextSelection.collapsed(offset: initialValue.length),
        );
        color.value = Color(parseHexColor(initialValue) ?? 0xFFFFFFFF);
      }
      return null;
    }, [initialValue]);
    final store = useMemoized(
      () => recentColorStore ?? RecentColorStore.local(),
      [recentColorStore],
    );

    Future<void> remember(String value) async {
      try {
        await store.add(value);
      } on Object {
        // Applying a color should still work if local preferences are unavailable.
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: '#RRGGBB',
          prefixIcon: IconButton(
            tooltip: '$label 컬러 피커',
            icon: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color.value,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            onPressed: () async {
              final selected = await showDialog<Color>(
                context: context,
                builder: (_) =>
                    _ColorPicker(initial: color.value, recentColors: store),
              );
              if (selected == null || !context.mounted) return;
              color.value = selected;
              controller.text = colorHex(selected.toARGB32());
              onChanged(controller.text);
              unawaited(remember(controller.text));
            },
          ),
        ),
        validator: (value) =>
            isHexColor(value ?? '') ? null : '#RRGGBB 형식으로 입력해 주세요.',
        onChanged: (value) {
          final parsed = parseHexColor(value);
          if (parsed != null) {
            color.value = Color(parsed);
            unawaited(remember(value));
          }
          onChanged(value);
        },
      ),
    );
  }
}

class _ColorPicker extends HookWidget {
  const _ColorPicker({required this.initial, required this.recentColors});
  final Color initial;
  final RecentColorStore recentColors;
  @override
  Widget build(BuildContext context) {
    final hsv = useState(HSVColor.fromColor(initial));
    final recent = useState<List<String>>(const []);
    final wheelSize = math
        .min(
          MediaQuery.sizeOf(context).width - 140,
          MediaQuery.sizeOf(context).height - 400,
        )
        .clamp(180.0, 260.0);
    useEffect(() {
      var active = true;
      recentColors
          .load()
          .then((colors) {
            if (active) recent.value = colors;
          })
          .catchError((_) {});
      return () => active = false;
    }, [recentColors]);
    final theme = Theme.of(context);
    final selectedColor = hsv.value.toColor();
    return Dialog(
      backgroundColor: AppDialogTheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: AppDialogTheme.shape,
      insetPadding: AppDialogTheme.insetPadding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 410),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '색상 선택',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '취소',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const Text(
                      '기본색',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: SizedBox(
                        width: 272,
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            for (final entry in const {
                              '#FFFFFF': '흰색',
                              '#000000': '검정',
                              '#808080': '회색',
                              '#FF0000': '빨강',
                              '#FF8000': '주황',
                              '#FFFF00': '노랑',
                              '#00A651': '초록',
                              '#0066FF': '파랑',
                              '#8000FF': '보라',
                              '#FF69B4': '분홍',
                            }.entries)
                              _RecentColorButton(
                                value: entry.key,
                                label: '기본색 ${entry.value}',
                                keyPrefix: 'basic-color',
                                selected:
                                    colorHex(selectedColor.toARGB32()) ==
                                    entry.key,
                                onPressed: () => hsv.value = HSVColor.fromColor(
                                  Color(parseHexColor(entry.key)!),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _HueSaturationValuePicker(
                      size: wheelSize,
                      value: hsv.value,
                      onChanged: (value) => hsv.value = value,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: selectedColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          colorHex(selectedColor.toARGB32()),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ExpansionTile(
                      title: const Text(
                        '세부 조정',
                        style: TextStyle(fontSize: 13),
                      ),
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      shape: const Border(),
                      collapsedShape: const Border(),
                      children: [
                        _ColorSlider(
                          label: '명도',
                          value: hsv.value.value,
                          onChanged: (value) =>
                              hsv.value = hsv.value.withValue(value),
                        ),
                        _ColorSlider(
                          label: '색조',
                          value: hsv.value.hue,
                          max: 360,
                          onChanged: (value) =>
                              hsv.value = hsv.value.withHue(value),
                        ),
                        _ColorSlider(
                          label: '채도',
                          value: hsv.value.saturation,
                          onChanged: (value) =>
                              hsv.value = hsv.value.withSaturation(value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '최근 색상',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (recent.value.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '선택한 색상이 여기에 표시됩니다.',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          for (final value in recent.value)
                            _RecentColorButton(
                              value: value,
                              selected:
                                  colorHex(selectedColor.toARGB32()) == value,
                              onPressed: () => hsv.value = HSVColor.fromColor(
                                Color(parseHexColor(value)!),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: SizedBox(
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppDialogTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, hsv.value.toColor()),
                  child: const Text(
                    '선택',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentColorButton extends StatelessWidget {
  const _RecentColorButton({
    required this.value,
    required this.selected,
    required this.onPressed,
    this.label,
    this.keyPrefix = 'recent-color',
  });

  final String? label;
  final String keyPrefix;
  final String value;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label ?? '최근 색상 $value',
      child: Tooltip(
        message: label == null ? value : '$label $value',
        child: InkWell(
          key: ValueKey('$keyPrefix-$value'),
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: selected ? 3 : 1,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(parseHexColor(value)!),
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: selected
                  ? Icon(
                      Icons.check_rounded,
                      size: 20,
                      color:
                          Color(parseHexColor(value)!).computeLuminance() > .4
                          ? Colors.black
                          : Colors.white,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorSlider extends StatelessWidget {
  const _ColorSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    this.max = 1,
  });

  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 38, child: Text(label)),
      Expanded(
        child: Slider(
          value: value,
          max: max,
          label: max == 360 ? '${value.round()}°' : '${(value * 100).round()}%',
          onChanged: onChanged,
        ),
      ),
    ],
  );
}

class _HueSaturationValuePicker extends HookWidget {
  const _HueSaturationValuePicker({
    required this.size,
    required this.value,
    required this.onChanged,
  });
  final double size;
  final HSVColor value;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) {
    final draggingHue = useRef(false);
    final squareSize = (size / 2 - 34) * math.sqrt2;
    void updateHue(Offset position) {
      final delta = position - Offset(size / 2, size / 2);
      final hue = (math.atan2(delta.dy, delta.dx) * 180 / math.pi + 360) % 360;
      onChanged(value.withHue(hue));
    }

    void updateSquare(Offset position) {
      onChanged(
        value
            .withSaturation((position.dx / squareSize).clamp(0, 1))
            .withValue((1 - position.dy / squareSize).clamp(0, 1)),
      );
    }

    return Center(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Semantics(
              label: '색조 색상환',
              value: '${value.hue.round()}도',
              child: GestureDetector(
                key: const ValueKey('color-wheel'),
                behavior: HitTestBehavior.opaque,
                onPanDown: (details) {
                  final distance =
                      (details.localPosition - Offset(size / 2, size / 2))
                          .distance;
                  draggingHue.value =
                      distance >= size / 2 - 28 && distance <= size / 2;
                  if (draggingHue.value) updateHue(details.localPosition);
                },
                onPanUpdate: (details) {
                  if (draggingHue.value) updateHue(details.localPosition);
                },
                onPanEnd: (_) => draggingHue.value = false,
                onPanCancel: () => draggingHue.value = false,
                child: CustomPaint(
                  size: Size.square(size),
                  painter: _HueRingPainter(value),
                ),
              ),
            ),
            Semantics(
              label: '채도와 명도',
              value:
                  '채도 ${(value.saturation * 100).round()}%, 명도 ${(value.value * 100).round()}%',
              child: GestureDetector(
                key: const ValueKey('color-saturation-value'),
                behavior: HitTestBehavior.opaque,
                onPanDown: (details) => updateSquare(details.localPosition),
                onPanUpdate: (details) => updateSquare(details.localPosition),
                child: CustomPaint(
                  size: Size.square(squareSize),
                  painter: _SaturationValuePainter(value),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HueRingPainter extends CustomPainter {
  const _HueRingPainter(this.value);
  final HSVColor value;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 12;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..shader = SweepGradient(
          colors: [
            for (var hue = 0; hue <= 360; hue += 60)
              HSVColor.fromAHSV(1, hue.toDouble(), 1, 1).toColor(),
          ],
        ).createShader(Offset.zero & size),
    );
    final angle = value.hue * math.pi / 180;
    final marker = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    _paintMarker(
      canvas,
      marker,
      HSVColor.fromAHSV(1, value.hue, 1, 1).toColor(),
    );
  }

  @override
  bool shouldRepaint(_HueRingPainter oldDelegate) =>
      oldDelegate.value.hue != value.hue;
}

class _SaturationValuePainter extends CustomPainter {
  const _SaturationValuePainter(this.value);
  final HSVColor value;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white,
            HSVColor.fromAHSV(1, value.hue, 1, 1).toColor(),
          ],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.black26,
    );
    _paintMarker(
      canvas,
      Offset(value.saturation * size.width, (1 - value.value) * size.height),
      value.toColor(),
    );
  }

  @override
  bool shouldRepaint(_SaturationValuePainter oldDelegate) =>
      oldDelegate.value != value;
}

void _paintMarker(Canvas canvas, Offset position, Color color) {
  canvas.drawCircle(position, 9, Paint()..color = Colors.black87);
  canvas.drawCircle(position, 7, Paint()..color = color);
  canvas.drawCircle(
    position,
    7,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
}
