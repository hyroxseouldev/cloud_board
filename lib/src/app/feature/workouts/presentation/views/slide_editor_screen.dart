import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_board/src/app/core/widgets/hex_color_field.dart';
import 'package:cloud_board/src/app/core/utils/hex_color.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_duration_field.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';

class SlideEditRequest {
  SlideEditRequest({
    required this.module,
    required this.onSave,
    this.brandL = '',
    this.brandR = '',
  });
  final WorkoutModule module;
  final Future<bool> Function(WorkoutModule) onSave;
  final String brandL;
  final String brandR;
}

class SlideEditorScreen extends ConsumerWidget {
  const SlideEditorScreen({
    super.key,
    required this.workoutId,
    required this.moduleId,
    required this.guard,
    this.request,
  });
  final String workoutId, moduleId;
  final ExitGuard guard;
  final SlideEditRequest? request;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (request != null) {
      return _SlideEditor(
        request: request!,
        guard: guard,
        workoutId: workoutId,
      );
    }
    final workouts = ref.watch(workoutControllerProvider);
    return workouts.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('운동을 불러오지 못했습니다: $e'))),
      data: (items) {
        final workout = items.where((w) => w.id == workoutId).firstOrNull;
        final module = workout?.modules
            .where((m) => m.id == moduleId)
            .firstOrNull;
        if (workout == null || module == null) {
          return const Scaffold(body: Center(child: Text('슬라이드를 찾을 수 없습니다.')));
        }
        return _SlideEditor(
          guard: guard,
          workoutId: workoutId,
          request: SlideEditRequest(
            module: module,
            brandL: workout.brandL,
            brandR: workout.brandR,
            onSave: (updated) async {
              final latest =
                  ref
                      .read(workoutControllerProvider)
                      .value
                      ?.where((w) => w.id == workoutId)
                      .firstOrNull ??
                  workout;
              return await ref
                      .read(workoutActionControllerProvider.notifier)
                      .save(
                        latest.copyWith(
                          modules: latest.modules
                              .map((m) => m.id == moduleId ? updated : m)
                              .toList(),
                        ),
                      ) !=
                  null;
            },
          ),
        );
      },
    );
  }
}

