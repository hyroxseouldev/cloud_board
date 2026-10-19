import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_reference_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/center_slide_catalog_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/center_slide_preview.dart';

import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/visible_slide_preview.dart';
import 'package:cloud_board/src/app/core/theme/app_motion.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slide_design_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slides_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_editor_controls.dart';

import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';

enum AiSlideDesignStudioSection { templates, create }

enum AiSlideCreationPath { notes, style, reference }

class AiSlideDesignStudio extends HookConsumerWidget {
  const AiSlideDesignStudio({
    super.key,
    this.draft,
    required this.section,
    required this.onSelected,
    this.creationPath = AiSlideCreationPath.notes,
    this.onCreationPathChanged,
    this.notesEditor,
    this.onEdited,
  });
  final AiSlideDesignStudioSection section;
  final AiSlideDraft? draft;
  final ValueChanged<AiSlideDesign> onSelected;
  final AiSlideCreationPath creationPath;
  final ValueChanged<AiSlideCreationPath>? onCreationPathChanged;
  final Widget? notesEditor;
  final VoidCallback? onEdited;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerId = ref.watch(aiSlideDesignOwnerIdProvider);
    final storeId = ref.watch(aiSlideDesignStoreIdProvider);
    final state = ref.watch(aiSlideDesignControllerProvider);
    final controller = ref.read(aiSlideDesignControllerProvider.notifier);
    final catalog = section == AiSlideDesignStudioSection.templates;
    final centerCatalog = catalog
        ? ref.watch(centerSlideCatalogProvider)
        : null;
    final centerData =
        centerCatalog?.isLoading == false && !centerCatalog!.hasError
        ? centerCatalog.value
        : null;
    final mode = creationPath;
    final brief = useTextEditingController();
    final reference = useState<Uint8List?>(null);
    final referenceName = useState<String?>(null);
    final picking = useState(false);
    final pickerError = useState<String?>(null);
    final priorities = useState(<String>{'색상', '글씨', '배치'});
    useEffect(() {
      brief.clear();
      reference.value = null;
      referenceName.value = null;
      pickerError.value = null;
      return null;
    }, [ownerId, storeId]);
    bool sameScope() =>
        context.mounted &&
        ref.read(aiSlideDesignOwnerIdProvider) == ownerId &&
        ref.read(aiSlideDesignStoreIdProvider) == storeId;
    final access = catalog ? null : ref.watch(aiSlidesAccessProvider);
    final canGenerate =
        access?.isLoading == false &&
        access?.hasError == false &&
        access?.value?.canRequest == true &&
        access?.value?.enabled == true;
    final busy =
        state.generating ||
        picking.value ||
        ref.watch(
          aiSlidesControllerProvider.select((value) => value.generating),
        );

    void choose(AiSlideDesign design) {
      controller.select(design);
      onSelected(design);
    }

