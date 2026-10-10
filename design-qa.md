# STA-98 홈 첫 진입 로딩 QA

final result: passed

검토일: 2026-10-10. 선택한 1번 시안을 기존 Flutter 홈에 적용했다. 남아 있는 P0/P1/P2 차이는 없다. 구현 증빙은 실제 Flutter 위젯을 렌더링한 캡처이며, 시뮬레이터나 실기기 실행 결과는 아니다.

## 비교 기준과 증빙

- 원본 화면: [reference-home.png](docs/design/home-loading-2026-10-09/reference-home.png)
- 선택한 시안: [01-layout-skeleton.png](docs/design/home-loading-2026-10-09/01-layout-skeleton.png)
- 구현 화면: [implementation-loading.png](docs/design/home-loading-2026-10-09/implementation-loading.png)
- 전체 나란히 비교: [comparison-full.jpg](docs/design/home-loading-2026-10-09/comparison-full.jpg)
- 헤더와 두 행 확대 비교: [comparison-rows.jpg](docs/design/home-loading-2026-10-09/comparison-rows.jpg)
- 재현 가능한 비교 페이지: [comparison.html](docs/design/home-loading-2026-10-09/comparison.html)

로그인 사용자 김선명, 연결된 디스플레이 없음, 온보딩 카드 없음, 최초 목록 응답 대기, 밝은 테마를 비교했다. 프로덕션의 온보딩 카드는 해당 조건에서 기존대로 표시된다.

| 항목 | 크기 / 정규화 |
| --- | --- |
| 시안 원본 | 851 × 1849 px, 생성 이미지의 밀도는 지정되지 않음 |
| Flutter 캡처 | 1206 × 2622 px, 402 × 874 논리 px를 3배로 렌더링 |
| 원래 시뮬레이터 스크린샷 | 1206 × 2622 px, 402 × 874 @3x |
| 실제 비교 크기 | 두 이미지를 각각 402 × 874 CSS px, `object-fit: contain`으로 배치 |
| 비교 브라우저 | Chrome; 이미지 DOM 측정으로 양쪽 402 × 874를 확인 |

전체 비교는 로고·인사말·디스플레이 연결·목록·추가 버튼의 구성을, 확대 비교는 안내 문구·바 두께·썸네일·동작 영역·행 간격을 확인했다. OS 상태 표시줄과 홈 인디케이터를 앱 콘텐츠로 합성하지 않았다. 브라우저는 비교용 이미지를 표시하며 Flutter 앱을 실행하는 페이지가 아니다.

## 발견 사항과 수정 이력

1. **[P2, 해결] 초기 스켈레톤의 텍스트 바가 시안보다 길고 두꺼웠다.** 제목/메타/시간 바의 폭을 가용 영역의 70%/46%/23%로 줄이고, 실제 행의 줄 높이는 유지하면서 바 높이는 60%로 줄였다. 수정 후 동일한 상태로 캡처를 다시 생성했고, 전체 및 확대 비교에서 얇은 세 줄과 두 행의 구성을 확인했다.
2. **[P2, 해결] 웹에서 최초 실패 후 재시도할 때 상단 스피너와 스켈레톤이 함께 표시됐다.** 상단 새로고침은 기존 데이터가 있을 때만 동작·회전하도록 수정했다. 최종 소스의 Chrome 홈 테스트 33개가 통과했고, 최초 재시도에는 스켈레톤만 표시된다.
3. **캡처 정리:** 테스트 배너를 숨기고 캡처에서 그림자를 활성화했다. 테스트용 이미지 생성 변경이며 앱의 실제 테마나 로고를 수정하지 않았다.

## 필수 시각 요소 점검

