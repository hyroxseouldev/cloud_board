import 'package:flutter/material.dart';

import 'dart:async';

import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_rehearsal_screen.dart';
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

String _nextLabel(FirstClassNext next) => switch (next) {
  FirstClassNext.explore => '예시 수업 둘러보기',
  FirstClassNext.rehearse => '저장한 수업으로 이 기기에서 연습',
  FirstClassNext.center => '실제 수업을 위한 센터 정보 확인',
  FirstClassNext.connect => 'TV 연결 준비하기',
  FirstClassNext.play => '확인한 TV에서 첫 수업 시작',
  FirstClassNext.repeat => '다음 수업 준비하기',
};

class FirstClassScreen extends HookConsumerWidget {
  const FirstClassScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(firstClassControllerProvider);
    final progress = state.isLoading ? null : state.value;
    final busy = useState(false);
    final actions = ref.read(firstClassControllerProvider.notifier);
    final devices = ref.watch(displayDevicesProvider);
    final onlineTv =
        devices.value?.any(
          (d) => d.online && d.paired && d.displayState == 'auto',
        ) ??
        false;
    final next = progress?.next(
      onlineTv:
          devices.value?.any(
            (d) =>
                d.id == progress.verifiedDeviceId &&
                d.online &&
                d.paired &&
                d.displayState == 'auto',
          ) ??
          false,
    );
    Future<void> rehearse() async {
      final id = progress?.savedWorkoutId;
      if (id == null || busy.value) return;
      busy.value = true;
      try {
        final workout = await ref
            .read(workoutActionControllerProvider.notifier)
            .prepare(id);
        if (!context.mounted) return;
        if (workout == null) throw StateError('수업을 찾을 수 없습니다.');
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => WorkoutRehearsalScreen(
              workout: workout,
              onFinished: () => unawaited(
                actions
                    .rehearsed(workout.id, ownerId: workout.ownerId)
                    .catchError((Object _) {}),
              ),
              onConnect: () => context.push('/displays/connect'),
            ),
          ),
        );
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('수업을 불러오지 못했어요. 연결을 확인하거나 수업을 다시 저장해 주세요.'),
            ),
          );
        }
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    Future<void> open(FirstClassStep step) async {
      await actions.enter(step);
      if (!context.mounted) return;
      switch (step) {
        case FirstClassStep.center:
          context.push('/onboarding?edit=true');
        case FirstClassStep.workout:
          context.push('/explore');
        case FirstClassStep.display:
          context.push('/displays/connect');
        case FirstClassStep.playback:
          final id = progress?.savedWorkoutId;
          if (id == null) {
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
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '수업을 시작하지 못했어요. 수업과 TV 연결 상태를 확인하고 다시 시도해 주세요.',
                  ),
                ),
              );
            }
          } finally {
            if (context.mounted) busy.value = false;
          }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('첫 수업 준비'),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '지금은 이 단계부터',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(switch (next!) {
                        FirstClassNext.explore =>
                          'TV 없이 예시를 조작해 보고 내 수업으로 만들어 보세요.',
                        FirstClassNext.rehearse =>
                          '수업이 저장됐어요. 실제 TV로 보내기 전에 이 기기에서 연습해 보세요.',
                        FirstClassNext.center =>
                          '로컬 연습을 마쳤어요. 센터 정보와 이용 상태는 실제 TV 수업을 준비할 때 확인해요.',
                        FirstClassNext.connect =>
                          onlineTv
                              ? '원하는 TV인지 확인한 뒤 수업을 시작해요.'
                              : 'TV가 없거나 오프라인이에요. 연결은 나중에 하고 연습을 계속해도 괜찮아요.',
                        FirstClassNext.play =>
                          '연결 확인을 마쳤어요. 시작 전 대상 TV를 직접 선택해 주세요.',
                        FirstClassNext.repeat => '첫 TV 수업을 시작했어요. 홈에서 최근 수업을 다시 열거나 수업 메뉴에서 복제해 다음 수업을 준비하세요.',
                      }),
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const ValueKey('first-class-next'),
                        onPressed: busy.value
                            ? null
                            : () {
                                switch (next) {
                                  case FirstClassNext.explore:
                                    context.push('/explore');
                                  case FirstClassNext.rehearse:
                                    rehearse();
                                  case FirstClassNext.center:
                                    open(FirstClassStep.center);
                                  case FirstClassNext.connect:
                                    open(FirstClassStep.display);
                                  case FirstClassNext.play:
                                    open(FirstClassStep.playback);
                                  case FirstClassNext.repeat:
                                    context.go('/');
                                }
                              },
                        child: Text(_nextLabel(next)),
                      ),
                      if (progress.savedWorkoutId != null &&
                          next != FirstClassNext.rehearse)
                        TextButton(
                          onPressed: busy.value ? null : rehearse,
                          child: const Text('TV 없이 연습 계속하기'),
                        ),
                      TextButton(
                        onPressed: busy.value
                            ? null
                            : () => context.push('/explore'),
                        child: const Text('둘러보기 다시 보기'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (progress.rehearsedWorkoutId == progress.savedWorkoutId &&
                  progress.savedWorkoutId != null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('✓ 이 기기 연습 완료 · TV 재생 완료와 별도로 기록해요.'),
                ),
              LinearProgressIndicator(
                value: progress.completedCount / 4,
                minHeight: 6,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 8),
              Text('${progress.completedCount}/4 완료'),
              const SizedBox(height: 20),
              ExpansionTile(
                title: const Text('전체 준비 단계와 도움말'),
                children: [
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
                                onPressed:
                                    busy.value ||
                                        (step == FirstClassStep.playback &&
                                            (progress.savedWorkoutId == null ||
                                                !onlineTv))
                                    ? null
                                    : () => open(step),
                                child: Text(
                                  progress.done(step)
                                      ? '다시 열기'
                                      : switch (step) {
                                          FirstClassStep.center => '센터 정보 열기',
                                          FirstClassStep.workout =>
                                            '예시 수업 둘러보기',
                                          FirstClassStep.display => 'TV 연결하기',
                                          FirstClassStep.playback =>
                                            progress.savedWorkoutId == null
                                                ? '수업 저장 후 TV 재생 가능'
                                                : !onlineTv
                                                ? '온라인 TV 연결 후 재생 가능'
                                                : '저장한 수업을 TV에서 재생',
                                        },
                                ),
                              ),
                              if (step == FirstClassStep.workout)
                                TextButton(
                                  onPressed: busy.value
                                      ? null
                                      : () => context.push(
                                          '/editor/new?guide=true',
                                        ),
                                  child: const Text('직접 수업 만들기'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
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
    final state = ref.watch(firstClassControllerProvider);
    final progress = state.isLoading ? null : state.value;
    if (progress == null || progress.dismissed) {
      return const SizedBox.shrink();
    }
    final devices = ref.watch(displayDevicesProvider).value ?? [];
    final next = progress.next(
      onlineTv: devices.any(
        (d) =>
            d.id == progress.verifiedDeviceId &&
            d.online &&
            d.paired &&
            d.displayState == 'auto',
      ),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: const Icon(Icons.checklist_rounded),
        title: Text(progress.complete ? '다음 수업 준비' : '첫 수업 준비'),
        subtitle: Text('${progress.completedCount}/4 완료 · ${_nextLabel(next)}'),
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
