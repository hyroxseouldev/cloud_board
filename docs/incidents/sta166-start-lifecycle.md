# STA-166 · 준비 완료 후 시작 실패

## 원인과 수정

2026-10-14 이슈에 기록된 Android build68 스택은 `preferences.apply(fresh: true)` 뒤 자동 폐기된 `playbackActionsProvider`의 Ref를 preparation 지연 콜백이 읽는 경로다. 원본 운영 소스 `020371c`의 생성 provider를 사용하는 격리 재현에서 구독 없는 시작은 같은 UnmountedRefException, 작업 중 구독을 유지한 대조군은 성공했다. 이 재현은 오후 장애의 코드 원인을 확인하며 전체 실패 17회가 모두 같은 오류였다는 뜻은 아니다.

시작 컨트롤러는 권한 확인 뒤 첫 기기 ID 조회 전부터 actions를 구독하고, 설정 → 준비 확인 → 세션 생성이 끝나는 모든 경로에서 구독을 닫는다. actions는 준비 검증 의존성을 동기적으로 확보한다. 준비 서버 시각과 split-playback 정책도 비동기 콜백에서 Ref를 다시 읽지 않고 확보한 서비스를 사용한다.

계정 변경, actions 무효화, 컨트롤러 폐기는 작업 epoch/구독을 통해 취소한다. 각 await 이후와 RTDB transaction 재실행 전에 계정 유효성을 확인해 이전 계정의 새 세션을 쓰지 않는다. 화면 이동만으로는 이미 제출한 작업을 취소하지 않는다. 취소 검사는 repository와 datasource를 통해 연결·기기·정책·현재 세션 조회 이후, snapshot 쓰기와 transaction의 매 재실행 직전까지 전달한다. 서버에 commit된 뒤 캐시 저장 실패나 계정 전환은 이미 만들어진 세션을 실패로 바꿔 재시도시키지 않는다. 늦은 시작 응답이 최신 revision·교체된 세션·삭제된 세션의 로컬 checkpoint를 덮지 않도록 수신 버전을 확인한다. RTDB transaction timeout의 commit 여부 불확실성은 기존 서버 확인/복구 정책을 따른다.

시작 중 추가 탭은 무시한다. 실패 시 loading을 해제하며 다시 준비·시작할 수 있다. 같은 actions를 사용하는 예약 시작도 최초 예약 조회부터 계정 변경을 감시하고, 실행할 예약이 확인되면 session 조회부터 시작 완료까지 actions 구독을 유지한다. 기존 예약 선점과 준비 검증 조건은 변경하지 않는다. 준비 proof, 콘텐츠 fingerprint, 만료, 대상 TV, entitlement, 권한 검사는 유지한다.

## 진단

`playback.control.submit`의 operationId와 `playback.start.device/preferences/preparation/session` 단계 breadcrumb를 연결한다. 실패 code는 `start_access/device/preferences/preparation/session/cancelled` 또는 기존 PlaybackFailure code다. 세션 생성 후 기존 `playback.control.ack`가 sessionId/revision과 TV ACK를 별도로 기록한다. 세션 commit 성공과 TV 수신 성공은 같은 의미로 처리하지 않는다. 토큰, 수업 본문, 이메일은 새 진단 필드에 포함하지 않는다.

## 검증 기록

로컬 Flutter 3.47.0에서 신규 lifecycle/commit 회귀는 VM 18/18, 실제 Chrome 18/18 통과했다. 동일 lifecycle 파일을 원본 운영 소스 `020371c`에 적용하면 지연 설정 조회 중 actions가 유지되어야 한다는 검사가 실패한다. 별도의 원본 재현에서는 동일한 UnmountedRefException을 확인했다. 테스트 데이터는 격리 fixture이며 운영 TV/session 쓰기를 하지 않았다.

## 필수 회귀

