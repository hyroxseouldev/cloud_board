import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart'
    show serverTimeOffsetProvider;

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/core/services/event_id.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/operations/data/operation_event_writer.dart';
import 'package:cloud_board/src/app/feature/operations/data/repositories/store_operations_repository_impl.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';

part 'operation_event_recorder.g.dart';

@Riverpod(keepAlive: true)
OperationEventWriter operationEventWriter(Ref ref) {
  final writer = OperationEventWriter(
    ref.watch(storeOperationsRepositoryProvider).recordDetailedEvent,
  );
  ref.onDispose(writer.dispose);
  return writer;
}

/// Capture all supplied context before asynchronous work, so a later account,
/// session or device rename cannot re-label historical events.
void recordOperationEvent(
  Ref ref, {
  required String type,
  required String phase,
  String? eventId,
  String? sessionId,
  String? workoutId,
  String? workoutName,
  String? deviceId,
  String? deviceRole,
  DisplayDevice? display,
  String? errorId,
  String? errorCode,
  String? incidentId,
  String? recoveryOfEventId,
  String? playbackImpact,
  List<DisplayDevice> targets = const [],
}) {
  try {
    final id = eventId ?? createEventId();
    final occurredAtMs =
        DateTime.now().millisecondsSinceEpoch +
        (ref.read(serverTimeOffsetProvider).value ?? 0);
    final defaults = ref.read(errorReporterProvider).defaults;
    final writer = ref.read(operationEventWriterProvider);
    final localDevice = deviceId ?? display?.id;
    final localId = localDevice == null
        ? ref.read(deviceIdProvider.future)
        : Future.value(localDevice);
    unawaited(
      localId
          .then(
            (resolvedId) => writer.record(
              OperationEvent(
                id: id,
                eventId: id,
                schemaVersion: 2,
                type: type,
                occurredAtMs: occurredAtMs,
                deviceId: resolvedId,
                deviceName: display?.name,
                zoneName: display?.zoneName,
                deviceRole:
                    deviceRole ??
                    (display == null
                        ? (defaults['role'] == 'tv' ? 'display' : 'controller')
                        : 'display'),
                appVersion: display == null
                    ? (deviceRole == 'display'
                          ? null
                          : defaults['version']?.toString())
                    : display.installedVersion,
                sessionId: sessionId,
                workoutId: workoutId,
                workoutName: workoutName,
                phase: phase,
                errorId: errorId,
                errorCode: errorCode,
                incidentId: incidentId,
                recoveryOfEventId: recoveryOfEventId,
                playbackImpact: playbackImpact,
                scheduled: false,
                scheduledAtMs: null,
                targetDeviceIds: targets.map((device) => device.id).toList(),
                targetDeviceNames: {
                  for (final device in targets) device.id: device.name,
                },
                targetDeviceVersions: {
                  for (final device in targets)
                    device.id: device.installedVersion,
                },
              ),
            ),
          )
          .catchError((Object _) {}),
    );
  } catch (_) {
    // Telemetry availability never changes a playback result.
  }
}
