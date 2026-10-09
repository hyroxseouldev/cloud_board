import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
      gradient: const LinearGradient(
        colors: [Color(0xFF4F46E5), Color(0xFF9333EA), Color(0xFFDB2777)],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      'beta',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: .4,
        color: Colors.white,
      ),
    ),
  );
}

Future<List<WorkoutModule>?> showAiSlidesPage(BuildContext context) {
  final parent = GoRouterState.of(context).uri.path
      .replaceFirst(RegExp(r'/$'), '');
  return context.push<List<WorkoutModule>>('$parent/images/create');
}

enum _EditorTab { content, templates, source, create }

/// A full route keeps creation, reference designs and editing in one workspace.
class AiSlidesPage extends HookConsumerWidget {
  const AiSlidesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final state = ref.watch(aiSlidesControllerProvider);
    final controller = ref.read(aiSlidesControllerProvider.notifier);
    useOnAppLifecycleStateChange((previous, next) {
      if (next != AppLifecycleState.resumed) unawaited(controller.flush());
    });
    final access = ref.watch(aiSlidesAccessProvider);
    final tab = useState(
      state.draft == null ? _EditorTab.templates : _EditorTab.content,
    );
    final visited = useState(<_EditorTab>{tab.value});
    void selectTab(_EditorTab value) {
      FocusScope.of(context).unfocus();
      visited.value = {...visited.value, value};
      tab.value = value;
    }

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
        module != null && !busy && validation == null && metrics!.readable;
    ref.listen(aiSlidesControllerProvider, (previous, next) {
      final restored = previous?.loading == true && !next.loading;
      final generated =
          previous?.generating == true &&
          !next.generating &&
          next.error == null;
      if ((restored || generated) && next.draft != null) {
        selectTab(_EditorTab.content);
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

    Widget studio(AiSlideDesignStudioSection section) => AiSlideDesignStudio(
      key: ValueKey(section),
      section: section,
      draft: draft,
      onSelected: (design) {
        controller.applyDesign(
          design.theme,
          classLabel: design.id.startsWith('ai-design-') ? design.name : null,
        );
        selectTab(_EditorTab.content);
      },
    );
    Widget panel(_EditorTab value) => switch (value) {
      _EditorTab.content =>
        draft == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '오늘 수업, 한 장으로',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text('템플릿을 골라 직접 입력하거나, 수업 메모로 운동 내용을 정리해 보세요.'),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => selectTab(_EditorTab.templates),
                    icon: const Icon(Icons.grid_view_rounded),
                    label: const Text('템플릿 고르기'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => selectTab(_EditorTab.source),
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('메모로 시작하기'),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AiSlidesContentEditor(
                    draft: draft,
                    warnings: state.warnings,
                    onChanged: controller.updateDraft,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '오른쪽 위 +로 슬라이드를 추가한 뒤 워크아웃을 저장해 주세요.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
      _EditorTab.templates => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          studio(AiSlideDesignStudioSection.templates),
          if (draft != null) ...[
            const Divider(height: 32),
            AiSlidesDesignEditor(
              draft: draft,
              state: state,
              onChanged: controller.updateDraft,
              onSaveTheme: controller.saveTheme,
              onApplyTheme: controller.applyTheme,
            ),
          ],
        ],
      ),
      _EditorTab.source => AiSlidesPromptEditor(
        state: state,
        access: access,
        allowed: allowed,
        onChanged: controller.setPrompt,
        onRetryAccess: () => ref.invalidate(aiSlidesAccessProvider),
        onGenerate: () {
          FocusScope.of(context).unfocus();
          controller.generate(state.prompt);
        },
      ),
      _EditorTab.create => studio(AiSlideDesignStudioSection.create),
    };
    Widget controls() => IndexedStack(
      index: tab.value.index,
      children: [
        for (final value in _EditorTab.values)
          visited.value.contains(value)
              ? AbsorbPointer(
                  absorbing: state.generating,
                  child: ListView(
                    key: PageStorageKey('ai-slides-editor-${value.name}'),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [panel(value)],
                  ),
                )
              : const SizedBox.shrink(),
      ],
    );
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) unawaited(controller.flush());
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          leading: IconButton(
            tooltip: '뒤로',
            onPressed: close,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          titleSpacing: 0,
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '수업 이미지 생성',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(width: 8),
              AiBetaBadge(),
            ],
          ),
          actions: [
            if (draft != null)
              IconButton(
                tooltip: '되돌리기',
                onPressed: state.canUndo && !busy ? controller.undo : null,
                icon: const Icon(Icons.undo_rounded),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton.filledTonal(
                key: const ValueKey('ai-slides-add'),
                tooltip: '슬라이드 추가',
                onPressed: canAdd ? add : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                children: [
                  if (busy) const LinearProgressIndicator(minHeight: 2),
                  if (state.storageError != null)
                    AiSlidesNotice(state.storageError!, error: true),
                  if (draft != null && state.error != null)
                    AiSlidesNotice(state.error!, error: true),
                  if (warning != null) AiSlidesNotice(warning, error: true),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, bounds) {
                        final showPreview =
                            module != null &&
                            !keyboardVisible &&
                            tab.value != _EditorTab.create;
                        final wide =
                            bounds.maxWidth >= 700 && bounds.maxHeight >= 270;
                        return Flex(
                          direction: wide ? Axis.horizontal : Axis.vertical,
                          crossAxisAlignment: wide
                              ? CrossAxisAlignment.start
                              : CrossAxisAlignment.center,
                          children: [
                            if (showPreview && wide)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    0,
                                    12,
                                  ),
                                  child: AiSlidesPreview(module: module),
                                ),
                              ),
                            if (showPreview && !wide && bounds.maxHeight > 270)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  8,
                                ),
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
                            if (showPreview && !wide && bounds.maxHeight <= 270)
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
                            Expanded(
                              key: const ValueKey('ai-slides-controls'),
                              child: controls(),
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
        ),
        bottomNavigationBar: keyboardVisible
            ? null
            : NavigationBar(
                height: 72,
                selectedIndex: tab.value.index,
                onDestinationSelected: (index) =>
                    selectTab(_EditorTab.values[index]),
                destinations: const [
                  NavigationDestination(
                    key: ValueKey('ai-nav-content'),
                    icon: Icon(Icons.edit_note_outlined),
                    selectedIcon: Icon(Icons.edit_note_rounded),
                    label: '내용',
                  ),
                  NavigationDestination(
                    key: ValueKey('ai-nav-templates'),
                    icon: Icon(Icons.grid_view_outlined),
                    selectedIcon: Icon(Icons.grid_view_rounded),
                    label: '템플릿',
                  ),
                  NavigationDestination(
                    key: ValueKey('ai-nav-source'),
                    icon: Icon(Icons.notes_outlined),
                    selectedIcon: Icon(Icons.notes_rounded),
                    label: '수업 메모',
                  ),
                  NavigationDestination(
                    key: ValueKey('ai-nav-create'),
                    icon: Icon(Icons.auto_awesome_outlined),
                    selectedIcon: Icon(Icons.auto_awesome_rounded),
                    label: '디자인 만들기',
                  ),
                ],
              ),
      ),
    );
  }
}
