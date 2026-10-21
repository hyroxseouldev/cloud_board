import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_reference_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/visible_slide_preview.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/center_slide_thumbnail.dart';

import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/center_slide_preview.dart';

enum StudioDesignCategory {
  center('센터 전용'),
  basic('기본 템플릿');

  const StudioDesignCategory(this.label);
  final String label;
}

class StudioDesignSelector extends HookWidget {
  const StudioDesignSelector({
    super.key,
    required this.designs,
    required this.category,
    required this.onCategoryChanged,
    required this.sourceLabel,
    required this.emptyMessage,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });
  final List<AiSlideDesign> designs;
  final StudioDesignCategory category;
  final ValueChanged<StudioDesignCategory> onCategoryChanged;
  final String Function(AiSlideDesign) sourceLabel;
  final AiSlideDesign selected;
  final ValueChanged<AiSlideDesign> onSelected;
  final bool enabled;
  final String emptyMessage;
  @override
  Widget build(BuildContext context) {
    final scroll = useScrollController();
    final width = MediaQuery.sizeOf(context).width < 500 ? 164.0 : 220.0;
    final height =
        width * 9 / 16 + MediaQuery.textScalerOf(context).scale(14) * 2.8 + 8;
    void reveal(AiSlideDesign design) {
      final index = designs.indexWhere((value) => value.id == design.id);
      if (index < 0 || !scroll.hasClients) return;
      final offset = (index * (width + 12)).clamp(
        0.0,
        scroll.position.maxScrollExtent,
      );
      if (MediaQuery.disableAnimationsOf(context)) {
        scroll.jumpTo(offset);
      } else {
        scroll.animateTo(
          offset,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    }

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) reveal(selected);
      });
      return null;
    }, [selected.id, designs.length, category]);
    Future<void> more() async {
      final wide = MediaQuery.sizeOf(context).width >= 700;
      final value = wide
          ? await showDialog<AiSlideDesign>(
              context: context,
              builder: (context) => Dialog(
                child: SizedBox(
                  width: 880,
                  height: MediaQuery.sizeOf(context).height * .8,
                  child: _AllDesigns(
                    designs: designs,
                    selected: selected,
                    category: category,
                    sourceLabel: sourceLabel,
                  ),
                ),
              ),
            )
          : await showModalBottomSheet<AiSlideDesign>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (context) => SizedBox(
                height: MediaQuery.sizeOf(context).height * .9,
                child: _AllDesigns(
                  designs: designs,
                  selected: selected,
                  category: category,
                  sourceLabel: sourceLabel,
                ),
              ),
            );
      if (value != null && context.mounted) {
        onSelected(value);
        reveal(value);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '디자인',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: '다음 디자인',
              onPressed: !enabled
                  ? null
                  : () {
                      if (!scroll.hasClients) return;
                      final next = (scroll.offset + width + 12).clamp(
                        0.0,
                        scroll.position.maxScrollExtent,
                      );
                      if (MediaQuery.disableAnimationsOf(context)) {
                        scroll.jumpTo(next);
                      } else {
                        scroll.animateTo(
                          next,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                        );
                      }
                    },
              icon: const Icon(Icons.chevron_right),
            ),
            TextButton(
              key: const ValueKey('studio-more'),
              onPressed: enabled && designs.isNotEmpty ? more : null,
              child: const Text('더보기'),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final value in StudioDesignCategory.values)
              ChoiceChip(
                key: ValueKey('studio-category-${value.name}'),
                label: Text(value.label),
                selected: category == value,
                selectedColor: const Color(0xffE3EBE5),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: category == value
                      ? const Color(0xff526B60)
                      : const Color(0xffDEDED7),
                ),
                labelStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xff526B60),
                ),
                onSelected: enabled ? (_) => onCategoryChanged(value) : null,
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (designs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(emptyMessage),
          )
        else
          SizedBox(
            height: height,
            child: Focus(
              onKeyEvent: (_, event) {
                if (!enabled ||
                    event is! KeyDownEvent ||
                    ![
                      LogicalKeyboardKey.arrowLeft,
                      LogicalKeyboardKey.arrowRight,
                    ].contains(event.logicalKey)) {
                  return KeyEventResult.ignored;
                }
                final index = designs.indexWhere((d) => d.id == selected.id);
                final delta = event.logicalKey == LogicalKeyboardKey.arrowRight
                    ? 1
                    : -1;
                if (designs.isNotEmpty) {
                  onSelected(
                    designs[(index + delta).clamp(0, designs.length - 1)],
                  );
                }
                return KeyEventResult.handled;
              },
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  scrollbars: false,
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                    PointerDeviceKind.stylus,
                  },
                ),
                child: ListView.separated(
                  controller: scroll,
                  scrollDirection: Axis.horizontal,
                  itemCount: designs.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, index) => SizedBox(
                    width: width,
                    child: StudioDesignCard(
                      design: designs[index],
                      source: sourceLabel(designs[index]),
                      selected: selected.id == designs[index].id,
                      onTap: enabled ? () => onSelected(designs[index]) : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AllDesigns extends StatelessWidget {
  const _AllDesigns({
    required this.designs,
    required this.selected,
    required this.category,
    required this.sourceLabel,
  });
  final StudioDesignCategory category;
  final String Function(AiSlideDesign) sourceLabel;
  final List<AiSlideDesign> designs;
  final AiSlideDesign selected;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${category.label} 더보기',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: '닫기',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),

      Expanded(
        child: LayoutBuilder(
          builder: (context, size) {
            final large = MediaQuery.textScalerOf(context).scale(14) > 22;
            final columns = size.maxWidth < 520 || large
                ? 1
                : size.maxWidth < 800
                ? 2
                : 3;
            final width = (size.maxWidth - 40 - 12 * (columns - 1)) / columns;
            return GridView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: designs.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                mainAxisExtent:
                    width * 9 / 16 +
                    MediaQuery.textScalerOf(context).scale(14) * 2.8 +
                    22,
              ),
              itemBuilder: (context, index) => StudioDesignCard(
                design: designs[index],
                source: sourceLabel(designs[index]),
                selected: designs[index].id == selected.id,
                onTap: () => Navigator.pop(context, designs[index]),
              ),
            );
          },
        ),
      ),
    ],
  );
}

