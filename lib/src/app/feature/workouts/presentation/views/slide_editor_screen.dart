import 'package:cloud_board/src/app/core/widgets/app_dropdown_form_field.dart';

import 'dart:async';

import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:cloud_board/src/app/core/theme/app_style.dart';
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
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/timer_editor_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_editor_style.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_editor_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/slide_editor_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_appearance_controls.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_rehearsal_screen.dart';

class SlideEditRequest {
  SlideEditRequest({
    required this.module,
    required this.onSave,
    this.brandL = '',
    this.brandR = '',
    this.workout,
  });
  final WorkoutModule module;
  final Future<bool> Function(WorkoutModule) onSave;
  final String brandL;
  final String brandR;
  final Workout? workout;
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
            workout: workout,
            brandL: workout.brandL,
            brandR: workout.brandR,
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

class _SlideEditor extends StatelessWidget {
  const _SlideEditor({
    required this.request,
    required this.guard,
    required this.workoutId,
  });
  final SlideEditRequest request;
  final ExitGuard guard;
  final String workoutId;

  @override
  Widget build(BuildContext context) => Theme(
    data: SlideEditorStyle.theme(Theme.of(context)),
    child: _SlideEditorBody(
      request: request,
      guard: guard,
      workoutId: workoutId,
    ),
  );
}

class _SlideEditorBody extends HookConsumerWidget {
  const _SlideEditorBody({
    required this.request,
    required this.guard,
    required this.workoutId,
  });
  final String workoutId;
  final SlideEditRequest request;
  final ExitGuard guard;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final original = useMemoized(() => request.module);
    final provider = slideEditorControllerProvider(
      workoutId,
      original,
      request.workout?.ownerId ?? 'local',
    );
    final state = ref.watch(provider);
    final actions = ref.read(provider.notifier);
    final module = state.module;
    final busy = useState(false);
    final error = useState<String?>(null);
    final form = useMemoized(() => GlobalKey<FormState>());
    final name = useTextEditingController(text: module.name);
    final description = useTextEditingController(text: module.text);
    final section = useState(1);
    final settingsScroll = useScrollController();
    final revision = useState(0);
    final previewRest = useState(false);
    final previewExpanded = useState(true);
    final selectedBlockId = useState<String?>(null);
    final blocks = effectiveIntervalBlocks(module);
    useEffect(() {
      for (final item in [(name, module.name), (description, module.text)]) {
        if (item.$1.text != item.$2) {
          item.$1.value = TextEditingValue(
            text: item.$2,
            selection: TextSelection.collapsed(offset: item.$2.length),
          );
        }
      }
      return null;
    }, [module.name, module.text]);
    useOnAppLifecycleStateChange((previous, next) {
      if (next != AppLifecycleState.resumed) unawaited(actions.flush());
    });

    void update(WorkoutModule value, {String? group}) =>
        actions.update(value, group: group);
    void resetFields(VoidCallback change) {
      FocusScope.of(context).unfocus();
      change();
      revision.value++;
    }