| 요소 | 결과 |
| --- | --- |
| 글꼴·타이포그래피 | 앱의 Pretendard와 기존 제목·인사말 스타일을 유지했다. 로딩 안내는 muted 14 / 줄 높이 1.3이다. 캡처 도구는 Pretendard Regular 한 파일을 로드하므로 로고의 굵기가 실제 앱보다 가볍게 보일 수 있다. 프로덕션 폰트 설정 변경은 없다. |
| 여백·배치 | 모바일 좌우 24, 썸네일 60, 동작 영역 44를 실제 행 구조와 맞췄다. 안내 문구 공간을 완료 후에도 유지해 첫 행의 상승을 막는다. 태블릿은 기존 목록과 같은 그리드 계산을 공유한다. 시안의 부정확한 행 간격 대신 기존 실제 행 높이를 유지했다. |
| 색상 | 흰 배경과 기존 accent/muted/line 토큰을 사용한다. 스켈레톤은 #F0EEF5 → #F8F7FB의 낮은 대비 밝기 이동이다. 캡처의 밝기 차이는 애니메이션 시점에 따른 것이다. |
| 이미지·아이콘 | 새 이미지 자산을 앱에 넣지 않았다. 기존 로고·Material 아이콘을 그대로 사용하며, 장식용 스켈레톤은 실제 Flutter 도형이다. 시안 PNG를 화면 배경으로 사용하는 방식이 아니다. |
| 문구·콘텐츠 | 대기 중에는 `워크아웃`과 `워크아웃을 불러오는 중`만 표시한다. 5초 후 `연결이 조금 지연되고 있어요`, 실패 시 `워크아웃을 불러오지 못했어요`와 `다시 시도`를 표시한다. 개수와 빈 목록 안내는 응답 이후에만 나타난다. |

추가 버튼의 활성 상태와 위치는 기존 앱 동작을 유지했다. 시안의 옅은 버튼은 초기 준비 미완료 예시이며, Linear 명세에 따라 생성 가능한 사용자를 목록 조회 때문에 차단하지 않는다. 폴더 선택과 장식용 행은 초기 응답 전에 비활성화한다.

## 추가 상태와 접근성

- [실패](docs/design/home-loading-2026-10-09/implementation-error.png), [재시도 후 정상 목록](docs/design/home-loading-2026-10-09/implementation-loaded.png): 한 번의 재시도 경로, 내부 오류 내용 비노출, 실제 항목/개수 복원.
- [작은 화면·큰 글꼴](docs/design/home-loading-2026-10-09/implementation-large-text.png): 320 × 568, 텍스트 2배, 출력 960 × 1704. 줄바꿈과 스크롤이 동작하고 오버플로가 없다.
- [태블릿](docs/design/home-loading-2026-10-09/implementation-tablet.png): 1194 × 834, 출력 3582 × 2502. 실제 그리드와 같은 열 배치를 사용한다.
- 834 × 1194 / 텍스트 2배도 위젯 테스트에서 오버플로 없이 통과했다.
- 로딩 상태는 하나의 live-region semantics 노드로 노출하고 장식용 스켈레톤은 제외한다. 모션 감소에서는 밝기 이동과 목록 전환 효과를 표시하지 않는다.
- 150ms 이내 응답은 스켈레톤을 건너뛰며, 노출 시간을 맞추려고 데이터를 기다리게 하지 않는다. 기존 데이터의 새로고침과 페이지 추가 로딩은 목록을 유지한다.

## 검증과 남은 범위

- 전체 Flutter 테스트: **665개 통과**. 이후 바 두께 조정 및 웹 상단 스피너 조건 수정 후 관련 홈 테스트를 다시 실행했다.
- 최종 소스의 홈 위젯 테스트: **33개 통과**.
- 최종 소스의 Chrome 홈 테스트: **33개 통과**.
- Flutter 캡처 테스트: **1개 통과**, 위의 다섯 화면 생성.
- 최종 `flutter analyze --no-pub`: **No issues found**.
- Dart 포맷과 `git diff --check` 통과.

실기기/시뮬레이터에서 실제 네트워크 지연과 VoiceOver 발화를 직접 확인하지 않았다. semantics, 상태 전이, 오류 복구, 레이아웃, 웹 동작은 자동 테스트로 확인했다. 시안은 정지 이미지이므로 애니메이션 체감은 기기 검토 시 추가 확인할 수 있다. 이는 이번 변경의 남은 수동 검증 범위이며 발견된 결함은 아니다.

## 구현 체크리스트

- [x] 1번 시안의 두 행 스켈레톤과 단일 상태 문구 적용
- [x] 초기 대기·실제 빈 목록·실패·재시도·기존 목록 갱신 구분
- [x] 스피너 중복, 초기 0개 노출, 비활성 폴더 조작 방지
- [x] 큰 글꼴·태블릿·모션 감소·타이머 해제 검증
- [x] 수정 후 동일 크기의 전체/확대 비교와 자동 테스트 확인

---

# STA-54 · Android / TV 복귀 화면 구현 검증

2026-10-01 · develop · 선택한 1번 수정본 구현

## 시각 비교 근거

