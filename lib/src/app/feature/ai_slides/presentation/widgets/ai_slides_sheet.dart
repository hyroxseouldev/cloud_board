import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slides_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_design_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_design_colors.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_design_section_editor.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';

class AiBetaBadge extends StatelessWidget {
  const AiBetaBadge({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      '베타',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    ),
  );
}

Future<List<WorkoutModule>?> showAiSlidesSheet(BuildContext context) =>
    showModalBottomSheet<List<WorkoutModule>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 1120),
      builder: (_) => const AiSlidesSheet(),
    );

class AiSlidesSheet extends HookConsumerWidget {
  const AiSlidesSheet({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiSlidesControllerProvider);
    final controller = ref.read(aiSlidesControllerProvider.notifier);
    useOnAppLifecycleStateChange((previous, next) {
      if (next != AppLifecycleState.resumed) unawaited(controller.flush());
    });
    final access = ref.watch(aiSlidesAccessProvider);
    final tab = useState(0);
    final draft = state.draft;
    final module = draft == null ? null : previewAiSlide(draft);
    final metrics = module == null ? null : measureSlideDesign(module);
    final validation = module == null ? null : slideDesignError(module);
    final busy = state.generating || state.loading;
    final allowed =
        access.value?.premium == true && access.value?.enabled == true;
    final warning = validation ?? metrics?.warning;
    final canAdd =
        module != null &&
        !busy &&
        allowed &&
        validation == null &&
        metrics!.readable;
    ref.listen(aiSlidesControllerProvider, (previous, next) {
      if (previous?.generating == true &&
          !next.generating &&
          next.error == null &&
          next.draft != null) {
        tab.value = 0;
      }
    });
    Future<void> close() async {
      await controller.flush();
      if (context.mounted) Navigator.pop(context);
    }

    Future<void> add() async {
      if (draft == null || !canAdd) return;
      final ownerId = ref.read(aiSlidesOwnerIdProvider);
      final value = confirmAiSlide(
        draft,
        'ai-${DateTime.now().microsecondsSinceEpoch}',
      );
      await controller.clearDraft();
      if (context.mounted && ref.read(aiSlidesOwnerIdProvider) == ownerId) {
        Navigator.pop(context, [value]);
      }
    }

    final input = _PromptEditor(
      state: state,
      access: access,
      allowed: allowed,
      onChanged: controller.setPrompt,
      onRetryAccess: () => ref.invalidate(aiSlidesAccessProvider),
      onGenerate: () {
        FocusScope.of(context).unfocus();
        controller.generate(state.prompt);
      },
    );
    final editor = draft == null
        ? input
        : switch (tab.value) {
            1 => _DesignEditor(
              draft: draft,
              state: state,
              onChanged: controller.updateDraft,
              onSaveTheme: controller.saveTheme,
              onApplyTheme: controller.applyTheme,
            ),
            2 => input,
            _ => _ContentEditor(
              draft: draft,
              warnings: state.warnings,
              onChanged: controller.updateDraft,
            ),
          };
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) unawaited(controller.flush());
      },
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .93,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'AI 슬라이드 만들기',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const AiBetaBadge(),
                    if (draft != null)
                      IconButton(
                        tooltip: '되돌리기',
                        onPressed: state.canUndo && !busy
                            ? controller.undo
                            : null,
                        icon: const Icon(Icons.undo_rounded),
                      ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: close,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              if (state.loading || state.generating)
                const LinearProgressIndicator(minHeight: 2),
              if (state.storageError != null)
                _Notice(state.storageError!, error: true),
              if (draft != null && state.error != null)
                _Notice(state.error!, error: true),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, bounds) {
                    final wide =
                        draft != null &&
                        bounds.maxWidth >= 700 &&
                        bounds.maxHeight >= 270;
                    Widget controls() => Column(
                      children: [
                        if (draft != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<int>(
                                showSelectedIcon: false,
                                segments: const [
                                  ButtonSegment(value: 0, label: Text('내용')),
                                  ButtonSegment(value: 1, label: Text('디자인')),
                                  ButtonSegment(value: 2, label: Text('원문')),
                                ],
                                selected: {tab.value},
                                onSelectionChanged: (value) =>
                                    tab.value = value.first,
                              ),
                            ),
                          ),
                        Expanded(
                          child: AbsorbPointer(
                            absorbing: busy,
                            child: ListView(
                              key: ValueKey('ai-slides-editor-${tab.value}'),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              children: [editor],
                            ),
                          ),
                        ),
                      ],
                    );
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
                              child: _Preview(module: module!),
                            ),
                          ),
                          Expanded(child: controls()),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        if (module != null && bounds.maxHeight > 270)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: SizedBox(
                              height: math.min(
                                (bounds.maxWidth - 32) * 9 / 16 + 24,
                                bounds.maxHeight * .46,
                              ),
                              child: _Preview(module: module, compact: true),
                            ),
                          ),
                        if (module != null && bounds.maxHeight <= 270)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _expandPreview(context, module),
                              icon: const Icon(
                                Icons.fullscreen_rounded,
                                size: 18,
                              ),
                              label: const Text('미리보기'),
                            ),
                          ),
                        Expanded(child: controls()),
                      ],
                    );
                  },
                ),
              ),
              if (draft != null && MediaQuery.viewInsetsOf(context).bottom == 0)
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (warning != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            warning,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const ValueKey('ai-slides-add'),
                          onPressed: canAdd ? add : null,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('슬라이드 추가'),
                        ),
                      ),
                      if (MediaQuery.viewInsetsOf(context).bottom == 0)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            '워크아웃을 저장하면 반영돼요.',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromptEditor extends StatelessWidget {
  const _PromptEditor({
    required this.state,
    required this.access,
    required this.allowed,
    required this.onChanged,
    required this.onGenerate,
    required this.onRetryAccess,
  });
  final AiSlidesEditorState state;
  final AsyncValue<AiSlidesAccess> access;
  final bool allowed;
  final ValueChanged<String> onChanged;
  final VoidCallback onGenerate, onRetryAccess;
  @override
  Widget build(BuildContext context) {
    final unchanged =
        state.draft != null &&
        state.prompt.trim() == state.generatedPrompt?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          state.draft == null ? '오늘 수업을 한 장으로' : '원문에서 새 초안 만들기',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          state.draft == null
              ? '수업 내용을 붙여넣으면 섹션별로 정리해요. 색상과 배치는 자유롭게 바꿀 수 있어요.'
              : '원문을 바꾸면 새 초안을 만들어요. 배치만 바꾸려면 디자인 탭을 이용하세요.',
        ),
        const SizedBox(height: 12),
        if (state.themeError != null) _Notice(state.themeError!),
        access.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Row(
            children: [
              Expanded(child: Text('$error')),
              TextButton(onPressed: onRetryAccess, child: const Text('다시 확인')),
            ],
          ),
          data: (value) => Text(
            !value.premium
                ? '프리미엄 전용 기능이에요.'
                : !value.enabled
                ? 'AI 기능을 준비 중이에요.'
                : '이번 달 ${state.remaining ?? value.remaining}/${value.limit}회 남음',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SyncedField(
          fieldKey: const ValueKey('ai-slides-prompt'),
          value: state.prompt,
          label: '수업 내용',
          minLines: 5,
          maxLines: 10,
          maxLength: 6000,
          onChanged: onChanged,
          hint: 'WARM UP\n스쿼트 10회 / 런지 10회\n\nMAIN\nRUN 1km\nROW 500m',
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          key: const ValueKey('ai-slides-generate'),
          onPressed:
              !allowed ||
                  state.loading ||
                  state.generating ||
                  state.prompt.trim().isEmpty ||
                  unchanged
              ? null
              : onGenerate,
          icon: state.generating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome_rounded, size: 18),
          label: Text(
            state.generating
                ? '슬라이드 구성 중…'
                : state.draft == null
                ? '초안 만들기'
                : '변경한 내용으로 생성',
          ),
        ),
        if (state.generating)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '초안을 만들고 있어요. 창을 닫아도 다시 이어서 편집할 수 있어요.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        if (state.draft == null && state.error != null)
          _Notice(state.error!, error: true),
      ],
    );
  }
}

