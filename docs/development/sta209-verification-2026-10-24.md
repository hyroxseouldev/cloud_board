# STA-209 개발 검증 — 2026-10-24

## 후보와 범위

- 기준 develop: `89091421b013b57d26c94fe440241d54d4ea5290`.
- 브랜치: `feature/sta-209-cloud-run-resilience`. 정확한 인계 head SHA는 PR에 기록한다.
- 앱: 기존 `2.0.3+5`, Flutter `3.47.0`, development debug web. 버전 변경 없음.
- 기존 회원의 DB 권한 기반 진입, 등록된 디스플레이의 DB 기반 재접속, 관련 보안 규칙/등록 증명/계정 차단 경로를 구현했다.
- 서버·규칙 배포, main 변경, 태그, 스토어 업로드, 자동화 재활성화는 수행하지 않았다.
- **개발 후보이며 완료/병합 상태가 아니다.** 아래 보안 관리 전제와 네이티브 검증을 남긴다.

## 자동 검사

| 검사 | 결과 | 유형 |
| --- | --- | --- |
| cloud_run_resilience, auth_router, onboarding, display_presence, display_verification, display_playback_continuity | 90개 통과 | Flutter 유닛·provider·실제 라우터 위젯(mock 의존성) |
| display-resume.test.js + display-recovery.test.js | 51개 통과 | 서버 유닛 |
| display-resume-emulator.mjs | 45개 허용/거부 assertion 통과 | 실제 RTDB emulator 규칙 |
| onboarding-entry-emulator.mjs | 6개 허용/거부 assertion 통과 | 실제 Firestore emulator 규칙 |
| 기존 display-recovery-emulator.mjs | 통과 | 기존 등록/복구·해제·지연 종료 규칙 계약 |
| 변경 Dart 27개 정적 분석 | 문제 없음 | flutter analyze |
| 최종 debug web 빌드 | 성공 | 실제 Flutter 빌드 |

관련 실행 명령:

```sh
fvm flutter test --no-pub test/cloud_run_resilience_test.dart test/auth_router_test.dart test/onboarding_test.dart test/display_presence_test.dart test/display_verification_test.dart test/display_playback_continuity_test.dart
node --test functions/test/display-resume.test.js functions/test/display-recovery.test.js
FIREBASE_DATABASE_EMULATOR_HOST=127.0.0.1:9000 node functions/test/display-resume-emulator.mjs
FIREBASE_DATABASE_EMULATOR_HOST=127.0.0.1:9000 node functions/test/display-recovery-emulator.mjs
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node functions/test/onboarding-entry-emulator.mjs
fvm flutter build web --debug --target tool/sta209/main.dart --dart-define=FIREBASE_ENV=development --output=output/sta209/web --no-pub
```

추가로 실행한 기존 `first_class_test.dart` 전체에서는 starter pack 테스트 1건의 `studio-*` 기대값과 실제 `starter-v1-illustrated` 값 불일치를 발견했다. 해당 테스트와 starter pack 구현은 이번 변경 대상이 아니다. 이를 통과로 집계하지 않았다. 새 홈 요약 조회 회귀 테스트는 별도로 수정 후 위 90개에 포함해 통과했다.

## 실제 앱 화면 + 로컬 Firebase E2E

업무 provider를 교체하지 않은 앱 4개(컨트롤러 1, 디스플레이 3)를 격리된 Chromium 프로필에서 실행했다. Auth/Firestore/RTDB/Storage는 `demo-cloudboard-studio` loopback emulator, Functions 주소는 요청을 500 또는 무응답으로 만드는 로컬 fault responder였다. 전용 계정은 `sta209@example.test`이며 외부 센터/기기를 연결하지 않았다. 네이티브 기기 결과를 뜻하지 않는다.

