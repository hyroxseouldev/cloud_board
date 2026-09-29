# 수업 오류 진단 운영 가이드

## 앱에서 확인

실패 안내의 **오류 상세**를 열고 복사한다. 발생 UTC 시각, 오류 ID, 작업, 예외 종류, Firebase plugin/code, 버전/빌드, 해당 수업/워크아웃 ID, revision을 확인할 수 있다. 전송 실패 시에도 상세는 기기에 남아 즉시 확인할 수 있다. 토큰·비밀번호·이메일·전화번호·전체 DB 경로·로컬 사용자 경로는 마스킹한다. 사용자 이름과 워크아웃 제목은 수집 문맥에 넣지 않는다.

Android/iOS/TV의 처리된 오류는 공통 ErrorReporter → Crashlytics non-fatal로 보고한다. Flutter/Platform 글로벌 미처리 예외는 fatal 경로를 유지한다. 같은 예외 객체는 최대 100개의 최근 이벤트 범위에서 중복 보고를 억제한다. 최대 15개 조작 breadcrumb를 이벤트별로 복사하며 계정 전환 시 초기화한다.

웹은 동일 이벤트 → 인증된 `reportClientDiagnostic` callable → Cloud Logging `client_diagnostic`으로 전송한다. Crashlytics 웹 지원을 가정하지 않는다. 앱 재시작을 포함하는 웹 로컬 큐는 최대 30개·24시간, 2–300초 백오프이며 계정 전환 시 이전 계정 내용을 삭제한다. 요청의 accountId와 인증 UID를 서버에서도 대조해 전송 도중 계정 변경을 차단한다.

서버는 16KB payload 한도, 문맥 허용 목록, 이벤트 ID/시각 검사, 계정당 분당 20건, 최근 100개 이벤트 ID 중복 억제를 적용한다. 익명 인증은 실제 연결된 디스플레이만 허용한다. 새 App Check 강제 적용은 하지 않는다. 진단 데이터는 공개 Firestore 경로에 저장하지 않고 로그로 보낸다. rate-limit 문서는 계정당 한 개이며 마지막 요청 24시간 뒤 일일 정리 작업의 대상이 된다(회당 최대 1,000개, 갱신 중인 문서는 트랜잭션으로 보존). 계정 탈퇴 시에도 삭제한다. Cloud Logging 로그 보존은 현재 프로젝트의 버킷 보존 설정을 따른다.

## 오류 ID로 조회

Google Cloud → `cloud-board-stationd` → Logs Explorer:

```text
resource.type="cloud_run_revision"
jsonPayload.message="client_diagnostic"
jsonPayload.eventId="복사한-오류-ID"
```

ID가 없으면 UTC 시각을 좁힌 뒤 `jsonPayload.context.sessionId` 또는 `jsonPayload.context.workoutId`로 조회한다. 모바일은 Crashlytics에서 해당 앱/버전의 non-fatal을 열고 information의 `eventId`, `code`, `context`를 대조한다. session/workout ID를 이용한 계정 자료 조회는 권한 있는 내부 운영자만 수행한다.

`revision_conflict`는 expected와 observed revision을 비교한다. `command_expired`는 elapsedMs·연결 상태와 대조한다. `invalid_index`는 stepIndex/stepCount를 확인한다. Firebase permission-denied는 인증·DB 규칙·연결 해제 시각을 확인한다. 스택과 원래 오류 코드를 보존하며 문자열 `Bad state` 하나로 분류하지 않는다. 진단 수집 자체의 실패는 재귀 보고하지 않는다.

## 웹 소스맵

저장소가 공개 상태이므로 GitHub Actions artifact 자체를 비공개 저장소로 간주하지 않는다. main 배포 CI는 main.dart.js, 소스맵, version.json을 tar로 묶고 **AES-256-GCM 인증 암호화** 후 `cloudboard-web-symbols-<run_number>-<attempt>` artifact에 90일 보관한다. artifact에는 `web-symbols-v1.tgz.enc`만 포함한다. 32바이트 키는 GitHub Actions secret `WEB_SYMBOLS_ENCRYPTION_KEY`와 운영자의 보호된 키 파일로 분리 보관한다. 키가 없으면 배포를 실패시키며 원문을 대신 업로드하지 않는다. PR 빌드는 심볼 artifact를 업로드하지 않는다.

