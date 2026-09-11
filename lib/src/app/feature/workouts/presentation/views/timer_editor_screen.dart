import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_editor_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_duration_field.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_editor_style.dart';

/// A child of the slide editor. All applied changes share its draft and history.
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
    final state = ref.watch(provider);
    final actions = ref.read(provider.notifier);
    final module = state.module;
    final blocks = effectiveIntervalBlocks(module);
    final expanded = useState<String?>(blocks.first.id);
    final revision = useState(0);
    final total = workoutModuleDuration(module);
    final workTotal = blocks.fold<int>(
      0,
      (sum, block) => sum + block.workSeconds * block.sets,
    );
    void updateBlocks(List<WorkoutIntervalBlock> value) {
      actions.update(withIntervalBlocks(ref.read(provider).module, value));
    }

    void history(VoidCallback action) {
      action();
      revision.value++;
    }

    return Theme(
      data: SlideEditorStyle.theme(Theme.of(context)),
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.pop(context)),
          actions: [
            IconButton(
              tooltip: '실행 취소',
              icon: const Icon(Icons.undo),
              onPressed: state.undo.isEmpty
                  ? null
                  : () => history(actions.undo),
            ),
            IconButton(
              tooltip: '다시 실행',
              icon: const Icon(Icons.redo),
              onPressed: state.redo.isEmpty
                  ? null
                  : () => history(actions.redo),
            ),
            TextButton(
              key: const ValueKey('close-timer-editor'),
              onPressed: () => Navigator.pop(context),
              child: const Text('편집 완료'),
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
                  const Text(
                    '타이머 편집',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    module.name,
                    style: const TextStyle(color: SlideEditorStyle.muted),
                  ),
                  const SizedBox(height: 32),
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
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('타이머 표시'),
                    subtitle: const Text('타이머를 숨겨도 운동 진행은 유지됩니다.'),
                    value: module.showTimer,
                    onChanged: (value) =>
                        actions.update(module.copyWith(showTimer: value)),
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
                        onSelectBlock(block.id);
                      }

                      return Padding(
                        key: ValueKey(block.id),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: SlideEditorStyle.surface,
                          borderRadius: BorderRadius.circular(10),
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
                                      key: ValueKey('timer-block-${block.id}'),
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
                                          [...blocks]..insert(index + 1, copy),
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
                                    tooltip: isOpen ? '시간 블록 접기' : '시간 블록 펼치기',
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
                                  padding: EdgeInsets.symmetric(horizontal: 20),
                                  child: Divider(height: 1),
                                ),
                                SlideTimingEditor(
                                  key: ValueKey(
                                    '${block.id}-${revision.value}-${block.workSeconds}-${block.restSeconds}-${block.sets}',
                                  ),
                                  embedded: true,
                                  initialWorkSeconds: block.workSeconds,
                                  initialRestSeconds: block.restSeconds,
                                  initialSets: block.sets,
                                  onCancel: () => expanded.value = null,
                                  onApply: (value) {
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
                                    onSelectBlock(block.id);
                                    expanded.value = null;
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
                      onSelectBlock(block.id);
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
                    '변경 사항은 슬라이드 편집에서 저장해 주세요.',
                    style: TextStyle(
                      fontSize: 12,
                      color: SlideEditorStyle.muted,
                    ),
                  ),
                  if (state.storageError != null)
                    Text(
                      state.storageError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
