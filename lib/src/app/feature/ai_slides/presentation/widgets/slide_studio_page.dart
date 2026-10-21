import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/slide_studio.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/slide_studio_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slide_design_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/center_slide_catalog_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slides_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/slide_studio_designs.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/center_slide_preview.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_preview.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_raster_page.dart';

const _oat = Color(0xffF7F5EF),
    _surface = Color(0xffFFFDF8),
    _sage = Color(0xff526B60),
    _ink = Color(0xff2B332E),
    _secondary = Color(0xff616B63);

/// Free template creation with immutable result snapshots.
class SlideStudioPage extends HookConsumerWidget {
  const SlideStudioPage({super.key, required this.guard});
  final ExitGuard guard;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(slideStudioControllerProvider);
    final controller = ref.read(slideStudioControllerProvider.notifier);
    final catalog = ref.watch(centerSlideCatalogProvider);
    final saved = ref.watch(aiSlideDesignControllerProvider);
    final scope = ref.watch(centerSlideCatalogScopeProvider);
    final owner = ref.watch(aiSlidesOwnerIdProvider);
    final centerDesigns = <AiSlideDesign>[
      if (scope != null &&
          !catalog.isLoading &&
          !catalog.hasError &&
          catalog.value?.centerId == scope.centerId)
        ...?catalog.value?.templates,
    ];
    // Saved styles are not an authority source for private center recipes.
    final savedDesigns = saved.templates
        .where(
          (design) =>
              design.theme.centerRecipe == null &&
              !aiSlideDesignCatalog.any((basic) => basic.id == design.id),
        )
        .toList();
    final category = useState(StudioDesignCategory.basic);
    final designs = category.value == StudioDesignCategory.center
        ? centerDesigns
        : [...aiSlideDesignCatalog, ...savedDesigns];
    String sourceLabel(AiSlideDesign design) =>
        category.value == StudioDesignCategory.center
        ? '센터 전용'
        : savedDesigns.contains(design)
        ? '저장한 디자인'
        : '기본 템플릿';
    final selections = useRef(<StudioDesignCategory, AiSlideDesign>{});
    final selectedAvailable = designs.contains(state.input.design);
    void selectDesign(AiSlideDesign design) {
      selections.value[category.value] = design;
      controller.select(design);
    }

    void selectCategory(StudioDesignCategory value) {
      selections.value[category.value] = state.input.design;
      category.value = value;
      final choices = value == StudioDesignCategory.center
          ? centerDesigns
          : [...aiSlideDesignCatalog, ...savedDesigns];
      final previous = selections.value[value];
      if (choices.isNotEmpty) {
        controller.select(
          choices.contains(previous) ? previous! : choices.first,
        );
      }
    }

