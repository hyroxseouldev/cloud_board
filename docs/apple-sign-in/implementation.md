# iOS Apple 로그인

2026-09-14, develop에서 구현. 이번 작업에서는 main 병합이나 서버 배포, 운영 계정의 로그인·삭제를 수행하지 않았다.

## 구현

- iPhone/iPad 로그인 화면에 Google과 같은 높이의 검정색 `Apple로 계속하기` 버튼 추가. Android/TV와 웹의 로그인 선택지는 기존대로 유지한다.
- 기존 Firebase Auth의 `AppleAuthProvider`와 native `signInWithProvider`를 사용한다. SDK가 Apple nonce/credential 및 처음 제공되는 이름을 처리한다. 별도 Apple 인증 패키지는 추가하지 않았다.
- View → Controller → UseCase → Repository → DataSource 구조를 유지한다. 로그인 중 중복 요청을 차단하고 사용자 취소는 실패 알림 없이 종료한다.
- 동일 이메일 충돌은 기존 로그인 방식을 사용하도록 안내한다. 앱에서 다른 UID의 데이터를 자동으로 합치거나 옮기지 않는다. Apple 이메일 숨기기는 Google 로그인과 별도 계정을 만들 수 있으므로 로그인 화면에 설명한다. 기존 Google 사용자는 기존 버튼으로 기존 콘텐츠에 접근한다. 계정 연결/콘텐츠 병합 UI는 이번 범위에 포함하지 않았다.
- Apple 계정 삭제 시 `reauthenticateWithProvider`로 새 authorization code를 받고 `revokeTokenWithAuthorizationCode`로 Apple 연결을 해제한 뒤 서버 삭제를 호출한다. 코드 누락·인증 취소·해제 실패 시 삭제 단계로 넘어가지 않는다. 코드는 저장하거나 로그에 남기지 않는다.
- 서버는 5분 이내 Google 또는 Apple 인증만 허용한다. 기존 UID 검증, 삭제 잠금, 데이터 정리·검증·재시도 순서를 유지한다.
- Apple-only 사용자의 로그아웃은 불필요한 Google 초기화를 하지 않는다. 프로필과 삭제 안내의 Google 전용 문구를 공통 문구로 수정했다.
- iOS Runner의 Sign in with Apple entitlement를 추가했다.

## main 배포 흐름

기존 Firebase Hosting 액션에 Node 22, 서버 단위 테스트, 계정 삭제 함수 및 Firestore/RTDB/Storage 규칙 배포를 추가했다. Apple 계정 허용 서버 변경이 앱 배포에서 누락되지 않도록 하기 위함이다. main push에서만 서버 배포한다. PR에서는 테스트만 실행한다.

GitHub Actions의 Firebase 서비스 계정은 함수 배포 및 서비스 계정 사용, 관련 규칙·인덱스 배포 권한이 필요하다. 로컬 사용자 계정의 배포 권한과 CI 서비스 계정 권한은 별개다. 실제 main 액션 실행 전 권한 확인이 필요하며, 이 작업에서는 IAM 권한을 확대하지 않았다.

## 외부 설정: 코드 구현 당시 확인 및 후속 검증

코드 구현 당시 Firebase 설정을 읽기 전용 API로 확인했을 때 `defaultSupportedIdpConfigs/apple.com`은 404였다. 이후 아래 브라우저 설정에서 제공자 활성화와 OAuth 키 저장을 완료했다. 실제 로그인 검증은 별도로 남아 있다.

1. Apple Developer의 App ID `com.sunmkim.cloudboard`에서 Sign in with Apple capability를 활성화한다. 서명 프로비저닝 프로파일에도 해당 entitlement가 포함되어야 한다.
2. Firebase Authentication에서 Apple 제공자를 활성화한다. Apple token revoke를 포함한 OAuth 구성을 위해 공식 설정 절차에 맞는 Team ID, Key ID, Sign in with Apple private key 및 필요한 Service ID를 구성한다. App Store Connect 업로드용 API 키와 Sign in with Apple 키는 용도가 다르다. 비밀 키는 소스·문서·채팅에 넣지 않는다.
3. 이메일 숨기기 사용자를 대상으로 Firebase 인증 이메일 등을 보낼 경우 Apple Private Email Relay의 발신자 설정을 확인한다.
4. 실제 Apple 테스트 계정으로 신규 가입(이메일 공개/숨기기), 취소, 재로그인, 이름 보존, 삭제 재인증 및 연결 해제를 검증한다. 기존 Google 계정의 로그인·삭제도 함께 확인한다.
5. 공개 개인정보처리방침의 로그인 제공자 설명과 스토어 개인정보 응답을 확인한다. 정책 페이지는 임의로 수정하지 않았다.

