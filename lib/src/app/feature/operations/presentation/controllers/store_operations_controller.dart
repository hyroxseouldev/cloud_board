import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';

import 'dart:async';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/operations/data/repositories/store_operations_repository_impl.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/audience_branding.dart';
import 'package:cloud_board/src/app/feature/operations/domain/operations_metrics.dart';
import 'package:cloud_board/src/app/feature/operations/domain/usecases/store_operations_actions.dart';
import 'package:cloud_board/src/app/feature/playback/domain/usecases/playback_actions.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_failure.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';

part 'store_operations_controller.g.dart';

@riverpod
Stream<AudienceBranding?> audienceBrandingForOwner(Ref ref, String ownerId) =>
    ref.watch(storeOperationsRepositoryProvider).watchAudienceBranding();

/// Synchronous owner filtering prevents retained AsyncData from a previous
/// account appearing for even one frame during sign-out or TV re-pairing.
@Riverpod(keepAlive: true)
AudienceBranding? audienceBranding(Ref ref) {
  if (Firebase.apps.isEmpty) return null;
  final account = ref.watch(accountOwnerIdProvider);
  final ownerId = account.value;
  if (account.isLoading || account.hasError || ownerId == null) return null;
  final policy = ref.watch(audienceBrandingForOwnerProvider(ownerId)).value;
  return policy?.ownerId == ownerId ? policy : null;
}

@Riverpod(keepAlive: true)
Stream<BrandTemplate> brandTemplate(Ref ref) =>
    ref.watch(storeOperationsRepositoryProvider).watchBrandTemplate();

@Riverpod(keepAlive: true)
Stream<BrandTemplate> effectiveBrandTemplate(Ref ref) =>
    ref.watch(storeOperationsRepositoryProvider).watchEffectiveBrandTemplate();

@Riverpod(keepAlive: true)
Stream<List<WorkoutSchedule>> workoutSchedules(Ref ref) =>
    ref.watch(storeOperationsRepositoryProvider).watchSchedules();

@Riverpod(keepAlive: true)
Stream<List<OperationEvent>> operationEvents(Ref ref) =>
    ref.watch(storeOperationsRepositoryProvider).watchEvents();

@riverpod
OperationsReport operationsReport(Ref ref) => buildOperationsReport(
  ref.watch(operationEventsProvider).value ?? const <OperationEvent>[],
);

@riverpod
class StoreOperationsActionController
    extends _$StoreOperationsActionController {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> saveBrandTemplate(BrandTemplate template) => _run(
    () => ref.read(storeOperationsActionsProvider).saveBrandTemplate(template),
  );

  Future<String?> uploadBrandImage({
    required Uint8List bytes,
    required String extension,
    required String purpose,
  }) async {
    String? url;
    final success = await _run(() async {
      url = await ref
          .read(storeOperationsActionsProvider)
          .uploadBrandImage(
            bytes: bytes,
            extension: extension,
            purpose: purpose,
          );
    });
    return success ? url : null;
  }

  Future<bool> saveSchedule(WorkoutSchedule schedule) => _run(
    () => ref.read(storeOperationsActionsProvider).saveSchedule(schedule),
  );

  Future<bool> deleteSchedule(String scheduleId) => _run(
    () => ref.read(storeOperationsActionsProvider).deleteSchedule(scheduleId),
  );

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }
}

@Riverpod(keepAlive: true)
class ScheduleRunnerController extends _$ScheduleRunnerController {
  int _runEpoch = 0;

  @override
  AsyncValue<void> build() {
    ++_runEpoch;
    ref.onDispose(() => ++_runEpoch);
    return const AsyncData(null);
  }

  Future<void> runDue() async {
    if (state.isLoading) return;
    final account = ref.read(accountOwnerIdProvider);
    final ownerId = account.value;
    if (account.isLoading || account.hasError || ownerId == null) return;
    // Cover every await, including the initial session query, and lock before it.
    state = const AsyncLoading();
    final epoch = _runEpoch;
    final result = await AsyncValue.guard(
      () => _runDueForOwner(ownerId, epoch),
    );
    if (ref.mounted && epoch == _runEpoch) state = result;
  }

  bool _isCurrentOwner(String ownerId) {
    if (!ref.mounted) return false;
    final account = ref.read(accountOwnerIdProvider);
    return !account.isLoading && !account.hasError && account.value == ownerId;
  }

  Future<void> _runDueForOwner(String ownerId, int epoch) async {
    var cancelled = false;
    bool isCurrent() =>
        !cancelled && epoch == _runEpoch && _isCurrentOwner(ownerId);
    void ensureCurrent() {
      if (!isCurrent()) {
        throw const PlaybackFailure(
          'start_cancelled',
          '계정이나 예약 연결이 변경되어 시작을 취소했어요. 다시 확인해 주세요.',
        );
      }
    }

    // Observe account changes before even the initial schedules await. A quick
    // A→B→A change must not let an old asynchronous run resume for A.
    final accountSubscription = ref.listen(accountOwnerIdProvider, (_, next) {
      if (next.isLoading || next.hasError || next.value != ownerId) {
        cancelled = true;
      }
    });
    void Function()? closeActions;
    try {
      final now = DateTime.now();
      final schedules = await ref.read(workoutSchedulesProvider.future);
      if (!isCurrent()) return;
      final due = schedules
          .where(
            (item) =>
                isScheduleDue(item, now) &&
                item.lastOccurrenceKey != scheduleOccurrenceKey(item, now),
          )
          .toList();
      if (due.isEmpty) return;
      // Retain the same generated actions and dependencies from the first
      // session query through start. No eligible schedule means no playback read.
      closeActions = ref.listen(playbackActionsProvider, (before, next) {
        if (before != null && !identical(before, next)) cancelled = true;
      }).close;
      final actions = ref.read(playbackActionsProvider);
      if (await actions.hasRunningSession()) return;
      if (!isCurrent()) return;
      final devices = await ref.read(displayDevicesProvider.future);
      if (!isCurrent()) return;
      final deviceId = await ref.read(deviceIdProvider.future);
      if (!isCurrent()) return;
      for (final schedule in due) {
        final workout = await ref.read(
          workoutDetailProvider(schedule.workoutId).future,
        );
        if (!isCurrent()) return;
        if (workout == null || workout.modules.isEmpty) continue;
        final targets = schedule.targetDeviceIds.isEmpty
            ? devices
                  .where((item) => item.online)
                  .map((item) => item.id)
                  .toList()
            : schedule.targetDeviceIds;
        if (targets.isEmpty) continue;
        final occurrenceKey = scheduleOccurrenceKey(schedule, now);
        final claimed = await ref
            .read(storeOperationsActionsProvider)
            .claimOccurrence(schedule.id, occurrenceKey);
        if (!isCurrent()) return;
        if (!claimed) continue;
        final steps = buildPlayerSteps(workout);
        await actions.start(
          workout: workout,
          targetDeviceIds: targets,
          stepIndex: 0,
          durationMs: steps.first.duration * 1000,
          deviceId: deviceId,
          scheduled: true,
          ensureCurrent: ensureCurrent,
          scheduledAtMs: scheduledDateTime(
            schedule,
            now,
          ).millisecondsSinceEpoch,
        );
        // Another due schedule must not replace the class that just started.
        return;
      }
    } finally {
      closeActions?.call();
      accountSubscription.close();
    }
  }
}
