# STA-176 TV 복구 검증과 출시 전 확인

2026-10-15 KST 기준. 개발 기준 커밋은 `73da574c54f3dad503a236c7053af3777934c062`이며, 아래 결과는 그 기준 위에서 수정한 작업 트리의 로컬 검증 기록이다. 운영 배포 완료나 실제 TV 검수 완료를 뜻하지 않는다. 서버 프로토콜과 읽기 전용 운영 점검은 [서버 연결·복구 문서](sta176-display-connection-server.md)를 참고한다. 최종 후보 커밋의 CI 결과와 출시 기록은 해당 PR/워크플로 실행에 연결한다.

## 원본 실패와 수정본 통과

`test/tv_playback_lifecycle_test.dart`의 `wake retries automatically after the first server failure`는 기존 `TvPlaybackLifecycle` 및 `PlaybackRecoveryController` API로 작성했다. 신규 구현 클래스가 없어 발생하는 컴파일 오류가 아니라, 절전 복귀 첫 서버 확인이 실패한 뒤 자동 재시도가 발생하지 않는 동작을 원본에서 재현했다.

```text
fvm flutter test test/tv_playback_lifecycle_test.dart \
  --plain-name 'wake retries automatically after the first server failure'

Expected: <2>
  Actual: <1>
Wake recovery must retry without another lifecycle event or tap
```

[원본 실패 로그](release/sta176/tv-baseline-wake-failure.txt)는 수정 전 실행한 `/tmp/sta176-baseline-wake-failure.log`에서 작업 경로만 `<workspace>`로 바꾸어 보존했다. 수정 후 동일 테스트가 통과한다. 재시도 중에 공유 수업의 시작·일시정지·종료 명령을 만들지 않는 것도 검사한다.

## 최초 STA-176 후보에서 실행한 로컬 검증

Flutter 버전은 저장소 `.fvmrc`의 `3.47.0`을 사용했다. 아래 두 테스트 실행에는 서로 겹치는 파일이 있으므로 통과 수를 합산하지 않는다.

| 실행 | 실제 결과 | 보존 로그 |
| --- | --- | --- |
| `fvm flutter test test/display_mode_flow_test.dart test/display_preparation_retry_test.dart test/tv_playback_lifecycle_test.dart test/playback_recovery_test.dart test/display_preparation_test.dart test/workout_preflight_dialog_test.dart` | 42개 통과 | [TV·준비·화면 회귀](release/sta176/tv-regressions.txt) |
| TV 첫 화면부터 서버 확인을 기다리도록 초기 게이트를 보완한 후 `fvm flutter test test/tv_playback_lifecycle_test.dart test/display_mode_flow_test.dart` | 12개 통과. 신규 cold-start 사례 포함 | [Cold-start 및 화면 흐름](release/sta176/tv-cold-start-and-display-flow.txt) |
| 마지막 변경 후 `fvm flutter analyze --no-pub` | `No issues found!` | [분석 결과](release/sta176/tv-analyze.txt) |
| `git diff --check` | 종료 코드 0 | 로컬 실행 확인 |
| `node --test tool/tv-recovery-check.test.mjs tool/firebase/workflow-scope.test.mjs` | 5개 통과 | [Gate 자체 및 native 조건 검사](release/sta176/tv-gate-review.txt) |

PR #61 통합 전 최초 후보 `caf4e19`까지 전체 Flutter 테스트는 **1,089개 통과**했고, 이후 구형 TV freshness와 준비 오류 시작 차단 회귀 2개를 추가했다. 최종 필수 TV 회귀 실행은 **7개 파일·67개 사례 통과, skip 0개**다. 필수 67개 사례를 manifest에 고정했으며 실행 결과는 [검증 결과 JSON](release/sta176/flutter-results.json)에 보존했다. 최종 전체 분석은 `No issues found!`, 포맷 검사는 693개 파일 중 변경 0개였다. Firebase/gate 도구의 Node 테스트 65개도 통과했고, 이후 실제 CLI 실패 시 이전 성공 증거가 제거되는 회귀 1개를 추가해 해당 runner의 4개 검사를 확인했다. 각 수치는 서로 겹치는 검사를 합산한 총계가 아니다.

