import 'package:cloud_board/src/app/core/theme/app_motion.dart';
import 'package:cloud_board/src/app/core/widgets/motion/app_content_transition.dart';
import 'package:cloud_board/src/app/core/widgets/motion/app_press_feedback.dart';

import 'dart:async';

import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_preflight_dialog.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/library_folder_controller.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_details.dart';
import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_page.dart';

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
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/folder_selector.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_creation_sheet.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_list_card.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_templates_controller.dart';

class WorkoutEditorScreen extends HookConsumerWidget {
  const WorkoutEditorScreen({super.key, required this.workoutId, this.guard});
  final String workoutId;
  final ExitGuard? guard;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = workoutId == 'new'
        ? const AsyncData<Workout?>(null)
        : ref.watch(workoutDetailProvider(workoutId));
    final user = ref.watch(authStateProvider).value;
    // Folder suggestions include older workouts without blocking the editor's
    // detail request or first render.
    useEffect(() {
      if (user == null) return null;
      unawaited(
        ref
            .read(workoutControllerProvider.notifier)
            .loadComplete()
            .catchError((Object _) => const <WorkoutSummary>[]),
      );
      return null;
    }, [user?.id]);
    return values.when(
      data: (detail) {
        final workout = workoutId == 'new' && user != null
            ? Workout.empty(
                newId(),
                WorkoutAuthor(
                  id: user.id,
                  displayName: user.displayName,
                  photoUrl: user.photoUrl,
                ),
              )
            : detail;
        return workout == null
            ? const Scaffold(body: Center(child: Text('워크아웃을 찾을 수 없습니다.')))
            : _EditorBody(
                key: ValueKey('${user?.id}:$workoutId'),
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
  const _WorkoutNameDialog({this.initialName = '', this.forSave = true});
  final String initialName;
  final bool forSave;
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
      title: Text(forSave ? '워크아웃 이름이 필요합니다' : '워크아웃 이름 수정'),
      content: Form(
        key: form,
        child: TextFormField(
          controller: name,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => submit(),
          decoration: InputDecoration(
            labelText: forSave ? '저장할 워크아웃 이름' : '워크아웃 이름',
          ),
          validator: (v) =>
              v == null || v.trim().isEmpty ? '이름을 입력해 주세요.' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: submit, child: Text(forSave ? '계속 저장' : '변경')),
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
        Navigator.pop(context, (name: name.text.trim(), favorite: true));
      }
    }

    return AppAlertDialog(
      title: const Text('라이브러리에 저장'),
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('내용과 타이머·화면 설정을 저장합니다. 라이브러리의 모든 슬라이드를 빠르게 추가할 수 있어요.'),
            const SizedBox(height: 16),
            TextFormField(
              controller: name,
              autofocus: true,
              maxLength: 40,
              decoration: const InputDecoration(labelText: '이름'),
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
        FilledButton(onPressed: submit, child: const Text('저장')),
      ],
    );
  }
}

class _EditorBody extends HookConsumerWidget {
  const _EditorBody({
    super.key,
    required this.initial,
    required this.isNew,
    this.guard,
  });
  final Workout initial;
  final bool isNew;
  final ExitGuard? guard;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = useState(initial);
    final savedBaseline = useState(initial);
    final hasPersisted = useState(!isNew);
    final name = useTextEditingController(text: initial.name);
    final folder = useTextEditingController(text: initial.folder);
    final slideScroll = useScrollController();
    final templateScroll = useScrollController();
    final selectedSlide = useState<String?>(null);
    final rowExtent = WorkoutSlideListCard.extent(
      MediaQuery.textScalerOf(context),
    );
    const slideListPadding = EdgeInsets.fromLTRB(24, 12, 24, 96);
    useListenable(name);
    useListenable(folder);
    final templatesProvider = slideTemplatesControllerProvider(
      ref.watch(authStateProvider).value?.id ?? initial.ownerId,
    );
    final templates = ref.watch(templatesProvider);
    final favoriteTemplates = templates.value ?? <WorkoutModule>[];
    final launching = useState(false);
    final action = ref.watch(workoutActionControllerProvider);
    final uploadProgress = ref.watch(workoutUploadProgressProvider);
    final playbackAction = ref.watch(playbackActionControllerProvider);
    final isBusy =
        launching.value || action.isLoading || playbackAction.isLoading;
    bool hasUnsavedChanges() =>
        draft.value != savedBaseline.value ||
        name.text.trim() != savedBaseline.value.name ||
        folder.text.trim() != savedBaseline.value.folder;

