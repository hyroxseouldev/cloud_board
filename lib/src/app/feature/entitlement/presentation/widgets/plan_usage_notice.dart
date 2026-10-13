import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:cloud_board/src/app/core/observability/operation_telemetry.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/feature/entitlement/domain/plan_limit_failure.dart';
import 'package:cloud_board/src/app/feature/entitlement/presentation/controllers/entitlement_controller.dart';
import 'package:cloud_board/src/app/feature/entitlement/presentation/controllers/plan_usage_controller.dart';

class PlanUsageNotice extends HookConsumerWidget {
  const PlanUsageNotice({
    super.key,
    this.resource = 'workouts',
    this.compact = false,
  });
  final String resource;
  // Open the full notice from an existing toolbar on constrained viewports.
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(planAccessProvider);
    final usage = ref.watch(planUsageProvider);
    final access = policy.value;
    final known = access?.policyKnown == true;
    final count = resource == 'workouts'
        ? usage.value?.workoutCount
        : usage.value?.savedSlideCount;
    final limit = resource == 'workouts'
        ? access?.maxWorkouts
        : access?.maxSavedSlides;
    final name = resource == 'workouts' ? '저장 수업' : '재사용 저장 슬라이드';
    final total = known ? limit?.toString() ?? '무제한' : '확인 중';
    final over = known && count != null && limit != null && count >= limit;
    final exposed = useRef(<String>{});
    useEffect(() {
      if (!compact && known && count != null && exposed.value.add(resource)) {
        ref
            .read(operationTelemetryProvider)
            .start('plan.$resource.usage')
            .success();
      }
      return null;
    }, [known, count, resource, compact]);
    if (compact) {
      final container = ProviderScope.containerOf(context, listen: false);
      return IconButton(
        tooltip: '$name ${count ?? '—'} / $total · 사용량 안내',
        onPressed: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => UncontrolledProviderScope(
            container: container,
            child: AlertDialog(
              title: const Text('보관 사용량'),
              content: SingleChildScrollView(
                child: PlanUsageNotice(resource: resource),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('닫기'),
                ),
              ],
            ),
          ),
        ),
        icon: Icon(
          over || usage.hasError || policy.hasError
              ? Icons.info_rounded
              : Icons.pie_chart_outline_rounded,
          semanticLabel: '$name ${count ?? '—'} / $total · 사용량 안내',
        ),
      );
    }
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$name ${count ?? '—'} / $total',
              key: ValueKey('plan-usage-$resource'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              resource == 'workouts'
                  ? '현재 보관한 수업 수입니다. 삭제하면 새 수업을 저장할 수 있어요.'
                  : '수업 안의 슬라이드는 이 한도를 사용하지 않습니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (usage.hasError || policy.hasError)
              TextButton(
                onPressed: () {
                  ref.invalidate(planUsageProvider);
                  ref.invalidate(planAccessProvider);
                },
                child: const Text('사용량 다시 확인'),
              ),
            if (over) ...[
              const SizedBox(height: 6),
              const Text(
                '기존 자료의 편집·재생·삭제는 계속 가능합니다. 새 자료를 저장하려면 기존 자료를 정리해 주세요.',
              ),
              TextButton(
                onPressed: () {
                  ref
                      .read(operationTelemetryProvider)
                      .start('plan.$resource.upgrade')
                      .success();
                  context.push('/subscription');
                },
                child: const Text('Plus 알아보기'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> showPlanLimitNotice(
  BuildContext context,
  PlanLimitFailure failure,
) async {
  final telemetry = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(operationTelemetryProvider);
  final attempt = telemetry.start('plan.${failure.resource}.limit');
  final choice = await showDialog<String>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(
        failure.resource == 'workouts'
            ? '수업 저장 한도에 도달했어요'
            : '슬라이드 저장 한도에 도달했어요',
      ),
      content: Text('${failure.message}\n\n기존 자료와 작성 중인 내용은 유지됩니다.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('계속 편집'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialog, 'manage'),
          child: Text(failure.resource == 'workouts' ? '수업 관리하기' : '슬라이드 관리하기'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialog, 'upgrade'),
          child: const Text('Plus 알아보기'),
        ),
      ],
    ),
  );
  if (choice == null) {
    attempt.cancel();
  } else {
    attempt.success();
    telemetry.start('plan.${failure.resource}.$choice').success();
  }
  if (!context.mounted) return;
  // Push preserves the editor and its unsaved draft through pricing/cancel/back.
  if (choice == 'upgrade') {
    await context.push('/subscription');
  } else if (choice == 'manage') {
    await context.push(failure.resource == 'workouts' ? '/' : '/slides');
  }
}

Future<bool> allowPlanAddition(
  BuildContext context,
  WidgetRef ref,
  String resource,
) async {
  final access = ref.read(planAccessProvider).value;
  final usage = ref.read(planUsageProvider).value;
  // Cached or unavailable counters are advisory; only the server can refuse.
  if (access?.policyKnown != true ||
      access?.serverConfirmed != true ||
      usage?.serverConfirmed != true) {
    return true;
  }
  final limit = resource == 'workouts'
      ? access!.maxWorkouts
      : access!.maxSavedSlides;
  final used = resource == 'workouts'
      ? usage!.workoutCount
      : usage!.savedSlideCount;
  if (limit == null || used < limit) return true;
  await showPlanLimitNotice(
    context,
    PlanLimitFailure(resource: resource, limit: limit, used: used),
  );
  return false;
}
