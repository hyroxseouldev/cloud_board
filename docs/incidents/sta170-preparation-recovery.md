# STA-170 · TV 준비 미완료 복구

## 확인 범위와 원인

2026-10-14 오후에 읽은 운영 상태에는 선택된 Android TV 3대(build 68), 준비 요청 1건, 응답 0건이 있었다. 그중 한 TV는 서버의 `displayAccess` 연결 매핑이 남아 있었지만 기기 레코드의 `displayUid`가 없었다. 이 자료는 오전 장애 시점의 스냅샷이 아니며, 3대 모두 또는 오전 장애 전체가 같은 원인이라는 증거는 아니다. 고객 식별자·토큰·원본 레코드는 저장소에 넣지 않았다.

동일한 결손 형태를 익명 fixture로 재현하면 기존 매핑을 이용한 heartbeat/온라인 표시는 가능하지만, 준비 요청 읽기와 준비 응답 쓰기는 규칙에서 거부된다. 기존 앱의 `_markOnline`은 누락된 역방향 UID를 복구하지 않았다. 따라서 ‘연결됨/온라인’만으로 준비 통신이 허용된다고 볼 수 없었다. 오후 시작 단계의 provider 수명 오류(STA-166)와는 다른 경로다.

## 복구와 권한 경계

기존 익명 TV가 다시 진입할 때 서버 연결 매핑의 owner·device·pairingCode와 현재 기기 레코드를 확인한다. `displayUid`가 없으면 그 **필드 하나만** transaction으로 자신의 실제 Firebase Auth UID로 복구한 뒤 일반 heartbeat를 수행한다. 성공한 복구 뒤 heartbeat가 끊겨도 재진입은 기존 UID를 유지하고 이어간다. 동시 복구는 같은 UID로 수렴하며 다른 UID·코드·기기·해제된 연결은 덮어쓰지 않는다.

추가 RTDB 쓰기 허용은 `devices/$deviceId/displayUid` 하위 경로에 한정된다. 익명 로그인, 기존 서버 매핑의 owner/device/code 일치, 기존 paired 기기, 기기 id 일치, 삭제 요청 없음, 기존 UID 없음 또는 동일함을 모두 요구한다. 전체 기기 쓰기·신규 기기 생성·다른 UID 할당 권한을 추가하지 않는다. 준비 요청/응답의 기존 대상·세션·revision·manifest·만료 검사는 유지한다. 기존 legacy pilot 상위 권한은 이 변경과 별개이며, 새 하위 규칙 검증은 pilot 권한을 제거한 fixture에서도 실행한다.

TV 화면은 pairing 복구가 끝나기 전 준비 스트림을 시작하지 않는다. pairing 실패는 재연결·앱 복귀 또는 연결된 상태의 15초 재시도로 복구한다. 종료된 준비 구독도 재연결/복귀 및 15초 주기로 다시 연다. 로딩·오류 상태에 남은 이전 요청 값으로 새 준비를 시작하지 않는다. 만료·해제·백그라운드·새 요청은 기존 취소 경계를 유지한다.

## 실패 구분과 사용자 흐름

`tv.prepare.request`, `tv.prepare.listen`, `tv.prepare.receipts`, `tv.prepare`는 각각 요청 전송, TV 요청 구독, 컨트롤러 응답 구독, TV 자료 준비/응답 저장을 구분한다. 실패 코드는 `prepare_request/listen/receipts/images/audio/response`이며, 진단에는 원본 오류·stack·Firebase code·operationId·preparationStage·해당 후보 session/revision을 연결한다. 토큰·pairing code·display UID·수업 본문은 새 계측 필드에 넣지 않는다.

TV의 자료 준비 성공은 서버 응답 저장이 확인된 뒤에만 성공 계측으로 남긴다. 응답 저장은 8초 한도이며 시간 초과는 실패로 기록한다. 늦은 SDK 완료가 성공 계측으로 바뀌지 않는다. 실제 ACK와 수업 시작은 기존 서버 검증을 계속 따른다.

기존 TV 체크박스와 재확인 버튼을 유지한다. 요청 오류가 떠도 아래 안내를 줄바꿈하여 계속 표시한다.

> 준비되지 않은 TV는 체크를 해제하면 제외하고 수업을 시작할 수 있어요.

자동 제외나 별도 제외 버튼을 추가하지 않는다. 사용자가 체크를 해제하면 새 대상 목록으로 새 준비 후보를 만들고, 남은 TV의 최신 응답이 확인되어야 시작할 수 있다.

