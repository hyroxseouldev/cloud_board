import 'dart:async';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/operations/data/repositories/store_operations_repository_impl.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/domain/operations_metrics.dart';
import 'package:cloud_board/src/app/feature/operations/domain/usecases/store_operations_actions.dart';
import 'package:cloud_board/src/app/feature/playback/domain/usecases/playback_actions.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/workout_controller.dart';

part 'store_operations_controller.g.dart';

@Riverpod(keepAlive: true)
Stream<BrandTemplate> brandTemplate(Ref ref) =>
    ref.watch(storeOperationsRepositoryProvider).watchBrandTemplate();

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
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> runDue() async {
    if (state.isLoading) return;
    if (await ref.read(playbackActionsProvider).hasRunningSession()) return;
    final now = DateTime.now();
    final schedules = await ref.read(workoutSchedulesProvider.future);
    final due = schedules.where((item) => isScheduleDue(item, now)).toList();
    if (due.isEmpty) return;
    final workouts = await ref
        .read(workoutControllerProvider.notifier)
        .loadComplete();
    final devices = await ref.read(displayDevicesProvider.future);
    for (final schedule in due) {
      final workout = workouts
          .where((item) => item.id == schedule.workoutId)
          .firstOrNull;
      if (workout == null || workout.modules.isEmpty) continue;
      final targets = schedule.targetDeviceIds.isEmpty
          ? devices.where((item) => item.online).map((item) => item.id).toList()
          : schedule.targetDeviceIds;
      if (targets.isEmpty) continue;
      final occurrenceKey = scheduleOccurrenceKey(schedule, now);
      final claimed = await ref
          .read(storeOperationsActionsProvider)
          .claimOccurrence(schedule.id, occurrenceKey);
      if (!claimed) continue;
      final steps = buildPlayerSteps(workout);
      state = const AsyncLoading();
      state = await AsyncValue.guard(() async {
        final scheduledAt = scheduledDateTime(schedule, now);
        await ref
            .read(playbackActionsProvider)
            .start(
              workout: workout,
              targetDeviceIds: targets,
              stepIndex: 0,
              durationMs: steps.first.duration * 1000,
              deviceId: await ref.read(deviceIdProvider.future),
              scheduled: true,
              scheduledAtMs: scheduledAt.millisecondsSinceEpoch,
            );
      });
    }
  }
}
