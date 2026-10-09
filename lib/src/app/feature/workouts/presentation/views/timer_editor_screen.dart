import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_editing.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/timer_modes.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_editor_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/timer_editor_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_editor_style.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_rehearsal_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/timer_editor_fields.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/timer_summary.dart';

/// One editing transaction; only the final action updates the slide draft.
class TimerEditorScreen extends HookConsumerWidget {
  const TimerEditorScreen({
    super.key,
    required this.workoutId,
    required this.original,
    required this.scope,
    required this.onSelectBlock,
    this.chooseModeInitially = false,
    this.brandL = '',
    this.brandR = '',
    this.workout,
  });
  final String workoutId, scope, brandL, brandR;
  final WorkoutModule original;
  final ValueChanged<String> onSelectBlock;
  final bool chooseModeInitially;
  final Workout? workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slide = slideEditorControllerProvider(workoutId, original, scope);
    final initial = useMemoized(() => ref.read(slide).module);
    final provider = timerEditorControllerProvider(initial);
    final state = ref.watch(provider);
    final actions = ref.read(provider.notifier);
    final applied = useState(false);
    final selecting = useState(false);
    final module = state.module;
    final error = timingValidationError(module);

    Future<void> chooseMode({bool creating = false}) async {
      if (selecting.value) return;
      selecting.value = true;
      FocusScope.of(context).unfocus();
      try {
        final mode = await showTimerModePicker(
          context,
          current: timerInputMode(module),
          creating: creating,
        );
        if (mode == null || !context.mounted) return;
        if (mode == WorkoutTimerMode.custom && !isContinuousTimer(module)) {
          actions.showDetails(true);
          return;
        }
        final candidate = timerModeCandidate(
          module,
          mode == WorkoutTimerMode.custom ? WorkoutTimerMode.interval : mode,
        );
        if (!creating && !sameSlideTiming(module, candidate)) {
          if (!await confirmTimerReplacement(context, module, candidate) ||
              !context.mounted) {
            return;
          }
        }
        actions.replace(candidate);
        if (mode == WorkoutTimerMode.custom) actions.showDetails(true);
      } finally {
        if (context.mounted) selecting.value = false;
      }
    }