- Source visual truth: `docs/design/resume-sync-2026-10-01/01-centered-refined.png` (1538×1024 디자인 보드).
- Implementation: 같은 폴더 `evidence/android.png`, `evidence/tv-1080p.png`, `evidence/tv-4k.png`, `evidence/android-error.png`, `evidence/android-landscape-large-text.png`, `evidence/tv-error.png`.
- 실제 `PlaybackRecoveryView`를 Flutter 엔진으로 렌더링했다. 설치된 기기 화면이나 Android 알림 캡처를 의미하지 않는다. 테스트 폰트는 저장소 Pretendard / Material Icons를 로드했다.
- Viewport: 휴대폰 390×844dp → 780×1688 PNG; TV 960×540dp → 1920×1080 PNG; 1920×1080dp → 3840×2160 PNG. 큰 글꼴 가로 화면 844×390dp, text scale 2. CSS viewport는 해당 없음.
- 소스는 기기 프레임 없는 합성 보드다. 휴대폰 약 400×792, TV 약 976×540 영역과 구현의 해당 콘텐츠를 논리 크기 기준으로 비교했다. 휴대폰 화면 비율 차이는 반응형 여백으로 수용하며 픽셀 단위 일치를 주장하지 않는다. 실제 구현 크기는 이슈의 14sp / 20–24sp 명세를 기준으로 했다.
- 전체 시안, 휴대폰 구현, TV 구현을 같은 도구 결과에서 함께 열어 비교했다. 중앙 링·라벨과 좌상단 워드마크가 충분히 크게 보여 별도 확대 크롭은 필요하지 않았다. 오류 상태는 원안에 없어 별도 기능 검증 대상으로 확인했다.

## 비교와 수정 이력

1. 첫 렌더에서 기본 indeterminate 스피너가 작은 크기에서 짧은 점처럼 줄어드는 순간을 확인했다. 선택안의 열린 링 형태가 잘 보이지 않는 P2 차이였다.
2. 22dp / 28dp, 두께 2의 일정한 열린 링을 회전시키도록 수정했다. 회전각은 프레임마다 다르며 진행률을 표시하는 UI가 아니다. 접근성에는 상태 라벨만 전달한다.
3. 수정 후 같은 viewport에서 다시 캡처하고 원안과 함께 비교했다. 최종 증거는 위 evidence 파일들이다. 확인한 복귀 화면에 남은 P0/P1/P2 시각 문제는 없다.

## 필수 시각 항목

- 글꼴: 앱의 Pretendard, 모바일 14sp / TV 22sp. Material과 명시적 기본 글자 스타일로 빨간 기본 글씨·노란 밑줄 상속을 차단했다. 2배 글꼴도 오류 없이 표시/스크롤된다.
- 간격: 중앙 정렬, 링과 라벨 16dp, 모바일 좌우 24dp. 작은 화면의 오류 버튼은 Wrap / Scroll로 접근 가능하다.
- 색상: 모바일 흰색, TV #050505, 링 #77729D. 모바일 라벨 #777683, TV 라벨 #E4E1EE. TV 오류 상세창도 어두운 테마를 사용한다.
- 에셋: 신규 브랜드를 만들지 않고 기존 CloudBoard 모니터·파형 도형을 런처와 단색 알림 아이콘에 재사용했다. Flutter 기본 런처 PNG 5개를 교체했다. TV 전용 배너·아이콘은 기존대로다.
- 문구: `수업 동기화 중`; 5초 이상 대기에 작은 설명. 실패는 재연결 안내, `다시 연결`, `오류 상세`로 분리한다. 앱 내부 기술 정보를 정상 로딩 문구에 노출하지 않는다.
- 접근성: 애니메이션 감소 설정에서 정적 sync 아이콘. TV 오류의 재시도 버튼에 최초 포커스와 리모컨 Enter 동작 확인.

## 동작 및 검증

- `flutter analyze --no-pub`: No issues found.
- Flutter 관련 회귀 테스트 20개 + 렌더 캡처 1개 통과. 검증 파일: playback_recovery_view, playback_recovery, active_class_shell, tv_playback_lifecycle, android_class_notifications 및 tool/playback_recovery_capture_test.dart.
- 서버 확인 전 명령 차단, 실패/재시도, 오래된 revision 거부, 삭제된 수업 복원 방지, 외부 수업 종료 처리, TV 백그라운드 음소거와 재복귀 경합 검증.
- Android `:app:testDebugUnitTest`: ClassCommandTest 10개 통과.
- Android `:app:compileDebugAndroidTestKotlin`: 변경한 알림 코드/리소스 및 계측 테스트 컴파일 성공.
- 구현 차이: 알림은 OS 기본 템플릿과 기존 Live Update 규격을 따른다. 시안의 자유로운 버튼 배치를 그대로 강제하지 않는다. 기존 조작과 서버 확인은 보존한다. 추정 시간/연결 확인 필요/명령 확인 실패는 별도 문구다.

