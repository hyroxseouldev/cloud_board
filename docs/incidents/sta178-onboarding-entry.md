# STA-178 기존 이용자 진입 반복 안내 수정

사용자 제보 환경은 iOS·Android 앱이다. 기존 권한 확인은 유지하면서 매 실행 시
`기존 이용 권한을 계속 사용할 수 있어요` 결과 화면을 거쳐야 했던 진입 흐름을 수정했다.

## 동작

- 인증 복원과 서버 이용 권한 조회 중에는 기존 Oat Sage 시작 화면을 유지한다.
  `AsyncLoading`/refreshing/error를 온보딩 필요 또는 이용 가능으로 해석하지 않는다.
- 서버가 기존 유효 체험/유료 권한 또는 인증 완료 Free를 확인하면 원래 목적지로
  자동 이동한다. `needsOnboarding` 정책과 서버 `serviceReady` 판정은 변경하지 않는다.
- 신규 인증 또는 명시적 활성화 재확인이 실제로 성공했을 때만 현재 화면 수명에서
  완료 안내를 유지한다. 화면을 나가거나 계정이 바뀌면 이 표시는 제거된다.
  앱 재실행 시 완료 기록을 로컬에서 권한 증거로 사용하지 않는다.
- `verify=true`/`edit=true`는 cold auth restoration을 거쳐도 유지된다.
  명시적 온보딩 URL 자체와 그 안의 완료 후 `from` 목적지를 구분한다.
- 로그인→이메일 로그인→인증 경로에서 안전한 앱 내부 목적지의 path/query/fragment를
  유지한다. 외부 URL, entry gate 재귀 주소는 return으로 허용하지 않는다.
- query의 starter/purpose와 실제 deep link가 우선이다. 별도 목적지 없는 기본 진입은
  기존에 이 계정에 저장된 pending 예시 수업 선택을 복원한다. 로딩/오류 상태에 남은
  이전 계정의 선택을 사용하지 않는다. 공개 둘러보기 경로는 계속 인증 없이 열린다.
- 권한 조회 실패는 재시도 가능한 시작 상태에 남고, 서버가 만료/미활성 상태를
  반환하면 필요한 인증/활성화 안내로 이동한다. 실패를 Free 또는 기존 이용 가능으로
  바꾸지 않는다.
- 계정 전환 중 지연된 인증 응답은 현재 progress/완료 표시를 바꾸지 못한다.
  이전 계정의 private return은 자동 복귀뿐 아니라 완료 버튼에서도 제거한다.

## 구조

`AuthEntryScreen`은 기존 `AppStartupScreen`의 로딩/재시도 표현을 재사용한다.
라우터가 pending/required/ready를 구분하고 목적지를 보존한다. `OnboardingAction`은
서버 응답을 수락한 경우에만 화면 수명의 `OnboardingCompletion`을 설정한다.
도메인 권한 모델, 서버 정책, 구독 가격/한도, 공개 탐색 기능은 변경하지 않는다.

## 자동 검증

기존 CI에 포함된 `auth_router_test.dart`, `onboarding_test.dart`,
`first_use_journey_test.dart`를 확장했다. 실제 generated controller 및 repository
fixture와 production router를 사용한다. iOS/Android `TargetPlatformVariant`에서도
실제 앱 시작 화면 → 홈 전환을 검증한다. Firebase/native 인증 SDK는 테스트 fixture다.

검사 항목:

- 기존 Free/paid/trial의 지연된 초기 확인 및 정확한 deep-link 복귀
- iOS/Android 설정에서 완료 안내 깜빡임 없이 자동 홈 진입
- 실제 시작 화면의 서버 오류 → 재시도 → 정상 진입
- cold explicit verify/edit와 그 안의 후속 목적지 보존
- 신규 SMS 완료 안내 1회 유지 → 서비스 진입 → `/onboarding` 재방문 시 반복 안 함
- 만료/실패, 로그아웃·재로그인, A→B 및 A→B→A 지연 응답 차단
- 이전 계정 인증 화면에 있던 private return 제거
- 저장된 pending 예시, query starter/purpose 및 private 목적지의 우선순위
- 기존 로그인·이메일 인증·공개 탐색·메인 탐색 화면 회귀

실행 명령(저장소 루트, Flutter 3.47.0):

```sh
flutter test --no-pub test/auth_router_test.dart test/onboarding_test.dart \
  test/first_use_journey_test.dart test/main_navigation_test.dart \
  test/email_auth_test.dart test/auth_startup_performance_test.dart
flutter test --no-pub --platform chrome test/auth_router_test.dart \
  test/onboarding_test.dart test/first_use_journey_test.dart
flutter analyze --no-pub
```

최종 실행 결과는 PR 검증 기록에 연결한다. TargetPlatformVariant/Chrome 회귀는
실제 iOS·Android 설치/강제종료/재실행 또는 실기기 인증 SDK 검증을 뜻하지 않는다.
실제 모바일 재실행·재로그인 및 웹 새로고침 확인은 사용자 후속 검수로 남긴다.
