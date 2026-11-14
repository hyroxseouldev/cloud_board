# 수업 준비: 전체 TV 사전 확인과 즉시 선택

> 2026-11-14 정정: 이 문서의 0대/빈 선택 Start 비활성 가정은 사용자 지시로 폐기됐다. 현재 동작은 [TV 0대 수업 시작 복구](zero-target-start-2026-11-14.md)를 따른다. 아래 내용과 검사 결과는 당시 구현 이력이다.

기준 `origin/develop` `9c7dc4360d2ffe657e0af1317381f9207dde0a9e`, 초기 버전 `2.2.0+12`에서 사용자 추가 지시에 따라 최종 후보 `2.2.1+13`으로 갱신했으며 실제 `shadcn_ui 0.59.0`과 기존 페이지 전용 테마를 유지했다. 원래 dirty checkout과 `normalize2dirty` 보고서는 수정하지 않았다. 이 문서는 기존 선택 적용/명시 solo/이미지 보기 동작을 설명한 이전 준비 화면 문서를 이번 화면에 한해 대체한다.

## 구현

- `showWorkoutPreflight`만 root Navigator에 push한다. 실제 홈 목록과 편집/온보딩 caller의 결과·뒤로·취소(null) 계약은 그대로다. 전역 router/하단 dock/theme을 수정하지 않았다.
- 상단 Back 하나, SafeArea 안의 고정 Start 하나를 둔다. 본문은 별도 Expanded scroll 영역이라 버튼 높이·안전 영역을 침범하지 않으며 수업 구성이 본문의 마지막이다.
- 공유 기기 health 구독의 첫 성공 결과에서 paired + auto인 소유 TV와 프로토콜 정보를 고정한다. 기존 enrollment 확인 직후 알려진 프로토콜 비호환 TV를 제외한 준비 가능 집합 C를 한 번 prepare한다(하단 경계 보정 참고). 호환되는 offline TV도 C에 포함하며 최근 응답한 호환 TV를 기본 선택한다. 이후 checkbox/전체 선택/전체 해제는 S만 즉시 바꾸며 prepare/admission/서버 쓰기·invalidate·debounce 호출은 0이다. 재시도 버튼만 C 전체를 명시적으로 재확인한다.
- `선택 적용`, TV/이 기기 모드 선택, 수업 구성 이미지 보기/닫기와 준비 화면 이미지 loader를 제거했다. 텍스트 구성 카드와 기존 상태 카드는 유지한다. 0 TV/빈 선택은 Start 비활성, `재생할 TV를 선택해 주세요.` 안내이며 solo나 broadcast로 전환하지 않는다.
- Start는 S만 반환한다. 실제 caller의 기존 action은 최신 preferences, 소유 기기, 연결/프로토콜/건강 상태, 준비 request/session/revision/hash/만료와 선택 TV receipt를 최종 검증하고 정상 session/권한/할당 경로로 진행한다. 준비되지 않은 미선택 TV는 S를 차단하지 않는다. 중복 Start와 계정 변경 취소는 기존 guard를 유지한다.
- TV 실제 이미지·소리 준비, 진행 중 수업, player 이미지 revision/cache/flicker 로직은 수정하지 않았다.

## 시작 계약

`DisplayPreparationProof.preparedTargetDeviceIds`는 불변 C다. `clientFingerprint`는 계속 `preparationFingerprint(effectiveWorkout,C)`이며 S의 fingerprint로 가장하지 않는다. 새로운 proof는 nonempty unique S⊆C, 현재 request 대상=C, exact session/revision/manifest, 최신 workout binding과 S의 receipt를 확인한다. cohort 없는 기존 proof는 기존 exact-target 검증을 유지한다.

Enrolled admission은 서버 담당의 별도 변경이 필요하다. 응답 `supportsTargetSubset:true`가 있을 때 `action:commitSelected`에 top-level `selectedTargetDeviceIds:S`를 보내며 기존 admissionId/sessionId/epoch/manifestHash/start와 안정된 requestId를 유지한다. 서버에 선택/idempotency/권한/할당/현재 사용량/active-slot 검증이 남는다. 응답 session 대상도 S와 정확히 일치해야 한다. capability 없는 구형 서버는 S=C일 때만 기존 commit을 쓰며 subset은 fail closed다. 새 action 실패 후 old commit으로 fallback하지 않는다.

