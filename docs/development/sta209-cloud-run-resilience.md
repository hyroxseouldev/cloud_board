# STA-209 — 함수 장애와 기존 수업 진입 분리

대상은 **Auth·Firestore·RTDB·Storage는 정상이고 Cloud Run/Functions만 실패하는 경우**다. 전체 인터넷 장애에서 새 수업을 시작하거나 새 기기 등록·AI 생성·수업 저장을 우회하는 기능이 아니다.

## 앱 진입

기존 Firestore entitlement 매퍼의 서버 권한/만료 판정을 사용하고, RTDB의 서버 응답과 plan/status/validUntilMs/revision/source/policyVersion 및 canStartClass를 대조한다. SDK의 캐시 fallback을 서버 확인으로 사용하지 않는다. 정상 기존 계정은 온보딩 `load`를 호출하지 않는다. 권한 없음·불일치·만료에는 기존 활성화/복구 경로가 유지되며, 명시적 센터 정보 편집은 계속 서버를 호출한다. 계정 변경, 서버 거부, 만료는 이전 진입 성공을 무효화한다.

## 디스플레이 재접속

등록 감사에서 `displayAccess`와 기기 역참조, 현재 UID/센터/기기/연결 코드/등록 시각, 중복 정방향·역방향 소속, 해제 기록, 계정 삭제, Firebase Auth 상태를 확인한다. 서버만 `displayResumeGrants/{displayUid}`를 발급한다. 별도 기기 UID가 없는 기존 owner 인증 디스플레이는 `ownerDisplayResumeGrants/{ownerId}/{deviceId}`로 구분한다.

등록 증명이 있는 기기의 정상 접속은 새 연결 ID의 onDisconnect 등록 → Auth 토큰 갱신 → DB 서버 조회 → RTDB transaction으로 끝난다. `verifyDisplayConnection`과 수동 복구 함수는 정상 경로의 선행 조건이 아니다. 쓰기 시점의 규칙이 권한을 다시 강제한다. 등록 정보 또는 증명이 없는 경우에만 기존 서버 검증/복구를 사용한다.

`presenceProtocol: 2`의 각 새 연결은 규칙이 허용한 `authorizedAtMs`를 갖는다. `connectionVerification`을 복사하거나 덮어쓰지 않는다. 이전 연결의 지연 onDisconnect는 그 연결의 슬롯만 오프라인으로 만든다. 현재 연결 ID를 기존 슬롯으로 되돌리거나 서버 검증값·소속·등록·권한을 위조하는 쓰기는 거부한다. 검은 화면/대기/활성 기기 정책은 재접속으로 변경하지 않는다. 최신 수업 복구·미디어 준비·실제 준비 ACK는 기존 재생 경로를 그대로 사용한다.

## 반드시 먼저 확정할 서버 운영 전제

