import 'dart:async';

import 'package:flutter/services.dart';

/// Android-only retained SoundPool resources and a bounded native deadline queue.
/// Method completion means accepted/prepared, never measured speaker onset.
class AndroidCueAudio {
  AndroidCueAudio({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.sunmkim.cloudboard/cue_audio');
  final MethodChannel _channel;
  final Map<String, Future<void>> _prepared = {};

  Future<void> prepare(String key, Future<Uint8List> Function() bytes) {
    return _prepared.putIfAbsent(key, () async {
      try {
        await _channel
            .invokeMethod<void>('prepare', {'key': key, 'wav': await bytes()})
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        _prepared.remove(key);
        rethrow;
      }
    });
  }

  Future<void> activate(String owner, {String? terminalCueId}) =>
      _channel.invokeMethod<void>('activate', {
        'owner': owner,
        'terminalCueId': terminalCueId,
      });
  Future<void> replace(
    String owner,
    List<Map<String, Object>> cues,
    double volume,
  ) => _channel.invokeMethod<void>('replace', {
    'owner': owner,
    'cues': cues,
    'volume': volume.clamp(0, 1),
  });
  Future<void> immediate(
    String owner,
    Map<String, Object> cue,
    double volume,
  ) => _channel.invokeMethod<void>('immediate', {
    'owner': owner,
    'cue': cue,
    'volume': volume.clamp(0, 1),
  });
  Future<void> cancel(String owner, {bool preserveEnd = false}) =>
      _channel.invokeMethod<void>('cancel', {
        'owner': owner,
        'preserveEnd': preserveEnd,
      });
  Future<void> dispose() => _channel.invokeMethod<void>('dispose');
}
