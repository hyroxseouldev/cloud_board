import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_rehearsal_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_rehearsal_screen.dart';

/// Local playback only. This screen cannot start a PlaybackSession or send to TV.
class WorkoutRehearsalScreen extends HookConsumerWidget {
  const WorkoutRehearsalScreen({
    super.key,
    required this.workout,
    this.demo = false,
    this.onFinished,
    this.onCreate,
    this.onConnect,
  });
  final Workout workout;
  final bool demo;
  final VoidCallback? onFinished, onCreate, onConnect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = useState(0), finished = useState(false);
    final completed = useState(<int>{});
    final reported = useRef(false);
    final modules = workout.modules
        .map((m) => m.copyWith(beep: false))
        .toList();
    void finish() {
      finished.value = true;
      if (completed.value.length == workout.modules.length && !reported.value) {
        reported.value = true;
        onFinished?.call();
      }
    }

    void move(int next) {
      ref
          .read(slideRehearsalControllerProvider(modules[index.value]).notifier)
          .pause();
      if (next >= workout.modules.length) {
        finish();
        return;
      }
      ref.invalidate(slideRehearsalControllerProvider(modules[next]));
      index.value = next;
    }

    if (workout.modules.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('수업 연습')),
        body: const Center(child: Text('연습할 슬라이드를 먼저 추가해 주세요.')),
      );
    }
    if (finished.value) {
      final complete = completed.value.length == workout.modules.length;
      return Scaffold(
        appBar: AppBar(title: const Text('이 기기에서 연습')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Icon(
                  complete
                      ? Icons.check_circle_outline
                      : Icons.pause_circle_outline,
                  size: 56,
                ),
                const SizedBox(height: 20),
                Text(
                  complete ? '연습을 마쳤어요' : '연습을 종료했어요',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text('이 기기에서만 연습했어요. 실제 TV 수업은 시작하지 않았어요.'),
                const SizedBox(height: 24),
                if (onCreate != null)
                  FilledButton(
                    onPressed: onCreate,
                    child: const Text('이 예시로 내 수업 만들기'),
                  ),
                if (onConnect != null)
                  FilledButton(
                    onPressed: onConnect,
                    child: const Text('TV 연결 준비하기'),
                  ),
                OutlinedButton(
                  onPressed: () {
                    completed.value = {};
                    finished.value = false;
                    index.value = 0;
                    ref.invalidate(
                      slideRehearsalControllerProvider(modules.first),
                    );
                  },
                  child: const Text('처음부터 다시 연습'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(demo ? '다른 예시 둘러보기' : '수업으로 돌아가기'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SlideRehearsalScreen(
      key: ValueKey(index.value),
      title: demo ? '예시 수업 체험' : '이 기기에서 연습',
      module: modules[index.value],
      workout: workout,
      brandL: workout.brandL,
      brandR: workout.brandR,
      introduction: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${index.value + 1}/${workout.modules.length} · ${demo ? '1분 체험' : '수업 연습'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              demo
                  ? '체험용 시간: 운동 8초 · 휴식 4초 · 2세트. 내 수업에는 원래 시간이 적용돼요.'
                  : '저장된 시간으로 연습해요. 전환음은 버튼을 눌러 확인할 수 있어요.',
            ),
            const SizedBox(height: 8),
            const Text('이 기기에서만 연습해요 · TV로 보내지 않아요.'),
            const SizedBox(height: 8),
            const Text(
              '운동 화면은 TV에, 재생·일시정지 버튼은 휴대폰에 보여요. 지금은 이 기기에서 두 역할을 함께 체험해 보세요.',
            ),
          ],
        ),
      ),
      navigation: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (index.value > 0)
              OutlinedButton(
                onPressed: () => move(index.value - 1),
                child: const Text('이전 슬라이드'),
              ),
            FilledButton(
              onPressed: () => move(index.value + 1),
              child: Text(
                index.value < workout.modules.length - 1 ? '다음 슬라이드' : '연습 종료',
              ),
            ),
            if (onCreate != null)
              TextButton(
                onPressed: () {
                  ref
                      .read(
                        slideRehearsalControllerProvider(
                          workout.modules[index.value].copyWith(beep: false),
                        ).notifier,
                      )
                      .pause();
                  onCreate!();
                },
                child: const Text('체험 건너뛰고 내 수업 만들기'),
              ),
          ],
        ),
      ),
      onCompleted: () {
        completed.value = {...completed.value, index.value};
        if (index.value == workout.modules.length - 1) finish();
      },
    );
  }
}
