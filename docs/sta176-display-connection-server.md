# STA-176: TV 연결정보 서버 계약과 출시 순서

이 문서는 개발 후보의 계약이다. 운영 데이터 수정, 함수·규칙 배포, TV 업데이트 및 실제 TV 3대의 24시간 검수는 수행하지 않았다. 실기기 검수는 [검증 문서](sta176-tv-recovery-validation.md)를 따른다. 과거 오1의 `displayUid`가 사라진 시점이나 실제 쓰기 주체는 미확정이다. 규칙에서 재현한 허용 공백과 현장 장애의 원인을 구분한다.

## 읽기 전용 운영 점검

2026-10-15 00:08:28–00:08:30 KST에 `cloud-board-stationd`를 읽기 전용으로 점검했다. 4개 RTDB 사용자 경로에서 등록 TV 3대를 확인했고, 모두 양방향 연결과 실제 익명 Auth 계정이 정상이다. 등록 TV의 누락·불일치는 0대이며 버전은 1.1.1 두 대, 1.1.0 한 대다. 등록 기기 레코드가 없는 owner 지정 `displayAccess` 1건은 별도로 분류했다. 남은 매핑만으로 기기를 재생성하거나 삭제하지 않았다.

- 결과: [식별자를 해시 처리한 점검 JSON](release/sta176/connection-inventory-2026-10-15.json)
- 재점검: `node functions/scripts/inventory-display-connections.mjs --project cloud-board-stationd`
- 실행기는 읽기 명령만 제공한다. 이름·이메일·토큰·원본 UID를 출력하지 않는다.
- 당시 배포 함수 목록에는 연결 검증/복구 callable이 없었다. 기존 `cloudboardPairDisplay`의 등록 로직은 기기 예약 후 매핑을 쓰는 두 단계이며, 별도 연결 보정 함수는 확인되지 않았다. 신규 등록은 이 정책을 유지하되 원자적 서버 경로로 이동한다.

## 권한과 무결성

`functions/src/display-recovery.js`가 등록, 해제, 검증, 수동 요청, TV 결과 보고의 공통 검증을 담당한다. 다섯 callable은 기존 정식 `account-deletion` codebase, `asia-northeast3`에 속한다. 모든 호출에서 서명 검증에 더해 `verifyIdToken(token, true)`로 Auth 삭제·비활성화·토큰 회수를 확인한다.

익명 TV의 보정은 아래 조건을 모두 만족할 때 기존 기기의 누락된 `displayUid`만 채운다.

1. 실제 호출자 UID의 `displayAccess`가 지정 owner/device를 가리킨다.
2. 등록 기기가 존재하고 `paired == true`다.
3. owner/device에 대한 매핑이 하나뿐이며 같은 UID의 다른 등록 기기가 없다.
4. 기존 UID가 없거나 정확히 일치한다. 코드·등록 세대가 양쪽에서 충돌하지 않는다.
5. 누락을 보완할 때는 양쪽에 동일한 pairingCode 증거가 남아 있어야 한다.
6. 계정 삭제나 코드 세대 회수 기록이 없다.

삭제된 기기를 만들거나 다른 UID/owner를 덮어쓰지 않는다. 소유자는 수동 복구를 요청할 수 있지만 실제 TV 인증 없이 누락 UID를 보정할 수 없다. 기존 owner 계정으로 로그인한 구형 TV에는 그 owner의 기존 등록만 검증하고 scoped presence를 지원한다. 별도 TV 신원이 없으므로 `recoveryProtocol: 1`을 부여하거나 TV가 응답한 것으로 처리하지 않는다.

서로 다른 RTDB 트리의 매핑과 등록, 감사 기록, 회수 기록을 같은 root compare-and-swap transaction에 저장한다. 재시도마다 최신 연결정보를 다시 검사한다. 이 경로는 등록·재연결·수동 복구에만 사용하고 heartbeat/준비 응답에는 사용하지 않는다. root 트랜잭션은 전체 RTDB 크기와 동시 쓰기의 영향을 받으므로 확장 전 데이터 크기·충돌률·지연을 확인해야 한다. 연결 경로를 공통 하위 트리로 이전하기 전에는 원자성을 포기한 두 단계 쓰기로 교체하지 않는다.

