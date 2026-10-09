import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_command.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_failure.dart';
import 'package:cloud_board/src/app/feature/playback/domain/playback_position.dart';
import 'package:cloud_board/src/app/feature/playback/data/datasources/playback_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/data/datasources/playback_session_local_data_source.dart';
import 'package:cloud_board/src/app/feature/playback/data/repositories/playback_repository_impl.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/workout_metrics.dart';
import 'package:cloud_board/src/app/feature/workouts/presentation/controllers/player_controller.dart';

Workout get workout =>
    Workout.empty(
      'w',
      const WorkoutAuthor(id: 'u', displayName: 'test', photoUrl: null),
    ).copyWith(
      countdownSeconds: 0,
      modules: [
        WorkoutModule.empty('m')
            .copyWith(sets: 2, workSeconds: 10, restSeconds: 5),
      ],
    );
PlaybackSessionModel get model => PlaybackSessionModel.fromJson({
  ...PlaybackSessionModel.fromWorkout(
    id: 's',
    ownerId: 'u',
    zoneId: 'main',
    targetDeviceIds: [],
    workout: workout,
    stepIndex: 0,
    durationMs: 10000,
    deviceId: 'c',
  ).toJson(),
  'anchorServerMs': 1000,
});

void main() {
  test('initial offline handshake waits for connected; timeout has an actionable code', () async {
    final stream = StreamController<bool>();
    var finished = false;
    final pending = waitForPlaybackConnection(stream.stream)
        .then((_) => finished = true);
    stream.add(false);
    await Future<void>.delayed(Duration.zero);
    expect(finished, isFalse);
    stream.add(true);
    await pending;
    await stream.close();
    await expectLater(
      waitForPlaybackConnection(
        const Stream<bool>.empty(),
        timeout: const Duration(milliseconds: 1),
      ),
      throwsA(anything),
    );
    final never = StreamController<bool>();
    await expectLater(
      waitForPlaybackConnection(
        never.stream,
        timeout: const Duration(milliseconds: 1),
      ),
      throwsA(
        isA<PlaybackFailure>().having(
          (e) => e.code,
          'code',
          'connection_timeout',
        ),
      ),
    );
    await never.close();
  });
  test(
    'simultaneous pause/seek/end commands retain exact conflicting revisions',
    () {
      final first = model.toEntity();
      for (final intent in ['paused', null, 'completed']) {
        final changed = first.copyWith(
          revision: 2,
          status: PlaybackStatus.paused,
        );
        expect(
          () => resolvePlaybackCommand(
            session: changed,
            expectedSessionId: 's',
            expectedRevision: 1,
            serverNowMs: 2000,
            expiresAtMs: 7000,
            status: intent,
            stepIndex: intent == null ? 1 : null,
          ),
          throwsA(
            isA<PlaybackFailure>()
                .having((e) => e.code, 'code', 'revision_conflict')
                .having((e) => e.expectedRevision, 'expected', 1)
                .having((e) => e.observedRevision, 'observed', 2),
          ),
        );
      }
      expect(
        () => resolvePlaybackCommand(
          session: first,
          expectedSessionId: 'old',
          expectedRevision: 1,
          serverNowMs: 2000,
          expiresAtMs: 7000,
          status: 'paused',
        ),
        throwsA(
          isA<PlaybackFailure>().having(
            (e) => e.code,
            'code',
            'session_changed',
          ),
        ),
      );
    },
  );
  test('invalid timeline indices fail explicitly, completed empty timeline is safe', () {
    final initial = model.toEntity();
    for (final index in [-1, 100]) {
      expect(
        () => playbackPosition(
          initial.copyWith(stepIndex: index),
          playbackDurations(workout),
          2000,
        ),
        throwsA(
          isA<PlaybackFailure>().having(
            (e) => e.code,
            'code',
            'invalid_position',
          ),
        ),
      );
    }
    expect(
      playbackPosition(
        initial.copyWith(status: PlaybackStatus.completed),
        [],
        2000,
      ).index,
      0,
    );
  });
  test('new final rests agree between totals, local steps and remote timeline; old snapshot unchanged', () {
    expect(workoutDuration(workout), 30);
    expect(playbackDurations(workout), [10000, 5000, 10000, 5000]);
    expect(buildPlayerSteps(workout).map((s) => s.duration), [10, 5, 10, 5]);
    final legacyJson = {
      ...model.toJson(),
      'workoutSnapshot': {
        ...model.workoutSnapshot,
        'modules': [
          for (final module in model.workoutSnapshot['modules'] as List)
            Map<String, dynamic>.from(module as Map)
              ..remove('includeFinalRest'),
        ],
      },
    };
    final legacy = PlaybackSessionModel.fromJson(legacyJson).toEntity().workout;
    expect(playbackDurations(legacy), [10000, 5000, 10000]);
    expect(workoutDuration(legacy), 25);
    expect(buildPlayerSteps(legacy).map((s) => s.duration), [10, 5, 10]);
    final noRest = workout.copyWith(
      modules: [WorkoutModule.empty('zero').copyWith(restSeconds: 0)],
    );
    expect(buildPlayerSteps(noRest).length, 1);
    expect(
      workoutDuration(
        workout.copyWith(modules: [...workout.modules, ...workout.modules]),
      ),
      60,
    );
  });
  test('paused preparation freezes remaining delay, resume continues, start-now exits preparation', () {
    final initial = model.toEntity().copyWith(startDelayMs: 10000);
    final paused = initial.copyWith(
      status: PlaybackStatus.paused,
      startDelayMs: 7000,
      anchorServerMs: 4000,
      revision: 2,
    );
    expect(
      playbackPosition(initial, playbackDurations(workout), 4000).countdownMs,
      7000,
    );
    expect(
      playbackPosition(paused, playbackDurations(workout), 99000).countdownMs,
      7000,
    );
    final resumed = paused.copyWith(
      status: PlaybackStatus.playing,
      anchorServerMs: 100000,
    );
    expect(
      playbackPosition(resumed, playbackDurations(workout), 102000).countdownMs,
      5000,
    );
    final start = resolvePlaybackCommand(
      session: paused,
      expectedSessionId: 's',
      expectedRevision: 2,
      serverNowMs: 5000,
      expiresAtMs: 11000,
      status: null,
      stepIndex: 0,
      remainingMs: 10000,
    );
    expect(start.status, 'playing');
    expect(start.remainingMs, 10000);
  });
  test('command ACK becomes baseline before slow checkpoint, without resurrecting removed session', () async {
    final remote = _Remote();
    final local = _Local();
    final repo = PlaybackRepositoryImpl(remote, local, 'u');
    final subscription = repo.watchActive().listen((_) {});
    await Future<void>.delayed(Duration.zero);
    remote.stream.add(model);
    await Future<void>.delayed(Duration.zero);
    await repo.pause(remainingMs: 10000, deviceId: 'c');
    await repo.resume(deviceId: 'c');
    expect(remote.revisions, [1, 2]);
    expect(local.pending.isCompleted, isFalse);
    remote.stream.add(null);
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      repo.pause(remainingMs: 10000, deviceId: 'c'),
      throwsStateError,
    );
    local.pending.complete();
    await remote.stream.close();
    await subscription.cancel();
  });
}

class _Remote extends Fake implements PlaybackRealtimeDataSource {
  final stream = StreamController<PlaybackSessionModel?>.broadcast();
  final revisions = <int>[];
  @override
  Stream<PlaybackSessionModel?> watchActive() => stream.stream;
  @override
  Future<PlaybackSessionModel> update({
    required String? status,
    required String deviceId,
    int? stepIndex,
    int? remainingMs,
    int startDelayMs = 0,
    bool requireBriefing = false,
    bool finishTimer = false,
    required String expectedSessionId,
    required int expectedRevision,
  }) async {
    revisions.add(expectedRevision);
    return PlaybackSessionModel.fromJson({
      ...model.toJson(),
      'revision': expectedRevision + 1,
      'status': status,
    });
  }
}

class _Local extends Fake implements PlaybackSessionLocalDataSource {
  final pending = Completer<void>();
  @override
  Future<PlaybackSessionModel?> load() async => model;
  @override
  Future<void> save(PlaybackSessionModel session) => pending.future;
  @override
  Future<void> clear() async {}
}
