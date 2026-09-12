import 'package:cloud_board/src/app/core/widgets/app_dropdown_form_field.dart';
import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
import 'package:flutter/material.dart';
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
    final selectedFolder = useState<String?>(null);
    final page = useState(0);
    final scroll = useScrollController();
    final refreshing = useState(false);
    final workouts = ref.watch(workoutControllerProvider);
    final items = workouts.value ?? const <Workout>[];
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

    return AsyncActionOverlay(
      isLoading: isBusy,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          titleSpacing: 24,
          title: const _Logo(),
          actions: [
            _SettingsMenu(user: user, isBusy: isBusy),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _WorkoutToolbar(
                search: search,
                folders: folders,
                selectedFolder: folder,
                onSearchChanged: (_) => changePage(0),
                onClearSearch: () {
                  search.clear();
                  changePage(0);
                },
                onFolderChanged: (value) {
                  selectedFolder.value = value;
                  changePage(0);
                },
                refreshing: refreshing.value,
                onRefresh: isBusy || refreshing.value ? null : refresh,
              ),
              if (filtered.isNotEmpty)
                _Pagination(
                  count: filtered.length,
                  page: currentPage,
                  pageCount: pageCount,
                  onChanged: changePage,
                ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Divider(height: 1),
              ),
              Expanded(
                child: AsyncValueWidget<List<Workout>>(
                  value: workouts,
                  onRetry: refreshing.value ? null : refresh,
                  data: (items) => RefreshIndicator(
                    onRefresh: refresh,
                    child: items.isEmpty || filtered.isEmpty
                        ? CustomScrollView(
                            key: const ValueKey('workout-empty-scroll'),
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: items.isEmpty
                                    ? const _EmptyWorkouts()
                                    : const Center(child: Text('검색 결과가 없습니다.')),
                              ),
                            ],
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
          ),
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: '워크아웃 추가',
          onPressed: isBusy ? null : () => context.push('/editor/new'),
          child: const Icon(Icons.add_rounded),
        ),
      ),
    );
  }
}

class _WorkoutToolbar extends StatelessWidget {
  const _WorkoutToolbar({
    required this.search,
    required this.folders,
    required this.selectedFolder,
    required this.onFolderChanged,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onRefresh,
    required this.refreshing,
  });

  final TextEditingController search;
  final List<String> folders;
  final String? selectedFolder;
  final ValueChanged<String?> onFolderChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback? onRefresh;
  final bool refreshing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 952),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final searchField = TextField(
              controller: search,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: '워크아웃 또는 폴더 검색',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: SlideEditorStyle.muted,
                ),
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '검색 지우기',
                        onPressed: onClearSearch,
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            );
            final controls = Row(
              children: [
                Expanded(
                  child: AppDropdownFormField<String>(
                    key: ValueKey(selectedFolder),
                    initialValue: selectedFolder ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '폴더',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('모든 폴더')),
                      for (final folder in folders)
                        DropdownMenuItem(
                          value: folder,
                          child: Text(folder, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) =>
                        onFolderChanged(value == '' ? null : value),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  tooltip: '워크아웃 새로고침',
                  style: IconButton.styleFrom(
                    backgroundColor: SlideEditorStyle.surface,
                    foregroundColor: SlideEditorStyle.accent,
                    minimumSize: Size.square(AppStyle.of(context).buttonHeight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppStyle.controlRadius,
                      ),
                    ),
                  ),
                  onPressed: onRefresh,
                  icon: refreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            );
            if (constraints.maxWidth < 592) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [searchField, const SizedBox(height: 16), controls],
              );
            }
            return Row(
              children: [
                Expanded(flex: 3, child: searchField),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: controls),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.count,
    required this.page,
    required this.pageCount,
    required this.onChanged,
  });
  final int count, page, pageCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppStyle.cardWidth * 2 + 60),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '워크아웃 $count개',
                style: const TextStyle(
                  color: SlideEditorStyle.muted,
                  fontSize: 13,
                ),
              ),
            ),
            IconButton(
              tooltip: '이전 페이지',
              onPressed: page > 0 ? () => onChanged(page - 1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Semantics(
              label: '전체 $pageCount페이지 중 ${page + 1}페이지',
              liveRegion: true,
              child: Text(
                '${page + 1} / $pageCount',
                key: const ValueKey('workout-page-indicator'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: '다음 페이지',
              onPressed: page + 1 < pageCount
                  ? () => onChanged(page + 1)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    ),
  );
}

class _WorkoutGrid extends StatelessWidget {
  const _WorkoutGrid({
    required this.items,
    required this.isBusy,
    required this.controller,
  });

  final List<Workout> items;
  final bool isBusy;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppStyle.cardWidth * 2 + 60),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = !AppStyle.of(context).compact
              ? 3
              : constraints.maxWidth < 360
              ? 1
              : 2;
          final cardWidth =
              (constraints.maxWidth - 48 - (columns - 1) * 12) / columns;
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          return GridView.builder(
            key: const ValueKey('workout-grid'),
            controller: controller,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              AppStyle.of(context).floatingSize + 40,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: AppStyle.of(context).compact
                  ? cardWidth * 9 / 16 + 138 * textScale
                  : AppStyle.cardMinHeight + 138 * (textScale - 1),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length + 1,
            itemBuilder: (context, index) => index == 0
                ? _AddWorkoutCard(isBusy: isBusy)
                : _WorkoutCard(workout: items[index - 1], isBusy: isBusy),
          );
        },
      ),
    ),
  );
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) => const Text(
    'CloudBoard',
    style: TextStyle(fontWeight: FontWeight.w900, color: XonColors.black),
  );
}

