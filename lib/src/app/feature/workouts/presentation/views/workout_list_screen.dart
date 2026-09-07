import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/async_action_overlay.dart';
import 'package:cloud_board/src/app/core/widgets/async_value_widget.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/auth/domain/entities/auth_user.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/device_mode_menu.dart';
import 'package:cloud_board/src/app/feature/device/presentation/widgets/paired_devices_button.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_preflight_dialog.dart';

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
          centerTitle: true,
          title: const _Logo(),
          actions: [
            const PairedDevicesButton(),
            const DeviceModeMenu(),
            if (user != null) _UserMenu(user: user, isBusy: isBusy),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: search,
                              decoration: const InputDecoration(
                                hintText: '워크아웃 또는 폴더 검색',
                                prefixIcon: Icon(Icons.search_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          DropdownButton<String?>(
                            value: selectedFolder.value,
                            hint: const Text('모든 폴더'),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('모든 폴더'),
                              ),
                              ...folders.map(
                                (folder) => DropdownMenuItem<String?>(
                                  value: folder,
                                  child: Text(folder),
                                ),
                              ),
                            ],
                            onChanged: (value) => selectedFolder.value = value,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('검색 결과가 없습니다.'))
                      : _WorkoutList(items: filtered, isBusy: isBusy),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: isBusy ? null : () => context.push('/editor/new'),
          child: const Icon(Icons.add_rounded),
        ),
      ),
    );
  }
}

class _WorkoutList extends StatelessWidget {
  const _WorkoutList({required this.items, required this.isBusy});

  final List<Workout> items;
  final bool isBusy;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) =>
            _WorkoutTile(workout: items[index], isBusy: isBusy),
      ),
    ),
  );
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) => const Text(
    'CloudBoard',
    style: TextStyle(fontWeight: FontWeight.w900, color: XonColors.cobalt),
  );
}

enum _UserAction { operations, profile, logout }

class _UserMenu extends ConsumerWidget {
  const _UserMenu({required this.user, required this.isBusy});

  final AuthUser user;
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      PopupMenuButton<_UserAction>(
        tooltip: '사용자 메뉴',
        enabled: !isBusy,
        onSelected: (action) {
          if (action == _UserAction.operations) {
            context.push('/operations');
          } else if (action == _UserAction.profile) {
            context.push('/profile');
          } else {
            ref.read(authControllerProvider.notifier).signOut();
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            enabled: false,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _Avatar(user: user, radius: 20),
              title: Text(user.displayName),
              subtitle: Text(user.email),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: _UserAction.operations,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.storefront_rounded),
              title: Text('매장 운영'),
              subtitle: Text('예약 · 브랜드 · 리포트'),
            ),
          ),
          const PopupMenuItem(
            value: _UserAction.profile,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.manage_accounts_outlined),
              title: Text('프로필 조회 및 변경'),
            ),
          ),
          const PopupMenuItem(
            value: _UserAction.logout,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.logout_rounded),
              title: Text('로그아웃'),
            ),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _Avatar(user: user, radius: 18),
        ),
      );
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

class _WorkoutTile extends ConsumerWidget {
  const _WorkoutTile({required this.workout, required this.isBusy});

  final Workout workout;
  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folderPrefix = workout.folder.isEmpty ? '' : '${workout.folder} · ';
    final author = workout.author.displayName.isEmpty
        ? '작성자 정보 없음'
        : '작성자 ${workout.author.displayName}';

    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: XonColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        enabled: !isBusy,
        onTap: isBusy ? null : () => context.push('/editor/${workout.id}'),
        contentPadding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        leading: CircleAvatar(
          backgroundColor: XonColors.cobalt.withValues(alpha: .1),
          foregroundColor: XonColors.cobalt,
          child: const Icon(Icons.view_carousel_outlined),
        ),
        title: Text(
          workout.name.isEmpty ? '이름 없음' : workout.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '$folderPrefix${workout.modules.length}개 슬라이드 · '
            '${durationLabel(workoutDuration(workout))}\n$author',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: XonColors.muted, height: 1.35),
          ),
        ),
        isThreeLine: true,
        trailing: Row(
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
        ),
      ),
    );
  }

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
