import 'package:flutter/material.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/core/theme/app_style.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_editor_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_duration_field.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_editor_style.dart';

/// A child of the slide editor. All applied changes share its draft.
class TimerEditorScreen extends HookConsumerWidget {
  const TimerEditorScreen({
    super.key,
    required this.workoutId,
    required this.original,
    required this.scope,
    required this.onSelectBlock,
  });
  final String workoutId, scope;
  final WorkoutModule original;
  final ValueChanged<String> onSelectBlock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = slideEditorControllerProvider(workoutId, original, scope);
    final initial = useMemoized(() => ref.read(provider).module);
    final draft = useState(initial);
    final applied = useState(false);
    final actions = ref.read(provider.notifier);
    final module = draft.value;
    final blocks = effectiveIntervalBlocks(module);
    final expanded = useState<String?>(blocks.first.id);
    final valid = blocks.every(
      (b) => b.workSeconds > 0 && b.restSeconds >= 0 && b.sets > 0,
    );
    void apply() {
      if (applied.value || !valid) return;
      applied.value = true;
      actions.update(copySlideTiming(ref.read(provider).module, module));
      onSelectBlock(
        blocks.any((block) => block.id == expanded.value)
            ? expanded.value!
            : blocks.first.id,
      );
      Navigator.of(context).pop();
    }

    final total = workoutModuleDuration(module);
    final workTotal = blocks.fold<int>(
      0,
      (sum, block) => sum + block.workSeconds * block.sets,
    );
    void updateBlocks(List<WorkoutIntervalBlock> value) {
      draft.value = withIntervalBlocks(draft.value, value);
    }

    return Theme(
      data: SlideEditorStyle.theme(Theme.of(context)),
      child: UnsavedChangesGuard(
        dirty: !applied.value && !sameSlideTiming(module, initial),
        confirmTitle: '적용하지 않고 닫을까요?',
        confirmMessage: '이번에 변경한 시간과 세트는 적용되지 않습니다.',
        discardLabel: '적용 안 하고 닫기',
        child: Scaffold(
          key: const ValueKey('timer-editor-sheet'),
          appBar: AppBar(
            leading: CloseButton(
              key: const ValueKey('close-timer-editor'),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: const Text('타이머 편집'),
            actions: [
              TextButton(
                key: const ValueKey('apply-timer-editor'),
                onPressed: applied.value || !valid ? null : apply,
                child: const Text('적용'),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: ListView(
                  key: const ValueKey('timer-editor-settings'),
                  padding: EdgeInsets.fromLTRB(
                    MediaQuery.sizeOf(context).width >= 700 ? 40 : 24,
                    20,
                    MediaQuery.sizeOf(context).width >= 700 ? 40 : 24,
                    40,
                  ),
                  children: [
                    Text(
                      module.name,
                      style: const TextStyle(color: SlideEditorStyle.muted),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '전체 운동 시간',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          durationLabel(total),
                          key: const ValueKey('timer-editor-total'),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: SlideEditorStyle.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                        Text(
                          '운동 ${formatSlideTime(workTotal)}',
                          style: const TextStyle(
                            color: SlideEditorStyle.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '휴식 ${formatSlideTime(total - workTotal)}',
                          style: const TextStyle(
                            color: SlideEditorStyle.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 40),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: blocks.length,
                      onReorderItem: (oldIndex, newIndex) {
                        final next = [...blocks];
                        next.insert(newIndex, next.removeAt(oldIndex));
                        updateBlocks(next);
                      },
                      itemBuilder: (context, index) {
                        final block = blocks[index];
                        final isOpen = expanded.value == block.id;
                        void toggle() {
                          expanded.value = isOpen ? null : block.id;
                        }

                        return Padding(
                          key: ValueKey(block.id),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: SlideEditorStyle.surface,
                            borderRadius: BorderRadius.circular(
                              AppStyle.controlRadius,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Semantics(
                                          label: '블록 ${index + 1} 순서 변경',
                                          child: const Icon(
                                            Icons.drag_handle_rounded,
                                            color: SlideEditorStyle.muted,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: InkWell(
                                        key: ValueKey(
                                          'timer-block-${block.id}',
                                        ),
                                        onTap: toggle,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 20,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '블록 ${index + 1}',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '운동 ${formatSlideTime(block.workSeconds)} · 휴식 ${formatSlideTime(block.restSeconds)} · ${block.sets}세트',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: SlideEditorStyle.muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      tooltip: '블록 메뉴',
                                      icon: const Icon(Icons.more_horiz),
                                      onSelected: (action) {
                                        if (action == 'duplicate') {
                                          final copy = block.copyWith(
                                            id: newId(),
                                          );
                                          updateBlocks(
                                            [...blocks]
                                              ..insert(index + 1, copy),
                                          );
                                        } else if (blocks.length > 1) {
                                          updateBlocks(
                                            [...blocks]..removeAt(index),
                                          );
                                          if (isOpen) expanded.value = null;
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                          value: 'duplicate',
                                          child: Text('복제'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          enabled: blocks.length > 1,
                                          child: Text(
                                            blocks.length > 1
                                                ? '삭제'
                                                : '블록은 하나 이상 필요합니다',
                                          ),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      tooltip: isOpen
                                          ? '시간 블록 접기'
                                          : '시간 블록 펼치기',
                                      onPressed: toggle,
                                      icon: Icon(
                                        isOpen
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                ),
                                if (isOpen) ...[
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    child: Divider(height: 1),
                                  ),
                                  SlideTimingEditor(
                                    key: ValueKey(block.id),
                                    embedded: true,
                                    initialWorkSeconds: block.workSeconds,
                                    initialRestSeconds: block.restSeconds,
                                    initialSets: block.sets,
                                    onChanged: (value) {
                                      final updated = block.copyWith(
                                        workSeconds: value.workSeconds,
                                        restSeconds: value.restSeconds,
                                        sets: value.sets,
                                      );
                                      updateBlocks([
                                        for (final item in blocks)
                                          if (item.id == block.id)
                                            updated
                                          else
                                            item,
                                      ]);
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      key: const ValueKey('add-interval-block'),
                      onPressed: () {
                        final block = WorkoutIntervalBlock(
                          id: newId(),
                          workSeconds: 60,
                          restSeconds: 0,
                          sets: 1,
                        );
                        updateBlocks([...blocks, block]);
                        expanded.value = block.id;
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('블록 추가'),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '각 블록의 마지막 세트 뒤에는 휴식이 없습니다. 배경 이미지에 적힌 시간은 설정과 자동으로 바뀌지 않습니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: SlideEditorStyle.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '적용 후 슬라이드 상단의 저장 버튼을 눌러 변경사항을 저장해 주세요.',
                      style: TextStyle(
                        fontSize: 12,
                        color: SlideEditorStyle.muted,
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
