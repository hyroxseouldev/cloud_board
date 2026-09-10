import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_board/src/app/core/widgets/hex_color_field.dart';
import 'package:cloud_board/src/app/core/utils/hex_color.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image.dart';

class SlideEditRequest {
  SlideEditRequest({required this.module, required this.onSave});
  final WorkoutModule module;
  final Future<bool> Function(WorkoutModule) onSave;
}

class SlideEditorScreen extends ConsumerWidget {
  const SlideEditorScreen({
    super.key,
    required this.workoutId,
    required this.moduleId,
    required this.guard,
    this.request,
  });
  final String workoutId, moduleId;
  final ExitGuard guard;
  final SlideEditRequest? request;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (request != null) {
      return _SlideEditor(
        request: request!,
        guard: guard,
        workoutId: workoutId,
      );
    }
    final workouts = ref.watch(workoutControllerProvider);
    return workouts.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('운동을 불러오지 못했습니다: $e'))),
      data: (items) {
        final workout = items.where((w) => w.id == workoutId).firstOrNull;
        final module = workout?.modules
            .where((m) => m.id == moduleId)
            .firstOrNull;
        if (workout == null || module == null) {
          return const Scaffold(body: Center(child: Text('슬라이드를 찾을 수 없습니다.')));
        }
        return _SlideEditor(
          guard: guard,
          workoutId: workoutId,
          request: SlideEditRequest(
            module: module,
            onSave: (updated) async {
              final latest =
                  ref
                      .read(workoutControllerProvider)
                      .value
                      ?.where((w) => w.id == workoutId)
                      .firstOrNull ??
                  workout;
              return await ref
                      .read(workoutActionControllerProvider.notifier)
                      .save(
                        latest.copyWith(
                          modules: latest.modules
                              .map((m) => m.id == moduleId ? updated : m)
                              .toList(),
                        ),
                      ) !=
                  null;
            },
          ),
        );
      },
    );
  }
}

