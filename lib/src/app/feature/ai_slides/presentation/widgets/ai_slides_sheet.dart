import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slide_design_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slide_design_studio.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slides_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_content_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_design_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_editor_controls.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_preview.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_prompt_editor.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_design_renderer.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';

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

enum _EditorTab { content, design, source }

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
    final tab = useState(_EditorTab.content);
    final designState = ref.watch(aiSlideDesignControllerProvider);
    useEffect(() {
      if (designState.selected != null) {
        controller.setPreferredTheme(
          designState.selected!.theme,
          classLabel: designState.selected!.id.startsWith('ai-design-')
              ? designState.selected!.name
              : null,
        );
      }
      return null;
    }, [designState.selected]);
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
        !state.generating &&
        validation == null &&
        metrics!.readable;
    ref.listen(aiSlidesControllerProvider, (previous, next) {
      if (previous?.generating == true &&
          !next.generating &&
          next.error == null &&
          next.draft != null) {
        tab.value = _EditorTab.content;
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

    final input = AiSlidesPromptEditor(
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
    final studio = AiSlideDesignStudio(
      draft: draft,
      onSelected: (design) {
        controller.applyDesign(
          design.theme,
          classLabel: design.id.startsWith('ai-design-') ? design.name : null,
        );
        tab.value = _EditorTab.content;
      },
    );
    final editor = draft == null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [studio, const Divider(height: 32), input],
          )
        : switch (tab.value) {
            _EditorTab.design => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                studio,
                const Divider(height: 32),
                AiSlidesDesignEditor(
                  draft: draft,
                  state: state,
                  onChanged: controller.updateDraft,
                  onSaveTheme: controller.saveTheme,
                  onApplyTheme: controller.applyTheme,
                ),
              ],
            ),
            _EditorTab.source => input,
            _EditorTab.content => AiSlidesContentEditor(
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
                        '수업 슬라이드',
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
                AiSlidesNotice(state.storageError!, error: true),
              if (draft != null && state.error != null)
                AiSlidesNotice(state.error!, error: true),
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
                              child: SegmentedButton<_EditorTab>(
                                showSelectedIcon: false,
                                segments: const [
                                  ButtonSegment(
                                    value: _EditorTab.content,
                                    label: Text('내용'),
                                  ),
                                  ButtonSegment(
                                    value: _EditorTab.design,
                                    label: Text('디자인'),
                                  ),
                                  ButtonSegment(
                                    value: _EditorTab.source,
                                    label: Text('수업 메모'),
                                  ),
                                ],
                                selected: {tab.value},
                                onSelectionChanged: (value) =>
                                    tab.value = value.first,
                              ),
                            ),
                          ),
                        Expanded(
                          child: AbsorbPointer(
                            absorbing: state.generating,
                            child: ListView(
                              key: ValueKey(
                                'ai-slides-editor-${tab.value.index}',
                              ),
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
                              child: AiSlidesPreview(module: module!),
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
                              child: AiSlidesPreview(
                                module: module,
                                compact: true,
                              ),
                            ),
                          ),
                        if (module != null && bounds.maxHeight <= 270)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () =>
                                  showAiSlidesPreview(context, module),
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
