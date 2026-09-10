import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/core/widgets/async_action_overlay.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/slide_editor_screen.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/folder_selector.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';

class WorkoutEditorScreen extends ConsumerWidget {
  const WorkoutEditorScreen({super.key, required this.workoutId, this.guard});
  final String workoutId;
  final ExitGuard? guard;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = ref.watch(workoutControllerProvider);
    final user = ref.watch(authStateProvider).value;
    return values.when(
      data: (items) {
        final workout = workoutId == 'new' && user != null
            ? Workout.empty(
                newId(),
                WorkoutAuthor(
                  id: user.id,
                  displayName: user.displayName,
                  photoUrl: user.photoUrl,
                ),
              )
            : items.where((item) => item.id == workoutId).firstOrNull;
        return workout == null
            ? const Scaffold(body: Center(child: Text('워크아웃을 찾을 수 없습니다.')))
            : _EditorBody(
                initial: workout,
                isNew: workoutId == 'new',
                guard: guard,
              );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
    );
  }
}

class _WorkoutNameDialog extends HookWidget {
  const _WorkoutNameDialog();
  @override
  Widget build(BuildContext context) {
    final name = useTextEditingController();
    final form = useMemoized(() => GlobalKey<FormState>());
    return AlertDialog(
      title: const Text('워크아웃 이름이 필요합니다'),
      content: Form(
        key: form,
        child: TextFormField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: '저장할 워크아웃 이름'),
          validator: (v) =>
              v == null || v.trim().isEmpty ? '이름을 입력해 주세요.' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, name.text.trim());
            }
          },
          child: const Text('계속 저장'),
        ),
      ],
    );
  }
}

class _EditorBody extends HookConsumerWidget {
  const _EditorBody({required this.initial, required this.isNew, this.guard});
  final Workout initial;
  final bool isNew;
  final ExitGuard? guard;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = useState(initial);
    final savedBaseline = useState(initial);
    final name = useTextEditingController(text: initial.name);
    final folder = useTextEditingController(text: initial.folder);
    final brandL = useTextEditingController(text: initial.brandL);
    final brandR = useTextEditingController(text: initial.brandR);
    useListenable(name);
    useListenable(folder);
    useListenable(brandL);
    useListenable(brandR);
    final action = ref.watch(workoutActionControllerProvider);
    final playbackAction = ref.watch(playbackActionControllerProvider);
    final isBusy = action.isLoading || playbackAction.isLoading;
    final hasUnsavedChanges =
        draft.value != savedBaseline.value ||
        name.text.trim() != savedBaseline.value.name ||
        folder.text.trim() != savedBaseline.value.folder ||
        brandL.text.trim() != savedBaseline.value.brandL ||
        brandR.text.trim() != savedBaseline.value.brandR;

    Future<Workout?> persist({Workout? edited}) async {
      if (name.text.trim().isEmpty) {
        final enteredName = await showDialog<String>(
          context: context,
          builder: (_) => const _WorkoutNameDialog(),
        );
        if (enteredName == null || !context.mounted) return null;
        name.text = enteredName;
      }
      final value = (edited ?? draft.value).copyWith(
        name: name.text.trim(),
        folder: folder.text.trim(),
        brandL: brandL.text.trim(),
        brandR: brandR.text.trim(),
      );
      final saved = await ref
          .read(workoutActionControllerProvider.notifier)
          .save(value);
      if (saved != null) {
        draft.value = saved;
        savedBaseline.value = saved;
      }
      return saved;
    }

