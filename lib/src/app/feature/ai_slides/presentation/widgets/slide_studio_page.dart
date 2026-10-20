import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/slide_studio.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/slide_studio_actions.dart';
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

/// One creation route, with explicit request modes and immutable result snapshots.
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
    final designs = <AiSlideDesign>[
      if (!catalog.isLoading && !catalog.hasError) ...?catalog.value?.templates,
      ...saved.templates,
      ...state.proposals,
      ...aiSlideDesignCatalog,
    ];
    final input = state.input;
    final expanded = useState(true);
    final raw = useTextEditingController(text: input.raw);
    final focus = useFocusNode();
    final picking = useState(false);
    final bodyScroll = useScrollController();
    final userSelected = useRef(false);
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
    useEffect(() {
      if (!userSelected.value &&
          input.raw.isEmpty &&
          state.result == null &&
          !catalog.isLoading &&
          !catalog.hasError &&
          (catalog.value?.templates.isNotEmpty ?? false)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && !userSelected.value) {
            userSelected.value = true;
            controller.select(catalog.value!.templates.first);
          }
        });
      }
      return null;
    }, [catalog]);
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
    Future<void> pickReference() async {
      if (picking.value) return;
      picking.value = true;
      try {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
        );
        if (picked == null || !sameScope()) return;
        if (await picked.length() > 10 * 1024 * 1024) {
          if (sameScope()) controller.reportError('10MB 이하 이미지를 선택해 주세요.');
          return;
        }
        final bytes = await picked.readAsBytes();
        if (sameScope()) controller.reference(bytes);
      } catch (_) {
        if (sameScope()) {
          controller.reportError('사진을 불러오지 못했어요. 사진 접근 권한을 확인해 주세요.');
        }
      } finally {
        if (context.mounted) picking.value = false;
      }
    }

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
    final locked = state.saving || picking.value;
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
        confirmMessage: state.pendingId != null
            ? '아직 결과를 확인 중인 생성 요청이 있어요. 나가도 접수된 요청의 사용량은 취소되지 않습니다.'
            : '저장하지 않은 입력과 생성 결과가 사라집니다. 라이브러리에 저장한 결과는 남아 있어요.',
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
              onRefresh: () => controller.refreshUsage(
                requestId: state.pendingId ?? state.result?.id,
                raster: state.pendingId != null
                    ? state.pendingRaster
                    : state.result?.job != null,
              ),
              onGenerate: () {
                FocusScope.of(context).unfocus();
                controller.generate();
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
                      selected: input.design,
                      enabled: !locked,
                      onSelected: (design) {
                        userSelected.value = true;
                        controller.select(design);
                      },
                    ),
                    if (catalog.isLoading)
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
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              key: const ValueKey('studio-reference'),
                              onPressed: locked ? null : pickReference,
                              icon: const Icon(Icons.image_outlined, size: 18),
                              label: Text(
                                state.reference == null
                                    ? '참고 이미지'
                                    : '참고 이미지 교체',
                              ),
                            ),
                          ),
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
                          if (state.reference != null)
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.memory(
                                    state.reference!,
                                    width: 64,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    '스타일 제안 실행 시에만 AI에 전송해요.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                IconButton(
                                  tooltip: '참고 이미지 제거',
                                  onPressed: locked
                                      ? null
                                      : () => controller.reference(null),
                                  icon: const Icon(Icons.close, size: 18),
                                ),
                              ],
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
                    ExpansionTile(
                      key: const ValueKey('studio-options'),
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        '생성 방식 · ${_modeLabel(input.mode)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        _estimate(input.mode),
                        style: const TextStyle(fontSize: 12, color: _secondary),
                      ),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final mode in StudioMode.values)
                              ChoiceChip(
                                label: Text(_modeLabel(mode)),
                                selected: input.mode == mode,
                                onSelected: locked || state.busy
                                    ? null
                                    : (_) => controller.edit(
                                        input.copyWith(mode: mode),
                                      ),
                              ),
                          ],
                        ),
                        if (input.mode == StudioMode.organize &&
                            !studioSupportsGroups(input))
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(studioGroupingUnavailable),
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
                        if (input.mode != StudioMode.artwork) ...[
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
                          const SizedBox(height: 12),
                        ],
                        StudioTextField(
                          key: const ValueKey('studio-brief'),
                          label: '원하는 정리·디자인 (선택)',
                          value: input.brief,
                          maxLength: 1000,
                          maxLines: 4,
                          onChanged: (v) => controller.edit(
                            ref
                                .read(slideStudioControllerProvider)
                                .input
                                .copyWith(brief: v),
                          ),
                        ),
                        if (input.mode == StudioMode.artwork) ...[
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final count in [1, 2, 3])
                                ChoiceChip(
                                  label: Text('$count개 그룹'),
                                  selected: input.artworkGroups == count,
                                  onSelected: locked || state.busy
                                      ? null
                                      : (_) => controller.edit(
                                          input.copyWith(artworkGroups: count),
                                        ),
                                ),
                              for (final size in [32.0, 38.0, 42.0])
                                ChoiceChip(
                                  label: Text('글자 ${size.toInt()}'),
                                  selected: input.artworkFontSize == size,
                                  onSelected: locked || state.busy
                                      ? null
                                      : (_) => controller.edit(
                                          input.copyWith(artworkFontSize: size),
                                        ),
                                ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              state.brand == null
                                  ? state.brandError ??
                                        '승인된 센터 AI 참고 디자인을 확인 중이에요.'
                                  : '승인 디자인: ${state.brand!.name} · 공식 로고는 원본 그대로 합성해요.',
                            ),
                          ),
                        ],
                        if (input.mode == StudioMode.style)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              '선택 디자인의 색상·서체 특징과 참고 이미지로 편집 가능한 스타일을 제안해요. 실제 AI 배경 이미지 생성과는 별도 기능이에요.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],
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
                    if (state.pendingId != null && !state.busy)
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: controller.retry,
                            icon: const Icon(Icons.refresh),
                            label: Text(
                              state.completedOperation == null
                                  ? '같은 요청 상태 확인 · 추가 차감 없음'
                                  : '현재 입력·디자인으로 다시 적용 · 추가 차감 없음',
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final accepted = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('새 요청으로 생성할까요?'),
                                  content: Text(
                                    state.completedOperation == null
                                        ? '이전 요청의 결과나 차감 여부를 아직 확인 중이에요. 새 요청은 별도로 1회를 사용할 수 있어요.'
                                        : '완료된 정리·디자인 결과가 보관되어 있어요. 새 요청을 준비하면 이 보관 결과를 닫고, 다음 AI 생성은 별도로 1회를 사용할 수 있어요.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('돌아가기'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('새 요청 준비'),
                                    ),
                                  ],
                                ),
                              );
                              if (accepted == true && sameScope()) {
                                controller.newRequest();
                              }
                            },
                            child: const Text('새 요청 준비'),
                          ),
                        ],
                      ),
                    if (state.completedOperation != null)
                      ExpansionTile(
                        key: const ValueKey('studio-completed-operation'),
                        title: const Text('완료된 AI 결과 보관 중'),
                        subtitle: const Text(
                          '미리보기 배치만 확인하지 못했어요. 입력이나 디자인을 바꾼 뒤 추가 호출 없이 다시 적용할 수 있어요.',
                        ),
                        children: [
                          for (final group in state.completedOperation!.groups)
                            ListTile(
                              title: Text(group.heading),
                              subtitle: Text(group.lines.join('\n')),
                            ),
                        ],
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

String _modeLabel(StudioMode mode) => switch (mode) {
  StudioMode.template => '템플릿 그대로',
  StudioMode.organize => 'AI 내용 정리',
  StudioMode.style => 'AI 스타일 제안',
  StudioMode.artwork => 'AI 배경 이미지',
};
String _estimate(StudioMode mode) => switch (mode) {
  StudioMode.template => '템플릿 적용 · AI 호출·차감 없음',
  StudioMode.organize => '내용 정리 1회 · 선택 디자인 유지 · 토큰은 실행 후 확인',
  StudioMode.style => '스타일 제안 1회 · 원문 유지 · 토큰은 실행 후 확인',
  StudioMode.artwork => '배경 이미지 1장 · 1회 사용 · 토큰은 실행 후 확인',
};

class StudioActionBar extends StatelessWidget {
  const StudioActionBar({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onGenerate,
  });
  final SlideStudioState state;
  final VoidCallback onRefresh, onGenerate;
  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.viewInsetsOf(context).bottom > 0 ||
        MediaQuery.sizeOf(context).height < 500;
    final usage = state.usage;
    final unknown = usage == null;
    final count = unknown
        ? (state.usageLoading ? '사용량 확인 중…' : '사용량 미확인')
        : usage.unlimited
        ? '생성 횟수 무제한'
        : '${usage.remaining}회 남음 · ${usage.used}/${usage.limit}회 사용';
    final token = usage?.tokenContractAvailable != true
        ? '토큰 정보 미확인'
        : usage!.lastInputTokens != null && usage.lastOutputTokens != null
        ? '최근 요청 확인분 ${usage.lastInputTokens! + usage.lastOutputTokens!}토큰 · 토큰 잔액은 제공하지 않아요'
        : '횟수 기준으로 이용해요 · 토큰 잔액은 제공하지 않아요';
    final local = state.input.mode == StudioMode.template;
    final canGenerate =
        !state.busy &&
        !state.saving &&
        state.pendingId == null &&
        (local ||
            usage?.allowed == true &&
                usage?.enabled == true &&
                (usage?.unlimited == true || (usage?.remaining ?? 0) > 0));
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: Color(0xffDEDED7))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: LayoutBuilder(
            builder: (context, size) {
              final stacked =
                  size.maxWidth < 650 ||
                  MediaQuery.textScalerOf(context).scale(14) > 22;
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          count,
                          key: const ValueKey('studio-usage-count'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: '사용량 새로고침',
                        onPressed: state.usageLoading ? null : onRefresh,
                        icon: const Icon(Icons.refresh, size: 18),
                      ),
                    ],
                  ),
                  if (!compact)
                    Text(
                      token,
                      key: const ValueKey('studio-usage-tokens'),
                      style: const TextStyle(fontSize: 12, color: _secondary),
                    ),
                  if (!compact && state.usageError != null)
                    Text(
                      unknown ? '사용량 조회 실패 · 다시 확인해 주세요.' : state.usageError!,
                      style: const TextStyle(fontSize: 12, color: _secondary),
                    )
                  else if (!compact && state.usageLoading && !unknown)
                    const Text(
                      '사용량 갱신 중 · 마지막 확인 값',
                      style: TextStyle(fontSize: 12),
                    ),
                  if (!compact)
                    Text(
                      _estimate(state.input.mode),
                      style: const TextStyle(fontSize: 12, color: _secondary),
                    ),
                ],
              );
              final button = FilledButton.icon(
                key: const ValueKey('studio-generate'),
                onPressed: canGenerate ? onGenerate : null,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                icon: state.busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward),
                label: Text(state.busy ? '슬라이드 생성 중…' : '슬라이드 생성'),
              );
              final compactDetails = compact
                  ? Row(
                      children: [
                        Expanded(
                          child: Text(
                            local ? '템플릿 · 차감 없음' : count,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        IconButton(
                          tooltip: '사용량과 차감 안내',
                          icon: const Icon(Icons.info_outline, size: 20),
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('사용량과 차감 안내'),
                              content: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(count),
                                    Text(token),
                                    Text(_estimate(state.input.mode)),
                                    if (state.usageError != null)
                                      Text(state.usageError!),
                                    TextButton(
                                      onPressed: onRefresh,
                                      child: const Text('사용량 새로고침'),
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('닫기'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : details;
              return stacked
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        compactDetails,
                        const SizedBox(height: 8),
                        button,
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: compactDetails),
                        const SizedBox(width: 24),
                        SizedBox(width: 360, child: button),
                      ],
                    );
            },
          ),
        ),
      ),
    );
  }
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
