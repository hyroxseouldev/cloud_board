import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_templates_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/slide_editor_style.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';

/// Reads the same account-scoped collection used by the home library.
class SlideLibraryPicker extends HookConsumerWidget {
  const SlideLibraryPicker({
    super.key,
    required this.scope,
    required this.onSelect,
  });
  final String scope;
  final ValueChanged<WorkoutModule> onSelect;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = useTextEditingController();
    useListenable(search);
    final favorites = useState(false);
    final provider = slideTemplatesControllerProvider(scope);
    final templates = ref.watch(provider);
    final query = search.text.trim().toLowerCase();
    final all = templates.value ?? const <WorkoutModule>[];
    final items =
        all
            .where(
              (item) =>
                  (!favorites.value || item.favorite) &&
                  '${item.name} ${item.text} ${item.category}'
                      .toLowerCase()
                      .contains(query),
            )
            .toList()
          ..sort(
            (a, b) => a.favorite != b.favorite
                ? (a.favorite ? -1 : 1)
                : a.name.compareTo(b.name),
          );
    return CustomScrollView(
      key: const ValueKey('slide-library-picker'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '자주 쓰는 슬라이드',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  '홈 라이브러리와 같은 목록입니다. 선택 후 미리보기에서 현재 슬라이드를 교체할 수 있어요.',
                  style: TextStyle(fontSize: 12, color: SlideEditorStyle.muted),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: search,
                  decoration: const InputDecoration(
                    labelText: '슬라이드 검색',
                    hintText: '제목, 본문, 분류',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 8),
                FilterChip(
                  label: const Text('즐겨찾기'),
                  selected: favorites.value,
                  onSelected: (value) => favorites.value = value,
                ),
              ],
            ),
          ),
        ),
        if (templates.isLoading)
          const SliverToBoxAdapter(child: LinearProgressIndicator())
        else if (templates.hasError)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('라이브러리를 불러오지 못했습니다.'),
                  TextButton(
                    onPressed: () => ref.invalidate(provider),
                    child: const Text('다시 불러오기'),
                  ),
                ],
              ),
            ),
          )
        else if (items.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                all.isEmpty
                    ? '저장한 슬라이드가 없습니다. 워크아웃 편집의 슬라이드 메뉴에서 자주 쓰는 슬라이드로 저장해 주세요.'
                    : '조건에 맞는 슬라이드가 없습니다.',
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: SlideEditorStyle.surface,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: ValueKey('library-slide-${item.id}'),
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        onSelect(item);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 88,
                              child: WorkoutSlidePreview(
                                module: item,
                                isRest: false,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${durationLabel(workoutModuleDuration(item))}${item.category.isEmpty ? '' : ' · ${item.category}'}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: SlideEditorStyle.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (item.favorite)
                              const Icon(
                                Icons.star_rounded,
                                size: 18,
                                color: SlideEditorStyle.accent,
                              ),
                            const Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: SlideEditorStyle.accent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class SlideLibraryReplacementDialog extends HookWidget {
  const SlideLibraryReplacementDialog({
    super.key,
    required this.template,
    this.brandL = '',
    this.brandR = '',
  });
  final WorkoutModule template;
  final String brandL, brandR;
  @override
  Widget build(BuildContext context) {
    final rest = useState(false);
    return AppAlertDialog(
      title: const Text('현재 슬라이드를 교체할까요?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            template.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          WorkoutSlidePreview(
            module: template,
            isRest: rest.value,
            brandL: brandL,
            brandR: brandR,
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('운동')),
              ButtonSegment(value: true, label: Text('휴식')),
            ],
            selected: {rest.value},
            onSelectionChanged: (values) => rest.value = values.first,
          ),
          const SizedBox(height: 12),
          Text('전체 시간 ${durationLabel(workoutModuleDuration(template))}'),
          const SizedBox(height: 8),
          const Text(
            '현재 슬라이드의 제목·이미지·본문·시간·표시 옵션·전환음 설정이 교체됩니다. 워크아웃의 소리 종류와 볼륨은 유지됩니다.',
          ),
          const SizedBox(height: 8),
          const Text('교체 후 실행 취소로 되돌릴 수 있습니다.', style: TextStyle(fontSize: 12)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('현재 슬라이드 교체'),
        ),
      ],
    );
  }
}