    Future<void> saveAndClose() async {
      final saved = await persist();
      if (saved == null || !context.mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (isNew || !context.canPop()) {
          context.go('/');
        } else {
          context.pop();
        }
      });
    }

    return UnsavedChangesGuard(
      guard: guard,
      dirty: hasUnsavedChanges,
      blocked: isBusy,
      child: AsyncActionOverlay(
        isLoading: isBusy,
        child: Scaffold(
          appBar: AppBar(
            leading: BackButton(
              onPressed: isBusy
                  ? null
                  : () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    },
            ),
            title: Text(
              isNew
                  ? '새 워크아웃'
                  : initial.name.isEmpty
                  ? '워크아웃'
                  : initial.name,
            ),
            actions: [
              Center(
                child: Text(
                  action.isLoading
                      ? '저장 중…'
                      : hasUnsavedChanges
                      ? '저장 필요'
                      : '저장됨',
                  style: TextStyle(
                    color: hasUnsavedChanges ? Colors.orange : XonColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 90),
                children: [
                  if (action.hasError)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        '저장하지 못했습니다. 변경사항은 유지됩니다. 다시 저장해 주세요.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  _TextField(
                    label: '워크아웃 이름',
                    controller: name,
                    hint: '예: 9/4 금 하이록스',
                  ),
                  FolderSelector(
                    value: folder.text,
                    folders: {
                      ...?ref
                          .watch(workoutControllerProvider)
                          .value
                          ?.map((w) => w.folder)
                          .where((f) => f.isNotEmpty),
                      if (folder.text.isNotEmpty) folder.text,
                    },
                    onChanged: (value) => folder.text = value,
                  ),
                  _WorkoutSettingsCard(
                    brandL: brandL,
                    brandR: brandR,
                    workout: draft.value,
                    onChanged: (value) => draft.value = value,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        '슬라이드',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: XonColors.muted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        durationLabel(workoutDuration(draft.value)),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: draft.value.modules.length,
                    onReorderItem: (oldIndex, newIndex) {
                      final list = [...draft.value.modules];
                      final item = list.removeAt(oldIndex);
                      list.insert(newIndex, item);
                      draft.value = draft.value.copyWith(modules: list);
                    },
                    proxyDecorator: (child, index, animation) => Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(9),
                      child: child,
                    ),
                    itemBuilder: (context, index) {
                      final module = draft.value.modules[index];
                      final intervalBlocks = effectiveIntervalBlocks(module);
                      Future<void> edit() async {
                        await context.push(
                          '/editor/${isNew ? 'new' : draft.value.id}/slides/${module.id}',
                          extra: SlideEditRequest(
                            module: module,
                            brandL: draft.value.brandL,
                            brandR: draft.value.brandR,
                            onSave: (updated) async {
                              final candidate = draft.value.copyWith(
                                modules: draft.value.modules
                                    .map(
                                      (m) => m.id == updated.id ? updated : m,
                                    )
                                    .toList(),
                              );
                              return await persist(edited: candidate) != null;
                            },
                          ),
                        );
                      }

                      return Card(
                        key: ValueKey(module.id),
                        child: ListTile(
                          onTap: edit,
                          leading: ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.drag_handle),
                            ),
                          ),
                          title: Text(
                            module.name.isEmpty
                                ? '슬라이드 ${index + 1}'
                                : module.name,
                          ),
                          subtitle: Text(
                            intervalBlocks.length == 1
                                ? '${intervalBlocks.first.sets}세트 · ${formatSlideTime(intervalBlocks.first.workSeconds)} / 휴식 ${formatSlideTime(intervalBlocks.first.restSeconds)}'
                                : '${intervalBlocks.length}블록 · 총 ${durationLabel(workoutModuleDuration(module))}',
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: '슬라이드 메뉴',
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('수정')),
                              PopupMenuItem(
                                value: 'duplicate',
                                child: Text('복제'),
                              ),
                              PopupMenuItem(value: 'delete', child: Text('삭제')),
                            ],
                            onSelected: (action) async {
                              if (action == 'edit') {
                                await edit();
                                return;
                              }
                              final modules = [...draft.value.modules];
                              if (action == 'duplicate') {
                                modules.insert(
                                  index + 1,
                                  module.copyWith(
                                    id: newId(),
                                    name: nextSlideName(modules),
                                  ),
                                );
                              } else {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('슬라이드를 삭제할까요?'),
                                    content: Text(
                                      '“${module.name}” 슬라이드를 목록에서 제거합니다.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, false),
                                        child: const Text('취소'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, true),
                                        child: const Text('삭제'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true || !context.mounted) {
                                  return;
                                }
                                modules.removeAt(index);
                              }
                              draft.value = draft.value.copyWith(
                                modules: modules,
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => draft.value = draft.value.copyWith(
                          modules: [
                            ...draft.value.modules,
                            WorkoutModule.empty(newId()).copyWith(
                              name: nextSlideName(draft.value.modules),
                            ),
                          ],
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('슬라이드 추가'),
                      ),
                      OutlinedButton(
                        onPressed: () => draft.value = draft.value.copyWith(
                          modules: [
                            ...draft.value.modules,
                            WorkoutModule.empty(newId()).copyWith(
                              name: '휴식',
                              workSeconds: 60,
                              text: '물 마시고 다음 스테이션으로',
                            ),
                          ],
                        ),
                        child: const Text('휴식 60초'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: isBusy ? null : saveAndClose,
                      icon: isBusy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(isBusy ? '처리 중...' : '저장'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.label,
    required this.controller,
    this.hint = '',
  });
  final String label, hint;
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: XonColors.muted,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    ),
  );
}

class _WorkoutSettingsCard extends StatelessWidget {
  const _WorkoutSettingsCard({
    required this.brandL,
    required this.brandR,
    required this.workout,
    required this.onChanged,
  });

  final TextEditingController brandL;
  final TextEditingController brandR;
  final Workout workout;
  final ValueChanged<Workout> onChanged;

  @override
  Widget build(BuildContext context) {
    final left = _settingsTextSummary(brandL.text);
    final right = _settingsTextSummary(brandR.text);
    final volume = (workout.soundVolume * 100).round();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const ValueKey('workout-display-sound-settings'),
        leading: const Icon(Icons.tune_rounded),
        title: const Text('화면·사운드 설정'),
        subtitle: Text(
          '왼쪽 $left · 오른쪽 $right · ${workout.soundTheme.label} $volume%',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tv_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '화면 문구',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '수업 화면 하단에 표시할 문구입니다.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: XonColors.muted),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final fields = [
                      _TextField(label: '화면 왼쪽 아래 문구', controller: brandL),
                      _TextField(label: '화면 오른쪽 아래 문구', controller: brandR),
                    ];
                    if (constraints.maxWidth < 720) {
                      return Column(children: fields);
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: fields.first),
                        const SizedBox(width: 20),
                        Expanded(child: fields.last),
                      ],
                    );
                  },
                ),
                const Divider(height: 32),
                _SoundSettingsSection(workout: workout, onChanged: onChanged),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _settingsTextSummary(String value) {
  final text = value.trim();
  if (text.isEmpty) return '없음';
  if (text.length <= 10) return '“$text”';
  return '“${text.substring(0, 10)}…”';
}

class _SoundSettingsSection extends ConsumerWidget {
  const _SoundSettingsSection({required this.workout, required this.onChanged});

  final Workout workout;
  final ValueChanged<Workout> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void preview(WorkoutSound sound) {
      unawaited(
        ref
            .read(beepPlayerProvider)
            .play(sound, workout.soundVolume)
            .catchError((_) {}),
      );
    }

    void applyTheme(WorkoutSoundTheme theme) {
      final sounds = soundsForTheme(theme);
      onChanged(
        workout.copyWith(
          soundTheme: theme,
          countdownSound: sounds.countdown,
          workStartSound: sounds.workStart,
          restStartSound: sounds.restStart,
          workoutEndSound: sounds.workoutEnd,
        ),
      );
      preview(sounds.workStart);
    }

    Workout custom({
      WorkoutSound? countdown,
      WorkoutSound? workStart,
      WorkoutSound? restStart,
      WorkoutSound? workoutEnd,
    }) => workout.copyWith(
      soundTheme: WorkoutSoundTheme.custom,
      countdownSound: countdown ?? workout.countdownSound,
      workStartSound: workStart ?? workout.workStartSound,
      restStartSound: restStart ?? workout.restStartSound,
      workoutEndSound: workoutEnd ?? workout.workoutEndSound,
    );

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.graphic_eq_rounded),
            const SizedBox(width: 8),
            Text('수업 사운드', style: theme.textTheme.titleMedium),
            const Spacer(),
            IconButton(
              tooltip: '현재 운동 시작음 미리 듣기',
              onPressed: () => preview(workout.workStartSound),
              icon: const Icon(Icons.volume_up_rounded),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '카운트다운과 운동·휴식 전환을 서로 다른 소리로 알려줍니다.',
          style: theme.textTheme.bodySmall?.copyWith(color: XonColors.muted),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...WorkoutSoundTheme.values
                .where((value) => value != WorkoutSoundTheme.custom)
                .map(
                  (option) => ChoiceChip(
                    label: Text(option.label),
                    tooltip: option.description,
                    selected: workout.soundTheme == option,
                    onSelected: (_) => applyTheme(option),
                  ),
                ),
            if (workout.soundTheme == WorkoutSoundTheme.custom)
              const ChoiceChip(label: Text('직접 설정'), selected: true),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.volume_down_rounded, size: 20),
            Expanded(
              child: Slider(
                value: workout.soundVolume.clamp(0, 1),
                divisions: 10,
                label: '${(workout.soundVolume * 100).round()}%',
                onChanged: (value) =>
                    onChanged(workout.copyWith(soundVolume: value)),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text('${(workout.soundVolume * 100).round()}%'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            _SoundEventSelector(
              label: '카운트다운',
              value: workout.countdownSound,
              onChanged: (sound) => onChanged(custom(countdown: sound)),
              onPreview: preview,
            ),
            _SoundEventSelector(
              label: '운동 시작',
              value: workout.workStartSound,
              onChanged: (sound) => onChanged(custom(workStart: sound)),
              onPreview: preview,
            ),
            _SoundEventSelector(
              label: '휴식 시작',
              value: workout.restStartSound,
              onChanged: (sound) => onChanged(custom(restStart: sound)),
              onPreview: preview,
            ),
            _SoundEventSelector(
              label: '수업 종료',
              value: workout.workoutEndSound,
              onChanged: (sound) => onChanged(custom(workoutEnd: sound)),
              onPreview: preview,
            ),
          ],
        ),
      ],
    );
  }
}

class _SoundEventSelector extends StatelessWidget {
  const _SoundEventSelector({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onPreview,
  });

  final String label;
  final WorkoutSound value;
  final ValueChanged<WorkoutSound> onChanged;
  final ValueChanged<WorkoutSound> onPreview;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 230,
    child: Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<WorkoutSound>(
            key: ValueKey('$label-${value.name}'),
            initialValue: value,
            decoration: InputDecoration(labelText: label, isDense: true),
            items: WorkoutSound.values
                .map(
                  (sound) =>
                      DropdownMenuItem(value: sound, child: Text(sound.label)),
                )
                .toList(),
            onChanged: (sound) {
              if (sound == null) return;
              onChanged(sound);
              onPreview(sound);
            },
          ),
        ),
        IconButton(
          tooltip: '$label 미리 듣기',
          onPressed: () => onPreview(value),
          icon: const Icon(Icons.play_circle_outline_rounded),
        ),
      ],
    ),
  );
}
