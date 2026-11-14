# 명시적 재생 대상과 컨트롤러 이미지 유지 — 2.2.0 후보

- 기준: `origin/develop 00a004fd1ab1a50a0baee5e96c532be237cd6ee2` (사용자가 확인한 Dev TestFlight 2.1.7(2)의 소스). 원래 dirty checkout은 수정하지 않았다.
- 작업: `/Users/sunmkim/orca/workspaces/cloudboardapp/compact-preflight`, `hyroxseouldev/explicit-playback-mode`.
- 최신 develop 홈 아이콘 변경 `417effe5e41fd9e42cadff947941f3adbf382b40`을 merge `6f6b1d94725fc9ea6bef951fd4b2755f96888817`로 반영. 홈 파일 충돌/수정 없음, 기존 홈 검증 재사용.
- 구현 `dc2ea36` (선행 명시 모드 `1005f45`), 이미지 원본 변경 회귀 테스트 `0b0a6e098980ab63afdee2d57c65d7d8e52c7712`, 최종 버전 `15d7f211762d495a8cd2f0180ba2051dcac9d7aa`; 마지막 인계 커밋은 문서/증거와 소식의 5개 항목 정리만 포함한다.
- 버전은 최종 사용자 지시에 따라 **2.2.0+12**. 실제 ASC 빌드 번호는 iOS 담당자가 새로 조회/할당한다. 후보 소식은 미게시.

## 원인과 변경

2.1.7(2)는 `remote = selectedDeviceIds.isNotEmpty`였으므로 TV 0대·모두 오프라인·전체 해제 시 자동 solo로 바뀌어 카운트다운/첫 두 슬라이드 로더가 실행됐다. 기존 “원격 자동 이미지 0건” 증거는 선택 TV가 있는 경우였으며 0대 예외를 보장하지 못했다.

이제 기본 사용자 의도는 TV이며 대상 수와 독립적이다. TV 0대에는 시작/이미지 보기/선택 적용이 비활성이고 안내를 표시한다. ‘이 기기에서 재생’을 직접 선택한 뒤 ‘선택 적용’을 눌러야 solo 승인 및 이미지 준비가 시작된다. solo→TV 0대 변경 즉시 이전 이미지 작업의 성공 재사용을 막고 후속 prefetch를 취소한다. 이미 시작한 HTTP의 강제 abort는 기존 계약상 보장하지 않는다.

TV 체크/전체 선택/전체 해제/모드 변경은 로컬 draft만 변경한다. 최초 기본 선택은 한 번 준비하며, 이후 ‘선택 적용’만 immutable applied snapshot을 교체해 한 번 준비한다. 중복 클릭 guard가 있고 draft가 applied와 다르거나 변경 후 원래 선택으로 돌아온 경우에도 적용 전 시작을 차단한다. displayDevices 공유 구독을 재사용하며 체크마다 prepare/admission을 발행하지 않는다. 초기 빈 원격 대상에는 empty-target prepare가 없다.

상단 TV 선택, 실제 준비 상태, 본문 시작 버튼, 맨 아래 수업 구성 순서다. 고정 footer/bottomNavigationBar를 제거했다. 권한/한도/승인 만료/TV 실패와 제외 안내는 유지한다. 원격 optional 이미지는 유효 승인 + 직접 클릭 시만 표시한다.

## 유지한 계약

- 최신 설정·계정·권한·ownership·quota/admission/active-slot, request/revision/hash/targets/fingerprint/freshness와 최종 시작 검사를 변경하지 않았다.
- solo도 기존 서버 승인 검사를 거친다. 반환 `localOnly = !remote && devices.isNotEmpty`를 유지하여 목록 없는 solo의 legacy empty-target server-session 경로를 무조건 local bypass로 바꾸지 않았다.
- solo 카운트다운/시작 이미지 ready/error gate 유지. TV/display의 이미지·음성 전체 준비, legacy 표시, active 수업, 중복 시작/unknown commit 처리 및 프로토콜 변경 없음.

## 컨트롤러 슬라이드 row

현재 슬라이드는 `LayoutBuilder → WorkoutSlideCanvas`/HTML prefer, 이웃은 `WorkoutSlidePreview → ... → WorkoutSlideCanvas`/canvas fallback이었다. 선택 변경 시 같은 이미지의 ancestry/type 및 web provider strategy가 달라져 ImageState가 폐기됐다. 모든 row 항목을 같은 canvas ancestry/preview strategy로 유지하고 현재 항목의 timer/phase 속성만 갱신한다. TV 표시 경로는 그대로다. 닫힌 미리보기의 eager load/전체 prefetch/cache flush를 추가하지 않았다.

