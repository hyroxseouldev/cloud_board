import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_position.dart';
import 'package:cloud_board/src/app/feature/image_usage/data/admission_workout_wire.dart';
import 'package:cloud_board/src/app/feature/image_usage/data/image_usage_repository.dart';
import 'package:cloud_board/src/app/feature/image_usage/domain/image_usage.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/operation_event_recorder.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/core/observability/operation_telemetry.dart';
import 'package:cloud_board/src/app/core/observability/preparation_diagnostics_provider.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/display_preparation_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
part 'display_preparation_controller.g.dart';

class DisplayPreparationState {
  const DisplayPreparationState({
    this.request,
    this.receipts = const {},
    this.error,
    this.loading = false,
    this.admission,
    this.clientFingerprint,
    this.accessChecked = false,
    this.incompatibleDeviceIds = const {},
  });
  final DisplayPreparation? request;
  final Map<String, DisplayPreparationReceipt> receipts;
  final String? error;
  final bool loading;
  final ClassAdmission? admission;
  final String? clientFingerprint;
  final bool accessChecked;
  final Set<String> incompatibleDeviceIds;
}

@riverpod
class DisplayPreparationController extends _$DisplayPreparationController {
  StreamSubscription<Map<String, DisplayPreparationReceipt>>? _subscription;
  int _epoch = 0;
  final _recorded = <String>{};
  @override
  DisplayPreparationState build() {
    ref.watch(displayPreparationRepositoryProvider);
    ref.watch(imageUsageSourceProvider);
    ref.onDispose(() {
      _epoch++;
      unawaited(_subscription?.cancel());
    });
    return const DisplayPreparationState();
  }

