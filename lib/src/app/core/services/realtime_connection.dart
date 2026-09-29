import 'dart:async';

import 'package:cloud_board/src/app/feature/playback/domain/playback_failure.dart';

/// The SDK initially emits false even while establishing a healthy connection.
Future<void> waitForPlaybackConnection(
  Stream<bool> connection, {
  Duration timeout = const Duration(seconds: 6),
}) async {
  try {
    await connection.firstWhere((connected) => connected).timeout(timeout);
  } on TimeoutException {
    throw const PlaybackFailure(
      'connection_timeout',
      '서버에 연결하지 못했습니다. 인터넷 연결을 확인해 주세요.',
    );
  }
}
