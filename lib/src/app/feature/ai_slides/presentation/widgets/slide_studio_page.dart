import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';
import 'package:cloud_board/src/app/core/theme/app_motion.dart';

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

import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/template_jobs_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/template_job_image.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/template_job.dart';

const _oat = Color(0xffF7F5EF),
    _surface = Color(0xffFFFDF8),
    _sage = Color(0xff526B60),
    _ink = Color(0xff2B332E),
    _secondary = Color(0xff616B63);

/// Free basic templates and durable center generation, with immutable results.
class SlideStudioPage extends HookConsumerWidget {
  const SlideStudioPage({super.key, required this.guard});
  final ExitGuard guard;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(slideStudioControllerProvider);
    final controller = ref.read(slideStudioControllerProvider.notifier);
    final jobs = ref.watch(templateJobsControllerProvider);
    final jobController = ref.read(templateJobsControllerProvider.notifier);
    ref.listen(templateJobsControllerProvider, (previous, next) {
      if (next.usage != null && previous?.usage != next.usage) {
        controller.acceptTemplateUsage(next.usage!);
      }
      if (next.authorityDenied && previous?.authorityDenied != true) {
        controller.clearTemplateResults();
      }
    });
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
    final subtitleFocus = useFocusNode();
    final subtitleAnchor = useMemoized(GlobalKey.new);
    final subtitleError = useState<String?>(null);
    final initialInput = useRef(input);
    final restoredJob = useRef(false);
    final currentJob = jobs.currentJob;
    final currentShown =
        currentJob != null &&
        state.result?.templateJob?.requestId == currentJob.requestId &&
        jobs.currentPng != null;
    final showingJobStatus =
        jobs.currentRequestId != null ||
        (jobs.unresolved && state.result == null) ||
        (input.design.theme.centerRecipe != null && jobs.error != null);
    final showingResult =
        state.result != null && (!showingJobStatus || currentShown);
    useEffect(() {
      // Resume only in-progress work on a pristine entry. Finished history is
      // opened explicitly from management, never below a new empty draft.
      if (!restoredJob.value && jobs.recoveryChecked == true && !jobs.loading) {
        restoredJob.value = true;
        final pending = jobs.jobs.where((job) => job.inProgress).firstOrNull;
        if (!jobs.unresolved &&
            jobs.error == null &&
            pending != null &&
            state.result == null &&
            input == initialInput.value &&
            jobs.currentRequestId == null) {
          final id = pending.requestId;
          Future.microtask(() {
            if (!context.mounted) return;
            final latest = ref.read(templateJobsControllerProvider);
            if (latest.currentRequestId == null &&
                !latest.unresolved &&
                latest.error == null &&
                latest.jobs.any(
                  (job) => job.requestId == id && job.inProgress,
                ) &&
                ref.read(slideStudioControllerProvider).input ==
                    initialInput.value &&
                ref.read(slideStudioControllerProvider).result == null) {
              jobController.selectCurrent(id);
            }
          });
        }
      }
      return null;
    }, [jobs.recoveryChecked, jobs.loading]);
    useEffect(() {
      final png = jobs.currentPng, job = currentJob;
      if (png != null &&
          job != null &&
          !currentShown &&
          !state.busy &&
          !state.saving) {
        Future.microtask(() {
          if (!context.mounted) return;
          final latest = ref.read(templateJobsControllerProvider);
          if (latest.currentRequestId == job.requestId &&
              identical(latest.currentPng, png)) {
            controller.openTemplateResult(job, png);
          }
        });
      }
      return null;
    }, [jobs.currentPng, currentJob, state.busy, state.saving]);

