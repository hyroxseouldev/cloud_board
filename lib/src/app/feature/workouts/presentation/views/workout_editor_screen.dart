import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cloud_board/src/app/core/theme/app_theme.dart';
import 'package:cloud_board/src/app/core/widgets/async_action_overlay.dart';
import 'package:cloud_board/src/app/feature/auth/presentation/controllers/auth_controller.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_image_source.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_image.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/workout_preflight_dialog.dart';

const _timerColors = <_TimerColorOption>[
  _TimerColorOption('기본', null),
  _TimerColorOption('흰색', 0xFFFFFFFF),
  _TimerColorOption('파랑', 0xFF0B4DFF),
  _TimerColorOption('초록', 0xFF34C759),
  _TimerColorOption('노랑', 0xFFFFCC00),
  _TimerColorOption('주황', 0xFFFF9500),
  _TimerColorOption('빨강', 0xFFFF3B30),
  _TimerColorOption('보라', 0xFFAF52DE),
];

class _TimerColorOption {
  const _TimerColorOption(this.label, this.value);

  final String label;
  final int? value;
}

class WorkoutEditorScreen extends ConsumerWidget {
  const WorkoutEditorScreen({super.key, required this.workoutId});
  final String workoutId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = ref.watch(workoutControllerProvider);
    final user = ref.watch(authStateProvider).value;
    return values.when(
      data: (items) {
        final workout = workoutId == 'new' && user != null
            ? Workout.empty(
                newId(),
                WorkoutAuthor(
                  id: user.id,
                  displayName: user.displayName,
                  photoUrl: user.photoUrl,
                ),
              )
            : items.where((item) => item.id == workoutId).firstOrNull;
        return workout == null
            ? const Scaffold(body: Center(child: Text('워크아웃을 찾을 수 없습니다.')))
            : _EditorBody(initial: workout, isNew: workoutId == 'new');
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
    );
  }
}

class _EditorBody extends HookConsumerWidget {
  const _EditorBody({required this.initial, required this.isNew});
  final Workout initial;
  final bool isNew;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = useState(initial);
    final savedBaseline = useState(initial);
    final name = useTextEditingController(text: initial.name);
    final folder = useTextEditingController(text: initial.folder);
    final brandL = useTextEditingController(text: initial.brandL);
    final brandR = useTextEditingController(text: initial.brandR);
    useListenable(name);
    useListenable(folder);
    useListenable(brandL);
    useListenable(brandR);
    final action = ref.watch(workoutActionControllerProvider);
    final playbackAction = ref.watch(playbackActionControllerProvider);
    final isBusy = action.isLoading || playbackAction.isLoading;
    final hasUnsavedChanges =
        draft.value != savedBaseline.value ||
        name.text.trim() != savedBaseline.value.name ||
        folder.text.trim() != savedBaseline.value.folder ||
        brandL.text.trim() != savedBaseline.value.brandL ||
        brandR.text.trim() != savedBaseline.value.brandR;