class _SlideEditor extends HookWidget {
  const _SlideEditor({
    required this.request,
    required this.guard,
    required this.workoutId,
  });
  final String workoutId;
  final SlideEditRequest request;
  final ExitGuard guard;
  @override
  Widget build(BuildContext context) {
    final original = useMemoized(() => request.module);
    final draft = useState(original);
    final dirty = useState(false);
    final busy = useState(false);
    final error = useState<String?>(null);
    final form = useMemoized(() => GlobalKey<FormState>());
    final name = useTextEditingController(text: original.name);
    final description = useTextEditingController(text: original.text);
    final blocks = useState(effectiveIntervalBlocks(original));
    final selectedBlockId = useState(blocks.value.first.id);
    useListenable(name);
    useListenable(description);
    final previewRest = useState(false);
    final colors = useState([
      colorHex(slideColor(original, rest: false, text: false)),
      colorHex(slideColor(original, rest: true, text: false)),
      colorHex(slideColor(original, rest: false, text: true)),
      colorHex(slideColor(original, rest: true, text: true)),
    ]);
    final touchedColors = useState(List.filled(4, false));
    Future<void> save() async {
      if (!form.currentState!.validate()) return;
      busy.value = true;
      error.value = null;
      try {
        final saved = await request.onSave(
          withIntervalBlocks(
            draft.value.copyWith(
              name: name.text.trim(),
              text: description.text,
              workGaugeColor: touchedColors.value[0]
                  ? colors.value[0].toUpperCase()
                  : original.workGaugeColor,
              restGaugeColor: touchedColors.value[1]
                  ? colors.value[1].toUpperCase()
                  : original.restGaugeColor,
              workTextColor: touchedColors.value[2]
                  ? colors.value[2].toUpperCase()
                  : original.workTextColor,
              restTextColor: touchedColors.value[3]
                  ? colors.value[3].toUpperCase()
                  : original.restTextColor,
            ),
            blocks.value,
          ),
        );
        if (!context.mounted) return;
        if (!saved) {
          error.value = '저장하지 못했습니다. 편집 내용은 유지됩니다. 연결을 확인하고 다시 저장해 주세요.';
          return;
        }
        dirty.value = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/editor/$workoutId');
            }
          }
        });
      } catch (e) {
        if (context.mounted) error.value = '저장하지 못했습니다: $e';
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    return UnsavedChangesGuard(
      guard: guard,
      dirty: dirty.value,
      blocked: busy.value,
      child: Scaffold(
        appBar: AppBar(title: const Text('슬라이드 편집')),
        body: AbsorbPointer(
          absorbing: busy.value,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Form(
                key: form,
                onChanged: () => dirty.value = true,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: '슬라이드 제목'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? '제목을 입력해 주세요.' : null,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text(
                          '시간 블록',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        Text('${blocks.value.length}개'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: blocks.value.length,
                      onReorderItem: (oldIndex, newIndex) {
                        final next = [...blocks.value];
                        next.insert(newIndex, next.removeAt(oldIndex));
                        blocks.value = next;
                        dirty.value = true;
                      },
                      itemBuilder: (context, index) {
                        final block = blocks.value[index];
                        return Padding(
                          key: ValueKey(block.id),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _IntervalBlockTile(
                            index: index,
                            block: block,
                            canDelete: blocks.value.length > 1,
                            onEditing: () => selectedBlockId.value = block.id,
                            onChanged: (updated) {
                              blocks.value = [
                                for (final value in blocks.value)
                                  if (value.id == updated.id)
                                    updated
                                  else
                                    value,
                              ];
                              selectedBlockId.value = updated.id;
                              dirty.value = true;
                            },
                            onDuplicate: () {
                              final next = [
                                ...blocks.value,
                              ]..insert(index + 1, block.copyWith(id: newId()));
                              blocks.value = next;
                              dirty.value = true;
                            },
                            onDelete: () {
                              blocks.value = [...blocks.value]..removeAt(index);
                              if (selectedBlockId.value == block.id) {
                                selectedBlockId.value = blocks.value.first.id;
                              }
                              dirty.value = true;
                            },
                          ),
                        );
                      },
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('add-interval-block'),
                      onPressed: () {
                        final block = WorkoutIntervalBlock(
                          id: newId(),
                          workSeconds: 60,
                          restSeconds: 0,
                          sets: 1,
                        );
                        blocks.value = [...blocks.value, block];
                        selectedBlockId.value = block.id;
                        dirty.value = true;
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('블록 추가'),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: description,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: '화면 텍스트'),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<TimerDisplayMode>(
                      initialValue: timerDisplayMode(draft.value),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '타이머 표시',
                        helperText: '타이머를 숨겨도 운동 진행은 유지됩니다.',
                        helperMaxLines: 2,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: TimerDisplayMode.gaugeAndNumber,
                          child: Text('숫자 + 게이지'),
                        ),
                        DropdownMenuItem(
                          value: TimerDisplayMode.numberOnly,
                          child: Text('숫자만'),
                        ),
                        DropdownMenuItem(
                          value: TimerDisplayMode.hidden,
                          child: Text('안 보임'),
                        ),
                      ],
                      onChanged: (mode) {
                        if (mode == null) return;
                        draft.value = draft.value.copyWith(
                          showTimer: mode != TimerDisplayMode.hidden,
                          showTimerGauge:
                              mode == TimerDisplayMode.gaugeAndNumber,
                        );
                        dirty.value = true;
                      },
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('세트 표시'),
                      subtitle: const Text('타이머와 별도로 남은 세트 수를 표시합니다.'),
                      value: draft.value.showSets,
                      onChanged: (value) {
                        draft.value = draft.value.copyWith(showSets: value);
                        dirty.value = true;
                      },
                    ),
                    const SizedBox(height: 20),
                    for (var i = 0; i < 4; i++)
                      HexColorField(
                        label: const [
                          '운동 게이지 색상',
                          '휴식 게이지 색상',
                          '운동 시간 텍스트 색상',
                          '휴식 시간 텍스트 색상',
                        ][i],
                        initialValue: colors.value[i],
                        onChanged: (v) {
                          final next = [...colors.value];
                          next[i] = v;
                          colors.value = next;
                          touchedColors.value = [...touchedColors.value]
                            ..[i] = true;
                          dirty.value = true;
                        },
                      ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('전환음'),
                      value: draft.value.beep,
                      onChanged: (v) {
                        draft.value = draft.value.copyWith(beep: v);
                        dirty.value = true;
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('이미지 꽉 채우기'),
                      value: draft.value.coverImage,
                      onChanged: (v) {
                        draft.value = draft.value.copyWith(coverImage: v);
                        dirty.value = true;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '슬라이드 미리보기',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('운동')),
                            ButtonSegment(value: true, label: Text('휴식')),
                          ],
                          selected: {previewRest.value},
                          showSelectedIcon: false,
                          onSelectionChanged: (values) {
                            previewRest.value = values.first;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    WorkoutSlidePreview(
                      module: withIntervalBlocks(
                        draft.value.copyWith(
                          name: name.text.trim(),
                          text: description.text,
                          workGaugeColor: colors.value[0],
                          restGaugeColor: colors.value[1],
                          workTextColor: colors.value[2],
                          restTextColor: colors.value[3],
                        ),
                        [
                          blocks.value.firstWhere(
                            (value) => value.id == selectedBlockId.value,
                            orElse: () => blocks.value.first,
                          ),
                        ],
                      ),
                      isRest: previewRest.value,
                      brandL: request.brandL,
                      brandR: request.brandR,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('배경 이미지 선택'),
                      onPressed: () async {
                        try {
                          final file = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1920,
                            imageQuality: 85,
                          );
                          if (file == null) return;
                          final bytes = await file.readAsBytes();
                          if (!context.mounted) return;
                          draft.value = draft.value.copyWith(
                            imageSource: WorkoutImageSource.fromBytes(
                              bytes,
                              contentType: file.mimeType,
                            ),
                          );
                          dirty.value = true;
                        } catch (e) {
                          if (context.mounted) {
                            error.value = '이미지를 불러오지 못했습니다: $e';
                          }
                        }
                      },
                    ),
                    if (draft.value.imageSource.isNotEmpty) ...[
                      TextButton(
                        onPressed: () {
                          draft.value = draft.value.copyWith(imageSource: '');
                          dirty.value = true;
                        },
                        child: const Text('이미지 제거'),
                      ),
                    ],
                    if (error.value != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          error.value!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: busy.value ? null : save,
                      icon: busy.value
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        busy.value
                            ? '저장 중…'
                            : error.value == null
                            ? '저장'
                            : '다시 저장',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _IntervalBlockAction { duplicate, delete }

class _IntervalBlockTile extends HookWidget {
  const _IntervalBlockTile({
    required this.index,
    required this.block,
    required this.canDelete,
    required this.onEditing,
    required this.onChanged,
    required this.onDuplicate,
    required this.onDelete,
  });

  final int index;
  final WorkoutIntervalBlock block;
  final bool canDelete;
  final VoidCallback onEditing;
  final ValueChanged<WorkoutIntervalBlock> onChanged;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final work = useTextEditingController(
      text: formatSlideTime(block.workSeconds),
    );
    final rest = useTextEditingController(
      text: formatSlideTime(block.restSeconds),
    );
    final sets = useTextEditingController(text: '${block.sets}');
    return SlideTimingBlocks(
      title: '블록 ${index + 1}',
      workController: work,
      restController: rest,
      setsController: sets,
      onEditing: onEditing,
      onChanged: () => onChanged(
        block.copyWith(
          workSeconds: parseSlideTime(work.text)!,
          restSeconds: parseSlideTime(rest.text)!,
          sets: int.parse(sets.text),
        ),
      ),
      workValidator: (value) =>
          (parseSlideTime(value ?? '') ?? 0) > 0 ? null : '00:01 이상',
      restValidator: (value) =>
          parseSlideTime(value ?? '') != null ? null : '올바른 시간 필요',
      setsValidator: (value) {
        final count = int.tryParse(value ?? '');
        return count != null && count >= 1 && count <= 999 ? null : '1~999 필요';
      },
      leading: ReorderableDragStartListener(
        index: index,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.drag_handle_rounded),
        ),
      ),
      trailing: PopupMenuButton<_IntervalBlockAction>(
        tooltip: '블록 메뉴',
        onSelected: (action) {
          switch (action) {
            case _IntervalBlockAction.duplicate:
              onDuplicate();
            case _IntervalBlockAction.delete:
              onDelete();
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: _IntervalBlockAction.duplicate,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.copy_outlined),
              title: Text('복제'),
            ),
          ),
          PopupMenuItem(
            value: _IntervalBlockAction.delete,
            enabled: canDelete,
            child: ListTile(
              enabled: canDelete,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline),
              title: Text(canDelete ? '삭제' : '블록은 하나 이상 필요합니다'),
            ),
          ),
        ],
      ),
    );
  }
}
