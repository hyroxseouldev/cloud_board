# STA-155 · STA-156 — 사용량 안내와 대기 화면 브랜딩

## 구현과 적용 경계

- 홈/수업 목록, 신규 생성·복제, 예시 가져오기, 라이브러리에 저장 사용량을 표시한다. `users/{uid}/planUsage/current` 서버 집계를 읽고, 문서가 없는 기존 계정만 `getPlanUsage`로 원본 컬렉션의 집계를 부트스트랩한다. 목록 전체 다운로드로 개수를 추정하지 않는다.
- 짧은 홈 화면과 큰 시스템 글자에서는 별도 안내 행 대신 폴더 도구 행의 사용량 버튼을 제공한다. 현재 수/한도를 접근성 이름과 툴팁에 포함하고, 누르면 같은 계정 scope의 전체 사용량·재확인·한도 안내를 스크롤 가능한 대화상자에서 연다. 목록과 초기 로딩 표시가 처음부터 보이도록 높이를 추가하지 않는다.
- `저장 수업`은 현재 보관한 전체 수업 수이며 매주 초기화되지 않는다. `재사용 저장 슬라이드`는 수업 내부 슬라이드와 별도 자원이다. Free 수업 7/슬라이드 3, Plus 수업 무제한/슬라이드 30, Premium 모두 무제한을 서버 정책으로 표시한다.
- 서버 확인된 정책·집계가 한도에 도달했을 때만 새 추가를 사전 안내한다. 캐시·누락·알 수 없는 권한을 Free 또는 0으로 가정하지 않는다. 최종 원자적 저장 판정은 서버이다. 기존 자료 편집·삭제·재생은 계속 가능하다.
- 한도 응답(`resource-exhausted`, `reason: plan-limit`)은 일반 저장/통신 실패와 구분한다. 관리·Plus 화면은 push하므로 뒤로 가기/결제 취소 후 편집 화면이 유지된다. 새 수업 저장 전에는 전체 초안을 로컬 복구 저장소에 먼저 기록한다. 저장 실패한 재사용 슬라이드의 이름과 내용도 controller의 `pendingDraft`로 유지한다. 복제 원본이나 선택된 가져오기 예시는 변경하지 않는다.
- 예시 가져오기는 기존에 가져온 수업을 다시 여는 멱등 경로가 있으므로 무조건 사전 차단하지 않는다. 사용량을 먼저 보여주고 서버가 신규 여부와 한도를 판정한다.

## 브랜드 원본과 TV 적용 데이터

| 경로 | 역할 | 읽기 / 쓰기 |
| --- | --- | --- |
| RTDB `users/{uid}/operations/brandConfig` | 사용자 지정 원본 | 소유자 읽기 / callable만 쓰기 |
| RTDB `users/{uid}/operations/brand` | 서버가 권한에 맞게 적용한 TV payload | 소유자·연결된 TV 읽기 / v2에서 서버만 쓰기 |
| RTDB `users/{uid}/operations/brandProjection` | 적용 정책과 revision | 소유자·연결된 TV 읽기 / 서버만 쓰기 |
| Storage `users/{uid}/brand/*` | 원본 이미지 | 소유자 읽기 / 유효한 custom 권한만 업로드·교체·삭제 |

첫 v2 적용 시 기존 `brand`를 `brandConfig`로 복사한 다음 적용 payload를 만든다. Free는 기본 오트·세이지 화면/제품 로고를 고정하고 사용자 배경·문구·센터 로고 적용만 중단한다. Plus/Premium은 보관된 원본과 제품 로고 숨김 설정을 복원한다. 다운그레이드 시 파일과 원본을 삭제하지 않는다. 원본·적용 payload의 로컬 캐시는 서로 분리하고 계정별 키를 사용한다.

설정 화면은 원본을 편집하고, TV/대기 미리보기는 서버의 적용 payload를 사용한다. 아직 v1인 계정은 `brandConfig`가 생길 때까지 기존 `brand`를 실시간 구독한다. v2 callable은 권한 누락·만료를 거절하며, v1 callable도 유효한 명시 권한이 있어야 한다. 이미 v2였던 계정은 projection 마커 때문에 v1으로 후퇴해 직접 쓰기 경로를 다시 열 수 없다.

`DisplayModeScreen`의 진행 중 플레이어는 브랜드와 독립적이다. 사용자 브랜드의 black-screen 시간도 `!isActive`일 때만 적용한다. 새 브랜드는 다음 대기 경계에서 표시되며 진행 중 결제 팝업은 없다. 권한 조회 실패/만료 시 서버는 마지막 확인된 적용 payload를 보존한다.

## 계측 계약

기존 `OperationTelemetry`/`recordOperationTelemetry`를 재사용한다. 상품 데이터, 수업 이름·내용, 이미지 주소, 이메일은 전송하지 않는다.

| action | 발생 시점 | 종료 의미 |
| --- | --- | --- |
| `plan.workouts.usage`, `plan.savedSlides.usage` | 정책·집계가 준비된 사용량 위젯 진입 시 1회 | success = 노출 |
| `plan.{resource}.limit` | 한도 안내 열기 | success = 관리/Plus 선택, cancelled = 계속 편집/닫기 |
| `plan.{resource}.manage`, `plan.{resource}.upgrade` | 안내에서 실제 경로 선택 | success = 해당 화면 진입 요청 |
| `workout.save` | 신규/편집/복제 서버 저장 | 서버 완료 후 success, 거절/통신 실패는 failure |
| `workout.import` | 예시 가져오기 | 서버 완료 후 success. 기존 자료 재열기도 포함하므로 **신규 증가 수**로 집계하지 않음 |
| `slides.save` | 저장 슬라이드 변경 요청 | 서버 완료 후 success; 기존 수정·삭제도 포함 |
| `plan.upgrade.purchase` | 실제 상품 구매 요청 | 서버 검증 성공/취소/실패. 복원·중복 전달은 구매 전환으로 중복 집계하지 않음 |