## Callable 계약

공통 요청은 `operationId`(1–128자 영문/숫자/`_`/`-`), `appVersion`, `appBuild`를 포함한다. 버전은 감사 기록에서 제한된 문자만 보관한다.

| 함수 | 입력 | 결과와 보장 |
| --- | --- | --- |
| `pairDisplayConnection` | `code`, `name`, `zoneName` | `{paired:true, deviceId}`. 코드 claim, device, displayAccess, audit를 원자적으로 저장. 기존 Free/Plus/Premium/legacy 등록 정책 유지. 등록만으로 online으로 표시하지 않음. |
| `unpairDisplayConnection` | `deviceId`, `expectedPairingCode` | `{unpaired:true, deviceId}`. 최신 코드가 다르면 중단. 매핑·등록·코드 해제와 세대 회수를 원자적으로 기록. 완료한 operationId 재전송은 재등록된 기기를 삭제하지 않음. |
| `verifyDisplayConnection` | `deviceId`, `connectionId` | `{ownerId,deviceId,status:'verified' 또는 'repaired',verifiedAtMs,recoveryProtocol}`. 서버 시각의 연결 검증 증거 저장. |
| `requestDisplayRecovery` | `deviceId` | 아래 current 레코드. 살아 있는 요청이 있으면 그 요청에 합류. 동일 작업 재전송은 이전 결과 반환. |
| `reportDisplayRecovery` | `deviceId`, `status`, `sessionId?`, `revision?`, `errorCode?` | 실제 대상 TV만 수신/수행/결과를 보고. 성공은 최신 서버 session ID/revision과 정확히 일치해야 함. |

`users/{ownerId}/displayRecovery/{deviceId}/current`는 서버만 쓴다. 소유자와 해당 TV만 읽으며 첫 요청이 없는 빈 상태도 TV가 구독할 수 있다. 필수 필드는 `schemaVersion:1`, `operationId`, `deviceId`, 내부 대상 `displayUid`, `requestedAtMs`, `expiresAtMs`, `status`다. 유효기간은 서버 시각 기준 60초다.

상태는 `requested → received → recovering → succeeded|failed`다. 접수는 성공이 아니다. 성공에는 `verifiedAtMs`, `completedAtMs`, 최신 `sessionId`/`revision`/`sessionStatus`를 기록한다. 세션이 없는 경우에만 생략/null 값을 `sessionId:null, revision:0`으로 해석한다. 종료된 세션도 최신 종료 revision을 확인하며 서버의 수업·타이머·명령을 수정하지 않는다. 실패는 허용된 코드와 `errorId = operationId`만 저장한다. 무응답은 화면의 60초 타임아웃으로 끝나며 뒤늦은 TV 보고는 서버가 거절한다. 다음 요청 때 이전 만료 작업도 보관된 결과에서 expired로 정리한다.

주요 `HttpsError.details.code`: `connection_missing`, `device_unpaired`, `connection_conflict`, `account_unavailable`, `update_required`, `request_expired`, `request_superseded`, `latest_session_changed`, `permission_denied`, `invalid_request`, `display_limit`. 원문 예외를 사용자에게 보여주지 않는다.

## 연결 감시와 오류

