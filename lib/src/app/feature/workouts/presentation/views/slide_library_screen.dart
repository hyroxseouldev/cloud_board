import 'package:cloud_board/src/app/core/widgets/motion/app_content_transition.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_details.dart';
import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
import 'package:cloud_board/src/app/core/widgets/app_bottom_tab_bar.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/library_folder_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_templates_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_edit_access.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';

/// Library membership is the bookmark. Legacy favorite flags no longer hide items.
class SlideLibraryScreen extends HookConsumerWidget {
  const SlideLibraryScreen({
    super.key,
    this.onSelect,
    this.initialFavoritesOnly = false,
  });
  final bool initialFavoritesOnly; // Retained for old deep links; all saved items remain visible.
  final ValueChanged<WorkoutModule>? onSelect;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = useState(1);
    final search = useTextEditingController();
    useListenable(search);
    final filter = useState<String?>(null);
    final scope = ref.watch(authStateProvider).value?.id;
    if (scope == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다.')));
    }
    final provider = slideTemplatesControllerProvider(scope);
    final templates = ref.watch(provider);
    final actions = ref.read(provider.notifier);
    final writingIds = ref.watch(slideTemplateWritesProvider(scope));
    final all = templates.value ?? const <WorkoutModule>[];
    final workouts = onSelect == null
        ? ref.watch(workoutControllerProvider)
        : const AsyncData(<WorkoutSummary>[]);
    final folders = onSelect == null
        ? ref.watch(libraryFoldersProvider)
        : const AsyncData(<String>[]);
    final folderAction = onSelect == null
        ? ref.watch(libraryFolderControllerProvider)
        : const AsyncData<void>(null);
    final workoutAction = onSelect == null
        ? ref.watch(workoutActionControllerProvider)
        : const AsyncData<String?>(null);
    final names = useMemoized(
      () => {
        ...?folders.value,
        ...all.map((m) => m.category),
        ...?workouts.value?.map((w) => w.folder),
      }.where((v) => v.isNotEmpty).toList()..sort(),
      [folders.value, all, workouts.value],
    );
    final query = search.text.trim().toLowerCase();
    final selected = filter.value == '' || names.contains(filter.value)
        ? filter.value
        : null;
    final slides = useMemoized(
      () =>
          all
              .where(
                (m) =>
                    (selected == null || m.category == selected) &&
                    '${m.name} ${m.text} ${m.category}'.toLowerCase().contains(
                      query,
                    ),
              )
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name)),
      [all, selected, query],
    );
    final items = useMemoized(
      () => (workouts.value ?? const <WorkoutSummary>[])
          .where(
            (w) =>
                (selected == null || w.folder == selected) &&
                '${w.name} ${w.folder}'.toLowerCase().contains(query),
          )
          .toList(),
      [workouts.value, selected, query],
    );
    final visibleFolders = useMemoized(
      () => names.where((name) => name.toLowerCase().contains(query)).toList(),
      [names, query],
    );
    final folderCounts = useMemoized(() {
      final counts = <String, ({int workouts, int slides})>{};
      for (final item in workouts.value ?? const <WorkoutSummary>[]) {
        final count = counts[item.folder] ?? (workouts: 0, slides: 0);
        counts[item.folder] = (
          workouts: count.workouts + 1,
          slides: count.slides,
        );
      }
      for (final item in all) {
        final count = counts[item.category] ?? (workouts: 0, slides: 0);
        counts[item.category] = (
          workouts: count.workouts,
          slides: count.slides + 1,
        );
      }
      return counts;
    }, [workouts.value, all]);
    // Library management/search needs the complete folder inventory.
    useEffect(() {
      if (onSelect == null) {
        unawaited(
          ref
              .read(workoutControllerProvider.notifier)
              .loadComplete()
              .catchError((Object _) => const <WorkoutSummary>[]),
        );
      }
      return null;
    }, [scope, onSelect == null]);
    final busy =
        templates.isLoading ||
        folderAction.isLoading ||
        workoutAction.isLoading;
    void notice(String message) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }

    Future<bool> perform(Future<bool> Function() action) async {
      final success = await action();
      if (!success) notice(actions.lastError ?? '변경하지 못했습니다. 잠시 후 다시 시도해 주세요.');
      return success;
    }

    Future<void> editDetails(WorkoutModule module) async {
      final updated = await showDialog<WorkoutModule>(
        context: context,
        builder: (_) => _LibraryDetailsDialog(module: module),
      );
      if (updated != null) {
        await perform(() => actions.updateTemplate(updated, base: module));
      }
    }

    Future<void> changeFolder(String action, String name) async {
      String? next;
      if (action != 'remove') {
        next = await libraryNameDialog(
          context,
          title: action == 'create' ? '폴더 만들기' : '폴더 이름 수정',
          initial: action == 'rename' ? name : '',
        );
        if (next == null || !context.mounted) return;
      } else if (!await _confirm(
        context,
        '폴더를 삭제할까요?',
        '안의 워크아웃과 슬라이드는 삭제되지 않고 ‘폴더 없음’으로 이동합니다.',
      )) {
        return;
      }
      if (!context.mounted) return;
      final success = await ref
          .read(libraryFolderControllerProvider.notifier)
          .change(action, action == 'create' ? next! : name, newName: next);
      if (success && context.mounted) {
        filter.value = action == 'remove' ? null : next;
        // Local list overlays must not retain pre-rename folder metadata.
        ref.invalidate(workoutControllerProvider);
        ref.invalidate(workoutDetailProvider);
        ref.invalidate(provider);
        try {
          await ref.read(workoutControllerProvider.notifier).loadComplete();
        } catch (_) {
          notice('폴더는 변경했지만 목록을 갱신하지 못했어요. 새로고침해 주세요.');
        }
      } else {
        notice('폴더를 변경하지 못했습니다. 잠시 후 다시 시도해 주세요.');
      }
    }

    Future<void> addToWorkout(WorkoutModule slide) async {
      final List<WorkoutSummary> choices;
      try {
        choices = await ref
            .read(workoutControllerProvider.notifier)
            .loadComplete();
      } catch (_) {
        notice('워크아웃 목록을 불러오지 못했어요. 다시 시도해 주세요.');
        return;
      }
      if (!context.mounted) return;
      final selectedWorkout = await showDialog<WorkoutSummary>(
        context: context,
        builder: (c) => AppAlertDialog(
          title: const Text('워크아웃에 슬라이드 추가'),
          content: SizedBox(
            width: 420,
            height: 320,
            child: choices.isEmpty
                ? const Center(child: Text('먼저 워크아웃을 만들어 주세요.'))
                : ListView.builder(
                    itemCount: choices.length,
                    itemBuilder: (context, index) {
                      final w = choices[index];
                      return ListTile(
                        key: ValueKey(w.id),
                        title: Text(w.name),
                        subtitle: Text('${w.moduleCount}개 슬라이드'),
                        onTap: () => Navigator.pop(c, w),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('취소'),
            ),
          ],
        ),
      );
      if (selectedWorkout == null || !context.mounted) return;
      final controller = ref.read(workoutActionControllerProvider.notifier);
      final detail = await controller.prepare(selectedWorkout.id);
      if (detail == null || !context.mounted) return;
      final copy = slide.copyWith(
        id: newId(),
        intervalBlocks: [
          for (final b in slide.intervalBlocks)
            b.copyWith(id: '${newId()}-${b.id}'),
        ],
      );
      final saved = await controller.save(
        detail.copyWith(modules: [...detail.modules, copy]),
      );
      notice(
        saved == null
            ? '추가하지 못했습니다. 진행 중인 수업과 연결 상태를 확인해 주세요.'
            : '슬라이드를 복사해 추가했습니다. 원본과 독립적으로 편집됩니다.',
      );
    }

    Future<void> workoutMenu(WorkoutSummary item, String action) async {
      final controller = ref.read(workoutActionControllerProvider.notifier);
      if (action == 'edit') {
        await context.push('/editor/${item.id}');
        return;
      }
      if (action == 'delete') {
        if (await _confirm(
          context,
          '워크아웃을 삭제할까요?',
          '“${item.name}” 워크아웃이 삭제됩니다. 저장한 슬라이드는 유지됩니다.',
        )) {
          if (context.mounted && !await controller.delete(item.id)) {
            notice('삭제하지 못했습니다.');
          }
        }
        return;
      }
      final detail = await controller.prepare(item.id);
      if (detail == null || !context.mounted) return;
      if (action == 'duplicate') {
        await controller.duplicate(detail, newId());
        return;
      }
      final target = await showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(
          title: const Text('폴더 이동'),
          children: [
            for (final name in ['', ...names])
              SimpleDialogOption(
                onPressed: () => Navigator.pop(c, name),
                child: Text(name.isEmpty ? '폴더 없음' : name),
              ),
          ],
        ),
      );
      if (target != null && context.mounted) {
        await controller.save(detail.copyWith(folder: target));
      }
    }

    Future<void> createSlide() async {
      final name = await libraryNameDialog(
        context,
        title: '슬라이드 저장',
        initial: '새 슬라이드',
      );
      if (name == null || !context.mounted) return;
      final module = WorkoutModule.empty(newId())
          .copyWith(name: name, category: selected ?? '', favorite: true);
      if (await perform(() => actions.createTemplate(module)) &&
          context.mounted) {
        context.push('/library/editor/${module.id}');
      }
    }

    final active = onSelect == null
        ? ref.watch(activePlaybackSessionProvider)
        : const AsyncData(null);
    return Scaffold(
      appBar: AppBar(
        title: Text(onSelect == null ? '라이브러리' : '슬라이드 빠른 삽입'),
        actions: [
          if (onSelect == null)
            IconButton(
              tooltip: tab.value == 0
                  ? '워크아웃 만들기'
                  : tab.value == 1
                  ? '슬라이드 만들기'
                  : '폴더 만들기',
              icon: const Icon(Icons.add),
              onPressed: busy
                  ? null
                  : () {
                      if (tab.value == 0) {
                        context.push('/editor/new');
                      } else if (tab.value == 1) {
                        createSlide();
                      } else {
                        changeFolder('create', '');
                      }
                    },
            ),
        ],
      ),
      bottomNavigationBar: onSelect == null
          ? AppBottomTabBar(
              selected: tab.value,
              onSelected: (value) {
                tab.value = value;
                search.clear();
              },
              items: const [
                AppBottomTab(label: '워크아웃', icon: Icons.view_list_outlined),
                AppBottomTab(label: '슬라이드', icon: Icons.star_outline_rounded),
                AppBottomTab(label: '폴더', icon: Icons.folder_outlined),
              ],
            )
          : null,
      body: AppContentTransition(
        transitionKey: tab.value,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: search,
                        decoration: InputDecoration(
                          labelText: tab.value == 0
                              ? '워크아웃 검색'
                              : tab.value == 1
                              ? '슬라이드 검색'
                              : '폴더 검색',
                          prefixIcon: const Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (tab.value != 2)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final name in <String?>[null, '', ...names])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(
                                      name == null
                                          ? '전체'
                                          : name.isEmpty
                                          ? '폴더 없음'
                                          : name,
                                    ),
                                    selected: selected == name,
                                    onSelected: (_) => filter.value = name,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (tab.value == 1)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            '저장한 슬라이드를 모아둔 곳이에요. 워크아웃에 추가하면 복사본으로 사용됩니다.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      if (templates.hasError)
                        ErrorDetailsButton(
                          error: templates.error,
                          stack: templates.stackTrace,
                          action: 'library.load',
                        ),
                      if (actions.lastFailure != null)
                        ErrorDetailsButton(
                          error: actions.lastFailure,
                          action: 'library.save',
                        ),
                      if (folderAction.hasError)
                        ErrorDetailsButton(
                          error: folderAction.error,
                          stack: folderAction.stackTrace,
                          action: 'library.folder',
                        ),
                      if (workoutAction.hasError)
                        ErrorDetailsButton(
                          error: workoutAction.error,
                          stack: workoutAction.stackTrace,
                          action: 'library.workout',
                        ),
                      if (actions.pendingDraft != null &&
                          actions.lastError != null)
                        Wrap(
                          spacing: 8,
                          children: [
                            const Text('편집 내용을 보관 중입니다.'),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => perform(
                                      () => actions.save(
                                        actions.pendingDraft!,
                                        '${actions.pendingDraft!.name} 복사',
                                      ),
                                    ),
                              child: const Text('복사본으로 저장'),
                            ),
                            TextButton(
                              onPressed: () {
                                actions.pendingDraft = null;
                                ref.invalidate(provider);
                              },
                              child: const Text('최신 내용 불러오기'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (busy) const LinearProgressIndicator(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(provider);
                      if (onSelect == null) {
                        await ref
                            .read(workoutControllerProvider.notifier)
                            .refresh();
                        await ref
                            .read(workoutControllerProvider.notifier)
                            .loadComplete();
                        ref.invalidate(workoutDetailProvider);
                        ref.invalidate(libraryFoldersProvider);
                      }
                    },
                    child: ListView.builder(
                      key: ValueKey('library-tab-${tab.value}'),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: switch (tab.value) {
                        0 => items.isEmpty ? 1 : items.length,
                        1 => slides.isEmpty ? 1 : slides.length,
                        _ => visibleFolders.isEmpty ? 1 : visibleFolders.length,
                      },
                      itemBuilder: (context, index) {
                        if (tab.value == 0) {
                          if (items.isEmpty) {
                            return const _Empty('워크아웃이 없습니다. + 버튼으로 만들어 보세요.');
                          }
                          final item = items[index];
                          return ListTile(
                            key: ValueKey(item.id),
                            leading: const Icon(Icons.view_list_outlined),
                            title: Text(item.name),
                            subtitle: Text(
                              '${item.folder.isEmpty ? '폴더 없음' : item.folder} · ${item.moduleCount}개 · ${timingDurationLabel(item.durationSeconds, item.durationKind)}',
                            ),
                            onTap: busy
                                ? null
                                : () => workoutMenu(item, 'edit'),
                            trailing: PopupMenuButton<String>(
                              enabled: !busy,
                              onSelected: (v) => workoutMenu(item, v),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  enabled:
                                      workoutEditBlockReason(active, item.id) ==
                                      null,
                                  child: const Text('편집'),
                                ),
                                const PopupMenuItem(
                                  value: 'duplicate',
                                  child: Text('복제'),
                                ),
                                PopupMenuItem(
                                  value: 'move',
                                  enabled:
                                      workoutEditBlockReason(active, item.id) ==
                                      null,
                                  child: const Text('폴더 이동'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  enabled:
                                      workoutEditBlockReason(active, item.id) ==
                                      null,
                                  child: const Text('삭제'),
                                ),
                              ],
                            ),
                          );
                        }
                        if (tab.value == 1) {
                          if (slides.isEmpty) {
                            return _Empty(
                              templates.hasError
                                  ? '불러오지 못했습니다. 아래로 당겨 다시 시도해 주세요.'
                                  : '저장한 슬라이드가 없습니다.',
                            );
                          }
                          final item = slides[index];
                          return Padding(
                            key: ValueKey(item.id),
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Card(
                              elevation: 0,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 72,
                                      child: WorkoutSlidePreview(
                                        module: item,
                                        isRest: false,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: InkWell(
                                        onTap: onSelect != null
                                            ? () => onSelect!(item)
                                            : () => context.push(
                                                '/library/editor/${item.id}',
                                              ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              '${item.category.isEmpty ? '폴더 없음' : item.category} · ${moduleDurationText(item)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (onSelect != null)
                                      TextButton(
                                        onPressed: busy
                                            ? null
                                            : () => onSelect!(item),
                                        child: const Text('삽입'),
                                      ),
                                    if (writingIds.contains(item.id))
                                      const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    PopupMenuButton<String>(
                                      tooltip: '슬라이드 관리',
                                      enabled: !busy && writingIds.isEmpty,
                                      itemBuilder: (_) => [
                                        if (onSelect == null)
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Text('슬라이드 편집'),
                                          ),
                                        const PopupMenuItem(
                                          value: 'details',
                                          child: Text('이름·폴더 수정'),
                                        ),
                                        if (onSelect == null)
                                          const PopupMenuItem(
                                            value: 'insert',
                                            child: Text('워크아웃에 추가'),
                                          ),
                                        const PopupMenuItem(
                                          value: 'duplicate',
                                          child: Text('복제'),
                                        ),
                                        const PopupMenuItem(
                                          value: 'remove',
                                          child: Text('저장 목록에서 삭제'),
                                        ),
                                      ],
                                      onSelected: (v) async {
                                        if (v == 'edit') {
                                          await context.push(
                                            '/library/editor/${item.id}',
                                          );
                                        }
                                        if (v == 'details') {
                                          await editDetails(item);
                                        }
                                        if (v == 'insert') {
                                          await addToWorkout(item);
                                        }
                                        if (v == 'duplicate') {
                                          await perform(
                                            () => actions.save(
                                              item,
                                              '${item.name} 복사',
                                            ),
                                          );
                                        }
                                        if (v == 'remove' &&
                                            context.mounted &&
                                            await _confirm(
                                              context,
                                              '저장 목록에서 삭제할까요?',
                                              '워크아웃에 이미 추가한 슬라이드는 유지됩니다.',
                                            )) {
                                          await perform(
                                            () => actions.remove(item.id),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                        if (visibleFolders.isEmpty) {
                          return const _Empty('폴더를 만들어 자료를 정리해 보세요.');
                        }
                        final name = visibleFolders[index];
                        return ListTile(
                          key: ValueKey(name),
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(name),
                          subtitle: Text(
                            '워크아웃 ${folderCounts[name]?.workouts ?? 0}개 · 슬라이드 ${folderCounts[name]?.slides ?? 0}개',
                          ),
                          onTap: () {
                            filter.value = name;
                            tab.value = 1;
                            search.clear();
                          },
                          trailing: PopupMenuButton<String>(
                            enabled: !busy,
                            onSelected: (v) => changeFolder(v, name),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text('이름 수정'),
                              ),
                              PopupMenuItem(
                                value: 'remove',
                                child: Text('폴더 삭제'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SavedSlideEditorScreen extends HookConsumerWidget {
  const SavedSlideEditorScreen({
    super.key,
    required this.id,
    required this.guard,
  });
  final String id;
  final ExitGuard guard;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다.')));
    }
    final provider = slideTemplatesControllerProvider(user.id);
    final values = ref.watch(provider);
    final original = useRef<WorkoutModule?>(null);
    original.value ??= values.value?.where((m) => m.id == id).firstOrNull;
    final baseline = useRef(original.value);
    baseline.value ??= original.value;
    if (original.value == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('슬라이드')),
        body: Center(
          child: Text(values.isLoading ? '불러오는 중…' : '저장한 슬라이드를 찾을 수 없습니다.'),
        ),
      );
    }
    return SlideEditorScreen(
      workoutId: 'library-$id',
      moduleId: id,
      guard: guard,
      request: SlideEditRequest(
        module: original.value!,
        workout: Workout.empty(
          'library-$id',
          WorkoutAuthor(
            id: user.id,
            displayName: user.displayName,
            photoUrl: user.photoUrl,
          ),
        ).copyWith(modules: [original.value!]),
        onSave: (updated) async {
          final success = await ref
              .read(provider.notifier)
              .updateTemplate(updated, base: baseline.value);
          if (success && context.mounted) {
            baseline.value =
                ref
                    .read(provider)
                    .value
                    ?.where((m) => m.id == updated.id)
                    .firstOrNull ??
                updated;
          }
          return success;
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
    child: Center(child: Text(text, textAlign: TextAlign.center)),
  );
}

Future<bool> _confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AppAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    ) ??
    false;
Future<String?> libraryNameDialog(
  BuildContext context, {
  required String title,
  String initial = '',
}) => showDialog<String>(
  context: context,
  builder: (_) => _NameDialog(title: title, initial: initial),
);

class _NameDialog extends HookWidget {
  const _NameDialog({required this.title, required this.initial});
  final String title, initial;
  @override
  Widget build(BuildContext context) {
    final name = useTextEditingController(text: initial);
    final form = useMemoized(() => GlobalKey<FormState>());
    void submit() {
      if (form.currentState!.validate()) {
        Navigator.pop(context, name.text.trim());
      }
    }

    return AppAlertDialog(
      title: Text(title),
      content: Form(
        key: form,
        child: TextFormField(
          controller: name,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(labelText: '이름'),
          validator: (v) =>
              v == null || v.trim().isEmpty ? '이름을 입력해 주세요.' : null,
          onFieldSubmitted: (_) => submit(),
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

class _LibraryDetailsDialog extends HookWidget {
  const _LibraryDetailsDialog({required this.module});
  final WorkoutModule module;
  @override
  Widget build(BuildContext context) {
    final name = useTextEditingController(text: module.name);
    final folder = useTextEditingController(text: module.category);
    final form = useMemoized(() => GlobalKey<FormState>());
    return AppAlertDialog(
      title: const Text('슬라이드 이름·폴더'),
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: name,
              maxLength: 60,
              decoration: const InputDecoration(labelText: '이름'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '이름을 입력해 주세요.' : null,
            ),
            TextFormField(
              controller: folder,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: '폴더',
                hintText: '비워두면 폴더 없음',
              ),
            ),
          ],
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
              Navigator.pop(
                context,
                module.copyWith(
                  name: name.text.trim(),
                  category: folder.text.trim(),
                ),
              );
            }
          },
          child: const Text('수정'),
        ),
      ],
    );
  }
}
