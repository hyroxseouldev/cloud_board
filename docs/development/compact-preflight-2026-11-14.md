# 수업 준비 페이지 · 원격 자동 이미지 요청 제거

- 기준: fetch로 확인한 `origin/develop` **c6f2b5e8272c82163267d4d54cc313879c67de38**, 2.1.6+10.
- 작업: Orca child worktree `compact-preflight`, branch `hyroxseouldev/compact-preflight`. 원래 dirty 앱 checkout은 수정하지 않았다.
- 구현 커밋: `7ddabe983734b5778cd324af063b90a45d213ce5`(원격 이미지 정책), **`6218652fb43ce564a43923e8076272379e41dc9f`**(최종 페이지). 뒤의 문서·증거 커밋은 동작을 바꾸지 않는다. PR의 검증한 커밋은 인계 head로 별도 기록한다.
- 사용자의 추가 지시에 따라 최종 결과는 팝업이 아닌 **전용 준비 페이지**다. 소스 버전은 **2.1.7+11**, 업데이트 소식은 미게시 후보다. 새 의존성·서버·프로토콜·CI workflow 변경 없음.

## 동작과 유지한 조건

`showWorkoutPreflight`의 기존 호출자(수업 목록·편집기·첫 수업)가 이제 `MaterialPageRoute`를 push하고 같은 선택 결과를 pop으로 받는다. 기존 시작 continuation, auth/router, 편집기 이탈 guard는 교체하지 않았다. in-app route 이름은 `/workouts/<id>/prepare`; 별도 URL deep-link 계약을 추가한 것은 아니다. 뒤로가기·취소는 시작하지 않고 돌아가며, 페이지에서 시작을 두 번 반환하지 않도록 제출 guard를 둔다.

| 경계 | 최종 동작 |
| --- | --- |
| 원격 준비 | 승인 이후에도 `preflightImageLoader`를 호출하지 않음. 첫 2장·카운트다운·이미지 window를 만들지 않음. 준비 전용 미리보기 spinner/성공/retry 삭제 |
| 구성 카드 | DB의 이름·시간·순서만 표시. 이미지 Widget 없음. 준비 중에도 탐색 가능 |
| 명시적 이미지 보기 | 현재 계정·수업·대상 승인이 유효할 때만 활성. 눌렀을 때 선택한 한 슬라이드의 기존 `WorkoutSlidePreview`를 mount. `WorkoutImage → ManagedImageProvider → authenticatedManagedImageBytes → media`의 기존 인증/lease 경로 보존. 오류는 선택 미리보기 안에서 처리하며 TV 준비를 다시 보내거나 원격 start gate를 변경하지 않음 |
| 재생 컨트롤러 | 실제 target이 있는 원격 역할만 rolling precache와 카운트다운 배경 이미지를 차단. 미리보기는 기본 접힘; 명시 열기 전 PageView/이미지 Widget 자체가 없음. 시간·이전/다음·기존 슬라이드 선택 유지. 제한시간 없는 구성에는 이미지 없는 선택기를 보완 |
| 단독·대상 0대 | session ID만으로 원격으로 판단하지 않음. 서버 세션이라도 target 0대이면 단독 이미지 표시/준비 유지. 준비의 카운트다운+시작 이미지 성공이 필요하며 오류는 시작 차단 |
| TV/display | 전체 이미지·소리 준비, retention, 재시도, 표시/rolling window는 그대로 |
| 무효화 | 계정 source, 수업/설정 fingerprint, 대상, 모드, admission, request ID/revision/hash 변경 시 이전 결과/미리보기 선택 폐기. 오래된 solo 작업은 후속 prefetch를 발행하지 않음. 이미 시작된 HTTP의 abort는 기존 계약상 보장하지 않음 |

최신 설정·ownership·권한·한도·admission·lease·요청 매칭·freshness와 최종 서버 시작 검사는 유지했다. 미준비 TV는 제외하거나 재시도할 수 있고, legacy는 이미지 준비 완료 수에 포함하지 않는다. unknown commit reconciliation·기존 active 수업 연속성·enrollment·한도 숫자는 변경하지 않았다.

