import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_progress.dart';
import 'package:cloud_board/src/app/feature/entitlement/presentation/widgets/plan_usage_notice.dart'
    show allowPlanAddition, showPlanLimitNotice;
import 'package:cloud_board/src/app/feature/entitlement/domain/plan_limit_failure.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/library_folder_controller.dart';
import 'package:cloud_board/src/app/core/config/app_brand.dart';
import 'package:cloud_board/src/app/core/widgets/motion/app_animated_sliver_list.dart';
import 'package:cloud_board/src/app/core/widgets/soft_rhythm_mark.dart';
import 'package:cloud_board/src/app/core/theme/app_motion.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/views/first_class_screen.dart';

import 'dart:async';

import 'dart:math' as math;

import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_edit_access.dart';
import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
import 'package:cloud_board/src/app/core/widgets/app_error_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_board/src/app/core/theme/app_style.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/home_shadcn.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shadcn;
import 'package:cloud_board/src/app/core/widgets/async_action_overlay.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_list_loading.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_list_mode_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_preparation_page.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/home_workout_thumbnail.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/services/home_thumbnail_loader.dart';

class WorkoutListScreen extends StatelessWidget {
  const WorkoutListScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const HomeShadcnScope(child: WorkoutListBody());
}

/// Home and the pushed search page share catalog rendering and action guards.
class WorkoutListBody extends HookConsumerWidget {
  const WorkoutListBody({super.key, this.searchController, this.searchFocus});
  final TextEditingController? searchController;
  final FocusNode? searchFocus;
  static const _pageSize = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = searchController;
    useListenable(search);
    final searching = search != null;
    final showCreate =
        !searching && MediaQuery.viewInsetsOf(context).bottom == 0;
    final selectedFolder = useState<String?>(null);
    final scroll = useScrollController();
    final refreshing = useState(false);
    final creating = useState(false);
    final openingSearch = useRef(false);
    final page = useState(0);
    final mode = ref.watch(workoutListModeControllerProvider);
    final showModeSelector = ref.watch(workoutListModeSelectorEnabledProvider);
    final paged = mode == WorkoutListMode.paged;
    final workouts = ref.watch(workoutControllerProvider);
    final catalog = ref.watch(workoutCatalogStatusProvider);
    final initialLoading =
        !workouts.hasValue && (workouts.isLoading || refreshing.value);
    final loading = useWorkoutLoadingPresentation(
      loading: initialLoading,
      hasData: workouts.hasValue,
    );
    final reveal = AppMotion.reduced(context)
        ? const AlwaysStoppedAnimation<double>(1)
        : loading.reveal;
    final items = workouts.value ?? const <WorkoutSummary>[];
    final knownFolders =
        ref.watch(libraryFoldersProvider).value ?? const <String>[];
    final folders = useMemoized(
      () => {
        ...knownFolders,
        ...items.map((item) => item.folder),
      }.where((folder) => folder.isNotEmpty).toList()..sort(),
      [items, knownFolders],
    );
    // A deleted or renamed folder must not leave an invalid dropdown selection.
    final folder = folders.contains(selectedFolder.value)
        ? selectedFolder.value
        : null;
    final query = search?.text.trim().toLowerCase() ?? '';
    final layout = ref.watch(homeWorkoutLayoutProvider);
    final filtered = useMemoized(
      () => items.where((item) {
        final matchesQuery =
            query.isEmpty ||
            item.name.toLowerCase().contains(query) ||
            item.folder.toLowerCase().contains(query);
        return matchesQuery && (folder == null || item.folder == folder);
      }).toList(),
      [items, query, folder],
    );
    useEffect(() {
      if (query.isEmpty && folder == null && !paged) return null;
      final debounce = Timer(const Duration(milliseconds: 250), () {
        unawaited(
          ref
              .read(workoutControllerProvider.notifier)
              .loadComplete()
              .catchError((Object _) => const <WorkoutSummary>[]),
        );
      });
      return debounce.cancel;
    }, [query, folder, paged]);
    useEffect(() {
      void requestNext() {
        if (!scroll.hasClients ||
            !workouts.hasValue ||
            refreshing.value ||
            scroll.position.extentAfter > 500 ||
            !catalog.hasMore ||
            catalog.loading ||
            catalog.error != null ||
            paged) {
          return;
        }
        unawaited(
          ref
              .read(workoutControllerProvider.notifier)
              .loadMore()
              .catchError((Object _) {}),
        );
      }

      scroll.addListener(requestNext);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) requestNext();
      });
      return () => scroll.removeListener(requestNext);
    }, [scroll, catalog, paged, items.length]);
    final pageCount = math.max(1, (filtered.length / _pageSize).ceil());
    final currentPage = page.value.clamp(0, pageCount - 1);
    final visibleItems = paged
        ? filtered.skip(currentPage * _pageSize).take(_pageSize).toList()
        : filtered;
    // If refresh/deletion removes the last page, stay on the surviving page
    // even if more items are added later.
    useEffect(() {
      final requestedPage = page.value;
      if (requestedPage != currentPage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && page.value == requestedPage) {
            page.value = currentPage;
          }
        });
      }
      return null;
    }, [currentPage, page.value]);
    final user = ref.watch(authStateProvider).value;
    // Keep one account cache alive across list/grid rebuilds and search pushes.
    ref.watch(homeThumbnailCacheProvider(user?.id ?? ''));
    final authAction = ref.watch(authControllerProvider);
    final workoutAction = ref.watch(workoutActionControllerProvider);
    final playbackAction = ref.watch(playbackActionControllerProvider);
    final isBusy =
        authAction.isLoading ||
        workoutAction.isLoading ||
        playbackAction.isLoading;

    void resetScroll() {
      if (scroll.hasClients) scroll.jumpTo(0);
    }

    void changePage(int value) {
      page.value = value;
      resetScroll();
    }

    ref.listen(workoutListModeControllerProvider, (_, _) {
      changePage(0);
    });

    Future<void> refresh() async {
      if (refreshing.value || isBusy) return;
      refreshing.value = true;
      try {
        await ref.read(workoutControllerProvider.notifier).refresh();
      } catch (_) {
        if (context.mounted && workouts.hasValue) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('새로고침하지 못했습니다. 다시 시도해 주세요.')),
          );
        }
      } finally {
        if (context.mounted) refreshing.value = false;
      }
    }

    return AsyncActionOverlay(
      isLoading: authAction.isLoading || workoutAction.isLoading,
      label: ref.watch(workoutMaterialProgressProvider),
      child: Scaffold(
        // The shell already reserves the dock and device safe area below this
        // scaffold. Keep the FAB in that remaining viewport, without guessing
        // the dock height (which also grows with accessibility text).
        floatingActionButton: !showCreate
            ? null
            : FloatingActionButton(
                key: const ValueKey('create-workout'),
                heroTag: null,
                tooltip: '수업 만들기',
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                onPressed: isBusy || creating.value
                    ? null
                    : () async {
                        if (creating.value) return;
                        creating.value = true;
                        try {
                          if (await allowPlanAddition(
                                context,
                                ref,
                                'workouts',
                              ) &&
                              context.mounted) {
                            await context.push('/editor/new');
                          }
                        } finally {
                          if (context.mounted) creating.value = false;
                        }
                      },
                child: const Icon(Icons.add_rounded, size: 28),
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        appBar: AppBar(
          toolbarHeight: searching
              ? math.max(
                  56,
                  MediaQuery.textScalerOf(context).scale(16) * 1.5 + 24,
                )
              : null,
          centerTitle: false,
          titleSpacing: searching
              ? 0
              : (MediaQuery.sizeOf(context).width < 360 ? 16 : 20),
          automaticallyImplyLeading: false,
          leading: searching
              ? IconButton(
                  tooltip: '뒤로',
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                )
              : null,
          title: searching
              ? shadcn.ShadInput(
                  key: const ValueKey('workout-search'),
                  controller: search,
                  focusNode: searchFocus,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => searchFocus?.unfocus(),
                  onChanged: (_) => changePage(0),
                  style: const TextStyle(fontSize: 16),
                  placeholder: const Text('워크아웃 또는 폴더 검색'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                )
              : const _Logo(),
          actions: [
            if (searching)
              IconButton(
                tooltip: '검색 지우기',
                onPressed: () {
                  search.clear();
                  changePage(0);
                  searchFocus?.requestFocus();
                },
                icon: const Icon(Icons.close_rounded),
              )
            else
              IconButton(
                tooltip: '검색',
                onPressed: () async {
                  if (openingSearch.value) return;
                  openingSearch.value = true;
                  final offset = scroll.hasClients ? scroll.offset : 0.0;
                  try {
                    await context.push('/search');
                  } finally {
                    if (context.mounted) openingSearch.value = false;
                  }
                  if (!context.mounted) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted && scroll.hasClients) {
                      scroll.jumpTo(
                        offset.clamp(0, scroll.position.maxScrollExtent),
                      );
                    }
                  });
                },
                icon: const Icon(Icons.search_rounded),
              ),
            if (showModeSelector)
              PopupMenuButton<WorkoutListMode>(
                tooltip: '목록 표시 방식',
                enabled: !isBusy,
                icon: const Icon(Icons.view_agenda_outlined),
                initialValue: mode,
                onSelected: ref
                    .read(workoutListModeControllerProvider.notifier)
                    .select,
                itemBuilder: (_) => [
                  CheckedPopupMenuItem(
                    value: WorkoutListMode.continuous,
                    checked: !paged,
                    child: const Text('무한 스크롤'),
                  ),
                  CheckedPopupMenuItem(
                    value: WorkoutListMode.paged,
                    checked: paged,
                    child: const Text('페이지 넘기기'),
                  ),
                ],
              ),
            if (kIsWeb)
              IconButton(
                tooltip: '새로고침',
                onPressed: !workouts.hasValue || refreshing.value || isBusy
                    ? null
                    : refresh,
                icon: refreshing.value && workouts.hasValue
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, bodyConstraints) {
            final compactViewport = bodyConstraints.maxHeight < 380;
            return SafeArea(
              top: false,
              // Normal home keeps its approved card/FAB separation. Short bodies
              // need this space to reveal a card; their trailing scroll padding
              // lets the final action move fully above the floating control.
              minimum: EdgeInsets.only(
                bottom: showCreate && !compactViewport ? 80 : 0,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final listLayout = layout == HomeWorkoutLayout.list;
                  final compactHeight = compactViewport;
                  final maxWidth = kIsWeb
                      ? AppStyle.webPageMaxWidth
                      : AppStyle.cardWidth * 2 + 60;
                  final inset =
                      (constraints.maxWidth < 360 ? 16.0 : 20.0) +
                      math.max(0, constraints.maxWidth - maxWidth) / 2;
                  // Keep the header, empty state and rows in one scrollable, so a
                  // pull can start anywhere and short lists can still overscroll.
                  return ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        ...ScrollConfiguration.of(context).dragDevices,
                        PointerDeviceKind.mouse,
                      },
                    ),
                    child: RefreshIndicator(
                      onRefresh: refresh,
                      child: CustomScrollView(
                        key: const ValueKey('workout-scroll'),
                        controller: scroll,
                        scrollCacheExtent: const ScrollCacheExtent.pixels(0),
                        physics: const AlwaysScrollableScrollPhysics(),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        slivers: [
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              inset,
                              compactHeight ? 8 : 16,
                              inset,
                              4,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!searching &&
                                      constraints.maxHeight > 440) ...[
                                    HomeWelcome(displayName: user?.displayName),
                                    _DisplayStatus(
                                      onPressed: isBusy
                                          ? null
                                          : () => context.go('/displays'),
                                    ),
                                    const SizedBox(height: 28),
                                  ],
                                  if (!searching) const FirstClassHomeCard(),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _WorkoutHeader(
                                          compact: compactHeight,
                                          count: workouts.hasValue
                                              ? '${filtered.length}개${catalog.hasMore ? ' 이상' : ''}'
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const _LayoutToggle(),
                                    ],
                                  ),
                                  SizedBox(height: compactHeight ? 0 : 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: _FolderMenu(
                                            enabled: workouts.hasValue,
                                            folders: folders,
                                            selected: folder,
                                            onChanged: (value) {
                                              selectedFolder.value = value;
                                              changePage(0);
                                            },
                                          ),
                                        ),
                                      ),
                                      if (MediaQuery.textScalerOf(context)
                                              .scale(14) <=
                                          20)
                                        Expanded(
                                          child: WorkoutLoadingStatus(
                                            visible: loading.visible,
                                            delayed: loading.delayed,
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (MediaQuery.textScalerOf(context)
                                              .scale(14) >
                                          20 &&
                                      (!compactHeight || loading.visible))
                                    WorkoutLoadingStatus(
                                      visible: loading.visible,
                                      delayed: loading.delayed,
                                    ),
                                  if (paged && filtered.isNotEmpty)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          tooltip: '이전 페이지',
                                          onPressed: currentPage > 0
                                              ? () =>
                                                    changePage(currentPage - 1)
                                              : null,
                                          icon: const Icon(
                                            Icons.chevron_left_rounded,
                                          ),
                                        ),
                                        Semantics(
                                          label:
                                              '전체 $pageCount페이지 중 ${currentPage + 1}페이지',
                                          liveRegion: true,
                                          child: Text(
                                            '${currentPage + 1} / $pageCount',
                                            key: const ValueKey(
                                              'workout-page-indicator',
                                            ),
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: '다음 페이지',
                                          onPressed: currentPage + 1 < pageCount
                                              ? () =>
                                                    changePage(currentPage + 1)
                                              : null,
                                          icon: const Icon(
                                            Icons.chevron_right_rounded,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (initialLoading)
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                inset,
                                listLayout || compactHeight ? 8 : 24,
                                inset,
                                24,
                              ),
                              sliver: loading.visible
                                  ? WorkoutListSkeleton(mobile: listLayout)
                                  : const SliverToBoxAdapter(
                                      child: SizedBox.shrink(),
                                    ),
                            )
                          else if (!workouts.hasValue)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: WorkoutListLoadError(onRetry: refresh),
                            )
                          else if (filtered.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: FadeTransition(
                                opacity: reveal,
                                child: items.isEmpty
                                    ? const _EmptyWorkouts()
                                    : Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text('검색 결과가 없습니다.'),
                                              const SizedBox(height: 8),
                                              TextButton(
                                                onPressed: () {
                                                  search?.clear();
                                                  selectedFolder.value = null;
                                                },
                                                child: const Text(
                                                  '검색·폴더 조건 지우기',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                              ),
                            )
                          else
                            SliverFadeTransition(
                              opacity: reveal,
                              sliver: SliverPadding(
                                padding: EdgeInsets.fromLTRB(
                                  inset,
                                  listLayout || compactHeight ? 8 : 24,
                                  inset,
                                  24,
                                ),
                                sliver: listLayout
                                    ? _WorkoutList(
                                        items: visibleItems,
                                        isBusy: isBusy,
                                        scope: (
                                          query,
                                          folder,
                                          mode,
                                          page.value,
                                        ),
                                      )
                                    : _WorkoutGrid(
                                        items: visibleItems,
                                        isBusy: isBusy,
                                      ),
                              ),
                            ),
                          if (workouts.hasValue &&
                              !refreshing.value &&
                              (catalog.loading ||
                                  catalog.hasMore ||
                                  catalog.error != null))
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  100,
                                ),
                                child: Center(
                                  child: catalog.loading
                                      ? const SizedBox.square(
                                          dimension: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : TextButton(
                                          key: const ValueKey(
                                            'workout-load-more',
                                          ),
                                          onPressed: () async {
                                            try {
                                              final controller = ref.read(
                                                workoutControllerProvider
                                                    .notifier,
                                              );
                                              if (catalog.error != null) {
                                                await controller.refresh();
                                              } else {
                                                await controller.loadMore();
                                              }
                                              if (query.isNotEmpty ||
                                                  folder != null ||
                                                  paged) {
                                                await controller.loadComplete();
                                              }
                                            } catch (_) {}
                                          },
                                          child: Text(
                                            catalog.error != null
                                                ? '목록을 불러오지 못했어요. 다시 시도'
                                                : '더 보기',
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          if (showCreate && compactViewport)
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 80),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FolderMenu extends StatelessWidget {
  const _FolderMenu({
    required this.folders,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });
  final List<String> folders;
  final String? selected;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: '폴더 선택',
    child: shadcn.ShadSelect<String>(
      // Reconcile reset/deleted folders with the controlled home filter.
      key: ValueKey(selected),
      enabled: enabled,
      initialValue: selected ?? '',
      minWidth: math.min(
        MediaQuery.sizeOf(context).width - 40,
        MediaQuery.textScalerOf(context).scale(16) * 5 + 48,
      ),
      maxWidth: MediaQuery.sizeOf(context).width - 40,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      selectedOptionBuilder: (_, value) => Text(
        value.isEmpty ? '모든 폴더' : value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onChanged: (value) => onChanged(value == '' ? null : value),
      options: [
        const shadcn.ShadOption(value: '', child: Text('모든 폴더')),
        for (final folder in folders)
          shadcn.ShadOption(value: folder, child: Text(folder)),
      ],
    ),
  );
}

class _DisplayStatus extends ConsumerWidget {
  const _DisplayStatus({required this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(displayDevicesProvider);
    final registered = devices.value?.where((d) => d.paired).toList();
    final nowMs =
        ref.watch(displayHealthNowProvider).value ??
        DateTime.now().millisecondsSinceEpoch;
    final count = registered?.where((d) => d.recentlySeen(nowMs)).length ?? 0;
    final label = devices.hasError
        ? '디스플레이 상태 확인 필요'
        : devices.isLoading || !devices.hasValue
        ? '디스플레이 상태 확인 중'
        : count == 0
        ? registered!.isEmpty
              ? '디스플레이 연결하기'
              : '등록된 디스플레이 오프라인 · TV 확인'
        : '디스플레이 $count대 온라인 · 연결 관리';
    return shadcn.ShadCard(
      padding: EdgeInsets.zero,
      backgroundColor: AppColors.surfaceAccent,
      child: shadcn.ShadButton.ghost(
        key: const ValueKey('home-display-status'),
        onPressed: onPressed,
        width: double.infinity,
        expands: true,
        enabled: onPressed != null,
        height: math.max(
          56,
          MediaQuery.textScalerOf(context).scale(13) * 2.8 + 20,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(
              devices.hasError
                  ? Icons.warning_amber_rounded
                  : Icons.desktop_windows_outlined,
              size: 21,
              color: AppColors.accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.start,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class _WorkoutList extends StatelessWidget {
  const _WorkoutList({
    required this.items,
    required this.isBusy,
    required this.scope,
  });
  final List<WorkoutSummary> items;
  final bool isBusy;
  final Object scope;
  @override
  Widget build(BuildContext context) => AppAnimatedSliverList<WorkoutSummary>(
    key: const ValueKey('workout-list'),
    items: items,
    idOf: (item) => item.id,
    scope: scope,
    itemBuilder: (_, item) => Padding(
      padding: EdgeInsets.zero,
      child: _WorkoutRow(workout: item, isBusy: isBusy),
    ),
  );
}

class _WorkoutRow extends ConsumerWidget {
  const _WorkoutRow({
    required this.workout,
    required this.isBusy,
    this.grid = false,
  });
  final WorkoutSummary workout;
  final bool isBusy;
  final bool grid;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editBlocked = workoutEditBlockReason(
      ref.watch(activePlaybackSessionProvider),
      workout.id,
    );
    final ownerId = ref.watch(authStateProvider).value?.id ?? '';
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final stacked = constraints.maxWidth < 330 || scaler.scale(17) > 23;
        final title = Text(
          workout.name.isEmpty ? '이름 없음' : workout.name,
          maxLines: grid && scaler.scale(16) <= 22 ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            height: 1.3,
            fontWeight: FontWeight.w600,
            letterSpacing: -.17,
          ),
        );
        final metadata = Text(
          '${workout.folder.isEmpty ? '폴더 없음' : workout.folder} · ${workout.moduleCount}개 슬라이드',
          maxLines: grid && scaler.scale(16) <= 22 ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppColors.muted,
          ),
        );
        final duration = Text(
          timingDurationLabel(workout.durationSeconds, workout.durationKind),
          style: const TextStyle(
            fontSize: 13,
            height: 1.4,
            color: AppColors.muted,
          ),
        );
        final thumbnail = HomeWorkoutThumbnail(
          key: ValueKey('workout-thumbnail-${workout.id}'),
          ownerId: ownerId,
          workout: workout,
          width: grid ? null : 96,
        );
        final details = InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isBusy
              ? null
              : () {
                  if (editBlocked != null) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(editBlocked)));
                  } else {
                    context.push('/editor/${workout.id}');
                  }
                },
          child: grid
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    thumbnail,
                    const SizedBox(height: 12),
                    title,
                    const SizedBox(height: 6),
                    metadata,
                  ],
                )
              : Row(
                  children: [
                    thumbnail,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          title,
                          const SizedBox(height: 6),
                          metadata,
                          const SizedBox(height: 4),
                          duration,
                        ],
                      ),
                    ),
                  ],
                ),
        );
        final actions = _WorkoutActions(
          workout: workout,
          isBusy: isBusy,
          compact: true,
        );
        if (grid) {
          final footerStacked =
              constraints.maxWidth - 20 < 106 + scaler.scale(13) * 3;
          return Container(
            key: ValueKey('workout-grid-card-${workout.id}'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                details,
                const Spacer(),
                if (footerStacked) ...[
                  duration,
                  const SizedBox(height: 6),
                  Align(alignment: Alignment.centerRight, child: actions),
                ] else
                  Row(
                    children: [
                      Expanded(child: duration),
                      const SizedBox(width: 4),
                      actions,
                    ],
                  ),
              ],
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    details,
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: 8),
                    actions,
                  ],
                ),
        );
      },
    );
  }
}