서버 계약 문서: [PR #188](https://github.com/hyroxseouldev/cloud_board/pull/188)의 `docs/development/prechecked-display-subset-2026-11-14.md`. `cloudboardClassAdmission`, `retryImageUsageOutbox`, `cloudboardMediaLease`, `cloudboardMedia`의 호환되는 개발 배포와 실제 앱 확인은 root 통합 범위다. 전체 C를 준비하므로 기존 보수적 C+controller 예약·quota를 유지하며, 일부 S만 시작해도 전체 사전 확인에 필요한 quota는 필요하다.

## 검증과 증거

SDK `/Users/sunmkim/fvm/versions/3.47.8/bin/flutter`. 앱 구현 검사 SHA `1baebea69bc559da3fbdff84d78eaa2bdd5edb26`.

```sh
flutter test --no-pub test/workout_preflight_dialog_test.dart test/display_preparation_test.dart test/preparation_subset_commit_test.dart test/image_usage_test.dart test/playback_start_commit_test.dart test/playback_start_lifecycle_test.dart
```

**79개 통과**: [로그](precheck-ux-evidence/tests.log). 유닛·위젯(fake repository/transport), 실제 외부 서비스 연결 없음. 화면 선택 4회 + 전체 해제/선택 3회 후 prepare=1, admission/enrollment check=1, 기기 구독=1이다. 실제 목록 caller→준비→정상 start action을 통해 정확한 subset ID를 확인했고 editor/list 전체 시작·중복 제출·권한/계정/만료/설정 변경과 구형 서버 fail-closed도 확인했다. 준비 ready/offline/empty/error 및 구성 스크롤은 cold HTTP client 생성 0회다.

실제 앱 router/list caller의 위젯 검사에서 390×844와 320×568/2배 글자/하단 safe area 34px를 사용했다. 준비 동안만 dock이 offstage이며 Back 후 기존 목록 Element·검색어·scroll offset·dock을 복원한다. 구성 끝까지 스크롤해도 CTA 위치가 같고 안전 영역과 겹치지 않는다.

기존 제거된 UI인 solo/apply/optional preview 양성 테스트는 새 사용자 동작인 빈 선택 차단·로컬 즉시 선택·text-only 구성 테스트로 대체했다. 이를 통과시키려고 서버/기존 proof 계약을 삭제하지 않았다. 기존 media loader/renderer 검사는 `image_usage_test.dart`, 준비 media/receipt 검사는 `display_preparation_test.dart`, 최종 시작 수명 검사는 `playback_start_lifecycle_test.dart`에서 유지했다.

대상 파일 analyze 문제 없음: [로그](precheck-ux-evidence/analyze.log). 전체 CI·전 플랫폼 빌드·실기기·TestFlight·배포는 미실행이다. player/home의 무관한 전체 검사는 반복하지 않았다. `source-evidence/docs/development/explicit-mode-evidence/after/row-revision-test.log`의 player row 이미지 유지 통과 기록은 해당 player 소스가 무변경이므로 문맥 증거로 재사용하며 이번 새 실행으로 세지 않는다.

## 로컬 시각 확인과 남은 통합

실제 Flutter 웹 fixture `tool/fixtures/prechecked_preparation.dart`는 production router와 실제 WorkoutListScreen의 재생 버튼을 사용한다. localhost의 fake 데이터만 사용하며 Firebase 초기화·로그인·외부 API 호출이 없다. query `scene=ready|mixed|offline|empty|error|request-error`, `scale=2`를 지원한다. 오래 열린 리뷰 탭에서도 가상 TV heartbeat와 준비 시간 기준이 맞도록 fixture server/health clock만 고정했다.

리뷰 URL `http://127.0.0.1:8798/`. 홈의 첫 재생 버튼을 누르면 준비 화면이 열린다. before는 기준 SHA에서 빌드한 실제 Flutter compact fixture 390 캡처이며 after는 실제 라우터 fixture다. 두 fixture의 수업 콘텐츠는 다르므로 화면 구조/고정 CTA/내비게이션 경계 비교용이다.

실제 앱→개발 callable→저장→재조회는 **미실행/미확인**이며 mock 성공을 실제 서버 저장 성공으로 주장하지 않는다. 서버 리비전은 배포되지 않았고 새 enrolled subset 경로는 별도 서버 PR과 개발 배포가 선행되어야 한다. 개발 환경에서 정확한 S의 session·소유/할당·미선택 제외와 실제 TV media 준비를 root가 확인해야 한다. PR 제출과 구현 완료는 이 통합 검증·배포 완료를 의미하지 않는다.

## 2.2.1 후보 메타데이터

사용자 추가 지시로 pubspec을 `2.2.1+13`으로 변경하고 `release-notes/current.json`을 새 candidate ID의 미게시 소식으로 갱신했다. 13은 소스 빌드 메타데이터이며 실제 ASC 번호는 업로드 담당이 별도 조회·할당한다. 이전 실제 iOS Dev 배포는 `9c7dc4360d2ffe657e0af1317381f9207dde0a9e`, ASC `2.2.0(3)`, 성공 receipt `1794654631824172`다. root 제공 근거는 `/Users/sunmkim/CloudBoard-release-artifacts/2.2.0-development-9c7dc436/final-report.json`, `successful-attempt-1794654631824172.json`, `remote-receipt-readback.json`이다. 소식은 이 기준 이후의 준비 UX/선택 시작과 동일 릴리스의 별도 홈 리디자인만 설명하며 기존 2.2.0 누적 변경을 신규 기능으로 반복하지 않는다. 최종 통합에 홈 PR이 포함되는지 root가 확인해야 한다. Android/web 직전 실제 배포 SHA는 미확인이며 운영 소식 게시 전 플랫폼별 diff 재검토는 root 인계 사항이다. 개발 TestFlight 후보를 운영 소식으로 게시하지 않았다.

메타데이터 검증: `node --test tool/update-news/news.test.mjs` 6개, `flutter test --no-pub test/update_news_test.dart` 10개 통과. 문구 최종 정리 후 버전 일치 검사를 재확인하며 이 변경으로 전체 기능 테스트나 native 빌드를 반복하지 않는다.

## 최종 통합 경계와 캡처

- 구현 79개 검사: `1baebea69bc559da3fbdff84d78eaa2bdd5edb26`.
- fixture clock만 보정한 `155783caf82bc2235d53003a7f0be12b6b966cc8`에서 준비 위젯 18개 재통과: [로그](precheck-ux-evidence/fixture-tests.log). 같은 소스의 실제 웹 빌드 성공: [로그](precheck-ux-evidence/fixture-build.log).
- 홈 PR #189와 서버 PR #188이 포함된 `origin/develop cc139f5`를 충돌 없이 반영했다. 통합 후 홈의 Material TextField를 가정하던 테스트 finder만 실제 EditableText로 바꿨다. 실제 router/list 경계 2개는 `13d535c644dc1e4c480e83d173bd6bf78abaa440`, 실제 list start 전체/선택 subset 2개는 `8a6b4b47f526c88a391c07ee5b62cedd2306cade`에서 재확인했다 (사이 변경은 문서·불필요한 test null assertion 제거뿐): [route](precheck-ux-evidence/integrated-routing.log), [start](precheck-ux-evidence/integrated-start.log). 홈 전체 70개나 서버 전체 검사는 반복하지 않았다.
- 실제 Flutter 화면: [before 390](precheck-ux-evidence/before-390.png), [준비 완료 390](precheck-ux-evidence/after-ready-390.png), [320×568/2배 글자 고정 CTA](precheck-ux-evidence/after-error-320-scale2.png), [동일 320px 오류 내용 전체를 보는 tall 캡처](precheck-ux-evidence/after-error-320-scale2-tall.png). 마지막 tall은 viewport 320×2000이며 작은 화면으로 가장하지 않는다.
- 캡처 fixture의 앱/준비 소스는 `155783c`이며 아래 프로토콜 경계 보정 전의 화면이다. 고정 CTA·root route·카드/테마 레이아웃은 이후 변경하지 않았다. 이후 2.2.1 메타데이터와 새 홈 통합 경계는 별도 위젯 검사로 확인했다.
- 브라우저 이미지 endpoint 기록 [local-image-http.json](precheck-ux-evidence/local-image-http.json)은 0건이다. fixture에 실제 계정/원격 미디어가 없으며 이 기록을 실물 TV 네트워크 검증으로 확대하지 않는다.
- Orca IME 입력 보호가 일시적으로 클릭을 차단했으며 정상 재시도 후 화면 진입·캡처는 완료했다. CanvasKit 브라우저의 wheel/Back 입력으로 화면 전환을 확정하지 못해 브라우저 Back/scroll 성공을 주장하지 않는다. 390·320 큰 글자/safe-area 조건의 실제 앱 라우터 위젯 테스트에서 Back/scroll/CTA 위치와 목록 복원을 검증했다. 통합 담당의 실제 시뮬레이터 런칭이 남는다.

최종 인계 PR head는 PR 본문의 `검증한 커밋:`에 기록한다. 그 이후 문서·로그만 추가된 경우 위 제품 소스 검증을 재사용한다.

최종 관련 테스트/fixture analyze: `13d535c644dc1e4c480e83d173bd6bf78abaa440`, [문제 없음](precheck-ux-evidence/integrated-analyze.log). 버전/소식 6개 검증도 같은 SHA에서 재확인했다. 이 기록과 로그 추가는 제품 코드를 바꾸지 않는다.


## Enrolled 혼합 프로토콜 경계 보정

기존 구현은 이 경계를 처리하지 못했다. enrollment는 controller에서 확인했지만 paired + auto 전체를 그대로 admission에 전달해, `resolveManifest`의 TV 한 대 프로토콜 거부가 전체 준비를 실패시켰다. receipt가 실패한 미선택 TV를 제외하는 기존 검사는 이 admission 이전 실패를 다루지 못했다.

보정 구현·검사 SHA: `3a61534e90e56acadc13dc2edec98d6cdb08a8ba`. 공유 device decoder에서 기존 서버 필드 `imageUsageProtocol`을 읽는다. 새 RPC나 구독 없이 기존 enrollment 확인 뒤 초기 후보의 프로토콜로 준비 집합 C를 결정한다. 공통으로 workout의 required timing protocol 미만을 제외하고, enrolled에만 imageUsageProtocol != 1 / preparationProtocol < 2 / playbackProtocol < 2를 추가 적용한다. 따라서 enrolled의 playback 조건은 서버와 같은 max(2, required)이며 nonenrolled의 기존 preparationProtocol 0/1 지원에 enrolled 요구를 적용하지 않는다.

제외 TV는 화면에 계속 표시하되 `TV 앱 업데이트 필요 · 준비 대상에서 제외됨`과 비활성 checkbox를 보이고 전체 선택에도 포함하지 않는다. 선택 S와 proof/fingerprint는 실제 준비 가능한 C에 묶인다. checkbox·전체 선택·전체 해제는 로컬 연산만 하며, C가 0이면 빈 대상 admission/prepare를 보내지 않고 Start를 비활성화한다. TV 업데이트 뒤 준비 화면을 다시 열면 새 health snapshot으로 확인한다. 서버의 실제 pairing/display UID/access/revocation/owner/quota/active-slot/만료/manifest 및 commitSelected 권한 검사는 그대로이며 backend 파일은 수정하지 않았다.

```sh
flutter test --no-pub test/preparation_protocol_cohort_test.dart test/workout_preflight_dialog_test.dart --name 'enrolled mixed protocols|enrolled all incompatible|all eligible displays prepare once'
dart analyze lib/src/app/feature/device/domain/entities/device_pairing.dart lib/src/app/feature/device/data/datasources/device_pairing_realtime_data_source.dart lib/src/app/feature/device/presentation/controllers/display_preparation_controller.dart lib/src/app/feature/workouts/presentation/widgets/preparation_shadcn.dart lib/src/app/feature/workouts/presentation/widgets/workout_preparation_page.dart test/preparation_protocol_cohort_test.dart
```

관련 3개 통과([로그](precheck-ux-evidence/protocol-cohort-tests.log)), analyze 문제 없음([로그](precheck-ux-evidence/protocol-cohort-analyze.log)). 혼합 enrolled 한 대 호환/한 대 비호환의 실제 page/controller 흐름: enrollment 1, prepare 1(호환 ID만), client preparation write 0, shared device subscription 1; checkbox 4회·전체 해제/선택 2회 후 추가 prepare/enrollment 0; Start proof 검증 후 실제 client commitSelected 경로를 fake transport로 1회 호출하여 정확한 호환 ID만 전달/반환했다. 전부 비호환이면 prepare 0이고 broadcast/solo 없음도 확인했다. 기존 nonenrolled fixture(preparationProtocol 1, imageUsageProtocol 기본 0)는 모든 TV 준비 1회와 반복 선택 RPC 0을 유지했다.

기존 79개 전체, UI 캡처·native build·외부 callable 저장 검증은 재실행하지 않았다. 이번 3개는 로컬 fake repository/transport 검증이며 실제 개발 서버나 실물 TV 연결 성공을 뜻하지 않는다. 버전 `2.2.1+13`, 홈 UI, 전역 navigation 및 backend 보안 계약은 무변경이다. root가 최종 SHA로 개발 callable/TV 통합과 iOS 빌드를 진행한다.
