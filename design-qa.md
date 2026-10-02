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