## 남은 기기 QA

연결된 Android/TV 기기가 없어 계측 테스트 실행과 제조사별 알림 시각 검증은 미실시. 실제 설치 빌드의 잠금 해제·알림 탭 복귀, TV 홈 왕복·오디오 정지, 원거리 가독성, 느린 네트워크를 확인해야 한다. 운영 DB나 실제 수업을 변경하는 검증은 하지 않았다. Linear는 In Review / 테스트 필요로 전달한다.

Implementation checklist: 선택안 UI, Material 상속 수정, 알림 문구/아이콘, 자동 회귀 검증, 렌더 비교 완료. 실기기 확인은 위 항목으로 별도 추적.

final result: passed

범위: 실제 Flutter로 렌더한 복귀 UI의 시각 QA. 제조사별 알림과 실제 디바이스 QA가 완료됐다는 뜻은 아니다.

---

## 이전 검증 기록 (보존)

# STA-33 — compact home implementation QA

Date: 2026-09-25

## Evidence and comparison

- Selected visual: `/Users/sunmkim/.codex/generated_images/01a08de2-8e40-7921-a76c-c4f878ee2ae1/exec-4e09ed30-21ca-42f6-93a9-c265358f6305.png`.
- Rendered implementation: `docs/design/home-list/implementation.jpg`, captured from the rebuilt iPhone 17 Pro simulator. Capture tool exports 368 × 800 pixels; the app runs at the simulator's native logical viewport. No CSS viewport applies to this native Flutter implementation.
- Source and final implementation were opened together in one tool result. Compared the whole home and focused on the appbar, greeting, folder control, thumbnail, row actions and bottom-right FAB. Both are idle/light theme, one workout, with search and drawer closed.
- Native status bar and safe areas account for the source's missing system chrome. The real account name, folder and actual disconnected display state intentionally replace mock content. The existing waterfall image is loaded from workout data and cropped to a square for the list.
- Prior login QA preserved at `docs/design/login-welcome/qa.md`.

## Findings and fixes

1. Initial simulator review: folder selector was not right-aligned, drawer wordmark inherited small text, and the overflow action lacked the reference's rounded surface. Corrected all three and added the final row divider.
2. Final comparison: compact hierarchy, rounded thumbnail, separate play/overflow buttons, white background and lower-right plus FAB match the approved direction. Existing Pretendard and purple theme are retained; system chrome and real data differ intentionally. No actionable P0/P1/P2 visual findings remain in the reviewed home state.
3. A subsequent capture caught the user opening the folder menu rather than the drawer; it was not used as drawer visual verification. Drawer destinations are verified by widget tests. No claim of a complete visual audit of every destination page.

## Behavior and checks

- Search moves to the appbar action, receives focus, clears/closes, and restores prior page and scroll offset.
- Folder filtering and pagination retained; single-page controls hidden.
- Mobile uses a compact list; iPad portrait/landscape retain three-column grids; existing web maximum width retained.
- Drawer links retain existing destinations; the duplicate favorites destination was removed after user feedback. Favorites remains a filter inside the slide library.
- Display connection label uses paired/online device data rather than a mock count.
- Existing playback entry, preflight, copy/delete actions and active-workout edit restrictions retained.
- Targeted home, auth-router and slide-template tests passed; resize coverage includes 320–1600 logical width and 2× text, plus iPad portrait/landscape.
- Targeted static analysis passed. Final iPhone simulator build/install/launch passed.
- Real display pairing and a complete class playback session were not retested for this home layout change. No backend, authentication or subscription schema changes.

## Follow-up: drawer navigation

- User reported the drawer closing visibly only after returning from a destination. Previous code started drawer close and route push together, allowing the offstage home ticker to pause before close finished.
- Queue one destination, close the drawer, and navigate after Flutter unmounts the fully dismissed drawer content. The early onDrawerChanged(false) callback is not used as an animation-completion signal. Pending navigation is guarded against duplicate taps and an unmounted/non-current home route.
- Regression test verifies the destination is absent while the drawer closes, drawer content is absent even offstage on the destination and during back navigation, and another menu destination still works afterward. Home suite: 14 passed; targeted static analysis passed.
- Drawer now has one slide-library destination; favorites remains inside that page.

final result: passed


