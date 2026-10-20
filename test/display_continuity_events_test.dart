import 'package:cloud_board/src/app/core/diagnostics/diagnostics_provider.dart';
import 'package:cloud_board/src/app/core/diagnostics/error_reporter.dart';
import 'package:cloud_board/src/app/core/services/firebase_account_scope.dart';
import 'package:cloud_board/src/app/feature/device/data/repositories/device_mode_repository_impl.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/device_pairing.dart';
import 'package:cloud_board/src/app/feature/device/presentation/controllers/device_pairing_controller.dart';
import 'package:cloud_board/src/app/feature/operations/data/operation_event_writer.dart';
import 'package:cloud_board/src/app/feature/operations/domain/entities/store_operations.dart';
import 'package:cloud_board/src/app/feature/operations/domain/operation_history.dart';
import 'package:cloud_board/src/app/feature/operations/domain/operations_metrics.dart';
import 'package:cloud_board/src/app/feature/operations/presentation/controllers/operation_event_recorder.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/display_playback_session.dart';
import 'package:cloud_board/src/app/feature/playback/presentation/controllers/playback_session_controller.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'support/playback_recovery_fixture.dart' show RecoveryUser;

void main() {
  test('display outage is one incident; local completion never counts as shared class completion', () async {
    final events = <OperationEvent>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    final session = PlaybackSession(
      id: 'class',
      ownerId: 'owner',
      zoneId: 'main',
      targetDeviceIds: ['tv'],
      workout: Workout.empty(
        'workout',
        const WorkoutAuthor(id: 'owner', displayName: 'Coach', photoUrl: null),
      ).copyWith(modules: [WorkoutModule.empty('one')]),
      status: PlaybackStatus.playing,
      stepIndex: 0,
      remainingMs: 10000,
      anchorServerMs: now - 60000,
      revision: 1,
      updatedByDeviceId: 'controller',
    );
    final writer = OperationEventWriter((event) async => events.add(event));
    final container = ProviderContainer(
      overrides: [
        accountOwnerIdProvider.overrideWith((_) => Stream.value('owner')),
        firebaseAccountUserProvider.overrideWith(
          (_) => Stream.value(RecoveryUser('display')),
        ),
        deviceIdProvider.overrideWith((_) async => 'tv'),
        displayDevicesProvider.overrideWith(
          (_) => Stream.value([
            const DisplayDevice(
              id: 'tv',
              name: 'TV',
              zoneId: 'main',
              zoneName: 'Main',
              paired: true,
              online: true,
              lastSeenAtMs: 0,
              currentSessionId: null,
              acknowledgedRevision: 0,
            ),
          ]),
        ),
        activePlaybackSessionProvider.overrideWith(
          (_) => Stream.value(session),
        ),
        playbackConnectionProvider.overrideWith((_) => Stream.value(false)),
        serverTimeOffsetProvider.overrideWith((_) => Stream.value(0)),
        operationEventWriterProvider.overrideWith((_) => writer),
        errorReporterProvider.overrideWith((_) => ErrorReporter(_Sink())),
      ],
    );
    addTearDown(() {
      container.dispose();
      writer.dispose();
    });
    container.listen(accountOwnerIdProvider, (_, _) {});
    container.listen(firebaseAccountUserProvider, (_, _) {});
    container.listen(deviceIdProvider, (_, _) {});
    container.listen(displayDevicesProvider, (_, _) {});
    container.listen(activePlaybackSessionProvider, (_, _) {});
    container.listen(playbackConnectionProvider, (_, _) {});
    await container.read(accountOwnerIdProvider.future);
    await container.read(firebaseAccountUserProvider.future);
    await container.read(deviceIdProvider.future);
    await container.read(displayDevicesProvider.future);
    await container.read(activePlaybackSessionProvider.future);
    await container.read(playbackConnectionProvider.future);
    final recovery = container.read(
      playbackRecoveryControllerProvider.notifier,
    );
    recovery.recordDisplayConnection(connected: false, session: session);
    recovery.recordDisplayConnection(connected: false, session: session);
    final playback = container.read(displayPlaybackSessionProvider.notifier);
    expect(playback.finishLocally(session.id), isTrue);
    expect(playback.finishLocally(session.id), isFalse);
    recovery.recordDisplayConnection(connected: true);
    recovery.recordDisplayConnection(connected: true);
    await Future<void>.delayed(Duration.zero);
    expect(events.map((e) => e.type), [
      'connection_failed',
      'display_playback_completed',
      'connection_recovered',
    ]);
    expect(events.first.incidentId, isNotNull);
    expect(events.last.recoveryOfEventId, events.first.eventId);
    expect(events.map((e) => e.connected), [false, false, true]);
    expect(events.every((e) => e.playbackImpact == 'none'), isTrue);
    expect(events[1].phase, 'local_completion');
    expect(events[1].occurredAtMs, greaterThanOrEqualTo(now));
    final report = buildOperationsRangeReport(
      events,
      range: OperationEventRange(
        startAtMs: now - 1000,
        endBeforeMs: now + 60000,
      ),
      nowMs: now + 60000,
    );
    expect(report.completedCount, 0);
    expect(report.playbackCount, 0);
    expect(report.interruptionCount, 0);
  });
}

class _Sink implements DiagnosticSink {
  @override
  Future<void> send(DiagnosticEvent event) async {}
}