class _ContentEditor extends StatelessWidget {
  const _ContentEditor({
    required this.draft,
    required this.warnings,
    required this.onChanged,
  });
  final AiSlideDraft draft;
  final List<String> warnings;
  final ValueChanged<AiSlideDraft> onChanged;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final warning in warnings) _Notice(warning),
        _SyncedField(
          fieldKey: const ValueKey('ai-slide-title'),
          value: draft.title,
          label: '슬라이드 제목',
          maxLength: 60,
          onChanged: (value) => onChanged(draft.copyWith(title: value)),
        ),
        const SizedBox(height: 8),
        SlideDesignSectionEditor(
          keyPrefix: 'ai-section',
          text: draft.lines.join('\n'),
          onChanged: (value) =>
              onChanged(draft.copyWith(lines: value.split('\n'))),
        ),
        const SizedBox(height: 8),
        const Text(
          '운동 순서·횟수·단위를 확인해 주세요. 타이머는 슬라이드를 추가한 뒤에도 설정할 수 있어요.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class _DesignEditor extends StatelessWidget {
  const _DesignEditor({
    required this.draft,
    required this.state,
    required this.onChanged,
    required this.onSaveTheme,
    required this.onApplyTheme,
  });
  final AiSlideDraft draft;
  final AiSlidesEditorState state;
  final ValueChanged<AiSlideDraft> onChanged;
  final VoidCallback onSaveTheme, onApplyTheme;
  @override
  Widget build(BuildContext context) {
    final module = previewAiSlide(draft);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('배치', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final choice in const {
                'auto': '큰 글씨',
                'columns': '2열',
                'cards': '섹션 카드',
              }.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 130,
                    child: InkWell(
                      key: ValueKey('ai-layout-${choice.key}'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: () =>
                          onChanged(draft.copyWith(designLayout: choice.key)),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            width: 2,
                            color: draft.designLayout == choice.key
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          children: [
                            ExcludeSemantics(
                              child: WorkoutSlidePreview(
                                module: module.copyWith(
                                  designLayout: choice.key,
                                ),
                                isRest: false,
                                borderRadius: 6,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              choice.value,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SlideDesignColors(
          module: module,
          onChanged: (value) => onChanged(
            draft.copyWith(
              designBackgroundColor: value.designBackgroundColor,
              designTextColor: value.designTextColor,
              designAccentColor: value.designAccentColor,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text('글씨', style: TextStyle(fontWeight: FontWeight.w700)),
        Wrap(
          spacing: 8,
          children: [
            for (final option in const {700: '굵게', 900: '아주 굵게'}.entries)
              ChoiceChip(
                label: Text(option.value),
                selected: draft.designFontWeight == option.key,
                onSelected: (_) =>
                    onChanged(draft.copyWith(designFontWeight: option.key)),
              ),
          ],
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('기울임'),
          value: draft.designItalic,
          onChanged: (value) => onChanged(draft.copyWith(designItalic: value)),
        ),
        const Text('간격', style: TextStyle(fontWeight: FontWeight.w700)),
        Wrap(
          spacing: 8,
          children: [
            for (final option in {.85: '좁게', 1.0: '기본', 1.15: '넓게'}.entries)
              ChoiceChip(
                label: Text(option.value),
                selected: (draft.designSpacing - option.key).abs() < .01,
                onSelected: (_) =>
                    onChanged(draft.copyWith(designSpacing: option.key)),
              ),
          ],
        ),
        const Divider(height: 28),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('타이머 표시'),
          value: draft.showTimer,
          onChanged: (value) => onChanged(draft.copyWith(showTimer: value)),
        ),
        if (draft.showTimer) ...[
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('왼쪽'),
                selected: draft.timerX < .5,
                onSelected: (_) => onChanged(draft.copyWith(timerX: .16)),
              ),
              ChoiceChip(
                label: const Text('오른쪽'),
                selected: draft.timerX >= .5,
                onSelected: (_) => onChanged(draft.copyWith(timerX: .84)),
              ),
            ],
          ),
          Row(
            children: [
              const Text('크기'),
              Expanded(
                child: Slider(
                  value: draft.timerSize.clamp(.7, 1.25),
                  min: .7,
                  max: 1.25,
                  onChanged: (value) =>
                      onChanged(draft.copyWith(timerSize: value)),
                ),
              ),
            ],
          ),
        ],
        const Divider(height: 28),
        const Text('우리 센터 테마', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text(
          '저장한 색상·글씨·배치를 다음 수업에도 적용해요.',
          style: TextStyle(fontSize: 12),
        ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('ai-theme-save'),
              onPressed: state.themeSaving ? null : onSaveTheme,
              icon: Icon(
                state.themeSaved
                    ? Icons.check_rounded
                    : Icons.bookmark_border_rounded,
                size: 18,
              ),
              label: Text(
                state.themeSaving
                    ? '저장 중…'
                    : state.themeSaved
                    ? '테마 저장됨'
                    : '현재 테마 저장',
              ),
            ),
            if (state.theme != null)
              TextButton(
                onPressed: onApplyTheme,
                child: const Text('저장한 테마 적용'),
              ),
          ],
        ),
        if (state.themeError != null) _Notice(state.themeError!, error: true),
      ],
    );
  }
}

class _SyncedField extends HookWidget {
  const _SyncedField({
    required this.fieldKey,
    required this.value,
    required this.label,
    required this.onChanged,
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
    this.hint,
  });
  final Key fieldKey;
  final String value, label;
  final String? hint;
  final int minLines, maxLines;
  final int? maxLength;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: value);
    useEffect(() {
      if (controller.text.trim() != value.trim()) {
        controller.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(
            offset: math.min(
              controller.selection.extentOffset.clamp(0, value.length),
              value.length,
            ),
          ),
        );
      }
      return null;
    }, [value]);
    return TextField(
      key: fieldKey,
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: true,
      ),
      onChanged: onChanged,
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.module, this.compact = false});
  final WorkoutModule module;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final preview = WorkoutSlidePreview(module: module, isRest: false);
    if (compact) {
      return Tooltip(
        message: '크게 보기',
        child: InkWell(
          onTap: () => _expandPreview(context, module),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(aspectRatio: 16 / 9, child: preview),
                ),
              ),
              const SizedBox(height: 4),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.fullscreen_rounded, size: 14),
                  SizedBox(width: 4),
                  Text('크게 보기', style: TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        preview,
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _expandPreview(context, module),
            icon: const Icon(Icons.fullscreen_rounded, size: 18),
            label: const Text('크게 보기'),
          ),
        ),
        const Text('실제 타이머 위치를 함께 확인할 수 있어요.', style: TextStyle(fontSize: 12)),
      ],
    );
  }
}

Future<void> _expandPreview(BuildContext context, WorkoutModule module) =>
    showDialog<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(title: const Text('슬라이드 미리보기')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: WorkoutSlidePreview(module: module, isRest: false),
              ),
            ),
          ),
        ),
      ),
    );

class _Notice extends StatelessWidget {
  const _Notice(this.message, {this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    child: Text(
      message,
      style: TextStyle(
        fontSize: 12,
        color: error
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
