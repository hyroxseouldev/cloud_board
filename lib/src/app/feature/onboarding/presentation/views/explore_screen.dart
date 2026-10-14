import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';
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
    void createFromExample() {
      remember(actions.beginImport(template, purpose: purpose));
      if (ref.read(authStateProvider).value == null) {
        remember(actions.event('demo_to_signup'));
      }
      context.push(
        starterLocation('/starter-workouts', template, purpose: purpose),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('예시 수업'),
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
        actions: [
          if (ref.watch(authStateProvider).value == null)
            TextButton(
              onPressed: () => context.push(
                starterLocation('/login', template, purpose: purpose),
              ),
              child: const Text('로그인'),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                key: const ValueKey('play-recommended-example'),
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
                label: const Text('이 기기에서 예시 재생'),
              ),
              TextButton(
                onPressed: createFromExample,
                child: const Text('체험 건너뛰고 내 수업 만들기'),
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            children: [
              Text(
                '내 수업, 예시 하나로 시작해요',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              const Text('재생해 보고, 마음에 들면 내 수업으로 바꿔 보세요. 계정이나 TV는 아직 필요 없어요.'),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    size: 18,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      template == StarterWorkout.basics
                          ? '처음이라면 이 예시를 추천해요'
                          : '선택한 예시',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                template.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(template.description),
              const SizedBox(height: 16),
              WorkoutSlidePreview(module: workout.modules.first, isRest: false),
              const SizedBox(height: 8),
              const Text(
                '예시 · 자유롭게 수정하세요',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Text(
                '${workout.modules.length}개 슬라이드 · 저장하면 ${workoutDurationText(workout)} 수업',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              const Text(
                '예시는 운동 8초·휴식 4초로 짧게 압축했어요. 재생과 다음 슬라이드를 직접 눌러 보세요.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.muted,
                ),
              ),
              if (progress.value?.completedTemplates.contains(template.key) ==
                  true)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('✓ 이 예시를 마쳤어요 · 내 수업 저장·연습 완료와는 별도예요.'),
                ),
              const SizedBox(height: 16),
              ExpansionTile(
                key: const ValueKey('example-options'),
                tilePadding: EdgeInsets.zero,
                title: const Text('다른 예시·시작 목적 선택'),
                childrenPadding: const EdgeInsets.only(bottom: 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    'preparing' =>
                      '먼저 수업을 저장하고 이 기기에서 연습해요. 센터·TV 준비는 나중에 해도 괜찮아요.',
                    'operating' => '예시를 내 수업으로 만든 뒤 센터 정보와 TV 연결을 확인해요.',
                    _ => '예시를 직접 조작해 본 뒤, 마음에 들면 내 수업으로 만들어 보세요.',
                  }),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '내 수업을 계정에 저장할 때 로그인·휴대폰 인증을 안내해요. 예시는 인증 없이 둘러볼 수 있어요.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              const ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('수업과 TV는 어떻게 사용하나요?'),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProductRoles(),
                  SizedBox(height: 16),
                  Text(
                    '수업은 여러 운동 화면을 순서대로 묶은 것이에요. 한 화면이 슬라이드이고, 템플릿은 처음 만들 때 쓰는 예시나 디자인이에요. 내용과 시간은 내 수업에서 바꿀 수 있어요.',
                  ),
                  SizedBox(height: 16),
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
