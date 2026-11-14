import 'package:cloud_board/src/app/feature/image_usage/data/image_usage_repository.dart';
import 'package:cloud_board/src/app/feature/image_usage/domain/image_usage.dart';
import 'package:cloud_board/src/app/core/widgets/preparation_stage_status.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/usecases/workout_preferences_actions.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/display_preparation_controller.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_position.dart';

import 'dart:async';

import 'package:cloud_board/src/app/core/widgets/app_alert_dialog.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/services/workout_image_loader.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_readiness.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/workout_error_message.dart';

typedef PreflightImageLoader = Future<int> Function(
  BuildContext context,
  Iterable<String> sources, {
  bool Function()? isCancelled,
});
final preflightImageLoaderProvider = Provider<PreflightImageLoader>(
  (ref) => precacheWorkoutImages,
);

// Local image failures keep solo playback blocked; remote access is checked
// by preparation and again by the existing server start gates.
bool _blocksAccess(Object? error) =>
    (error is ImageUsageFailure && error.reason != 'service_unavailable') ||
    error is FirebaseException &&
        const {'permission-denied', 'unauthenticated'}.contains(error.code);

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
) => showDialog<WorkoutPreflightSelection>(
  context: context,
  barrierDismissible: false,
  builder: (_) => WorkoutPreflightDialog(workout: workout),
);

