import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';

void main() {
  test(
    'short countdown source and original start source remain distinct',
    () async {
      final native = _NativeAudio();
      final player = BeepPlayer(player: native);
      await player.playCountdown(WorkoutSound.videoBeep, 0.5);
      await player.play(WorkoutSound.videoBeep, 0.7);
      expect(native.sources, [
        'sounds/video_beep_tick.wav',
        'sounds/video_beep.wav',
      ]);
      expect(native.volumes, [0.5, 0.7]);
      await player.dispose();
    },
  );

  test(
    'new start supersedes queued countdowns without overlapping native calls',
    () async {
      final native = _NativeAudio()..configuration = Completer<void>();
      final player = BeepPlayer(player: native);
      final first = player.playCountdown(WorkoutSound.videoBeep, 1);
      await Future<void>.delayed(Duration.zero);
      final stale = player.playCountdown(WorkoutSound.videoBeep, 1);
      final start = player.play(WorkoutSound.videoBeep);
      native.configuration!.complete();
      await Future.wait([first, stale, start]);
      expect(native.sources, ['sounds/video_beep.wav']);
      expect(native.configureCalls, 1);
      await player.dispose();
    },
  );

  test('failed native request does not block following playback', () async {
    final native = _NativeAudio()..failNextStop = true;
    final player = BeepPlayer(player: native);
    await expectLater(
      player.playCountdown(WorkoutSound.videoBeep, 1),
      throwsStateError,
    );
    await player.play(WorkoutSound.videoBeep);
    expect(native.sources, ['sounds/video_beep.wav']);
    await player.dispose();
  });

  test('silent and zero volume do not configure native audio; dispose cancels pending cue', () async {
    final native = _NativeAudio();
    final player = BeepPlayer(player: native);
    await player.play(WorkoutSound.silent);
    await player.playCountdown(WorkoutSound.videoBeep, 0);
    expect(native.configureCalls, 0);
    final pending = player.playCountdown(WorkoutSound.videoBeep, 1);
    await player.dispose();
    await pending;
    expect(native.sources, isEmpty);
    expect(native.disposed, isTrue);
  });
}

class _NativeAudio implements AudioPlayer {
  final sources = <String>[];
  final volumes = <double?>[];
  Completer<void>? configuration;
  int configureCalls = 0;
  bool failNextStop = false;
  bool disposed = false;
  @override
  Future<void> setAudioContext(AudioContext ctx) async {
    configureCalls++;
    await configuration?.future;
  }

  @override
  Future<void> setReleaseMode(ReleaseMode mode) async {}
  @override
  Future<void> stop() async {
    if (failNextStop) {
      failNextStop = false;
      throw StateError('native failure');
    }
  }

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    sources.add((source as AssetSource).path);
    volumes.add(volume);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