class StudioDesignCard extends ConsumerWidget {
  const StudioDesignCard({
    super.key,
    required this.design,
    required this.source,
    required this.selected,
    required this.onTap,
  });
  final AiSlideDesign design;
  final String source;
  final bool selected;
  final VoidCallback? onTap;
  Future<void> enlarge(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => UncontrolledProviderScope(
      container: ProviderScope.containerOf(context),
      child: Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(design.name),
            leading: Builder(
              builder: (context) => IconButton(
                tooltip: '확대 보기 닫기',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
          ),
          body: LayoutBuilder(
            builder: (context, size) {
              final draft = applyAiSlideTheme(
                design.sample ?? initialAiSlideDesignDraft(design.theme),
                design.theme,
              );
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: SizedBox(
                    width: size.maxWidth,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: draft.centerRecipe != null
                          ? CenterSlidePreview(draft: draft)
                          : WorkoutSlidePreview(
                              module: previewAiSlide(draft),
                              isRest: false,
                              creationTypography: true,
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context, WidgetRef ref) => Semantics(
    selected: selected,
    button: true,
    label: '${design.name} · $source · 디자인 견본',
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: ValueKey('studio-design-${design.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VisibleSlidePreview(
                    builder: (_) {
                      final draft = applyAiSlideTheme(
                        design.sample ??
                            initialAiSlideDesignDraft(design.theme),
                        design.theme,
                      );
                      return draft.centerRecipe != null
                          ? CenterSlideThumbnail(draft: draft)
                          : WorkoutSlidePreview(
                              module: previewAiSlide(draft),
                              isRest: false,
                              creationTypography: true,
                              borderRadius: 6,
                            );
                    },
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? const Color(0xff526B60)
                                : const Color(0xffDEDED7),
                            width: selected ? 2 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: IconButton.filledTonal(
                      key: ValueKey('studio-enlarge-${design.id}'),
                      tooltip: '${design.name} 크게 보기',
                      onPressed: () => enlarge(context),
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(32),
                        fixedSize: const Size.square(32),
                        padding: const EdgeInsets.all(8),
                        tapTargetSize: MaterialTapTargetSize.padded,
                        visualDensity: VisualDensity.standard,
                      ),
                      icon: const Icon(Icons.open_in_full, size: 16),
                    ),
                  ),
                  if (selected)
                    const Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(Icons.check_circle, color: Color(0xff526B60)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                design.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xff2B332E),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