## 수업 중 연결 끊김과 컨트롤러 복구

추가 조사에서 컨트롤러 재연결의 별도 재현 가능한 결함을 확인했다. REST가 최신 수업을 확인한 뒤 recovery controller가 active provider를 다시 구독할 때, broadcast 확인값은 재전달되지 않고 repository는 이미 서버 응답을 받은 상태라 로컬 checkpoint도 내보내지 않았다. SDK의 첫 값이 더 오래된 캐시이면 stale 필터에 걸려 새 구독이 값을 받지 못하고 복구가 실패했다. 실제 datasource → repository → generated recovery controller 회귀는 수정 전 실패하고 수정 후 통과한다. 이것이 현장에서 보고한 제어 불가의 확정 원인이라는 뜻은 아니다.

성공한 서버 확인이 있었는지를 값과 별도로 보관해, 재구독에 마지막으로 승인한 상태 또는 확인된 삭제(null)를 전달한다. 이후 수신한 더 최신 revision·다른 세션·삭제도 반영해 이전 확인값으로 되돌리지 않는다. 첫 SDK 이벤트가 서버 확인값과 null 여부에서 모순되면 서버를 다시 조회해 캐시와 실제 삭제/새 수업을 구분한다. 이 조회는 전송 연결을 재시작하거나 명령을 보내지 않으며, 실패·폐기·더 최신 확인과의 경합을 정상 복구로 바꾸지 않는다.

명시적 재시도에서는 provider가 갱신 중 유지하는 이전 오류/값을 새 확인 결과로 사용하지 않는다. recovery controller는 loading이 끝난 뒤 현재 오류 또는 최신 값/null을 판정한다. 최초 재확인 실패 뒤 서버가 정상 응답해도 이전 AsyncError 때문에 재시도가 즉시 실패하던 회귀를 함께 수정했다.

개별 TV의 ACK는 전달 결과 관찰이며 전체 제어를 잠그는 조건이 아니다. 휴대폰 자체의 서버 연결 확인이 진행 중이거나 실패했다면 기존 복구 화면과 ‘다시 연결’을 사용하고, 확인된 최신 수업으로 복귀한다. 디스플레이 설정의 TV별 ‘최근 응답 수신/TV 응답 확인 필요’ 표시는 휴대폰의 연결 복구 화면과 구분해 유지한다. 진단도 `playback.control.submit`, `playback.control.ack`, `playback.recover`로 나누어 기록한다. 기존 수업을 종료·재시작하거나 재생 명령을 자동 재전송하는 우회는 추가하지 않는다.

## 자동 검증

- RTDB 격리 에뮬레이터: 복구 전 요청 읽기/응답 거부, 필드 하나 복구 후 요청/응답 성공, 반복 복구, 관련 없는 동시 필드 수정 거부, 다른 UID·코드·기기·해제·삭제 요청 거부, stale 응답 거부, 제외 TV가 새 후보의 ACK/active target이 될 수 없음. `functions/test/display-preparation-emulator.mjs`는 기존 필수 Firebase 계약 manifest에 포함된다.
- Flutter 실제 datasource fake transaction 회귀: 기존 연결·재실행·동시 복구, 부분 성공 후 재시도, 다른 UID 경합, 복구 중 해제 시 기기 재생성 금지.
- Flutter 실제 준비 hook/controller·화면 회귀: 응답 저장 전 성공 금지, 권한/timeout 원본 진단, 연결·구독 회복, pairing 완료 대기, 만료/폐기 취소, 오류 중 체크 해제 안내와 재확인. 기존 stale/revision/manifest/만료/미디어 실패 검증 유지.
- 재연결 재구독 회귀의 수정 전/후 로컬 증거: `/tmp/sta170-recovery-seed-red.log`, `/tmp/sta170-recovery-seed-green.log`. 이후 추가된 부분 연결 끊김/복구 검증까지 포함한 최종 결과는 PR의 CI artifact로 보관한다.
- 필수 VM/Chrome 실행 목록과 missing/skip/0건 차단은 `tool/class_start_regressions.mjs` 및 STA-166 공유 CI가 관리한다.

2026-10-14 로컬 검증(Flutter 3.47.0, `38a2f60611d74826bd967b74f6dc903da93b07a9` 기반 STA-166/170 작업 사본):