    Future<Workout?> persist() async {
      if (name.text.trim().isEmpty) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('워크아웃 이름이 필요합니다'),
            content: const Text('매장에서 구분할 수 있는 이름을 입력해 주세요.'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
        );
        return null;
      }
      final value = draft.value.copyWith(
        name: name.text.trim(),
        folder: folder.text.trim(),
        brandL: brandL.text.trim(),
        brandR: brandR.text.trim(),
      );
      final saved = await ref
          .read(workoutActionControllerProvider.notifier)
          .save(value);
      if (saved != null) {
        draft.value = saved;
        savedBaseline.value = saved;
      }
      return saved;
    }

    useEffect(() {
      if (isNew || !hasUnsavedChanges || isBusy) return null;
      final timer = Timer(const Duration(milliseconds: 1200), persist);
      return timer.cancel;
    }, [draft.value, name.text, folder.text, brandL.text, brandR.text, isBusy]);

    Future<bool> confirmExit() async {
      if (!hasUnsavedChanges) return true;
      return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('변경사항을 저장할까요?'),
              content: const Text('저장하지 않고 나가면 방금 수정한 내용이 사라집니다.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('저장 안 함'),
                ),
                FilledButton(
                  onPressed: () async {
                    final saved = await persist();
                    if (context.mounted) {
                      Navigator.of(context).pop(saved != null);
                    }
                  },
                  child: const Text('저장 후 나가기'),
                ),
              ],
            ),
          ) ??
          false;
    }

    Future<void> requestBack() async {
      if (await confirmExit() && context.mounted) context.pop();
    }

    Future<void> saveAndClose() async {
      final saved = await persist();
      if (saved == null || !context.mounted) return;
      if (isNew) {
        context.go('/');
      } else {
        context.pop();
      }
    }

    Future<void> saveAndPlay({int? start}) async {
      final saved = await persist();
      if (saved == null || !context.mounted) return;
      final selection = await showWorkoutPreflight(context, saved);
      if (selection == null || !context.mounted) return;
      final stepIndex = playerStepIndexForModule(saved, start ?? 0);
      final steps = buildPlayerSteps(saved);
      if (steps.isEmpty) return;
      final sessionId = await ref
          .read(playbackActionControllerProvider.notifier)
          .start(
            workout: saved,
            zoneId: selection.zoneId,
            stepIndex: stepIndex,
            durationMs: steps[stepIndex].duration * 1000,
          );
      if (sessionId == null || !context.mounted) return;
      final query = start == null ? '' : '?start=$start';
      final separator = query.isEmpty ? '?' : '&';
      context.go('/player/${saved.id}$query${separator}session=$sessionId');
    }

    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(requestBack());
      },
      child: AsyncActionOverlay(
        isLoading: isBusy,
        child: Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: isBusy ? null : requestBack),
            title: Text(
              isNew
                  ? '새 워크아웃'
                  : initial.name.isEmpty
                  ? '워크아웃'
                  : initial.name,
            ),
            actions: [
              Center(
                child: Text(
                  action.isLoading
                      ? '저장 중…'
                      : hasUnsavedChanges
                      ? '저장 필요'
                      : '저장됨',
                  style: TextStyle(
                    color: hasUnsavedChanges ? Colors.orange : XonColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.icon(
                  onPressed: draft.value.modules.isEmpty || isBusy
                      ? null
                      : saveAndPlay,
                  icon: isBusy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Text('재생'),
                ),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 90),
                children: [
                  _TextField(
                    label: '워크아웃 이름',
                    controller: name,
                    hint: '예: 9/4 금 하이록스',
                  ),
                  _TextField(label: '폴더', controller: folder, hint: '예: 잠실'),
                  _TextField(label: '화면 왼쪽 아래 문구', controller: brandL),
                  _TextField(label: '화면 오른쪽 아래 문구', controller: brandR),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        '슬라이드',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: XonColors.muted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        durationLabel(workoutDuration(draft.value)),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: draft.value.modules.length,
                    onReorderItem: (oldIndex, newIndex) {
                      final list = [...draft.value.modules];
                      final item = list.removeAt(oldIndex);
                      list.insert(newIndex, item);
                      draft.value = draft.value.copyWith(modules: list);
                    },
                    proxyDecorator: (child, index, animation) => Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(9),
                      child: child,
                    ),
                    itemBuilder: (context, index) {
                      final module = draft.value.modules[index];
                      return _ModuleEditor(
                        key: ValueKey(module.id),
                        module: module,
                        index: index,
                        onChange: (module) {
                          final list = [...draft.value.modules];
                          list[index] = module;
                          draft.value = draft.value.copyWith(modules: list);
                        },
                        onRemove: () {
                          final list = [...draft.value.modules]
                            ..removeAt(index);
                          draft.value = draft.value.copyWith(modules: list);
                        },
                        onMove: (amount) {
                          final target = index + amount;
                          if (target < 0 ||
                              target >= draft.value.modules.length) {
                            return;
                          }
                          final list = [...draft.value.modules];
                          final item = list.removeAt(index);
                          list.insert(target, item);
                          draft.value = draft.value.copyWith(modules: list);
                        },
                        onPlay: () async {
                          await saveAndPlay(start: index);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => draft.value = draft.value.copyWith(
                          modules: [
                            ...draft.value.modules,
                            WorkoutModule.empty(newId()),
                          ],
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('슬라이드 추가'),
                      ),
                      OutlinedButton(
                        onPressed: () => draft.value = draft.value.copyWith(
                          modules: [
                            ...draft.value.modules,
                            WorkoutModule.empty(newId()).copyWith(
                              name: '휴식',
                              workSeconds: 60,
                              text: '물 마시고 다음 스테이션으로',
                            ),
                          ],
                        ),
                        child: const Text('휴식 60초'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: isBusy ? null : saveAndClose,
                      icon: isBusy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(isBusy ? '처리 중...' : '저장'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.label,
    required this.controller,
    this.hint = '',
  });
  final String label, hint;
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: XonColors.muted,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    ),
  );
}

class _ModuleEditor extends HookWidget {
  const _ModuleEditor({
    super.key,
    required this.module,
    required this.index,
    required this.onChange,
    required this.onRemove,
    required this.onMove,
    required this.onPlay,
  });
  final WorkoutModule module;
  final int index;
  final ValueChanged<WorkoutModule> onChange;
  final VoidCallback onRemove, onPlay;
  final ValueChanged<int> onMove;
  @override
  Widget build(BuildContext context) {
    final open = useState(index == 0);
    final name = useTextEditingController(text: module.name);
    final text = useTextEditingController(text: module.text);
    final isPickingImage = useState(false);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: open.value ? XonColors.black : XonColors.line,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => open.value = !open.value,
            leading: CircleAvatar(
              backgroundColor: XonColors.black,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            title: Text(
              module.name.isEmpty ? '이름 없음' : module.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${module.sets}세트 · ${durationLabel(module.workSeconds)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(open.value ? Icons.expand_less : Icons.expand_more),
                const SizedBox(width: 6),
                Tooltip(
                  message: '드래그해서 순서 변경',
                  child: ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.drag_handle),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (open.value)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  _TextField(label: '슬라이드 이름', controller: name),
                  Row(
                    children: [
                      _NumberField(
                        label: '시간(초) · ±30',
                        value: module.workSeconds,
                        min: 1,
                        step: 30,
                        onChanged: (value) =>
                            onChange(module.copyWith(workSeconds: value)),
                      ),
                      const SizedBox(width: 8),
                      _NumberField(
                        label: '세트',
                        value: module.sets,
                        min: 1,
                        onChanged: (value) =>
                            onChange(module.copyWith(sets: value)),
                      ),
                      const SizedBox(width: 8),
                      _NumberField(
                        label: '휴식(초) · ±30',
                        value: module.restSeconds,
                        min: 0,
                        step: 30,
                        onChanged: (value) =>
                            onChange(module.copyWith(restSeconds: value)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '화면 텍스트',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: XonColors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: text,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: '운동 설명을 줄바꿈으로 입력하세요',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      FilterChip(
                        label: const Text('타이머 표시'),
                        selected: module.showTimer,
                        onSelected: (value) =>
                            onChange(module.copyWith(showTimer: value)),
                      ),
                      FilterChip(
                        label: const Text('비프음'),
                        selected: module.beep,
                        onSelected: (value) =>
                            onChange(module.copyWith(beep: value)),
                      ),
                      FilterChip(
                        label: const Text('이미지 꽉 채우기'),
                        selected: module.coverImage,
                        onSelected: (value) =>
                            onChange(module.copyWith(coverImage: value)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '타이머 색상',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: XonColors.muted,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: _timerColors
                        .map(
                          (option) => ChoiceChip(
                            avatar: option.value == null
                                ? const Icon(Icons.auto_awesome, size: 16)
                                : Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Color(option.value!),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: XonColors.line),
                                    ),
                                  ),
                            label: Text(option.label),
                            selected: module.timerColorValue == option.value,
                            onSelected: (_) => onChange(
                              module.copyWith(timerColorValue: option.value),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: isPickingImage.value
                            ? null
                            : () async {
                                isPickingImage.value = true;
                                try {
                                  final file = await ImagePicker().pickImage(
                                    source: ImageSource.gallery,
                                    maxWidth: 1920,
                                    imageQuality: 85,
                                  );
                                  if (file == null) return;
                                  final bytes = await file.readAsBytes();
                                  onChange(
                                    module.copyWith(
                                      imageSource: WorkoutImageSource.fromBytes(
                                        bytes,
                                        contentType: file.mimeType,
                                      ),
                                    ),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('배경 이미지를 선택했습니다.'),
                                      ),
                                    );
                                  }
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '이미지를 불러오지 못했습니다: $error',
                                        ),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (context.mounted) {
                                    isPickingImage.value = false;
                                  }
                                }
                              },
                        icon: isPickingImage.value
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.image_outlined),
                        label: Text(
                          isPickingImage.value
                              ? '불러오는 중...'
                              : module.imageSource.isEmpty
                              ? '배경 이미지'
                              : '이미지 변경',
                        ),
                      ),
                      if (module.imageSource.isNotEmpty)
                        IconButton(
                          onPressed: () =>
                              onChange(module.copyWith(imageSource: '')),
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                  if (module.imageSource.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ColoredBox(
                          color: Colors.black,
                          child: WorkoutImage(
                            source: module.imageSource,
                            fit: module.coverImage
                                ? BoxFit.cover
                                : BoxFit.contain,
                            showLoadingIndicator: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '슬라이드 이미지 미리보기',
                      style: TextStyle(fontSize: 12, color: XonColors.muted),
                    ),
                  ],
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton(
                        onPressed: () => onMove(-1),
                        child: const Text('↑ 위로'),
                      ),
                      TextButton(
                        onPressed: () => onMove(1),
                        child: const Text('↓ 아래로'),
                      ),
                      TextButton(
                        onPressed: () {
                          onChange(
                            module.copyWith(name: name.text, text: text.text),
                          );
                          onPlay();
                        },
                        child: const Text('이 슬라이드부터 재생'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        onPressed: onRemove,
                        child: const Text('삭제'),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => onChange(
                      module.copyWith(name: name.text, text: text.text),
                    ),
                    child: const Text('슬라이드 변경 적용'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NumberField extends HookWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.min,
    required this.onChanged,
    this.step = 1,
  });
  final String label;
  final int value, min, step;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: '$value');
    useEffect(() {
      if (controller.text != '$value') {
        controller.value = TextEditingValue(
          text: '$value',
          selection: TextSelection.collapsed(offset: '$value'.length),
        );
      }
      return null;
    }, [value]);

    void commit(String input) {
      final parsed = int.tryParse(input);
      if (parsed != null) onChanged(parsed.clamp(min, 9999));
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: XonColors.muted,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              IconButton(
                tooltip: '$step 감소',
                onPressed: () => onChanged((value - step).clamp(min, 9999)),
                icon: const Icon(Icons.remove),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  onChanged: commit,
                  onSubmitted: commit,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              IconButton(
                tooltip: '$step 증가',
                onPressed: () => onChanged((value + step).clamp(min, 9999)),
                icon: const Icon(Icons.add),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
