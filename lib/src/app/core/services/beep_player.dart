import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:cloud_board/src/app/feature/workouts/domain/entities/workout_sound.dart';

part 'beep_player.g.dart';

class BeepPlayer {
  final AudioPlayer _player = AudioPlayer();
  final Map<WorkoutSound, BytesSource> _sources = {};
  bool _configured = false;

  Future<void> play([
    WorkoutSound sound = WorkoutSound.classicBeep,
    double volume = 1,
  ]) async {
    if (sound == WorkoutSound.silent || volume <= 0) return;
    if (!_configured) {
      await _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.notificationEvent,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.duckOthers},
          ),
        ),
      );
      await _player.setReleaseMode(ReleaseMode.stop);
      _configured = true;
    }
    final source = _sources.putIfAbsent(
      sound,
      () => BytesSource(_createWave(sound), mimeType: 'audio/wav'),
    );
    await _player.stop();
    await _player.play(
      source,
      volume: volume.clamp(0, 1),
      mode: PlayerMode.mediaPlayer,
    );
  }

  Future<void> dispose() => _player.dispose();
}

@Riverpod(keepAlive: true)
BeepPlayer beepPlayer(Ref ref) {
  final player = BeepPlayer();
  ref.onDispose(() => player.dispose());
  return player;
}

Uint8List _createWave(WorkoutSound sound) {
  const sampleRate = 44100;
  final durationMs = switch (sound) {
    WorkoutSound.doubleBeep => 520,
    WorkoutSound.boxingBell => 720,
    WorkoutSound.longFinish => 1050,
    WorkoutSound.softBell => 620,
    _ => 280,
  };
  final sampleCount = sampleRate * durationMs ~/ 1000;
  final dataLength = sampleCount * 2;
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

  for (var index = 0; index < sampleCount; index++) {
    final seconds = index / sampleRate;
    final progress = index / sampleCount;
    final value = _sample(sound, seconds, progress);
    bytes.setInt16(
      44 + index * 2,
      (value.clamp(-1.0, 1.0) * 28000).round(),
      Endian.little,
    );
  }
  return bytes.buffer.asUint8List();
}

double _sample(WorkoutSound sound, double seconds, double progress) {
  double tone(double frequency) => sin(2 * pi * frequency * seconds);
  final fade = sin(pi * progress).clamp(0.0, 1.0);
  switch (sound) {
    case WorkoutSound.silent:
      return 0;
    case WorkoutSound.classicBeep:
      return tone(1046.5) * fade;
    case WorkoutSound.sharpBeep:
      return (tone(1396.9) * .8 + tone(2093) * .2) * fade;
    case WorkoutSound.lowPulse:
      return tone(440) * pow(1 - progress, 1.4);
    case WorkoutSound.softBell:
      final decay = exp(-4.2 * progress);
      return (tone(659.3) * .72 + tone(1318.5) * .2 + tone(1975.5) * .08) *
          decay;
    case WorkoutSound.boxingBell:
      final attack = min(1.0, seconds * 35);
      final decay = exp(-3.5 * progress);
      return (tone(880) * .55 + tone(1320) * .3 + tone(1760) * .15) *
          attack *
          decay;
    case WorkoutSound.doubleBeep:
      final local = seconds < .2
          ? seconds / .2
          : seconds > .3 && seconds < .5
          ? (seconds - .3) / .2
          : -1.0;
      if (local < 0) return 0;
      return tone(987.8) * sin(pi * local.clamp(0, 1));
    case WorkoutSound.longFinish:
      final frequency = progress < .52 ? 784.0 : 1046.5;
      return tone(frequency) * sin(pi * progress);
  }
}