- `devices/{id}/connectionVerification = {connectionId,operationId,verifiedAtMs,requestStartedAtMs,protocol:1}`은 서버 전용이다. handler 진입 시각을 Auth 검증 전에 고정하여, timeout된 이전 호출이 늦게 끝나더라도 새 연결의 증거를 덮지 못한다. 이미 처리된 이전 operationId의 재전송도 새 연결을 되돌리지 못한다.
- `presence/{connectionId}`에는 online, lastSeenAtMs, 선택 readyAtMs만 쓴다. 매 연결마다 해당 경로에 `onDisconnect().set({online:false,lastSeenAtMs:serverTimestamp})`를 먼저 등록하고 검증 후 currentConnectionId를 공개한다. `update`는 등록 시 필드별 권한 평가로 결손 UID의 사전 감시 등록이 실패하므로 전체 종료 레코드를 `set`한다.
- 누락 UID의 최초 보정이 감시 등록 단계에서 막히지 않도록, 유효한 own mapping과 기존 paired 기기에 한해 해당 presence의 `online:false` 종료 기록만 사전 등록할 수 있다. 이 예외로 online이나 인증 증거를 만들 수 없다.
- currentConnectionId는 서버가 검증한 connectionId와 같아야 한다. 늦은 이전 연결의 종료는 그 이전 슬롯만 바꾼다. 화면은 현재 슬롯, 서버 heartbeat 신선도, 인증 증거, 준비 오류를 각각 판정한다.
- `preparationHealth`는 stage(`request_read`, `media`, `response_write`, `heartbeat`), 제한된 code, attempt, 서버 checkedAtMs, 선택 requestId만 허용한다. 미디어 성공과 응답 저장 성공은 구별한다.

## 이전 서버/앱과 회수 경합

신규 해제는 `displayConnectionRevocations/{displayUid}/{pairingCode}`에 해당 코드 세대를 원자적으로 회수한다. 이미 시작된 구형 Admin 등록이 나중에 두 레코드를 다시 써도 같은 세대의 TV 읽기·쓰기·수업 대상 지정·복구는 거부한다. 원본 등록 레코드가 남더라도 권한이 정상이라는 증거가 아니다. 새 코드를 발급한 정상 재등록은 허용한다. 회수 경로는 클라이언트가 읽거나 쓸 수 없으며 감사 기록에는 코드 원문 대신 fingerprint만 남긴다.

구형 owner 앱의 직접 RTDB 해제는 기존의 원자적 device/access 삭제 계약을 유지한다. 그 경로는 새 서버의 회수 transaction을 호출하지 않는다. 따라서 **구형 직접 해제와 이미 실행 중인 구형 Admin 두 단계 등록의 동시 경합까지 완전히 제거하려면 기존 `cloudboardPairDisplay`도 공통 원자 경로로 이관해야 한다.** 해당 기존 codebase의 전환과 혼합 버전 검수는 출시 조건이다. 새 앱만 검증하고 구형 endpoint까지 모두 원자화됐다고 보고하지 않는다.