| 검사 | 결과 | 로컬 로그/증거 |
| --- | --- | --- |
| `dart run build_runner build --delete-conflicting-outputs` | 성공, 관련 provider hash 5개 갱신 | `/tmp/sta170-codegen.log` |
| `FLUTTER_BIN=…/flutter node tool/class_start_regressions.mjs vm` | 필수 8개 파일 57/57, skip 0 | `/tmp/sta170-required-vm.log`, `build/class-start/vm.jsonl` |
| 같은 runner `chrome` | 실제 Chrome 57/57, skip 0 | `/tmp/sta170-required-chrome.log`, `build/class-start/chrome.jsonl` |
| `flutter analyze` | No issues | `/tmp/sta170-analyze.log` |
| `cd functions && npm test` | 176/176 | `/tmp/sta170-functions.log` |
| `node --test tool/class_start_regressions.test.mjs` | 8/8, 누락/skip/0건 거부 검사 포함 | `/tmp/sta170-required-suites.log` |
| RTDB 준비 계약 에뮬레이터 | 성공, production 연결 없음 | `/tmp/sta170-emulator.log` |

에뮬레이터는 `JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' firebase emulators:exec --only database --project demo-cloudboard-preparation --config /tmp/sta170-firebase.json 'node functions/test/display-preparation-emulator.mjs'`로 실행했다. 임시 config는 이 저장소 규칙과 격리 RTDB/hub/logging 포트 19400/19401/19402만 사용한다. 로그는 재현 환경의 로컬 증거이고 고객 운영 데이터가 아니다. 위 표는 STA-170 단독 변경의 검증 기록이다. STA-166 추가 취소/예약 및 부분 연결 끊김 회귀까지 포함한 최종 필수 파일과 전체 앱 회귀, 후보 SHA의 CI 결과는 통합 PR의 검증 항목과 Checks에서 관리한다. 이 수치는 실기기 성공률을 의미하지 않는다.

## 배포 및 남은 확인

운영 Firebase·고객 TV 쓰기, 실기기 조작, 배포, 스토어 업로드는 수행하지 않았다. 승인 후 먼저 새 하위 복구 규칙을 검증·배포하고, 그 규칙을 이용하는 TV 앱 패치를 배포한다. 이전 앱은 스스로 새 복구 코드를 실행하지 않으므로 서버 규칙만으로 기기 UID가 채워지지 않는다. 원격 고객 레코드 일괄 수정을 이 작업에 포함하지 않는다.

격리 테스트 계정에서 기존 정상 연결·신규 연결·누락 UID 복구·앱 재실행·네트워크 끊김/복구·선택 해제 후 남은 TV 시작을 실제 Android TV와 컨트롤러에서 검수해야 한다. 후보 SHA, 각 기기 빌드, 요청/응답/세션 시각과 단계 진단을 제한된 QA 기록에 남긴다. 운영 승인 조건은 [STA-166 기록](sta166-start-lifecycle.md)의 exact-SHA 실기기 승인 절차를 따른다. 이후 실제 준비 요청 대비 응답/시작 결과로 확인하며, 요청 자체가 없는 시간대를 성공으로 세지 않는다.

추가 현장 증상인 ‘TV 한 대가 끊긴 뒤 나머지 두 대는 재생하지만 휴대폰 제어는 불가’는 발생 시각과 원본 로그가 확인되지 않았다. 오전 준비 실패 또는 오후 시작 실패와 원인이 같다고 단정하지 않는다. 다음 검수는 실제 Google TV Streamer를 포함한 TV 3대와 격리 계정으로 별도 기록하며, 자동 테스트로 실기기 통과를 대체하지 않는다.

- [ ] 진행 중 TV 한 대의 네트워크만 차단하고 나머지 두 대의 화면·타이머 및 정상 휴대폰의 일시정지·재개·슬라이드 이동을 확인한다.
- [ ] 휴대폰 잠금/백그라운드→복귀, Wi-Fi↔모바일 데이터 전환, 서버 조회 지연·일시 실패를 각각 재현한다.
- [ ] 최신 서버 세션을 확인한 뒤 기존 수업·위치에서 제어가 회복되는지 확인한다. 만료 명령 재전송, 새 세션 생성, 정상 TV의 종료·재시작 또는 타이머 초기화가 없어야 한다.
- [ ] 복구 실패 시 기존 ‘다시 연결’로 회복하고, 휴대폰 연결 문제와 개별 TV 미응답이 구분되는지 확인한다.
- [ ] 동일 계정의 예비 컨트롤러로 진행 중 수업에 진입해 제어를 이어간다. 검증 전 예비 컨트롤러 절차를 코치용 운영 안내에 확정적으로 기재하지 않는다.
