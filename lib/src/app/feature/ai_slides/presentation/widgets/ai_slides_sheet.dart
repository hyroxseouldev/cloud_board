import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_design_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/slide_design.dart';
import 'package:cloud_board/src/app/feature/workouts/data/datasources/slide_design_renderer.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/entities/ai_slides.dart';
import 'package:cloud_board/src/app/feature/ai_slides/domain/usecases/ai_slides_actions.dart';
import 'package:cloud_board/src/app/feature/ai_slides/presentation/controllers/ai_slides_controller.dart';

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
      constraints: const BoxConstraints(maxWidth: 840),
      builder: (_) => const AiSlidesSheet(),
    );

class AiSlidesSheet extends HookConsumerWidget {
  const AiSlidesSheet({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prompt = useTextEditingController();
    useListenable(prompt);
    final access = ref.watch(aiSlidesAccessProvider);
    final state = ref.watch(aiSlidesControllerProvider);
    final result = state.asData?.value;
    ref.listen(aiSlidesControllerProvider, (before, after) {
      if (after.hasError && before?.error != after.error) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${after.error}')));
      }
    });
    final allowed =
        access.value?.premium == true && access.value?.enabled == true;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .93,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
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
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const Text(
                    '한 장으로 만드는 수업 보드',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '수업 내용을 한 장의 슬라이드로 정리해요. 미리보기에서 색상과 내용을 바꿀 수 있어요.',
                  ),
                  const SizedBox(height: 12),
                  access.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$error'),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(aiSlidesAccessProvider),
                          child: const Text('다시 확인'),
                        ),
                      ],
                    ),
                    data: (value) => Text(
                      !value.premium
                          ? '프리미엄 전용 기능이에요.'
                          : !value.enabled
                          ? 'AI 기능을 준비 중이에요.'
                          : '이번 달 ${value.remaining}/${value.limit}회 남음 · 한 번에 1장',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const ValueKey('ai-slides-prompt'),
                    controller: prompt,
                    enabled: !state.isLoading,
                    maxLength: 6000,
                    minLines: 4,
                    maxLines: 9,
                    decoration: const InputDecoration(
                      labelText: '수업 내용',
                      alignLabelWithHint: true,
                      hintText: '예: WARM UP\n스쿼트 10회 / 런지 10회 / 점핑잭 20회\n운동 5분, 휴식 없음, 1세트\n\nFMC\n운동 1분, 휴식 45초, 10세트',
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    key: const ValueKey('ai-slides-generate'),
                    onPressed:
                        !allowed ||
                            state.isLoading ||
                            prompt.text.trim().isEmpty
                        ? null
                        : () {
                            FocusScope.of(context).unfocus();
                            ref
                                .read(aiSlidesControllerProvider.notifier)
                                .generate(prompt.text);
                          },
                    icon: state.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(
                      state.isLoading
                          ? '슬라이드 구성 중…'
                          : result == null
                          ? '초안 만들기'
                          : '다시 만들기',
                    ),
                  ),
                  if (state.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        '창을 닫아도 요청은 처리될 수 있어요. 같은 내용으로 다시 요청하면 저장된 결과를 불러와요.',
                      ),
                    ),
                  if (state.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${state.error}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (result != null)
                    _ReviewSlides(key: ObjectKey(result), result: result),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewSlides extends HookWidget {
  const _ReviewSlides({super.key, required this.result});
  final AiSlidesResult result;
  @override
  Widget build(BuildContext context) {
    final drafts = useState(result.slides);
    final selected = useState({
      for (var i = 0; i < result.slides.length; i++) i,
    });
    final error = useState<String?>(null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          '${result.slides.length}장 미리보기',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        const Text('내용과 색상을 확인해 주세요. 타이머는 추가한 뒤 편집할 수 있어요.'),
        for (final warning in result.warnings)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('• $warning'),
          ),
        for (final (index, draft) in drafts.value.indexed)
          _SlideDraftCard(
            key: ValueKey('ai-slide-$index'),
            index: index,
            draft: draft,
            selected: selected.value.contains(index),
            onSelected: (value) => selected.value = {...selected.value}
              ..removeWhere((i) => !value && i == index)
              ..addAll(value ? [index] : []),
            onChanged: (value) {
              final next = [...drafts.value];
              next[index] = value;
              drafts.value = next;
              error.value = null;
            },
          ),
        const SizedBox(height: 16),
        if (error.value != null)
          Text(
            error.value!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        FilledButton(
          key: const ValueKey('ai-slides-add'),
          onPressed: selected.value.isEmpty
              ? null
              : () {
                  try {
                    final stamp = DateTime.now().microsecondsSinceEpoch;
                    final modules = [
                      for (final (i, draft) in drafts.value.indexed)
                        if (selected.value.contains(i))
                          confirmAiSlide(draft, 'ai-$stamp-$i'),
                    ];
                    Navigator.pop(context, modules);
                  } on AiSlidesFailure catch (e) {
                    error.value = e.message;
                  }
                },
          child: Text('선택한 ${selected.value.length}장 추가'),
        ),
        const SizedBox(height: 8),
        const Text(
          '워크아웃 초안에 추가돼요. 워크아웃을 저장하면 반영됩니다.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SlideDraftCard extends HookWidget {
  const _SlideDraftCard({
    super.key,
    required this.index,
    required this.draft,
    required this.selected,
    required this.onSelected,
    required this.onChanged,
  });
  final int index;
  final AiSlideDraft draft;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final ValueChanged<AiSlideDraft> onChanged;
  @override
  Widget build(BuildContext context) {
    final title = useTextEditingController(text: draft.title);
    final text = useTextEditingController(text: draft.lines.join('\n'));
    final preview = WorkoutModule.empty('preview').copyWith(
      name: draft.title,
      text: draft.lines.join('\n'),
      designTemplate: 'stationd-v1-${draft.layout}',
      designBackgroundColor: draft.designBackgroundColor,
      designTextColor: draft.designTextColor,
      designAccentColor: draft.designAccentColor,
      workSeconds: draft.workSeconds ?? 0,
      restSeconds: draft.restSeconds ?? 0,
      sets: draft.sets ?? 0,
    );
    return Card(
      margin: const EdgeInsets.only(top: 18),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('슬라이드 ${index + 1}'),
              value: selected,
              onChanged: (value) => onSelected(value ?? false),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CustomPaint(painter: SlideDesignPainter(preview)),
              ),
            ),
            const SizedBox(height: 12),
            SlideDesignColors(
              module: preview,
              onChanged: (value) => onChanged(
                draft.copyWith(
                  designBackgroundColor: value.designBackgroundColor,
                  designTextColor: value.designTextColor,
                  designAccentColor: value.designAccentColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: preview.designTemplate,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '배치'),
              items: [
                for (final entry in slideDesigns.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) {
                if (value != null) {
                  onChanged(
                    draft.copyWith(
                      layout: value.replaceFirst('stationd-v1-', ''),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: title,
              maxLength: 60,
              decoration: const InputDecoration(labelText: '제목'),
              onChanged: (value) => onChanged(draft.copyWith(title: value)),
            ),
            TextField(
              controller: text,
              minLines: 2,
              maxLines: 8,
              maxLength: slideDesignMaxTextLength,
              decoration: const InputDecoration(
                labelText: '운동 목록',
                helperText: '최대 24줄 · 긴 내용은 한 장 안에서 여러 열로 배치',
                helperMaxLines: 2,
              ),
              onChanged: (value) =>
                  onChanged(draft.copyWith(lines: slideDesignLines(value))),
            ),
          ],
        ),
      ),
    );
  }
}