  Future<void> prepare(
    Workout workout,
    List<String> targets, {
    List<DisplayDevice>? candidates,
  }) async {
    final epoch = ++_epoch;
    _recorded.clear();
    unawaited(_subscription?.cancel());
    if (!ref.mounted || epoch != _epoch) return;
    state = const DisplayPreparationState(loading: true);
    final reporter = ref.read(errorReporterProvider);
    final telemetry = ref.read(operationTelemetryProvider);
    final diagnostics = ref.read(preparationDiagnosticsProvider);
    final now = DateTime.now();
    final requestId =
        'prepare-${now.microsecondsSinceEpoch.toRadixString(36)}-$epoch';
    final attempt = telemetry.start(
      'tv.prepare.request',
      trace: {
        ...diagnostics.snapshot(),
        'requestId': requestId,
        'targetCount': targets.length,
      },
    );
    var incompatible = const <String>{};
    try {
      final repository = ref.read(displayPreparationRepositoryProvider);
      final usage = ref.read(imageUsageSourceProvider);
      final enrolled = await usage.enrolled();
      if (!ref.mounted || epoch != _epoch) return;
      // Enrollment is resolved once by the existing access check. Do not send
      // known-incompatible displays to admission, where one rejects the entire
      // cohort. Legacy accounts keep their existing preparation protocol support.
      if (candidates != null) {
        final required = requiredTimingProtocol(workout);
        incompatible = Set.unmodifiable(
          candidates
              .where(
                (device) =>
                    targets.contains(device.id) &&
                    (device.playbackProtocol < required ||
                        (enrolled &&
                            (device.imageUsageProtocol != 1 ||
                                device.preparationProtocol < 2 ||
                                device.playbackProtocol < 2))),
              )
              .map((device) => device.id),
        );
        targets = List.unmodifiable(
          targets.where((id) => !incompatible.contains(id)),
        );
        state = DisplayPreparationState(
          loading: true,
          incompatibleDeviceIds: incompatible,
        );
        if (targets.isEmpty) {
          // Empty targets mean broadcast/controller-only in older contracts.
          // Here they mean no compatible TV, so never make that admission call.
          state = DisplayPreparationState(
            accessChecked: true,
            incompatibleDeviceIds: incompatible,
          );
          attempt.success();
          return;
        }
      }
      ClassAdmission? admission;
      final fingerprint = preparationFingerprint(workout, targets);
      DisplayPreparation? request;
      if (enrolled) {
        admission = await usage.prepare(
          workout: admissionWorkoutWire(workout),
          targets: targets,
          controllerDeviceId: await ref.read(deviceIdProvider.future),
          clientFingerprint: fingerprint,
        );
        if (!ref.mounted || epoch != _epoch) return;
        if (admission.pending || admission.status == 'active') {
          throw const ImageUsageFailure('start_pending', retryable: true);
        }
        // The server publishes after reservation; never client-write a fallback.
        request = await repository.current();
        if (request == null ||
            request.sessionId != admission.sessionId ||
            request.manifestHash != admission.manifestHash) {
          throw const ImageUsageFailure('service_unavailable', retryable: true);
        }
      } else if (targets.isNotEmpty) {
        request = prepareDisplayCandidate(
          workout,
          targets,
          sessionId: requestId,
          revision: epoch,
          nowMs: preparationServerNow(
            ref.read(serverTimeOffsetProvider).value ?? 0,
          ),
        );
        await diagnostics.observeRequest(
          write: () => repository.request(request!),
          attempt: attempt,
          requestId: requestId,
          superseded: () => !ref.mounted || epoch != _epoch,
        );
      }
      if (request == null) {
        if (ref.mounted && epoch == _epoch) {
          state = DisplayPreparationState(
            accessChecked: true,
            incompatibleDeviceIds: incompatible,
            clientFingerprint: fingerprint,
          );
        }
        attempt.success();
        return;
      }
      final acceptedRequest = request;
      attempt.success(
        trace: {
          ...diagnostics.snapshot(),
          'superseded': !ref.mounted || epoch != _epoch,
        },
      );
      if (!ref.mounted || epoch != _epoch) return;
      state = DisplayPreparationState(
        request: acceptedRequest,
        incompatibleDeviceIds: incompatible,
        admission: admission,
        clientFingerprint: fingerprint,
        accessChecked: true,
      );
      _subscription = repository.watchReceipts().listen(
        (receipts) {
          if (ref.mounted && epoch == _epoch) {
            state = DisplayPreparationState(
              request: acceptedRequest,
              incompatibleDeviceIds: incompatible,
              receipts: receipts,
              admission: admission,
              clientFingerprint: fingerprint,
              accessChecked: true,
            );
            final devices = ref.read(displayDevicesProvider).value ?? const [];
            for (final display in devices.where(
              (device) => targets.contains(device.id),
            )) {
              final receipt = receipts[display.id];
              if (receipt == null ||
                  receipt.sessionId != acceptedRequest.sessionId ||
                  receipt.revision != acceptedRequest.revision ||
                  receipt.manifestHash != acceptedRequest.manifestHash ||
                  (receipt.status != 'ready' && receipt.status != 'failed')) {
                continue;
              }
              final ready = receipt.readyFor(
                acceptedRequest,
                preparationServerNow(
                  ref.read(serverTimeOffsetProvider).value ?? 0,
                ),
              );
              if (!ready && receipt.status != 'failed') continue;
              final key =
                  '${acceptedRequest.sessionId}-${display.id}-${receipt.status}';
              if (!_recorded.add(key)) continue;
              recordOperationEvent(
                ref,
                type: ready ? 'preparation_ready' : 'preparation_failed',
                phase: 'tv_preparation',
                eventId: key,
                sessionId: acceptedRequest.sessionId,
                workoutId: workout.id,
                workoutName: workout.name,
                display: display,
                errorCode: ready ? null : 'preparation_failed',
              );
            }
          }
        },
        onError: (Object error, StackTrace stack) {
          final failure = telemetry.start(
            'tv.prepare.receipts',
            trace: {
              ...diagnostics.snapshot(),
              'requestId': requestId,
              'targetCount': targets.length,
            },
          );
          failure.failure(
            'prepare_receipts',
            trace: {'transportCode': operationFailureCode(error)},
          );
          reporter.capture(
            error,
            stack,
            action: 'tv.prepare.receipts',
            context: {
              'operationId': failure.id,
              'preparationStage': 'receipts',
              'sessionId': acceptedRequest.sessionId,
              'expectedRevision': acceptedRequest.revision,
            },
          );
          if (ref.mounted && epoch == _epoch) {
            state = DisplayPreparationState(
              request: acceptedRequest,
              incompatibleDeviceIds: incompatible,
              error: 'TV 응답을 확인하지 못했어요. 다시 시도해 주세요.',
            );
          }
        },
      );
    } catch (error, stack) {
      attempt.failure(
        'prepare_request',
        trace: {
          ...diagnostics.snapshot(),
          'superseded': !ref.mounted || epoch != _epoch,
          'transportCode': operationFailureCode(error),
        },
      );
      final diagnostic = reporter.capture(
        error,
        stack,
        action: 'tv.prepare.request',
        context: {
          'operationId': attempt.id,
          'preparationStage': 'request',
          'sessionId': requestId,
          'workoutId': workout.id,
        },
      );
      if (ref.mounted && epoch == _epoch) {
        recordOperationEvent(
          ref,
          type: 'preparation_failed',
          phase: 'preparation_request',
          eventId: diagnostic.id,
          errorId: diagnostic.id,
          errorCode: 'request_failed',
          workoutId: workout.id,
          workoutName: workout.name,
        );
        state = DisplayPreparationState(
          incompatibleDeviceIds: incompatible,
          error: error is ImageUsageFailure
              ? error.message
              : 'TV 준비 요청을 보내지 못했어요. 연결을 확인하고 다시 시도해 주세요.',
        );
      }
    }
  }
}