    useEffect(() {
      if (chooseModeInitially) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) chooseMode(creating: true);
        });
      }
      return null;
    }, const []);

    void apply() {
      if (applied.value || !state.valid) return;
      applied.value = true;
      final current = ref.read(slide).module;
      ref.read(slide.notifier).update(copySlideTiming(current, module));
      onSelectBlock(effectiveIntervalBlocks(module).first.id);
      Navigator.pop(context);
    }

    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Theme(
      data: SlideEditorStyle.theme(Theme.of(context)),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.maybePop(context),
        },
        child: UnsavedChangesGuard(
          dirty: !applied.value && actions.dirty,
          confirmTitle: '반영하지 않고 닫을까요?',
          confirmMessage: '이번에 변경한 타이머 설정은 슬라이드에 반영되지 않습니다.',
          discardLabel: '반영 안 하고 닫기',
          child: Scaffold(
            key: const ValueKey('timer-editor-sheet'),
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              leading: CloseButton(
                key: const ValueKey('close-timer-editor'),
                onPressed: () => Navigator.maybePop(context),
              ),
              title: const Text('타이머 편집'),
            ),
            body: SafeArea(
              top: false,
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 660),
                  child: ListView(
                    key: const ValueKey('timer-editor-settings'),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    children: [
                      Text(
                        module.name,
                        style: const TextStyle(
                          fontSize: 13,
                          color: SlideEditorStyle.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              timerEditorLabel(module),
                              key: const ValueKey('timer-current-mode'),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            key: const ValueKey('open-timer-builder'),
                            onPressed:
                                selecting.value || state.errors.isNotEmpty
                                ? null
                                : chooseMode,
                            label: const Text('방식 변경'),
                            icon: const Icon(Icons.chevron_right, size: 18),
                            iconAlignment: IconAlignment.end,
                          ),
                        ],
                      ),
                      Text(
                        timerModeDescription(timerInputMode(module)),
                        style: const TextStyle(
                          fontSize: 14,
                          color: SlideEditorStyle.muted,
                        ),
                      ),
                      if (initial.timerMode != WorkoutTimerMode.custom &&
                          module.timerMode == WorkoutTimerMode.custom) ...[
                        const SizedBox(height: 8),
                        const Text(
                          '구간을 변경해 사용자 지정 구성으로 전환했어요.',
                          key: ValueKey('timer-custom-notice'),
                          style: TextStyle(
                            fontSize: 13,
                            color: SlideEditorStyle.accent,
                          ),
                        ),
                      ],
                      if (initial.timerMode == WorkoutTimerMode.tabata &&
                          module.timerMode == WorkoutTimerMode.interval) ...[
                        const SizedBox(height: 8),
                        const Text('시간·반복을 바꾼 구성은 인터벌로 저장해요.'),
                      ],
                      const SizedBox(height: 16),
                      KeyedSubtree(
                        key: ValueKey(state.formRevision),
                        child: state.detailed
                            ? TimerDetailedFields(
                                state: state,
                                actions: actions,
                              )
                            : TimerCompactFields(
                                state: state,
                                actions: actions,
                              ),
                      ),
                      if (!isContinuousTimer(module) &&
                          (!state.detailed ||
                              timerInputMode(module) !=
                                  WorkoutTimerMode.custom)) ...[
                        const Divider(height: 16),
                        ListTile(
                          key: const ValueKey('timer-detail-toggle'),
                          visualDensity: VisualDensity.compact,
                          minTileHeight: 44,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            state.detailed ? '간단한 설정으로 돌아가기' : '구간별로 직접 편집',
                            style: const TextStyle(fontSize: 14),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          enabled: state.valid,
                          onTap: () => actions.showDetails(!state.detailed),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (state.valid)
                        TimerResultSummary(
                          module: module,
                          onRehearse: () => Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SlideRehearsalScreen(
                                module: module,
                                brandL: brandL,
                                brandR: brandR,
                                workout: workout,
                              ),
                            ),
                          ),
                        )
                      else
                        Text(
                          error ?? '입력을 완료하면 총시간과 진행 순서를 확인할 수 있어요.',
                          key: const ValueKey('timer-validation-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      if (state.inputMode == WorkoutTimerMode.emom &&
                          !state.detailed)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            key: const ValueKey('emom-preset-rounds'),
                            onPressed: () async {
                              final candidate = editEmom(module, (
                                seconds: 120,
                                intervals: 3,
                                rounds: 6,
                                restSeconds: 30,
                                includeFinalRest: true,
                              ));
                              if (sameSlideTiming(module, candidate)) return;
                              if (await confirmTimerReplacement(
                                    context,
                                    module,
                                    candidate,
                                  ) &&
                                  context.mounted) {
                                actions.replace(candidate);
                              }
                            },
                            child: const Text('예시 · 2분 × 3구간 · 6라운드'),
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (module.imageSource.isNotEmpty) ...[
                        const Text(
                          '배경 이미지에 적힌 시간은 자동으로 바뀌지 않아요.',
                          style: TextStyle(
                            fontSize: 12,
                            color: SlideEditorStyle.muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const Text(
                        '준비 카운트다운은 별도예요.',
                        style: TextStyle(
                          fontSize: 12,
                          color: SlideEditorStyle.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            bottomNavigationBar: Padding(
              padding: EdgeInsets.only(bottom: keyboard),
              child: SafeArea(
                top: false,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: SlideEditorStyle.line),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const ValueKey('apply-timer-editor'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: applied.value || !state.valid
                              ? null
                              : apply,
                          child: const Text('타이머 반영'),
                        ),
                      ),
                      if (keyboard == 0) ...[
                        const SizedBox(height: 8),
                        const Text(
                          '슬라이드에 반영한 뒤 저장해 주세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: SlideEditorStyle.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