- `playback_start_lifecycle_test.dart`: 실제 generated actions/controller/preferences/preparation provider, 기기 ID/설정 지연, 3대 준비 후 목록·편집 화면 시작, 중복 탭, 화면 이동, 계정/의존성/컨트롤러 변경, 실패 후 재시도, 미준비/오래된/만료/다른 콘텐츠/권한 거부.
- `playback_start_commit_test.dart`: 서버 commit 뒤 캐시 실패 및 계정 변경이 중복 쓰기/잘못된 시작 실패를 만들지 않으며 최신/교체/삭제된 checkpoint를 보존함.
- `playback_metadata_test.dart`: 실제 datasource의 서버 대기·transaction 재실행 중 취소, commit 후 성공 유지.
- `schedule_runner_initialization_test.dart`: 실제 generated actions의 지연 예약 시작과 최초 조회 중 계정 변경, 준비 검증 및 예약 선점 조건 유지.
- 기존 display-preparation/ACK 및 Firebase 계약: 응답 검증·출시 클라이언트·TV 권한. STA-170의 연결 식별자 복구 계약은 함께 실행한다.

`class-start-regressions.yml`은 VM 및 Chrome에서 명시한 필수 파일을 실행하고, 실제 machine 이벤트에 성공 완료·실행된 테스트가 있는지 확인한다. fail/error/skip/missing/0건은 모두 실패다. web `firebase-required`, 개발 Firebase 배포, Android 업로드, iOS 업로드가 이 job 성공을 필요로 한다. 최종 10개 필수 파일과 전체 앱 테스트의 결과는 통합 PR의 검증 항목과 Checks에서 관리한다. 각 CI run/attempt의 `class-start-*` artifact에 후보 SHA, 플랫폼, suite, 실행 수와 원본 결과를 보관한다. Firebase 계약 게이트와 기존 exact-SHA backend 검증도 유지한다.

## 실기기 검수와 운영 승인

자동 검증은 실기기 검수를 대체하지 않는다. 사용자 요청대로 실기기 테스트·배포·스토어 업로드는 수행하지 않는다. 격리 개발 Firebase 후보와 테스트 계정을 사용하여 Android/iOS/Web 컨트롤러별 실제 TV 3대 시작 10회, 일시정지/재개/종료, 재실행/연결 복구, 기존·후보 TV 빌드를 검수한다. 기기 모델, 빌드, 후보 SHA, session ID, 시각, 화면 및 CI 증거는 접근 제한된 QA 기록에 남긴다.

운영 Firebase/web 변경은 릴리스 담당자가 `CLASS_START_PHYSICAL_APPROVAL` repository variable에 아래 JSON 형태의 실제 승인 기록을 입력해야 진행한다. 예시는 승인 결과가 아니며 저장소/변수에 자동 설정하지 않는다. SHA가 바뀌면 기존 승인은 통과하지 않는다. 내부 build-only 산출물과 개발 환경 검증은 이 운영 승인 조건의 대상이 아니다. 승인 전 Android/iOS 기기 검수는 같은 후보 소스를 개발 Firebase 대상으로 빌드한 개발 서명 앱을 내부 설치하여 진행할 수 있다. 기존 internal/TestFlight 업로드의 exact-SHA 운영 backend 확인은 유지되므로, 그 자동 업로드를 승인 전 검수의 유일한 진입 경로로 사용하지 않는다. 스토어 공개/단계적 rollout은 별도 운영 승인 후 진행하며 이 저장소의 internal/TestFlight 업로드가 공개 출시 승인을 의미하지 않는다.

```json
{
  "sha": "<40-character candidate SHA>",
  "result": "passed",
  "approvedBy": "<release owner>",
  "testedAt": "<ISO timestamp>",
  "evidenceUrl": "https://<restricted QA record>",
  "isolatedTestAccount": true,
  "tvBuilds": ["<supported build>", "<candidate build>"],
  "controllers": {
    "android": {"starts": 10, "tvCount": 3, "pauseResumeEnd": true, "reconnectAndRestart": true, "build": "<build>"},
    "ios": {"starts": 10, "tvCount": 3, "pauseResumeEnd": true, "reconnectAndRestart": true, "build": "<build>"},
    "web": {"starts": 10, "tvCount": 3, "pauseResumeEnd": true, "reconnectAndRestart": true, "build": "<build>"}
  }
}
```

이미 설치된 1.1.0/1.1.1 네이티브 앱의 provider 수명 문제는 서버 배포만으로 고쳐지지 않는다. 패치 앱 업데이트가 필요하며 버전·빌드는 실제 업로드 시 기존 릴리스 도구로 결정한다. 출시 후 실제 시작 시도 대비 성공률과 동일 Crashlytics 오류를 확인하고, 시작 시도가 없는 상태를 성공으로 기록하지 않는다.