## Slide editor inline bottom tabs — 2026-09-25

- Scope: selected third displayed mock; existing Flutter app bottom tabs only.
- Source visual truth: docs/design/editor-inline-tabs/reference.png (1430×1100 component concept, intended logical width390).
- Implementation: docs/design/editor-inline-tabs/implementation.jpg (368×800 tool-normalized screenshot of iPhone17Pro402×874 logical viewport).
- State: sound tab selected, light theme. Source and implementation opened together in one comparison tool result. Compared app-owned bottom bar regions, normalized concept width390 and implementation width402; full-screen image includes OS chrome and existing preview that are outside this component change.
- Typography: Pretendard, compact12px (11px below350 width), selected700weight. Inline labels readable and untruncated in screenshot and320/390/834/844 tests. Larger accessibility text uses stacked icon/label layout rather than truncation.
- Layout: white full-width bar, thin divider, icon left of label, lavender selected rounded rectangle.56px content height,48px targets and native bottom safe area. Library receives slightly more width for its longer label. No floating shadow or outer pill.
- Color: existing primary #77729D, primaryContainer #E4E1EE, outlineVariant #E6E3EF. Matches source palette.
- Assets: existing Material outlined icons (timer/image/volume/overlapping slides), no raster assets needed by the implementation.
- Copy: 타이머 / 배경 / 소리 / 라이브러리 exactly retained. Existing sound explanations outside the bar retained.
- Comparison history: first narrow320 widget check found1.8px overflow; reduced font to11px at widths below350. Repeated four-size tab tests and timing tests:9passed. Post-fix simulator capture confirms single-line text and selected sound state. Native accessibility snapshot exposes all four as buttons.
- Findings: no actionable P0/P1/P2 component differences. Minor source/render icon stroke and panel-width differences follow the existing app icon library and responsive constraints.
- Verification: analyzer clean; native hot reload successful; sound tab tap verified. No browser prototype, build or deployment involved.
- Follow-up: large accessibility text fallback has not been visually captured on simulator.
- final result: passed

## STA-34 — Firebase onboarding, design 3 (2026-09-25)

- Reference: `docs/design/onboarding/reference.png`, 850×1848, approved purpose-selection mock 3.
- Implementation: `docs/design/onboarding/purpose-fixture.png`, real Flutter widgets at 390×844 logical / 780×1688 raster, regular Pretendard and Material icons loaded, fake repository with operating selected. This is a deterministic UI fixture, not a production account with fabricated verification.
- Live entry: `docs/design/onboarding/phone-simulator.jpg`, 368×800 normalized screenshot from iPhone 17 Pro, authenticated callable loaded successfully after hot reload. No real SMS was sent.
- Reference, purpose fixture and live phone entry were opened together in one comparison result. Compared normalized full frames and the heading, progress indicators, grouped choices, selected border, bottom primary action and explanatory copy.
- White background, existing lavender theme, three purpose rows, trailing radio controls, outline group and bottom CTA match the chosen direction. AppBar uses the existing brand style; `건너뛰기` is clarified as `나중에` because it saves progress. Initial production state has no preselected purpose. Native status bar/safe area appears on device and is outside the supplied mock.
- Existing Material outlined icons replace the mock's drawn icons. No generated raster assets are needed in the app. Form body scrolls independently above the bottom action, with a 600 logical-pixel content limit on wider devices.
- Tests cover 320/390/834 widths without overflow, failed save retry, explicit trial consent, existing-access completion and auth redirect. The phone screen uses a scrollable body for the keyboard. Subsequent center fields and trial steps were behavior-tested; not all field combinations have live simulator screenshots.
- No actionable P0/P1/P2 visual findings in the reviewed purpose and phone states. Actual SMS delivery and full production OTP completion remain manual checks.
- final result: passed for reviewed visual states.

## STA-86 / STA-87 — 통합 타이머 편집과 요약 (2026-10-09)

