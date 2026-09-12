# 앱 내 계정 삭제 구현

2026-09-12, develop에 구현. 사용자가 이메일 요청 방식 대신 앱 안에서 실제 계정과 데이터를 삭제하는 방식으로 범위를 변경했다.

## 사용자 흐름

휴대폰·태블릿의 프로필 → 계정 관리 → 계정 삭제 → 삭제 범위 확인 → Google 재인증 → 서버 삭제 → 완료 시 로컬 저장 데이터 정리와 로그아웃. Google 계정 자체는 삭제하지 않는다. 삭제 중에는 중복 실행을 막고, 일부 정리가 실패하면 완료 대신 처리 중이라고 표시한다. Android TV에서는 이 모바일 메뉴를 표시하지 않는다.

외부 계정 삭제 안내 및 개인정보처리방침 링크도 유지한다. 외부 브라우저 실행 실패 시 문의 이메일을 표시하고 복사할 수 있다. URL에는 사용자 정보나 인증 토큰을 첨부하지 않는다.

## 서버와 보안

- Firebase callable `deleteMyAccount`, 서울 리전 `asia-northeast3`. 서버가 인증 토큰의 UID를 사용하며, 요청 본문으로 다른 계정을 지정할 수 없다. 5분 이내 Google 재인증과 명시적 확인을 요구한다.
- Firestore `accountDeletions/{uid}` 및 RTDB 삭제 잠금으로 추가 접근·쓰기를 차단한다. Storage 규칙의 Firestore 조회에 필요한 서비스 에이전트 역할도 확인한다.
- 진행 중인 수업을 종료하고 RTDB `displayAccess`, `pairingCodes`의 해당 소유자 연결을 정리한다. 연결 소유자가 중간에 바뀌면 다른 소유자의 연결은 지우지 않는다.
- Storage `users/{uid}/` 파일, Firestore `users/{uid}`와 모든 하위 컬렉션, RTDB `users/{uid}`를 제거하고 확인한 뒤 Authentication 계정을 삭제한다.
- 재사용 가능한 디스플레이의 별도 익명 인증 계정은 삭제하지 않는다. 삭제 계정에 대한 연결과 접근 권한은 제거한다.
- 부분 실패는 서버 작업으로 남겨 `retryAccountDeletions`가 15분마다 재시도한다. 작업 임대로 중복 실행을 제한한다. 완료 작업 기록과 잠금은 공개된 처리 기록 보관 기간인 30일 후 정리한다.
- Storage soft delete 등 서비스 백업 보관은 공개 개인정보처리방침을 따른다. 즉시 모든 백업까지 삭제했다고 표시하지 않는다.

## 배포와 검증

두 Cloud Functions, Firestore/Realtime Database/Storage 규칙, 작업 조회 인덱스를 Firebase 프로젝트 `cloud-board-stationd`에 배포했다. 함수 컨테이너 빌드 이미지의 보관 정책은 7일이며, 사용자 데이터 보관 정책과 별개다.

- Flutter 정적 분석: 통과.
- Flutter 전체 테스트: 142개 통과. 취소 시 실행하지 않음, 중복 삭제 방지, 처리 중과 완료 구분, 휴대폰·태블릿 메뉴, 외부 링크 실패 및 이메일 복사 포함.
- 서버 단위 테스트: 11개 통과. 삭제 순서, 인증 조건, 단계별 실패 및 재시도 검증.
- Firebase 에뮬레이터: 가짜 Google 계정으로 실제 callable 로직을 실행하여 Auth·중첩 Firestore·Storage·RTDB 정리, 다른 계정 보존, 삭제 후 이전 인증으로 재생성 차단을 확인했다. 테스트 스크립트는 localhost 및 demo 프로젝트만 허용한다.
- 프로필 및 삭제 확인창을 실제 위젯으로 렌더링하고 이미지 확인. `profile.png`, `confirmation.png`는 가짜 프로필로 생성했으며 실제 삭제를 호출할 수 없다.
- Android debug APK 빌드 통과.
- 실제 사용자 데이터 삭제나 요청 이메일 발송은 하지 않았다.

재현 명령:

```sh
flutter analyze
flutter test
npm test --prefix functions
firebase emulators:exec --project demo-cloudboard --config firebase.deletion-test.json --only auth,firestore,database,storage 'node functions/test/emulator.mjs'
flutter test tool/account_deletion_capture_test.dart
flutter build apk --debug --no-pub
```

## 출시 전 남은 확인

실기기가 없어 실제 Android Google 재인증 UI와 운영 환경의 삭제 전체 흐름은 실행하지 않았다. 배포 함수는 확인했지만 운영 계정 삭제로 검증하지 않았다. 출시 전 전용 테스트 계정으로 확인해야 한다. 수정된 앱을 새 versionCode의 서명 AAB에 포함해야 하며 기존 비공개 테스트 바이너리에 소스 변경이 자동 반영되지는 않는다. 이번 작업에서 Play 게시를 진행하지 않았다.

공개 페이지는 브라우저에서 최신 본문과 이메일 요청 링크를 확인했다. Play Console에 등록된 URL과의 대조는 아직 완료하지 않았다. 앱을 사용할 수 없는 사용자의 이메일 삭제 요청 처리 경로는 계속 운영해야 한다.

- 계정 삭제 안내: https://clyr-landing-20.vercel.app/apps/cloudboard/delete-account
- 개인정보처리방침: https://clyr-landing-20.vercel.app/apps/cloudboard/privacy
- 문의: vividxxxxx@gmail.com

정책 페이지 자체는 수정하지 않았다. 관련 근거: https://support.google.com/googleplay/android-developer/answer/13327111?hl=ko