원본 로그 경로는 각각 `/tmp/sta176-tv-final-tests.log`, `/tmp/sta176-cold-start-tests.log`, `/tmp/sta176-tv-complete-analyze.log`이다. 이 문서의 보존본은 워크스페이스 절대 경로만 정리했다. 기기·계정 식별자, 인증 토큰 및 서버 응답 원문을 검증 기록에 넣지 않는다.

검사하는 주요 동작은 다음과 같다.

- 첫 복귀 실패 뒤 1/2/4/8/16초 재시도와 재시도 예산 종료, 연결 복구 이벤트에 따른 새 확인.
- 연속 세 번의 네트워크 단절·재연결, background 및 연결 해제 뒤 예약된 재시도 취소.
- 자동·수동·원격 요청이 한 번의 실제 서버 확인을 기다리고, 이전 계정/foreground 세대의 늦은 결과를 거부하는 동작.
- 서버에서 완료되거나 삭제된 수업을 이전 SDK 캐시의 `playing` 상태로 되돌리지 않는 동작.
- 첫 TV 프레임 및 복귀 확인 중 재생/오디오 차단. 브라우저와 컨트롤러의 기존 동작 유지.
- 준비 요청 읽기, 미디어 준비, 응답 저장, heartbeat 실패를 별도로 기록하고 제한적으로 재시도하는 동작.
- `permission-denied`/`unauthenticated` 시 재시도 중단. Riverpod 기본 오류 재시도가 이를 우회하지 못하는 동작.
- 응답 저장 재시도는 미디어 준비를 반복하지 않으며, background/계정/요청 변경 뒤 오래된 준비 완료를 쓰지 않는 동작.
- heartbeat 등 준비 오류가 남으면 기존의 성공 응답만으로 준비 완료를 표시하지 않는 동작.

## CI와 배포 선행 조건 검토

`tool/tv-recovery-tests.json`은 필수 파일과 사례 이름을 고정한다. `tool/tv-recovery-check.mjs`는 Flutter machine 이벤트에서 실제 파일 실행, 필수 사례 실행, 완료 및 성공을 확인한다. 빠진 파일/사례, skip, 실패, 중복 완료 또는 불완전한 실행은 성공으로 처리하지 않는다. 필터 없이 지정된 파일을 실행하며, runner 자체의 오류 처리 테스트도 함께 실행한다.

네 곳의 실제 워크플로를 별도로 검토하고 Ruby 표준 YAML 파서로 단계 순서·작업 의존성·결과 보존 조건을 검사했다. TV 회귀 단계에는 조건부 실행이나 `continue-on-error`가 없으며, 실패한 뒤 배포를 계속하는 경로가 없다.

| 워크플로 | 필수 선행 관계 | 배포/업로드 차단 범위 |
| --- | --- | --- |
| `.github/workflows/firebase-development.yml` | `validate`에서 TV 회귀 완료 후 웹 빌드. `deploy`는 `validate`와 `class_start_regressions` 필요 | development Functions, rules, web 모두 |
| `.github/workflows/firebase-hosting-merge.yml` | `app_validation`에서 TV 회귀. `firebase_required`가 `app_validation`, `firebase_contracts`, `deployment_plan`, `class_start_regressions`의 성공을 확인. `firebase_production`은 `firebase_required` 필요 | production rules-only/backend/full 경로 모두. Hosting은 full일 때만 |
| `.github/workflows/google-play-main.yml` | `upload` 작업 안에서 TV 회귀 후 서명 번들 빌드 및 업로드. `class_start_regressions` 성공도 필수 | Android/TV AAB 빌드 및 Play internal 업로드. 수동 build-only도 회귀 검사를 통과해야 함 |
| `.github/workflows/testflight-main.yml` | `verify`에서 TV 회귀. `upload` 조건에 `verify`와 `class_start_regressions`의 성공을 명시 | iOS archive/IPA 빌드 및 TestFlight 업로드. 수동 build-only도 verify 필수 |