- Source visual truth: `docs/design/timer-ux-2026-10-09/02-interval-proposed.png`, `03-emom-proposed.png`, `04-mode-change-proposed.png` (853×1844); `05-slide-timer-summary-proposed.png` (1536×1024 component board). 기획과 시안은 https://linear.app/clyrdev/issue/STA-86 에 보관했다.
- Implementation captures: 같은 폴더의 `interval-implemented.png`, `emom-implemented.png`, `mode-change-implemented.png`, `summary-implemented.png`. 결과까지 스크롤한 화면은 `interval-implemented-result.png`, `emom-implemented-result.png`다.
- Viewport / density: 실제 Flutter 위젯을 390×844 logical, pixelRatio 2 (780×1688 PNG)로 렌더링했다. 편집 시안은 390 logical 폭으로 환산해 비교했다. 요약 시안은 전체 페이지가 아닌 컴포넌트 보드이므로 실제 화면의 해당 카드 영역을 기준으로 비율·내용을 비교했다. 네이티브 시트 상단 여백·모서리와 기존 슬라이드 캔버스는 시안 밖의 기존 제품 구조다.
- States: 인터벌 13:20 + 01:00 = 14:20, EMOM 2분×3구간/30초 휴식×6라운드 = 39:00, EMOM→AMRAP 10:00 교체 확인, 인터벌 7분/2분×3회 = 27:00 요약. 캡처 도구는 `tool/timer_ux_capture_test.dart`; 마지막 캡처는 메모리 저장소를 사용해 실제 계정·수업을 쓰지 않는다.
- Full-view comparison: 각 원본 이미지와 대응하는 구현 이미지를 동일 도구 응답에 함께 열어 확인했다. 서로 다른 이미지를 픽셀 단위로 동일하다고 판단하지 않았다. 폼→상세 편집→총시간/순서→고정 반영 버튼의 정보 구조와 대비를 비교했다.
- Focused comparison: 시간 입력의 수치/분:초, 총시간과 운동·휴식 합계, EMOM의 4개 진행 구간, 요약의 27:00과 07:00/02:00×3 관계, 교체 확인의 현재/변경 후 수치 및 취소/교체 버튼을 확대된 원본 해상도에서 확인했다.

**Findings and comparison history**

- [P2, resolved] 최초 캡처에서 큰 반복 횟수 입력칸과 여백 때문에 진행 순서·시험 재생이 첫 화면 아래로 밀렸다. 반복은 직접 입력 가능한 −/+ 컨트롤로 바꾸고, 입력 행간/높이 및 구간 간격을 조정했다. 재캡처에서 인터벌의 운동/휴식 순서와 시험 재생이 표시된다.
- [P2, resolved] EMOM의 마지막 휴식 칩이 다음 줄로 밀렸다. 칩 패딩과 행간을 줄여 390 폭에서 운동 3구간과 휴식이 한 줄에 표시된다. 최종 `emom-implemented.png`에서 확인했다. 작은 화면/글자 확대에서는 정상적으로 여러 줄을 사용한다.
- [P2, resolved] 최초 상세 구간의 배경이 ListTile 터치 효과를 가렸다. Material 표면으로 바꾸고 위젯 회귀 검사로 확인했다.
- [fixture-only, resolved] 첫 요약 캡처에 플랫폼 저장 플러그인 미초기화 경고가 있었다. 캡처용 메모리 저장소를 연결한 뒤 재캡처했다. 실제 브라우저에서는 로컬 저장소가 정상 동작하고 같은 오류가 없었다.
- 현재 검토한 상태에 남은 P0/P1/P2 문제 없음. 최초 캡처는 대화의 도구 결과에 남아 있으며, 위 구현 파일은 수정 후 최종 캡처다.

**Required fidelity surfaces**

- Fonts / typography: 기존 Pretendard와 Material 아이콘을 사용한다. 모드명·시간은 굵게, 입력 레이블은 중간 굵기, 보조 문구는 작은 크기로 구분했다. 실제 폰트로 렌더링한 캡처에서 잘림을 확인했다. 200% 확대는 폼/요약을 세로 배치하고 오버플로 테스트를 통과했다.
- Spacing / layout: 24 logical 바깥 여백, 12–16 반경, 단순 설정 우선 배치, 고정 하단 반영 버튼을 유지했다. 기존 슬라이드 화면의 AI 입력·표시 제어는 유지하고 요약 카드와 12 간격을 뒀다. 새 교체 비교는 긴 무제한 시간 문구도 수용하도록 수치를 세로로 배치한다. 보조 예시와 준비 카운트다운 안내는 작은 화면에서 스크롤로 접근한다.
- Colors / tokens: 앱의 기존 AppColors/SlideEditorStyle 라벤더 강조, 옅은 표면, 흰 배경, 잉크 텍스트를 재사용했다. 선택·비활성·검증 오류 상태는 기존 테마를 따른다. 시안의 미세한 래스터 음영은 앱 전체 테마를 바꾸는 근거로 삼지 않았다.
- Image / icon fidelity: 이 화면은 편집 가능한 Flutter UI다. 앱에 생성 이미지를 배경으로 넣거나 비표준 그림으로 아이콘을 흉내 내지 않았다. 표준 타이머·화살표·재생·닫기 아이콘으로 구성했다.
- Copy / content: 총 소요 시간과 반복 구성을 구분하며 한 번의 `타이머 반영`과 최종 `저장`을 분리했다. 교체 전후의 구조·시간, 무제한/최대 시간, 마지막 휴식 및 저장 전 변경 상태를 확인했다.

