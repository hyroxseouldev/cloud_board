import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'beep_player.g.dart';

class BeepPlayer {
  BeepPlayer() : _source = BytesSource(_createWave(), mimeType: 'audio/wav');

  final AudioPlayer _player = AudioPlayer();
  final BytesSource _source;
  bool _configured = false;

  Future<void> play() async {
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
    await _player.stop();
    await _player.play(_source, volume: 1, mode: PlayerMode.mediaPlayer);
  }

  Future<void> dispose() => _player.dispose();
}

@Riverpod(keepAlive: true)
BeepPlayer beepPlayer(Ref ref) {
  final player = BeepPlayer();
  ref.onDispose(() => player.dispose());
  return player;
}

Uint8List _createWave() {
  const sampleRate = 44100;
  const durationMs = 280;
  const frequency = 1046.5;
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
    final progress = index / sampleCount;
    final envelope = sin(pi * progress);
    final sample =
        (sin(2 * pi * frequency * index / sampleRate) * envelope * 28000)
            .round();
    bytes.setInt16(44 + index * 2, sample, Endian.little);
  }
  return bytes.buffer.asUint8List();
}
