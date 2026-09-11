import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_editor_style.dart';

/// Edits the parent workout draft; closing the sheet does not save or discard it.
class WorkoutSettingsSheet extends StatelessWidget {
  const WorkoutSettingsSheet({
    super.key,
    required this.draft,
    required this.brandL,
    required this.brandR,
  });

  final ValueNotifier<Workout> draft;
  final TextEditingController brandL;
  final TextEditingController brandR;

  @override
  Widget build(BuildContext context) => Theme(
    data: SlideEditorStyle.theme(Theme.of(context)),
    child: FractionallySizedBox(
      heightFactor: .9,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gutter = constraints.maxWidth >= 600 ? 32.0 : 24.0;
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(gutter, 20, 12, 16),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '워크아웃 설정',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '설정 닫기',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      key: const ValueKey('workout-settings-scroll'),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(gutter, 28, gutter, 32),
                      child: Column(
                        key: const ValueKey('workout-display-sound-settings'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionHeading(
                            icon: Icons.tv_rounded,
                            title: '화면 문구',
                            description: '수업 화면 하단에 표시할 문구입니다.',
                          ),
                          const SizedBox(height: 20),
                          _SettingsGrid(
                            children: [
                              TextField(
                                controller: brandL,
                                decoration: const InputDecoration(
                                  labelText: '화면 왼쪽 아래 문구',
                                  hintText: '예: 스튜디오 이름',
                                ),
                              ),
                              TextField(
                                controller: brandR,
                                decoration: const InputDecoration(
                                  labelText: '화면 오른쪽 아래 문구',
                                  hintText: '예: 오늘도 나만의 페이스로',
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 56),
                          ValueListenableBuilder<Workout>(
                            valueListenable: draft,
                            builder: (context, workout, _) =>
                                _SoundSettingsSection(
                                  workout: workout,
                                  onChanged: (value) => draft.value = value,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: EdgeInsets.fromLTRB(gutter, 14, gutter, 16),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '워크아웃 저장 시 함께 저장돼요.',
                            style: TextStyle(
                              color: SlideEditorStyle.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('설정 완료'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 22, color: SlideEditorStyle.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          ?action,
        ],
      ),
      const SizedBox(height: 8),
      Text(
        description,
        style: const TextStyle(color: SlideEditorStyle.muted, fontSize: 13),
      ),
    ],
  );
}

class _SettingsGrid extends StatelessWidget {
  const _SettingsGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final twoColumns =
          constraints.maxWidth >= 560 &&
          MediaQuery.textScalerOf(context).scale(14) <= 20;
      final width = twoColumns
          ? (constraints.maxWidth - 20) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: 20,
        runSpacing: 20,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          icon: Icons.graphic_eq_rounded,
          title: '수업 사운드',
          description: '카운트다운과 운동·휴식 전환을 서로 다른 소리로 알려줍니다.',
          action: IconButton(
            tooltip: '현재 운동 시작음 미리 듣기',
            onPressed: () => preview(workout.workStartSound),
            icon: const Icon(Icons.volume_up_rounded),
          ),
        ),
        const SizedBox(height: 20),
        const _FieldLabel('사운드 테마'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...WorkoutSoundTheme.values
                .where((value) => value != WorkoutSoundTheme.custom)
                .map(
                  (option) => ChoiceChip(
                    label: Text(option.label),
                    selectedColor: SlideEditorStyle.wheel,
                    backgroundColor: SlideEditorStyle.surface,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    tooltip: option.description,
                    selected: workout.soundTheme == option,
                    onSelected: (_) => applyTheme(option),
                  ),
                ),
            if (workout.soundTheme == WorkoutSoundTheme.custom)
              const Chip(
                label: Text('직접 설정'),
                avatar: Icon(Icons.tune_rounded, size: 16),
                backgroundColor: SlideEditorStyle.wheel,
                side: BorderSide.none,
              ),
          ],
        ),
        const SizedBox(height: 20),
        const _FieldLabel('볼륨'),
        Row(
          children: [
            const Icon(Icons.volume_down_rounded, size: 20),
            Expanded(
              child: Slider(
                semanticFormatterCallback: (value) =>
                    '볼륨 ${(value * 100).round()}%',
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
        const SizedBox(height: 20),
        const _FieldLabel('상황별 사운드'),
        const SizedBox(height: 16),
        _SettingsGrid(
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
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: DropdownButtonFormField<WorkoutSound>(
          key: ValueKey('$label-${value.name}'),
          initialValue: value,
          isExpanded: true,
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
      const SizedBox(width: 8),
      IconButton.filledTonal(
        style: IconButton.styleFrom(
          backgroundColor: SlideEditorStyle.surface,
          foregroundColor: SlideEditorStyle.accent,
          minimumSize: const Size(48, 48),
        ),
        tooltip: '$label 미리 듣기',
        onPressed: () => onPreview(value),
        icon: const Icon(Icons.play_circle_outline_rounded),
      ),
    ],
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: SlideEditorStyle.muted,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
  );
}
