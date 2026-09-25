import 'dart:math' as math;

import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_edit_access.dart';
import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_board/src/app/core/theme/app_style.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_editor_style.dart';
import 'package:cloud_board/src/app/core/widgets/async_action_overlay.dart';
import 'package:cloud_board/src/app/core/widgets/async_value_widget.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_summary.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_preflight_dialog.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image.dart';

class WorkoutListScreen extends StatelessWidget {
  const WorkoutListScreen({super.key});

  @override
  Widget build(BuildContext context) => Theme(
    data: SlideEditorStyle.theme(Theme.of(context)),
    child: const _WorkoutListBody(),
  );
}

class _WorkoutListBody extends HookConsumerWidget {
  const _WorkoutListBody();
  static const _pageSize = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = useTextEditingController();
    useListenable(search);
    final searchOpen = useState(false);
    final searchFocus = useFocusNode();
    final previousPage = useRef(0);
    final previousOffset = useRef(0.0);
    final pendingDrawerRoute = useRef<String?>(null);
    final selectedFolder = useState<String?>(null);
    final page = useState(0);
    final scroll = useScrollController();
    final refreshing = useState(false);
    final workouts = ref.watch(workoutControllerProvider);
    final items = workouts.value ?? const <WorkoutSummary>[];
    final folders = useMemoized(
      () =>
          items
              .map((item) => item.folder)
              .where((folder) => folder.isNotEmpty)
              .toSet()
              .toList()
            ..sort(),
      [items],
    );
    // A deleted or renamed folder must not leave an invalid dropdown selection.
    final folder = folders.contains(selectedFolder.value)
        ? selectedFolder.value
        : null;
    final query = search.text.trim().toLowerCase();
    final filtered = useMemoized(
      () =>
          items.where((item) {
            final matchesQuery =
                query.isEmpty ||
                item.name.toLowerCase().contains(query) ||
                item.folder.toLowerCase().contains(query);
            return matchesQuery && (folder == null || item.folder == folder);
          }).toList()..sort((a, b) {
            final updated = b.updatedAt.compareTo(a.updatedAt);
            return updated != 0 ? updated : a.id.compareTo(b.id);
          }),
      [items, query, folder],
    );
    final pageCount = (filtered.length / _pageSize).ceil().clamp(1, 1 << 30);
    final currentPage = page.value.clamp(0, pageCount - 1);
    final pageItems = filtered
        .skip(currentPage * _pageSize)
        .take(_pageSize)
        .toList();
    final user = ref.watch(authStateProvider).value;
    final authAction = ref.watch(authControllerProvider);
    final workoutAction = ref.watch(workoutActionControllerProvider);
    final playbackAction = ref.watch(playbackActionControllerProvider);
    ref.listen(playbackActionControllerProvider, (previous, next) {
      if (next.hasError && previous?.error != next.error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('수업 제어에 실패했습니다: ${next.error}')));
      }
    });
    final isBusy =
        authAction.isLoading ||
        workoutAction.isLoading ||
        playbackAction.isLoading;

    void changePage(int value) {
      page.value = value;
      if (scroll.hasClients) scroll.jumpTo(0);
    }

    Future<void> refresh() async {
      if (refreshing.value || isBusy) return;
      refreshing.value = true;
      try {
        await ref.read(workoutControllerProvider.notifier).refresh();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('새로고침하지 못했습니다. 다시 시도해 주세요.')),
          );
        }
      } finally {
        if (context.mounted) refreshing.value = false;
      }
    }

    void closeSearch() {
      searchFocus.unfocus();
      search.clear();
      searchOpen.value = false;
      page.value = previousPage.value;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && scroll.hasClients) {
          scroll.jumpTo(
            previousOffset.value.clamp(0, scroll.position.maxScrollExtent),
          );
        }
      });
    }

    return PopScope(
      canPop: !searchOpen.value,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && searchOpen.value) closeSearch();
      },
      child: AsyncActionOverlay(
        isLoading: authAction.isLoading || workoutAction.isLoading,
        child: Scaffold(
          drawer: _HomeDrawer(
            user: user,
            isBusy: isBusy,
            onNavigate: (drawerContext, route) {
              if (pendingDrawerRoute.value != null) return;
              pendingDrawerRoute.value = route;
              Scaffold.of(drawerContext).closeDrawer();
            },
            onClosed: () {
              // Scaffold unmounts the drawer content when its closing animation
              // is dismissed. onDrawerChanged(false) fires too early (at start).
              final route = pendingDrawerRoute.value;
              pendingDrawerRoute.value = null;
              if (route == null) return;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted &&
                    ModalRoute.of(context)?.isCurrent == true) {
                  context.push(route);
                }
              });
            },
          ),
          appBar: AppBar(
            centerTitle: false,
            titleSpacing: 0,
            leading: searchOpen.value
                ? IconButton(
                    tooltip: '검색 닫기',
                    onPressed: closeSearch,
                    icon: const Icon(Icons.arrow_back_rounded),
                  )
                : Builder(
                    builder: (context) => IconButton(
                      tooltip: '메뉴',
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: const Icon(Icons.menu_rounded),
                    ),
                  ),
            title: searchOpen.value
                ? TextField(
                    key: const ValueKey('workout-search'),
                    controller: search,
                    focusNode: searchFocus,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => searchFocus.unfocus(),
                    onChanged: (_) => changePage(0),
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: '워크아웃 또는 폴더 검색',
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  )
                : const _Logo(),
            actions: [
              if (searchOpen.value)
                IconButton(
                  tooltip: '검색 지우기',
                  onPressed: () {
                    search.clear();
                    changePage(0);
                    searchFocus.requestFocus();
                  },
                  icon: const Icon(Icons.close_rounded),
                )
              else
                IconButton(
                  tooltip: '검색',
                  onPressed: () {
                    previousPage.value = currentPage;
                    previousOffset.value = scroll.hasClients
                        ? scroll.offset
                        : 0;
                    searchOpen.value = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) searchFocus.requestFocus();
                    });
                  },
                  icon: const Icon(Icons.search_rounded),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final mobile = constraints.maxWidth < 600;
                return Column(
                  children: [
                    _HomeWidth(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!searchOpen.value &&
                                constraints.maxHeight > 440) ...[
                              Text(
                                user == null || user.displayName.trim().isEmpty
                                    ? '반가워요.'
                                    : '${user.displayName}님, 반가워요.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _DisplayStatus(
                                onPressed: isBusy
                                    ? null
                                    : () => context.push('/displays'),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '워크아웃 ${filtered.length}개',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Flexible(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: _FolderMenu(
                                      folders: folders,
                                      selected: folder,
                                      onChanged: (value) {
                                        selectedFolder.value = value;
                                        changePage(0);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (pageCount > 1)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    tooltip: '이전 페이지',
                                    onPressed: currentPage > 0
                                        ? () => changePage(currentPage - 1)
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
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '다음 페이지',
                                    onPressed: currentPage + 1 < pageCount
                                        ? () => changePage(currentPage + 1)
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
                    Expanded(
                      child: AsyncValueWidget<List<WorkoutSummary>>(
                        value: workouts,
                        onRetry: refreshing.value ? null : refresh,
                        data: (items) => RefreshIndicator(
                          onRefresh: refresh,
                          child: items.isEmpty || filtered.isEmpty
                              ? CustomScrollView(
                                  key: const ValueKey('workout-empty-scroll'),
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  slivers: [
                                    SliverFillRemaining(
                                      hasScrollBody: false,
                                      child: items.isEmpty
                                          ? const _EmptyWorkouts()
                                          : const Center(
                                              child: Text('검색 결과가 없습니다.'),
                                            ),
                                    ),
                                  ],
                                )
                              : mobile
                              ? _WorkoutList(
                                  items: pageItems,
                                  isBusy: isBusy,
                                  controller: scroll,
                                )
                              : _WorkoutGrid(
                                  items: pageItems,
                                  isBusy: isBusy,
                                  controller: scroll,
                                ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: '워크아웃 추가',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            onPressed: isBusy ? null : () => context.push('/editor/new'),
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ),
    );
  }
}

class _HomeWidth extends StatelessWidget {
  const _HomeWidth({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: kIsWeb
            ? AppStyle.webPageMaxWidth
            : AppStyle.cardWidth * 2 + 60,
      ),
      child: child,
    ),
  );
}

class _FolderMenu extends StatelessWidget {
  const _FolderMenu({
    required this.folders,
    required this.selected,
    required this.onChanged,
  });
  final List<String> folders;
  final String? selected;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: '폴더 선택',
    initialValue: selected ?? '',
    onSelected: (value) => onChanged(value.isEmpty ? null : value),
    itemBuilder: (_) => [
      CheckedPopupMenuItem(
        value: '',
        checked: selected == null,
        child: const Text('모든 폴더'),
      ),
      for (final folder in folders)
        CheckedPopupMenuItem(
          value: folder,
          checked: selected == folder,
          child: Text(folder),
        ),
    ],
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              selected ?? '모든 폴더',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: AppColors.accent),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: AppColors.accent,
          ),
        ],
      ),
    ),
  );
}