// This stream owns its bounded retries. Riverpod's default error retry would
// restart a denied subscription indefinitely and defeat the permission stop.
Duration? _noAutomaticPreparationRetry(int attempt, Object error) => null;

@Riverpod(retry: _noAutomaticPreparationRetry)
Stream<DisplayPreparation?> displayPreparationRequest(
  Ref ref,
  String deviceId,
) async* {
  final repository = ref.watch(displayPreparationRepositoryProvider);
  var cancelled = false;
  ref.onDispose(() => cancelled = true);
  for (var attempt = 1; attempt <= 4; attempt++) {
    if (cancelled) return;
    try {
      await for (final request in repository.watchRequest(deviceId)) {
        if (cancelled) return;
        unawaited(
          repository
              .reportHealth(deviceId, stage: 'request_read')
              .catchError((Object _) {}),
        );
        yield request;
      }
      return;
    } catch (error, stack) {
      if (cancelled) return;
      final code = operationFailureCode(error);
      final failure = ref
          .read(operationTelemetryProvider)
          .start('tv.prepare.listen');
      failure.failure('prepare_listen');
      ref
          .read(errorReporterProvider)
          .capture(
            error,
            stack,
            action: 'tv.prepare.request_read',
            context: {
              'operationId': failure.id,
              'preparationStage': 'listen',
              'retryCount': attempt,
              'firebaseCode': code,
            },
          );
      unawaited(
        repository
            .reportHealth(
              deviceId,
              stage: 'request_read',
              code: code,
              attempt: attempt,
            )
            .catchError((Object _) {}),
      );
      // Expose the error immediately so cached candidate work is cancelled
      // while this same provider owns the bounded backoff/re-subscription.
      yield* Stream<DisplayPreparation?>.error(error, stack);
      if (code == 'permission-denied' ||
          code == 'unauthenticated' ||
          attempt == 4) {
        return;
      }
      await Future<void>.delayed(Duration(seconds: 1 << (attempt - 1)));
    }
  }
}
