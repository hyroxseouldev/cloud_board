# STA-169 · Soft Rhythm brand loading

## 구현 범위

초기 진입의 별도 원형 스피너를 제거하고 기존 `assets/branding/soft_rhythm_mark.png`를 그대로 사용한다. 로고 형상·질감·색·원본 파일, 네이티브 시작 이미지 및 아이콘은 변경하지 않았다. 관리 UI의 진행률·버튼 처리·TV 재생 로딩처럼 초기 진입과 목적이 다른 표시기는 바꾸지 않는다.

| 단계 | 표시 및 종료 조건 |
| --- | --- |
| Android/iOS OS launch | 기존 oat 바탕 + 정적 원본 로고. OS 시작 화면에서는 애니메이션하지 않음 |
| 웹 HTML → JS/engine 준비 | 같은 번들 원본, 128 CSS px, oat 바탕. `flutter-first-frame`에서 바로 DOM 제거 |
| Flutter 초기화 (`AppBootstrap`) | 공통 `SoftRhythmLoadingMark`. 실제 초기화 완료 즉시 다음 화면. 최소 노출 시간 없음 |
| 인증 복원 (`/auth-loading`) | 같은 공통 로고. 기존 redirect, 목적 경로 및 로그인/온보딩/홈 분기 보존 |
| 초기화 실패 | 정적 로고 + 기존 안내/재시도. HTML 엔진 실패는 페이지 새로고침으로 재시도 |
| 긴 초기화 | 기존 pending 상태 유지. 새 timeout·실패 판정·자동 retry 또는 임의 지연을 만들지 않음 |

네이티브 first-frame defer/allow 균형은 유지한다. 로컬 원본의 decode만 기다리고 Firebase/네트워크 초기화는 병렬로 진행한다. 빠른 이동·이미지 실패·dispose에서도 first-frame hold를 해제한다. Flutter 최초 프레임이 실제 렌더되기 전에는 HTML 로고를 제거하지 않는다.

## 확정 모션

| 항목 | 값 |
| --- | --- |
| 원본 레이아웃 크기 / 중심 | 128 logical px / 화면 정중앙 |
| 크기 | 1.00 → 0.97 → 1.00 |
| 불투명도 | 1.00 → 0.80 → 1.00 |
| 전체 주기 | 1,800ms (각 반주기 900ms) |
| easing | Flutter `easeInOut`, CSS `ease-in-out` (같은 cubic-bezier 0.42,0,0.58,1) |
| 배경 | `AppColors.canvas` #F7F5EF |
| 시작/정지 | 최대 크기·불투명도에서 시작, 동작 줄이기/접근성 탐색/배경/TickerMode 비활성 때 정적 원본 |

회전·바운스·번쩍임·새 로고·원격 이미지·대기시간 추가 없음. 공통 위젯은 이미지 subtree를 유지하고 합성의 scale/opacity만 변경한다. `앱 준비 중` semantics는 고정된 하나의 live region으로 이미지 및 프레임별 중복 안내를 제외한다. HTML도 하나의 status만 사용하고 첫 Flutter 프레임에서 제거한다. 실제 스크린리더의 기기별 음성 발화는 수동 확인 항목이다.

Flutter lifecycle은 inactive/hidden/paused에서 controller를 중지하고 1.0으로 돌린다. route가 TickerMode로 가려져도 중지하며 dispose 때 controller를 해제한다. 웹은 visibility/pagehide에서 CSS animation을 제거하고, pageshow 때 복원한다. 완료 후 DOM과 이벤트 listener를 정리한다.

## 자산·브랜드 계약

- Dart는 기존 `SoftRhythmMark.imageProvider`를 공유한다. HTML 경로 `assets/assets/branding/soft_rhythm_mark.png`는 Flutter 웹 빌드의 동일 원본 번들이다. 별도 이미지 복사/다운로드가 없다.
- 표시 이름은 기존 `config/brand.json` → `tool/brand.mjs` 계약을 유지한다. 생성기는 `web/index.html`의 소유 title/meta 필드만 수정하므로 로더 마크업을 지우지 않는다.
- `tool/startup_loading.test.mjs`가 HTML/Dart 원본 경로·128px·canvas·모션 범위/주기 일치 및 오류·정리 동작을 검사한다. 원본 자산의 픽셀은 변경하지 않는다.

## 검증 기록

