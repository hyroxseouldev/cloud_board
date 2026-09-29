import 'package:firebase_core/firebase_core.dart';

/// Do not send raw SDK messages: they may include database paths or account IDs.
String pairingFailureKind(Object error) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => 'permission_denied',
      'network-request-failed' || 'disconnected' || 'unavailable' => 'network',
      _ => 'firebase_error',
    };
  }
  if (error is FormatException) return 'invalid_code';
  if (error is StateError) {
    final message = error.message;
    if (message.contains('매장을 찾을 수 없습니다')) return 'owner_not_ready';
    if (message.contains('로그인')) return 'authentication_required';
    if (message.contains('등급')) return 'display_limit';
    if (message.contains('만료')) return 'expired_code';
    if (message.contains('이미 사용')) return 'claimed_code';
    if (message.contains('코드를 찾을 수 없습니다')) return 'code_not_found';
    return 'state_error';
  }
  return 'unexpected_error';
}
