# 준비 속도·로딩 UX 개발 인계 — 2026-11-14

## 범위와 상태

- 구현 브랜치: `hyroxseouldev/preparation-speed-ux`
- clean Orca worktree: `/Users/sunmkim/orca/workspaces/cloudboardapp/preparation-speed-ux`
- 기준 develop: `1f9cb6b49898e63de2dc30680252d159036fedac` (구현 후 fetch로 동일함 확인)
- 실제 최종 코드 검사 커밋: `7c194a0a2456989eb89f897c5de02742af035bc7`
- PR 인계 head는 PR 본문의 `검증한 커밋:`으로 기록한다. 코드 커밋 이후 Flutter 실행 코드 변경은 없다. 문서·검증 로그·fixture 캡처와 후속 표시 버전/소식 후보 메타데이터 변경을 포함하며, 버전 일치 검사는 아래 후속 기록의 커밋에서 별도 수행했다.
- 원본 기획: `/Users/sunmkim/Dev2026/CloudBoard/report/output/preparation-performance-2026-11-14/astra-analysis.json`의 `latency_plan`.
- 구현·관련 검증 완료. develop/main 병합·배포 미실행. 원래 dirty develop checkout, 타이모, CI 설정, 서버, TV protocol, 캐시/압축/전송 정책은 수정하지 않았다. 최초 UX 검증의 표시 버전은 `2.1.5+9`였으며, 이후 사용자 지시로 `2.1.6+10` 기점 변경을 추가했다(아래 후속 기록).

## 의존성 확인과 동작

명령 데이터는 DB에서 받은 `Workout`, 유효 설정, `buildPlayerSteps`, `PlaybackSessionModel.fromWorkout`으로 만든다. 미리보기 image provider의 decode 결과·이미지 크기·canvas 측정값은 start payload, slide 선택, timer 초기화의 입력이 아니다. 기존 player의 rolling image warmup도 제어 실패로 전파하지 않는다. `functions/src/class-admission.js`의 `validReceipts`는 대상 TV receipt를 검사하며 컨트롤러 preview decode 완료를 요구하지 않는다. 서버 계약을 변경할 필요가 없다.

| 상태 | 시작 조건 / 표시 |
| --- | --- |
| 비어 있지 않은 TV 대상 | 기존 readiness, 현재 승인, 대상 일치, 준비 지원 TV의 현재 receipt와 구버전 연결·timing 호환성 유지. preview loading/decode/transport 오류는 필수 조건에서 제외 |
| 대상 0개 | controller 시작 이미지·카운트다운 이미지가 필수. 빈 집합의 `every`만으로 원격 준비 완료가 되지 않음 |
| 기존 명시적 단독 경로 | 등록된 기기를 모두 제외했을 때의 `localOnly` route 유지. 기기 자체가 없는 경우의 기존 empty-target server-session 경로도 유지하여 서버 권한/active-slot 검사와 구버전 broadcast 계약을 바꾸지 않음. 두 경우 모두 이미지 gate는 필수 |
| TV pending/failed/expired/offline/update required | 기존 차단 유지. 준비 지원 TV만 완료 n/m에 포함. 준비 미지원 기기는 별도 수와 행으로 표시 |
| 권한·한도·admission·lease 거절 | 공통 오류로 차단. `ImageUsageFailure`는 transport 실패인 `service_unavailable`만 preview 전용으로 처리하며 나머지는 보수적으로 차단. Firebase permission/unauthenticated도 차단 |
| preview 재시도 | 독립 retry 값과 future만 갱신. TV prepare, ID/revision, 선택 대상, start를 호출하지 않음. 현재 승인 경계 안에서 기존 managed provider/lease 사용 |
| 계정/수업/설정/대상/모드/승인 변경 | source identity와 전체 fingerprint에 묶인 preview 작업 폐기, `useFuture(preserveState: false)`로 과거 성공 제거. 계정 scope 실패는 provider 경계에서 안전한 오류로 매핑. 늦은 callback은 새 상태나 active session에 반영하지 않음 |

