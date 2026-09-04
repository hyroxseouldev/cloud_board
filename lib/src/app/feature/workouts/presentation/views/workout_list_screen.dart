import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/async_value_widget.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/workout.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const _Logo(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => context.push('/editor/new'),
              icon: const Icon(Icons.add),
              label: const Text('새 워크아웃'),
            ),
          ),
          IconButton(
            tooltip: '로그아웃',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(user.displayName),
            ),
        ],
      ),
      body: AsyncValueWidget<List<Workout>>(
        value: workouts,
        data: (items) => items.isEmpty
            ? const _EmptyWorkouts()
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
                itemCount: items.length + 1,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  if (index == items.length) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'TV에 연결한 기기에서 재생하세요. 재생 중 Space: 일시정지 · ← →: 이전/다음',
                        style: TextStyle(color: XonColors.muted, fontSize: 13),
                      ),
                    );
                  }
                  return _WorkoutCard(workout: items[index]);
                },
              ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) => const Text.rich(
    TextSpan(
      text: 'XON ',
      style: TextStyle(fontWeight: FontWeight.w900),
      children: [
        TextSpan(
          text: 'BOARD',
          style: TextStyle(color: XonColors.cobalt),
        ),
      ],
    ),
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
                '오른쪽 위 버튼으로 첫 수업을 만드세요.',
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
  const _WorkoutCard({required this.workout});
  final Workout workout;
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
          '${workout.modules.length}개 슬라이드 · ${durationLabel(workoutDuration(workout))}',
          style: const TextStyle(color: XonColors.muted),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            OutlinedButton(
              onPressed: () => context.push('/editor/${workout.id}'),
              child: const Text('편집'),
            ),
            OutlinedButton(
              onPressed: () => ref
                  .read(workoutControllerProvider.notifier)
                  .duplicate(workout, newId()),
              child: const Text('복사'),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
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
                      .read(workoutControllerProvider.notifier)
                      .delete(workout.id);
                }
              },
              child: const Text('삭제'),
            ),
            FilledButton.icon(
              onPressed: workout.modules.isEmpty
                  ? null
                  : () => context.push('/player/${workout.id}'),
              icon: const Icon(Icons.play_arrow),
              label: const Text('재생'),
            ),
          ],
        ),
      ],
    ),
  );
}
