import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
import 'package:cloud_board/src/app/core/widgets/app_dropdown_form_field.dart';
import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/slide_templates_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_slide_preview.dart';

class SlideLibraryScreen extends HookConsumerWidget {
  const SlideLibraryScreen({super.key, this.onSelect});
  final ValueChanged<WorkoutModule>? onSelect;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = useTextEditingController();
    useListenable(search);
    final favorites = useState(false);
    final category = useState('');
    final scope = ref.watch(authStateProvider).value?.id;
    if (scope == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다.')));
    }
    final provider = slideTemplatesControllerProvider(scope);
    final templates = ref.watch(provider);
    final actions = ref.read(provider.notifier);
    final all = templates.value ?? const <WorkoutModule>[];
    final categories =
        all.map((m) => m.category).where((v) => v.isNotEmpty).toSet().toList()
          ..sort();
    final selectedCategory = categories.contains(category.value)
        ? category.value
        : '';
    final query = search.text.trim().toLowerCase();
    final items =
        all
            .where(
              (m) =>
                  (!favorites.value || m.favorite) &&
                  (selectedCategory.isEmpty ||
                      selectedCategory == m.category) &&
                  '${m.name} ${m.text} ${m.category}'.toLowerCase().contains(
                    query,
                  ),
            )
            .toList()
          ..sort(
            (a, b) => a.favorite != b.favorite
                ? (a.favorite ? -1 : 1)
                : a.name.compareTo(b.name),
          );
    Future<void> perform(Future<bool> Function() action) async {
      final success = await action();
      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('변경하지 못했습니다. 기존 슬라이드는 유지됩니다. 다시 시도해 주세요.'),
          ),
        );
      }
    }

    Future<void> edit(WorkoutModule module) async {
      final updated = await showDialog<WorkoutModule>(
        context: context,
        builder: (_) => _LibraryDetailsDialog(module: module),
      );
      if (updated != null) await perform(() => actions.updateTemplate(updated));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(onSelect == null ? '슬라이드 라이브러리' : '슬라이드 빠른 삽입'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(
                      controller: search,
                      decoration: const InputDecoration(
                        labelText: '슬라이드 검색',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppDropdownFormField<String>(
                            key: ValueKey(selectedCategory),
                            initialValue: selectedCategory,
                            decoration: const InputDecoration(labelText: '분류'),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('모든 분류'),
                              ),
                              ...categories.map(
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              ),
                            ],
                            onChanged: (v) => category.value = v ?? '',
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilterChip(
                          label: const Text('즐겨찾기'),
                          selected: favorites.value,
                          onSelected: (v) => favorites.value = v,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '이 계정으로 이 기기에 저장한 슬라이드입니다. 워크아웃 편집의 슬라이드 메뉴에서 추가할 수 있어요.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (templates.isLoading) const LinearProgressIndicator(),
              if (templates.hasError)
                TextButton(
                  onPressed: () => ref.invalidate(provider),
                  child: const Text('라이브러리 다시 불러오기'),
                ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          all.isEmpty ? '저장한 슬라이드가 없습니다.' : '검색 결과가 없습니다.',
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 100,
                                        child: WorkoutSlidePreview(
                                          module: item,
                                          isRest: false,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              item.category.isEmpty
                                                  ? '미분류'
                                                  : item.category,
                                              style: const TextStyle(
                                                color: AppColors.muted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: item.favorite
                                            ? '즐겨찾기 해제'
                                            : '즐겨찾기 추가',
                                        onPressed: templates.isLoading
                                            ? null
                                            : () => perform(
                                                () => actions.updateTemplate(
                                                  item.copyWith(
                                                    favorite: !item.favorite,
                                                  ),
                                                ),
                                              ),
                                        icon: Icon(
                                          item.favorite
                                              ? Icons.star
                                              : Icons.star_border,
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        enabled: !templates.isLoading,
                                        tooltip: '슬라이드 관리',
                                        onSelected: (v) async {
                                          if (v == 'edit') await edit(item);
                                          if (v == 'duplicate') {
                                            await perform(
                                              () => actions.save(
                                                item,
                                                '${item.name} 복사',
                                              ),
                                            );
                                          }
                                          if (v == 'remove' &&
                                              context.mounted) {
                                            final confirmed =
                                                await showDialog<bool>(
                                                  context: context,
                                                  builder: (c) =>
                                                      AppAlertDialog(
                                                        title: const Text(
                                                          '라이브러리에서 삭제할까요?',
                                                        ),
                                                        content: const Text(
                                                          '워크아웃에 이미 삽입한 슬라이드는 유지됩니다.',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  c,
                                                                  false,
                                                                ),
                                                            child: const Text(
                                                              '취소',
                                                            ),
                                                          ),
                                                          FilledButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  c,
                                                                  true,
                                                                ),
                                                            child: const Text(
                                                              '삭제',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                );
                                            if (confirmed == true) {
                                              await perform(
                                                () => actions.remove(item.id),
                                              );
                                            }
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Text('이름·분류 수정'),
                                          ),
                                          PopupMenuItem(
                                            value: 'duplicate',
                                            child: Text('복제'),
                                          ),
                                          PopupMenuItem(
                                            value: 'remove',
                                            child: Text('삭제'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (onSelect != null)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: templates.isLoading
                                            ? null
                                            : () => onSelect!(item),
                                        icon: const Icon(Icons.add),
                                        label: const Text('삽입'),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryDetailsDialog extends HookWidget {
  const _LibraryDetailsDialog({required this.module});
  final WorkoutModule module;
  @override
  Widget build(BuildContext context) {
    final name = useTextEditingController(text: module.name);
    final category = useTextEditingController(text: module.category);
    final form = useMemoized(() => GlobalKey<FormState>());
    return AppAlertDialog(
      title: const Text('슬라이드 이름·분류'),
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: name,
              maxLength: 60,
              decoration: const InputDecoration(labelText: '이름'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '이름을 입력해 주세요.' : null,
            ),
            TextFormField(
              controller: category,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: '분류',
                hintText: '예: 워밍업, 인터벌',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(
                context,
                module.copyWith(
                  name: name.text.trim(),
                  category: category.text.trim(),
                ),
              );
            }
          },
          child: const Text('수정'),
        ),
      ],
    );
  }
}