Apple 설정이 끝나기 전에는 이 코드를 정식 출시 준비 완료로 취급하지 않는다. Apple 계정은 이번 범위에서 iOS에서 가입·재인증하며 Android/Web용 Apple 로그인은 후속 범위다.

## 검증

Flutter 정적 분석 통과, 전체 Flutter 테스트 150개 통과, 서버 단위 테스트 12개 통과. iOS 시뮬레이터 빌드 통과 (서명 및 실제 Apple 인증 검증과는 별개).

- Flutter 테스트: Apple 삭제 인증·연결 해제 순서, 취소/코드 누락/연결 해제 실패, Apple-only 로그아웃, 로그인 중복 방지·취소·계정 충돌 안내, iOS/Android 로그인 버튼 표시 검증.
- 서버 단위 테스트: Apple 허용, 미지원 제공자 및 오래된 인증 거부.
- Firebase 에뮬레이터: Apple 제공자의 가짜 계정으로 실제 callable 로직 실행. Auth/Firestore 중첩 문서/Storage/RTDB 삭제, 다른 계정 보존, 이전 토큰의 재생성 차단 확인.
- Apple 실제 로그인/연결 해제는 외부 설정과 실제 계정이 필요하여 미검증. 운영 사용자 데이터는 변경하지 않았다.

재현:

```sh
flutter analyze
flutter test
npm test --prefix functions
CLOUD_BOARD_TEST_PROVIDER=apple.com firebase emulators:exec --project demo-cloudboard --config firebase.deletion-test.json --only auth,firestore,database,storage 'node functions/test/emulator.mjs'
flutter build ios --simulator --no-codesign
```

공식 근거 (2026-09-14 확인):
- https://firebase.google.com/docs/auth/flutter/federated-auth
- https://firebase.google.com/docs/auth/ios/apple
- https://developer.apple.com/app-store/review/guidelines/#login-services

## 2026-09-14 브라우저 설정 진행 상황

사용자의 요청으로 Apple Developer와 Firebase Console에서 설정을 진행했다.

- App ID `com.sunmkim.cloudboard`에 Sign in with Apple을 primary App ID로 활성화하고 저장.
- Firebase Apple 로그인 제공자 활성화 및 목록의 `사용 설정됨` 확인.
- CloudBoard 전용 Apple 로그인 키 `DRBKDH3R9N` 발급. 권한은 Sign in with Apple, 대상은 CloudBoard App ID만 지정. Apple 화면에서 Downloaded 상태 확인.
- Service ID `com.sunmkim.cloudboard.auth` 등록, CloudBoard App ID와 연결.
- 인증 도메인 `cloud-board-stationd.firebaseapp.com`, callback `https://cloud-board-stationd.firebaseapp.com/__/auth/handler` 등록·저장.
- 발급된 `AuthKey_DRBKDH3R9N.p8`를 Downloads에서 확인하고, 사용자 요청에 따라 Firebase의 비공개 키 필드에 입력·저장했다. 새 키는 발급하지 않았다.
- 저장 후 Apple 설정을 다시 열어 Service ID, Team ID `NL7AM62SB9`, Key ID `DRBKDH3R9N`, 비공개 키의 저장 상태를 확인했다.
- 실제 Apple 로그인·연결 해제는 아직 검증하지 않았다. 서명 프로비저닝 프로파일 반영과 main 배포 후 실제 계정으로 검증해야 한다.

발급된 private key의 내용은 문서나 Git에 기록하지 않았다. 이번 브라우저 설정에서 main 병합·앱 배포·서버 배포는 하지 않았다.
