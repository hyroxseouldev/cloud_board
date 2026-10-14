# STA-164 화면 검증

실제 `OnboardingScreen`을 서버 응답 fixture와 연결해 390×844, 2배 해상도로 캡처했다. 운영 계정·SMS를 사용한 실기기 캡처는 아니다. 위젯 테스트는 인증 결과가 도착하기 전, 실패 후 재조회, 확인된 Free에서 선택한 예시로 이어지는 경로를 검증한다.

- [인증 전](phone-verification.png): Free 활성화 조건과 가입 없이 둘러보기를 안내한다.
- [권한 반영 실패·재시도](activation-retry.png): 완료로 표시하지 않고 인증을 반복하지 않는 재조회 경로를 제공한다.
- [서버 확인 후 완료](free-confirmed.png): Free 활성화를 안내하고 바로 수업 화면으로 이동한다. 센터 정보 입력은 선택이다.

재생성: `flutter test tool/sta164_capture_test.dart`

세 이미지의 글자 잘림·가로 넘침·버튼 배치를 확인했다. 인증→Free→서비스 위젯 여정은 320/390/834 너비에서도 검증한다.
