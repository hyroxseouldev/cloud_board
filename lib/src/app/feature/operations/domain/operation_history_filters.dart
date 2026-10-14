import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/domain/operation_history.dart';

/// A controller event can address multiple TVs. Include it in each target TV's
/// history, without multiplying session counts in the whole-center report.
List<OperationEvent> filterOperationHistory(
  Iterable<OperationEvent> events, {
  String? deviceId,
  String? workoutId,
  String? type,
}) => uniqueOperationEvents(events).where((event) {
  if (event.type.startsWith('onboarding_')) return false;
  if (deviceId != null &&
      event.deviceId != deviceId &&
      !event.targetDeviceIds.contains(deviceId)) {
    return false;
  }
  if (workoutId != null && event.workoutId != workoutId) return false;
  return type == null || event.type == type;
}).toList();

/// Labels are taken from the historical row, never today's device registry.
Map<String, String> operationDeviceOptions(Iterable<OperationEvent> events) {
  final result = <String, String>{};
  for (final event in uniqueOperationEvents(events)) {
    final id = event.deviceId;
    if (id != null) {
      result.putIfAbsent(id, () => event.deviceName ?? '이름 기록 없음 · $id');
    }
    for (final target in event.targetDeviceIds) {
      result.putIfAbsent(
        target,
        () => event.targetDeviceNames[target] ?? '이름 기록 없음 · $target',
      );
    }
  }
  return result;
}

Map<String, String> operationWorkoutOptions(Iterable<OperationEvent> events) {
  final result = <String, String>{};
  for (final event in uniqueOperationEvents(events)) {
    final id = event.workoutId;
    if (id != null) {
      result.putIfAbsent(id, () => event.workoutName ?? '수업 이름 기록 없음 · $id');
    }
  }
  return result;
}