    Future<void> showSubtitleError() async {
      subtitleError.value = '운동 안내 문구를 입력해 주세요. 공백만 입력할 수 없어요.';
      // Materialize the field even when the lazy list is far from the input.
      if (subtitleAnchor.currentContext == null && bodyScroll.hasClients) {
        bodyScroll.jumpTo(0);
        await WidgetsBinding.instance.endOfFrame;
        while (context.mounted &&
            subtitleAnchor.currentContext == null &&
            bodyScroll.hasClients &&
            bodyScroll.offset < bodyScroll.position.maxScrollExtent) {
          bodyScroll.jumpTo(
            (bodyScroll.offset + bodyScroll.position.viewportDimension * .7)
                .clamp(0, bodyScroll.position.maxScrollExtent),
          );
          await WidgetsBinding.instance.endOfFrame;
        }
      }
      if (!context.mounted) return;
      final field = subtitleAnchor.currentContext;
      if (field != null) {
        await Scrollable.ensureVisible(
          field,
          alignment: .35,
          duration: const Duration(milliseconds: 180),
        );
      }
      if (context.mounted) subtitleFocus.requestFocus();
    }

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

    Future<void> openLibrary() async {
      FocusScope.of(context).unfocus();
      final studioPath = GoRouterState.of(context).uri.path
          .replaceFirst(RegExp(r'/$'), '');
      final job = await context.push<TemplateJob>('$studioPath/library');
      if (job == null || !sameScope()) return;
      jobController.selectResult(job);
    }

    Widget preview(StudioResult result) => result.serverPng != null
        ? TemplateJobImage(bytes: result.serverPng!)
        : result.job != null && result.brand != null
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