## UI와 실제 캡처

기존 Material/Oat Sage 테마의 아이콘·둥근 구성 카드·짧은 문구를 사용했다. 수업 요약, 필수 상태, 구성 카드, TV 선택, 고정 하단 CTA 순서다. 정상 연결 정보만 접으며 오류/권한/만료 사유는 기본 본문에 남긴다. 5초 안내는 현재 미완료 단계에만 표시한다. 가짜 진행률이나 새 animation timer는 없다.

- [이전 실제 Flutter 팝업](compact-preflight-evidence/before-popup.png): 기준 c6f2b5e의 widget 렌더.
- 최종 실제 Flutter web fixture: [준비 완료 390](compact-preflight-evidence/ready-390.png), [대기](compact-preflight-evidence/waiting-390.png), [실패](compact-preflight-evidence/error-390.png), [권한 거절](compact-preflight-evidence/permission-390.png), [단독](compact-preflight-evidence/solo-390.png).
- [320px·130%](compact-preflight-evidence/ready-320-130pct.png), [320px·200% 오류](compact-preflight-evidence/error-320-200pct.png): 본문은 스크롤되며 하단 CTA는 유지. 위젯 검사에서는 390px·200%도 확인.
- [원격 제어 기본](compact-preflight-evidence/controller-closed-390.png), [명시 열기](compact-preflight-evidence/controller-open-390.png), [원격 카운트다운](compact-preflight-evidence/remote-countdown-390.png), [준비 페이지 명시 이미지](compact-preflight-evidence/page-explicit-image-390.png).

최종 캡처는 HTML 목업이 아니라 `tool/fixtures/compact_preflight.dart`가 실제 페이지·플레이어를 import하여 Orca 내부 브라우저에서 실행한 결과다. Firebase 초기화·계정 로그인 없음. 사용자 검토용 localhost:8796 서버는 유지한다. 원격 플레이어 fixture에서 내장 브라우저의 기존 Wake Lock 권한 거절이 관측됐으며 이미지 GET/레이아웃 검증과 별개다; 이 작업에서 플랫폼 wakelock 정책을 바꾸지 않았다.

## 이미지 요청 증거

[측정 원본](compact-preflight-evidence/network.json). `127.0.0.1:8796`의 `fixture-image.png`를 실제 HTTP로 제공하고 서버가 본문 GET을 센다. 응답은 `no-store`, 페이지 이동마다 새 Flutter 앱이다. **실제 TV는 접속하지 않았고 TV receipt는 fake**다.

| 실제 로컬 HTTP 관측 | 이미지 GET 증가 |
| --- | ---: |
| 원격 준비 ready/waiting/error/permission, 320px 확대 상태 | 0 |
| 원격 재생 기본 접힘 / 원격 카운트다운 | 0 / 0 |
| 준비 페이지에서 이미지 보기 명시 클릭 | 1 |
| 재생 컨트롤러 미리보기 명시 클릭 | 2 (현재·인접 표시) |
| 단독 준비 | 3 (카운트다운 + 첫 2장) |

별도로 loader spy는 원격 대기·ready·실패·retry·승인 거절·계정 변경에서 0회다. 빈 Flutter ImageCache에서 실제 기본 preflight loader를 사용한 HTTP-client 진입 검사도 0회다. mock loader 0회와 로컬 HTTP 0건은 서로 다른 증거이며 **운영 Storage/게이트웨이·실물 TV의 네트워크 측정은 아니다**. DB 설정/메타데이터/승인 요청은 삭제하지 않았다.

## 검증과 재사용

SDK: `/Users/sunmkim/fvm/versions/3.47.8/bin/flutter`. `pub get --offline` 후 lockfile 변경 없음. 전체 앱/전 플랫폼 빌드·전체 CI는 실행하지 않았다.