class _LayoutToggle extends ConsumerWidget {
  const _LayoutToggle();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(homeWorkoutLayoutProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final layout in HomeWorkoutLayout.values)
          Semantics(
            selected: selected == layout,
            child: Tooltip(
              message: layout == HomeWorkoutLayout.list ? '목록 보기' : '그리드 보기',
              child: shadcn.ShadButton.ghost(
                key: ValueKey('home-layout-${layout.name}'),
                width: 48,
                height: 48,
                padding: EdgeInsets.zero,
                backgroundColor: selected == layout
                    ? AppColors.selected
                    : Colors.transparent,
                onPressed: () async {
                  if (selected == layout) return;
                  final owner = ref.read(authStateProvider).value?.id;
                  final saved = await ref
                      .read(homeWorkoutLayoutProvider.notifier)
                      .select(layout);
                  if (!saved &&
                      context.mounted &&
                      ref.read(authStateProvider).value?.id == owner) {
                    AppErrorToast.show(
                      context,
                      '보기 설정을 기기에 저장하지 못했어요. 이번 방문에는 선택한 보기를 유지해요.',
                    );
                  }
                },
                child: Icon(
                  layout == HomeWorkoutLayout.list
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                  size: 21,
                  color: selected == layout
                      ? AppColors.accent
                      : AppColors.muted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WorkoutGrid extends StatelessWidget {
  const _WorkoutGrid({required this.items, required this.isBusy});
  final List<WorkoutSummary> items;
  final bool isBusy;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      return SliverGrid.builder(
        key: const ValueKey('workout-grid'),
        gridDelegate: workoutListGridDelegate(
          context,
          constraints.crossAxisExtent,
        ),
        itemCount: items.length,
        findChildIndexCallback: (key) {
          final index = items.indexWhere((item) => ValueKey(item.id) == key);
          return index < 0 ? null : index;
        },
        itemBuilder: (_, index) => KeyedSubtree(
          key: ValueKey(items[index].id),
          child: _WorkoutRow(workout: items[index], isBusy: isBusy, grid: true),
        ),
      );
    },
  );
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) => Semantics(
    label: AppBrand.name,
    excludeSemantics: true,
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SoftRhythmMark(size: 30),
        SizedBox(width: 10),
        Flexible(
          child: Text(
            AppBrand.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              letterSpacing: -.21,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    ),
  );
}

class _WorkoutHeader extends StatelessWidget {
  const _WorkoutHeader({required this.count, this.compact = false});
  final String? count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: '내 수업'),
          if (count != null)
            TextSpan(
              text: ' $count',
              style: const TextStyle(color: AppColors.secondaryText),
            ),
        ],
      ),
      style: TextStyle(
        fontSize: compact ? 16 : 20,
        letterSpacing: -.2,
        height: 1.3,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _EmptyWorkouts extends StatelessWidget {
  const _EmptyWorkouts();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Padding(
          padding: EdgeInsets.all(34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.dashboard_outlined, size: 42),
              SizedBox(height: 12),
              Text(
                '아직 워크아웃이 없어요',
                style: TextStyle(
                  fontSize: 20,
                  letterSpacing: -.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '수업 만들기로 첫 수업을 준비해 보세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: XonColors.muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

enum _WorkoutAction { edit, duplicate, delete }

class _WorkoutActions extends ConsumerWidget {
  const _WorkoutActions({
    required this.workout,
    required this.isBusy,
    this.compact = false,
  });

  final bool compact;

  final WorkoutSummary workout;
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Tooltip(
        message: '재생',
        excludeFromSemantics: true,
        child: shadcn.ShadButton.secondary(
          width: 48,
          height: 48,
          padding: EdgeInsets.zero,
          enabled: workout.moduleCount > 0 && !isBusy,
          onPressed: workout.moduleCount == 0 || isBusy
              ? null
              : () => _play(context, ref),
          child: const Icon(
            Icons.play_arrow_rounded,
            size: 26,
            semanticLabel: '재생',
          ),
        ),
      ),
      const SizedBox(width: 6),
      PopupMenuButton<_WorkoutAction>(
        tooltip: '워크아웃 메뉴',
        style: compact
            ? IconButton.styleFrom(
                backgroundColor: AppColors.surface,
                minimumSize: const Size(48, 48),
                maximumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              )
            : null,
        enabled: !isBusy,
        onSelected: (action) => _handleAction(context, ref, action),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: _WorkoutAction.edit,
            enabled:
                workoutEditBlockReason(
                  ref.read(activePlaybackSessionProvider),
                  workout.id,
                ) ==
                null,
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_outlined),
              title: Text('편집'),
            ),
          ),
          PopupMenuItem(
            value: _WorkoutAction.duplicate,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.copy_outlined),
              title: Text('복사'),
            ),
          ),
          PopupMenuDivider(),
          PopupMenuItem(
            value: _WorkoutAction.delete,
            enabled:
                workoutEditBlockReason(
                  ref.read(activePlaybackSessionProvider),
                  workout.id,
                ) ==
                null,
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline, color: Colors.red),
              title: Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    ],
  );