Firebase RTDB 규칙은 Auth 관리 API의 disabled/tokensValidAfterTime을 직접 조회할 수 없다. [Firebase의 세션 관리 문서](https://firebase.google.com/docs/auth/admin/manage-sessions)와 같이 서버 관리 상태 `authAccess/{uid}`의 disabled/validAfterSeconds와 `auth.token.auth_time`을 비교한다.

- 정지/토큰 폐기는 `functions/src/auth-access.js`의 `revokeAccountSessions`로 **DB 차단 → Auth 변경** 순서로 수행한다. 중간 실패는 차단 상태를 유지한다. 계정 삭제 경로도 이 함수를 사용한다.
- Firebase Console 또는 다른 Admin 스크립트가 Auth만 직접 변경하면 DB 미러와 원자적으로 동기화되지 않는다. 앱의 강제 토큰 갱신은 정직한 클라이언트의 재접속을 차단하지만, 이를 기존 토큰을 가진 공격자에 대한 DB 규칙 보장이라고 보고하지 않는다.
- 모든 관리 변경 경로가 이 전제를 지킨다는 확인 전에는 `displayResumePolicy/authoritativeAuthMirror`를 **활성화하지 않는다**. 기본값은 비활성이다. 등록/복구 함수는 비활성 상태에서 새 재접속 증명을 발급하지 않고 기존 함수 검증 프로토콜을 유지한다.
- 등록 소속의 Admin 직접 수정도 기존 증명을 먼저 폐기하고 전체 소속 감사를 다시 수행해야 한다. 앱 클라이언트는 증명을 발급하거나 새 익명 UID의 등록을 만들 수 없다.
- 이 전제의 실제 운영 적용 확인 없이 STA-209 전체 완료나 기존 보안 검증과 완전히 동등하다고 표시하지 않는다. 이번 작업은 운영 정책 활성화·서버/규칙 배포 권한을 포함하지 않는다.

## 기존 등록 준비

정책을 승인한 개발/로컬 환경에서 기존 정상 등록을 미리 감사해 증명을 준비해야 **장애를 먼저 주입한 cold start**가 동작한다. 앱 시작 때 준비 작업을 몰래 수행하거나 이전 권한을 복제하지 않는다.

`node tool/sta209/provision.mjs --project cloud-board-development --display-uid <UID>`는 읽기/감사만 한다. 적용은 동일 명령에 `--apply`를 붙인다. owner 인증 등록은 `--owner <UID> --device <ID>`를 사용한다. 도구는 development 또는 loopback demo 프로젝트만 허용하며 정책을 대신 활성화하지 않는다. 누락/중복/해제/정지 상태를 임의 복구하지 않는다. 정상 사용자 화면에서 새로 등록하거나 실제 누락 역참조를 복구할 때는 기존 pair/verify 서버 경로에서 증명 발급도 함께 처리한다.

## 재현 가능한 로컬 검증

- Flutter: `test/cloud_run_resilience_test.dart`, `test/auth_router_test.dart`, `test/display_presence_test.dart`, `test/display_verification_test.dart`, `test/display_playback_continuity_test.dart`.
- 서버 유닛: `node --test functions/test/display-resume.test.js functions/test/display-recovery.test.js`.
- RTDB 실제 규칙: loopback emulator에서 `FIREBASE_DATABASE_EMULATOR_HOST=127.0.0.1:9000 node functions/test/display-resume-emulator.mjs`. 별도 `demo-cloudboard-resume` namespace를 사용한다. Functions는 필요 없다. 기존 계약은 `functions/test/display-recovery-emulator.mjs`로 확인한다.
- Firestore 실제 규칙: `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node functions/test/onboarding-entry-emulator.mjs`. 홈의 첫 수업 안내는 본인 소유 `onboarding/progress`의 서버 요약만 읽는다. 전화 인증 challenge·다른 계정·클라이언트 수정은 허용하지 않는다. 이 요약은 이용 권한 판정에 사용하지 않는다.
- 앱 화면: `tool/sta209/main.dart`는 development debug web 및 `localhost` 전용이며, 가짜 API 키와 `demo-cloudboard-studio`의 loopback emulator를 사용한다. 업무 provider를 mock으로 교체하지 않는다. `tool/sta209/seed.mjs`는 전용 계정과 저장된 수업을 준비한다.
- `tool/sta209/fault-server.mjs`는 loopback 5001에서 HTTP 500을 주입한다. `/__timeout`으로 응답 지연, `/__500`으로 500 모드 전환이 가능하다. 인증 헤더/요청 본문은 기록하지 않는다.
- 디스플레이마다 격리된 브라우저 프로필에서 `?role=tv1&prepare=true`(tv2/tv3도 동일)로 익명 인증을 먼저 보존한다. 출력 UID를 `node tool/sta209/seed.mjs tv1=<UID> tv2=<UID> tv3=<UID>`에 넘겨 등록한다. 이후 prepare 없이 앱을 재실행한다. 이 준비는 신규 등록 E2E 결과가 아니다.
- 실제 결과와 소스 SHA, 함수 장애 주입 시점, 브라우저/네이티브 차이, 미확인 항목은 PR 증거에 별도로 기록한다. 로컬 브라우저 결과를 iPad/Android TV 전원 재부팅 검증으로 부르지 않는다.
