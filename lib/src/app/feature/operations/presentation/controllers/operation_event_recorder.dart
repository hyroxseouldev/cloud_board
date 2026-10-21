import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart'
    show serverTimeOffsetProvider, playbackConnectionProvider;

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostic_queue.dart';
import 'package:cloud_board/src/app/feature/operations/data/models/store_operations_models.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/core/services/event_id.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/operations/data/operation_event_writer.dart';
import 'package:cloud_board/src/app/feature/operations/data/repositories/store_operations_repository_impl.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';

part 'operation_event_recorder.g.dart';

String? _operationScope(Ref ref) {
  final owner = ref.read(accountOwnerIdProvider);
  final user = ref.read(firebaseAccountUserProvider);
  final device = ref.read(deviceIdProvider);
  if (owner.isLoading ||
      owner.hasError ||
      owner.value == null ||
      user.isLoading ||
      user.hasError ||
      user.value == null ||
      device.isLoading ||
      device.hasError ||
      device.value == null) {
    return null;
  }
  return jsonEncode([
    owner.value,
    user.value!.uid,
    user.value!.isAnonymous,
    device.value,
  ]);
}

/// Reuse the bounded diagnostics outbox, but send the original operation model
/// to its existing RTDB path. One queue survives identity changes so writes from
/// an old scope cannot race a new scope's local persistence.
@Riverpod(keepAlive: true)
DiagnosticQueue operationEventQueue(Ref ref) {
  final app = ref.watch(firebaseClientAuthProvider).app;
  final preferences = SharedPreferencesAsync();
  final key = 'cloudboard.operations.v1.${app.options.projectId}.${app.name}';
  final queue = DiagnosticQueue(
    read: () => preferences.getString(key),
    write: (value) => value == null
        ? preferences.remove(key)
        : preferences.setString(key, value),
    send: (value, account) async {
      if (!ref.mounted || _operationScope(ref) != account) {
        throw StateError('Operation event authorization scope changed');
      }
      final model = OperationEventModel.fromJson(
        Map<String, dynamic>.from(value['operation'] as Map),
      );
      await ref
          .read(storeOperationsRepositoryProvider)
          .recordDetailedEvent(model.toEntity());
    },
  );
  ref.onDispose(queue.dispose);
  return queue;
}

@Riverpod(keepAlive: true)
OperationEventWriter operationEventWriter(Ref ref) {
  ref.watch(
    firebaseAccountUserProvider.select(
      (value) => (
        value.value?.uid,
        value.value?.isAnonymous,
        value.isLoading || value.hasError,
      ),
    ),
  );
  ref.watch(accountOwnerIdProvider);
  ref.watch(deviceIdProvider);
  final queue = ref.watch(operationEventQueueProvider);
  unawaited(queue.setAccount(_operationScope(ref)).catchError((Object _) {}));
  final writer = OperationEventWriter(
    ref.watch(storeOperationsRepositoryProvider).recordDetailedEvent,
    retryQueue: queue,
  );
  ref.onDispose(writer.dispose);
  ref.listen(playbackConnectionProvider, (_, next) {
    if (next.value == true) unawaited(queue.flush().catchError((Object _) {}));
  });
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
  bool? connected,
  List<DisplayDevice> targets = const [],
}) {
  AccountOperationScope? scope;
  try {
    scope = AccountOperationScope.capture(ref);
    if (scope == null) return;
    final capturedScope = scope;
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
          .then((resolvedId) {
            if (!capturedScope.isCurrent) return Future<void>.value();
            return writer.record(
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
                connected: connected,
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
            );
          })
          .catchError((Object _) {})
          .whenComplete(capturedScope.close),
    );
  } catch (_) {
    scope?.close();
    // Telemetry availability never changes a playback result.
  }
}