    final input = state.input;
    final expanded = useState(true);
    final raw = useTextEditingController(text: input.raw);
    final focus = useFocusNode();
    final bodyScroll = useScrollController();
    useEffect(() {
      if (raw.text != input.raw && !raw.value.composing.isValid) {
        raw.value = TextEditingValue(
          text: input.raw,
          selection: TextSelection.collapsed(
            offset: raw.selection.baseOffset.clamp(0, input.raw.length),
          ),
        );
      }
      return null;
    }, [input.raw]);
    useEffect(() {
      void expand() {
        if (focus.hasFocus) expanded.value = true;
      }

      focus.addListener(expand);
      return () => focus.removeListener(expand);
    }, [focus]);
    ref.listen(slideStudioControllerProvider, (previous, next) {
      if (next.result != null &&
          next.result != previous?.result &&
          !next.dirty &&
          !focus.hasFocus) {
        expanded.value = false;
      }
    });
    bool sameScope() =>
        context.mounted &&
        ref.read(centerSlideCatalogScopeProvider) == scope &&
        ref.read(aiSlidesOwnerIdProvider) == owner;
    Future<void> close() async {
      if (await guard.confirm() && context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) Navigator.pop(context);
        });
      }
    }

    Future<void> add() async {
      final module = await controller.add();
      if (module == null || !sameScope()) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (sameScope()) Navigator.pop(context, [module]);
      });
    }

    void openLibrary() {
      FocusScope.of(context).unfocus();
      final studioPath = GoRouterState.of(context).uri.path
          .replaceFirst(RegExp(r'/$'), '');
      context.push<void>('$studioPath/library');
    }

    Widget preview(StudioResult result) =>
        result.job != null && result.brand != null
        ? AiRasterPreview(brand: result.brand!, job: result.job!)
        : result.draft?.centerRecipe != null
        ? CenterSlidePreview(draft: result.draft!)
        : AiSlidesPreview(module: previewAiSlide(result.draft!), compact: true);
    Future<void> enlarge() async {
      final result = state.result;
      if (result == null) return;
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(title: const Text('생성된 슬라이드')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: preview(result),
              ),
            ),
          ),
        ),
      );
    }

    final narrow = MediaQuery.sizeOf(context).width < 560;
    final locked = state.saving;
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        scaffoldBackgroundColor: _oat,
        colorScheme: theme.colorScheme.copyWith(
          primary: _sage,
          onPrimary: Colors.white,
          surface: _surface,
          onSurface: _ink,
          onSurfaceVariant: _secondary,
        ),
        textTheme: theme.textTheme.apply(
          fontFamily: 'Pretendard',
          bodyColor: _ink,
          displayColor: _ink,
        ),
        appBarTheme: theme.appBarTheme.copyWith(
          backgroundColor: _oat,
          foregroundColor: _ink,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      child: UnsavedChangesGuard(
        guard: guard,
        dirty: state.unsaved,
        blocked: state.busy || state.saving,
        confirmMessage: '저장하지 않은 입력과 생성 결과가 사라집니다. 라이브러리에 저장한 결과는 남아 있어요.',
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: '뒤로',
              onPressed: close,
              icon: const Icon(Icons.arrow_back),
            ),
            titleSpacing: 0,
            title: const Text(
              '슬라이드 만들기',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            actions: [
              if (narrow)
                IconButton(
                  tooltip: '저장된 슬라이드',
                  onPressed: locked || state.busy ? null : openLibrary,
                  icon: const Icon(Icons.bookmarks_outlined),
                )
              else
                TextButton(
                  onPressed: locked || state.busy ? null : openLibrary,
                  child: const Text('저장된 슬라이드'),
                ),
              const SizedBox(width: 8),
            ],
          ),
          bottomNavigationBar: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: StudioActionBar(
              state: state,
              designAvailable: selectedAvailable,
              onGenerate: () {
                FocusScope.of(context).unfocus();
                controller.generateTemplate();
              },
            ),
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: ListView(
                  key: const ValueKey('studio-body'),
                  controller: bodyScroll,
                  padding: EdgeInsets.fromLTRB(
                    narrow ? 16 : 32,
                    8,
                    narrow ? 16 : 32,
                    28,
                  ),
                  children: [
                    StudioDesignSelector(
                      designs: designs,
                      category: category.value,
                      onCategoryChanged: selectCategory,
                      emptyMessage: catalog.isLoading
                          ? '센터 전용 템플릿을 불러오는 중이에요.'
                          : catalog.hasError
                          ? '센터 전용 템플릿을 불러오지 못했어요. 다시 불러오거나 기본 템플릿을 선택해 주세요.'
                          : '현재 사용할 수 있는 센터 전용 템플릿이 없어요. 기본 템플릿을 선택해 주세요.',
                      sourceLabel: sourceLabel,
                      selected: input.design,
                      enabled: !locked,
                      onSelected: selectDesign,
                    ),
                    if (category.value == StudioDesignCategory.center &&
                        catalog.isLoading)
                      const LinearProgressIndicator(minHeight: 2),
                    if (catalog.hasError || saved.templateError != null)
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('일부 디자인을 불러오지 못했어요. 기본 디자인은 사용할 수 있어요.'),
                          TextButton(
                            onPressed: () {
                              ref.invalidate(centerSlideCatalogProvider);
                              ref.invalidate(aiSlideDesignControllerProvider);
                            },
                            child: const Text('다시 불러오기'),
                          ),
                        ],
                      ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          '수업 내용',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Text(
                          '운동 내용과 숫자·단위는 입력한 순서 그대로 사용해요.',
                          style: TextStyle(color: _secondary, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xffDEDED7)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            key: const ValueKey('studio-wod'),
                            controller: raw,
                            focusNode: focus,
                            enabled: !state.saving,
                            minLines: expanded.value ? 5 : 3,
                            maxLines: expanded.value ? 16 : 3,
                            maxLength: 6000,
                            decoration: const InputDecoration(
                              hintText: '오늘의 수업 내용을 붙여 넣으세요.\n예: Run 800m\nSki 500m · DB Press 12회',
                              border: InputBorder.none,
                              counterText: '',
                            ),
                            onChanged: (value) => controller.edit(
                              ref
                                  .read(slideStudioControllerProvider)
                                  .input
                                  .copyWith(raw: value),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              key: const ValueKey('studio-expand-input'),
                              onPressed: () => expanded.value = !expanded.value,
                              icon: Icon(
                                expanded.value
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 18,
                              ),
                              label: Text(
                                expanded.value ? '전체 내용 접기' : '전체 내용 펼치기',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    StudioTextField(
                      key: const ValueKey('studio-title'),
                      label: '슬라이드 제목',
                      value: input.title,
                      maxLength: 60,
                      onChanged: (v) => controller.edit(
                        ref
                            .read(slideStudioControllerProvider)
                            .input
                            .copyWith(title: v),
                      ),
                    ),
                    const SizedBox(height: 12),
                    StudioTextField(
                      key: const ValueKey('studio-subtitle'),
                      label: '운동 안내 문구 (선택)',
                      value: input.subtitle,
                      maxLength: 120,
                      onChanged: (v) => controller.edit(
                        ref
                            .read(slideStudioControllerProvider)
                            .input
                            .copyWith(subtitle: v),
                      ),
                    ),
                    if (state.busy) const LinearProgressIndicator(minHeight: 2),
                    if (state.error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          state.error!,
                          key: const ValueKey('studio-error'),
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '생성된 슬라이드',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (state.history.isNotEmpty)
                          TextButton.icon(
                            onPressed: locked || state.busy
                                ? null
                                : () {
                                    FocusScope.of(context).unfocus();
                                    controller.undo();
                                  },
                            icon: const Icon(Icons.undo, size: 18),
                            label: const Text('이전 결과 보기'),
                          ),
                        if (state.result != null)
                          IconButton(
                            tooltip: '미리보기 확대',
                            onPressed: enlarge,
                            icon: const Icon(Icons.open_in_full, size: 18),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xffDEDED7)),
                      ),
                      child: state.result == null
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.image_outlined,
                                    size: 28,
                                    color: _secondary,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    '디자인을 고르고 수업 내용을 입력한 뒤 생성해 주세요.',
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    '생성 결과가 여기에 표시돼요.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _secondary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : preview(state.result!),
                    ),
                    if (state.dirty)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          '변경사항이 아직 반영되지 않았어요. 새 결과를 생성한 뒤 저장하거나 추가해 주세요.',
                          key: ValueKey('studio-dirty'),
                          style: TextStyle(color: _secondary),
                        ),
                      ),
                    if (state.result != null) ...[
                      for (final warning in state.result!.warnings)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(warning),
                        ),
                      const SizedBox(height: 14),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          Text(
                            state.result!.savedModule != null
                                ? '라이브러리에 저장됨'
                                : '아직 저장되지 않았어요',
                            key: const ValueKey('studio-save-status'),
                            style: const TextStyle(
                              color: _secondary,
                              fontSize: 13,
                            ),
                          ),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                key: const ValueKey('studio-save'),
                                onPressed:
                                    locked ||
                                        state.busy ||
                                        state.pendingId != null ||
                                        state.dirty ||
                                        state.result!.savedModule != null
                                    ? null
                                    : controller.save,
                                icon: Icon(
                                  state.result!.savedModule != null
                                      ? Icons.bookmark_added
                                      : Icons.bookmark_add_outlined,
                                ),
                                label: Text(
                                  state.saving ? '처리 중…' : '라이브러리에 저장',
                                ),
                              ),
                              OutlinedButton.icon(
                                key: const ValueKey('studio-add'),
                                onPressed:
                                    locked ||
                                        state.busy ||
                                        state.pendingId != null ||
                                        state.dirty
                                    ? null
                                    : add,
                                icon: const Icon(Icons.add),
                                label: const Text('수업에 추가'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          '수업에 추가한 뒤 수업 편집 화면에서 저장해 주세요.',
                          style: TextStyle(fontSize: 12, color: _secondary),
                        ),
                      ),
                    ],
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

class StudioActionBar extends StatelessWidget {
  const StudioActionBar({
    super.key,
    required this.state,
    required this.designAvailable,
    required this.onGenerate,
  });
  final SlideStudioState state;
  final bool designAvailable;
  final VoidCallback onGenerate;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: _surface,
      border: Border(top: BorderSide(color: Color(0xffDEDED7))),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: FilledButton.icon(
          key: const ValueKey('studio-generate'),
          onPressed: state.busy || state.saving || !designAvailable
              ? null
              : onGenerate,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
          icon: state.busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward),
          label: Text(state.busy ? '슬라이드 생성 중…' : '슬라이드 생성'),
        ),
      ),
    ),
  );
}

class StudioTextField extends HookWidget {
  const StudioTextField({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    required this.maxLength,
    this.maxLines = 1,
  });
  final String value, label;
  final int maxLength, maxLines;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: value);
    useEffect(() {
      if (controller.text != value && !controller.value.composing.isValid) {
        controller.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(
            offset: controller.selection.baseOffset.clamp(0, value.length),
          ),
        );
      }
      return null;
    }, [value]);
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}
