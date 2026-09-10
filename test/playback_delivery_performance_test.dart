import 'dart:async';

import 'package:cloud_board/src/app/feature/playback/data/datasources/playback_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/playback/data/datasources/playback_session_local_data_source.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/data/repositories/playback_repository_impl.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'remote commands are delivered before a slow checkpoint write finishes',
    () async {
      final local = _Local();
      final repository = PlaybackRepositoryImpl(_Remote(), local, 'u');
      final events = await repository.watchActive().toList();
      expect(events.last?.id, 's');
      expect(local.pending.isCompleted, isFalse);
      local.pending.complete();
    },
  );

  test(
    'unresolved owner hides but does not erase the offline checkpoint',
    () async {
      final local = _Local();
      final repository = PlaybackRepositoryImpl(_Remote(), local, null);
      expect(await repository.watchActive().toList(), [null]);
      expect(local.loads, 0);
      expect(local.clears, 0);
    },
  );

  test('playback revisions reuse the decoded immutable workout', () {
    final session = _session();
    final next = PlaybackSessionModel.fromJson({
      ...session.toJson(),
      'revision': 2,
      'remainingMs': 15000,
    });
    expect(
      identical(session.toEntity().workout, next.toEntity().workout),
      isTrue,
    );
    expect(next.toEntity().remainingMs, 15000);
  });
}

PlaybackSessionModel _session() => PlaybackSessionModel.fromWorkout(
  id: 's',
  ownerId: 'u',
  zoneId: 'main',
  targetDeviceIds: [],
  workout: Workout.empty(
    'w',
    const WorkoutAuthor(id: 'u', displayName: 'Coach', photoUrl: null),
  ),
  stepIndex: 0,
  durationMs: 60000,
  deviceId: 'd',
);

class _Remote implements PlaybackRealtimeDataSource {
  @override
  Stream<PlaybackSessionModel?> watchActive() => Stream.value(_session());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Local implements PlaybackSessionLocalDataSource {
  final pending = Completer<void>();
  int loads = 0, clears = 0;
  @override
  Future<PlaybackSessionModel?> load() async {
    loads++;
    return null;
  }

  @override
  Future<void> clear() async {
    clears++;
  }

  @override
  Future<void> save(PlaybackSessionModel session) => pending.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