class WorkoutPreflightDialog extends HookConsumerWidget {
  const WorkoutPreflightDialog({super.key, required this.workout});

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
      return _PreparedWorkoutPreflightDialog(workout: resolved.data!);
    }
    return AppAlertDialog(
      title: const Text('수업 준비'),
      content: resolved.hasError
          ? Text(
              workoutErrorMessage(
                resolved.error,
                fallback: '수업 설정을 불러오지 못했어요. 연결을 확인하고 다시 시도해 주세요.',
              ),
            )
          : PreparationStageStatus(
              key: ValueKey(loading),
              label: '최신 수업 설정 확인 중',
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        if (resolved.hasError)
          FilledButton(
            onPressed: () => retry.value++,
            child: const Text('다시 시도'),
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

class _PreparedWorkoutPreflightDialog extends ConsumerWidget {
  const _PreparedWorkoutPreflightDialog({required this.workout});
  final Workout workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(_preflightScopeProvider);
    final ready = scope.value;
    if (ready != null) {
      return _WorkoutReadinessDialog(
        key: ObjectKey(ready.$1),
        workout: workout,
        accountScope: ready.$1,
        preparation: ready.$2,
      );
    }
    return AppAlertDialog(
      title: const Text('수업 준비'),
      content: Text(
        workoutErrorMessage(
          scope.error,
          fallback: '계정 연결을 확인하지 못했어요. 현재 계정을 확인한 뒤 수업 준비를 다시 열어 주세요.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

class _PreviewWork {
  bool cancelled = false;
}

class _WorkoutReadinessDialog extends HookConsumerWidget {
  const _WorkoutReadinessDialog({
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
    final onlineDevices = devices
        .where((item) => item.paired && item.displayState == 'auto')
        .toList();
    final selectedDeviceIds = useState<Set<String>>(
      onlineDevices
          .where((device) => device.recentlySeen(nowMs))
          .map((device) => device.id)
          .toSet(),
    );
    final initializedDeviceSelection = useRef(onlineDevices.isNotEmpty);
    final selectingInitialTargets =
        !initializedDeviceSelection.value && onlineDevices.isNotEmpty;
    final fingerprint = preparationFingerprint(
      workout,
      selectedDeviceIds.value,
    );
    final approvalExpired =
        preparation.admission != null &&
        (preparation.admission!.status != 'preparing' ||
            preparation.admission!.prepareExpiresAtMs <= nowMs);
    final currentApproval =
        !deviceState.isLoading &&
        !deviceState.hasError &&
        !selectingInitialTargets &&
        preparation.accessChecked &&
        preparation.clientFingerprint == fingerprint &&
        (preparation.admission == null ||
            (preparation.admission!.status == 'preparing' &&
                preparation.admission!.prepareExpiresAtMs > nowMs));
    final remote = selectedDeviceIds.value.isNotEmpty;
    final previewRetry = useState(0);
    final loader = ref.watch(preflightImageLoaderProvider);
    final readiness = evaluateWorkoutReadiness(workout);
    final previewWork = useMemoized(_PreviewWork.new, [
      accountScope,
      workout,
      fingerprint,
      currentApproval,
      remote,
      preparation.admission,
      preparation.request?.sessionId,
      preparation.request?.revision,
      preparation.request?.manifestHash,
      preparation.loading,
      preparation.error,
      previewRetry.value,
      loader,
    ]);
    useEffect(
      () =>
          () => previewWork.cancelled = true,
      [previewWork],
    );
    final preview = useMemoized(() {
      if (remote ||
          !currentApproval ||
          preparation.loading ||
          preparation.error != null) {
        return null;
      }
      return Future<int>.sync(() async {
        await WidgetsBinding.instance.endOfFrame;
        if (previewWork.cancelled || !context.mounted) return 0;
        try {
          return await loader(
            context,
            workoutImageWindow(workout, count: 2, includeCountdown: true),
            isCancelled: () => previewWork.cancelled,
          );
        } catch (error, stack) {
          if (!previewWork.cancelled) {
            ref
                .read(errorReporterProvider)
                .capture(error, stack, action: 'workout.preflight.images');
          }
          Error.throwWithStackTrace(error, stack);
        }
      });
    }, [previewWork]);
    // Never keep a prior success while a different account/target/mode loads.
    final imageCheck = useFuture(preview, preserveState: false);
    final imageReady =
        imageCheck.connectionState == ConnectionState.done &&
        imageCheck.hasData;
    final accessError = _blocksAccess(imageCheck.error);

    final onlineDeviceIds = onlineDevices.map((device) => device.id).toSet();
    final onlineDeviceSignature = onlineDeviceIds.toList()..sort();
    useEffect(() {
      final retained = selectedDeviceIds.value.intersection(onlineDeviceIds);
      final next = !initializedDeviceSelection.value && retained.isEmpty
          ? onlineDevices
                .where((device) => device.recentlySeen(nowMs))
                .map((device) => device.id)
                .toSet()
          : retained;
      if (onlineDeviceIds.isNotEmpty) initializedDeviceSelection.value = true;
      if (!_sameIds(next, selectedDeviceIds.value)) {
        Future.microtask(() {
          if (context.mounted) selectedDeviceIds.value = next;
        });
      }
      return null;
    }, [onlineDeviceSignature.join('|')]);

    final selected = onlineDevices
        .where((d) => selectedDeviceIds.value.contains(d.id))
        .toList();
    final modern = selected.where((d) => d.preparationProtocol >= 1).toList();
    final retry = useState(0);
    final signature = (selectedDeviceIds.value.toList()..sort()).join('|');
    useEffect(
      () {
        if (deviceState.isLoading ||
            deviceState.hasError ||
            selectingInitialTargets) {
          return null;
        }
        var cancelled = false;
        final targets = selectedDeviceIds.value.toList();
        Future.microtask(() {
          if (!cancelled && context.mounted) {
            unawaited(
              ref
                  .read(displayPreparationControllerProvider.notifier)
                  .prepare(workout, targets),
            );
          }
        });
        return () => cancelled = true;
      },
      [
        accountScope,
        workout,
        signature,
        retry.value,
        deviceState.isLoading,
        deviceState.hasError,
        selectingInitialTargets,
      ],
    );
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
        !accessError &&
        (remote || imageReady) &&
        selected.length == selectedDeviceIds.value.length &&
        allPrepared;

    Future<void> start() async {
      if (context.mounted) {
        Navigator.of(context).pop(
          WorkoutPreflightSelection(
            targetDeviceIds: selectedDeviceIds.value,
            // Preserve the existing local-route vs empty-target server-session
            // contract. Both zero-target cases still require controller images.
            localOnly: !remote && devices.isNotEmpty,
            preparation: selected.isEmpty
                ? null
                : DisplayPreparationProof(
                    manifestHash: matchingRequest?.manifestHash ?? fingerprint,
                    clientFingerprint: fingerprint,
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

    return AppAlertDialog(
      scrollable: false,
      title: const Text('수업 준비'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                workout.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${workout.modules.length}개 슬라이드 · ${workoutDurationText(workout)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (!readiness.isReady)
                _CheckTile(
                  ok: false,
                  title: '수업 내용을 확인해 주세요',
                  subtitle: readiness.issues.join('\n'),
                ),
              if (preparation.error != null ||
                  accessError ||
                  approvalExpired) ...[
                _CheckTile(
                  ok: false,
                  title: approvalExpired
                      ? '수업 준비 승인을 다시 확인해 주세요'
                      : '이용 상태를 다시 확인해 주세요',
                  subtitle:
                      preparation.error ??
                      (approvalExpired
                          ? '준비 시간이 만료되었거나 수업 상태가 변경됐어요.'
                          : workoutErrorMessage(
                              imageCheck.error,
                              fallback: '수업 이용 승인을 확인하지 못했어요.',
                            )),
                ),
                TextButton(
                  onPressed: preparation.loading ? null : () => retry.value++,
                  child: const Text('수업 상태 다시 확인'),
                ),
              ] else if (deviceState.hasError) ...[
                const _CheckTile(
                  ok: false,
                  title: 'TV 목록 확인 실패',
                  subtitle: '연결을 확인한 뒤 다시 시도해 주세요.',
                ),
                TextButton(
                  onPressed: () => ref.invalidate(displayDevicesProvider),
                  child: const Text('TV 목록 다시 확인'),
                ),
              ] else if (!currentApproval || preparation.loading)
                PreparationStageStatus(
                  key: ValueKey('$fingerprint-${retry.value}'),
                  label: '최신 수업 설정·이용 상태 확인 중',
                ),
              if (!remote) ...[
                const Text(
                  '이 기기에서만 재생',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                if (imageCheck.hasError && !accessError) ...[
                  _CheckTile(
                    ok: false,
                    title: '이미지 준비 실패',
                    subtitle: workoutErrorMessage(
                      imageCheck.error,
                      fallback: '이미지를 불러오지 못했어요. 연결을 확인해 주세요.',
                    ),
                  ),
                  TextButton(
                    onPressed: currentApproval
                        ? () => previewRetry.value++
                        : null,
                    child: const Text('시작 이미지 다시 불러오기'),
                  ),
                ] else if (imageReady)
                  const _CheckTile(
                    ok: true,
                    title: '이미지 준비 완료',
                    subtitle: '시작 화면과 다음 슬라이드를 준비했어요.',
                  )
                else if (currentApproval &&
                    !preparation.loading &&
                    preparation.error == null &&
                    !approvalExpired)
                  PreparationStageStatus(
                    key: ValueKey(previewWork),
                    label: '시작 이미지 준비 중',
                  ),
              ],
              if (remote && modern.isNotEmpty) ...[
                if (waiting)
                  PreparationStageStatus(
                    key: ValueKey(matchingRequest?.sessionId),
                    label: 'TV 이미지 준비 중 · $readyCount/${modern.length}대 완료',
                  )
                else
                  _CheckTile(
                    ok: readyCount == modern.length,
                    title: 'TV 이미지 준비 $readyCount/${modern.length}대 완료',
                    subtitle: readyCount == modern.length
                        ? '선택한 TV에서 수업을 시작할 수 있어요.'
                        : '아래 TV 상태를 확인해 주세요.',
                  ),
                if (blockedTVs.isNotEmpty)
                  Text(
                    blockedTVs
                        .map(
                          (d) => '${d.name}: ${_preparationLabel(statusOf(d))}',
                        )
                        .join('\n'),
                    style: TextStyle(color: colors.error),
                  ),
                if (!allPrepared &&
                    !preparation.loading &&
                    preparation.error == null)
                  TextButton(
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
              if (onlineDevices.isNotEmpty) ...[
                if (remote && !allPrepared)
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
                    TextButton(
                      onPressed: () => selectedDeviceIds.value =
                          selectedDeviceIds.value.length == onlineDevices.length
                          ? <String>{}
                          : onlineDeviceIds,
                      child: Text(
                        selectedDeviceIds.value.length == onlineDevices.length
                            ? '전체 해제'
                            : '전체 선택',
                      ),
                    ),
                  ],
                ),
                for (final device in onlineDevices)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: selectedDeviceIds.value.contains(device.id),
                    title: Text(
                      device.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      selectedDeviceIds.value.contains(device.id)
                          ? _preparationLabel(statusOf(device))
                          : '선택 안 함',
                    ),
                    onChanged: (checked) {
                      final next = Set<String>.from(selectedDeviceIds.value);
                      if (checked == true) {
                        next.add(device.id);
                      } else {
                        next.remove(device.id);
                      }
                      selectedDeviceIds.value = next;
                    },
                  ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('연결 정보', style: TextStyle(fontSize: 13)),
                  children: [
                    for (final device in onlineDevices)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(device.name),
                        subtitle: Text(
                          '${device.zoneName} · ${device.installedVersion}',
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton.icon(
          onPressed: canStart ? start : null,
          style: FilledButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
          ),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('수업 시작'),
        ),
      ],
    );
  }
}

bool _sameIds(Set<String> first, Set<String> second) =>
    first.length == second.length && first.containsAll(second);

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
          Icon(
            ok == true
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
            size: 20,
            color: ok == true
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
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
