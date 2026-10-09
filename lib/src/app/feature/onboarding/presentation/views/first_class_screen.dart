import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_preflight_dialog.dart';
import 'package:cloud_board/src/app/feature/onboarding/domain/entities/first_class_progress.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/first_class_controller.dart';

const _titles = ['센터 정보 확인', '첫 수업 저장', 'TV 연결 확인', 'TV에서 첫 재생'];
const _details = [
  '가입 때 입력한 센터 정보와 이용 상태를 확인하세요.',
  '예시를 가져오거나 새 수업을 만들고 저장하세요.',
  'QR·코드로 연결하고 이름과 확인 번호를 확인하세요.',
  '저장한 수업을 TV로 보내면 TV 응답 후 완료됩니다.',
];

class FirstClassScreen extends HookConsumerWidget {
  const FirstClassScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(firstClassControllerProvider);
    final progress = state.isLoading ? null : state.value;
    final busy = useState(false);
    final actions = ref.read(firstClassControllerProvider.notifier);
    Future<void> open(FirstClassStep step) async {
      await actions.enter(step);
      if (!context.mounted) return;
      switch (step) {
        case FirstClassStep.center:
          context.push('/onboarding?edit=true');
        case FirstClassStep.workout:
          context.push('/starter-workouts');
        case FirstClassStep.display:
          context.push('/displays/connect');
        case FirstClassStep.playback:
          final id = progress?.savedWorkoutId;
          if (id == null) {
            context.push('/starter-workouts');
            return;
          }
          busy.value = true;
          try {
            final workout = await ref
                .read(workoutActionControllerProvider.notifier)
                .prepare(id);
            if (workout == null || !context.mounted) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('수업을 불러오지 못했습니다. 수업을 다시 저장하거나 예시를 가져와 주세요.'),
                  ),
                );
              }
              return;
            }
            final selection = await showWorkoutPreflight(context, workout);
            if (!context.mounted || selection == null) return;
            if (selection.targetDeviceIds.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('첫 TV 재생을 완료하려면 온라인 TV를 선택해 주세요.'),
                ),
              );
              return;
            }
            final steps = buildPlayerSteps(workout);
            if (steps.isEmpty) return;
            final sessionId = await ref
                .read(playbackActionControllerProvider.notifier)
                .start(
                  workout: workout,
                  targetDeviceIds: selection.targetDeviceIds,
                  stepIndex: 0,
                  durationMs: steps.first.duration * 1000,
                );
            if (sessionId != null && context.mounted) {
              context.push('/player/$id?session=$sessionId');
            }
          } finally {
            if (context.mounted) busy.value = false;
          }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('첫 수업 준비')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              progress?.complete == true ? '첫 TV 수업을 시작했어요' : '첫 수업까지, 한 단계씩',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text('언제든 나가도 괜찮아요. 이 계정과 센터의 진행 상태를 저장하고 이어서 안내합니다.'),
            const SizedBox(height: 24),
            if (state.isLoading) const LinearProgressIndicator(),
            if (state.hasError) ...[
              const Text('진행 상태를 불러오지 못했습니다. 인터넷 연결을 확인해 주세요.'),
              TextButton(
                onPressed: () => ref.invalidate(firstClassControllerProvider),
                child: const Text('다시 불러오기'),
              ),
            ],
            if (!state.isLoading && !state.hasError && progress == null)
              const Text('승인된 센터 계정으로 로그인해 주세요. 센터 초대와 TV 등록은 소유자에게 요청해 주세요.'),
            if (progress != null) ...[
              LinearProgressIndicator(
                value: progress.completedCount / 4,
                minHeight: 6,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 8),
              Text('${progress.completedCount}/4 완료'),
              const SizedBox(height: 20),
              for (final step in FirstClassStep.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                progress.done(step)
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: progress.done(step)
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _titles[step.index],
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                              IconButton(
                                tooltip: '${_titles[step.index]} 도움말',
                                icon: const Icon(Icons.help_outline),
                                onPressed: () async {
                                  await actions.help(step);
                                  if (!context.mounted) return;
                                  showModalBottomSheet<void>(
                                    context: context,
                                    showDragHandle: true,
                                    builder: (_) => SafeArea(
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Text(switch (step) {
                                          FirstClassStep.center => '센터 정보는 프로필에서 다시 바꿀 수 있어요. 수업 준비는 바로 할 수 있고 TV 연결과 재생에는 이용 권한이 필요합니다.',
                                          FirstClassStep.workout => '시작 예시는 수정 가능한 내 수업으로 복사됩니다. 저장이 실패하면 완료로 표시하지 않아요. 편집 화면에서 다시 저장해 주세요.',
                                          FirstClassStep.display => '이미 등록한 TV는 다시 추가하지 말고 목록에서 선택하세요. TV 앱을 켜고 인터넷과 앱 버전을 확인한 뒤 확인 화면을 다시 보내세요.',
                                          FirstClassStep.playback => 'TV의 수업 시작 응답이 와야 완료됩니다. 이 기기에서만 재생하거나 TV가 오프라인이면 완료되지 않아요. TV 앱과 연결 상태를 확인하세요.',
                                        }),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          Text(_details[step.index]),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: busy.value ? null : () => open(step),
                            child: Text(
                              progress.done(step)
                                  ? '다시 열기'
                                  : switch (step) {
                                      FirstClassStep.center => '센터 정보 열기',
                                      FirstClassStep.workout => '예시 수업 고르기',
                                      FirstClassStep.display => 'TV 연결하기',
                                      FirstClassStep.playback => '저장한 수업 재생',
                                    },
                            ),
                          ),
                          if (step == FirstClassStep.workout)
                            TextButton(
                              onPressed: busy.value
                                  ? null
                                  : () => context.push('/editor/new'),
                              child: const Text('직접 수업 만들기'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              TextButton(
                onPressed: () async {
                  await actions.dismiss(!progress.dismissed);
                },
                child: Text(progress.dismissed ? '홈에서 안내 다시 표시' : '홈에서 안내 숨기기'),
              ),
              const Text(
                '숨긴 안내는 홈 메뉴의 ‘첫 수업 준비’에서 다시 열 수 있어요.',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class FirstClassHomeCard extends ConsumerWidget {
  const FirstClassHomeCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(firstClassControllerProvider).value;
    if (progress == null || progress.dismissed || progress.complete) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: const Icon(Icons.checklist_rounded),
        title: const Text('첫 수업 준비'),
        subtitle: Text('${progress.completedCount}/4 완료 · 예시 수업부터 TV 재생까지'),
        trailing: IconButton(
          tooltip: '첫 수업 안내 숨기기',
          icon: const Icon(Icons.close, size: 20),
          onPressed: () =>
              ref.read(firstClassControllerProvider.notifier).dismiss(true),
        ),
        onTap: () => context.push('/first-class'),
      ),
    );
  }
}