최초 TV 목록 수신·자동 선택 중에는 빈 대상 prepare를 먼저 보내지 않는다. 실제 대상 준비와 미리보기는 승인 후 계속 병렬이며, 미리보기는 TV 상태 아래 보조 영역에 표시한다. 수업 자료 조회, 최신 설정·이용 상태, 실제 TV 준비, 최종 설정/TV 검증, 서버 시작 확인, **서버 승인 후 TV ACK**를 구분한다. ACK는 기존 수동 명령을 막지 않는 관측이며 재전송을 유발하지 않는다.

현재 단계가 5초 이상 지속될 때만 해당 단계의 지연 안내를 표시한다. 진행률·완료 예상 시각·프로토콜에 없는 TV image n/m을 만들지 않는다. 준비/복구 상태는 text+icon과 semantic live region을 사용하고 reduced motion에서는 정적 아이콘을 쓴다. 초기 연결·foreground 복구는 실제 repository handshake와 fresh subscription 확인으로 구분하고, TV 연결 복구 팝업은 서버 접수/TV 수신/복구 상태를 그대로 사용한다.

## 속도 근거와 제한

컨트롤러와 TV는 기존에도 병렬이었다. 같은 승인 이후 C=컨트롤러 이미지, V=TV 필수 준비, S=나머지 필수 검사라면 기존 `max(C,V,S)`에서 원격 필수 대기는 `max(V,S)`가 된다. preview가 마지막 대기일 때만 시작 가능 시각이 빨라진다.

- widget fake 완료 milestone C=8초/V=3초: TV 완료 후 이미지가 pending이어도 시작 가능, 제거 가능한 필수 대기 5초.
- C=3초/V=8초: TV 완료까지 차단, 제거되는 대기 0초.
- `verifyStart` request·receipts 독립 조회를 `Future.wait`로 병렬화했다. delayed fake 600ms/400ms에서 두 읽기가 함께 시작하고 600ms 이후 검증이 끝남을 확인했다. 이전 직렬 모델은 1000ms다. 서버 시간은 두 응답 이후 읽으며 동일 ID/revision/hash/targets, 만료·연결 freshness 검사는 그대로 유지한다.

위 수치는 **설정한 fake 지연의 비교**이며 현장 네트워크 실측/p95가 아니다. 공유 네트워크 경합, 이미지 다운로드량, TV 자체 준비 시간 감소를 주장하지 않는다. 캡처와 테스트는 운영 이미지를 다운로드하지 않았다.

복구 결과 재사용은 적용하지 않았다. 현재 `recover`가 `void`를 반환하고 data source의 generation·verified 상태를 controller의 fresh subscription 결과와 묶어 전달하는 계약이 없다. 불명확한 재사용 대신 기존 single-flight, generation 무효화와 fresh 확인을 유지한다. 최종 fresh settings read도 유지한다.

## 검증 기록

환경: macOS 로컬, `/Users/sunmkim/fvm/versions/3.47.8/bin/flutter`. `flutter pub get --enforce-lockfile` 성공, pubspec/lockfile 변경 없음. 실제 앱 빌드: 미실행. 관련 서버 리비전/외부 서비스 연결: 없음(mock); 개발·운영 Firebase 및 스토어 미접속.

### 최종 코드 커밋에서 실행

실제 검사 SHA: `7c194a0a2456989eb89f897c5de02742af035bc7`.

```sh
git diff 1f9cb6b HEAD --name-only -- '*.dart' | xargs /Users/sunmkim/fvm/versions/3.47.8/bin/flutter analyze --no-pub
/Users/sunmkim/fvm/versions/3.47.8/bin/flutter test --no-pub --dart-define=STA190_EVIDENCE=/tmp/preparation-speed-ux-evidence test/workout_preflight_dialog_test.dart test/playback_start_lifecycle_test.dart test/active_class_shell_test.dart
```

