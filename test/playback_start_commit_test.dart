import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/feature/playback/data/datasources/playback_realtime_data_source.dart';
import 'package:cloud_board/src/app/feature/playback/data/datasources/playback_session_local_data_source.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/data/repositories/playback_repository_impl.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';

void main() {
  for (final change in ['cache-failure', 'account-after-commit']) {
    test(
      'committed start remains successful after $change without duplicate writes',
      () async {
        final source = _CommittedSource(
          current: change != 'account-after-commit',
        );
        final local = _Cache();
        final repository = PlaybackRepositoryImpl(source, local, 'owner');
        final result = await repository.start(
          workout: Workout.empty(
            'w',
            const WorkoutAuthor(id: 'owner', displayName: '', photoUrl: null),
          ),
          targetDeviceIds: ['tv-a', 'tv-b', 'tv-c'],
          stepIndex: 0,
          durationMs: 1000,
          deviceId: 'controller',
        );
        expect(result.status, PlaybackStatus.playing);
        expect(source.starts, 1);
        expect(local.writes, change == 'cache-failure' ? 1 : 0);
        expect(source.errors, change == 'cache-failure' ? 1 : 0);
      },
    );
  }
  for (final newer in ['revision', 'replacement', 'cleared']) {
    test(
      'late start ACK preserves $newer already delivered by the stream',
      () async {
        final source = _DelayedSource();
        final local = _MemoryCache();
        final repository = PlaybackRepositoryImpl(source, local, 'owner');
        final observed = Completer<void>();
        final subscription = repository.watchActive().listen((_) {
          if (!observed.isCompleted) observed.complete();
        });
        await source.listening.future;
        final starting = _start(repository);
        final submitted = await source.entered.future;
        final latest = newer == 'cleared'
            ? null
            : PlaybackSessionModel.fromJson({
                ...submitted.toJson(),
                'id': newer == 'replacement' ? 'other-session' : submitted.id,
                'status': 'paused',
                'revision': 2,
              });
        source.changes.add(latest);
        await observed.future;
        expect(local.cached?.id, latest?.id);
        expect(local.cached?.revision, latest?.revision);
        source.release.complete(submitted);
        expect((await starting).id, submitted.id);
        expect(local.cached?.id, latest?.id);
        expect(local.cached?.revision, latest?.revision);
        expect(local.writes, newer == 'cleared' ? 0 : 1);
        await source.changes.close();
        await subscription.cancel();
      },
    );
  }

  test(
    'a previously observed empty slot still checkpoints a confirmed new start',
    () async {
      final source = _DelayedSource();
      final local = _MemoryCache();
      final repository = PlaybackRepositoryImpl(source, local, 'owner');
      final empty = Completer<void>();
      final subscription = repository.watchActive().listen(
        (_) => empty.complete(),
      );
      await source.listening.future;
      source.changes.add(null);
      await empty.future;
      final starting = _start(repository);
      final submitted = await source.entered.future;
      source.release.complete(submitted);
      expect((await starting).id, submitted.id);
      expect(local.cached?.id, submitted.id);
      expect(local.writes, 1);
      await source.changes.close();
      await subscription.cancel();
    },
  );

  test(
    'repository forwards cancellation to the datasource before writes',
    () async {
      final source = _DelayedSource();
      final repository = PlaybackRepositoryImpl(
        source,
        _MemoryCache(),
        'owner',
      );
      var current = true;
      final starting = _start(
        repository,
        ensureCurrent: () {
          if (!current) throw StateError('cancelled');
        },
      );
      final rejected = expectLater(starting, throwsStateError);
      final submitted = await source.entered.future;
      current = false;
      source.release.complete(submitted);
      await rejected;
      expect(source.starts, 0);
      await source.changes.close();
    },
  );
}

Future<PlaybackSession> _start(
  PlaybackRepositoryImpl repository, {
  void Function()? ensureCurrent,
}) => repository.start(
  workout: Workout.empty(
    'w',
    const WorkoutAuthor(id: 'owner', displayName: '', photoUrl: null),
  ),
  targetDeviceIds: const ['tv'],
  stepIndex: 0,
  durationMs: 1000,
  deviceId: 'controller',
  ensureCurrent: ensureCurrent,
);

class _DelayedSource extends _CommittedSource {
  _DelayedSource() : super(current: true) {
    changes = StreamController<PlaybackSessionModel?>.broadcast(
      onListen: listening.complete,
    );
  }
  late final StreamController<PlaybackSessionModel?> changes;
  final listening = Completer<void>();
  final entered = Completer<PlaybackSessionModel>();
  final release = Completer<PlaybackSessionModel>();
  @override
  Stream<PlaybackSessionModel?> watchActive() => changes.stream;
  @override
  Future<PlaybackSessionModel> start(
    PlaybackSessionModel model, {
    bool scheduled = false,
    int? scheduledAtMs,
    void Function()? ensureCurrent,
  }) async {
    entered.complete(model);
    final result = await release.future;
    ensureCurrent?.call();
    starts++;
    return result;
  }
}

class _MemoryCache extends Fake implements PlaybackSessionLocalDataSource {
  PlaybackSessionModel? cached;
  int writes = 0;
  @override
  Future<PlaybackSessionModel?> load() async => cached;
  @override
  Future<void> save(PlaybackSessionModel model) async {
    writes++;
    cached = model;
  }

  @override
  Future<void> clear() async => cached = null;
}

class _CommittedSource extends Fake implements PlaybackRealtimeDataSource {
  _CommittedSource({required this.current});
  final bool current;
  int starts = 0, errors = 0;
  @override
  bool get canUseAccount => current;
  @override
  void Function(Object, StackTrace)? get onAncillaryFailure => (_, _) {
    errors++;
  };
  @override
  Future<PlaybackSessionModel> start(
    PlaybackSessionModel model, {
    bool scheduled = false,
    int? scheduledAtMs,
    void Function()? ensureCurrent,
  }) async {
    starts++;
    return model;
  }
}

class _Cache extends Fake implements PlaybackSessionLocalDataSource {
  int writes = 0;
  @override
  Future<void> save(PlaybackSessionModel model) async {
    writes++;
    throw StateError('local disk full after server commit');
  }
}