공개 Hosting 출력에서는 `.map` 파일과 sourceMappingURL을 제거한다. 오류의 build 값과 복호화한 version.json이 일치하는 artifact만 사용한다. 이후 빌드의 소스맵으로 과거 스택을 해석하지 않는다. `main.dart.js:행:열` 위치는 마스킹 후에도 남는다. `tool/web_symbols.mjs open INPUT OUTPUT`으로 권한 있는 환경에서 복호화하고 source-map 도구로 원본 위치를 해석한다. 키는 `WEB_SYMBOLS_ENCRYPTION_KEY` 환경 변수로만 전달하고 로그/명령 인자에 넣지 않는다. 도구는 인증 태그 검증을 마친 뒤에만 원문 파일을 쓰며 기존 파일을 덮어쓰지 않는다. 키를 교체하면 기존 v1 키도 해당 artifact 보관 기간 동안 보호해서 유지해야 한다.

2026-09-30 배포 확인 중 공개 저장소 설정을 발견해 최초 72.1/73.1 평문 artifact를 삭제했다. 두 빌드의 심볼은 운영자 로컬 `$HOME/.config/cloudboard/private-web-symbols`에 암호화 보관했고 복호화 일치 검증을 마쳤다. 같은 보호된 디렉터리의 `key-v1.hex`는 권한 600, 디렉터리는 700이며 Git에 포함하지 않는다. 이후 CI 보관은 암호화 파일만 허용한다.

## iOS dSYM 조사

STA-51에 기록된 누락 UUID:

- 1.0.0(2): `E7972151-7635-366C-96BB-F7DC568E1AE6`, 대기 이벤트 1건.
- 1.0.0(534): `0A472440-ADBD-31F8-8B2E-53DEC845AEDB`, 대기 이벤트 4건.

2026-09-30 CI artifact `10739301375`(build 534)를 내려받아 dwarfdump로 확인했다. Runner UUID는 `B79C23DA-53DF-34DB-A7F6-637536AEA0F9`, App.framework는 `B483D593-F921-DD13-113A-08D12343A5FB`, Flutter.framework는 `4C4C44E9-5555-3144-A1E6-9AC3C80B5823`였고 요청 UUID와 일치하지 않았다. **이 파일로 누락 심볼이 복구됐다고 판단하거나 다른 빌드 심볼을 대신 올리지 않았다.** 해당 UUID의 원본 archive가 추가로 필요하다. 과거에 수집되지 않은 웹 오류도 소급 복구할 수 없다.

기존 TestFlight CI의 dSYM 보관·upload-symbols 단계를 유지한다. 후속 빌드는 실제 archive UUID와 업로드 결과를 확인하고 콘솔의 처리/스택 해석까지 대조해야 최종 수신 검증이다.

## 현장 검증 순서

1. 테스트용 워크아웃으로 웹과 Android를 연결한다. 같은 시점의 pause/seek를 반복해 한 명령만 승인되고 나머지는 최신 상태로 복구되는지 확인한다.
2. 네트워크를 끊고 명령을 시도한 뒤 오류 상세를 복사한다. 복구 후 지연된 명령이 현재 수업을 되돌리지 않는지 확인한다.
3. 웹에서 큐에 남은 오류가 재연결/재실행 후 같은 eventId로 로그에 도착하는지 확인한다. 테스트 오류는 실제 고객 장애와 별도로 기록한다.
4. Android/iOS에서 처리된 Firebase 오류를 발생시키고 앱 재실행을 포함해 Crashlytics 수신을 확인한다. SDK 함수의 반환만으로 성공 처리하지 않는다.
5. TV 홈/다른 앱/대기 전환 후 운동·휴식 경계가 지나도 소리가 없는지 듣고, 복귀 시 현재 세션으로 한 번만 재생되는지 확인한다.
6. 빌드, 플랫폼, 발생/수신 시각, eventId, 콘솔 링크, 양쪽 연결/해제 지연 시간을 Linear에 남긴다.
