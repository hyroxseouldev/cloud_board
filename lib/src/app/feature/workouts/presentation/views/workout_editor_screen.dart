import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:cloud_board/src/app/core/theme/app_style.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/async_action_overlay.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/folder_selector.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_settings_sheet.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_templates_controller.dart';

class WorkoutEditorScreen extends ConsumerWidget {
  const WorkoutEditorScreen({super.key, required this.workoutId, this.guard});
  final String workoutId;
  final ExitGuard? guard;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = ref.watch(workoutControllerProvider);
    final user = ref.watch(authStateProvider).value;
    return values.when(
      data: (items) {
        final workout = workoutId == 'new' && user != null
            ? Workout.empty(
                newId(),
                WorkoutAuthor(
                  id: user.id,
                  displayName: user.displayName,
                  photoUrl: user.photoUrl,
                ),
              )
            : items.where((item) => item.id == workoutId).firstOrNull;
        return workout == null
            ? const Scaffold(body: Center(child: Text('워크아웃을 찾을 수 없습니다.')))
            : _EditorBody(
                initial: workout,
                isNew: workoutId == 'new',
                guard: guard,
              );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
    );
  }
}

class _WorkoutNameDialog extends HookWidget {
  const _WorkoutNameDialog();
  @override
  Widget build(BuildContext context) {
    final name = useTextEditingController();
    final form = useMemoized(() => GlobalKey<FormState>());
    return AppAlertDialog(
      title: const Text('워크아웃 이름이 필요합니다'),
      content: Form(
        key: form,
        child: TextFormField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: '저장할 워크아웃 이름'),
          validator: (v) =>
              v == null || v.trim().isEmpty ? '이름을 입력해 주세요.' : null,
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
              Navigator.pop(context, name.text.trim());
            }
          },
          child: const Text('계속 저장'),
        ),
      ],
    );
  }
}

class _SlideTemplateNameDialog extends HookWidget {
  const _SlideTemplateNameDialog({required this.initialName});
  final String initialName;

  @override
  Widget build(BuildContext context) {
    final name = useTextEditingController(text: initialName);
    final form = useMemoized(() => GlobalKey<FormState>());
    void submit() {
      if (form.currentState!.validate()) {
        Navigator.pop(context, name.text.trim());
      }
    }

    return AppAlertDialog(
      title: const Text('자주 쓰는 슬라이드로 저장'),
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('내용과 타이머·화면 설정을 이 기기에 저장해 다른 워크아웃에서도 사용할 수 있어요.'),
            const SizedBox(height: 16),
            TextFormField(
              controller: name,
              autofocus: true,
              maxLength: 40,
              decoration: const InputDecoration(labelText: '칩 이름'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '이름을 입력해 주세요.' : null,
              onFieldSubmitted: (_) => submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: submit, child: const Text('칩 만들기')),
      ],
    );
  }
}

class _EditorBody extends HookConsumerWidget {
  const _EditorBody({required this.initial, required this.isNew, this.guard});
  final Workout initial;
  final bool isNew;
  final ExitGuard? guard;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = useState(initial);
    final savedBaseline = useState(initial);
    final name = useTextEditingController(text: initial.name);
    final folder = useTextEditingController(text: initial.folder);
    final brandL = useTextEditingController(text: initial.brandL);
    final brandR = useTextEditingController(text: initial.brandR);
    final slideScroll = useScrollController();
    final selectedSlide = useState<String?>(null);
    final rowExtent = 96 * MediaQuery.textScalerOf(context).scale(1);
    useListenable(name);
    useListenable(folder);
    useListenable(brandL);
    useListenable(brandR);
    final templatesProvider = slideTemplatesControllerProvider(
      ref.watch(authStateProvider).value?.id ?? initial.ownerId,
    );
    final templates = ref.watch(templatesProvider);
    final action = ref.watch(workoutActionControllerProvider);
    final playbackAction = ref.watch(playbackActionControllerProvider);
    final isBusy = action.isLoading || playbackAction.isLoading;
    final hasUnsavedChanges =
        draft.value != savedBaseline.value ||
        name.text.trim() != savedBaseline.value.name ||
        folder.text.trim() != savedBaseline.value.folder ||
        brandL.text.trim() != savedBaseline.value.brandL ||
        brandR.text.trim() != savedBaseline.value.brandR;

