import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/starter_workouts.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_rehearsal_screen.dart';

import 'package:cloud_board/src/app/feature/onboarding/domain/exploration_routes.dart';
import 'package:cloud_board/src/app/feature/onboarding/presentation/controllers/exploration_controller.dart';

class ExploreScreen extends HookConsumerWidget {
  const ExploreScreen({super.key, this.initialTemplate, this.initialPurpose});
  final StarterWorkout? initialTemplate;
  final String? initialPurpose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(explorationControllerProvider);
    final selection = useState(initialTemplate);
    final selectedPurpose = useState(explorationPurpose(initialPurpose));
    final purpose =
        selectedPurpose.value ?? progress.value?.purpose ?? 'exploring';
    final template =
        selection.value ??
        starterFromKey(progress.value?.templateKey) ??
        StarterWorkout.basics;
    final workout = template.create(
      const WorkoutAuthor(id: 'preview', displayName: '', photoUrl: null),
    );
    final actions = ref.read(explorationControllerProvider.notifier);
    void remember(Future<void> task) =>
        unawaited(task.catchError((Object _) {}));
    return Scaffold(
      appBar: AppBar(
        title: const Text('예시 수업 둘러보기'),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(
                ref.read(authStateProvider).value == null ? '/login' : '/',
              );
            }
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: FilledButton.icon(
            onPressed: () {
              remember(actions.select(template));
              context.push(
                starterLocation(
                  '/explore/play/${template.key}',
                  null,
                  purpose: purpose,
                ),
              );
            },
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('이 기기에서 1분 체험'),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                '첫 수업, 여기서 시작해요',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                '휴대폰으로 수업을 준비하고 TV에 운동·타이머를 보여줘요. 지금은 계정이나 TV 없이 살펴보세요.',
              ),
              const SizedBox(height: 20),
              const ProductRoles(),
              const SizedBox(height: 24),
              Text(
                '어떻게 시작하고 싶으세요?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in const [
                    ('exploring', '먼저 둘러보기'),
                    ('preparing', '센터 오픈 준비'),
                    ('operating', '운영 중인 센터'),
                  ])
                    ChoiceChip(
                      label: Text(item.$2),
                      selected: purpose == item.$1,
                      onSelected: (_) {
                        selectedPurpose.value = item.$1;
                        remember(actions.purpose(item.$1));
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(switch (purpose) {
                'preparing' => '예시로 수업을 준비하고 이 기기에서 연습하세요. TV 연결은 나중에 해도 괜찮아요.',
                'operating' => '예시를 내 수업으로 만든 뒤 센터 정보와 TV 연결을 확인해요.',
                _ => '예시를 직접 조작해 본 뒤, 마음에 들면 내 수업으로 만들어 보세요.',
              }),
              const SizedBox(height: 24),
              Text(
                '어떤 수업을 해볼까요?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in StarterWorkout.values)
                    ChoiceChip(
                      label: Text(item.title),
                      selected: template == item,
                      onSelected: (_) {
                        selection.value = item;
                        remember(actions.select(item));
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                template.description,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${workout.modules.length}개 슬라이드 · 실제 수업 ${workoutDurationText(workout)}',
              ),
              const SizedBox(height: 12),
              WorkoutSlidePreview(module: workout.modules.first, isRest: false),
              const SizedBox(height: 16),
              if (progress.value?.completedTemplates.contains(template.key) ==
                  true)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('✓ 이 예시의 연습을 마쳤어요 · 실제 TV 재생과는 달라요.'),
                ),
              const Text(
                '운동 8초·휴식 4초로 짧게 체험해요. 내 수업에는 위에 표시된 원래 시간이 적용됩니다.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  remember(actions.beginImport(template, purpose: purpose));
                  if (ref.read(authStateProvider).value == null) {
                    remember(actions.event('demo_to_signup'));
                  }
                  context.push(
                    starterLocation(
                      '/starter-workouts',
                      template,
                      purpose: purpose,
                    ),
                  );
                },
                child: const Text('이 예시로 내 수업 만들기'),
              ),
              const Text(
                '내 수업 저장은 로그인 후 가능해요. 둘러보기만으로 무료 체험이 시작되지는 않아요.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 24),
              const ExpansionTile(
                title: Text('수업·슬라이드·템플릿이 뭔가요?'),
                childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Text(
                    '수업(워크아웃)은 여러 운동 화면을 순서대로 묶은 것이에요. 한 화면이 슬라이드이고, 템플릿은 처음 만들 때 쓰는 예시나 디자인이에요. 내용과 시간은 내 수업에서 바꿀 수 있어요.',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductRoles extends StatelessWidget {
  const ProductRoles({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 20,
    runSpacing: 12,
    children: [
      for (final item in const [
        (Icons.smartphone_outlined, '휴대폰 · 수업 준비와 제어'),
        (Icons.connected_tv_outlined, 'TV · 운동 화면과 타이머'),
      ])
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.$1),
            const SizedBox(width: 8),
            Flexible(child: Text(item.$2)),
          ],
        ),
    ],
  );
}

class ExploreDemoScreen extends HookConsumerWidget {
  const ExploreDemoScreen({super.key, required this.template, this.purpose});
  final StarterWorkout template;
  final String? purpose;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      final actions = ref.read(explorationControllerProvider.notifier);
      unawaited(actions.select(template).catchError((Object _) {}));
      unawaited(actions.event('demo_started').catchError((Object _) {}));
      return null;
    }, [template]);
    return WorkoutRehearsalScreen(
      workout: template.createDemo(),
      demo: true,
      onFinished: () => unawaited(
        ref
            .read(explorationControllerProvider.notifier)
            .completed(template)
            .catchError((Object _) {}),
      ),
      onCreate: () {
        unawaited(
          ref
              .read(explorationControllerProvider.notifier)
              .beginImport(template, purpose: purpose)
              .catchError((Object _) {}),
        );
        if (ref.read(authStateProvider).value == null) {
          unawaited(
            ref
                .read(explorationControllerProvider.notifier)
                .event('demo_to_signup')
                .catchError((Object _) {}),
          );
        }
        context.push(
          starterLocation('/starter-workouts', template, purpose: purpose),
        );
      },
    );
  }
}
