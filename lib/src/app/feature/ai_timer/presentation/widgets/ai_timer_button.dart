import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

import 'package:cloud_board/src/app/feature/ai_timer/domain/entities/ai_timer_result.dart';
import 'package:cloud_board/src/app/feature/ai_timer/domain/usecases/ai_timer_actions.dart';
import 'package:cloud_board/src/app/feature/ai_timer/presentation/controllers/ai_timer_controller.dart';

class AiTimerButton extends StatelessWidget {
  const AiTimerButton({super.key, required this.module, required this.onApply});
  final WorkoutModule module;
  final bool Function(WorkoutModule) onApply;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        key: const ValueKey('ai-timer-button'),
        onPressed: module.imageSource.isEmpty
            ? null
            : () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  showDragHandle: true,
                  constraints: const BoxConstraints(maxWidth: 640),
                  builder: (_) =>
                      _AiTimerSheet(module: module, onApply: onApply),
                );
              },
        icon: const Icon(Icons.auto_awesome_outlined, size: 18),
        label: const Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            Text('AI로 타이머 만들기'),
            Text('프리미엄', style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
      if (module.imageSource.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            '배경 이미지를 추가하면 시간과 세트를 읽을 수 있어요.',
            style: TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
    ],
  );
}

class _AiTimerSheet extends HookConsumerWidget {
  const _AiTimerSheet({required this.module, required this.onApply});
  final WorkoutModule module;
  final bool Function(WorkoutModule) onApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(aiTimerAccessProvider);
    final analysis = ref.watch(aiTimerControllerProvider);
    ref.listen(aiTimerControllerProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.error is AiTimerFailure
                  ? next.error.toString()
                  : '이미지를 분석하지 못했습니다. 다시 시도해 주세요.',
            ),
          ),
        );
      }
    });
    Widget body;
    if (analysis.isLoading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(height: 16),
            Text('이미지에서 시간과 세트를 읽고 있어요'),
            SizedBox(height: 8),
            Text('잠시만 기다려 주세요.', style: TextStyle(fontSize: 12)),
          ],
        ),
      );
    } else if (analysis.value != null && !analysis.hasError) {
      body = _AiTimerReview(
        suggestion: analysis.value!,
        module: module,
        onApply: onApply,
      );
    } else {
      body = access.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (error, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              error is AiTimerFailure
                  ? error.message
                  : '이용 권한을 확인하지 못했습니다. 연결을 확인해 주세요.',
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => ref.invalidate(aiTimerAccessProvider),
              child: const Text('다시 확인'),
            ),
          ],
        ),
        data: (value) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              !value.premium
                  ? '프리미엄 전용 기능이에요.'
                  : !value.enabled
                  ? 'AI 기능을 준비 중이에요. 타이머는 직접 설정할 수 있어요.'
                  : '선택한 이미지를 OpenAI로 분석해 운동 시간, 휴식, 세트를 읽어요. 결과를 확인한 뒤 적용해 주세요.',
            ),
            const SizedBox(height: 12),
            if (value.premium && value.enabled) ...[
              Text(
                '이번 달 ${value.remaining}/${value.limit}회 남음 · 매월 1일 초기화',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                value.remaining == 0
                    ? '이미 분석한 이미지는 남은 횟수 없이 다시 확인할 수 있어요.'
                    : '같은 이미지의 저장된 결과는 횟수를 차감하지 않아요.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 20),
            if (!value.premium)
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/subscription');
                },
                child: const Text('내 구독 확인'),
              )
            else
              FilledButton.icon(
                key: const ValueKey('ai-timer-analyze'),
                onPressed: value.enabled
                    ? () => ref
                          .read(aiTimerControllerProvider.notifier)
                          .recognize(module.imageSource)
                    : null,
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: const Text('이미지 분석'),
              ),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .82,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'AI로 타이머 만들기',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              body,
            ],
          ),
        ),
      ),
    );
  }
}

class _AiTimerReview extends HookWidget {
  const _AiTimerReview({
    required this.suggestion,
    required this.module,
    required this.onApply,
  });
  final AiTimerSuggestion suggestion;
  final WorkoutModule module;
  final bool Function(WorkoutModule) onApply;
  @override
  Widget build(BuildContext context) {
    final form = useMemoized(() => GlobalKey<FormState>());
    final work = useTextEditingController(
      text: suggestion.workSeconds?.toString() ?? '',
    );
    final rest = useTextEditingController(
      text: suggestion.restSeconds?.toString() ?? '',
    );
    final sets = useTextEditingController(
      text: suggestion.sets?.toString() ?? '',
    );
    final name = useTextEditingController(text: suggestion.name ?? '');
    final applyName = useState(false);
    final stale = useState(false);
    Widget number(
      String label,
      String key,
      TextEditingController controller,
      int min,
      int max,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: ValueKey(key),
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          hintText: '확인 필요 · 직접 입력',
          helperText: controller.text.isEmpty ? '이미지에서 확실하게 읽지 못했어요.' : null,
        ),
        validator: (value) {
          final parsed = int.tryParse(value ?? '');
          return parsed == null || parsed < min || parsed > max
              ? '$min~$max 사이의 값을 입력해 주세요.'
              : null;
        },
      ),
    );
    return Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            suggestion.cached
                ? '이전에 읽은 결과예요. 추가 횟수는 사용하지 않았어요.'
                : '이렇게 읽었어요. 필요한 값은 수정해 주세요.',
          ),
          const SizedBox(height: 8),
          Text(
            '이번 달 ${suggestion.remaining}회 남음',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          for (final warning in suggestion.warnings)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('확인 필요 · $warning'),
            ),
          if (module.intervalBlocks.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '적용하면 기존 ${module.intervalBlocks.length}개 타이머 블록을 하나의 반복 타이머로 교체해요.',
              ),
            ),
          const SizedBox(height: 20),
          number('운동 시간 (초)', 'ai-timer-work', work, 1, 3600),
          number('휴식 시간 (초)', 'ai-timer-rest', rest, 0, 3600),
          number('세트', 'ai-timer-sets', sets, 1, 100),
          if (suggestion.name?.isNotEmpty == true) ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('읽은 운동명을 슬라이드 제목에 적용'),
              value: applyName.value,
              onChanged: (v) => applyName.value = v ?? false,
            ),
            if (applyName.value)
              TextFormField(
                controller: name,
                maxLength: 120,
                decoration: const InputDecoration(labelText: '슬라이드 제목'),
                validator: (v) =>
                    v?.trim().isEmpty != false ? '제목을 입력해 주세요.' : null,
              ),
          ],
          if (stale.value) const Text('분석 중 슬라이드가 변경됐어요. 닫은 뒤 다시 분석해 주세요.'),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('ai-timer-apply'),
            onPressed: stale.value
                ? null
                : () {
                    if (form.currentState?.validate() != true) return;
                    final next = applyAiTimer(
                      module,
                      workSeconds: int.parse(work.text),
                      restSeconds: int.parse(rest.text),
                      sets: int.parse(sets.text),
                      name: applyName.value ? name.text : null,
                    );
                    if (onApply(next)) {
                      Navigator.pop(context);
                    } else {
                      stale.value = true;
                    }
                  },
            child: const Text('타이머 적용'),
          ),
          const SizedBox(height: 8),
          const Text(
            '적용 후 슬라이드의 저장 버튼을 눌러 주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
