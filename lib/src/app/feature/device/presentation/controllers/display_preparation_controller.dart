import 'package:cloud_board/src/app/feature/operations/presentation/controllers/operation_event_recorder.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/core/observability/operation_telemetry.dart';
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
  });
  final DisplayPreparation? request;
  final Map<String, DisplayPreparationReceipt> receipts;
  final String? error;
  final bool loading;
}

@riverpod
class DisplayPreparationController extends _$DisplayPreparationController {
  StreamSubscription<Map<String, DisplayPreparationReceipt>>? _subscription;
  int _epoch = 0;
  final _recorded = <String>{};
  @override
  DisplayPreparationState build() {
    ref.watch(displayPreparationRepositoryProvider);
    ref.onDispose(() {
      _epoch++;
      unawaited(_subscription?.cancel());
    });
    return const DisplayPreparationState();
  }

  Future<void> prepare(Workout workout, List<String> targets) async {
    final epoch = ++_epoch;
    _recorded.clear();
    unawaited(_subscription?.cancel());
    if (!ref.mounted || epoch != _epoch) return;
    state = const DisplayPreparationState(loading: true);
    final reporter = ref.read(errorReporterProvider);
    final telemetry = ref.read(operationTelemetryProvider);
    final attempt = telemetry.start('tv.prepare.request');
    try {
      final repository = ref.read(displayPreparationRepositoryProvider);
      final now = DateTime.now();
      final request = prepareDisplayCandidate(
        workout,
        targets,
        sessionId:
            'prepare-${now.microsecondsSinceEpoch.toRadixString(36)}-$epoch',
        revision: epoch,
        nowMs: preparationServerNow(
          ref.read(serverTimeOffsetProvider).value ?? 0,
        ),
      );
      await repository.request(request).timeout(const Duration(seconds: 8));
      attempt.success();
      if (!ref.mounted || epoch != _epoch) return;
      state = DisplayPreparationState(request: request);
      _subscription = repository.watchReceipts().listen(
        (receipts) {
          if (ref.mounted && epoch == _epoch) {
            state = DisplayPreparationState(
              request: request,
              receipts: receipts,
            );
            final devices = ref.read(displayDevicesProvider).value ?? const [];
            for (final display in devices.where(
              (device) => targets.contains(device.id),
            )) {
              final receipt = receipts[display.id];
              if (receipt == null ||
                  receipt.sessionId != request.sessionId ||
                  receipt.revision != request.revision ||
                  receipt.manifestHash != request.manifestHash ||
                  (receipt.status != 'ready' && receipt.status != 'failed')) {
                continue;
              }
              final ready = receipt.readyFor(
                request,
                preparationServerNow(
                  ref.read(serverTimeOffsetProvider).value ?? 0,
                ),
              );
              if (!ready && receipt.status != 'failed') continue;
              final key =
                  '${request.sessionId}-${display.id}-${receipt.status}';
              if (!_recorded.add(key)) continue;
              recordOperationEvent(
                ref,
                type: ready ? 'preparation_ready' : 'preparation_failed',
                phase: 'tv_preparation',
                eventId: key,
                sessionId: request.sessionId,
                workoutId: workout.id,
                workoutName: workout.name,
                display: display,
                errorCode: ready ? null : 'preparation_failed',
              );
            }
          }
        },
        onError: (Object error, StackTrace stack) {
          final failure = telemetry.start('tv.prepare.receipts');
          failure.failure('prepare_receipts');
          reporter.capture(
            error,
            stack,
            action: 'tv.prepare.receipts',
            context: {
              'operationId': failure.id,
              'preparationStage': 'receipts',
              'sessionId': request.sessionId,
              'expectedRevision': request.revision,
            },
          );
          if (ref.mounted && epoch == _epoch) {
            state = DisplayPreparationState(
              request: request,
              error: 'TV 응답을 확인하지 못했어요. 다시 시도해 주세요.',
            );
          }
        },
      );
    } catch (error, stack) {
      attempt.failure('prepare_request');
      final diagnostic = reporter.capture(
        error,
        stack,
        action: 'tv.prepare.request',
        context: {
          'operationId': attempt.id,
          'preparationStage': 'request',
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
        state = const DisplayPreparationState(
          error: 'TV 준비 요청을 보내지 못했어요. 연결을 확인하고 다시 시도해 주세요.',
        );
      }
    }
  }
}

@riverpod
Stream<DisplayPreparation?> displayPreparationRequest(
  Ref ref,
  String deviceId,
) => ref.watch(displayPreparationRepositoryProvider).watchRequest(deviceId);
