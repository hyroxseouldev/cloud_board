import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/image_usage/data/image_usage_repository.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shadcn;

import 'package:cloud_board/src/app/feature/workouts/presentation/widgets/preparation_shadcn.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/usecases/workout_preferences_actions.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/display_preparation_controller.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_position.dart';

import 'dart:async';

import 'package:cloud_board/src/app/core/theme/app_colors.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_readiness.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/workout_error_message.dart';

class WorkoutPreflightSelection {
  WorkoutPreflightSelection({
    required Iterable<String> targetDeviceIds,
    this.preparation,
    this.localOnly = false,
  }) : targetDeviceIds = List.unmodifiable(targetDeviceIds);

  final List<String> targetDeviceIds;
  final DisplayPreparationProof? preparation;
  final bool localOnly;
}

Future<WorkoutPreflightSelection?> showWorkoutPreflight(
  BuildContext context,
  Workout workout,
) => Navigator.of(context, rootNavigator: true).push<WorkoutPreflightSelection>(
  MaterialPageRoute(
    settings: RouteSettings(name: '/workouts/${workout.id}/prepare'),
    builder: (_) => WorkoutPreparationPage(workout: workout),
  ),
);

class WorkoutPreparationPage extends HookConsumerWidget {
  const WorkoutPreparationPage({super.key, required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final retry = useState(0);
    final preferences = ref.watch(workoutPreferencesActionsProvider);
    final reporter = ref.read(errorReporterProvider);
    final loading = useMemoized(
      () => Future<Workout>.sync(() => preferences.apply(workout, fresh: true))
          .catchError((Object error, StackTrace stack) {
            reporter.capture(
              error,
              stack,
              action: 'workout.preflight.preferences',
            );
            Error.throwWithStackTrace(error, stack);
          }),
      [preferences, workout, retry.value],
    );
    final resolved = useFuture(loading);
    if (resolved.connectionState == ConnectionState.done && resolved.hasData) {
      return _PreparedWorkoutPreparationPage(workout: resolved.data!);
    }
    return _PreparationLayout(
      workout: workout,
      composition: _WorkoutComposition(workout: workout),
      children: [
        if (resolved.hasError) ...[
          _CheckTile(
            ok: false,
            title: '수업 설정을 확인하지 못했어요',
            subtitle: workoutErrorMessage(
              resolved.error,
              fallback: '연결을 확인하고 다시 시도해 주세요.',
            ),
          ),
          shadcn.ShadButton.ghost(
            expands: true,
            height: 0,
            onPressed: () => retry.value++,
            child: const Text('다시 시도'),
          ),
        ] else
          PreparationShadcnStage(
            key: ValueKey(loading),
            label: '최신 수업 설정 확인 중',
          ),
      ],
    );
  }
}

// Catch synchronous account/provider failures inside the provider boundary:
// a Widget try/catch cannot handle a later ref.watch error notification.
final _preflightScopeProvider =
    Provider.autoDispose<AsyncValue<(Object, DisplayPreparationState)>>((ref) {
      try {
        final scope = ref.watch(imageUsageSourceProvider);
        return AsyncData((
          scope,
          ref.watch(displayPreparationControllerProvider),
        ));
      } catch (error, stack) {
        return AsyncError(error, stack);
      }
    });

class _PreparedWorkoutPreparationPage extends ConsumerWidget {
  const _PreparedWorkoutPreparationPage({required this.workout});
  final Workout workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(_preflightScopeProvider);
    final ready = scope.value;
    if (ready != null) {
      return _WorkoutReadinessPage(
        key: ObjectKey(ready.$1),
        workout: workout,
        accountScope: ready.$1,
        preparation: ready.$2,
      );
    }
    return _PreparationLayout(
      workout: workout,
      composition: _WorkoutComposition(workout: workout),
      children: [
        _CheckTile(
          ok: false,
          title: '계정 연결을 확인해 주세요',
          subtitle: workoutErrorMessage(
            scope.error,
            fallback: '계정 연결을 확인하지 못했어요. 현재 계정을 확인한 뒤 수업 준비를 다시 열어 주세요.',
          ),
        ),
      ],
    );
  }
}