    Future<void> editName() async {
      if (isBusy) return;
      final value = await showDialog<String>(
        context: context,
        builder: (_) =>
            _WorkoutNameDialog(initialName: name.text, forSave: false),
      );
      if (value != null && context.mounted) name.text = value;
    }

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
      );
      final saved = await ref
          .read(workoutActionControllerProvider.notifier)
          .save(value);
      if (saved != null && context.mounted) {
        hasPersisted.value = true;
        draft.value = saved;
        savedBaseline.value = saved;
      }
      return saved;
    }

    Future<void> saveInPlace() async {
      if (isBusy || (hasPersisted.value && !hasUnsavedChanges())) return;
      final saved = await persist();
      if (saved == null || !context.mounted || !isNew) return;
      // Give the dirty-state guard a frame to observe the saved baseline.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.replace('/editor/${saved.id}');
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
                    slideListPadding.vertical -
                    slideScroll.position.viewportDimension)
                .clamp(0.0, double.infinity);
        final target = (index * rowExtent).clamp(0.0, maxOffset);
        if (AppMotion.reduced(context)) {
          slideScroll.jumpTo(target);
          return;
        }
        slideScroll.animateTo(
          target,
          duration: AppMotion.duration(context, AppMotion.layout),
          curve: AppMotion.curve,
        );
      });
    }

    Future<void> editSlide(WorkoutModule module) async {
      await context.push(
        '/editor/${isNew ? 'new' : draft.value.id}/slides/${module.id}',
        extra: SlideEditRequest(
          module: module,
          needsInitialSave: !hasPersisted.value || hasUnsavedChanges(),
          workout: draft.value.copyWith(name: name.text, folder: folder.text),
          brandL: draft.value.brandL,
          brandR: draft.value.brandR,
          onSave: (updated) async {
            final candidate = draft.value.copyWith(
              modules: draft.value.modules
                  .map((m) => m.id == updated.id ? updated : m)
                  .toList(),
            );
            return await persist(edited: candidate) != null;
          },
        ),
      );
    }

    WorkoutModule addSlide([WorkoutModule? template]) {
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
      return module;
    }

    Future<void> addAiSlides() async {
      final owner = ref.read(authStateProvider).value?.id;
      final modules = await showAiSlidesPage(context);
      if (!context.mounted ||
          modules == null ||
          modules.isEmpty ||
          ref.read(authStateProvider).value?.id != owner) {
        return;
      }
      draft.value = draft.value.copyWith(
        modules: [...draft.value.modules, ...modules],
      );
      selectSlide(modules.first.id);
    }

    Future<void> chooseSlideCreation() async {
      if (isBusy) return;
      final method = await showSlideCreationSheet(context);
      if (!context.mounted) return;
      switch (method) {
        case SlideCreationMethod.blank:
          await editSlide(addSlide());
        case SlideCreationMethod.design:
          await addAiSlides();
        case null:
          return;
      }
    }

    Future<void> saveTemplate(WorkoutModule module) async {
      final templateName = await showDialog<({String name, bool favorite})>(
        context: context,
        builder: (_) => _SlideTemplateNameDialog(initialName: module.name),
      );
      if (templateName == null || !context.mounted) return;
      final saved = await ref
          .read(templatesProvider.notifier)
          .save(module, templateName.name, favorite: templateName.favorite);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? '라이브러리에 저장했습니다.'
                : ref.read(templatesProvider.notifier).lastError ??
                      '저장하지 못했습니다. 다시 시도해 주세요.',
          ),
        ),
      );
    }

    Future<void> playSlides() async {
      if (launching.value || isBusy || draft.value.modules.isEmpty) return;
      launching.value = true;
      try {
        final saved = (!hasPersisted.value || hasUnsavedChanges())
            ? await persist()
            : draft.value;
        if (saved == null || !context.mounted) return;
        final selection = await showWorkoutPreflight(context, saved);
        if (selection == null || !context.mounted) return;
        final steps = buildPlayerSteps(saved);
        if (steps.isEmpty) return;
        final id = await ref
            .read(playbackActionControllerProvider.notifier)
            .start(
              workout: saved,
              stepIndex: 0,
              durationMs: steps.first.duration * 1000,
              targetDeviceIds: selection.targetDeviceIds,
            );
        if (id != null && context.mounted) {
          launching.value = false;
          await WidgetsBinding.instance.endOfFrame;
          if (context.mounted) {
            await context.push('/player/${saved.id}?session=$id');
          }
        }
      } finally {
        if (context.mounted) launching.value = false;
      }
    }

    return UnsavedChangesGuard(
      guard: guard,
      dirty: hasUnsavedChanges(),
      blocked: isBusy,
      child: AsyncActionOverlay(
        // A mini-controller command must not obscure the editor.
        isLoading: false,
        child: Scaffold(
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: AppPressFeedback(
            enabled: !isBusy && draft.value.modules.isNotEmpty,
            child: FloatingActionButton(
              key: const ValueKey('workout-play-button'),
              tooltip: '슬라이드 실행',
              onPressed: isBusy || draft.value.modules.isEmpty
                  ? null
                  : playSlides,
              child: const Icon(Icons.play_arrow_rounded),
            ),
          ),
          appBar: AppBar(
            title: const Text(
              '워크아웃 편집',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            centerTitle: false,
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
              IconButton(
                key: const ValueKey('workout-save-button'),
                tooltip: action.isLoading
                    ? workoutSaveProgressLabel(uploadProgress)
                    : hasPersisted.value && !hasUnsavedChanges()
                    ? '저장됨'
                    : '저장',
                onPressed:
                    isBusy || (hasPersisted.value && !hasUnsavedChanges())
                    ? null
                    : saveInPlace,
                icon: AppContentTransition(
                  transitionKey: (
                    action.isLoading,
                    hasPersisted.value && !hasUnsavedChanges(),
                  ),
                  child: action.isLoading
                      ? SizedBox.square(
                          dimension: 20,
                          child: AppMotion.reduced(context)
                              ? const Icon(
                                  Icons.hourglass_empty_rounded,
                                  size: 20,
                                )
                              : const CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          hasPersisted.value && !hasUnsavedChanges()
                              ? Icons.check_rounded
                              : Icons.save_outlined,
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    key: const ValueKey('workout-name-button'),
                                    controller: name,
                                    enabled: !isBusy,
                                    readOnly: true,
                                    showCursor: false,
                                    onTap: editName,
                                    decoration: const InputDecoration(
                                      labelText: '워크아웃 이름',
                                      hintText: 'Title',
                                      isDense: true,
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
                                      ...?ref
                                          .watch(libraryFoldersProvider)
                                          .value,
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
                                    workoutDurationText(draft.value),
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: XonColors.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (action.hasError)
                              ErrorDetailsButton(
                                error: action.error,
                                stack: action.stackTrace,
                                action: 'workout.save',
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
                                            !templates.hasError &&
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
                                        : favoriteTemplates.isEmpty
                                        ? const Text(
                                            '저장한 슬라이드를 여기에서 빠르게 추가할 수 있어요',
                                            style: TextStyle(
                                              color: XonColors.muted,
                                              fontSize: 12,
                                            ),
                                          )
                                        : Scrollbar(
                                            controller: templateScroll,
                                            thumbVisibility: true,
                                            child: ListView.separated(
                                              controller: templateScroll,
                                              padding: const EdgeInsets.only(
                                                bottom: 6,
                                              ),
                                              key: const ValueKey(
                                                'workout-slide-templates',
                                              ),
                                              scrollDirection: Axis.horizontal,
                                              itemCount:
                                                  favoriteTemplates.length,
                                              separatorBuilder: (_, _) =>
                                                  const SizedBox(width: 8),
                                              itemBuilder: (context, index) {
                                                final template =
                                                    favoriteTemplates[index];
                                                return Center(
                                                  child: Tooltip(
                                                    message:
                                                        '${template.name} · ${moduleDurationText(template)} 추가',
                                                    child: InputChip(
                                                      label: ConstrainedBox(
                                                        constraints:
                                                            const BoxConstraints(
                                                              maxWidth: 180,
                                                            ),
                                                        child: Text(
                                                          template.name,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      backgroundColor:
                                                          AppColors.selected,
                                                      deleteButtonTooltipMessage:
                                                          '${template.name} 칩 삭제',
                                                      onPressed:
                                                          isBusy ||
                                                              templates
                                                                  .isLoading
                                                          ? null
                                                          : () => addSlide(
                                                              template,
                                                            ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
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
                          footer: Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 8),
                            child: Tooltip(
                              message: '슬라이드 추가',
                              child: SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  key: const ValueKey('add-slide-at-end'),
                                  onPressed: isBusy
                                      ? null
                                      : chooseSlideCreation,
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('슬라이드 추가'),
                                ),
                              ),
                            ),
                          ),
                          padding: slideListPadding,
                          buildDefaultDragHandles: false,
                          itemCount: draft.value.modules.length,
                          onReorderItem: (oldIndex, newIndex) {
                            if (isBusy ||
                                oldIndex < 0 ||
                                oldIndex >= draft.value.modules.length ||
                                newIndex < 0 ||
                                newIndex >= draft.value.modules.length) {
                              return;
                            }
                            final list = [...draft.value.modules];
                            final item = list.removeAt(oldIndex);
                            list.insert(newIndex, item);
                            draft.value = draft.value.copyWith(modules: list);
                          },
                          proxyDecorator: (child, index, animation) => Material(
                            elevation: 8,
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: child,
                          ),
                          itemBuilder: (context, index) {
                            final module = draft.value.modules[index];
                            return WorkoutSlideListCard(
                              key: ValueKey(module.id),
                              module: module,
                              index: index,
                              brandL: draft.value.brandL,
                              brandR: draft.value.brandR,
                              enabled: !isBusy,
                              onTap: isBusy ? null : () => editSlide(module),
                              selected: selectedSlide.value == module.id,
                              menu: PopupMenuButton<String>(
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
                                    child: const Text('라이브러리에 저장'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('삭제'),
                                  ),
                                ],
                                onSelected: (action) async {
                                  if (action == 'edit') {
                                    await editSlide(module);
                                    return;
                                  }
                                  if (action == 'template') {
                                    await saveTemplate(module);
                                    return;
                                  }
                                  final modules = [...draft.value.modules];
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
                                      builder: (dialogContext) => AppAlertDialog(
                                        title: const Text('슬라이드를 삭제할까요?'),
                                        content: Text(
                                          '“${module.name}” 슬라이드를 목록에서 제거합니다.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(
                                              dialogContext,
                                              false,
                                            ),
                                            child: const Text('취소'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(
                                              dialogContext,
                                              true,
                                            ),
                                            child: const Text('삭제'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed != true || !context.mounted) {
                                      return;
                                    }
                                    modules.removeAt(index);
                                  }
                                  draft.value = draft.value.copyWith(
                                    modules: modules,
                                  );
                                },
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
