import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/starter_workouts.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/starter_workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/exploration_routes.dart';

class StarterWorkoutsScreen extends HookConsumerWidget {
  const StarterWorkoutsScreen({super.key, this.initialTemplate, this.purpose});
  final StarterWorkout? initialTemplate;
  final String? purpose;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = useState(initialTemplate ?? StarterWorkout.basics);
    final action = ref.watch(starterWorkoutControllerProvider);
    ref.listen(starterWorkoutControllerProvider, (previous, next) {
      if (next.hasError && previous?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.error is StateError
                  ? (next.error! as StateError).message
                  : '가져오지 못했습니다. 연결을 확인하고 다시 시도해 주세요.',
            ),
          ),
        );
      }
    });
    final workout = selected.value.create(
      const WorkoutAuthor(id: 'preview', displayName: '', photoUrl: null),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('시작 템플릿')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: FilledButton.icon(
            onPressed: action.isLoading
                ? null
                : () async {
                    final saved = await ref
                        .read(starterWorkoutControllerProvider.notifier)
                        .import(selected.value, owned: true);
                    if (saved != null && context.mounted) {
                      context.push('/editor/${saved.id}?guide=true');
                    }
                  },
            icon: action.isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.copy_outlined),
            label: Text(action.isLoading ? '내 수업에 저장 중…' : '내 수업으로 만들고 편집'),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '예시로 첫 수업을 준비하세요',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              '완성된 예시를 내 수업으로 가져와 제목·운동·시간을 바꿀 수 있어요. AI 생성 없이 바로 시작합니다.',
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final template in StarterWorkout.values)
                  ChoiceChip(
                    label: Text(template.title),
                    selected: selected.value == template,
                    onSelected: action.isLoading
                        ? null
                        : (_) => selected.value = template,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              selected.value.description,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${workout.modules.length}개 슬라이드 · ${workoutDurationText(workout)}',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: action.isLoading
                  ? null
                  : () => context.push(
                      starterLocation(
                        '/explore/play/${selected.value.key}',
                        null,
                        purpose: purpose,
                      ),
                    ),
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('저장 전에 이 기기에서 체험'),
            ),
            TextButton(
              onPressed: action.isLoading
                  ? null
                  : () => context.go(
                      starterLocation(
                        '/explore',
                        selected.value,
                        purpose: purpose,
                      ),
                    ),
              child: const Text('다른 예시 둘러보기'),
            ),
            const SizedBox(height: 16),
            for (final module in workout.modules) ...[
              WorkoutSlidePreview(module: module, isRest: false),
              const SizedBox(height: 12),
            ],
            const Text(
              '아래 버튼을 누르면 실제 수업에 쓸 수 있는 내 워크아웃이 저장됩니다. 체험용 시간이 아닌 원래 시간을 사용해요. 회원 수준에 맞게 운동과 시간을 조정하세요.',
            ),
            const SizedBox(height: 8),
            const Text(
              '이 예시로 만든 내 수업이 있으면 다시 열어요. 수정한 내용은 덮어쓰지 않습니다. 기존 [예시] 수업도 그대로 남아요.',
            ),
            if (action.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '가져오지 못했습니다. 연결을 확인하고 다시 시도해 주세요.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