class _WorkoutReadinessPage extends HookConsumerWidget {
  const _WorkoutReadinessPage({
    super.key,
    required this.workout,
    required this.accountScope,
    required this.preparation,
  });
  final Workout workout;
  final Object accountScope;
  final DisplayPreparationState preparation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceState = ref.watch(displayDevicesProvider);
    final devices = deviceState.value ?? const [];
    final nowMs =
        ref.watch(displayHealthNowProvider).value ??
        DateTime.now().millisecondsSinceEpoch;
    final eligibleDevices = devices
        .where((item) => item.paired && item.displayState == 'auto')
        .toList();
    final eligibleIds = eligibleDevices.map((device) => device.id).toSet();
    // The preparation cohort is captured once after the shared health stream
    // resolves. Selection is independent and never invalidates that request.
    final cohort = useState<List<DisplayDevice>?>(null);
    final selectedDeviceIds = useState<Set<String>>({});
    final retry = useState(0);
    useEffect(() {
      if (cohort.value != null ||
          deviceState.isLoading ||
          deviceState.hasError) {
        return null;
      }
      var cancelled = false;
      Future.microtask(() {
        if (cancelled || !context.mounted) return;
        cohort.value = List.unmodifiable(eligibleDevices);
        selectedDeviceIds.value = eligibleDevices
            .where((device) => device.recentlySeen(nowMs))
            .map((device) => device.id)
            .toSet();
      });
      return () => cancelled = true;
    }, [cohort.value, deviceState]);
    final requestedTargets =
        cohort.value?.map((device) => device.id).toList() ?? const <String>[];
    final incompatible = preparation.incompatibleDeviceIds;
    final preparedTargets = requestedTargets
        .where((id) => !incompatible.contains(id))
        .toList();
    final selectableIds = eligibleIds.difference(incompatible);
    final targets = selectedDeviceIds.value.difference(incompatible);
    final fingerprint = preparationFingerprint(workout, preparedTargets);
    final approvalExpired =
        preparation.admission != null &&
        (preparation.admission!.status != 'preparing' ||
            preparation.admission!.prepareExpiresAtMs <= nowMs);
    final currentApproval =
        preparedTargets.isNotEmpty &&
        preparation.accessChecked &&
        preparation.clientFingerprint == fingerprint &&
        preparation.request != null &&
        !preparation.request!.expired(nowMs) &&
        preparation.request!.targetDeviceIds.length == preparedTargets.length &&
        preparation.request!.targetDeviceIds.toSet().containsAll(
          preparedTargets,
        ) &&
        !approvalExpired;
    final readiness = evaluateWorkoutReadiness(workout);
    useEffect(() {
      if (requestedTargets.isEmpty) return null;
      var cancelled = false;
      Future.microtask(() {
        if (!cancelled && context.mounted) {
          unawaited(
            ref
                .read(displayPreparationControllerProvider.notifier)
                .prepare(workout, requestedTargets, candidates: cohort.value),
          );
        }
      });
      return () => cancelled = true;
    }, [accountScope, workout, cohort.value, retry.value]);
    final selected = eligibleDevices
        .where((d) => targets.contains(d.id))
        .toList();
    final modern = selected.where((d) => d.preparationProtocol >= 1).toList();
    final requiredProtocol = requiredTimingProtocol(workout);
    final matchingRequest = preparation.clientFingerprint == fingerprint
        ? preparation.request
        : null;
    DisplayPreparationStatus statusOf(device) => displayPreparationStatus(
      device,
      requiredProtocol,
      matchingRequest,
      preparation.receipts[device.id],
      nowMs,
    );
    final allPrepared = selected.every(
      (d) => switch (statusOf(d)) {
        DisplayPreparationStatus.ready => true,
        DisplayPreparationStatus.legacy => true,
        _ => false,
      },
    );
    final canStart =
        readiness.isReady &&
        currentApproval &&
        preparation.error == null &&
        !preparation.loading &&
        !deviceState.isLoading &&
        !deviceState.hasError &&
        targets.isNotEmpty &&
        preparedTargets.toSet().containsAll(targets) &&
        selected.length == targets.length &&
        allPrepared;

    final submitted = useRef(false);
    Future<void> start() async {
      if (submitted.value || !canStart) return;
      submitted.value = true;
      if (context.mounted) {
        Navigator.of(context).pop(
          WorkoutPreflightSelection(
            targetDeviceIds: targets,
            preparation: DisplayPreparationProof(
              manifestHash: matchingRequest?.manifestHash ?? fingerprint,
              clientFingerprint: fingerprint,
              preparedTargetDeviceIds: preparedTargets,
              sessionId: matchingRequest?.sessionId,
              revision: matchingRequest?.revision,
            ),
          ),
        );
      }
    }