이 이관은 [STA-172의 소스 소유권 이관 PR #62](https://github.com/hyroxseouldev/cloud_board/pull/62)가 제공하는 `functions-legacy/src/services/pairing.ts`, `functions-legacy/src/index.ts`, `tool/legacy-auth-release.mjs`를 사용하는 별도 호환 [PR #64](https://github.com/hyroxseouldev/cloud_board/pull/64) (`hyroxseouldev/sta176-legacy-pairing`)과 함께 검토한다. 기존 endpoint는 `cloudboard-auth` codebase와 `asia-southeast1`에 있으므로 이 PR의 `account-deletion` codebase에 같은 이름을 추가하지 않는다. 호환 패치의 계약은 기존 handler에서 인증·회수를 검증한 원래 Firebase ID token을 같은 프로젝트의 `asia-northeast3/pairDisplayConnection`으로 전달하고 기존 `{paired:true, deviceId}` 응답을 유지하는 것이다. 호출마다 새 operationId를 사용하며, 같은 호출의 HTTP 재전송은 같은 ID를 유지한다. 새 endpoint가 없거나 응답이 불확실하면 실패로 끝내고 기존 Admin 두 단계 쓰기로 돌아가지 않는다. 새 callable을 먼저 배포하고 legacy bridge와 강화 규칙을 검수한 뒤 새 앱을 출시해야 한다. 코드 패치와 별개로 실제 codebase 배포·혼합 버전 검수는 아직 수행하지 않았다.

## 감사와 출시

`displayConnectionAudit`, `displayConnectionOperations`, `displayRecoveryOperations`, `displayConnectionRevocations`는 일반 owner/TV 모두 접근 불가다. 변경 전후 identity 필드, 서버 시각, 경로, 앱 버전, operationId를 기록하며 이름·이메일·ID 토큰·원문 예외는 기록하지 않는다. 기존 클라이언트 변경도 RTDB 이벤트 감사가 남는다. 두 감사 트리거는 RTDB 인스턴스의 지역인 `asia-southeast1`에서 실행하며 이벤트 ID로 중복 전달을 제거한다. 트리거에 호출자 정보가 없으면 수행 주체를 추정하지 않고 unknown으로 남긴다.

출시는 다음 순서를 따른다.

1. 읽기 전용 inventory를 다시 실행하고 등록 TV의 누락·충돌·회수 건을 분리한다. 알려지지 않은 과거 누락 경로를 확정 원인으로 쓰지 않는다.
2. 격리 개발 프로젝트에 새 callable/감사 경로를 배포하고 실제 앱의 token revocation, 초기 빈 복구 구독, 누락 UID 보정, 코드 세대 경합을 검증한다. 기존 legacy 등록 endpoint의 공통 원자 경로 전환도 준비한다.
3. 검수한 backend와 규칙을 함께 선행 배포한다. 아직 새 callable이 없는 환경에 새 TV 앱을 먼저 배포하지 않는다. 미보완 결손 TV가 있을 때 강화 규칙만 먼저 배포하지 않는다.
4. 후보 TV/관리 앱과 지원 구버전을 섞어서 자동 계약 및 [실기기 검수](sta176-tv-recovery-validation.md)를 완료한 후 단계적으로 출시한다. 네이티브 TV 업데이트 확인 전 완료 처리하지 않는다.
5. 롤백 때 새 callable과 감사·회수 데이터를 유지한다. root map을 과거 snapshot으로 복원하거나 회수 기록을 삭제하면 이미 폐기한 권한이 돌아올 수 있다. 문제 함수의 새 요청을 중지하고 이전 규칙/앱과의 읽기 계약을 검증한 뒤 되돌린다. 사용자 logout·기기 삭제·재페어링을 일반 복구로 사용하지 않는다.

`display-recovery` 에뮬레이터 suite는 공통 Firebase 필수 manifest에 등록되어 있다. 서버 Node 테스트, 실제 최신/지원 구버전 payload 계약, 회수·identity 삭제·빈 구독·3회 재접속·준비 응답·TV 1대 격리를 자동 검증한다. 실기기의 Wi-Fi/절전/24시간 결과는 이 자동 검사로 대체할 수 없다.

2026-10-15 최초 후보 `caf4e19`의 서버 검증: Node 테스트 **208개 통과**(신규 34개 포함), 공통 Firebase 에뮬레이터 **28개 suite 통과, skip 0개**. 에뮬레이터 전체 실행은 00:29:13 KST에 완료했다. HTTP timeout 뒤 오래된 검증이 새 연결 증거를 덮는 경우, 연결 코드 재사용 뒤 이전 pair/unpair 요청이 새 연결을 변경하는 경우, 누락 UID 상태에서 실제 SDK `onDisconnect.set` 사전 등록까지 검사했다.

PR #61 및 최신 develop 통합 서버 기준 `2a76aceda6df4cfb45e3b1a757d1f466717cfbd8` 재검증: Node **221/221**, Firebase 도구 **53/53**, 실제 Firebase 계약 **29/29 suite** 통과, skip 0개. 2026-10-15 00:52:03 KST 완료. support-tickets 계약의 Storage 필수 조건과 기존 함수 export, development 대상 목록도 유지했다. [통합 계약 결과](release/sta176/integration-contract-results.json)는 이 서버 소스 기준의 증거다. 외부 메일 발송과 운영 배포는 수행하지 않았다.