    Future<Workout?> persist({Workout? edited}) async {
      if (name.text.trim().isEmpty) {
        final enteredName = await showDialog<String>(
          context: context,
          builder: (_) => const _WorkoutNameDialog(),
        );
        if (enteredName == null || !context.mounted) return null;
        name.text = enteredName;
      }
      final value = (edited ?? draft.value).copyWith(
        name: name.text.trim(),
        folder: folder.text.trim(),
        brandL: brandL.text.trim(),
        brandR: brandR.text.trim(),
      );
      final saved = await ref
          .read(workoutActionControllerProvider.notifier)
          .save(value);
      if (saved != null) {
        draft.value = saved;
        savedBaseline.value = saved;
      }
      return saved;
    }

    Future<void> saveAndClose() async {
      final saved = await persist();
      if (saved == null || !context.mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (isNew || !context.canPop()) {
          context.go('/');
        } else {
          context.pop();
        }
      });
    }

    void selectSlide(String id) {
      selectedSlide.value = id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || !slideScroll.hasClients) return;
        final index = draft.value.modules.indexWhere((m) => m.id == id);
        if (index < 0) return;
        // Include the newly appended row before the lazy list updates its extent.
        final maxOffset =
            (draft.value.modules.length * rowExtent +
                    36 -
                    slideScroll.position.viewportDimension)
                .clamp(0.0, double.infinity);
        slideScroll.animateTo(
          (index * rowExtent).clamp(0.0, maxOffset),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    }

    void addSlide([WorkoutModule? template]) {
      final module = template == null
          ? WorkoutModule.empty(newId())
                .copyWith(name: nextSlideName(draft.value.modules))
          : template.copyWith(
              id: newId(),
              intervalBlocks: [
                for (final (index, block) in template.intervalBlocks.indexed)
                  block.copyWith(id: '${newId()}-$index'),
              ],
            );
      draft.value = draft.value.copyWith(
        modules: [...draft.value.modules, module],
      );
      selectSlide(module.id);
    }

    Future<void> saveTemplate(WorkoutModule module) async {
      final templateName = await showDialog<String>(
        context: context,
        builder: (_) => _SlideTemplateNameDialog(initialName: module.name),
      );
      if (templateName == null || !context.mounted) return;
      final saved = await ref
          .read(templatesProvider.notifier)
          .save(module, templateName);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved ? '자주 쓰는 슬라이드 칩을 만들었습니다.' : '칩을 저장하지 못했습니다. 다시 시도해 주세요.',
          ),
        ),
      );
    }

    Future<void> removeTemplate(WorkoutModule template) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AppAlertDialog(
          title: const Text('자주 쓰는 슬라이드를 삭제할까요?'),
          content: Text('“${template.name}” 칩을 삭제합니다. 워크아웃에 추가한 슬라이드는 유지됩니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('삭제'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      final removed = await ref
          .read(templatesProvider.notifier)
          .remove(template.id);
      if (!removed && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('칩을 삭제하지 못했습니다. 다시 시도해 주세요.')),
        );
      }
    }

    Future<void> openSettings() => showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 800),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) =>
          WorkoutSettingsSheet(draft: draft, brandL: brandL, brandR: brandR),
    );

    return UnsavedChangesGuard(
      guard: guard,
      dirty: hasUnsavedChanges,
      blocked: isBusy,
      child: AsyncActionOverlay(
        isLoading: isBusy,
        child: Scaffold(
          appBar: AppBar(
            leading: BackButton(
              onPressed: isBusy
                  ? null
                  : () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    },
            ),
            actions: [
              Center(
                child: Text(
                  action.isLoading
                      ? '저장 중…'
                      : hasUnsavedChanges
                      ? '저장 필요'
                      : '저장됨',
                  style: TextStyle(
                    color: hasUnsavedChanges ? Colors.orange : XonColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 480;
                  return Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          compact ? 0 : 8,
                          24,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '워크아웃 편집',
                                    style: compact
                                        ? AppStyle.of(context).subText2
                                        : AppStyle.of(context).mainText,
                                  ),
                                ),
                                IconButton(
                                  tooltip: '화면·사운드 설정',
                                  onPressed: isBusy ? null : openSettings,
                                  icon: const Icon(Icons.tune_rounded),
                                ),
                              ],
                            ),
                            SizedBox(height: compact ? 4 : 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: name,
                                    enabled: !isBusy,
                                    decoration: const InputDecoration(
                                      labelText: '워크아웃 이름',
                                      hintText: 'Title',
                                      isDense: true,
                                      suffixIcon: Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: FolderSelector(
                                    compact: true,
                                    enabled: !isBusy,
                                    value: folder.text,
                                    folders: {
                                      ...?ref
                                          .watch(workoutControllerProvider)
                                          .value
                                          ?.map((w) => w.folder)
                                          .where((f) => f.isNotEmpty),
                                      if (folder.text.isNotEmpty) folder.text,
                                    },
                                    onChanged: (value) => folder.text = value,
                                  ),
                                ),
                              ],
                            ),
                            if (!compact) ...[
                              const SizedBox(height: 24),
                              Text(
                                '슬라이드 설정',
                                style: AppStyle.of(context).subText1,
                              ),
                              const SizedBox(height: 12),
                            ],
                            Row(
                              children: [
                                const Text(
                                  '전체 워크아웃',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    durationLabel(workoutDuration(draft.value)),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: XonColors.muted,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: '저장',
                                  onPressed: isBusy ? null : saveAndClose,
                                  icon: const Icon(Icons.save_outlined),
                                ),
                              ],
                            ),
                            if (action.hasError)
                              Text(
                                '저장하지 못했습니다. 변경사항은 유지됩니다. 다시 저장해 주세요.',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            SizedBox(
                              height: 48,
                              child: Row(
                                children: [
                                  Expanded(
                                    child:
                                        templates.isLoading &&
                                            !templates.hasValue
                                        ? const Align(
                                            alignment: Alignment.centerLeft,
                                            child: SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          )
                                        : templates.hasError
                                        ? TextButton(
                                            onPressed: () => ref.invalidate(
                                              templatesProvider,
                                            ),
                                            child: const Text('칩 불러오기 다시 시도'),
                                          )
                                        : (templates.value ?? []).isEmpty
                                        ? const Text(
                                            '슬라이드 메뉴(⋮)에서 칩으로 저장',
                                            style: TextStyle(
                                              color: XonColors.muted,
                                              fontSize: 12,
                                            ),
                                          )
                                        : ListView.separated(
                                            key: const ValueKey(
                                              'workout-slide-templates',
                                            ),
                                            scrollDirection: Axis.horizontal,
                                            itemCount: templates.value!.length,
                                            separatorBuilder: (_, _) =>
                                                const SizedBox(width: 8),
                                            itemBuilder: (context, index) {
                                              final template =
                                                  templates.value![index];
                                              return Center(
                                                child: Tooltip(
                                                  message:
                                                      '${template.name} · ${durationLabel(workoutModuleDuration(template))} 추가',
                                                  child: InputChip(
                                                    label: Text(template.name),
                                                    backgroundColor:
                                                        AppColors.selected,
                                                    deleteButtonTooltipMessage:
                                                        '${template.name} 칩 삭제',
                                                    onPressed:
                                                        isBusy ||
                                                            templates.isLoading
                                                        ? null
                                                        : () => addSlide(
                                                            template,
                                                          ),
                                                    onDeleted:
                                                        isBusy ||
                                                            templates.isLoading
                                                        ? null
                                                        : () => removeTemplate(
                                                            template,
                                                          ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                  IconButton(
                                    tooltip: '슬라이드 추가',
                                    onPressed: isBusy ? null : () => addSlide(),
                                    icon: const Icon(Icons.add_rounded),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: AppColors.line),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ReorderableListView.builder(
                          key: const ValueKey('workout-slide-list'),
                          scrollController: slideScroll,
                          itemExtent: rowExtent,
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                          buildDefaultDragHandles: false,
                          itemCount: draft.value.modules.length,
                          onReorderItem: (oldIndex, newIndex) {
                            final list = [...draft.value.modules];
                            final item = list.removeAt(oldIndex);
                            list.insert(newIndex, item);
                            draft.value = draft.value.copyWith(modules: list);
                          },
                          proxyDecorator: (child, index, animation) => Material(
                            elevation: 8,
                            borderRadius: BorderRadius.circular(9),
                            child: child,
                          ),
                          itemBuilder: (context, index) {
                            final module = draft.value.modules[index];
                            final intervalBlocks = effectiveIntervalBlocks(
                              module,
                            );
                            Future<void> edit() async {
                              await context.push(
                                '/editor/${isNew ? 'new' : draft.value.id}/slides/${module.id}',
                                extra: SlideEditRequest(
                                  module: module,
                                  workout: draft.value.copyWith(
                                    name: name.text,
                                    folder: folder.text,
                                    brandL: brandL.text,
                                    brandR: brandR.text,
                                  ),
                                  brandL: brandL.text,
                                  brandR: brandR.text,
                                  onSave: (updated) async {
                                    final candidate = draft.value.copyWith(
                                      modules: draft.value.modules
                                          .map(
                                            (m) => m.id == updated.id
                                                ? updated
                                                : m,
                                          )
                                          .toList(),
                                    );
                                    return await persist(edited: candidate) !=
                                        null;
                                  },
                                ),
                              );
                            }

                            return Card(
                              key: ValueKey(module.id),
                              elevation: 0,
                              color: AppColors.surface,
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppStyle.controlRadius,
                                ),
                              ),
                              child: ListTile(
                                onTap: isBusy ? null : edit,
                                selected: selectedSlide.value == module.id,
                                selectedTileColor: AppColors.selected,
                                leading: ReorderableDragStartListener(
                                  index: index,
                                  child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(Icons.drag_handle),
                                  ),
                                ),
                                title: Text(
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  module.name.isEmpty
                                      ? '슬라이드 ${index + 1}'
                                      : module.name,
                                ),
                                subtitle: Text(
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  intervalBlocks.length == 1
                                      ? '${intervalBlocks.first.sets}세트 · ${formatSlideTime(intervalBlocks.first.workSeconds)} / 휴식 ${formatSlideTime(intervalBlocks.first.restSeconds)}'
                                      : '${intervalBlocks.length}블록 · 총 ${durationLabel(workoutModuleDuration(module))}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      durationLabel(
                                        workoutModuleDuration(module),
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: XonColors.muted,
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      enabled: !isBusy,
                                      tooltip: '슬라이드 메뉴',
                                      itemBuilder: (_) => [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('수정'),
                                        ),
                                        PopupMenuItem(
                                          value: 'duplicate',
                                          child: Text('복제'),
                                        ),
                                        PopupMenuItem(
                                          value: 'template',
                                          enabled:
                                              templates.hasValue &&
                                              !templates.isLoading,
                                          child: const Text('자주 쓰는 슬라이드로 저장'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('삭제'),
                                        ),
                                      ],
                                      onSelected: (action) async {
                                        if (action == 'edit') {
                                          await edit();
                                          return;
                                        }
                                        if (action == 'template') {
                                          await saveTemplate(module);
                                          return;
                                        }
                                        final modules = [
                                          ...draft.value.modules,
                                        ];
                                        if (action == 'duplicate') {
                                          modules.insert(
                                            index + 1,
                                            module.copyWith(
                                              id: newId(),
                                              name: nextSlideName(modules),
                                            ),
                                          );
                                        } else {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (dialogContext) =>
                                                AppAlertDialog(
                                                  title: const Text(
                                                    '슬라이드를 삭제할까요?',
                                                  ),
                                                  content: Text(
                                                    '“${module.name}” 슬라이드를 목록에서 제거합니다.',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            dialogContext,
                                                            false,
                                                          ),
                                                      child: const Text('취소'),
                                                    ),
                                                    FilledButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            dialogContext,
                                                            true,
                                                          ),
                                                      child: const Text('삭제'),
                                                    ),
                                                  ],
                                                ),
                                          );
                                          if (confirmed != true ||
                                              !context.mounted) {
                                            return;
                                          }
                                          modules.removeAt(index);
                                        }
                                        draft.value = draft.value.copyWith(
                                          modules: modules,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