**Live browser verification**

- Local production-widget preview: `http://127.0.0.1:4187/`, entry `tool/timer_ux_preview.dart`. 실제 운영 계정·원격 세션을 쓰지 않는 샘플이다.
- In-app browser가 제공되지 않아 Chrome으로 검수했다. 579×863 CSS, devicePixelRatio 2에서 스크린샷과 접근성 트리를 직접 확인했다. 네이티브 390 화면 비교는 위 PNG를 사용했다.
- 수행: 현재 설정 바로 진입 → 키보드로 13:20을 12:00으로 입력 → Tab 포커스 이동 → 총 13:00 확인 → AMRAP 교체 비교 → 취소 후 12:00 유지 → 한 번 반영 → 저장 전 변경 확인 → 저장 후 상태 해제.
- Console: 앱 출처의 error/warn 없음. 별도 설치된 브라우저 확장의 EventEmitter/ObjectMultiplex 경고가 있었으며 앱 코드에서 발생한 오류로 분류하지 않았다.

**Implementation checklist / remaining verification**

- [x] 기존 데이터·초안·취소·반영·저장 경계에 대한 자동 검증.
- [x] 320/390/834 폭, 가로 844×390, 텍스트 200%, 키보드 노출 시 반영 접근성 검증.
- [x] 원본 시안과 실제 구현 비교, 브라우저의 핵심 수정/취소/저장 조작.
- [ ] 실제 휴대폰·TV 원격 재생, VoiceOver/TalkBack 전체 읽기 순서, 코치 사용성은 STA-91에서 별도로 검수한다. 자동 검증으로 대신 완료 처리하지 않는다.
- Follow-up polish (P3): 플랫폼별 스위치·아이콘의 미세한 획 차이와 작은 화면의 보조 안내 위치는 현장 피드백으로 조정 가능하다.
- final result: passed


# STA-111 · 메인 바텀 내비게이션 / 2안 구현 검수

2026-10-10 · `feat/sta-111-bottom-navigation` · 실제 Flutter 앱

## 시각 근거와 범위

- Source visual truth: `docs/design/home-bottom-navigation-2026-10-10/02-playback-dock.png`, 생성 시안 853×1844 (390×844 논리 크기 기준).
- 같은 폴더의 `home-implemented.png`, `idle-implemented.png`, `library-implemented.png`, `more-implemented.png`는 실제 프로덕션 라우터/화면을 로컬 fixture로 렌더링한 780×1688 PNG다.
- 추가 렌더: 320×568, 320×568/글자 200%, 844×390 가로, 834×1194 태블릿, 1440×900 데스크톱. 각각 2배 PNG로 저장했다. OS 프레임·상태 표시줄이 없는 Flutter 렌더다.
- 선택 시안과 구현 홈을 함께 열어 배치·글꼴·표면·아이콘·여백을 비교했다. 추가 크기와 라이브러리/더보기도 별도로 확인했다. 기존 Pretendard와 Material Icons를 로드했고, 사진 대신 기존 슬라이드 원본 에셋을 예시 데이터로 사용했다. 이미지 슬롯의 실서비스 내용은 사용자의 워크아웃에 따른다.
- Chrome에서 실제 루트 탭 전환, 접근성 이름, 웹 뒤로/앞으로와 URL 복귀, 수업 상태 유지도 확인했다. 브라우저 확장 프로그램 경고 외 앱 오류는 관찰하지 않았다.

## 발견 사항과 수정

