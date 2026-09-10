import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class FolderSelector extends HookWidget {
  const FolderSelector({
    super.key,
    required this.value,
    required this.folders,
    required this.onChanged,
    this.compact = false,
    this.enabled = true,
  });
  final bool compact;
  final bool enabled;
  final String value;
  final Set<String> folders;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final created = useState(<String>{});
    final revision = useState(0);
    final options = {
      ...folders,
      ...created.value,
      if (value.isNotEmpty) value,
    }.where((f) => f.isNotEmpty).toList()..sort();
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 0 : 16),
      child: DropdownButtonFormField<int>(
        key: ValueKey((value, revision.value)),
        initialValue: value.isEmpty ? -1 : options.indexOf(value),
        isExpanded: true,
        decoration: compact
            ? const InputDecoration(
                labelText: '폴더',
                filled: true,
                fillColor: Color(0xFFF5F5F9),
                isDense: true,
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              )
            : const InputDecoration(labelText: '폴더'),
        items: [
          const DropdownMenuItem(value: -1, child: Text('폴더 없음')),
          for (var i = 0; i < options.length; i++)
            DropdownMenuItem(value: i, child: Text(options[i])),
          const DropdownMenuItem(value: -2, child: Text('+ 새 폴더 추가')),
        ],
        onChanged: !enabled
            ? null
            : (index) async {
                if (index == null) return;
                if (index != -2) {
                  onChanged(index == -1 ? '' : options[index]);
                  return;
                }
                final name = await showDialog<String>(
                  context: context,
                  builder: (_) => _NewFolder(existing: options),
                );
                if (!context.mounted) return;
                revision.value++;
                if (name != null && context.mounted) {
                  created.value = {...created.value, name};
                  onChanged(name);
                }
              },
      ),
    );
  }
}

class _NewFolder extends HookWidget {
  const _NewFolder({required this.existing});
  final List<String> existing;
  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController();
    final form = useMemoized(() => GlobalKey<FormState>());
    return AlertDialog(
      title: const Text('새 폴더'),
      content: Form(
        key: form,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '폴더 이름'),
          validator: (v) {
            final name = (v ?? '').trim();
            if (name.isEmpty) return '폴더 이름을 입력해 주세요.';
            if (existing.any(
              (f) => f.trim().toLowerCase() == name.toLowerCase(),
            )) {
              return '같은 이름의 폴더가 있습니다.';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, controller.text.trim());
            }
          },
          child: const Text('추가'),
        ),
      ],
    );
  }
}