class _DisplayStatus extends ConsumerWidget {
  const _DisplayStatus({required this.onPressed});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(displayDevicesProvider);
    final count = devices.value?.where((d) => d.paired && d.online).length ?? 0;
    final label = devices.hasError
        ? '디스플레이 상태 확인 필요'
        : !devices.hasValue
        ? '디스플레이 상태 확인 중'
        : count == 0
        ? '디스플레이 연결하기'
        : '디스플레이 $count대 연결됨';
    final color = devices.hasValue && !devices.hasError && count > 0
        ? const Color(0xFF287858)
        : AppColors.muted;
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 44),
        alignment: Alignment.centerLeft,
        foregroundColor: color,
        textStyle: const TextStyle(fontFamily: 'Pretendard', fontSize: 13),
      ),
      icon: const Icon(Icons.desktop_windows_outlined, size: 20),
      label: Text(label),
    );
  }
}

class _WorkoutList extends StatelessWidget {
  const _WorkoutList({
    required this.items,
    required this.isBusy,
    required this.controller,
  });
  final List<WorkoutSummary> items;
  final bool isBusy;
  final ScrollController controller;
  @override
  Widget build(BuildContext context) => ListView.separated(
    key: const ValueKey('workout-list'),
    controller: controller,
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
    itemCount: items.length,
    separatorBuilder: (_, _) => const Divider(height: 1),
    itemBuilder: (_, index) => Column(
      children: [
        _WorkoutRow(workout: items[index], isBusy: isBusy),
        if (index == items.length - 1) const Divider(height: 1),
      ],
    ),
  );
}

