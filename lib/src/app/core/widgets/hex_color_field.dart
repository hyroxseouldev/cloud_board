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
          MediaQuery.sizeOf(context).height - 450,
        )
        .clamp(140.0, 246.0);
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
                    const SizedBox(height: 14),
                    _HueSaturationWheel(
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
                    _ColorSlider(
                      label: '명도',
                      value: hsv.value.value,
                      onChanged: (value) =>
                          hsv.value = hsv.value.withValue(value),
                    ),
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