enum _SettingsAction { displays, operations, profile, logout }

class _SettingsMenu extends ConsumerWidget {
  const _SettingsMenu({required this.user, required this.isBusy});

  final AuthUser? user;
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(displayDevicesProvider).value ?? const [];
    final onlineCount = devices.where((device) => device.online).length;
    return PopupMenuButton<_SettingsAction>(
      tooltip: '설정',
      icon: const Icon(Icons.settings_outlined),
      enabled: !isBusy,
      onSelected: (action) async {
        switch (action) {
          case _SettingsAction.displays:
            context.push('/displays');
          case _SettingsAction.operations:
            context.push('/operations');
          case _SettingsAction.profile:
            context.push('/profile');
          case _SettingsAction.logout:
            await ref.read(authControllerProvider.notifier).signOut();
        }
      },
      itemBuilder: (_) => [
        if (user != null) ...[
          PopupMenuItem(
            enabled: false,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _Avatar(user: user!, radius: 20),
              title: Text(user!.displayName),
              subtitle: Text(user!.email),
            ),
          ),
          const PopupMenuDivider(),
        ],
        PopupMenuItem(
          value: _SettingsAction.displays,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.connected_tv_rounded),
            title: const Text('디스플레이 설정'),
            subtitle: Text('온라인 $onlineCount / 등록 ${devices.length}'),
          ),
        ),
        if (user != null) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: _SettingsAction.operations,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.storefront_rounded),
              title: Text('매장 운영'),
              subtitle: Text('예약 · 브랜드 · 리포트'),
            ),
          ),
          const PopupMenuItem(
            value: _SettingsAction.profile,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.manage_accounts_outlined),
              title: Text('프로필 조회 및 변경'),
            ),
          ),
          const PopupMenuItem(
            value: _SettingsAction.logout,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.logout_rounded),
              title: Text('로그아웃'),
            ),
          ),
        ],
      ],
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

class _AddWorkoutCard extends StatelessWidget {
  const _AddWorkoutCard({required this.isBusy});
  final bool isBusy;

  @override
  Widget build(BuildContext context) => Material(
    color: SlideEditorStyle.surface,
    borderRadius: BorderRadius.circular(AppStyle.cardRadius),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: isBusy ? null : () => context.push('/editor/new'),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_rounded, size: 40, color: SlideEditorStyle.accent),
          SizedBox(height: 8),
          Text('워크아웃 추가', style: TextStyle(color: XonColors.muted)),
        ],
      ),
    ),
  );
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.workout, required this.isBusy});

  final Workout workout;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final folder = workout.folder.isEmpty ? '폴더 없음' : workout.folder;
    final imageSource = workout.modules.firstOrNull?.imageSource ?? '';
    return Material(
      color: SlideEditorStyle.surface,
      borderRadius: BorderRadius.circular(AppStyle.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isBusy ? null : () => context.push('/editor/${workout.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ExcludeSemantics(
                child: imageSource.isEmpty
                    ? const Center(
                        child: Icon(
                          Icons.view_carousel_outlined,
                          size: 36,
                          color: AppColors.selected,
                        ),
                      )
                    : WorkoutImage(source: imageSource, fit: BoxFit.contain),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workout.name.isEmpty ? '이름 없음' : workout.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppStyle.of(context).subText3,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$folder · ${workout.modules.length}개 슬라이드',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: XonColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 4, bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      durationLabel(workoutDuration(workout)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
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
  const _WorkoutActions({required this.workout, required this.isBusy});

  final Workout workout;
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: '재생',
        onPressed: workout.modules.isEmpty || isBusy
            ? null
            : () => _play(context, ref),
        icon: const Icon(Icons.play_arrow_rounded),
      ),
      PopupMenuButton<_WorkoutAction>(
        tooltip: '워크아웃 메뉴',
        enabled: !isBusy,
        onSelected: (action) => _handleAction(context, ref, action),
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: _WorkoutAction.edit,
            child: ListTile(
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
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline, color: Colors.red),
              title: Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    ],
  );

  Future<void> _play(BuildContext context, WidgetRef ref) async {
    final selection = await showWorkoutPreflight(context, workout);
    if (selection == null || !context.mounted) return;
    final steps = buildPlayerSteps(workout);
    final sessionId = await ref
        .read(playbackActionControllerProvider.notifier)
        .start(
          workout: workout,
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
    switch (action) {
      case _WorkoutAction.edit:
        context.push('/editor/${workout.id}');
      case _WorkoutAction.duplicate:
        await ref
            .read(workoutActionControllerProvider.notifier)
            .duplicate(workout, newId());
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
