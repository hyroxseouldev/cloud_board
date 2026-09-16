import 'package:cloud_board/src/app/core/theme/app_dialog_theme.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:cloud_board/src/app/core/services/recent_color_store.dart';
import 'package:cloud_board/src/app/core/services/saved_color_store.dart';
import 'package:cloud_board/src/app/core/utils/hex_color.dart';

class HexColorField extends HookWidget {
  const HexColorField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.recentColorStore,
    this.compact = false,
  });
  final bool compact;
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

    Future<void> pick() async {
      final selected = await showModalBottomSheet<Color>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        backgroundColor: AppDialogTheme.surface,
        constraints: const BoxConstraints(maxWidth: double.infinity),
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: _ColorPicker(initial: color.value, recentColors: store),
        ),
      );
      if (selected == null || !context.mounted) return;
      color.value = selected;
      controller.text = colorHex(selected.toARGB32());
      onChanged(controller.text);
      unawaited(remember(controller.text));
    }

    if (compact) {
      return SizedBox(
        width: 86,
        child: Tooltip(
          message: '$label ${controller.text}',
          child: InkWell(
            key: ValueKey('color-swatch-$label'),
            borderRadius: BorderRadius.circular(12),
            onTap: pick,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.value,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
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
            onPressed: pick,
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
    final saved = useState<List<String>>(SavedColorStore.initialColors);
    final savedStore = useMemoized(() => const SavedColorStore());
    final saving = useState(false);
    final paletteError = useState<String?>(null);
    final hex = useTextEditingController(text: colorHex(initial.toARGB32()));
    final hexValid = useState(true);
    void setHsv(HSVColor value) {
      hsv.value = value;
      hex.text = colorHex(value.toColor().toARGB32());
      hexValid.value = true;
    }

    void selectColor(String value) =>
        setHsv(HSVColor.fromColor(Color(parseHexColor(value)!)));

    useEffect(() {
      var active = true;
      recentColors
          .load()
          .then((colors) {
            if (active) recent.value = colors;
          })
          .catchError((_) {});
      savedStore
          .load()
          .then((colors) {
            if (active) saved.value = colors;
          })
          .catchError((_) {
            if (active) paletteError.value = '저장한 색상을 불러오지 못했습니다.';
          });
      return () => active = false;
    }, [recentColors, savedStore]);

    Future<void> updateSaved(String value, {bool remove = false}) async {
      if (saving.value) return;
      saving.value = true;
      paletteError.value = null;
      try {
        final colors = remove
            ? await savedStore.remove(value)
            : await savedStore.add(value);
        if (context.mounted) saved.value = colors;
      } catch (_) {
        if (context.mounted) {
          paletteError.value = '색상 목록을 저장하지 못했습니다. 다시 시도해 주세요.';
        }
      } finally {
        if (context.mounted) saving.value = false;
      }
    }

    final theme = Theme.of(context);
    final selectedHex = colorHex(hsv.value.toColor().toARGB32());
    final availableHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom -
        MediaQuery.paddingOf(context).top -
        64;
    return SizedBox(
      width: double.infinity,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: availableHeight.clamp(
            100.0,
            MediaQuery.sizeOf(context).height * .85,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
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
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
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
                    const SizedBox(height: 8),
                    _RectangularColorPicker(
                      value: hsv.value,
                      onChanged: setHsv,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '저장한 색상',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        FilledButton.tonalIcon(
                          key: const ValueKey('save-color-button'),
                          onPressed: hexValid.value && !saving.value
                              ? () => updateSaved(selectedHex)
                              : null,
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text(
                            '추가',
                            style: TextStyle(fontSize: 14),
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final value in saved.value)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _RecentColorButton(
                                      value: value,
                                      label: '저장한 색상 $value · 길게 눌러 삭제',
                                      keyPrefix: 'saved-color',
                                      selected: selectedHex == value,
                                      onPressed: () => selectColor(value),
                                      onLongPress: saving.value
                                          ? null
                                          : () => updateSaved(
                                              value,
                                              remove: true,
                                            ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      paletteError.value ?? '길게 누르면 저장한 색상을 삭제합니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: paletteError.value == null
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '최근 사용색',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (recent.value.isEmpty)
                      Text(
                        '적용한 색상이 최대 10개까지 표시됩니다.',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final value in recent.value)
                            _RecentColorButton(
                              value: value,
                              selected: selectedHex == value,
                              onPressed: () => selectColor(value),
                            ),
                        ],
                      ),
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const ValueKey('picker-hex-input'),
                      controller: hex,
                      decoration: InputDecoration(
                        labelText: 'HEX 색상',
                        hintText: '#RRGGBB',
                        errorText: hexValid.value
                            ? null
                            : '#RRGGBB 형식으로 입력해 주세요.',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: hsv.value.toColor(),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                      onChanged: (input) {
                        hexValid.value = isHexColor(input);
                        if (hexValid.value) {
                          hsv.value = HSVColor.fromColor(
                            Color(parseHexColor(input)!),
                          );
                        }
                      },
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
                          label: '명도',
                          value: hsv.value.value,
                          onChanged: (v) => setHsv(hsv.value.withValue(v)),
                        ),
                        _ColorSlider(
                          label: '색조',
                          value: hsv.value.hue,
                          max: 360,
                          onChanged: (v) => setHsv(hsv.value.withHue(v)),
                        ),
                        _ColorSlider(
                          label: '채도',
                          value: hsv.value.saturation,
                          onChanged: (v) => setHsv(hsv.value.withSaturation(v)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: AppDialogTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: hexValid.value
                      ? () => Navigator.pop(context, hsv.value.toColor())
                      : null,
                  child: const Text(
                    '선택',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
    this.onLongPress,
    this.keyPrefix = 'recent-color',
  });

  final String? label;
  final String keyPrefix;
  final String value;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

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
          onLongPress: onLongPress,
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

class _RectangularColorPicker extends StatelessWidget {
  const _RectangularColorPicker({required this.value, required this.onChanged});
  final HSVColor value;
  final ValueChanged<HSVColor> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        width: double.infinity,
        height: ((MediaQuery.sizeOf(context).width - 48) / 2.8).clamp(
          150.0,
          280.0,
        ),
        child: LayoutBuilder(
          builder: (context, bounds) {
            void update(Offset position) => onChanged(
              value
                  .withSaturation((position.dx / bounds.maxWidth).clamp(0, 1))
                  .withValue((1 - position.dy / bounds.maxHeight).clamp(0, 1)),
            );
            return Semantics(
              label: '채도와 명도',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GestureDetector(
                  key: const ValueKey('color-saturation-value'),
                  behavior: HitTestBehavior.opaque,
                  onPanDown: (event) => update(event.localPosition),
                  onPanUpdate: (event) => update(event.localPosition),
                  child: CustomPaint(
                    size: bounds.biggest,
                    painter: _SaturationValuePainter(value),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 24,
              right: 24,
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(
                    colors: [
                      for (var hue = 0; hue <= 360; hue += 60)
                        HSVColor.fromAHSV(1, hue.toDouble(), 1, 1).toColor(),
                    ],
                  ),
                ),
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbColor: HSVColor.fromAHSV(1, value.hue, 1, 1).toColor(),
                trackHeight: 5,
              ),
              child: Slider(
                key: const ValueKey('color-hue-slider'),
                value: value.hue,
                max: 360,
                label: '${value.hue.round()}°',
                onChanged: (hue) => onChanged(value.withHue(hue)),
              ),
            ),
          ],
        ),
      ),
    ],
  );
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
