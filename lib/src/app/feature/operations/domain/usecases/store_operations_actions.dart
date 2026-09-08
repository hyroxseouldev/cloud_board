import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/operations/data/repositories/store_operations_repository_impl.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/domain/repositories/store_operations_repository.dart';

part 'store_operations_actions.g.dart';

class StoreOperationsActions {
  const StoreOperationsActions(this._repository);

  final StoreOperationsRepository _repository;

  Future<void> saveBrandTemplate(BrandTemplate template) =>
      _repository.saveBrandTemplate(template);

  Future<String> uploadBrandImage({
    required Uint8List bytes,
    required String extension,
    required String purpose,
  }) => _repository.uploadBrandImage(
    bytes: bytes,
    extension: extension,
    purpose: purpose,
  );

  Future<void> saveSchedule(WorkoutSchedule schedule) =>
      _repository.saveSchedule(schedule);

  Future<void> deleteSchedule(String scheduleId) =>
      _repository.deleteSchedule(scheduleId);

  Future<bool> claimOccurrence(String scheduleId, String occurrenceKey) =>
      _repository.claimOccurrence(scheduleId, occurrenceKey);

  Future<void> recordEvent({
    required String type,
    String? deviceId,
    String? workoutId,
    String? workoutName,
    bool scheduled = false,
    int? scheduledAtMs,
  }) => _repository.recordEvent(
    type: type,
    deviceId: deviceId,
    workoutId: workoutId,
    workoutName: workoutName,
    scheduled: scheduled,
    scheduledAtMs: scheduledAtMs,
  );
}

@riverpod
StoreOperationsActions storeOperationsActions(Ref ref) =>
    StoreOperationsActions(ref.watch(storeOperationsRepositoryProvider));