- analyze: 변경 Dart 16개 파일, **No issues found**, exit 0.
- focused widget/controller/mock: **47 tests passed**, exit 0.
- 증거: [analyze](preparation-speed-ux-evidence/code-commit-analyze.txt), [47 tests](preparation-speed-ux-evidence/code-commit-tests.txt).
- 확인: preview slow/error+TV ready 시작; TV pending/failure gate; solo 이미지 gate; preview retry 요청 불변; 오래된 account/mode/target callback; 권한/한도/lease 거절; 실제 generated start의 single-flight, 최종 설정 변경 검사, account 취소; 시작 후 늦은 preview 실패가 active session을 중단/재시작하지 않음; server 승인/ACK 단계 구분; shell 최소화·복구·확장 연속성.

### 먼저 수행한 관련 검증 재사용

실행 당시 HEAD는 기준 `1f9cb6b49898e63de2dc30680252d159036fedac`이고 구현 중인 dirty worktree에서 검사했다. 이를 기준 커밋 자체의 통과로 표시하지 않는다. 해당 검사 이후 변경한 preflight/shell 경계는 위 최종 코드 커밋에서 다시 검사했으며, 아래의 읽기 병렬화·기존 image usage·복구/commit·display continuity 구현은 변경하지 않았다.

```sh
/Users/sunmkim/fvm/versions/3.47.8/bin/flutter test --no-pub test/workout_preflight_dialog_test.dart test/display_preparation_test.dart test/playback_start_lifecycle_test.dart test/playback_recovery_test.dart test/playback_recovery_view_test.dart test/image_usage_test.dart
/Users/sunmkim/fvm/versions/3.47.8/bin/flutter test --no-pub --dart-define=STA190_EVIDENCE=/tmp/preparation-speed-ux-evidence test/workout_preflight_dialog_test.dart test/display_recovery_ui_test.dart test/display_playback_continuity_test.dart test/playback_start_commit_test.dart
```

각각 **97 tests passed**, **65 tests passed**, exit 0. [97개 로그](preparation-speed-ux-evidence/focused-working-tree.txt), [65개 로그](preparation-speed-ux-evidence/compatibility-working-tree.txt). 배치 간 중복 테스트가 있으므로 합산한 고유 테스트 수로 보고하지 않는다. 기존 TV capability/receipt/서버시간, auth/lease, unknown-start reconciliation, 복구 generation, TV 계속 재생, 연결 복구 팝업의 좁은 화면·확대 글자를 포함한다.

구현 중 실패는 모두 해결했다. 변경된 단계 문구의 기대값 갱신, 오류 상태의 불필요한 spinner 제거, 초기 대상 선택 전 중복 preview 방지, fixture container 정리, 계정 provider 오류의 비동기 통지 경계 수정, 변경 범위 lint 수정 후 관련 검사를 재실행했다. 테스트 삭제/skip/조건 약화는 하지 않았다.

### 로컬 시각 증거

기존 `test/support/ui_layout_evidence.dart`의 선택적 캡처 도구와 번들 폰트를 재사용했다. 이 도구의 기존 환경 변수 이름이 `STA190_EVIDENCE`이며 이번 작업이 STA-190이라는 의미는 아니다. **실제 앱·실기기/E2E 증거가 아닌 local widget fixture**다. 600×1300 및 320×568, text scale 1.3에서 overflow 없이 시작·재시도 접근을 확인했다.

- [원격 preview 지연 — 시작 가능](preparation-speed-ux-evidence/remote-preview-slow.png)
- [원격 preview 오류 — 시작 가능](preparation-speed-ux-evidence/remote-preview-error.png)
- [320px 확대 글자 — 재시도와 시작](preparation-speed-ux-evidence/remote-narrow-scaled.png)

## 미확인·통합 인계

