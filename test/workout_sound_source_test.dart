import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_board/src/app/core/services/beep_player.dart';
import 'package:cloud_board/src/app/feature/device/domain/entities/display_preparation.dart';
import 'package:cloud_board/src/app/feature/device/domain/usecases/prepare_display_media.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout.dart';
import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, Uint8List> recordings;
  setUpAll(() async {
    recordings = {
      for (final path in [
        'assets/sounds/video_beep.wav',
        'assets/sounds/video_beep_tick.wav',
      ])
        path: await File(path).readAsBytes(),
    };
  });

  test('prepared web recordings survive offline playback and player remount', () async {
    final bundle = _Bundle(recordings);
    final cache = WorkoutSoundSourceCache(bundle: bundle, web: true);
    final preparation = _Audio();
    final result = await _prepare(cache, preparation);
    expect(result!.audioReady, isTrue);
    expect(result.ready, isTrue);
    expect(bundle.loads, hasLength(2));
    expect(preparation.prepared, everyElement(isA<BytesSource>()));
    await preparation.dispose();
    bundle.offline = true;

    for (var mount = 0; mount < 2; mount++) {
      final output = _Audio();
      final player = BeepPlayer(player: output, soundSources: cache);
      for (var cue = 0; cue < 3; cue++) {
        await player.playCountdown(WorkoutSound.videoBeep, .5);
        await player.play(WorkoutSound.videoBeep);
      }
      expect(output.played, hasLength(6));
      for (var i = 0; i < output.played.length; i++) {
        final source = output.played[i] as BytesSource;
        expect(source.mimeType, 'audio/wav');
        expect(
          source.bytes,
          orderedEquals(recordings.values.elementAt(i.isEven ? 1 : 0)),
        );
        expect(source, same(preparation.prepared[i.isEven ? 1 : 0]));
      }
      await player.dispose();
    }
    // Any later bundle/network access would throw, not silently hit HTTP cache.
    expect(bundle.loads, hasLength(2));
  });

  test('failed asset preparation is not ready and can retry', () async {
    final bundle = _Bundle(recordings)..offline = true;
    final cache = WorkoutSoundSourceCache(bundle: bundle, web: true);
    final output = _Audio();
    final failed = await _prepare(cache, output);
    expect(failed!.ready, isFalse);
    expect(failed.audioReady, isFalse);
    expect(output.prepared, isEmpty);
    bundle.offline = false;
    final retried = await _prepare(cache, output);
    expect(retried!.ready, isTrue);
    expect(retried.audioReady, isTrue);
    expect(bundle.loads, hasLength(3));
  });

  test(
    'cached bytes still require the audio player to accept the source',
    () async {
      final cache = WorkoutSoundSourceCache(
        bundle: _Bundle(recordings),
        web: true,
      );
      final result = await _prepare(cache, _Audio()..failPrepare = true);
      expect(result!.ready, isFalse);
      expect(result.audioReady, isFalse);
    },
  );

  test(
    'invalid and oversized bundled recordings cannot become ready',
    () async {
      for (final bytes in [
        Uint8List(44),
        Uint8List(WorkoutSoundSourceCache.maxAssetBytes + 1),
      ]) {
        final cache = WorkoutSoundSourceCache(
          bundle: _Bundle({
            ...recordings,
            'assets/sounds/video_beep.wav': bytes,
          }),
          web: true,
        );
        final result = await _prepare(cache, _Audio());
        expect(result!.ready, isFalse);
        expect(result.audioReady, isFalse);
      }
    },
  );

  test('concurrent preparation shares a single asset load', () async {
    final bundle = _Bundle(recordings)..gate = Completer<void>();
    final cache = WorkoutSoundSourceCache(bundle: bundle, web: true);
    final first = cache.source(WorkoutSound.videoBeep);
    final second = cache.source(WorkoutSound.videoBeep);
    expect(bundle.loads, hasLength(1));
    bundle.gate!.complete();
    expect(await first, same(await second));
  });

  test('disabling audio while bytes load cancels the stale cue', () async {
    final bundle = _Bundle(recordings)..gate = Completer<void>();
    final cache = WorkoutSoundSourceCache(bundle: bundle, web: true);
    final output = _Audio();
    final player = BeepPlayer(player: output, soundSources: cache);
    final cue = player.play(WorkoutSound.videoBeep);
    await Future<void>.delayed(Duration.zero);
    expect(bundle.loads, hasLength(1));
    final stop = player.setEnabled(false);
    bundle.gate!.complete();
    await Future.wait([cue, stop]);
    expect(output.played, isEmpty);
    bundle.offline = true;
    await player.setEnabled(true);
    expect(output.played, isEmpty);
    await player.play(WorkoutSound.videoBeep);
    expect(output.played, hasLength(1));
    expect(bundle.loads, hasLength(1));
    await player.dispose();
  });

  test(
    'native recordings keep AssetSource without loading web bytes',
    () async {
      final bundle = _Bundle(recordings)..offline = true;
      final cache = WorkoutSoundSourceCache(bundle: bundle, web: false);
      expect(
        (await cache.source(WorkoutSound.videoBeep) as AssetSource).path,
        'sounds/video_beep.wav',
      );
      expect(
        (await cache.source(
          WorkoutSound.videoBeep,
          countdown: true,
        ) as AssetSource).path,
        'sounds/video_beep_tick.wav',
      );
      expect(bundle.loads, isEmpty);
    },
  );
}

Future<DisplayMediaPreparationResult?> _prepare(
  WorkoutSoundSourceCache cache,
  _Audio player,
) {
  final workout = Workout.empty(
    'sound-test',
    const WorkoutAuthor(id: 'owner', displayName: '', photoUrl: null),
  );
  final request = prepareDisplayCandidate(
    workout,
    ['display'],
    sessionId: 'prepare-sound',
    revision: 1,
    nowMs: 0,
  );
  return prepareDisplayMedia(
    request,
    images: (_) async => 0,
    audio: (_) async {
      await player.setSource(await cache.source(WorkoutSound.videoBeep));
      await player.setSource(
        await cache.source(WorkoutSound.videoBeep, countdown: true),
      );
    },
    cancelled: () => false,
  );
}

class _Bundle extends CachingAssetBundle {
  _Bundle(this.recordings);
  final Map<String, Uint8List> recordings;
  final loads = <String>[];
  bool offline = false;
  Completer<void>? gate;
  @override
  Future<ByteData> load(String key) async {
    loads.add(key);
    if (offline) throw StateError('network unavailable');
    await gate?.future;
    return ByteData.sublistView(recordings[key]!);
  }
}

class _Audio implements AudioPlayer {
  final prepared = <Source>[];
  final played = <Source>[];
  bool failPrepare = false;
  @override
  Future<void> setSource(Source source) async {
    if (failPrepare) throw StateError('decode failure');
    prepared.add(source);
  }

  @override
  Future<void> setAudioContext(AudioContext ctx) async {}
  @override
  Future<void> setReleaseMode(ReleaseMode mode) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    played.add(source);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