    final colors = Theme.of(context).colorScheme;
    final readyCount = modern
        .where((device) => statusOf(device) == DisplayPreparationStatus.ready)
        .length;
    final waiting =
        currentApproval &&
        modern.any(
          (device) => statusOf(device) == DisplayPreparationStatus.waiting,
        );
    final blockedTVs = selected
        .where(
          (device) => switch (statusOf(device)) {
            DisplayPreparationStatus.ready ||
            DisplayPreparationStatus.legacy ||
            DisplayPreparationStatus.waiting => false,
            _ => true,
          },
        )
        .toList();

    return _PreparationLayout(
      workout: workout,
      onStart: canStart ? start : null,
      composition: _WorkoutComposition(workout: workout),
      children: [
        if (eligibleDevices.isNotEmpty) ...[
          if (!allPrepared)
            Text(
              '준비되지 않은 TV는 선택을 해제해 제외할 수 있어요.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const Divider(height: 24),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '재생 TV · ${selected.length}대 선택',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              shadcn.ShadButton.ghost(
                height: 0,
                onPressed: () {
                  selectedDeviceIds.value =
                      targets.length == selectableIds.length
                      ? <String>{}
                      : selectableIds;
                },
                child: Text(
                  targets.length == selectableIds.length ? '전체 해제' : '전체 선택',
                ),
              ),
            ],
          ),
          for (final device in eligibleDevices)
            PreparationDeviceTile(
              key: ValueKey('preparation-device-${device.id}'),
              name: device.name,
              selected: targets.contains(device.id),
              status: incompatible.contains(device.id)
                  ? 'TV 앱 업데이트 필요 · 준비 대상에서 제외됨'
                  : _preparationLabel(statusOf(device)),
              onChanged: incompatible.contains(device.id)
                  ? null
                  : (checked) {
                      final next = Set<String>.from(selectedDeviceIds.value);
                      if (checked == true) {
                        next.add(device.id);
                      } else {
                        next.remove(device.id);
                      }
                      selectedDeviceIds.value = next;
                    },
            ),
          shadcn.ShadAccordion<String>(
            children: [
              shadcn.ShadAccordionItem(
                value: 'connection',
                title: const Text('연결 정보'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final device in eligibleDevices)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '${device.name} · ${device.zoneName} · ${device.installedVersion}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
        if (targets.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('재생할 TV를 선택해 주세요.'),
          ),
        if (!readiness.isReady)
          _CheckTile(
            ok: false,
            title: '수업 내용을 확인해 주세요',
            subtitle: readiness.issues.join('\n'),
          ),
        if (preparedTargets.isNotEmpty &&
            (preparation.error != null || approvalExpired)) ...[
          _CheckTile(
            ok: false,
            title: approvalExpired
                ? '수업 준비 승인을 다시 확인해 주세요'
                : '이용 상태를 다시 확인해 주세요',
            subtitle: preparation.error ?? '준비 시간이 만료되었거나 수업 상태가 변경됐어요.',
          ),
          shadcn.ShadButton.ghost(
            expands: true,
            height: 0,
            enabled: !preparation.loading,
            onPressed: preparation.loading ? null : () => retry.value++,
            child: const Text('수업 상태 다시 확인'),
          ),
        ] else if (deviceState.hasError) ...[
          const _CheckTile(
            ok: false,
            title: 'TV 목록 확인 실패',
            subtitle: '연결을 확인한 뒤 다시 시도해 주세요.',
          ),
          shadcn.ShadButton.ghost(
            expands: true,
            height: 0,
            onPressed: () => ref.invalidate(displayDevicesProvider),
            child: const Text('TV 목록 다시 확인'),
          ),
        ] else if (preparedTargets.isNotEmpty &&
            (!currentApproval || preparation.loading))
          PreparationShadcnStage(
            key: ValueKey('$fingerprint-${retry.value}'),
            label: '최신 수업 설정·이용 상태 확인 중',
          ),
        if (modern.isNotEmpty) ...[
          if (waiting)
            PreparationShadcnStage(
              key: ValueKey(matchingRequest?.sessionId),
              label: 'TV 이미지 준비 중 · $readyCount/${modern.length}대 완료',
            )
          else
            _CheckTile(
              ok: readyCount == modern.length,
              title: 'TV 이미지 준비 $readyCount/${modern.length}대 완료',
              subtitle: readyCount == modern.length
                  ? '선택한 TV에서 수업을 시작할 수 있어요.'
                  : '위 TV 상태를 확인해 주세요.',
            ),
          if (blockedTVs.isNotEmpty)
            Text(
              blockedTVs
                  .map((d) => '${d.name}: ${_preparationLabel(statusOf(d))}')
                  .join('\n'),
              style: TextStyle(color: colors.error),
            ),
          if (!allPrepared && !preparation.loading && preparation.error == null)
            shadcn.ShadButton.ghost(
              expands: true,
              height: 0,
              onPressed: () => retry.value++,
              child: const Text('TV 준비 다시 확인'),
            ),
        ],
        if (selected.length > modern.length)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '이미지 사전 확인 미지원 ${selected.length - modern.length}대',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// Reserve footer space outside the scroll view, including the bottom safe area.
class _PreparationLayout extends StatelessWidget {
  const _PreparationLayout({
    required this.workout,
    required this.children,
    this.onStart,
    this.composition,
  });
  final Workout workout;
  final List<Widget> children;
  final VoidCallback? onStart;
  final Widget? composition;

  @override
  Widget build(BuildContext context) {
    return PreparationShadcnScope(
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
                child: Row(
                  children: [
                    shadcn.ShadButton.ghost(
                      height: 0,
                      key: const ValueKey('preparation-back'),
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Icon(
                        shadcn.LucideIcons.arrowLeft,
                        size: 20,
                        semanticLabel: '뒤로',
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '수업 준비',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: SingleChildScrollView(
                      key: const ValueKey('preparation-page-scroll'),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.selected,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  shadcn.LucideIcons.sparkles,
                                  color: AppColors.accent,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '오늘의 수업',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      workout.name,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        shadcn.ShadBadge.outline(
                                          child: Text(
                                            workoutDurationText(workout),
                                          ),
                                        ),
                                        shadcn.ShadBadge.outline(
                                          child: Text(
                                            '${workout.modules.length}개 슬라이드',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          shadcn.ShadCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  '재생할 곳',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...children,
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ?composition,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 580),
                  child: SizedBox(
                    width: double.infinity,
                    child: shadcn.ShadButton(
                      key: const ValueKey('preparation-start'),
                      enabled: onStart != null,
                      onPressed: onStart,
                      height: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      leading: const Icon(shadcn.LucideIcons.play, size: 18),
                      child: const Text('수업 시작', textAlign: TextAlign.center),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text-only composition never fetches controller media during preparation.
class _WorkoutComposition extends StatelessWidget {
  const _WorkoutComposition({required this.workout});
  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (workout.modules.isEmpty) return const SizedBox.shrink();
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('수업 구성', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 112 * scale.clamp(1, 2),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: workout.modules.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final module = workout.modules[index];
                return SizedBox(
                  width: 164 * scale.clamp(1, 1.5),
                  child: shadcn.ShadCard(
                    padding: EdgeInsets.zero,
                    backgroundColor: index == 0
                        ? AppColors.selected
                        : AppColors.dialog,
                    radius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${index + 1}'.padLeft(2, '0'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              module.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            moduleDurationText(module),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({
    required this.ok,
    required this.title,
    required this.subtitle,
  });

  final bool? ok;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          shadcn.ShadBadge.secondary(
            child: Icon(
              ok == true
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              size: 20,
              color: ok == true
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

String _preparationLabel(DisplayPreparationStatus status) => switch (status) {
  DisplayPreparationStatus.offline => '최근 응답 없음 · 연결 확인 또는 제외',
  DisplayPreparationStatus.updateRequired => '이 수업은 TV 업데이트가 필요해요',
  DisplayPreparationStatus.legacy => '연결·재생 호환 · 이미지 확인 미지원',
  DisplayPreparationStatus.waiting => '이미지·소리 준비 중',
  DisplayPreparationStatus.failed => '자료 준비 실패 · 재시도 또는 제외',
  DisplayPreparationStatus.ready => '준비 완료',
  DisplayPreparationStatus.expired => '준비 확인 만료 · 다시 확인해 주세요',
};
