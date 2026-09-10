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
            icon: Icon(Icons.palette, color: color.value),
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
    final wheelSize = (MediaQuery.sizeOf(context).height - 420).clamp(
      170.0,
      230.0,
    );
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
    return AlertDialog(
      title: const Text('색상 선택'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: hsv.value.toColor(),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                colorHex(hsv.value.toColor().toARGB32()),
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (recent.value.isNotEmpty) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '최근 색상',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: recent.value
                        .map(
                          (value) => _RecentColorButton(
                            value: value,
                            selected:
                                colorHex(hsv.value.toColor().toARGB32()) ==
                                value,
                            onPressed: () => hsv.value = HSVColor.fromColor(
                              Color(parseHexColor(value)!),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _HueSaturationWheel(
                size: wheelSize,
                value: hsv.value,
                onChanged: (value) => hsv.value = value,
              ),
              const SizedBox(height: 12),
              _ColorSlider(
                label: '색조',
                value: hsv.value.hue,
                max: 360,
                onChanged: (value) => hsv.value = hsv.value.withHue(value),
              ),
              _ColorSlider(
                label: '채도',
                value: hsv.value.saturation,
                onChanged: (value) =>
                    hsv.value = hsv.value.withSaturation(value),
              ),
              _ColorSlider(
                label: '명도',
                value: hsv.value.value,
                onChanged: (value) => hsv.value = hsv.value.withValue(value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, hsv.value.toColor()),
          child: const Text('선택'),
        ),
      ],
    );
  }
}

class _RecentColorButton extends StatelessWidget {
  const _RecentColorButton({
    required this.value,
    required this.selected,
    required this.onPressed,
  });

  final String value;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '최근 색상 $value',
      child: Tooltip(
        message: value,
        child: InkWell(
          key: ValueKey('recent-color-$value'),
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
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

class _HueSaturationWheel extends StatelessWidget {
  const _HueSaturationWheel({
    required this.size,
    required this.value,
    required this.onChanged,
  });

  final double size;
  final HSVColor value;
  final ValueChanged<HSVColor> onChanged;

  void _update(Offset position, Size size) {
    final center = size.center(Offset.zero);
    final delta = position - center;
    final radius = size.shortestSide / 2;
    final saturation = (delta.distance / radius).clamp(0.0, 1.0);
    final radians = math.atan2(delta.dy, delta.dx);
    final hue = ((radians * 180 / math.pi) + 360) % 360;
    onChanged(value.withHue(hue).withSaturation(saturation));
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '색상 휠',
    value: colorHex(value.toColor().toARGB32()),
    child: Center(
      child: SizedBox.square(
        dimension: size,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            return GestureDetector(
              key: const ValueKey('color-wheel'),
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _update(details.localPosition, size),
              onPanStart: (details) => _update(details.localPosition, size),
              onPanUpdate: (details) => _update(details.localPosition, size),
              child: CustomPaint(painter: _HueSaturationWheelPainter(value)),
            );
          },
        ),
      ),
    ),
  );
}

class _HueSaturationWheelPainter extends CustomPainter {
  const _HueSaturationWheelPainter(this.value);

  final HSVColor value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Colors.red,
            Colors.yellow,
            Colors.green,
            Colors.cyan,
            Colors.blue,
            Colors.purple,
            Colors.red,
          ],
        ).createShader(bounds),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Colors.white, Color(0x00FFFFFF)],
        ).createShader(bounds),
    );

    final angle = value.hue * math.pi / 180;
    final marker =
        center +
        Offset(math.cos(angle), math.sin(angle)) * (radius * value.saturation);
    canvas.drawCircle(marker, 9, Paint()..color = Colors.black54);
    canvas.drawCircle(
      marker,
      7,
      Paint()
        ..color = value.toColor()
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      marker,
      7,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_HueSaturationWheelPainter oldDelegate) =>
      oldDelegate.value != value;
}