class _WorkoutRow extends ConsumerWidget {
  const _WorkoutRow({required this.workout, required this.isBusy});
  final WorkoutSummary workout;
  final bool isBusy;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editBlocked = workoutEditBlockReason(
      ref.watch(activePlaybackSessionProvider),
      workout.id,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
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
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox.square(
                      key: ValueKey('workout-thumbnail-${workout.id}'),
                      dimension: 60,
                      child: workout.imageSource.isEmpty
                          ? const ColoredBox(
                              color: AppColors.surface,
                              child: Icon(
                                Icons.view_carousel_outlined,
                                color: AppColors.muted,
                              ),
                            )
                          : WorkoutImage(
                              source: workout.imageSource,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workout.name.isEmpty ? '이름 없음' : workout.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${workout.folder.isEmpty ? '폴더 없음' : workout.folder} · ${workout.moduleCount}개 슬라이드',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          durationLabel(workout.durationSeconds),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _WorkoutActions(workout: workout, isBusy: isBusy, compact: true),
        ],
      ),
    );
  }
}

class _WorkoutGrid extends StatelessWidget {
  const _WorkoutGrid({
    required this.items,
    required this.isBusy,
    required this.controller,
  });

  final List<WorkoutSummary> items;
  final bool isBusy;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const horizontalPadding = 24.0;
      const gap = 12.0;
      final gridWidth = math.min(
        constraints.maxWidth,
        kIsWeb ? AppStyle.webPageMaxWidth : AppStyle.cardWidth * 2 + 60,
      );
      final columns = !AppStyle.of(context).compact
          ? 3
          : gridWidth < 360
          ? 1
          : 2;
      final cardWidth =
          (gridWidth - horizontalPadding * 2 - (columns - 1) * gap) / columns;
      final textScaler = MediaQuery.textScalerOf(context);
      final detailsHeight =
          12 +
          (textScaler.scale(18) * 1.25).ceilToDouble() +
          4 +
          (textScaler.scale(12) * 1.25).ceilToDouble() +
          12 +
          math.max(
            AppStyle.of(context).buttonHeight,
            textScaler.scale(12) * 1.25,
          ) +
          8;
      return Center(
        child: SizedBox(
          width: gridWidth,
          child: GridView.builder(
            key: const ValueKey('workout-grid'),
            controller: controller,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              24,
              horizontalPadding,
              AppStyle.of(context).floatingSize + 40,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: cardWidth * 9 / 16 + detailsHeight,
              crossAxisSpacing: gap,
              mainAxisSpacing: gap,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) =>
                _WorkoutCard(workout: items[index], isBusy: isBusy),
          ),
        ),
      );
    },
  );
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) => const Text(
    'CloudBoard',
    style: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w900,
      letterSpacing: -1,
      color: XonColors.black,
    ),
  );
}

