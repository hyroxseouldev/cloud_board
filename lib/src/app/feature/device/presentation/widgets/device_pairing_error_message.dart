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
      'deadline-exceeded' => 'TV 응답이 늦어지고 있습니다. 등록 목록을 확인한 뒤 다시 시도해 주세요.',
      'already-exists' => '이미 등록된 TV입니다. 등록 목록에서 해당 TV를 선택해 확인해 주세요.',
      'not-found' => '연결 코드를 찾을 수 없습니다. TV에 표시된 최신 코드를 입력해 주세요.',
      'failed-precondition' => '만료되었거나 사용된 코드일 수 있습니다. TV에서 새 코드를 확인해 주세요.',
      'permission-denied' => '연결 요청이 거부되었습니다. 로그인 상태와 디스플레이의 최신 코드를 확인해 주세요.',
      'network-request-failed' ||
      'disconnected' ||
      'unavailable' => '인터넷에 연결하지 못했습니다. 연결을 확인한 뒤 다시 시도해 주세요.',
      _ => '디스플레이를 연결하지 못했습니다. 잠시 후 다시 시도해 주세요.',
    };
  }
  return '디스플레이를 연결하지 못했습니다. 잠시 후 다시 시도해 주세요.';
}
