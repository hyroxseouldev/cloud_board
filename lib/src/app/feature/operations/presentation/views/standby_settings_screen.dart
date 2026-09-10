import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_board/src/app/core/widgets/unsaved_changes_guard.dart';

import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/domain/standby_rotation.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/store_operations_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image.dart';

class StandbySettingsScreen extends ConsumerWidget {
  const StandbySettingsScreen({super.key, required this.guard});
  final ExitGuard guard;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(brandTemplateProvider)
      .when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: const Text('스탠바이 설정')),
          body: Center(child: Text('설정을 불러오지 못했습니다: $e')),
        ),
        data: (brand) => _StandbyEditor(initial: brand, guard: guard),
      );
}

class _StandbyEditor extends HookConsumerWidget {
  const _StandbyEditor({required this.initial, required this.guard});
  final BrandTemplate initial;
  final ExitGuard guard;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = useState(initial);
    final keys = useState(
      List.generate(initial.promotionImageUrls.length, (_) => UniqueKey()),
    );
    final minutes = useState(
      List.generate(
        initial.promotionImageUrls.length,
        (i) => '${standbyMinutes(initial, i)}',
      ),
    );
    final dirty = useState(false);
    final busy = useState(false);
    final error = useState<String?>(null);
    final form = useMemoized(() => GlobalKey<FormState>());
    Future<void> add() async {
      try {
        final files = await ImagePicker().pickMultiImage(
          maxWidth: 1920,
          imageQuality: 85,
        );
        final sources = <String>[];
        for (final file in files) {
          sources.add(
            WorkoutImageSource.fromBytes(
              await file.readAsBytes(),
              contentType: file.mimeType,
            ),
          );
        }
        if (!context.mounted || sources.isEmpty) return;
        draft.value = draft.value.copyWith(
          promotionImageUrls: [...draft.value.promotionImageUrls, ...sources],
        );
        keys.value = [...keys.value, ...sources.map((_) => UniqueKey())];
        minutes.value = [...minutes.value, ...sources.map((_) => '1')];
        dirty.value = true;
      } catch (e) {
        if (context.mounted) error.value = '이미지를 불러오지 못했습니다: $e';
      }
    }

    Future<void> save() async {
      if (!form.currentState!.validate()) return;
      busy.value = true;
      error.value = null;
      // Only update fields owned by this page, preserving other brand edits.
      final latest = ref.read(brandTemplateProvider).value ?? initial;
      final success = await ref
          .read(storeOperationsActionControllerProvider.notifier)
          .saveBrandTemplate(
            latest.copyWith(
              promotionImageUrls: draft.value.promotionImageUrls,
              promotionDurationMinutes: minutes.value.map(int.parse).toList(),
              standbyTransition: draft.value.standbyTransition,
            ),
          );
      if (!context.mounted) return;
      busy.value = false;
      if (!success) {
        error.value = '저장하지 못했습니다. 변경사항은 유지됩니다. 연결을 확인하고 다시 저장해 주세요.';
        return;
      }
      dirty.value = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/operations');
          }
        }
      });
    }

    return UnsavedChangesGuard(
      guard: guard,
      dirty: dirty.value,
      blocked: busy.value,
      child: Scaffold(
        appBar: AppBar(title: const Text('스탠바이 설정')),
        body: AbsorbPointer(
          absorbing: busy.value,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Form(
                key: form,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Text(
                      '등록 순서대로 반복 재생합니다. 이미지가 없거나 모두 불러올 수 없으면 기본 대기 화면을 표시합니다.',
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<StandbyTransition>(
                      initialValue: draft.value.standbyTransition,
                      decoration: const InputDecoration(labelText: '전환 효과'),
                      items: const [
                        DropdownMenuItem(
                          value: StandbyTransition.none,
                          child: Text('없음'),
                        ),
                        DropdownMenuItem(
                          value: StandbyTransition.fade,
                          child: Text('페이드'),
                        ),
                        DropdownMenuItem(
                          value: StandbyTransition.slide,
                          child: Text('슬라이드'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          draft.value = draft.value.copyWith(
                            standbyTransition: v,
                          );
                          dirty.value = true;
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: keys.value.length,
                      onReorderItem: (oldIndex, newIndex) {
                        final images = [...draft.value.promotionImageUrls];
                        final times = [...minutes.value];
                        final ids = [...keys.value];
                        images.insert(newIndex, images.removeAt(oldIndex));
                        times.insert(newIndex, times.removeAt(oldIndex));
                        ids.insert(newIndex, ids.removeAt(oldIndex));
                        draft.value = draft.value.copyWith(
                          promotionImageUrls: images,
                        );
                        minutes.value = times;
                        keys.value = ids;
                        dirty.value = true;
                      },
                      itemBuilder: (context, i) => Card(
                        key: keys.value[i],
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  ReorderableDragStartListener(
                                    index: i,
                                    child: const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Icon(Icons.drag_handle),
                                    ),
                                  ),
                                  Expanded(child: Text('이미지 ${i + 1}')),
                                  IconButton(
                                    tooltip: '이미지 삭제',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () {
                                      final images = [
                                        ...draft.value.promotionImageUrls,
                                      ]..removeAt(i);
                                      draft.value = draft.value.copyWith(
                                        promotionImageUrls: images,
                                      );
                                      minutes.value = [...minutes.value]
                                        ..removeAt(i);
                                      keys.value = [...keys.value]..removeAt(i);
                                      dirty.value = true;
                                    },
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: 150,
                                width: double.infinity,
                                child: WorkoutImage(
                                  source: draft.value.promotionImageUrls[i],
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                initialValue: minutes.value[i],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '표시 시간 (분)',
                                  suffixText: '분',
                                ),
                                validator: (v) {
                                  final n = int.tryParse(v ?? '');
                                  return n != null && n >= 1 && n <= 1440
                                      ? null
                                      : '1~1440분으로 입력해 주세요.';
                                },
                                onChanged: (v) {
                                  final times = [...minutes.value];
                                  times[i] = v;
                                  minutes.value = times;
                                  dirty.value = true;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy.value ? null : add,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('이미지 추가'),
                    ),
                    if (error.value != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          error.value!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: busy.value ? null : save,
                      icon: busy.value
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        busy.value
                            ? '저장 중…'
                            : error.value == null
                            ? '저장'
                            : '다시 저장',
                      ),
                    ),
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
