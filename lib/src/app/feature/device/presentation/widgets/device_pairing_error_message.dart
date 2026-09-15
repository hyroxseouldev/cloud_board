import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

/// Keep actionable pairing failures visible without Dart/Firebase prefixes.
String devicePairingErrorMessage(Object? error) {
  if (error is StateError) return error.message;
  if (error is FormatException) return error.message;
  if (error is TimeoutException) {
    return '연결 확인이 지연되고 있습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.';
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => '연결 요청이 거부되었습니다. 로그인 상태와 디스플레이의 최신 코드를 확인해 주세요.',
      'network-request-failed' ||
      'disconnected' ||
      'unavailable' => '인터넷에 연결하지 못했습니다. 연결을 확인한 뒤 다시 시도해 주세요.',
      _ => '디스플레이를 연결하지 못했습니다. 잠시 후 다시 시도해 주세요.',
    };
  }
  return '디스플레이를 연결하지 못했습니다. 잠시 후 다시 시도해 주세요.';
}
