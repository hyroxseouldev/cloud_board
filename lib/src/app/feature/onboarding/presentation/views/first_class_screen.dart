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

const _titles = ['센터 정보 확인 · 선택', '첫 수업 저장', 'TV 연결', 'TV에서 첫 재생'];
const _details = [
  '센터 정보는 선택 사항이며 프로필에서 나중에 입력할 수 있어요.',
  '예시를 가져오거나 새 수업을 만들고 저장하세요.',
  'QR·코드로 연결하고 TV 이름과 구역을 정하세요.',
  '저장한 수업을 TV로 보내면 TV 응답 후 완료됩니다.',
];

String _nextLabel(FirstClassNext next) => switch (next) {
  FirstClassNext.explore => '예시로 내 수업 만들기',
  FirstClassNext.rehearse => '저장한 수업으로 이 기기에서 연습',
  FirstClassNext.center => '실제 수업을 위한 센터 정보 확인',
  FirstClassNext.connect => 'TV 연결 준비하기',
  FirstClassNext.play => '연결한 TV에서 첫 수업 시작',
  FirstClassNext.repeat => '다음 수업 준비하기',
};

class FirstClassScreen extends HookConsumerWidget {
  const FirstClassScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(firstClassControllerProvider);
    final progress = state.isLoading ? null : state.value;
    final saved = progress?.savedWorkoutId != null;
    final rehearsed =
        saved && progress?.rehearsedWorkoutId == progress?.savedWorkoutId;
    final firstAchievementCount = (saved ? 1 : 0) + (rehearsed ? 1 : 0);
    final busy = useState(false);
    final actions = ref.read(firstClassControllerProvider.notifier);
    final devices = ref.watch(displayDevicesProvider);
    final nowMs =
        ref.watch(displayHealthNowProvider).value ??
        DateTime.now().millisecondsSinceEpoch;
    final onlineTv =
        devices.value?.any(
          (d) => d.recentlySeen(nowMs) && d.paired && d.displayState == 'auto',
        ) ??
        false;
    final next = progress?.next(onlineTv: onlineTv);
    bool stepDone(FirstClassStep step) => step == FirstClassStep.display
        ? onlineTv || progress?.done(step) == true
        : progress?.done(step) == true;
    final preparationCount = const [
      FirstClassStep.workout,
      FirstClassStep.display,
      FirstClassStep.playback,
    ].where(stepDone).length;
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
          context.push('/starter-workouts');
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
                  preparationProof: selection.preparation,
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
              progress?.complete == true
                  ? '첫 TV 수업을 시작했어요'
                  : rehearsed
                  ? '내 수업을 준비했어요'
                  : '내 수업 저장부터,\n이 기기 연습까지',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text('먼저 수업 하나를 저장하고 연습해 보세요. 센터 정보와 TV 연결은 그다음에 준비해도 괜찮아요.'),
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
                        FirstClassNext.explore => '예시를 선택하고 내 수업으로 저장해 보세요.',
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
                                    context.push('/starter-workouts');
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
                value: firstAchievementCount / 2,
                minHeight: 6,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 8),
              Text('첫 목표 $firstAchievementCount/2 완료 · 내 수업 저장 + 이 기기 연습'),
              const SizedBox(height: 8),
              Text(
                rehearsed
                    ? '저장한 같은 수업의 연습을 마쳤어요. TV 송출은 별도로 확인해요.'
                    : '수업을 계정에 저장한 뒤, 저장한 수업으로 연습하면 준비가 끝나요.',
              ),
              const SizedBox(height: 20),
              ExpansionTile(
                title: const Text('센터·TV 준비와 도움말'),
                subtitle: Text('$preparationCount/3 완료 · 실제 TV 수업 준비'),
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
                                    stepDone(step)
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: stepDone(step)
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
                                              FirstClassStep.display => '이미 등록한 TV는 다시 추가하지 말고 목록에서 선택하세요. TV 앱을 켜고 인터넷 연결과 등록 상태를 확인하세요.',
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
                                  stepDone(step)
                                      ? '다시 열기'
                                      : switch (step) {
                                          FirstClassStep.center => '센터 정보 열기',
                                          FirstClassStep.workout =>
                                            '예시로 내 수업 만들기',
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
    final nowMs =
        ref.watch(displayHealthNowProvider).value ??
        DateTime.now().millisecondsSinceEpoch;
    final next = progress.next(
      onlineTv: devices.any(
        (d) => d.recentlySeen(nowMs) && d.paired && d.displayState == 'auto',
      ),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: const Icon(Icons.checklist_rounded),
        title: Text(progress.complete ? '다음 수업 준비' : '첫 수업 준비'),
        subtitle: Text(
          '${progress.savedWorkoutId != null && progress.rehearsedWorkoutId == progress.savedWorkoutId ? '저장·연습 완료' : '첫 목표 · 저장하고 연습하기'} · ${_nextLabel(next)}',
        ),
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