  Future<Workout?> _detail(BuildContext context, WidgetRef ref) async {
    // The app owns action feedback; avoid a second local error SnackBar.
    // A new tap after failure must make a fresh request, not reuse AsyncError.
    if (ref.read(workoutDetailProvider(workout.id)).hasError) {
      ref.invalidate(workoutDetailProvider(workout.id));
    }
    return ref
        .read(workoutActionControllerProvider.notifier)
        .prepare(workout.id);
  }

  Future<void> _play(BuildContext context, WidgetRef ref) async {
    final detail = await _detail(context, ref);
    if (detail == null || !context.mounted) return;
    final selection = await showWorkoutPreflight(context, detail);
    if (selection == null || !context.mounted) return;
    if (selection.localOnly) {
      await context.push('/player/${workout.id}');
      return;
    }
    final steps = buildPlayerSteps(detail);
    if (steps.isEmpty) return;
    final sessionId = await ref
        .read(playbackActionControllerProvider.notifier)
        .start(
          workout: detail,
          targetDeviceIds: selection.targetDeviceIds,
          preparationProof: selection.preparation,
          stepIndex: 0,
          durationMs: steps.first.duration * 1000,
        );
    if (sessionId != null && context.mounted) {
      context.push('/player/${workout.id}?session=$sessionId');
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    _WorkoutAction action,
  ) async {
    if (action != _WorkoutAction.duplicate) {
      final reason = workoutEditBlockReason(
        ref.read(activePlaybackSessionProvider),
        workout.id,
      );
      if (reason != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(reason)));
        return;
      }
    }
    switch (action) {
      case _WorkoutAction.edit:
        context.push('/editor/${workout.id}');
      case _WorkoutAction.duplicate:
        if (!await allowPlanAddition(context, ref, 'workouts') ||
            !context.mounted) {
          return;
        }
        final detail = await _detail(context, ref);
        if (detail == null || !context.mounted) return;
        await ref
            .read(workoutActionControllerProvider.notifier)
            .duplicate(detail, newId());
        if (context.mounted) {
          final failure = PlanLimitFailure.from(
            ref.read(workoutActionControllerProvider).error,
          );
          if (failure != null) await showPlanLimitNotice(context, failure);
        }
      case _WorkoutAction.delete:
        final delete = await showDialog<bool>(
          context: context,
          builder: (_) => AppAlertDialog(
            title: const Text('워크아웃 삭제'),
            content: Text('"${workout.name}"을 삭제할까요?'),
            actions: [
              TextButton(
                onPressed: () => context.pop(false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => context.pop(true),
                child: const Text('삭제'),
              ),
            ],
          ),
        );
        if (delete == true) {
          await ref
              .read(workoutActionControllerProvider.notifier)
              .delete(workout.id);
        }
    }
  }
}
