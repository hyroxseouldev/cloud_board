import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/saved_slide_order.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/saved_slide_order_controller.dart';

class SavedSlideChips extends HookConsumerWidget {
  const SavedSlideChips({
    super.key,
    required this.scope,
    required this.templates,
    required this.onAdd,
    required this.emptyMessage,
    this.enabled = true,
  });

  final String scope;
  final List<WorkoutModule> templates;
  final ValueChanged<WorkoutModule> onAdd;
  final String emptyMessage;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = savedSlideOrderControllerProvider(scope);
    final state = ref.watch(provider);
    final editing = useState(false);
    final dragging = useState(false);
    final dragIds = useRef<List<String>>([]);
    final dragFrom = useRef<int?>(null);
    final scroll = useScrollController();
    final byId = {for (final item in templates) item.id: item};
    final ids = reconcileSavedSlideOrder(state.ids, byId.keys);
    final canReorder =
        enabled && state.ready && !state.saving && ids.length > 1;
    final liveKey = byId.keys.join(',');
    useEffect(() {
      // Persist append/cleanup separately from slide content, including when the
      // last chip is deleted. Never mutate a provider during widget build.
      scheduleMicrotask(() {
        if (context.mounted) {
          unawaited(
            ref.read(provider.notifier).synchronize(byId.keys.toList()),
          );
        }
      });
      return null;
    }, [scope, liveKey, state.ready, state.saving, state.ids]);
    ref.listen(provider.select((value) => value.error), (_, error) {
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            action: SnackBarAction(
              label: '다시 시도',
              onPressed: () => unawaited(ref.read(provider.notifier).retry()),
            ),
          ),
        );
      }
    });

    void move(List<String> snapshot, int from, int to) {
      if (canReorder) {
        unawaited(ref.read(provider.notifier).move(snapshot, from, to));
      }
    }

    return SizedBox(
      height:
          48 + (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(0, 42),
      child: Row(
        children: [
          Expanded(
            child: ids.isEmpty
                ? Text(emptyMessage, style: const TextStyle(fontSize: 12))
                : ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context)
                        .copyWith(scrollbars: false),
                    child: ReorderableListView.builder(
                      key: const ValueKey('workout-slide-templates'),
                      scrollController: scroll,
                      scrollDirection: Axis.horizontal,
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      itemCount: ids.length,
                      onReorderStart: (index) {
                        dragIds.value = [...ids];
                        dragFrom.value = index;
                        dragging.value = true;
                      },
                      onReorderEnd: (index) {
                        final from = dragFrom.value;
                        if (from != null &&
                            (index > from ? index - 1 : index) == from) {
                          dragIds.value = [];
                        }
                        dragFrom.value = null;
                        // The accepted drag cancels the chip's tap recognizer.
                        // Keep the explicit guard through the pointer-up frame too.
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (context.mounted) dragging.value = false;
                        });
                      },
                      onReorderItem: (from, to) {
                        // Framework accessibility actions do not start a drag.
                        final snapshot = dragIds.value.isEmpty
                            ? ids
                            : dragIds.value;
                        dragIds.value = [];
                        move(snapshot, from, to);
                      },
                      proxyDecorator: (child, _, animation) => Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(16),
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: child,
                      ),
                      itemBuilder: (context, index) {
                        final template = byId[ids[index]]!;
                        return Padding(
                          key: ValueKey(template.id),
                          padding: const EdgeInsets.only(right: 8),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Listener(
                                  onPointerDown: canReorder
                                      ? (event) {
                                          if (event.buttons != kPrimaryButton) {
                                            return;
                                          }
                                          SliverReorderableList.of(
                                            context,
                                          ).startItemDragReorder(
                                            index: index,
                                            event: event,
                                            recognizer:
                                                event.kind ==
                                                    PointerDeviceKind.mouse
                                                ? ImmediateMultiDragGestureRecognizer()
                                                : DelayedMultiDragGestureRecognizer(),
                                          );
                                        }
                                      : null,
                                  child: Tooltip(
                                    message:
                                        '${template.name} · ${moduleDurationText(template)} 추가',
                                    child: InputChip(
                                      key: ValueKey(
                                        'saved-slide-chip-${template.id}',
                                      ),
                                      label: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 180,
                                        ),
                                        child: Text(
                                          template.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      backgroundColor: AppColors.selected,
                                      onPressed: !enabled || dragging.value
                                          ? null
                                          : () => onAdd(template),
                                    ),
                                  ),
                                ),
                                if (editing.value)
                                  PopupMenuButton<int>(
                                    key: ValueKey(
                                      'saved-slide-menu-${template.id}',
                                    ),
                                    tooltip: '${template.name} 순서 이동',
                                    enabled: canReorder,
                                    icon: const Icon(Icons.more_vert, size: 18),
                                    padding: EdgeInsets.zero,
                                    onSelected: (offset) =>
                                        move(ids, index, index + offset),
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        value: -1,
                                        enabled: index > 0,
                                        child: const Text('이전으로 이동'),
                                      ),
                                      PopupMenuItem(
                                        value: 1,
                                        enabled: index < ids.length - 1,
                                        child: const Text('다음으로 이동'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          if (state.error != null)
            IconButton(
              tooltip: '칩 순서 다시 시도',
              onPressed: state.saving
                  ? null
                  : () => ref.read(provider.notifier).retry(),
              icon: const Icon(Icons.refresh, size: 18),
            ),
          if (ids.length > 1)
            IconButton(
              key: const ValueKey('saved-slide-order-edit'),
              tooltip: editing.value ? '순서 편집 완료' : '순서 편집',
              isSelected: editing.value,
              onPressed: canReorder
                  ? () => editing.value = !editing.value
                  : null,
              icon: const Icon(Icons.swap_horiz, size: 20),
              selectedIcon: const Icon(Icons.check, size: 20),
            ),
        ],
      ),
    );
  }
}