    final narrow = MediaQuery.sizeOf(context).width < 700;
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
        dirty: state.unsaved && jobs.acceptedInput != state.input,
        blocked: state.busy || state.saving || jobs.submitting,
        confirmMessage:
            '접수하지 않은 입력과 저장하지 않은 기본 템플릿 결과가 사라집니다. 접수된 생성 작업과 저장된 이미지는 남아 있어요.',
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
                  tooltip: 'AI 생성 슬라이드 관리',
                  onPressed: locked || state.busy ? null : openLibrary,
                  icon: const Icon(Icons.photo_library_outlined),
                )
              else
                TextButton(
                  onPressed: locked || state.busy ? null : openLibrary,
                  child: const Text('AI 생성 슬라이드 관리'),
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
              submitting: jobs.submitting,
              unresolved: jobs.unresolved,
              generating: currentJob?.inProgress == true,
              designAvailable: selectedAvailable,
              onRefreshUsage: () {
                controller.refreshUsage();
                jobController.refresh();
              },
              onGenerate: () async {
                FocusScope.of(context).unfocus();
                final currentInput = ref
                    .read(slideStudioControllerProvider)
                    .input;
                if (currentInput.subtitle.trim().isEmpty) {
                  await showSubtitleError();
                  return;
                }
                subtitleError.value = null;
                restoredJob.value = true;
                if (currentInput.design.theme.centerRecipe != null) {
                  jobController.enqueue(currentInput);
                } else {
                  jobController.selectCurrent(null);
                  controller.generateTemplate();
                }
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
                    Padding(
                      key: subtitleAnchor,
                      padding: EdgeInsets.zero,
                      child: StudioTextField(
                        key: const ValueKey('studio-subtitle'),
                        label: '운동 안내 문구 (필수)',
                        value: input.subtitle,
                        maxLength: 120,
                        focusNode: subtitleFocus,
                        errorText: subtitleError.value,
                        onChanged: (v) {
                          if (v.trim().isNotEmpty) subtitleError.value = null;
                          controller.edit(
                            ref
                                .read(slideStudioControllerProvider)
                                .input
                                .copyWith(subtitle: v),
                          );
                        },
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
                                    jobController.selectCurrent(null);
                                    controller.undo();
                                  },
                            icon: const Icon(Icons.undo, size: 18),
                            label: const Text('이전 결과 보기'),
                          ),
                        if (showingResult)
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
                      child: showingJobStatus && !currentShown
                          ? StudioCurrentJob(
                              state: jobs,
                              onRefresh: jobController.refresh,
                              onRecover: jobController.recover,
                              onRetryAsset: jobController.retryCurrentAsset,
                              onRetry: currentJob == null
                                  ? null
                                  : () => jobController.retry(currentJob),
                            )
                          : state.result == null
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
                    if (showingResult && state.dirty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          state.result!.templateJob != null
                              ? '열어 본 이미지는 이전 수업 내용으로 만들어졌어요. 현재 입력은 그대로 유지됩니다.'
                              : '변경사항이 아직 반영되지 않았어요. 새 결과를 생성한 뒤 저장하거나 추가해 주세요.',
                          key: const ValueKey('studio-dirty'),
                          style: const TextStyle(color: _secondary),
                        ),
                      ),
                    if (showingResult) ...[
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
                                ? '이미지 보관함에 저장됨'
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
                                        (state.dirty &&
                                            state.result!.templateJob ==
                                                null) ||
                                        state.result!.savedModule != null
                                    ? null
                                    : controller.save,
                                icon: Icon(
                                  state.result!.savedModule != null
                                      ? Icons.photo_library
                                      : Icons.save_outlined,
                                ),
                                label: Text(state.saving ? '처리 중…' : '이미지 저장'),
                              ),
                              OutlinedButton.icon(
                                key: const ValueKey('studio-add'),
                                onPressed:
                                    locked ||
                                        state.busy ||
                                        state.pendingId != null ||
                                        (state.dirty &&
                                            state.result!.templateJob == null)
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
    required this.onRefreshUsage,
    this.submitting = false,
    this.unresolved = false,
    this.generating = false,
  });
  final SlideStudioState state;
  final bool designAvailable, submitting, unresolved, generating;
  final VoidCallback onGenerate, onRefreshUsage;
  @override
  Widget build(BuildContext context) {
    final usage = state.usage;
    final center = state.input.design.theme.centerRecipe != null;
    final count = usage == null
        ? state.usageLoading
              ? 'AI 남은 횟수 조회 중…'
              : 'AI 남은 횟수 미확인'
        : usage.unlimited
        ? 'AI 생성 횟수 무제한'
        : 'AI ${usage.remaining}회 남음 · ${usage.used}/${usage.limit}회 사용';
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: Color(0xffDEDED7))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      count,
                      key: const ValueKey('studio-usage-count'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '사용량 새로고침',
                    visualDensity: VisualDensity.compact,
                    onPressed: state.usageLoading ? null : onRefreshUsage,
                    icon: const Icon(Icons.refresh, size: 18),
                  ),
                ],
              ),
              if (state.usageError != null)
                Text(
                  usage == null
                      ? '사용량을 불러오지 못했어요. 다시 확인해 주세요.'
                      : '사용량 갱신 실패 · 마지막 확인 값',
                  style: const TextStyle(fontSize: 12, color: _secondary),
                ),
              if (state.usageLoading && usage != null)
                const Text(
                  '사용량 갱신 중 · 마지막 확인 값',
                  style: TextStyle(fontSize: 12),
                ),
              if (usage != null && (!usage.allowed || !usage.enabled))
                const Text(
                  '현재 AI 생성은 이용할 수 없어요.',
                  style: TextStyle(fontSize: 12),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  center
                      ? '센터 전용 생성은 AI 1회를 사용해요. 접수 후 화면을 나가도 계속 만들어요.'
                      : '기본 템플릿은 AI 없이 무료로 생성해요.',
                  style: TextStyle(fontSize: 12, color: _secondary),
                ),
              ),
              FilledButton.icon(
                key: const ValueKey('studio-generate'),
                onPressed:
                    state.busy ||
                        state.saving ||
                        submitting ||
                        !designAvailable ||
                        (center &&
                            (unresolved ||
                                generating ||
                                usage == null ||
                                !usage.allowed ||
                                !usage.enabled ||
                                (!usage.unlimited && usage.remaining == 0)))
                    ? null
                    : onGenerate,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                icon: state.busy || submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward),
                label: Text(
                  submitting
                      ? '생성 접수 중…'
                      : state.busy
                      ? '슬라이드 생성 중…'
                      : '슬라이드 생성',
                ),
              ),
            ],
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
    this.focusNode,
    this.errorText,
  });
  final String value, label;
  final FocusNode? focusNode;
  final String? errorText;
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
      focusNode: focusNode,
      maxLength: maxLength,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        errorMaxLines: 2,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}

