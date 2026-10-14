import 'package:cloud_board/src/app/feature/operations/domain/operation_history.dart';
import 'dart:typed_data';

import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/audience_branding.dart';

abstract interface class StoreOperationsRepository {
  Stream<AudienceBranding?> watchAudienceBranding();
  Stream<BrandTemplate> watchBrandTemplate();
  Stream<BrandTemplate> watchEffectiveBrandTemplate();
  Stream<List<WorkoutSchedule>> watchSchedules();
  Stream<List<OperationEvent>> watchEvents();
  Stream<OperationEventBatch> watchEventsInRange(OperationEventRange range);
  Future<void> recordDetailedEvent(OperationEvent event);
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
