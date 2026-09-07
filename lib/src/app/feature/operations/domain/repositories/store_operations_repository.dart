import 'dart:typed_data';

import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';

abstract interface class StoreOperationsRepository {
  Stream<BrandTemplate> watchBrandTemplate();
  Stream<List<WorkoutSchedule>> watchSchedules();
  Stream<List<OperationEvent>> watchEvents();
  Future<void> saveBrandTemplate(BrandTemplate template);
  Future<String> uploadBrandImage({
    required Uint8List bytes,
    required String extension,
    required String purpose,
  });
  Future<void> saveSchedule(WorkoutSchedule schedule);
  Future<void> deleteSchedule(String scheduleId);
  Future<bool> claimOccurrence(String scheduleId, String occurrenceKey);
  Future<void> recordEvent({
    required String type,
    String? deviceId,
    String? workoutId,
    String? workoutName,
    bool scheduled,
    int? scheduledAtMs,
  });
}