/// Only the selected request belongs in the result area, never the history list.
class StudioCurrentJob extends StatelessWidget {
  const StudioCurrentJob({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onRecover,
    required this.onRetryAsset,
    this.onRetry,
  });
  final TemplateJobsState state;
  final VoidCallback onRefresh, onRecover, onRetryAsset;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final job = state.currentJob;
    final error = state.currentAssetError ?? state.error;
    final waiting =
        !state.unresolved &&
        error == null &&
        (state.submitting ||
            job?.inProgress == true ||
            state.currentAssetLoading == true);
    final text = state.unresolved
        ? '생성 접수를 확인하지 못했어요. 접수 확인으로 같은 요청을 확인해 주세요.'
        : error ??
              (job?.status == 'failed'
                  ? job?.message ?? '이미지를 만들지 못했어요.'
                  : state.currentAssetLoading == true
                  ? '완료된 이미지를 불러오고 있어요.'
                  : state.submitting
                  ? '생성을 접수하고 있어요.'
                  : job?.inProgress == true
                  ? '슬라이드를 만들고 있어요.'
                  : '작업 상태를 다시 확인해 주세요.');
    return Padding(
      key: const ValueKey('studio-current-job'),
      padding: waiting
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (waiting) ...[
            const _StudioSlideSkeleton(),
            const SizedBox(height: 16),
          ],
          Text(text, textAlign: TextAlign.center),
          if (job?.inProgress == true) ...[
            const SizedBox(height: 8),
            const Text(
              '화면을 나가도 계속 생성돼요. AI 생성 슬라이드 관리에서 다시 확인할 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _secondary),
            ),
          ],
          if (state.unresolved)
            TextButton(
              onPressed: state.submitting ? null : onRecover,
              child: const Text('접수 확인'),
            )
          else if (state.currentAssetError != null && !state.authorityDenied)
            TextButton(
              onPressed: state.currentAssetLoading == true
                  ? null
                  : onRetryAsset,
              child: const Text('이미지 다시 불러오기'),
            )
          else if (job?.status == 'failed' && job?.retryable == true)
            TextButton(
              onPressed: state.submitting ? null : onRetry,
              child: const Text('다시 생성 (AI 1회)'),
            )
          else if (!state.submitting && state.currentAssetLoading != true)
            TextButton(
              onPressed: state.loading ? null : onRefresh,
              child: const Text('상태 확인'),
            ),
          if (job?.status == 'failed' && job?.retryable != true)
            const Text(
              '중복 생성을 막기 위해 이 작업은 다시 생성할 수 없어요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
        ],
      ),
    );
  }
}

/// Keeps the exact final PNG footprint while only the placeholder breathes.
class _StudioSlideSkeleton extends HookWidget {
  const _StudioSlideSkeleton();

  @override
  Widget build(BuildContext context) {
    final lifecycle = useAppLifecycleState();
    final animate =
        !AppMotion.reduced(context) &&
        TickerMode.valuesOf(context).enabled &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    final pulse = useAnimationController(
      duration: AppMotion.shimmer,
      initialValue: 1,
    );
    useEffect(() {
      if (animate) {
        pulse.repeat(reverse: true);
      } else {
        pulse.stop();
        pulse.value = 1;
      }
      return null;
    }, [animate, pulse]);
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AspectRatio(
          key: const ValueKey('studio-result-skeleton'),
          aspectRatio: 16 / 9,
          child: FadeTransition(
            opacity: Tween<double>(
              begin: .55,
              end: 1,
            ).animate(pulse.drive(CurveTween(curve: Curves.easeInOut))),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xffEBEEE8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: LayoutBuilder(
                builder: (_, bounds) {
                  Widget bar(double top, double width, double height) =>
                      Positioned(
                        left: bounds.maxWidth * .07,
                        top: bounds.maxHeight * top,
                        width: bounds.maxWidth * width,
                        height: bounds.maxHeight * height,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xffD4DBD2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                  return Stack(
                    children: [
                      bar(.14, .45, .08),
                      bar(.37, .53, .05),
                      bar(.51, .43, .05),
                      bar(.65, .48, .05),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
