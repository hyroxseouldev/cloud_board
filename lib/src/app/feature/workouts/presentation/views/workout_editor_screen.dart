import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/workout.dart';
import '../controllers/workout_controller.dart';
import 'workout_list_screen.dart';

class WorkoutEditorScreen extends ConsumerWidget {
  const WorkoutEditorScreen({super.key, required this.workoutId});
  final String workoutId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = ref.watch(workoutControllerProvider);
    return values.when(
      data: (items) {
        final workout = workoutId == 'new'
            ? Workout.empty(newId())
            : items.where((item) => item.id == workoutId).firstOrNull;
        return workout == null
            ? const Scaffold(body: Center(child: Text('워크아웃을 찾을 수 없습니다.')))
            : _EditorBody(initial: workout, isNew: workoutId == 'new');
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
    );
  }
}

class _EditorBody extends HookConsumerWidget {
  const _EditorBody({required this.initial, required this.isNew});
  final Workout initial;
  final bool isNew;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = useState(initial);
    final name = useTextEditingController(text: initial.name);
    final folder = useTextEditingController(text: initial.folder);
    final brandL = useTextEditingController(text: initial.brandL);
    final brandR = useTextEditingController(text: initial.brandR);
    Future<void> save() async {
      final value = draft.value.copyWith(
        name: name.text.trim(),
        folder: folder.text.trim(),
        brandL: brandL.text.trim(),
        brandR: brandR.text.trim(),
      );
      await ref.read(workoutControllerProvider.notifier).save(value);
      if (context.mounted) context.pop();
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: Text(
          isNew
              ? '새 워크아웃'
              : initial.name.isEmpty
              ? '워크아웃'
              : initial.name,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: draft.value.modules.isEmpty
                  ? null
                  : () async {
                      await save();
                      if (context.mounted) {
                        context.push('/player/${draft.value.id}');
                      }
                    },
              icon: const Icon(Icons.play_arrow),
              label: const Text('재생'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
        children: [
          _TextField(label: '워크아웃 이름', controller: name, hint: '예: 9/4 금 하이록스'),
          _TextField(label: '폴더', controller: folder, hint: '예: 잠실'),
          _TextField(label: '화면 왼쪽 아래 문구', controller: brandL),
          _TextField(label: '화면 오른쪽 아래 문구', controller: brandR),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                '슬라이드',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: XonColors.muted,
                ),
              ),
              const Spacer(),
              Text(
                durationLabel(workoutDuration(draft.value)),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(
            draft.value.modules.length,
            (index) => _ModuleEditor(
              module: draft.value.modules[index],
              index: index,
              onChange: (module) {
                final list = [...draft.value.modules];
                list[index] = module;
                draft.value = draft.value.copyWith(modules: list);
              },
              onRemove: () {
                final list = [...draft.value.modules]..removeAt(index);
                draft.value = draft.value.copyWith(modules: list);
              },
              onMove: (amount) {
                final target = index + amount;
                if (target < 0 || target >= draft.value.modules.length) return;
                final list = [...draft.value.modules];
                final item = list.removeAt(index);
                list.insert(target, item);
                draft.value = draft.value.copyWith(modules: list);
              },
              onPlay: () async {
                await save();
                if (context.mounted) {
                  context.push('/player/${draft.value.id}?start=$index');
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => draft.value = draft.value.copyWith(
                  modules: [
                    ...draft.value.modules,
                    WorkoutModule.empty(newId()),
                  ],
                ),
                icon: const Icon(Icons.add),
                label: const Text('슬라이드 추가'),
              ),
              OutlinedButton(
                onPressed: () => draft.value = draft.value.copyWith(
                  modules: [
                    ...draft.value.modules,
                    WorkoutModule.empty(newId()).copyWith(
                      name: '휴식',
                      workSeconds: 60,
                      text: '물 마시고 다음 스테이션으로',
                    ),
                  ],
                ),
                child: const Text('휴식 60초'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: FilledButton(onPressed: save, child: const Text('저장')),
          ),
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.label,
    required this.controller,
    this.hint = '',
  });
  final String label, hint;
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: XonColors.muted,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    ),
  );
}

class _ModuleEditor extends HookWidget {
  const _ModuleEditor({
    required this.module,
    required this.index,
    required this.onChange,
    required this.onRemove,
    required this.onMove,
    required this.onPlay,
  });
  final WorkoutModule module;
  final int index;
  final ValueChanged<WorkoutModule> onChange;
  final VoidCallback onRemove, onPlay;
  final ValueChanged<int> onMove;
  @override
  Widget build(BuildContext context) {
    final open = useState(index == 0);
    final name = useTextEditingController(text: module.name);
    final text = useTextEditingController(text: module.text);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: open.value ? XonColors.black : XonColors.line,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => open.value = !open.value,
            leading: CircleAvatar(
              backgroundColor: XonColors.black,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            title: Text(
              module.name.isEmpty ? '이름 없음' : module.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${module.sets}세트 · ${durationLabel(module.workSeconds)}',
            ),
            trailing: Icon(open.value ? Icons.expand_less : Icons.expand_more),
          ),
          if (open.value)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  _TextField(label: '슬라이드 이름', controller: name),
                  Row(
                    children: [
                      _NumberField(
                        label: '시간(초)',
                        value: module.workSeconds,
                        min: 1,
                        onChanged: (value) =>
                            onChange(module.copyWith(workSeconds: value)),
                      ),
                      const SizedBox(width: 8),
                      _NumberField(
                        label: '세트',
                        value: module.sets,
                        min: 1,
                        onChanged: (value) =>
                            onChange(module.copyWith(sets: value)),
                      ),
                      const SizedBox(width: 8),
                      _NumberField(
                        label: '휴식(초)',
                        value: module.restSeconds,
                        min: 0,
                        onChanged: (value) =>
                            onChange(module.copyWith(restSeconds: value)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '화면 텍스트',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: XonColors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: text,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: '운동 설명을 줄바꿈으로 입력하세요',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      FilterChip(
                        label: const Text('타이머 표시'),
                        selected: module.showTimer,
                        onSelected: (value) =>
                            onChange(module.copyWith(showTimer: value)),
                      ),
                      FilterChip(
                        label: const Text('비프음'),
                        selected: module.beep,
                        onSelected: (value) =>
                            onChange(module.copyWith(beep: value)),
                      ),
                      FilterChip(
                        label: const Text('이미지 꽉 채우기'),
                        selected: module.coverImage,
                        onSelected: (value) =>
                            onChange(module.copyWith(coverImage: value)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final file = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1920,
                            imageQuality: 85,
                          );
                          if (file != null) {
                            onChange(
                              module.copyWith(
                                imageBase64: base64Encode(
                                  await file.readAsBytes(),
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.image_outlined),
                        label: Text(
                          module.imageBase64.isEmpty ? '배경 이미지' : '이미지 변경',
                        ),
                      ),
                      if (module.imageBase64.isNotEmpty)
                        IconButton(
                          onPressed: () =>
                              onChange(module.copyWith(imageBase64: '')),
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton(
                        onPressed: () => onMove(-1),
                        child: const Text('↑ 위로'),
                      ),
                      TextButton(
                        onPressed: () => onMove(1),
                        child: const Text('↓ 아래로'),
                      ),
                      TextButton(
                        onPressed: () {
                          onChange(
                            module.copyWith(name: name.text, text: text.text),
                          );
                          onPlay();
                        },
                        child: const Text('이 슬라이드부터 재생'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        onPressed: onRemove,
                        child: const Text('삭제'),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => onChange(
                      module.copyWith(name: name.text, text: text.text),
                    ),
                    child: const Text('슬라이드 변경 적용'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.min,
    required this.onChanged,
  });
  final String label;
  final int value, min;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: XonColors.muted,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            IconButton(
              onPressed: () => onChanged((value - 1).clamp(min, 9999)),
              icon: const Icon(Icons.remove),
              visualDensity: VisualDensity.compact,
            ),
            Expanded(child: Text('$value', textAlign: TextAlign.center)),
            IconButton(
              onPressed: () => onChanged(value + 1),
              icon: const Icon(Icons.add),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    ),
  );
}
