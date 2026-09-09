import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:cloud_board/src/app/core/utils/hex_color.dart';

class HexColorField extends HookWidget {
  const HexColorField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
  });
  final String label, initialValue;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: initialValue);
    final color = useState(Color(parseHexColor(initialValue) ?? 0xFFFFFFFF));
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
                builder: (_) => _ColorPicker(initial: color.value),
              );
              if (selected == null || !context.mounted) return;
              color.value = selected;
              controller.text = colorHex(selected.toARGB32());
              onChanged(controller.text);
            },
          ),
        ),
        validator: (value) =>
            isHexColor(value ?? '') ? null : '#RRGGBB 형식으로 입력해 주세요.',
        onChanged: (value) {
          final parsed = parseHexColor(value);
          if (parsed != null) color.value = Color(parsed);
          onChanged(value);
        },
      ),
    );
  }
}

class _ColorPicker extends HookWidget {
  const _ColorPicker({required this.initial});
  final Color initial;
  @override
  Widget build(BuildContext context) {
    final hsv = useState(HSVColor.fromColor(initial));
    return AlertDialog(
      title: const Text('색상 선택'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 56, color: hsv.value.toColor()),
            const SizedBox(height: 12),
            Text(colorHex(hsv.value.toColor().toARGB32())),
            const Text('색조'),
            Slider(
              value: hsv.value.hue,
              max: 360,
              onChanged: (v) => hsv.value = hsv.value.withHue(v),
            ),
            const Text('채도'),
            Slider(
              value: hsv.value.saturation,
              onChanged: (v) => hsv.value = hsv.value.withSaturation(v),
            ),
            const Text('명도'),
            Slider(
              value: hsv.value.value,
              onChanged: (v) => hsv.value = hsv.value.withValue(v),
            ),
          ],
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
