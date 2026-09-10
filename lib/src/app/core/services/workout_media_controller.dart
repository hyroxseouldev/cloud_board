import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workout_media_controller.g.dart';

enum WorkoutMediaCommand { play, pause, next, previous, stop }

class WorkoutMediaSnapshot {
  const WorkoutMediaSnapshot({
    required this.sessionId,
    required this.workoutName,
    required this.slideName,
    required this.statusLabel,
    required this.durationMs,
    required this.remainingMs,
    required this.stepIndex,
    required this.isPaused,
  });

  final String sessionId;
  final String workoutName;
  final String slideName;
  final String statusLabel;
  final int durationMs;
  final int remainingMs;
  final int stepIndex;
  final bool isPaused;

  Map<String, dynamic> toMap() => {
    'sessionId': sessionId,
    'workoutName': workoutName,
    'slideName': slideName,
    'statusLabel': statusLabel,
    'durationMs': durationMs,
    'remainingMs': remainingMs,
    'stepIndex': stepIndex,
    'isPaused': isPaused,
  };
}

abstract interface class WorkoutMediaController {
  Stream<WorkoutMediaCommand> get commands;

  Future<void> show(WorkoutMediaSnapshot snapshot);

  Future<void> hide();
}

class _NoopWorkoutMediaController implements WorkoutMediaController {
  const _NoopWorkoutMediaController();

  @override
  Stream<WorkoutMediaCommand> get commands => const Stream.empty();

  @override
  Future<void> show(WorkoutMediaSnapshot snapshot) async {}

  @override
  Future<void> hide() async {}
}

class _AudioServiceWorkoutMediaController implements WorkoutMediaController {
  const _AudioServiceWorkoutMediaController(this._handler);

  final AudioHandler _handler;

  @override
  Stream<WorkoutMediaCommand> get commands => _handler.customEvent
      .where((event) => event is String)
      .map(
        (event) => WorkoutMediaCommand.values.firstWhere(
          (command) => command.name == event,
        ),
      );

  @override
  Future<void> show(WorkoutMediaSnapshot snapshot) =>
      _handler.customAction('showWorkout', snapshot.toMap());

  @override
  Future<void> hide() => _handler.customAction('hideWorkout');
}

/// A stable command stream survives lazy initialization. Operations are ordered
/// so leaving the player during initialization cannot leave a notification behind.
class LazyWorkoutMediaController implements WorkoutMediaController {
  LazyWorkoutMediaController(this._create);

  final Future<WorkoutMediaController> Function() _create;
  final _commands = StreamController<WorkoutMediaCommand>.broadcast();
  WorkoutMediaController? _delegate;
  Future<void> _pending = Future.value();
  StreamSubscription<WorkoutMediaCommand>? _subscription;

  @override
  Stream<WorkoutMediaCommand> get commands => _commands.stream;

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _pending.then((_) => action());
    _pending = operation.catchError((Object error, StackTrace stack) {
      debugPrint('Workout media controls unavailable: $error\n$stack');
    });
    return _pending;
  }

  @override
  Future<void> show(WorkoutMediaSnapshot snapshot) => _enqueue(() async {
    if (_delegate == null) {
      _delegate = await _create();
      _subscription = _delegate!.commands.listen(_commands.add);
    }
    await _delegate!.show(snapshot);
  });

  @override
  Future<void> hide() => _enqueue(() async => _delegate?.hide());

  Future<void> dispose() => _enqueue(() async {
    await _delegate?.hide();
    await _subscription?.cancel();
    await _commands.close();
  });
}

Future<WorkoutMediaController> _createWorkoutMediaController() async {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.iOS &&
          defaultTargetPlatform != TargetPlatform.android)) {
    return const _NoopWorkoutMediaController();
  }
  try {
    final handler = await AudioService.init(
      builder: _WorkoutAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.sunmkim.cloudboard.workout',
        androidNotificationChannelName: '진행 중인 수업',
        androidStopForegroundOnPause: false,
      ),
    );
    return _AudioServiceWorkoutMediaController(handler);
  } catch (error, stackTrace) {
    debugPrint('Workout media controls unavailable: $error\n$stackTrace');
    rethrow;
  }
}

@Riverpod(keepAlive: true)
WorkoutMediaController workoutMediaController(Ref ref) {
  final controller = LazyWorkoutMediaController(_createWorkoutMediaController);
  ref.onDispose(() => unawaited(controller.dispose()));
  return controller;
}

class _WorkoutAudioHandler extends BaseAudioHandler {
  _WorkoutAudioHandler();

  final AudioPlayer _backgroundPlayer = AudioPlayer();
  bool _backgroundStarted = false;

  @override
  Future<void> play() => _emit(WorkoutMediaCommand.play);

  @override
  Future<void> pause() => _emit(WorkoutMediaCommand.pause);

  @override
  Future<void> skipToNext() => _emit(WorkoutMediaCommand.next);

  @override
  Future<void> skipToPrevious() => _emit(WorkoutMediaCommand.previous);

  @override
  Future<void> stop() => _emit(WorkoutMediaCommand.stop);

  Future<void> _emit(WorkoutMediaCommand command) async {
    customEvent.add(command.name);
  }

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    switch (name) {
      case 'showWorkout':
        if (extras != null) return _show(extras);
        return;
      case 'hideWorkout':
        return _hide();
      default:
        return super.customAction(name, extras);
    }
  }

  Future<void> _show(Map<String, dynamic> value) async {
    await _ensureBackgroundAudio();
    final durationMs = (value['durationMs'] as num?)?.toInt() ?? 0;
    final remainingMs = (value['remainingMs'] as num?)?.toInt() ?? 0;
    final paused = value['isPaused'] as bool? ?? false;
    final stepIndex = (value['stepIndex'] as num?)?.toInt() ?? 0;
    mediaItem.add(
      MediaItem(
        id: value['sessionId'] as String? ?? 'local-workout',
        album: value['workoutName'] as String? ?? 'CloudBoard',
        title: value['slideName'] as String? ?? '수업 진행 중',
        artist: value['statusLabel'] as String? ?? '',
        duration: Duration(milliseconds: durationMs),
      ),
    );
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          paused ? MediaControl.play : MediaControl.pause,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.ready,
        playing: !paused,
        updatePosition: Duration(
          milliseconds: max(0, durationMs - remainingMs),
        ),
        speed: 1,
        queueIndex: stepIndex,
      ),
    );
  }

  Future<void> _hide() async {
    playbackState.add(
      PlaybackState(processingState: AudioProcessingState.idle),
    );
    mediaItem.add(null);
    _backgroundStarted = false;
    await _backgroundPlayer.stop();
  }

  Future<void> _ensureBackgroundAudio() async {
    if (_backgroundStarted) return;
    await _backgroundPlayer.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );
    await _backgroundPlayer.setReleaseMode(ReleaseMode.loop);
    await _backgroundPlayer.play(
      BytesSource(_silentWave(), mimeType: 'audio/wav'),
      volume: 1,
      mode: PlayerMode.mediaPlayer,
    );
    _backgroundStarted = true;
  }
}

Uint8List _silentWave() {
  const sampleRate = 8000;
  const sampleCount = sampleRate;
  const dataLength = sampleCount * 2;
  final bytes = ByteData(44 + dataLength);

  void text(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      bytes.setUint8(offset + index, value.codeUnitAt(index));
    }
  }

  text(0, 'RIFF');
  bytes.setUint32(4, 36 + dataLength, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  text(36, 'data');
  bytes.setUint32(40, dataLength, Endian.little);
  return bytes.buffer.asUint8List();
}
