import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
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

class WorkoutListScreen extends HookConsumerWidget {
  const WorkoutListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = useTextEditingController();
    useListenable(search);
    final selectedFolder = useState<String?>(null);
    final workouts = ref.watch(workoutControllerProvider);
    final user = ref.watch(authStateProvider).value;
    final authAction = ref.watch(authControllerProvider);
    final workoutAction = ref.watch(workoutActionControllerProvider);
    final playbackAction = ref.watch(playbackActionControllerProvider);
    final isBusy =
        authAction.isLoading ||
        workoutAction.isLoading ||
        playbackAction.isLoading;

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
        body: AsyncValueWidget<List<Workout>>(
          value: workouts,
          data: (items) {
            if (items.isEmpty) return const _EmptyWorkouts();
            final folders =
                items
                    .map((item) => item.folder)
                    .where((folder) => folder.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();
            final query = search.text.trim().toLowerCase();
            final filtered = items.where((item) {
              final matchesQuery =
                  query.isEmpty ||
                  item.name.toLowerCase().contains(query) ||
                  item.folder.toLowerCase().contains(query);
              final matchesFolder =
                  selectedFolder.value == null ||
                  item.folder == selectedFolder.value;
              return matchesQuery && matchesFolder;
            }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
            return Column(
              children: [
                _WorkoutToolbar(
                  search: search,
                  folders: folders,
                  selectedFolder: selectedFolder.value,
                  onFolderChanged: (value) => selectedFolder.value = value,
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Divider(height: 1, color: Color(0xFFDEDDF3)),
                ),
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Text('검색 결과가 없습니다.'),
                  ),
                Expanded(
                  child: _WorkoutGrid(items: filtered, isBusy: isBusy),
                ),
              ],
            );
          },
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
  });

  final TextEditingController search;
  final List<String> folders;
  final String? selectedFolder;
  final ValueChanged<String?> onFolderChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final searchField = TextField(
              controller: search,
              decoration: const InputDecoration(
                hintText: '워크아웃 또는 폴더 검색',
                suffixIcon: Icon(Icons.search_rounded),
                filled: true,
                fillColor: Color(0xFFF5F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                  borderSide: BorderSide.none,
                ),
              ),
            );
            final controls = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: DropdownButton<String?>(
                    value: selectedFolder,
                    hint: const Text('모든 폴더'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('모든 폴더'),
                      ),
                      ...folders.map(
                        (folder) => DropdownMenuItem<String?>(
                          value: folder,
                          child: Text(folder, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: onFolderChanged,
                  ),
                ),
              ],
            );
            if (constraints.maxWidth < 640) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  searchField,
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: controls),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 12),
                controls,
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _WorkoutGrid extends StatelessWidget {
  const _WorkoutGrid({required this.items, required this.isBusy});

  final List<Workout> items;
  final bool isBusy;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 600 ? 2 : 3;
          final cardWidth =
              (constraints.maxWidth - 40 - (columns - 1) * 12) / columns;
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          return GridView.builder(
            key: const ValueKey('workout-grid'),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: cardWidth * 9 / 16 + 138 * textScale,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length + 1,
            itemBuilder: (context, index) => index == items.length
                ? _AddWorkoutCard(isBusy: isBusy)
                : _WorkoutCard(workout: items[index], isBusy: isBusy),
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
          border: Border.all(color: XonColors.line, width: 2),
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
    color: const Color(0xFFF5F5F9),
    borderRadius: BorderRadius.circular(4),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: isBusy ? null : () => context.push('/editor/new'),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_rounded, size: 40, color: XonColors.muted),
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
      color: const Color(0xFFF5F5F9),
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isBusy ? null : () => context.push('/editor/${workout.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ExcludeSemantics(
                child: imageSource.isEmpty
                    ? const Center(
                        child: Icon(
                          Icons.view_carousel_outlined,
                          size: 36,
                          color: Color(0xFFC6C5D5),
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
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
            const Spacer(),
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
          builder: (_) => AlertDialog(
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
