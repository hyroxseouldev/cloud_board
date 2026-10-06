import 'package:firebase_auth/firebase_auth.dart';

String authErrorMessage(Object? error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'account-exists-with-different-credential' ||
      'credential-already-in-use' ||
      'email-already-in-use' =>
        '이미 가입한 로그인 방식으로 로그인해 주세요. 기존 계정을 자동으로 합치지 않습니다.',
      'operation-not-allowed' => '이 로그인 방식을 사용할 수 없습니다. 오류 상세를 확인해 주세요.',
      'network-request-failed' => '로그인 서버에 연결하지 못했습니다. 인터넷 연결을 확인해 주세요.',
      'too-many-requests' => '로그인 요청이 많습니다. 잠시 후 다시 시도해 주세요.',
      'user-disabled' => '사용이 중지된 계정입니다. 관리자에게 문의해 주세요.',
      _ => '로그인을 완료하지 못했습니다. 오류 상세를 확인해 주세요.',
    };
  }
  return '로그인을 완료하지 못했습니다. 오류 상세를 확인해 주세요.';
}
