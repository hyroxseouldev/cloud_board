import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_library_picker.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
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
    this.onSaveTimer,
    this.brandL = '',
    this.brandR = '',
    this.workout,
  });
  final WorkoutModule module;
  final Future<bool> Function(WorkoutModule) onSave;
  final Future<bool> Function(WorkoutModule)? onSaveTimer;
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
            onSaveTimer: (timing) async {
              final latest = ref
                  .read(workoutControllerProvider)
                  .value
                  ?.where((w) => w.id == workoutId)
                  .firstOrNull;
              if (latest == null ||
                  !latest.modules.any((m) => m.id == moduleId)) {
                return false;
              }
              return await ref
                      .read(workoutActionControllerProvider.notifier)
                      .save(
                        latest.copyWith(
                          modules: [
                            for (final m in latest.modules)
                              if (m.id == moduleId)
                                copySlideTiming(m, timing)
                              else
                                m,
                          ],
                        ),
                      ) !=
                  null;
            },
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
    final description = useTextEditingController(text: module.text);
    final section = useState(1);
    final settingsScroll = useScrollController();
    final revision = useState(0);
    final previewRest = useState(false);
    final previewExpanded = useState(true);
    final selectedBlockId = useState<String?>(null);
    final blocks = effectiveIntervalBlocks(module);
    useEffect(() {
      for (final item in [(description, module.text)]) {
        if (item.$1.text != item.$2) {
          item.$1.value = TextEditingValue(
            text: item.$2,
            selection: TextSelection.collapsed(offset: item.$2.length),
          );
        }
      }
      return null;
    }, [module.text]);
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
      if (module.name.trim().isEmpty) {
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
      final candidate = module.copyWith(name: module.name.trim());
      try {
        final saved = await request.onSave(candidate);
        if (!context.mounted) return;
        if (!saved) {
          error.value = '저장하지 못했습니다. 편집 내용은 유지됩니다. 연결을 확인하고 다시 저장해 주세요.';
          return;
        }
        await actions.markSaved(candidate);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('슬라이드를 저장했습니다.')));
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

    Future<void> pickBackgroundImage() async {
      try {
        final file = await ImagePicker().pickImage(source: ImageSource.gallery);
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
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(44, 32),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        textStyle: const TextStyle(fontFamily: 'Pretendard', fontSize: 12),
        visualDensity: VisualDensity.compact,
      ),
      selected: {previewRest.value},
      showSelectedIcon: false,
      onSelectionChanged: (values) => previewRest.value = values.first,
    );
    final preview = Material(
      key: const ValueKey('slide-preview-card'),
      color: Theme.of(context).colorScheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showPreview =
              previewExpanded.value && constraints.maxHeight >= 150;
          final imageHeight = math.min(
            constraints.maxWidth * 9 / 16,
            math.max(0.0, constraints.maxHeight - 57),
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                key: const ValueKey('slide-preview-toolbar'),
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          blocks.length > 1
                              ? '미리보기 · 블록 ${blocks.indexOf(selectedBlock) + 1}'
                              : '미리보기',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: SlideEditorStyle.accent,
                          ),
                        ),
                      ),
                      if (showPreview) phaseSelector,
                      IconButton(
                        key: const ValueKey('slide-preview-rehearse'),
                        tooltip: '전체 화면 · 시험 재생',
                        onPressed: rehearse,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          iconSize: 22,
                          foregroundColor: SlideEditorStyle.accent,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                      ),
                      IconButton(
                        key: const ValueKey('slide-preview-toggle'),
                        tooltip: previewExpanded.value ? '미리보기 접기' : '미리보기 펼치기',
                        style: IconButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          iconSize: 22,
                          foregroundColor: SlideEditorStyle.accent,
                        ),
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
                ),
              ),
              if (showPreview) const Divider(height: 1),
              if (showPreview)
                SizedBox(
                  height: imageHeight,
                  width: double.infinity,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: WorkoutSlidePreview(
                        borderRadius: 0,
                        module: withIntervalBlocks(module, [selectedBlock]),
                        isRest: previewRest.value,
                        brandL: request.brandL,
                        brandR: request.brandR,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );

    void selectSection(int value) {
      FocusScope.of(context).unfocus();
      section.value = value;
      if (settingsScroll.hasClients) settingsScroll.jumpTo(0);
    }

    final titleButton = TextButton(
      key: const ValueKey('slide-title-button'),
      style: TextButton.styleFrom(
        foregroundColor: SlideEditorStyle.accent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        minimumSize: const Size(44, 44),
        alignment: Alignment.centerLeft,
      ),
      onPressed: busy.value
          ? null
          : () async {
              FocusScope.of(context).unfocus();
              final edited = await showDialog<String>(
                context: context,
                builder: (_) => _SlideTitleDialog(initialValue: module.name),
              );
              if (edited == null || !context.mounted) return;
              final latest = ref.read(provider).module;
              if (edited != latest.name) update(latest.copyWith(name: edited));
            },
      child: Tooltip(
        message: '슬라이드 제목 수정',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                module.name.isEmpty ? '슬라이드 제목' : module.name,
                key: const ValueKey('slide-title-text'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.edit_outlined, size: 18),
          ],
        ),
      ),
    );
    final workTotal = blocks.fold(0, (sum, b) => sum + b.workSeconds * b.sets);
    final restTotal = blocks.fold(
      0,
      (sum, b) => sum + b.restSeconds * (b.sets - 1),
    );
    final summary = Material(
      color: Theme.of(context).colorScheme.surface,
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
                onSave: request.onSaveTimer ?? request.onSave,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 22,
                color: SlideEditorStyle.accent,
              ),
              const SizedBox(width: 8),
              Text(
                durationLabel(total),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: SlideEditorStyle.accent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Text('운동 ${durationLabel(workTotal)}'),
                    Text('휴식 ${durationLabel(restTotal)}'),
                    Text('${blocks.fold(0, (sum, b) => sum + b.sets)}세트'),
                    if (blocks.length > 1) Text('${blocks.length}블록'),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: SlideEditorStyle.muted),
            ],
          ),
        ),
      ),
    );

    final settings = Form(
      key: form,
      child: section.value == 4
          ? SlideLibraryPicker(
              scope: request.workout?.ownerId ?? 'local',
              onSelect: (template) async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => SlideLibraryReplacementDialog(
                    template: template,
                    brandL: request.brandL,
                    brandR: request.brandR,
                  ),
                );
                if (confirmed != true || !context.mounted) return;
                resetFields(() => actions.replaceWithTemplate(template));
                selectedBlockId.value = null;
                previewRest.value = false;
                selectSection(1);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('슬라이드를 교체했습니다. 저장 전까지 실행 취소로 되돌릴 수 있습니다.'),
                  ),
                );
              },
            )
          : ListView(
              controller: settingsScroll,
              key: const ValueKey('slide-editor-settings'),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              children: [
                if (section.value == 1) ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const label = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '타이머 표시',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '숨겨도 운동 진행은 유지됩니다.',
                            style: TextStyle(
                              fontSize: 12,
                              color: SlideEditorStyle.muted,
                            ),
                          ),
                        ],
                      );
                      final toggle = SegmentedButton<TimerDisplayMode>(
                        key: const ValueKey('timer-display-toggle'),
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        segments: const [
                          ButtonSegment(
                            value: TimerDisplayMode.gaugeAndNumber,
                            label: Text('숫자 + 게이지'),
                          ),
                          ButtonSegment(
                            value: TimerDisplayMode.numberOnly,
                            label: Text('숫자만'),
                          ),
                          ButtonSegment(
                            value: TimerDisplayMode.hidden,
                            label: Text('안 보임'),
                          ),
                        ],
                        selected: {timerDisplayMode(module)},
                        onSelectionChanged: (values) {
                          final mode = values.first;
                          update(
                            module.copyWith(
                              showTimer: mode != TimerDisplayMode.hidden,
                              showTimerGauge:
                                  mode == TimerDisplayMode.gaugeAndNumber,
                            ),
                          );
                        },
                      );
                      if (constraints.maxWidth < 580) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [label, const SizedBox(height: 12), toggle],
                        );
                      }
                      return Row(
                        children: [
                          const Expanded(child: label),
                          const SizedBox(width: 16),
                          SizedBox(width: 310, child: toggle),
                        ],
                      );
                    },
                  ),
                  const Divider(height: 20),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('세트 표시'),
                    subtitle: const Text('타이머와 별도로 남은 세트 수를 표시합니다.'),
                    value: module.showSets,
                    onChanged: (v) => update(module.copyWith(showSets: v)),
                  ),
                  const SizedBox(height: 16),
                  SlideAppearanceControls(
                    key: ValueKey('appearance-${revision.value}'),
                    section: SlideAppearanceSection.timer,
                    value: module.appearance,
                    onChanged: (value, group) => update(
                      module.copyWith(appearance: value),
                      group: group,
                    ),
                  ),
                  const Divider(height: 24),
                  const Text(
                    '타이머 색상',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      HexColorField(
                        compact: true,
                        label: '세트 숫자 색상',
                        initialValue: colorHex(module.appearance.setsColor),
                        onChanged: (input) {
                          final color = parseHexColor(input);
                          if (color != null) {
                            update(
                              module.copyWith(
                                appearance: module.appearance.copyWith(
                                  setsColor: color,
                                ),
                              ),
                              group: '세트 숫자 색상',
                            );
                          }
                        },
                      ),
                      for (var i = 0; i < 4; i++)
                        HexColorField(
                          compact: true,
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
                              colorHex(
                                slideColor(module, rest: i.isOdd, text: i >= 2),
                              ),
                          onChanged: (v) => update(switch (i) {
                            0 => module.copyWith(workGaugeColor: v),
                            1 => module.copyWith(restGaugeColor: v),
                            2 => module.copyWith(workTextColor: v),
                            _ => module.copyWith(restTextColor: v),
                          }, group: 'phase-color-$i'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (section.value == 2) ...[
                  _SlideEditorMenuTile(
                    icon: Icons.image_outlined,
                    title: '이미지',
                    subtitle: module.imageSource.isEmpty
                        ? '선택된 이미지가 없습니다.'
                        : '배경 이미지 변경',
                    menuTooltip: '이미지 메뉴',
                    onSelected: (action) {
                      if (action == 'change') {
                        unawaited(pickBackgroundImage());
                      } else if (action == 'remove') {
                        update(module.copyWith(imageSource: ''));
                      }
                    },
                    items: [
                      PopupMenuItem(
                        value: 'change',
                        child: Text(
                          module.imageSource.isEmpty ? '이미지 선택' : '이미지 변경',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'remove',
                        enabled: module.imageSource.isNotEmpty,
                        child: const Text('이미지 제거'),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  _SlideEditorMenuTile(
                    icon: Icons.palette_outlined,
                    title: '스타일',
                    subtitle: '색상·배치·표시 옵션',
                    menuTooltip: '스타일 메뉴',
                    onSelected: (action) {
                      if (action == 'save') unawaited(saveStyle());
                      if (action == 'load') unawaited(loadStyle());
                    },
                    items: const [
                      PopupMenuItem(value: 'save', child: Text('스타일 저장')),
                      PopupMenuItem(value: 'load', child: Text('스타일 불러오기')),
                    ],
                  ),
                  const Divider(height: 24),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('이미지 꽉 채우기'),
                    value: module.coverImage,
                    onChanged: (v) => update(module.copyWith(coverImage: v)),
                  ),
                  SlideAppearanceControls(
                    section: SlideAppearanceSection.visibility,
                    value: module.appearance,
                    onChanged: (value, group) => update(
                      module.copyWith(appearance: value),
                      group: group,
                    ),
                  ),
                  const Divider(height: 24),
                  TextFormField(
                    controller: description,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: '화면 텍스트'),
                    onChanged: (v) =>
                        update(module.copyWith(text: v), group: 'body'),
                  ),
                  const Divider(height: 24),
                  const Text(
                    '색상',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SlideAppearanceControls(
                    key: ValueKey('background-appearance-${revision.value}'),
                    section: SlideAppearanceSection.background,
                    value: module.appearance,
                    onChanged: (value, group) => update(
                      module.copyWith(appearance: value),
                      group: group,
                    ),
                  ),
                ],
                if (section.value == 3) ...[
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('전환음'),
                    subtitle: const Text('이 슬라이드의 마지막 3초와 구간 전환에 소리를 냅니다.'),
                    value: module.beep,
                    onChanged: (v) => update(module.copyWith(beep: v)),
                  ),
                  const Text('소리 종류와 볼륨은 워크아웃 설정을 따릅니다.'),
                  const SizedBox(height: 12),
                  const Text(
                    '소리는 상단 미리보기의 재생 버튼으로 확인할 수 있어요.',
                    style: TextStyle(
                      fontSize: 12,
                      color: SlideEditorStyle.muted,
                    ),
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
          titleSpacing: 0,
          title: AbsorbPointer(
            absorbing: busy.value,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: titleButton,
              ),
            ),
          ),
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
              child: IconButton(
                key: const ValueKey('slide-save-button'),
                tooltip: busy.value
                    ? '저장 중'
                    : error.value == null
                    ? '저장'
                    : '다시 저장',
                style: IconButton.styleFrom(
                  foregroundColor: SlideEditorStyle.accent,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: busy.value ? null : save,
                icon: busy.value
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          semanticsLabel: '저장 중',
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 24),
              ),
            ),
          ],
        ),
        bottomNavigationBar: AbsorbPointer(
          absorbing: busy.value,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<int>(
                        key: const ValueKey('slide-editor-tabs'),
                        style: SegmentedButton.styleFrom(
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                          backgroundColor: const Color(0xFFF5F4F8),
                          selectedBackgroundColor: const Color(0xFFDEDBED),
                          minimumSize: const Size(44, 44),
                          textStyle: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        segments: const [
                          ButtonSegment(value: 1, label: Text('타이머')),
                          ButtonSegment(value: 2, label: Text('배경')),
                          ButtonSegment(value: 3, label: Text('소리')),
                          ButtonSegment(value: 4, label: Text('라이브러리')),
                        ],
                        showSelectedIcon: false,
                        selected: {section.value},
                        onSelectionChanged: (values) =>
                            selectSection(values.first),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      state.storageError ??
                          (state.dirty
                              ? (state.localSaved
                                    ? '저장 필요 · 이 기기에 임시저장됨'
                                    : '저장 필요 · 임시저장 중…')
                              : '저장됨'),
                      style: TextStyle(
                        fontSize: 12,
                        color: state.storageError == null
                            ? SlideEditorStyle.muted
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
              const Divider(height: 1),
              summary,
              const Divider(height: 1),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Column(
                    children: [
                      if (MediaQuery.viewInsetsOf(context).bottom == 0 &&
                          constraints.maxHeight >= 160) ...[
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: constraints.maxHeight * .6,
                          ),
                          child: preview,
                        ),
                        const Divider(height: 1),
                      ],
                      Expanded(child: settings),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideEditorMenuTile extends HookWidget {
  const _SlideEditorMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.menuTooltip,
    required this.items,
    required this.onSelected,
  });
  final IconData icon;
  final String title, subtitle, menuTooltip;
  final List<PopupMenuEntry<String>> items;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final menu = useMemoized(() => GlobalKey<PopupMenuButtonState<String>>());
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      minVerticalPadding: 12,
      leading: Icon(icon, color: SlideEditorStyle.accent),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: SlideEditorStyle.muted),
      ),
      trailing: PopupMenuButton<String>(
        key: menu,
        tooltip: menuTooltip,
        icon: const Icon(Icons.more_vert, color: SlideEditorStyle.accent),
        itemBuilder: (_) => items,
        onSelected: onSelected,
      ),
      onTap: () => menu.currentState?.showButtonMenu(),
    );
  }
}

class _SlideTitleDialog extends HookWidget {
  const _SlideTitleDialog({required this.initialValue});
  final String initialValue;
  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: initialValue);
    final form = useMemoized(() => GlobalKey<FormState>());
    void confirm() {
      if (form.currentState!.validate()) {
        Navigator.pop(context, controller.text.trim());
      }
    }

    return AppAlertDialog(
      title: const Text('슬라이드 제목 수정'),
      content: Form(
        key: form,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: '슬라이드 제목'),
          validator: (value) => value == null || value.trim().isEmpty
              ? '슬라이드 제목을 입력해 주세요.'
              : null,
          onFieldSubmitted: (_) => confirm(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: confirm, child: const Text('변경')),
      ],
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
