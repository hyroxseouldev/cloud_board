import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';

typedef _EditableSection = ({int id, String heading, String body});

/// Edits structured text without exposing serialization markers. Raw local
/// buffers retain blank lines and composing/cursor state across parent echoes.
class SlideDesignSectionEditor extends HookWidget {
  const SlideDesignSectionEditor({
    super.key,
    required this.text,
    required this.onChanged,
    this.keyPrefix = 'slide-section',
  });

  final String text;
  final ValueChanged<String> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final nextId = useRef(0);
    List<_EditableSection> decode(String value) {
      final parsed = parseSlideDesignSections(value);
      if (parsed.isEmpty) {
        return [(id: nextId.value++, heading: '', body: '')];
      }
      return [
        for (final section in parsed)
          (
            id: nextId.value++,
            heading: section.heading,
            body: section.lines.join('\n'),
          ),
      ];
    }

    final initial = useMemoized(() => decode(text), const []);
    final sections = useState(initial);
    final lastEmitted = useRef<String?>(null);
    useEffect(() {
      if (text != lastEmitted.value) sections.value = decode(text);
      // An emitted echo is only special once. Undo may later revisit exactly
      // the same serialized text and still needs to replace the local buffers.
      lastEmitted.value = null;
      return null;
    }, [text]);

    void emit(List<_EditableSection> updated) {
      sections.value = updated;
      final serialized = serializeSlideDesignSections(
        updated.map(
          (section) =>
              (heading: section.heading, lines: section.body.split('\n')),
        ),
      );
      lastEmitted.value = serialized;
      onChanged(serialized);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, section) in sections.value.indexed)
          _SectionFields(
            key: ValueKey('$keyPrefix-node-${section.id}'),
            keyPrefix: keyPrefix,
            index: index,
            heading: section.heading,
            body: section.body,
            onDelete: sections.value.length > 1
                ? () => emit([...sections.value]..removeAt(index))
                : null,
            onChanged: (heading, body) {
              final updated = [...sections.value];
              updated[index] = (id: section.id, heading: heading, body: body);
              emit(updated);
            },
          ),
        OutlinedButton.icon(
          key: ValueKey('$keyPrefix-add'),
          onPressed: sections.value.length >= 12
              ? null
              : () => emit([
                  ...sections.value,
                  (id: nextId.value++, heading: '', body: ''),
                ]),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('섹션 추가'),
        ),
      ],
    );
  }
}

class _SectionFields extends HookWidget {
  const _SectionFields({
    super.key,
    required this.keyPrefix,
    required this.index,
    required this.heading,
    required this.body,
    required this.onChanged,
    this.onDelete,
  });
  final String keyPrefix, heading, body;
  final int index;
  final void Function(String heading, String body) onChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final headingController = useTextEditingController(text: heading);
    final bodyController = useTextEditingController(text: body);
    useEffect(() {
      for (final (controller, value) in [
        (headingController, heading),
        (bodyController, body),
      ]) {
        if (controller.text != value) {
          controller.value = TextEditingValue(
            text: value,
            selection: TextSelection.collapsed(
              offset: controller.selection.extentOffset.clamp(0, value.length),
            ),
          );
        }
      }
      return null;
    }, [heading, body]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '섹션 ${index + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (onDelete != null)
                    IconButton(
                      key: ValueKey('$keyPrefix-$index-delete'),
                      tooltip: '섹션 ${index + 1} 삭제',
                      onPressed: onDelete,
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                ],
              ),
              TextField(
                key: ValueKey('$keyPrefix-$index-heading'),
                controller: headingController,
                maxLength: slideDesignMaxLineLength,
                decoration: const InputDecoration(
                  labelText: '섹션 제목',
                  hintText: '예: WARM UP',
                ),
                onChanged: (value) => onChanged(value, bodyController.text),
              ),
              const SizedBox(height: 8),
              TextField(
                key: ValueKey('$keyPrefix-$index-lines'),
                controller: bodyController,
                minLines: 2,
                maxLines: 8,
                maxLength: slideDesignMaxTextLength,
                decoration: const InputDecoration(
                  labelText: '운동 목록',
                  alignLabelWithHint: true,
                ),
                onChanged: (value) => onChanged(headingController.text, value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
