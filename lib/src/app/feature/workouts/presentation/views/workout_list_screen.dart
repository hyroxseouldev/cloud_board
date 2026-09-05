import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/async_action_overlay.dart';
import '../../../../core/widgets/async_value_widget.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../device/presentation/widgets/device_mode_menu.dart';
import '../../../playback/presentation/controllers/playback_session_controller.dart';
import '../../domain/entities/workout.dart';
import '../controllers/player_controller.dart';
import '../controllers/workout_controller.dart';

String durationLabel(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
int workoutDuration(Workout workout) => workout.modules.fold(
  0,
  (sum, module) =>
      sum +
      (module.workSeconds * module.sets) +
      (module.restSeconds * (module.sets - 1)),
);
String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

class WorkoutListScreen extends ConsumerWidget {
  const WorkoutListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          title: const _Logo(),
          actions: [
            const DeviceModeMenu(),
            if (user != null) _UserMenu(user: user, isBusy: isBusy),
            const SizedBox(width: 8),
          ],
        ),
        body: AsyncValueWidget<List<Workout>>(
          value: workouts,
          data: (items) => items.isEmpty
              ? const _EmptyWorkouts()
              : _WorkoutGrid(items: items, isBusy: isBusy),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: isBusy ? null : () => context.push('/editor/new'),
          icon: const Icon(Icons.add_rounded),
          label: const Text('새 워크아웃'),
        ),
      ),
    );
  }
}

class _WorkoutGrid extends StatelessWidget {
  const _WorkoutGrid({required this.items, required this.isBusy});

  final List<Workout> items;
  final bool isBusy;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1500
          ? 3
          : constraints.maxWidth >= 900
          ? 2
          : 1;
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent: columns == 1 ? 230 : 210,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) =>
            _WorkoutCard(workout: items[index], isBusy: isBusy),
      );
    },
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

enum _UserAction { profile, logout }

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
          if (action == _UserAction.profile) {
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

class _WorkoutCard extends ConsumerWidget {
  const _WorkoutCard({required this.workout, required this.isBusy});
  final Workout workout;
  final bool isBusy;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: XonColors.black, width: 2),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                workout.name.isEmpty ? '이름 없음' : workout.name,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (workout.folder.isNotEmpty) Chip(label: Text(workout.folder)),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '${workout.modules.length}개 슬라이드 · '
          '${durationLabel(workoutDuration(workout))} · '
          '작성자 ${workout.author.displayName}',
          style: const TextStyle(color: XonColors.muted),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            OutlinedButton(
              onPressed: isBusy
                  ? null
                  : () => context.push('/editor/${workout.id}'),
              child: const Text('편집'),
            ),
            OutlinedButton(
              onPressed: isBusy
                  ? null
                  : () async {
                      final success = await ref
                          .read(workoutActionControllerProvider.notifier)
                          .duplicate(workout, newId());
                      if (!success) return;
                    },
              child: const Text('복사'),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: isBusy
                  ? null
                  : () async {
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
                        final success = await ref
                            .read(workoutActionControllerProvider.notifier)
                            .delete(workout.id);
                        if (!success) return;
                      }
                    },
              child: const Text('삭제'),
            ),
            FilledButton.icon(
              onPressed: workout.modules.isEmpty
                  ? null
                  : isBusy
                  ? null
                  : () async {
                      final steps = buildPlayerSteps(workout);
                      final sessionId = await ref
                          .read(playbackActionControllerProvider.notifier)
                          .start(
                            workout: workout,
                            stepIndex: 0,
                            durationMs: steps.first.duration * 1000,
                          );
                      if (sessionId != null && context.mounted) {
                        context.push(
                          '/player/${workout.id}?session=$sessionId',
                        );
                      }
                    },
              icon: const Icon(Icons.play_arrow),
              label: const Text('재생'),
            ),
          ],
        ),
      ],
    ),
  );
}