| 검사 | 결과·실행 소스 |
| --- | --- |
| 변경된 Dart 13개 경로 `flutter analyze --no-pub ...` | [문제 0](compact-preflight-evidence/analyze.txt), 6218652에서 실행 |
| `flutter test --no-pub test/workout_preflight_dialog_test.dart` | [27 통과](compact-preflight-evidence/page-tests.txt). 7ddabe9 + 작업트리에서 실행, 최종 6218652의 제품 코드와 동일. 페이지 push/back, 준비 중 메타데이터, late callback, 선택, role, loader/HTTP 0, solo gate, 좁은 폭/확대 오류/CTA |
| 같은 파일 `--name 'remote access refusal\|page image preview'` | [6 통과](compact-preflight-evidence/access-tests.txt), 6218652. 이미지 버튼은 승인 거절 시 비활성; 선택 이미지 오류는 원격 start와 TV request 수에 영향 없음 |
| 페이지 전환 후 `test/workout_preflight_dialog_test.dart test/playback_start_lifecycle_test.dart` | [초기 실행](compact-preflight-evidence/page-and-start-tests-initial.txt): 46 통과/1 실패. 실패는 이전 설정오류 문구 기대값 하나였으며 수정 후 위 27개 모두 통과. 시작 수명 검사에는 실패 없음; 목록·편집기·첫 수업/중복 시작·권한·stale/expired 후보·계정 변경 결과 재사용 |
| `test/player_rebuild_performance_test.dart` | [3 통과](compact-preflight-evidence/player-tests.txt), c6f2b5e + 최종 7ddabe9 제품 코드 작업트리. target 0/원격 역할과 명시 이미지 열기, 기존 TV ticker 재빌드 유지. 이후 해당 코드 변경 없음 |
| 준비/시작 수명/제어/카운트다운 4개 파일 | [61 통과](compact-preflight-evidence/initial-role-tests.txt). 페이지 전환 전 결과 중 변경하지 않은 제어·카운트다운 검사를 재사용. 새 scope에서 미리보기 재접힘, 숨긴 PageView 미생성, countdown 이미지 Widget 미생성 |
| 준비/제어/업데이트 소식 3개 파일 | [43 통과](compact-preflight-evidence/controller-news-tests.txt). 페이지 전환 전 실행; 변경 없는 제어/버전 계약 결과만 재사용. 위 숫자는 중복 포함으로 합산하지 않음 |
| `node --test tool/update-news/news.test.mjs` | [6 통과](compact-preflight-evidence/news-tests.txt), 6218652. 2.1.7 후보 형식/앱 버전 일치 |
| `flutter build web --no-pub --target tool/fixtures/compact_preflight.dart --no-web-resources-cdn --no-wasm-dry-run` | [성공](compact-preflight-evidence/fixture-build.txt), 7ddabe9 + 최종 6218652 제품/fixture 소스 작업트리. 로컬 fixture 전용 빌드이며 운영 앱 배포 산출물 아님 |

`6218652` 이후 제품/테스트 변경 없이 증거 문서만 추가한다. SHA 변경만을 이유로 통과한 검사를 반복하지 않는다. 실패한 기대값을 숨기거나 테스트를 삭제/skip하지 않았고, 폐기된 자동 미리보기 요구 테스트는 0호출·solo·승인 차단 요구로 갱신했다.

재현: 위 fixture web 빌드 후 `cd build/web`에서 `python3 ../../tool/fixtures/compact_preflight_server.py`, `http://127.0.0.1:8796/?scene=ready` 열기. scene은 waiting/error/permission/solo/controller/countdown, scale은 1.3/2를 지원한다. `/metrics`는 이미지 요청 경로만 반환한다.

## 남은 범위

- 실제 개발 callable 저장/재조회·실물 TV·혼합 설치 버전 E2E: **미확인**. 저장/서버 계약 변경 없음. 시작 지연 절감률은 **미측정**.
- main 승격·태그·Firebase/Hosting·모바일 빌드/업로드·TestFlight·소식 게시: **미실행**. root 검토·병합 후 별도 담당자가 Dev TestFlight 진행 예정.
- release-notes/current.json은 기존 2.1.6 미게시 후보 내용을 유지하면서 이번 UX를 더한 2.1.7 후보다. 최종 공개 소식은 통합 담당자가 플랫폼별 실제 직전 배포 SHA와 후보 diff로 확정해야 한다. 소스 +11과 ASC allocator의 실제 업로드 빌드 번호는 별개다.