- 수정 전 실제 widget 회귀: timer tick·동일 workout의 session revision은 유지되지만 첫 선택 전환에서 ImageState 동일성 assertion 실패. warm memory 이미지에서는 cache hit로 픽셀이 즉시 복구되므로 이 테스트만으로 빈 프레임을 주장하지 않는다.
- 수정 후: 0→1→0→1→0 선택에도 동일 ImageState/provider, skeleton 0, 첫 프레임 유지. 실제 다른 PNG source를 가진 workout revision은 열린 preview scope를 닫고, 다시 열 때 새 provider/새 decoded frame을 표시한다.
- 로컬 웹 실제 GET: 이전 renderer는 preview open 시 slide 0/1 각각 1건, next 시 이미 본 0/1 각각 재요청 + 새 이웃2 = 총5건. 수정 renderer는 open 0/1, next 새 이웃2만 = 총3건; 1→0→1 반복 후에도3건. settled PNG는 레이아웃 증거이며 순간 깜빡임 영상 증거는 아니다. 실제 TestFlight/TV의 모든 깜빡임 원인이 해결됐다고 단정하지 않는다.

## 검증과 증거

SDK `/Users/sunmkim/fvm/versions/3.47.8/bin/flutter`. [증거 폴더](explicit-mode-evidence/).

- `flutter test --no-pub test/workout_preflight_dialog_test.dart test/player_rebuild_performance_test.dart`: **39 통과**, 구현 `dc2ea36`과 동일 소스에서 실행. [로그](explicit-mode-evidence/focused-tests.log).
- `flutter analyze --no-pub` 변경 page/player, 두 테스트, fixture 5경로: **문제 없음**. [로그](explicit-mode-evidence/analyze.log).
- 추가 revision 테스트만 `--plain-name 'controller row preserves'`: **1 통과** + 해당 파일 analyze 통과, `0b0a6e0`과 동일 소스. [로그](explicit-mode-evidence/after/row-revision-test.log).
- `node --test tool/update-news/news.test.mjs`: **6 통과**, 최종2.2.0 metadata. [로그](explicit-mode-evidence/news-tests.log).
- 관련 테스트에 cold 실제 loader/HttpOverrides client 생성0, remote waiting/ready/error/retry0, empty/offline/clear0, solo 양성/ready/error, 취소 late callback, 권한/quota/admission 차단, TV 제외 후 새 proof, 한 구독/초안 변경0요청/적용1요청/더블 클릭,320/390 확대글자 critical error 및 본문 CTA 접근을 포함한다. spy/client-count는 실제 HTTP 계측과 구분한다.
- 실제 Flutter fixture build 성공(앱 전체 빌드 아님). `tool/fixtures/compact_preflight.dart`, `compact_preflight_server.py`; 외부 서비스 datasource는 로컬 override, 운영/실제 계정 접속 없음. localhost8797은 수정본,8798은 player renderer만 기준00a004fd로 교체한 비교 fixture. 기존8796 탭/서버는 유지했다.
- 실제 로컬 HTTP `Cache-Control: no-store`, 각 scene 새 Flutter document/ImageCache와 고유 scene URL: 준비 ready/선택 해제/재선택/solo draft까지 **0건**([before-solo](explicit-mode-evidence/before-solo-http.json)). 명시 solo 적용 후 countdown+slide0+slide1 **3건**([solo](explicit-mode-evidence/solo-http.json)). 이어 empty/offline scene은 추가 **0건**([동일 누적 기록](explicit-mode-evidence/after-empty-offline-http.json)). 이는 fixture 이미지 본문만의 측정이며 앱 JS/font/메타데이터 요청0을 뜻하지 않는다.
- row HTTP 원본은 `before/row-next-http.json`, `after/row-open-http.json`, `after/row-next-http.json`, `after/row-repeated-http.json`; after 파일의 앞3건은 별도 ready scene의 solo 요청이며 controller 필터로 비교한다.
- PNG: [390 ready](explicit-mode-evidence/ready-390.png), [전체 해제](explicit-mode-evidence/cleared-390.png), [빈 목록](explicit-mode-evidence/empty-390.png), [오프라인](explicit-mode-evidence/offline-390.png), [solo](explicit-mode-evidence/solo-390.png), [이전 controller](explicit-mode-evidence/before/controller-390.png), [수정 controller](explicit-mode-evidence/after/controller-390.png). `before/row-*.png`, `after/row-*.png`는 실제 widget 테스트 캡처로 브라우저 캡처와 구분한다.

실제 TV/Dev TestFlight 기기 검증·시작 지연 절감률 측정·전체 앱 테스트/전 플랫폼 빌드·배포는 **미실행/미확인**이다. 새 CI/workflow/tag/main/server/스토어 변경 없음. root가 PR을 리뷰/병합한 고정 SHA를 iOS 담당자에게 인계한다. 마지막 metadata/docs 및 충돌 없는 홈 merge는 기존 준비/player 실행 소스를 바꾸지 않아 유효한 결과를 재사용했다.