1. P1 / 레이아웃: 상단 분류를 추가한 라이브러리의 고정 검색 영역이 가로 화면과 글자 200%에서 넘쳤다. 헤더와 지연 생성 목록을 하나의 CustomScrollView/SliverList로 연결했다. 동일 크기 재검증에서 overflow가 사라졌다.
2. P1 / 상태: 기존 세션 유무에 따라 라우트 자식의 부모가 달라져 홈 상태가 재생성될 수 있었다. ActiveClassShell의 본문 위치를 고정하고 세션 컨트롤만 별도 자식으로 유지했다. 수업 등장/종료와 탭 왕복에서도 같은 홈 Element, 플레이어 인스턴스, 일시정지 시간, 저장소 구독을 유지한다.
3. P2 / 표면: 최초 엔진 캡처에서 도크 주변에 배경이 칠해지지 않았다. 셸에 앱 배경색을 명시했다. 도크는 흰색, 미니 바는 연한 라벤더로 분리했다.
4. P2 / 대비: 작은 탭 라벨과 미니 바 보조 텍스트에 `secondaryText #646171`를 적용했다. 흰색에서 약 6.0:1, 연한 라벤더에서 약 5.1:1로 4.5:1 이상이다. 선택 아이콘 #77729D / 선택 배경 #E4E1EE는 약 3.49:1이다.
5. P2 / 글자 확대: 큰 글자에서 탭 아이콘의 높이가 달라 보이던 부분을 상단 정렬했다. 라벨 줄바꿈과 도크 높이 증가를 허용한다. 320 폭/200%에서는 장식 썸네일을 숨겨 미니 바의 제목·시간·조작 공간을 확보한다.
6. 캡처 도구: 첫 홈 프레임의 비동기 썸네일이 로드되기 전에 캡처되던 문제는 fixture 이미지를 precache한 후 캡처하도록 고쳤다. 앱 이미지 로더를 별도로 변경하지 않았다.

## 필수 비교 항목

- 글꼴/정보 위계: 기존 Pretendard, 워크아웃 헤더 옆 만들기, 24 아이콘과 12 탭 라벨을 사용한다. 큰 글자는 자연스럽게 줄바꿈하며 임의 축소하지 않는다.
- 간격/형태: 공통 하단 좌우 16, 미니 바와 도크 10, 하단 안전 영역 + 16. 도크 반경 32, 미니 바 반경 20. 콘텐츠와 바가 실제 레이아웃 공간을 나눠 가지며 마지막 항목을 가리지 않는다.
- 색상/상태: 기존 흰색·라벤더 브랜드 유지. 연결 성공의 기존 녹색은 기능 상태를 전달한다. 선택 상태는 아이콘 배경·굵기·selected 시맨틱으로 구별한다.
- 아이콘/에셋: 표준 Material 아이콘을 사용한다. 소스의 화살표는 전체 수업 복귀를 뜻하는 위쪽 화살표로 정규화했다. 미니 바는 모바일에서 재개/일시정지와 복귀, 넓은 화면에서 이전/다음까지 제공한다.
- 동작/오류: 탭별 검색·분류·스크롤 보존, 현재 탭 재선택 무동작, 계정 변경 시 초기화, 실제 편집 진입/복귀, 딥링크, 다른 루트의 시스템 뒤로가기→홈을 검증한다. 전송 중/복귀 대기/연결 실패 시 기존 명령 차단과 재시도 처리를 유지한다.
- 접근성: 탭 터치 영역 최소 48×48, 미니 재생 버튼 48×48, 항상 보이는 라벨과 접근성 이름, 애니메이션 감소 설정 적용. 키보드가 열리면 도크/미니 바가 함께 사라진다. VoiceOver/TalkBack의 실제 음성 읽기와 실제 iOS/Android 안전 영역은 실기기 확인 대상이다.

## 검증 및 제한

- `flutter analyze`: 통과.
- 관련 회귀/캡처 테스트 75개 통과(홈·라이브러리·재생 셸·인증·새 내비게이션·실제 캡처 42개 + 앱 통합 회귀 33개). 새 내비게이션의 Chrome 테스트 12개 통과. 전체 스위트 및 Chrome 테스트는 PR CI에 포함한다. 포맷 검사: 555개 파일 변경 없음.
- 로컬 전체 스위트/동시 빌드 시 호스트 디스크 부족을 겪어 해당 실행은 완료 결과로 세지 않았다. CI의 전체 테스트/릴리스 웹 빌드 결과를 PR에서 확인한다.
- 실제 운영 DB, TV 송출, 실기기 Android 뒤로가기/시스템 키보드와 화면 낭독기 검수는 수행하지 않았다. 생성 시안이나 fixture 캡처를 실기기 완료 증거로 쓰지 않는다.
- 소스와 다른 예시 이미지·수업 제목·정지 시간, 이전/다음 버튼의 넓은 화면 제한, 대비를 위한 라벨 색 조정은 명시한 구현 차이다. 검토한 렌더와 동작 범위에 남은 P0/P1/P2 문제는 없다.

final result: passed (검토한 Flutter 렌더·자동 동작 범위)