class _HomeDrawer extends HookWidget {
  const _HomeDrawer({
    required this.user,
    required this.isBusy,
    required this.onNavigate,
    required this.onClosed,
  });
  final AuthUser? user;
  final bool isBusy;
  final void Function(BuildContext, String) onNavigate;
  final VoidCallback onClosed;
  @override
  Widget build(BuildContext context) {
    useEffect(() => onClosed, const []);
    void open(String route) => onNavigate(context, route);

    Widget destination(String label, IconData icon, String route) => ListTile(
      leading: Icon(icon),
      title: Text(label),
      enabled: !isBusy,
      onTap: () => open(route),
    );
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 8, 16),
              child: Row(
                children: [
                  const Expanded(child: _Logo()),
                  IconButton(
                    tooltip: '메뉴 닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  ListTile(
                    leading: const Icon(Icons.home_outlined),
                    title: const Text('홈'),
                    selected: true,
                    selectedTileColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  destination(
                    '즐겨찾기',
                    Icons.star_outline_rounded,
                    '/slides',
                  ),
                  const Divider(height: 32),
                  if (user != null)
                    destination(
                      '매장 관리',
                      Icons.storefront_outlined,
                      '/operations',
                    ),
                  destination(
                    '디스플레이 관리',
                    Icons.desktop_windows_outlined,
                    '/displays',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ListTile(
                leading: user == null
                    ? const Icon(Icons.account_circle_outlined)
                    : _Avatar(user: user!, radius: 20),
                title: Text(
                  user?.displayName ?? '내 계정',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: const Text('프로필 및 설정'),
                trailing: const Icon(Icons.chevron_right_rounded),
                enabled: !isBusy,
                onTap: () => open('/profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.radius});
  final AuthUser user;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    foregroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty
        ? NetworkImage(user.photoUrl!)
        : null,
    child: user.photoUrl == null || user.photoUrl!.isEmpty
        ? Text(
            user.displayName.isEmpty ? '?' : user.displayName.characters.first,
          )
        : null,
  );
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
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 6),
              Text(
                '아래 버튼으로 첫 수업을 만드세요.',
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

class _WorkoutCard extends ConsumerWidget {
  const _WorkoutCard({required this.workout, required this.isBusy});

  final WorkoutSummary workout;
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editBlocked = workoutEditBlockReason(
      ref.watch(activePlaybackSessionProvider),
      workout.id,
    );
    final folder = workout.folder.isEmpty ? '폴더 없음' : workout.folder;
    final imageSource = workout.imageSource;
    const thumbnailRadius = BorderRadius.all(Radius.circular(16));
    return Material(
      color: Colors.transparent,
      borderRadius: thumbnailRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isBusy
            ? null
            : () {
                if (editBlocked != null) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(editBlocked)));
                  return;
                }
                context.push('/editor/${workout.id}');
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              key: ValueKey('workout-thumbnail-${workout.id}'),
              aspectRatio: 16 / 9,
              child: ExcludeSemantics(
                child: imageSource.isEmpty
                    ? const DecoratedBox(
                        decoration: BoxDecoration(
                          color: SlideEditorStyle.surface,
                          borderRadius: thumbnailRadius,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.view_carousel_outlined,
                            size: 36,
                            color: AppColors.selected,
                          ),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: thumbnailRadius,
                        child: WorkoutImage(
                          source: imageSource,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workout.name.isEmpty ? '이름 없음' : workout.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$folder · ${workout.moduleCount}개 슬라이드',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: XonColors.muted,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      durationLabel(workout.durationSeconds),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _WorkoutActions(workout: workout, isBusy: isBusy),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
      IconButton(
        tooltip: '재생',
        style: compact
            ? IconButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.surface,
                minimumSize: const Size(44, 44),
                maximumSize: const Size(44, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              )
            : null,
        onPressed: workout.moduleCount == 0 || isBusy
            ? null
            : () => _play(context, ref),
        icon: const Icon(Icons.play_arrow_rounded),
      ),
      if (compact) const SizedBox(width: 6),
      PopupMenuButton<_WorkoutAction>(
        tooltip: '워크아웃 메뉴',
        style: compact
            ? IconButton.styleFrom(
                backgroundColor: AppColors.surface,
                minimumSize: const Size(44, 44),
                maximumSize: const Size(44, 44),
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
    try {
      final detail = await ref
          .read(workoutActionControllerProvider.notifier)
          .prepare(workout.id);
      if (!context.mounted) return null;
      final error = ref.read(workoutActionControllerProvider).error;
      if (error != null) throw error;
      return detail;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('운동을 불러오지 못했습니다: $error')));
      }
      return null;
    }
  }

  Future<void> _play(BuildContext context, WidgetRef ref) async {
    final detail = await _detail(context, ref);
    if (detail == null || !context.mounted) return;
    final selection = await showWorkoutPreflight(context, detail);
    if (selection == null || !context.mounted) return;
    final steps = buildPlayerSteps(detail);
    final sessionId = await ref
        .read(playbackActionControllerProvider.notifier)
        .start(
          workout: detail,
          targetDeviceIds: selection.targetDeviceIds,
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
        final detail = await _detail(context, ref);
        if (detail == null || !context.mounted) return;
        await ref
            .read(workoutActionControllerProvider.notifier)
            .duplicate(detail, newId());
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