`[skip google-play]`, `[skip testflight]`, `[backend only]`는 해당 native 업로드를 생략한다. TV 검사만 생략하고 업로드를 계속하는 우회 조건으로 사용되지 않는다. 수동 build-only 입력은 backend 배포 대기를 생략할 수 있지만 TV 회귀 검사는 생략하지 못한다.

각 검증 작업은 성공/실패와 관계없이 `build/sta176/`를 `tv-recovery-{development|web|android|ios}-{run_id}-{run_attempt}` artifact로 30일 보존한다. 여기에는 실행된 Flutter machine 이벤트와, 성공한 경우 검증된 `flutter-results.json`이 들어간다. 결과 파일이 없으면 artifact 단계도 오류가 나며, 원래 회귀 검사 실패를 성공으로 바꾸지 않는다. 이 문서는 GitHub 브랜치 보호 설정이나 운영 배포 실행을 변경/검증했다고 주장하지 않는다.

Android development 디버그 APK는 `fvm flutter build apk --debug --dart-define=FIREBASE_ENV=development`로 빌드에 성공했다. 산출물은 `build/app/outputs/flutter-apk/app-development-debug.apk`다. 빌드 성공은 기기 설치·실행이나 서명된 출시 AAB 검증을 뜻하지 않는다.

## PR #61 및 최신 develop 통합

최초 STA-176 후보 `caf4e19`에 PR #61의 `c065f3a`를 통합한 커밋은 `2112116`이며, develop의 PR #60(`877c2ca`)도 `2a76ace`에서 반영했다. 앞 절의 1,089개·67개 및 APK 결과는 최초 후보의 기록이며 이 통합본의 증거로 재사용하지 않는다.

충돌 해소에서는 최신 승인 revision·삭제 tombstone·첫 SDK 모순 REST 재확인·dispose 보호를 유지하고 각 REST 읽기에 8초 제한을 결합했다. 복구 controller의 loading 우선 guard와 공유 handshake를 모두 보존했다. 시작 직전 및 transaction 재시도의 취소 확인, 예약 실행의 계정 A→B→A latch도 유지했다.

준비 작업은 STA-176의 제한된 재시도만 사용한다. 15초 blanket invalidate를 제거하고 원본 오류·stack·operationId·stage 계측을 결합했다. 요청 stream 오류는 즉시 노출해 캐시된 준비 작업을 취소하며, 권한 거부와 예산 종료 후에는 연결/foreground 등 새 scope 전까지 중단한다. 누락 UID 복구는 서버 검증 경로 한 곳에서 수행하며 기존 PR #61 회귀를 이 계약에 맞춰 검증한다.

재연결 시 현재 연결 세대의 verifying/ready/failed를 datasource에서 controller까지 전달한다. disconnect부터 해당 세대의 서버 검증 및 presence publish 완료까지 준비 구독·heartbeat를 차단한다. 일반 요청은 권한 거부/예산 소진을 다시 열지 않고 명시적 refresh 또는 새 연결만 복구를 시작한다. 최초 신규 TV 코드 발급도 UID·기기별 singleflight로 묶어 provider 재빌드가 두 코드를 발급하지 못하게 했다. 실제 datasource → repository/actions → 생성된 controller → 준비 hook 회귀를 포함한 관련 43개 검사가 통과했다.

PR #61의 14개 suite VM/Chrome gate와 STA-176의 7개 suite TV gate를 모두 유지한다. STA-176 manifest는 기존 67개를 모두 유지하고 REST 제한시간 2개 및 현재 연결 readiness/권한 중단 3개를 더해 필수 72개 이름을 요구한다. 겹치는 suite의 통과 수를 합산하지 않는다. 두 runner 모두 새 실행 전에 이전 성공 결과를 제거하고, 실패한 실행의 새 로그를 보존한다. 배포의 두 gate 의존성과 실제 기기 출시 증거 gate도 유지한다.

