import 'package:cloud_board/src/app/core/observability/operation_telemetry.dart';
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
    unawaited(_subscription?.cancel());
    if (!ref.mounted || epoch != _epoch) return;
    state = const DisplayPreparationState(loading: true);
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
      if (!ref.mounted || epoch != _epoch) return;
      state = DisplayPreparationState(request: request);
      _subscription = repository.watchReceipts().listen(
        (receipts) {
          if (ref.mounted && epoch == _epoch) {
            state = DisplayPreparationState(
              request: request,
              receipts: receipts,
            );
          }
        },
        onError: (Object _) {
          if (ref.mounted && epoch == _epoch) {
            state = DisplayPreparationState(
              request: request,
              error: 'TV 응답을 확인하지 못했어요. 다시 시도해 주세요.',
            );
          }
        },
      );
    } catch (_) {
      if (ref.mounted && epoch == _epoch) {
        state = const DisplayPreparationState(
          error: 'TV 준비 요청을 보내지 못했어요. 연결을 확인하고 다시 시도해 주세요.',
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
      ref
          .read(errorReporterProvider)
          .capture(
            error,
            stack,
            action: 'tv.prepare.request_read',
            context: {'attempt': attempt, 'code': code},
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
      if (code == 'permission-denied' ||
          code == 'unauthenticated' ||
          attempt == 4) {
        rethrow;
      }
      await Future<void>.delayed(Duration(seconds: 1 << (attempt - 1)));
    }
  }
}