- 실기기/실제 앱+개발 callable/실제 TV 혼합 버전 실행: **미확인**. 실제 Firebase 저장·재조회 성공을 주장하지 않는다. 저장 schema/callable/commit 로직은 변경하지 않았다.
- 실제 모바일·웹 렌더링/현장 p95 및 VoiceOver/TalkBack/TV remote 실기기 탐색: **미확인**. widget semantics/reduced-motion/좁은 화면만 검증.
- 서버/TV protocol 배포: **불필요**. 적용에는 컨트롤러 앱 또는 웹 업데이트가 필요하지만 이번 작업에서 빌드·업로드·배포하지 않았다.
- 전체 CI/전체 Firebase 계약 검사/전 플랫폼 빌드/자동 앱 E2E: **미실행**. CI 정책 변경 없음, 통과로 표시하지 않음.
- preview 작업 무효화는 화면 결과와 후속 요청의 취소이며 이미 전송 중인 HTTP abort를 보장하지 않는다. 캐시/중복 GET/이미지 압축/한도 변경은 범위 밖.
- 기능 브랜치 → develop PR 인계만 수행하며 병합·승격·릴리즈는 통합 담당자 소유. 충돌이나 관련 코드·환경 변경이 있을 때만 영향을 받는 검사를 다시 수행한다.


## 후속 버전 기점 변경 — 2026-11-14

총괄의 추가 지시에 따라 `2.1.5+9` 유지 지시를 `2.1.6+10`으로 변경했다. 전체 2.1.6 기점·통합 커밋은 준비 UX와 별도 CI/CD 담당 결과를 확인한 뒤 총괄이 남긴다.

- 버전 변경·실제 검사 커밋: `a700ca70fa3740f3d19c340500486d76c4979f49`.
- 표시 버전의 단일 소스는 `pubspec.yaml`이다. Android는 `flutter.versionName/versionCode`, iOS/macOS는 `FLUTTER_BUILD_NAME/NUMBER`, Windows는 Flutter의 생성 버전 값을 사용하므로 네이티브 파일의 별도 숫자는 변경하지 않았다.
- `release-notes/README.md`의 기존 일치 규칙에 따라 `release-notes/current.json`의 후보 버전을 `2.1.6`, 새 ID를 `2026-11-14-2-1-6-candidate`로 동기화했다. 본문은 기존 미게시 후보 그대로이며 **최종 2.1.6 배포 소식 확정/게시가 아니다**. 총괄이 통합 후보에서 플랫폼별 직전 실제 배포 SHA와 diff를 검토해 준비 UX 등을 포함한 최종 문구를 확정해야 한다.
- `image-usage-2.1.5-v1`은 표시 버전이 아닌 서버/클라이언트 정책 계약 식별자이므로 변경하지 않았다. 기존 사용량 구현 기록도 당시 버전의 역사적 증거로 유지한다.
- 로컬 소스 build suffix `+10`은 실제 Play/TestFlight 예약·업로드 번호가 아니다. main에서 버전을 최종 확정하면 develop 역동기화가 필요하다는 기존 규칙을 유지한다.
- `node --test tool/update-news/news.test.mjs`: **6 passed, 0 failed, 0 skipped**, exit 0. 후보 소식과 실제 pubspec 버전 일치·형식 및 미배포 소식 제외 규칙 확인.
- `node tool/release/play_version_code.mjs --version-name`: **2.1.6**, exit 0. 읽기 전용 버전 추출이며 번호 예약·네트워크·태그 생성 없음.
- `git diff --check`: 통과. Flutter 실행 코드·의존성·lockfile에 변경이 없어 앞선 관련 검증을 재사용했으며 전체 회귀/빌드는 재실행하지 않았다.
- `.github/workflows`, `tool/release`, Firebase 문서는 읽기만 했고 수정하지 않았다. 별도 담당과 경로 충돌 없음. 태그·배포·소식 게시·스토어 빌드/업로드 미실행.