최종 보완 작업 트리에서 분석은 `No issues found!`, 수업 시작 VM gate는 **143개**, TV gate는 **91개** 통과했고 skip은 0개다. TV의 필수 72개 이름도 모두 확인했다. [통합 TV 결과](release/sta176/integration-flutter-results.json)와 [수업 시작 VM 결과](release/sta176/integration-class-start-vm.json)를 별도로 보존했다. 서버 기준 `2a76ace`의 Node 221개와 Firebase 계약 29개도 모두 통과했다. 전체 Flutter, 필수 Chrome 및 최종 후보 head 검증은 PR #63의 CI 결과와 artifact에서 확인한다. 실제 배포와 실기기 검수는 이번 작업 범위에 포함하지 않는다.

## 아직 수행하지 않은 검증

다음 항목은 모두 **미수행**이다. 로컬 Flutter 테스트와 CI 설정 검토를 실제 Android/Google TV의 네트워크·절전 동작 검수로 대체하지 않는다.

- [ ] Android/Android TV 출시 AAB 빌드 및 실제 기기 설치·실행. development 디버그 APK 컴파일만 완료했다.
- [ ] 이 변경을 포함한 iOS archive/IPA native 빌드·설치·실행.
- [ ] 실제 Android TV/Google TV 3대를 동시에 연결한 실기기 매트릭스. 각 기기의 모델, OS, app version/build, 후보 SHA 및 동일 센터 연결 여부를 기록한다.
- [ ] 3대가 같은 수업을 재생하는 상태에서 한 대만 복구 요청. 나머지 두 대의 수업/타이머/음성이 유지되고, 공유 start/pause/end가 생성되지 않는지 확인한다.
- [ ] 화면 절전·앱 background 상태에서 오디오 중단, 첫 복귀 확인 실패 후 사용자 조작 없이 재시도, 복구 후 현재 서버 session/revision 및 재생 위치 확인.
- [ ] Wi-Fi 차단·복구와 라우터 재시작을 각각 세 번 이상 반복. 끊긴 이전 연결의 onDisconnect가 새 연결의 온라인 상태를 덮지 않는지 확인한다.
- [ ] 네트워크 단절 중 시작/일시정지/종료·다른 수업 교체. TV 복귀 시 최신 서버 상태만 반영하고 종료된 수업이나 과거 음성이 재생되지 않는지 확인한다.
- [ ] 인증 토큰 갱신과 만료/거부, 연결 해제 및 다른 계정 로그인 중 복구. 권한 오류는 중단하고 이전 계정/연결의 늦은 응답을 수락하지 않는지 확인한다.
- [ ] 이전 배포 버전 TV와 새 TV가 섞인 환경. 기존 연결과 수업 재생이 유지되고, 지원하지 않는 원격 복구에는 업데이트 안내가 나오는지 확인한다.
- [ ] 준비 요청 읽기·이미지/음원 준비·응답 저장·heartbeat를 각각 실패시켜 관리 화면의 단계/오류 코드/재시도 상태와 현장 조치 문구를 확인한다.
- [ ] 실제 3대의 24시간 연속 운영. 절전/재연결/수업 전환, false online/false ready, 미완료 요청, 반복 재시도, 음성 중복 및 메모리/리소스 이상 여부를 기록한다.
- [ ] production Functions/RTDB rules 배포, 실제 배포된 함수 및 rules 해시 확인, 운영 canary와 native 배포 순서 확인.
- [ ] Play/TestFlight 업로드 및 production rollout. 이 작업에서는 어느 것도 실행하지 않았다.

실기기/배포 검수에는 후보 SHA, UTC/KST 발생 시각, 기기별 app version/build, 기대한 session/revision, 실제 상태 및 오류 코드를 남긴다. 인증 토큰이나 고객 개인정보 대신 테스트용 비식별 기기 라벨을 사용한다. 실패한 항목이 있으면 해당 후보를 현장 검증 완료로 표시하지 않는다.