각 operationId에는 attempt와 terminal 최대 1개만 허용한다. 클라이언트 queue 재전송, 서버 재수신, 분석 집계 모두 기존 중복 제거 계약을 따른다. 사용량 위젯의 provider rebuild·count 변경은 노출을 다시 보내지 않는다. 서로 다른 action의 사용자별 추적 식별자를 새로 수집하지 않으므로 이 이벤트로 개인별 전환 여정을 재구성한다고 주장하지 않는다. 집계는 각 단계 operationKey의 고유 수와 시간대별 추이로 본다. 결제 성공과 최종 저장 성공은 별도 지표이다.

## 검증

- 최종 작은 화면 보완: `home_workout_loading_test`, `main_navigation_test`, `plan_usage_branding_test` 및 캡처 **39/39 통과**. 320×568/글자 2배의 로딩 행과 첫 수업 가시성, 844×390 가로 첫 수업, 320×390/글자 2배의 안내 스크롤·닫기·Plus 접근, route-local ProviderScope 보존을 확인했다. 로그 `/tmp/cloudboard-plan-compact-tests.log`.
- `test/plan_usage_branding_test.dart`: 권한 누락/캐시 판단, Free·Plus·Premium 한도 표시, 서버 확인 6→7 차단·Plus 전환, 실제 오류 구분, 요금 화면 취소 후 입력 유지, 한도/노출 계측 중복 제거, 원본/적용 캐시 및 계정 격리, 구버전 realtime fallback 구독 해제, Free 제품 로고/Plus 숨김.
- `test/display_mode_flow_test.dart`: 진행 중 downgrade와 blackout 설정 갱신에도 같은 player element를 유지하고, 수업 종료 후 Free 적용 화면으로 전환. 연결 복귀/리프레시/TV 상태 기존 회귀 포함.
- `test/slide_templates_test.dart`: 실패한 이름·이미지·내용 초안 및 기존 자료 유지.
- 기존 복구/라이브러리/예시 가져오기/운영 화면 등 10파일 + 캡처 실행에서 **61/61 통과**. 최종 작은 화면·내비게이션·사용량·캡처 회귀 **39/39**, 앱 전체 테스트 **954/954**, 정적 검사 통과. 서버 통합 Node **162/162**, Firebase 계약 emulator **25/25** 통과.
- `functions/test/standby-branding.test.js`: 7개 테스트로 Free sanitization, 원본 보존/재업그레이드, v1 보존, stale revision, unknown/expired, callable 우회 차단 검증.
- `functions/test/standby-branding-emulator.mjs`: 직접 RTDB 쓰기 차단, owner/TV 분리, Free Storage 쓰기 거절, Plus/Premium 허용, 다운그레이드 보관/읽기, 만료·revoked 거절, 유효 past_due 유예 허용. 다른 Firebase 계약과 root 통합 실행.
- 쿼터의 동시 쓰기·삭제 후 재시도·다운그레이드 초과 기존 자료 수정은 [서버 계약](../../plan-entitlements-v2-server.md)의 emulator suite가 담당한다.

## 화면 증빙

생산 위젯을 로컬 공급 데이터로 캡처한다. 별도 모형을 그린 시안이 아니며 실계정/결제/원격 TV 요청은 실행하지 않는다. 명령: `flutter test --no-pub tool/sta155_156_capture_test.dart`.

- [Free 6/7 홈](free-home-6-of-7.png): 논리 390×844, DPR 2.
- [Free 7/7 · 작은 화면·글자 2배](free-home-7-of-7-text2x.png): 논리 320×844, DPR 2. 폴더 옆 사용량 버튼으로 [전체 한도 안내](free-home-7-of-7-text2x-usage.png)를 열고 나머지 목록은 스크롤로 접근한다.
- [Free 설정 잠금·기본 미리보기](free-brand-settings.png), [Plus 설정·사용자 원본 미리보기](plus-brand-settings.png).
- [Free TV 1920×1080](free-tv-1920.png), [Plus TV 1920×1080](plus-tv-1920.png). 같은 원본을 두 권한에 적용한 비교이며 과거 커밋의 baseline 캡처라고 주장하지 않는다.

## 배포와 수동 검수의 남은 경계

실기기, 실제 TV 거리 가독성, 프로덕션 결제·배포는 실행하지 않았다. 원격 배포 승인 없이 로컬 구현/계약 검증만 수행했다. 실제 클라이언트 배포 후 앱/웹/TV를 함께 확인해야 한다.

v2 계정 활성화는 정책 rollout gate를 따른다. 기존 TV는 같은 `operations/brand` 경로의 Free 기본 데이터/센터 콘텐츠 제거를 읽을 수 있지만 새 제품 심볼 overlay(`showCloudBoardLogo`)를 모르는 버전은 완전한 표시 계약을 충족하지 못한다. 따라서 제품 로고 고정을 요구하는 v2 활성화 전 이 PR을 포함한 TV 버전을 배포하고 기존 앱 업데이트 게이트의 minimum/published build로 구버전 업데이트를 안내해야 한다. 임의 build 번호를 코드에 미리 고정하지 않았다.

오프라인 TV의 이미 보관된 화면을 서버에서 즉시 교체할 수는 없다. 연결 복귀 후 적용 payload를 동기화하고 다음 대기 진입에서 바뀌는지 실기기로 확인한다. 권한 조회 실패를 Free로 간주해 기존 화면을 강제로 지우지 않는다.