- Auth 9099, Firestore 8080, RTDB 9000, Storage 9199, Functions 장애 5001, 앱 `http://localhost:18709`.
- 최초 등록 상태는 준비 스크립트가 만들었다. 신규 등록 성공 E2E로 집계하지 않았다.
- 함수 500을 먼저 주입한 뒤 21:46 KST에 앱 4개를 재실행했다. 기존 수업 목록 진입, 3대 온라인, 실제 준비 화면의 3/3 완료 후 수업을 시작했다.
- 세션 `session-hnie3s5x54`: 시작 revision 1 → 일시정지 2 → 재개 3 → 종료 4. 일시정지 상태에서 TV1 재실행 후 같은 위치(remainingMs 80305)/revision 2 복구. TV2/3의 연결 ID는 유지됐다.
- TV1 앱을 닫아 실제 RTDB onDisconnect의 online=false를 확인하고 수업을 종료했다. TV1 재실행 후 최신 completed 상태를 읽고 대기 화면에 진입했다. 종료 수업 재생은 관찰되지 않았다.
- 최종 빌드에서 21:59:45 KST 이전에 Functions를 무응답 모드로 바꾼 뒤 앱 4개를 재실행했다. 수업 목록·3대 온라인·3/3 준비가 함수 timeout 전에 완료됐다.
- 다음 세션 `session-hniegifxds`를 실제 UI에서 시작했다. TV1 브라우저 네트워크를 끊자 실제 RTDB online=false가 됐고 화면의 기존 타이머는 계속 진행했다. 끊어진 동안 컨트롤러에서 일시정지 후 네트워크를 복구했다.
- 복구 TV1은 새 연결 ID `-P4hzyaYPRAF8SDJdoGL`로 online=true 및 최신 revision 2 ACK를 보냈다. TV2/3은 기존 연결을 유지하며 같은 revision 2를 확인했다. 재개 revision 3, 종료 revision 4 및 세 화면 대기 복귀를 확인했다.
- 21:46:04 KST 이후 정상 경로의 `cloudboardAppOnboarding`/`verifyDisplayConnection` 요청은 0건이었다. 별도 목록 기능 `listLibraryFolders`의 500/timeout은 발생했고 수업 진입·제어를 막지 않았다.
- 500 E2E 후에는 DI 구성을 repository/usecase로 정리했다. 최종 빌드의 무응답 E2E와 정적 분석으로 해당 구성을 확인했다. 서버/규칙/재생 로직의 동일한 기존 증거는 재사용했다.

증거는 사용한 Sable 작업 공간의 다음 경로에 보존한다.

- `output/sta209/e2e/*.json`: 각 단계의 DB 서버 관찰값과 assertion 결과.
- `output/playwright/sta209/*network-recovered-paused.png`, `*ended-standby.png`: 컨트롤러/각 디스플레이 캡처.
- `output/sta209/logs/`: 유닛·규칙·분석·빌드·함수 장애 로그.
- `output/sta209/web/`: 최종 로컬 테스트 앱. 네이티브 앱 산출물이 아니다.

## 남은 검증과 차단 사항

1. **관리 절차 확인 전 활성화 금지:** RTDB는 Firebase Auth Console의 정지/토큰 폐기를 직접 읽지 못한다. 코드의 `revokeAccountSessions`는 DB 차단 후 Auth 변경을 수행하고 계정 삭제 경로에 적용했다. Console/외부 Admin 도구를 포함한 모든 관리 경로가 DB 미러를 갱신한다는 확인은 아직 없다. `displayResumePolicy/authoritativeAuthMirror` 기본값은 비활성이다. 증명 사전 발급 및 개발 규칙/서버 반영도 원격 환경에서는 실행하지 않았다. 자세한 설계는 [재접속 설계](sta209-cloud-run-resilience.md)를 따른다.
2. **실기기 미확인:** iPad/Android TV 전원 재부팅, 네이티브 인증 저장/복귀, 실제 Wi-Fi·스피커 종료음 중복 여부는 실행하지 않았다. 웹의 프로세스 재실행/네트워크 단절과 유닛의 cue 검사를 실기기·음향 확인으로 대체하지 않는다.
3. **디버그 프레임 오류:** 최종 웹 TV2에서 Flutter `FrameTiming` callback의 assertion이 반복됐다. UI/RTDB 상태 전환과 타이머는 동작했지만 오류 없는 E2E라고 보고하지 않는다. 로컬 SDK의 `widgets/binding.dart:1549` 첫 프레임 assertion 경로와 일치하는 로그이며 원인과 네이티브 영향은 미확정이다.
4. 실제 Firebase 개발 서버의 신규 등록/인증/Free 활성화, 계정 전환, 앱이 꺼진 동안 다음 수업이 새로 시작된 경우의 전체 E2E는 별도 미확인이다. 관련 기존 유닛·규칙 검사는 통과했으나 외부 서버 검증을 뜻하지 않는다.

## 테스트 준비 중 정리한 개발 계정

초기 `127.0.0.1` 주소의 FlutterFire Auth emulator 복원 문제로 이번 실행의 익명 계정 3개가 `cloud-board-development`에 생성됐다. 생성 시각·UID·익명 여부·토큰 대상 프로젝트를 확인해 해당 3개만 삭제했으며 각각 삭제 HTTP 200을 확인했다. 이후 테스트 진입점은 **가짜 API 키 + localhost 강제 + demo 프로젝트**로 변경했다. 성공 E2E는 이 격리 환경에서 수행했다. 운영 프로젝트/운영 계정은 변경하지 않았다.

