import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slide_reference_design.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides_editor.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slide_design_controller.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/widgets/ai_slides_editor_controls.dart';

import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';

enum _StartPath { catalog, ai, reference }

class AiSlideDesignStudio extends HookConsumerWidget {
  const AiSlideDesignStudio({super.key, this.draft, required this.onSelected});
  final AiSlideDraft? draft;
  final ValueChanged<AiSlideDesign> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerId = ref.watch(aiSlideDesignOwnerIdProvider);
    final storeId = ref.watch(aiSlideDesignStoreIdProvider);
    final state = ref.watch(aiSlideDesignControllerProvider);
    final controller = ref.read(aiSlideDesignControllerProvider.notifier);
    final mode = useState(_StartPath.catalog);
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
    final access = mode.value == _StartPath.catalog
        ? null
        : ref.watch(aiSlideDesignAccessProvider);
    final canGenerate =
        access?.value?.premium == true && access?.value?.enabled == true;
    final busy = state.generating || picking.value;

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
      if (theme == null) return;
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
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(8),
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
                  child: WorkoutSlidePreview(
                    module: previewAiSlide(
                      applyAiSlideTheme(
                        draft ?? initialAiSlideDesignDraft(design.theme),
                        design.theme,
                      ),
                    ),
                    isRest: false,
                    borderRadius: 8,
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
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
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
                    fontSize: 11,
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
        final columns = bounds.maxWidth >= 560 ? 3 : 2;
        final width = (bounds.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final design in designs)
              SizedBox(width: width, child: designCard(design)),
          ],
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '클래스에 어울리는 디자인',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 5),
                  Text(
                    '디자인을 고르고, 매일 운동 내용만 바꿔 보세요.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            if (draft != null || state.selected != null)
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
        if (state.selected != null)
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
        if (state.templates.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            '저장한 클래스',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
        if (state.templateError != null) AiSlidesNotice(state.templateError!),
        const SizedBox(height: 16),
        SegmentedButton<_StartPath>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: _StartPath.catalog, label: Text('기본')),
            ButtonSegment(value: _StartPath.ai, label: Text('디자인 추천')),
            ButtonSegment(value: _StartPath.reference, label: Text('이미지 스타일')),
          ],
          selected: {mode.value},
          onSelectionChanged: busy
              ? null
              : (values) => mode.value = values.first,
        ),
        const SizedBox(height: 14),
        if (mode.value == _StartPath.catalog) ...[
          const Text(
            '예시 내용을 오늘의 운동으로 바꿔 시작해요. AI 사용량 차감은 없어요.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          designGrid(aiSlideDesignCatalog),
          if (showDolpaReferenceDesign) ...[
            const SizedBox(height: 22),
            const Text(
              '참고 템플릿',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text('원본 배치 유지 · 운동 문구만 수정', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            designGrid(const [dolpaReferenceDesign]),
          ],
        ] else ...[
          if (mode.value == _StartPath.reference) ...[
            const Text(
              '이미지에서 스타일 가져오기',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
            enabled: !busy,
            minLines: 2,
            maxLines: 4,
            maxLength: 1500,
            decoration: InputDecoration(
              labelText: mode.value == _StartPath.reference
                  ? '더 반영할 특징 (선택)'
                  : '원하는 디자인',
              hintText: '예: 짙은 배경, 라임색 포인트, 큰 제목과 여유 있는 운동행',
              border: const OutlineInputBorder(),
            ),
          ),
          if (access?.isLoading == true)
            const LinearProgressIndicator(minHeight: 2),
          if (access?.hasError == true)
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '이용 가능 여부를 확인하지 못했어요.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(aiSlideDesignAccessProvider),
                  child: const Text('다시 확인'),
                ),
              ],
            ),
          if (access?.hasValue == true && !canGenerate)
            AiSlidesNotice(
              access!.value!.premium
                  ? '디자인 추천을 준비 중이에요. 기본 디자인으로 시작해 주세요.'
                  : '디자인 추천과 이미지 스타일 가져오기는 프리미엄 기능이에요.',
            ),
          if (canGenerate)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '이번 달 AI 사용 가능 ${state.remaining ?? access!.value!.remaining}회',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          FilledButton.icon(
            key: const ValueKey('ai-design-generate'),
            onPressed:
                !canGenerate ||
                    busy ||
                    (mode.value == _StartPath.reference &&
                        reference.value == null)
                ? null
                : () {
                    FocusScope.of(context).unfocus();
                    controller.generate(
                      mode.value == _StartPath.reference
                          ? '${brief.text}\n중점적으로 반영할 특징: ${priorities.value.join(', ')}'
                          : brief.text,
                      reference: mode.value == _StartPath.reference
                          ? reference.value
                          : null,
                    );
                  },
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(
              state.generating
                  ? '디자인 준비 중…'
                  : mode.value == _StartPath.reference
                  ? '이미지에서 스타일 가져오기'
                  : '새 디자인 추천받기',
            ),
          ),
          if (mode.value == _StartPath.reference)
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
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            designGrid(state.proposals),
          ],
          for (final warning in state.warnings) AiSlidesNotice(warning),
        ],
        if (pickerError.value != null)
          AiSlidesNotice(pickerError.value!, error: true),
        if (state.error != null) AiSlidesNotice(state.error!, error: true),
        if (state.saving) const LinearProgressIndicator(minHeight: 2),
      ],
    );
  }
}