class _SlideEditor extends HookWidget {
  const _SlideEditor({
    required this.request,
    required this.guard,
    required this.workoutId,
  });
  final String workoutId;
  final SlideEditRequest request;
  final ExitGuard guard;
  @override
  Widget build(BuildContext context) {
    final original = useMemoized(() => request.module);
    final draft = useState(original);
    final dirty = useState(false);
    final busy = useState(false);
    final error = useState<String?>(null);
    final form = useMemoized(() => GlobalKey<FormState>());
    final name = useTextEditingController(text: original.name);
    final description = useTextEditingController(text: original.text);
    final work = useTextEditingController(
      text: formatSlideTime(original.workSeconds),
    );
    final rest = useTextEditingController(
      text: formatSlideTime(original.restSeconds),
    );
    final sets = useTextEditingController(text: '${original.sets}');
    final colors = useState([
      colorHex(slideColor(original, rest: false, text: false)),
      colorHex(slideColor(original, rest: true, text: false)),
      colorHex(slideColor(original, rest: false, text: true)),
      colorHex(slideColor(original, rest: true, text: true)),
    ]);
    final touchedColors = useState(List.filled(4, false));
    Future<void> save() async {
      if (!form.currentState!.validate()) return;
      busy.value = true;
      error.value = null;
      try {
        final saved = await request.onSave(
          draft.value.copyWith(
            name: name.text.trim(),
            text: description.text,
            workSeconds: parseSlideTime(work.text)!,
            restSeconds: parseSlideTime(rest.text)!,
            sets: int.parse(sets.text),
            workGaugeColor: touchedColors.value[0]
                ? colors.value[0].toUpperCase()
                : original.workGaugeColor,
            restGaugeColor: touchedColors.value[1]
                ? colors.value[1].toUpperCase()
                : original.restGaugeColor,
            workTextColor: touchedColors.value[2]
                ? colors.value[2].toUpperCase()
                : original.workTextColor,
            restTextColor: touchedColors.value[3]
                ? colors.value[3].toUpperCase()
                : original.restTextColor,
          ),
        );
        if (!context.mounted) return;
        if (!saved) {
          error.value = '저장하지 못했습니다. 편집 내용은 유지됩니다. 연결을 확인하고 다시 저장해 주세요.';
          return;
        }
        dirty.value = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/editor/$workoutId');
            }
          }
        });
      } catch (e) {
        if (context.mounted) error.value = '저장하지 못했습니다: $e';
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    return UnsavedChangesGuard(
      guard: guard,
      dirty: dirty.value,
      blocked: busy.value,
      child: Scaffold(
        appBar: AppBar(title: const Text('슬라이드 편집')),
        body: AbsorbPointer(
          absorbing: busy.value,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Form(
                key: form,
                onChanged: () => dirty.value = true,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: '슬라이드 제목'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? '제목을 입력해 주세요.' : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: work,
                      decoration: const InputDecoration(
                        labelText: '운동 시간 (mm:ss)',
                        hintText: '01:30',
                      ),
                      keyboardType: TextInputType.datetime,
                      validator: (v) => (parseSlideTime(v ?? '') ?? 0) > 0
                          ? null
                          : '00:01 이상, mm:ss 형식으로 입력해 주세요. 초는 00~59입니다.',
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: rest,
                      decoration: const InputDecoration(
                        labelText: '휴식 시간 (mm:ss)',
                        hintText: '00:45',
                      ),
                      keyboardType: TextInputType.datetime,
                      validator: (v) => parseSlideTime(v ?? '') != null
                          ? null
                          : 'mm:ss 형식으로 입력해 주세요. 초는 00~59입니다.',
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: sets,
                      decoration: const InputDecoration(labelText: '전체 세트 수'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        return n != null && n >= 1 && n <= 999
                            ? null
                            : '1~999 사이의 세트 수를 입력해 주세요.';
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: description,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: '화면 텍스트'),
                    ),
                    DropdownButtonFormField<TimerDisplayMode>(
                      initialValue: timerDisplayMode(draft.value),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '타이머 표시',
                        helperText: '타이머를 숨겨도 운동 진행은 유지됩니다.',
                        helperMaxLines: 2,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: TimerDisplayMode.gaugeAndNumber,
                          child: Text('숫자 + 게이지'),
                        ),
                        DropdownMenuItem(
                          value: TimerDisplayMode.numberOnly,
                          child: Text('숫자만'),
                        ),
                        DropdownMenuItem(
                          value: TimerDisplayMode.hidden,
                          child: Text('안 보임'),
                        ),
                      ],
                      onChanged: (mode) {
                        if (mode == null) return;
                        draft.value = draft.value.copyWith(
                          showTimer: mode != TimerDisplayMode.hidden,
                          showTimerGauge:
                              mode == TimerDisplayMode.gaugeAndNumber,
                        );
                        dirty.value = true;
                      },
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('세트 표시'),
                      subtitle: const Text('타이머와 별도로 남은 세트 수를 표시합니다.'),
                      value: draft.value.showSets,
                      onChanged: (value) {
                        draft.value = draft.value.copyWith(showSets: value);
                        dirty.value = true;
                      },
                    ),
                    for (var i = 0; i < 4; i++)
                      HexColorField(
                        label: const [
                          '운동 게이지 색상',
                          '휴식 게이지 색상',
                          '운동 시간 텍스트 색상',
                          '휴식 시간 텍스트 색상',
                        ][i],
                        initialValue: colors.value[i],
                        onChanged: (v) {
                          final next = [...colors.value];
                          next[i] = v;
                          colors.value = next;
                          touchedColors.value = [...touchedColors.value]
                            ..[i] = true;
                          dirty.value = true;
                        },
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('전환음'),
                      value: draft.value.beep,
                      onChanged: (v) {
                        draft.value = draft.value.copyWith(beep: v);
                        dirty.value = true;
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('이미지 꽉 채우기'),
                      value: draft.value.coverImage,
                      onChanged: (v) {
                        draft.value = draft.value.copyWith(coverImage: v);
                        dirty.value = true;
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('배경 이미지 선택'),
                      onPressed: () async {
                        try {
                          final file = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1920,
                            imageQuality: 85,
                          );
                          if (file == null) return;
                          final bytes = await file.readAsBytes();
                          if (!context.mounted) return;
                          draft.value = draft.value.copyWith(
                            imageSource: WorkoutImageSource.fromBytes(
                              bytes,
                              contentType: file.mimeType,
                            ),
                          );
                          dirty.value = true;
                        } catch (e) {
                          if (context.mounted) {
                            error.value = '이미지를 불러오지 못했습니다: $e';
                          }
                        }
                      },
                    ),
                    if (draft.value.imageSource.isNotEmpty) ...[
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: WorkoutImage(
                          source: draft.value.imageSource,
                          fit: draft.value.coverImage
                              ? BoxFit.cover
                              : BoxFit.contain,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          draft.value = draft.value.copyWith(imageSource: '');
                          dirty.value = true;
                        },
                        child: const Text('이미지 제거'),
                      ),
                    ],
                    if (error.value != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          error.value!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: busy.value ? null : save,
                      icon: busy.value
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        busy.value
                            ? '저장 중…'
                            : error.value == null
                            ? '저장'
                            : '다시 저장',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