    Future<void> pickReference() async {
      picking.value = true;
      pickerError.value = null;
      try {
        final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
        );
        if (!sameScope() || image == null) return;
        if (await image.length() > 10 * 1024 * 1024) {
          if (context.mounted) pickerError.value = '10MB 이하의 참고 이미지를 선택해 주세요.';
          return;
        }
        final bytes = await image.readAsBytes();
        if (!sameScope()) return;
        reference.value = bytes;
        referenceName.value = image.name;
        onEdited?.call();
      } catch (_) {
        if (context.mounted) {
          pickerError.value = '사진을 불러오지 못했어요. 사진 접근 권한을 확인해 주세요.';
        }
      } finally {
        if (context.mounted) picking.value = false;
      }
    }

    Future<void> saveClass() async {
      final theme = draft == null
          ? state.selected?.theme
          : aiSlideThemeFromDraft(draft!);
      if (theme == null || theme.centerRecipe != null) return;
      final name = await showDialog<String>(
        context: context,
        builder: (context) => HookBuilder(
          builder: (context) {
            final field = useTextEditingController();
            final value = useValueListenable(field);
            return AlertDialog(
              title: const Text('클래스 디자인 저장'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('다음 수업에도 같은 디자인을 사용할 수 있어요. 운동 내용은 저장하지 않아요.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: field,
                    autofocus: true,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      labelText: '클래스 이름',
                      hintText: '예: HYROX, 스트렝스, 아침 클래스',
                    ),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        Navigator.pop(context, value.trim());
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: value.text.trim().isEmpty
                      ? null
                      : () => Navigator.pop(context, value.text.trim()),
                  child: const Text('저장'),
                ),
              ],
            );
          },
        ),
      );
      if (name == null || !context.mounted) return;
      final saved = await controller.saveClass(name, theme);
      if (saved && context.mounted) {
        final selected = ref.read(aiSlideDesignControllerProvider).selected;
        if (selected != null) onSelected(selected);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$name 디자인을 저장했어요.')));
      }
    }

    Widget designCard(AiSlideDesign design) {
      final selected =
          state.selected?.id == design.id &&
          state.selected?.theme == design.theme;
      return Semantics(
        selected: selected,
        button: true,
        label: '${design.name}, ${design.description}',
        child: InkWell(
          key: ValueKey('ai-design-${design.id}'),
          onTap: busy ? null : () => choose(design),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: AppMotion.duration(context, AppMotion.stateChange),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                        .withValues(alpha: .32)
                  : Theme.of(context).colorScheme.surfaceContainerLow,
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: VisibleSlidePreview(
                    builder: (context) {
                      final preview = applyAiSlideTheme(
                        design.sample ??
                            (design.theme.designStyle?.originalTemplate != null
                                ? initialAiSlideDesignDraft(design.theme)
                                : draft ??
                                      initialAiSlideDesignDraft(design.theme)),
                        design.theme,
                      );
                      return preview.centerRecipe != null
                          ? CenterSlidePreview(draft: preview, compact: true)
                          : WorkoutSlidePreview(
                              module: previewAiSlide(preview),
                              isRest: false,
                              borderRadius: 8,
                            );
                    },
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        design.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          letterSpacing: -0.14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 17,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  design.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget designGrid(List<AiSlideDesign> designs) => LayoutBuilder(
      builder: (context, bounds) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
        final columns = bounds.maxWidth < 300 || largeText ? 1 : 2;
        final width = (bounds.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final design in designs)
              SizedBox(width: width, child: designCard(design)),
          ],
        );
      },
    );

    Widget templateHeading(String title, int count) => Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              letterSpacing: -0.15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          '$count개',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    catalog
                        ? '수업에 맞는 템플릿'
                        : switch (mode) {
                            AiSlideCreationPath.notes => '수업 메모로 시작해요',
                            AiSlideCreationPath.style => '수업에 맞는 스타일을 찾아요',
                            AiSlideCreationPath.reference => '이미지의 느낌을 가져와요',
                          },
                    style: const TextStyle(
                      fontSize: 24,
                      letterSpacing: -0.24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    catalog
                        ? '마음에 드는 틀을 고르고 운동 내용만 바꿔 보세요.'
                        : '적어 둔 운동을 수업 화면으로 정리해요.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (catalog &&
                (draft != null || state.selected != null) &&
                (draft != null
                        ? draft!.centerRecipe
                        : state.selected?.theme.centerRecipe) ==
                    null)
              IconButton(
                key: const ValueKey('ai-save-class'),
                onPressed: state.saving ? null : saveClass,
                tooltip: '클래스 디자인 저장',
                icon: Icon(
                  state.saved
                      ? Icons.bookmark_added_rounded
                      : Icons.bookmark_add_outlined,
                ),
              ),
          ],
        ),
        if (catalog && state.selected != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '현재 디자인 · ${state.selected!.name}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        if (catalog && state.templates.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            '저장한 클래스',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: -0.12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 7,
            runSpacing: 4,
            children: [
              for (final design in state.templates)
                ChoiceChip(
                  key: ValueKey('ai-class-${design.id}'),
                  label: Text(design.name),
                  selected: state.selected?.id == design.id,
                  onSelected: busy ? null : (_) => choose(design),
                ),
            ],
          ),
        ],
        if (catalog && state.templateError != null)
          AiSlidesNotice(state.templateError!),
        if (!catalog) const SizedBox(height: 24),
        if (!catalog)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final path in AiSlideCreationPath.values)
                ChoiceChip(
                  selected: mode == path,
                  label: Text(switch (path) {
                    AiSlideCreationPath.notes => '수업 메모',
                    AiSlideCreationPath.style => '스타일 제안',
                    AiSlideCreationPath.reference => '이미지로 시작',
                  }),
                  onSelected: busy
                      ? null
                      : (_) => onCreationPathChanged?.call(path),
                ),
            ],
          ),
        SizedBox(height: catalog ? 20 : 14),
        if (catalog) ...[
          const AiSlidesNotice('템플릿 선택과 직접 수정은 AI 토큰·생성 횟수를 사용하지 않아요.'),
          const SizedBox(height: 20),
          if (centerData != null && centerData.templates.isNotEmpty) ...[
            templateHeading(
              centerData.centerName.trim().isEmpty
                  ? '우리 센터 템플릿'
                  : '${centerData.centerName} 센터 템플릿',
              centerData.templates.length,
            ),
            const SizedBox(height: 6),
            const Text(
              '우리 센터의 디자인을 고르고 운동 내용을 바꿔 보세요.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            designGrid(centerData.templates),
            const Divider(height: 48),
          ] else if (centerCatalog?.isLoading == true) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 12),
          ] else if (centerCatalog?.hasError == true) ...[
            const Text('센터 템플릿을 불러오지 못했어요. 기본 템플릿은 사용할 수 있어요.'),
            TextButton.icon(
              onPressed: () => ref.invalidate(centerSlideCatalogProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('다시 불러오기'),
            ),
            const SizedBox(height: 12),
          ],
          templateHeading('기본 템플릿', aiSlideDesignCatalog.length),
          const SizedBox(height: 6),
          const Text(
            '예시 내용을 오늘의 운동으로 바꿔 시작해요.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          designGrid(aiSlideDesignCatalog),
        ] else if (mode == AiSlideCreationPath.notes) ...[
          ?notesEditor,
        ] else ...[
          if (mode == AiSlideCreationPath.reference) ...[
            const Text(
              '이 이미지의 느낌으로',
              style: TextStyle(
                fontSize: 15,
                letterSpacing: -0.15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('ai-reference-pick'),
              onPressed: busy ? null : pickReference,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                reference.value == null ? '참고 이미지 한 장 선택' : '다른 이미지 선택',
              ),
            ),
            if (reference.value != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    reference.value!,
                    height: 140,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, trace) => const SizedBox(
                      height: 72,
                      child: Center(child: Text('이미지를 읽을 수 없어요. 다시 선택해 주세요.')),
                    ),
                  ),
                ),
              ),
            if (referenceName.value != null)
              Text(
                referenceName.value!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            Wrap(
              spacing: 6,
              children: [
                for (final label in const ['색상', '글씨', '배치', '장식'])
                  FilterChip(
                    label: Text(label),
                    selected: priorities.value.contains(label),
                    onSelected: busy
                        ? null
                        : (selected) => priorities.value =
                              selected
                                    ? {...priorities.value, label}
                                    : {...priorities.value}
                                ..remove(label),
                  ),
              ],
            ),
            const Text(
              '선택한 색상·글씨·배치를 참고해 편집 가능한 스타일을 만들어요. 원본과는 차이가 있을 수 있어요.',
              style: TextStyle(fontSize: 12),
            ),
          ] else
            const Text(
              '같은 수업 내용으로 서로 다른 디자인 3가지를 추천해요.',
              style: TextStyle(fontSize: 12),
            ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('ai-design-brief'),
            controller: brief,
            onChanged: (_) => onEdited?.call(),
            enabled: !busy,
            minLines: 2,
            maxLines: 4,
            maxLength: 1500,
            decoration: InputDecoration(
              labelText: mode == AiSlideCreationPath.reference
                  ? '더 반영할 특징 (선택)'
                  : '원하는 디자인',
              hintText: '예: 짙은 배경, 라임색 포인트, 큰 제목과 여유 있는 운동행',
              border: const OutlineInputBorder(),
            ),
          ),
          FilledButton.icon(
            key: const ValueKey('ai-design-generate'),
            onPressed:
                !canGenerate ||
                    busy ||
                    (mode == AiSlideCreationPath.reference &&
                        reference.value == null)
                ? null
                : () {
                    FocusScope.of(context).unfocus();
                    controller.generate(
                      mode == AiSlideCreationPath.reference
                          ? '${brief.text}\n중점적으로 반영할 특징: ${priorities.value.join(', ')}'
                          : brief.text,
                      reference: mode == AiSlideCreationPath.reference
                          ? reference.value
                          : null,
                    );
                  },
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(
              state.generating
                  ? '디자인 준비 중…'
                  : mode == AiSlideCreationPath.reference
                  ? '이 이미지로 디자인 만들기'
                  : '스타일 3가지 제안받기',
            ),
          ),
          if (mode == AiSlideCreationPath.reference)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '스타일을 가져올 때 선택한 이미지를 AI에 전송해요.',
                style: TextStyle(fontSize: 11),
              ),
            ),
          if (state.generating)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (state.proposals.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '마음에 드는 디자인을 선택해 주세요.',
              style: TextStyle(
                letterSpacing: -0.14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            designGrid(state.proposals),
          ],
          for (final warning in state.warnings) AiSlidesNotice(warning),
        ],
        if (mode == AiSlideCreationPath.reference && pickerError.value != null)
          AiSlidesNotice(pickerError.value!, error: true),
        if (state.error != null &&
            (catalog || mode != AiSlideCreationPath.notes))
          AiSlidesNotice(state.error!, error: true),
        if (!catalog)
          Container(
            key: const ValueKey('ai-generation-usage'),
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '이번 달 요청 사용량',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: -0.12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '사용량 새로고침',
                      onPressed: () => ref.invalidate(aiSlidesAccessProvider),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                access!.when(
                  loading: () => const Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('사용량 확인 중…', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  error: (_, _) => Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '사용량을 불러오지 못했어요.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => ref.invalidate(aiSlidesAccessProvider),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('새로고침'),
                      ),
                    ],
                  ),
                  data: (value) => Text(
                    !value.canRequest
                        ? 'AI 슬라이드 도우미 · Plus 월 10회 / Premium 월 30회'
                        : !value.enabled
                        ? value.availabilityReason == 'feature-disabled'
                              ? 'AI 슬라이드 도우미를 잠시 점검하고 있어요.'
                              : 'AI 슬라이드 도우미를 준비 중이에요.'
                        : 'AI 슬라이드 도우미 · 이번 달 ${value.usedRequests}/${value.limit}회 사용 · ${value.remaining}회 남음'
                              '${value.availabilityReason == 'service-limit' ? '\n서비스 제공 한도로 새 요청이 잠시 중단됐어요.' : ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '내용 정리와 디자인 제안은 합산해 요청마다 1회 사용해요. 내용 1회 + 디자인 1회 = 2회이며, 슬라이드 장수와는 무관해요.\n매월 1일 00:00 KST 초기화 · 같은 요청의 저장된 결과는 추가 차감 없이 다시 확인할 수 있어요.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        if (!catalog) const AiSlidesNotice('템플릿 선택과 직접 수정은 생성 횟수를 사용하지 않아요.'),
        if (state.saving) const LinearProgressIndicator(minHeight: 2),
      ],
    );
  }
}
