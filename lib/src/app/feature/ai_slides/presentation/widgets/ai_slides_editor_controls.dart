import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class AiSlidesSyncedField extends HookWidget {
  const AiSlidesSyncedField({
    super.key,
    required this.fieldKey,
    required this.value,
    required this.label,
    required this.onChanged,
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
    this.hint,
  });
  final Key fieldKey;
  final String value, label;
  final String? hint;
  final int minLines, maxLines;
  final int? maxLength;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: value);
    useEffect(() {
      if (controller.text.trim() != value.trim()) {
        controller.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(
            offset: controller.selection.extentOffset.clamp(0, value.length),
          ),
        );
      }
      return null;
    }, [value]);
    return TextField(
      key: fieldKey,
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: true,
      ),
      onChanged: onChanged,
    );
  }
}

class AiSlidesNotice extends StatelessWidget {
  const AiSlidesNotice(this.message, {super.key, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    child: Text(
      message,
      style: TextStyle(
        fontSize: 12,
        color: error
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
