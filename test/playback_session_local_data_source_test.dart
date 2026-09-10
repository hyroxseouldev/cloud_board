import 'dart:convert';

import 'package:cloud_board/src/app/feature/playback/data/datasources/playback_session_local_data_source.dart';
import 'package:cloud_board/src/app/feature/playback/data/models/playback_session_model.dart';
import 'package:cloud_board/src/app/feature/playback/domain/entities/playback_session.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('active playback session survives a local reload', () async {
    final source = PlaybackSessionLocalDataSource(SharedPreferencesAsync());
    final workout = Workout.empty(
      'workout',
      const WorkoutAuthor(id: 'user', displayName: 'Coach', photoUrl: null),
    ).copyWith(modules: [WorkoutModule.empty('module')]);
    final session = PlaybackSessionModel.fromWorkout(
      id: 'session',
      ownerId: 'user',
      zoneId: 'main',
      targetDeviceIds: const ['display-a', 'display-b'],
      workout: workout,
      stepIndex: 0,
      durationMs: 60000,
      deviceId: 'device',
    );

    await source.save(session);
    final restored = await source.load();

    expect(restored?.id, session.id);
    expect(restored?.toEntity().workout, workout);
    expect(restored?.status, PlaybackStatus.playing.name);
  });

  test(
    'legacy checkpoint migrates and a new source restores the same workout',
    () async {
      final preferences = SharedPreferencesAsync();
      final session = _session();
      await preferences.setString(
        'xonboard.active-playback.v1',
        jsonEncode(session.toJson()),
      );
      final source = PlaybackSessionLocalDataSource(preferences);
      expect((await source.load())?.toEntity(), session.toEntity());
      expect(
        await preferences.getString('xonboard.active-playback.v1'),
        isNull,
      );
      expect(
        (await PlaybackSessionLocalDataSource(preferences).load())?.toEntity(),
        session.toEntity(),
      );
    },
  );

  test(
    'repeated checkpoints write workout once and preserve command order',
    () async {
      final preferences = _CountingPreferences();
      final source = PlaybackSessionLocalDataSource(preferences);
      final session = _session();
      await source.save(session);
      await source.save(session);
      expect(
        preferences.writes.length,
        2,
      ); // snapshot + checkpoint, no duplicate
      final pause = source.update(
        status: 'paused',
        deviceId: 'a',
        remainingMs: 42000,
      );
      final play = source.update(status: 'playing', deviceId: 'b');
      await Future.wait([pause, play]);
      expect(
        preferences.writes.where(
          (key) => key.startsWith('xonboard.playback-workout.'),
        ),
        hasLength(1),
      );
      final restored = await PlaybackSessionLocalDataSource(preferences).load();
      expect(restored?.status, 'playing');
      expect(restored?.revision, 3);
      expect(restored?.remainingMs, 42000);
      expect(restored?.toEntity().workout, session.toEntity().workout);
      final checkpoint = await preferences.getString(
        'xonboard.active-playback.v2',
      );
      expect(
        jsonDecode(checkpoint!) as Map,
        isNot(contains('workoutSnapshot')),
      );
    },
  );

  test(
    'failed checkpoint commit leaves the previous session recoverable',
    () async {
      final preferences = _CountingPreferences();
      final source = PlaybackSessionLocalDataSource(preferences);
      final previous = _session();
      await source.save(previous);
      preferences.failingKeys.add('xonboard.active-playback.v2');
      final replacement = PlaybackSessionModel.fromJson({
        ...previous.toJson(),
        'id': 'replacement',
      });
      await expectLater(source.save(replacement), throwsStateError);
      preferences.failingKeys.clear();
      final restored = await PlaybackSessionLocalDataSource(preferences).load();
      expect(restored?.id, previous.id);
      expect(restored?.toEntity().workout, previous.toEntity().workout);
    },
  );

  test('invalid local playback data is discarded', () async {
    final preferences = SharedPreferencesAsync();
    await preferences.setString('xonboard.active-playback.v1', '{broken');
    final source = PlaybackSessionLocalDataSource(preferences);

    expect(await source.load(), isNull);
    expect(await preferences.getString('xonboard.active-playback.v1'), isNull);
  });

  test('playback updates are stored before remote synchronization', () async {
    final source = PlaybackSessionLocalDataSource(SharedPreferencesAsync());
    final workout = Workout.empty(
      'workout',
      const WorkoutAuthor(id: 'user', displayName: 'Coach', photoUrl: null),
    ).copyWith(modules: [WorkoutModule.empty('module')]);
    await source.save(
      PlaybackSessionModel.fromWorkout(
        id: 'session',
        ownerId: 'user',
        zoneId: 'main',
        targetDeviceIds: const ['display-a', 'display-b'],
        workout: workout,
        stepIndex: 0,
        durationMs: 60000,
        deviceId: 'device-a',
      ),
    );

    await source.update(
      status: PlaybackStatus.paused.name,
      deviceId: 'device-b',
      stepIndex: 1,
      remainingMs: 15000,
    );
    final restored = await source.load();

    expect(restored?.status, PlaybackStatus.paused.name);
    expect(restored?.stepIndex, 1);
    expect(restored?.remainingMs, 15000);
    expect(restored?.revision, 2);
    expect(restored?.updatedByDeviceId, 'device-b');
  });
}

PlaybackSessionModel _session() => PlaybackSessionModel.fromWorkout(
  id: 'session',
  ownerId: 'user',
  zoneId: 'main',
  targetDeviceIds: ['tv'],
  workout: Workout.empty(
    'workout',
    const WorkoutAuthor(id: 'user', displayName: 'Coach', photoUrl: null),
  ).copyWith(modules: [WorkoutModule.empty('m')]),
  stepIndex: 0,
  durationMs: 60000,
  deviceId: 'device',
);

class _CountingPreferences extends SharedPreferencesAsync {
  final writes = <String>[];
  final failingKeys = <String>{};
  @override
  Future<void> setString(String key, String value) async {
    if (failingKeys.contains(key)) {
      throw StateError('disk write failed');
    }
    writes.add(key);
    await super.setString(key, value);
  }
}
