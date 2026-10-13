import 'package:cloud_board/src/app/core/theme/app_motion.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/timer_summary.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_timeline.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_design_colors.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_design_section_editor.dart';
import 'package:cloud_board/src/app/core/widgets/app_bottom_tab_bar.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/prepare_workout_image.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_preferences_controller.dart';

import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_library_picker.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
import 'package:flutter/material.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/original_slide_template.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_page.dart';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_board/src/app/core/widgets/hex_color_field.dart';
import 'package:cloud_board/src/app/core/utils/hex_color.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_settings.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/views/timer_editor_screen.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_editor_style.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_style_picker.dart';
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
    this.needsInitialSave = false,
  });
  final WorkoutModule module;
  final Future<bool> Function(WorkoutModule) onSave;
  final String brandL;
  final String brandR;
  final Workout? workout;
  final bool needsInitialSave;
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
    final workouts = ref.watch(workoutDetailProvider(workoutId));
    return workouts.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('운동을 불러오지 못했습니다: $e'))),
      data: (workout) {
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
              // Save against the version this editor opened. Loading a newer
              // version here would hide a conflict and overwrite its slide.
              return await ref
                      .read(workoutActionControllerProvider.notifier)
                      .save(
                        workout.copyWith(
                          modules: workout.modules
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
    final previewSettings = request.workout == null
        ? null
        : ref.watch(workoutPreviewProvider(request.workout!));
    final renderedWorkout = previewSettings?.value ?? request.workout;
    final renderedBrandL = renderedWorkout?.brandL ?? request.brandL;
    final renderedBrandR = renderedWorkout?.brandR ?? request.brandR;

    final module = state.module;
    final originalTemplate = originalSlideTemplate(
      module.designStyle?.originalTemplate,
    );
    final originalDesign = originalTemplate != null;
    final structuredDesign =
        slideDesigns.containsKey(module.designTemplate) ||
        isStudioSlideDesign(module);
    final busy = useState(false);
    final needsInitialSave = useState(request.needsInitialSave);
    final timerConfigured = useState(false);
    final uploadProgress = ref.watch(workoutUploadProgressProvider);
    final error = useState<String?>(null);
    final form = useMemoized(() => GlobalKey<FormState>());
    final description = useTextEditingController(text: module.text);
    final designHeader = useTextEditingController(
      text: module.designHeaderLabel,
    );
    final designSubtitle = useTextEditingController(
      text: module.designSubtitle,
    );
    final section = useState(1);
    final sectionTransition = useAnimationController(
      duration: AppMotion.stateChange,
      initialValue: 1,
    );
    final sectionOpacity = sectionTransition.drive(
      CurveTween(curve: AppMotion.curve),
    );
    final settingsScroll = useScrollController();
    final revision = useState(0);
    final selectedBlockId = useState<String?>(null);
    final blocks = effectiveIntervalBlocks(module);
    useEffect(
      () {
        for (final item in [
          (description, module.text),
          (designHeader, module.designHeaderLabel),
          (designSubtitle, module.designSubtitle),
        ]) {
          if (item.$1.text != item.$2) {
            item.$1.value = TextEditingValue(
              text: item.$2,
              selection: TextSelection.collapsed(offset: item.$2.length),
            );
          }
        }
        return null;
      },
      [
        module.name,
        module.text,
        module.designHeaderLabel,
        module.designSubtitle,
      ],
    );
    useOnAppLifecycleStateChange((previous, next) {
      if (next != AppLifecycleState.resumed) unawaited(actions.flush());
    });

    void update(WorkoutModule value) => actions.update(value);
    void resetFields(VoidCallback change) {
      FocusScope.of(context).unfocus();
      change();
      revision.value++;
    }

    Future<void> save() async {
      if (busy.value || (!state.dirty && !needsInitialSave.value)) return;
      if (module.name.trim().isEmpty) {
        section.value = 1;
        error.value = '슬라이드 제목을 입력해 주세요.';
        return;
      }
      final timingError = timingValidationError(module);
      if (timingError != null) {
        section.value = 1;
        error.value = timingError;
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
        needsInitialSave.value = false;
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
            const SnackBar(content: Text('계정에 스타일을 저장했습니다. 같은 이름은 덮어씁니다.')),
          );
        }
      } catch (_) {
        if (context.mounted) error.value = '스타일을 저장하지 못했습니다. 다시 시도해 주세요.';
      }
    }

    Future<void> loadStyle() async {
      final selected = await showModalBottomSheet<WorkoutModule>(
        context: context,
        sheetAnimationStyle: AppMotion.sheet(context),
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => Consumer(
          builder: (context, sheetRef, _) => SlideStylePicker(
            styles: sheetRef.watch(provider.select((value) => value.styles)),
            slides:
                request.workout?.modules
                    .where((value) => value.id != module.id)
                    .toList() ??
                const [],
            onDelete: (style) => actions.deleteStyle(style.id),
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
        final source = await prepareWorkoutImage(
          await file.readAsBytes(),
          contentType: file.mimeType,
        );
        if (context.mounted) {
          actions.update(
            ref
                .read(provider)
                .module
                .copyWith(
                  imageSource: source,
                  designTemplate: null,
                  designStyle: null,
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
      if (previewSettings != null &&
          (previewSettings.isLoading || previewSettings.hasError)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              previewSettings.hasError
                  ? '공통 설정을 불러오지 못했습니다. 다시 시도해 주세요.'
                  : '공통 설정을 불러오고 있습니다.',
            ),
          ),
        );
        if (previewSettings.hasError) {
          ref.invalidate(workoutPreviewProvider(request.workout!));
        }
        return;
      }
      FocusScope.of(context).unfocus();
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SlideRehearsalScreen(
            module: module,
            brandL: renderedBrandL,
            brandR: renderedBrandR,
            workout: renderedWorkout,
          ),
        ),
      );
    }

    final selectedBlock =
        blocks.where((v) => v.id == selectedBlockId.value).firstOrNull ??
        blocks.first;
    final preview = Material(
      key: const ValueKey('slide-preview-card'),
      color: Theme.of(context).colorScheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageHeight = math.min(
            constraints.maxWidth * 9 / 16,
            math.max(0.0, constraints.maxHeight),
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: imageHeight,
                width: double.infinity,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: previewSettings?.isLoading == true
                        ? const Center(child: CircularProgressIndicator())
                        : previewSettings?.hasError == true
                        ? Center(
                            child: TextButton(
                              onPressed: () => ref.invalidate(
                                workoutPreviewProvider(request.workout!),
                              ),
                              child: const Text('공통 설정을 불러오지 못했습니다 · 다시 시도'),
                            ),
                          )
                        : WorkoutSlidePreview(
                            borderRadius: 0,
                            module: withIntervalBlocks(module, [selectedBlock]),
                            isRest: false,
                            brandL: renderedBrandL,
                            brandR: renderedBrandR,
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
      if (value == section.value) return;
      FocusScope.of(context).unfocus();
      section.value = value;
      if (AppMotion.reduced(context)) {
        sectionTransition.value = 1;
      } else {
        sectionTransition.forward(from: 0);
      }
      if (settingsScroll.hasClients) settingsScroll.jumpTo(0);
    }

    final titleButton = TextButton(
      key: const ValueKey('slide-title-button'),
      style: TextButton.styleFrom(
        foregroundColor: SlideEditorStyle.accent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        minimumSize: const Size(48, 48),
        alignment: Alignment.centerLeft,
      ),
      onPressed: busy.value
          ? null
          : () async {
              FocusScope.of(context).unfocus();
              final edited = await showDialog<String>(
                context: context,
                builder: (_) => _SlideTitleDialog(
                  initialValue: module.name,
                  maxLength: hasSlideDesign(module) ? 60 : null,
                ),
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
                  letterSpacing: -0.22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.edit_outlined, size: 18),
          ],
        ),
      ),
    );
    final summary = SlideTimerSummary(
      module: module,
      dirty: !sameSlideTiming(module, state.saved),
      onEdit: () {
        FocusScope.of(context).unfocus();
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          isDismissible: false,
          enableDrag: false,
          showDragHandle: false,
          constraints: const BoxConstraints(maxWidth: 720),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          builder: (_) => FractionallySizedBox(
            heightFactor: .98,
            child: TimerEditorScreen(
              workoutId: workoutId,
              original: original,
              scope: request.workout?.ownerId ?? 'local',
              chooseModeInitially:
                  needsInitialSave.value && !timerConfigured.value,
              brandL: renderedBrandL,
              brandR: renderedBrandR,
              workout: renderedWorkout,
              onSelectBlock: (id) {
                selectedBlockId.value = id;
                timerConfigured.value = true;
              },
            ),
          ),
        );
      },
    );

    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
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
                    brandL: renderedBrandL,
                    brandR: renderedBrandR,
                  ),
                );
                if (confirmed != true || !context.mounted) return;
                resetFields(() => actions.replaceWithTemplate(template));
                selectedBlockId.value = null;
                selectSection(1);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('슬라이드를 교체했습니다. 저장 버튼을 눌러 반영해 주세요.'),
                  ),
                );
              },
            )
          : ListView(
              controller: settingsScroll,
              key: const ValueKey('slide-editor-settings'),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              children: [
                if (largeText && error.value != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      error.value!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (section.value == 1) ...[
                  summary,
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const label = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '타이머 표시',
                            style: TextStyle(
                              letterSpacing: -0.14,
                              fontWeight: FontWeight.w600,
                            ),
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
                          minimumSize: const Size(48, 48),
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
                      final setsToggle = MergeSemantics(
                        child: InkWell(
                          onTap: () => update(
                            module.copyWith(showSets: !module.showSets),
                          ),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                key: const ValueKey('slide-show-sets'),
                                value: module.showSets,
                                onChanged: (value) => update(
                                  module.copyWith(showSets: value ?? false),
                                ),
                              ),
                              const Text(
                                '세트 표시',
                                style: TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      );
                      final narrow =
                          constraints.maxWidth <
                          340 * MediaQuery.textScalerOf(context).scale(1);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (narrow) ...[
                            label,
                            Align(
                              alignment: Alignment.centerRight,
                              child: setsToggle,
                            ),
                          ] else
                            Row(
                              children: [
                                const Expanded(child: label),
                                const SizedBox(width: 8),
                                setsToggle,
                              ],
                            ),
                          const SizedBox(height: 12),
                          toggle,
                        ],
                      );
                    },
                  ),
                  const Divider(height: 20),
                  const SizedBox(height: 16),
                  SlideAppearanceControls(
                    key: ValueKey('appearance-${revision.value}'),
                    section: SlideAppearanceSection.timer,
                    value: module.appearance,
                    onChanged: (value, _) =>
                        update(module.copyWith(appearance: value)),
                  ),
                  const Divider(height: 24),
                  const Text(
                    '스타일',
                    style: TextStyle(
                      letterSpacing: -0.14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('색상·배치·표시 옵션을 한 번에 적용하거나 저장해요.'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('slide-load-style'),
                        onPressed: loadStyle,
                        icon: const Icon(Icons.palette_outlined),
                        label: const Text('스타일 불러오기'),
                      ),
                      TextButton.icon(
                        key: const ValueKey('slide-save-style'),
                        onPressed: saveStyle,
                        icon: const Icon(Icons.bookmark_add_outlined),
                        label: const Text('스타일 저장'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '타이머 색상',
                    style: TextStyle(
                      letterSpacing: -0.14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    key: const ValueKey('timer-color-scroll'),
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      spacing: 8,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HexColorField(
                          compact: true,
                          compactWidth: MediaQuery.textScalerOf(context)
                              .scale(80),
                          label: '세트 숫자',
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
                              );
                            }
                          },
                        ),
                        for (var i = 0; i < 4; i++)
                          HexColorField(
                            compact: true,
                            compactWidth: MediaQuery.textScalerOf(context)
                                .scale(i >= 2 ? 112 : 80),
                            key: ValueKey('phase-color-$i-${revision.value}'),
                            label: const [
                              '운동 게이지',
                              '휴식 게이지',
                              '운동 시간 텍스트',
                              '휴식 시간 텍스트',
                            ][i],
                            initialValue:
                                [
                                  module.workGaugeColor,
                                  module.restGaugeColor,
                                  module.workTextColor,
                                  module.restTextColor,
                                ][i] ??
                                colorHex(
                                  slideColor(
                                    module,
                                    rest: i.isOdd,
                                    text: i >= 2,
                                  ),
                                ),
                            onChanged: (v) => update(switch (i) {
                              0 => module.copyWith(workGaugeColor: v),
                              1 => module.copyWith(restGaugeColor: v),
                              2 => module.copyWith(workTextColor: v),
                              _ => module.copyWith(restTextColor: v),
                            }),
                          ),
                      ],
                    ),
                  ),
                ],
                if (section.value == 2) ...[
                  if (hasSlideDesign(module) && !originalDesign) ...[
                    const Row(
                      children: [
                        Text('슬라이드 테마'),
                        SizedBox(width: 8),
                        AiBetaBadge(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: module.designTemplate,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '운동 목록 형식'),
                      items: [
                        for (final entry in slideDesignOptions(module).entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                      onChanged: (value) =>
                          update(module.copyWith(designTemplate: value)),
                    ),
                    if (structuredDesign) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          'slide-design-layout-${module.designLayout}',
                        ),
                        initialValue: module.designLayout,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: '슬라이드 배치'),
                        items: [
                          for (final entry in slideDesignLayouts.entries)
                            DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            update(module.copyWith(designLayout: value));
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    SlideDesignColors(module: module, onChanged: update),
                    const SizedBox(height: 12),
                    const Text(
                      '제목·운동 목록·타이머를 바꾸면 이미지도 함께 바뀌어요. 다른 이미지를 선택하면 테마가 해제돼요.',
                    ),
                    const Divider(height: 24),
                  ],
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
                        update(
                          module.copyWith(
                            imageSource: '',
                            designTemplate: null,
                            designStyle: null,
                          ),
                        );
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
                        enabled:
                            hasSlideDesign(module) ||
                            module.imageSource.isNotEmpty,
                        child: const Text('이미지 제거'),
                      ),
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
                  if (!hasSlideDesign(module))
                    SlideAppearanceControls(
                      section: SlideAppearanceSection.visibility,
                      value: module.appearance,
                      onChanged: (value, _) =>
                          update(module.copyWith(appearance: value)),
                    ),
                  const Divider(height: 24),
                  if (isStudioSlideDesign(module) && !originalDesign) ...[
                    TextFormField(
                      key: const ValueKey('studio-class-label'),
                      controller: designHeader,
                      maxLength: 60,
                      decoration: const InputDecoration(
                        labelText: '클래스 이름 · 분류',
                      ),
                      onChanged: (value) =>
                          update(module.copyWith(designHeaderLabel: value)),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('studio-subtitle'),
                      controller: designSubtitle,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: '운동 안내 · 시간 문구',
                      ),
                      onChanged: (value) =>
                          update(module.copyWith(designSubtitle: value)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (originalDesign) ...[
                    TextFormField(
                      key: const ValueKey('original-slide-subtitle'),
                      controller: designSubtitle,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: '운동 안내 · 시간 문구',
                      ),
                      onChanged: (value) =>
                          update(module.copyWith(designSubtitle: value)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (structuredDesign && !originalDesign)
                    SlideDesignSectionEditor(
                      text: module.text,
                      onChanged: (value) =>
                          update(module.copyWith(text: value)),
                    )
                  else
                    TextFormField(
                      key: const ValueKey('slide-body-text'),
                      controller: description,
                      maxLines: 4,
                      maxLength: hasSlideDesign(module)
                          ? slideDesignMaxTextLength
                          : null,
                      decoration: InputDecoration(
                        labelText: '화면 텍스트',
                        helperText: originalDesign
                            ? '최대 ${originalTemplate.maxLines}줄 · 한 줄에 120자'
                            : hasSlideDesign(module)
                            ? '최대 24줄 · 한 줄에 120자'
                            : null,
                      ),
                      onChanged: (v) => update(module.copyWith(text: v)),
                    ),
                  const Divider(height: 24),
                  if (!hasSlideDesign(module))
                    const Text(
                      '색상',
                      style: TextStyle(
                        letterSpacing: -0.14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (!hasSlideDesign(module))
                    SlideAppearanceControls(
                      key: ValueKey('background-appearance-${revision.value}'),
                      section: SlideAppearanceSection.background,
                      value: module.appearance,
                      onChanged: (value, _) =>
                          update(module.copyWith(appearance: value)),
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
                    '미리 재생에서 이 기기의 전환음을 확인할 수 있어요.',
                    style: TextStyle(
                      fontSize: 12,
                      color: SlideEditorStyle.muted,
                    ),
                  ),
                ],
              ],
            ),
    );

    final editorTabs = AbsorbPointer(
      absorbing: busy.value,
      child: AppBottomTabBar(
        key: const ValueKey('slide-editor-tabs'),
        indicatorKey: const ValueKey('slide-tab-indicator'),
        selected: section.value - 1,
        onSelected: (index) => selectSection(index + 1),
        items: [
          const AppBottomTab(label: '타이머', icon: Icons.timer_outlined, flex: 4),
          AppBottomTab(label: '배경', icon: Icons.image_outlined, flex: 4),
          const AppBottomTab(
            label: '소리',
            icon: Icons.volume_up_outlined,
            flex: 4,
          ),
          const AppBottomTab(
            label: '라이브러리',
            icon: Icons.filter_none_rounded,
            flex: 5,
          ),
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
          title:
              MediaQuery.sizeOf(context).height < 540 ||
                  MediaQuery.viewInsetsOf(context).bottom > 0
              ? titleButton
              : const Text('슬라이드 편집'),
          actions: [
            IconButton(
              key: const ValueKey('slide-preview-rehearse'),
              tooltip: '미리 재생',
              onPressed: busy.value ? null : rehearse,
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                iconSize: 22,
                foregroundColor: SlideEditorStyle.accent,
              ),
              icon: const Icon(Icons.play_arrow_rounded),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Tooltip(
                message: error.value == null ? '저장' : '다시 저장',
                child: TextButton(
                  key: const ValueKey('slide-save-button'),
                  style: TextButton.styleFrom(
                    foregroundColor: SlideEditorStyle.accent,
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed:
                      busy.value || (!state.dirty && !needsInitialSave.value)
                      ? null
                      : save,
                  child: busy.value
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            semanticsLabel: '저장 중',
                          ),
                        )
                      : Text(error.value == null ? '저장' : '다시 저장'),
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
              if ((error.value != null && !largeText) ||
                  state.storageError != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    (largeText ? null : error.value) ?? state.storageError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxHeight < 180) {
                      // Keyboard, large text and a recovery/error notice can
                      // leave less room than the tabs themselves need. Let the
                      // section controls scroll without clipping their labels.
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            MediaQuery.removePadding(
                              context: context,
                              removeBottom: true,
                              child: editorTabs,
                            ),
                            SizedBox(height: 260, child: settings),
                          ],
                        ),
                      );
                    }
                    if (constraints.maxWidth >= 700 &&
                        constraints.maxHeight < 400) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: preview),
                          Expanded(
                            child: Column(
                              children: [
                                MediaQuery.removePadding(
                                  context: context,
                                  removeBottom: true,
                                  child: editorTabs,
                                ),
                                Expanded(child: settings),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        if (constraints.maxHeight >= 280 &&
                            MediaQuery.sizeOf(context).height >= 540 &&
                            MediaQuery.viewInsetsOf(context).bottom == 0)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                titleButton,
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    busy.value
                                        ? workoutSaveProgressLabel(
                                            uploadProgress,
                                          )
                                        : error.value != null
                                        ? '저장 실패 · 편집 내용 유지됨'
                                        : state.dirty || needsInitialSave.value
                                        ? '변경사항 있음'
                                        : '저장됨',
                                    key: const ValueKey('slide-save-status'),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: SlideEditorStyle.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (MediaQuery.viewInsetsOf(context).bottom == 0 &&
                            constraints.maxHeight >= 400) ...[
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: largeText
                                  ? (constraints.maxHeight * .24).clamp(0, 110)
                                  : constraints.maxHeight * .32,
                            ),
                            child: preview,
                          ),
                          if (MediaQuery.textScalerOf(context).scale(14) <=
                              20) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: TextButton.icon(
                                onPressed: busy.value ? null : rehearse,
                                icon: const Icon(Icons.play_circle_outline),
                                label: const Text('이 기기에서 연습'),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                              child: Text(
                                '이 기기에서만 재생되며 TV에는 반영되지 않아요.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: SlideEditorStyle.muted,
                                ),
                              ),
                            ),
                          ],
                        ],
                        MediaQuery.removePadding(
                          context: context,
                          removeBottom: true,
                          child: editorTabs,
                        ),
                        Expanded(
                          child: FadeTransition(
                            opacity: sectionOpacity,
                            child: settings,
                          ),
                        ),
                      ],
                    );
                  },
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
      title: Text(
        title,
        style: const TextStyle(
          letterSpacing: -0.13,
          fontWeight: FontWeight.w600,
        ),
      ),
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
  const _SlideTitleDialog({required this.initialValue, this.maxLength});
  final String initialValue;
  final int? maxLength;
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
          maxLength: maxLength,
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