- Node: `node --test tool/startup_loading.test.mjs tool/brand-platforms.test.mjs tool/brand.test.mjs` **21/21 통과**. `node tool/brand.mjs --check` **15 outputs / 0 changes**.
- HTML Chromium: 390×844, 1440×900, 원본 decode, reduced motion, pagehide/pageshow, 첫 프레임 제거, 스크립트 실패·retry 확인. 캡처는 실제 HTML/CSS/JS에 엔진 진입만 통제한 fixture이며 운영 Firebase에 접속하지 않았다.
- Flutter VM: startup/auth/native resources 및 캡처 **24/24 통과**. 30초 pending, 실제 실패→retry, 즉시 완료, local decode 지연/실패/빠른 이탈, 중심/크기/큰 글자, reduced-motion 전환, background/resume, TickerMode, dispose 확인.
- Flutter Chrome: 공통 로고·startup·bootstrap·auth router **17/17 통과**.
- `flutter analyze --no-pub`: **No issues found**. 전체 `lib/main.dart` 웹 release 빌드 성공.
- 실제 release를 로컬 Chromium에서 실행: HTML → 실제 engine first frame → Flutter 로고 → 로그인 확인. 외부 서비스 요청은 차단하고 CanvasKit만 빌드의 로컬 파일로 응답했다. `release-handoff-checks.json` 시각은 로컬 관찰값이며 성능 벤치마크/실기기 수치가 아니다.
- 부모 작업자가 CI에 Node startup 계약과 Chrome 로딩 회귀를 추가했다.

### 화면 증거

- [HTML mobile](html-phone.png), [HTML desktop](html-desktop.png), [HTML reduced motion](html-reduced-motion.png), [HTML failure](html-error.png)
- [HTML 호흡 실제 Chromium 녹화](html-breathing.webm), [브라우저 모션 수치·상태 검사](html-motion-checks.json)
- [Flutter mobile](flutter-phone.png), [Flutter desktop](flutter-desktop.png), [Flutter reduced motion](flutter-reduced-motion.png), [Flutter error](flutter-error.png)
- [큰 글자 가로 오류](flutter-error-large-text.png), [같은 화면 retry로 스크롤](flutter-error-large-text-scrolled.png). 기존 중앙 로고/스크롤 레이아웃을 유지하고 테스트에서 실제 버튼 도달·탭을 확인했다.
- [실제 Flutter 24프레임 호흡 GIF](flutter-breathing.gif): 75ms 간격의 실제 위젯 캡처, GIF의 10ms 정밀도는 70/80ms 교대로 총 주기 1,800ms 유지.
- [실제 release Flutter 첫 화면](release-flutter-pending.png), [동일 실행의 로그인 도착](release-login.png), [engine handoff 검사](release-handoff-checks.json)

### 재현

```sh
flutter test --no-pub test/soft_rhythm_loading_mark_test.dart test/app_startup_screen_test.dart test/startup_performance_test.dart test/auth_router_test.dart test/auth_startup_performance_test.dart test/native_splash_resources_test.dart tool/sta169_loading_capture_test.dart
flutter test --no-pub --platform chrome test/soft_rhythm_loading_mark_test.dart test/app_startup_screen_test.dart test/startup_performance_test.dart test/auth_router_test.dart
flutter analyze --no-pub
flutter build web --release --no-pub --no-wasm-dry-run --output build/sta169-app-web
```

`tool/sta169_loading_capture_test.dart`는 실제 제품 위젯의 PNG 및 build/sta169-motion 프레임을 기록한다. `tool/sta169_loading_preview.dart`는 Firebase 없이 pending/error/ready를 수동 확인할 수 있는 별도 진입점이다. 이번 release browser 검증은 preview 진입점이 아닌 전체 `lib/main.dart` 빌드로 수행했다.

## 플랫폼 경계 / 출시 전 수동 확인

Android/iOS 설치 앱과 실제 모바일 브라우저는 이번 작업에서 실기기 측정하지 않았다. 해당 플랫폼의 OS launch → Flutter frame → 로그인/홈, 운영 인증 네트워크 지연, VoiceOver/TalkBack 발화, OS 동작 줄이기, background/resume은 설치 빌드로 확인해야 한다. 자동 위젯 테스트/데스크톱 Chromium의 모바일 viewport를 실기기 검증으로 표현하지 않는다. 기존 네이티브 리소스는 그대로이며 앱 업데이트 이후 cold start로 확인한다.