    Future<void> save() async {
      if (busy.value) return;
      if (name.text.trim().isEmpty) {
        section.value = 1;
        error.value = '슬라이드 제목을 입력해 주세요.';
        return;
      }
      if (!form.currentState!.validate()) return;
      // Hidden sections must also pass validation.
      if ([
        module.workGaugeColor,
        module.restGaugeColor,
        module.workTextColor,
        module.restTextColor,
      ].any((v) => v != null && !isHexColor(v))) {
        section.value = 1;
        error.value = '색상을 #RRGGBB 형식으로 입력해 주세요.';
        return;
      }
      busy.value = true;
      error.value = null;
      final candidate = module.copyWith(name: name.text.trim());
      try {
        final saved = await request.onSave(candidate);
        if (!context.mounted) return;
        if (!saved) {
          error.value = '저장하지 못했습니다. 편집 내용은 유지됩니다. 연결을 확인하고 다시 저장해 주세요.';
          return;
        }
        await actions.markSaved(candidate);
        if (!context.mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/editor/$workoutId');
          }
        });
      } catch (_) {
        if (context.mounted) {
          error.value = '저장하지 못했습니다. 편집 내용은 유지됩니다. 다시 저장해 주세요.';
        }
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    Future<void> saveStyle() async {
      final styleName = await showDialog<String>(
        context: context,
        builder: (_) => const _StyleNameDialog(),
      );
      if (styleName == null || !context.mounted) return;
      try {
        await actions.saveStyle(styleName);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이 기기에 스타일을 저장했습니다. 같은 이름은 덮어씁니다.')),
          );
        }
      } catch (_) {
        if (context.mounted) error.value = '스타일을 저장하지 못했습니다. 다시 시도해 주세요.';
      }
    }

    Future<void> loadStyle() async {
      final green = WorkoutModule.empty('green').copyWith(
        name: '초록 링 · 검정 숫자',
        workGaugeColor: '#34C759',
        restGaugeColor: '#0047FF',
        workTextColor: '#000000',
        restTextColor: '#000000',
        appearance: const SlideAppearance(
          titleColor: 0xFF000000,
          bodyColor: 0xFF000000,
          setsColor: 0xFF000000,
          brandColor: 0xFF000000,
        ),
      );
      final selected = await showModalBottomSheet<WorkoutModule>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .7,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  '스타일 불러오기',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text('색상·배치·표시 옵션을 가져옵니다. 시간, 제목, 이미지는 유지됩니다.'),
                const SizedBox(height: 16),
                for (final entry in [
                  (
                    '기본 스타일',
                    [
                      green,
                      WorkoutModule.empty('default').copyWith(name: '기본 · 흰색'),
                    ],
                  ),
                  ('내 스타일 · 이 기기', state.styles),
                  (
                    '이 워크아웃의 슬라이드',
                    request.workout?.modules
                            .where((v) => v.id != module.id)
                            .toList() ??
                        <WorkoutModule>[],
                  ),
                ]) ...[
                  Text(
                    entry.$1,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (entry.$2.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('아직 없습니다.'),
                    ),
                  for (final style in entry.$2)
                    ListTile(
                      title: Text(style.name),
                      leading: Icon(
                        Icons.palette_outlined,
                        color: Color(
                          slideColor(style, rest: false, text: false),
                        ),
                      ),
                      onTap: () => Navigator.pop(sheetContext, style),
                      trailing: entry.$1.startsWith('내 스타일')
                          ? IconButton(
                              tooltip: '스타일 삭제',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                try {
                                  await actions.deleteStyle(style.id);
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    error.value = '스타일을 삭제하지 못했습니다.';
                                  }
                                }
                              },
                            )
                          : const Icon(Icons.chevron_right),
                    ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      );
      if (selected != null && context.mounted) {
        resetFields(() => update(applySlideStyle(module, selected)));
      }
    }

    void rehearse() {
      FocusScope.of(context).unfocus();
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SlideRehearsalScreen(
            module: module,
            brandL: request.brandL,
            brandR: request.brandR,
            workout: request.workout,
          ),
        ),
      );
    }

    final selectedBlock =
        blocks.where((v) => v.id == selectedBlockId.value).firstOrNull ??
        blocks.first;
    final total = workoutModuleDuration(module);
    final phaseSelector = SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text('운동')),
        ButtonSegment(value: true, label: Text('휴식')),
      ],
      selected: {previewRest.value},
      showSelectedIcon: false,
      onSelectionChanged: (values) => previewRest.value = values.first,
    );
    final preview = Material(
      key: const ValueKey('slide-preview-card'),
      color: SlideEditorStyle.surface,
      borderRadius: BorderRadius.circular(AppStyle.controlRadius),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 440;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '미리보기',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (previewExpanded.value && !compact) phaseSelector,
                    IconButton(
                      key: const ValueKey('slide-preview-rehearse'),
                      tooltip: '전체 화면 · 시험 재생',
                      onPressed: rehearse,
                      icon: const Icon(Icons.play_arrow_rounded),
                    ),
                    IconButton(
                      key: const ValueKey('slide-preview-toggle'),
                      tooltip: previewExpanded.value ? '미리보기 접기' : '미리보기 펼치기',
                      onPressed: () =>
                          previewExpanded.value = !previewExpanded.value,
                      icon: Icon(
                        previewExpanded.value
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                      ),
                    ),
                  ],
                ),
                if (previewExpanded.value) ...[
                  if (compact)
                    Align(
                      alignment: Alignment.centerRight,
                      child: phaseSelector,
                    ),
                  const SizedBox(height: 12),
                  WorkoutSlidePreview(
                    module: withIntervalBlocks(module, [selectedBlock]),
                    isRest: previewRest.value,
                    brandL: request.brandL,
                    brandR: request.brandR,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '블록 ${blocks.indexOf(selectedBlock) + 1} · ${durationLabel(total)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: SlideEditorStyle.muted,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );

    final summary = LayoutBuilder(
      builder: (context, constraints) {
        final titleField = TextFormField(
          controller: name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
            labelText: '슬라이드 제목',
            floatingLabelBehavior: FloatingLabelBehavior.never,
            suffixIcon: Icon(Icons.edit_outlined, size: 22),
            contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          ),
          validator: (v) =>
              v == null || v.trim().isEmpty ? '제목을 입력해 주세요.' : null,
          onChanged: (v) => update(module.copyWith(name: v), group: 'name'),
        );
        final timer = Material(
          color: SlideEditorStyle.surface,
          borderRadius: BorderRadius.circular(AppStyle.controlRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('slide-timer-summary'),
            onTap: () {
              FocusScope.of(context).unfocus();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TimerEditorScreen(
                    workoutId: workoutId,
                    original: original,
                    scope: request.workout?.ownerId ?? 'local',
                    onSelectBlock: (id) => selectedBlockId.value = id,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '타이머',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: SlideEditorStyle.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    durationLabel(total),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: SlideEditorStyle.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        if (constraints.maxWidth < 320 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [titleField, const SizedBox(height: 12), timer],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleField),
            const SizedBox(width: 16),
            Expanded(child: timer),
          ],
        );
      },
    );

    final settings = Form(
      key: form,
      child: ListView(
        controller: settingsScroll,
        key: const ValueKey('slide-editor-settings'),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        children: [
          if (MediaQuery.viewInsetsOf(context).bottom == 0) ...[
            preview,
            const SizedBox(height: 24),
          ],
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('화면')),
              ButtonSegment(value: 2, label: Text('소리')),
            ],
            selected: {section.value},
            onSelectionChanged: (values) {
              FocusScope.of(context).unfocus();
              section.value = values.first;
            },
          ),
          const SizedBox(height: 20),
          if (section.value == 1) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: saveStyle,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('스타일 저장'),
                ),
                OutlinedButton.icon(
                  onPressed: loadStyle,
                  icon: const Icon(Icons.palette_outlined),
                  label: const Text('스타일 불러오기'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppDropdownFormField<TimerDisplayMode>(
              key: ValueKey(
                'timer-mode-${revision.value}-${module.showTimer}-${module.showTimerGauge}',
              ),
              initialValue: timerDisplayMode(module),
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
                if (mode != null) {
                  update(
                    module.copyWith(
                      showTimer: mode != TimerDisplayMode.hidden,
                      showTimerGauge: mode == TimerDisplayMode.gaugeAndNumber,
                    ),
                  );
                }
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('세트 표시'),
              subtitle: const Text('타이머와 별도로 남은 세트 수를 표시합니다.'),
              value: module.showSets,
              onChanged: (v) => update(module.copyWith(showSets: v)),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < 4; i++)
              HexColorField(
                key: ValueKey('phase-color-$i-${revision.value}'),
                label: const [
                  '운동 게이지 색상',
                  '휴식 게이지 색상',
                  '운동 시간 텍스트 색상',
                  '휴식 시간 텍스트 색상',
                ][i],
                initialValue:
                    [
                      module.workGaugeColor,
                      module.restGaugeColor,
                      module.workTextColor,
                      module.restTextColor,
                    ][i] ??
                    colorHex(slideColor(module, rest: i.isOdd, text: i >= 2)),
                onChanged: (v) => update(switch (i) {
                  0 => module.copyWith(workGaugeColor: v),
                  1 => module.copyWith(restGaugeColor: v),
                  2 => module.copyWith(workTextColor: v),
                  _ => module.copyWith(restTextColor: v),
                }, group: 'phase-color-$i'),
              ),
            SlideAppearanceControls(
              key: ValueKey('appearance-${revision.value}'),
              value: module.appearance,
              onChanged: (value, group) =>
                  update(module.copyWith(appearance: value), group: group),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: description,
              maxLines: 4,
              decoration: const InputDecoration(labelText: '화면 텍스트'),
              onChanged: (v) => update(module.copyWith(text: v), group: 'body'),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('이미지 꽉 채우기'),
              value: module.coverImage,
              onChanged: (v) => update(module.copyWith(coverImage: v)),
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
                  if (context.mounted) {
                    actions.update(
                      ref
                          .read(provider)
                          .module
                          .copyWith(
                            imageSource: WorkoutImageSource.fromBytes(
                              bytes,
                              contentType: file.mimeType,
                            ),
                          ),
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    error.value = '이미지를 불러오지 못했습니다. 다시 선택해 주세요.';
                  }
                }
              },
            ),
            if (module.imageSource.isNotEmpty)
              TextButton(
                onPressed: () => update(module.copyWith(imageSource: '')),
                child: const Text('이미지 제거'),
              ),
          ],
          if (section.value == 2) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('전환음'),
              subtitle: const Text('이 슬라이드의 마지막 3초와 구간 전환에 소리를 냅니다.'),
              value: module.beep,
              onChanged: (v) => update(module.copyWith(beep: v)),
            ),
            const Text('소리 종류와 볼륨은 워크아웃 설정을 따릅니다.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: rehearse,
              icon: const Icon(Icons.volume_up_outlined),
              label: const Text('시험 재생에서 소리 확인'),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );

    return UnsavedChangesGuard(
      guard: guard,
      dirty: state.dirty,
      blocked: busy.value,
      onDiscard: () async {
        try {
          await actions.discard();
        } catch (_) {
          /* Keep editing exit available when local storage is unavailable. */
        }
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              tooltip: '실행 취소',
              onPressed: busy.value || state.undo.isEmpty
                  ? null
                  : () => resetFields(actions.undo),
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: '다시 실행',
              onPressed: busy.value || state.redo.isEmpty
                  ? null
                  : () => resetFields(actions.redo),
              icon: const Icon(Icons.redo),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: busy.value ? null : save,
                child: Text(
                  busy.value
                      ? '저장 중…'
                      : error.value == null
                      ? '저장'
                      : '다시 저장',
                ),
              ),
            ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: busy.value,
          child: Column(
            children: [
              if (state.recovery != null)
                MaterialBanner(
                  content: const Text('이 기기에 저장하지 않은 편집 내용이 있습니다.'),
                  actions: [
                    TextButton(
                      onPressed: actions.dismissRecovery,
                      child: const Text('버리기'),
                    ),
                    TextButton(
                      onPressed: () => resetFields(actions.restore),
                      child: const Text('복원'),
                    ),
                  ],
                ),
              if (error.value != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    error.value!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      flex: 3,
                      child: Text(
                        '슬라이드 편집',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          state.storageError ??
                              (state.dirty
                                  ? (state.localSaved
                                        ? '저장 필요 · 이 기기에 임시저장됨'
                                        : '저장 필요 · 임시저장 중…')
                                  : '저장됨'),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            color: state.storageError == null
                                ? SlideEditorStyle.muted
                                : Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: summary,
              ),
              Expanded(child: settings),
            ],
          ),
        ),
      ),
    );
  }
}

class _StyleNameDialog extends HookWidget {
  const _StyleNameDialog();
  @override
  Widget build(BuildContext context) {
    final name = useTextEditingController();
    useListenable(name);
    return AppAlertDialog(
      title: const Text('스타일 저장'),
      content: TextField(
        controller: name,
        autofocus: true,
        maxLength: 40,
        decoration: const InputDecoration(
          labelText: '스타일 이름',
          hintText: '예: 초록 링 / 검정 숫자',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: name.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, name.text.trim()),
          child: const Text('스타일 저장'),
        ),
      ],
    );
  }
}
