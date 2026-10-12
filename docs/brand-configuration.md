# 표시 브랜드 설정 (STA-131)

현재 CloudBoard의 이름·문구·디자인을 보존하면서, 표시 설정의 수정 위치를 한 곳으로 모았다.
실제 이름·로고·아이콘 변경 및 공개 전환은 STA-130의 별도 작업이다.

## 수정 위치와 생성 명령

원본은 [`config/brand.json`](../config/brand.json)이다. 앱 실행 중 설정을 다운로드하지 않는다.

```sh
node tool/brand.mjs
node tool/brand.mjs --check
node --test tool/brand.test.mjs tool/brand-platforms.test.mjs
node tool/brand-smoke.mjs
```

마지막 명령에는 PATH의 Flutter가 필요하다. `FLUTTER_BIN=/absolute/path/to/flutter`로 지정할 수도 있다.
영문·한글·긴 이름 및 다른 기본값/링크를 **임시 사본에서만** 생성해 실제 위젯과 데이터 경로를
테스트하고 사본을 삭제한다. 작업 트리와 출시 설정에는 테스트 이름을 기록하지 않는다.

생성기는 순수 Dart `AppBrand`·`AppLinks`, Swift `AppBrand`, Android 문자열 리소스,
Windows/Linux 표시 헤더, 서버의 `AppBrand`를 만든다. 기존 plist와 web 파일에는 지정된
표시 필드만 변경한다. 키가 없거나 중복되면 실패하며, 생성 결과는 결정적이다.
생성 파일을 직접 편집하면 `--check`가 실패하므로 설정 수정 후 다시 생성해 함께 커밋한다.
서버 메시지의 문장과 변수 위치는 원래 사용처에 남겨 두었다.
iOS App Intent의 설명은 Xcode metadata extractor가 문자열 보간을 허용하지 않으므로,
전용 생성 extension에 완성된 문자열 리터럴로 출력한다.

## 현재 표기 대조표

| 설정/사용처 | 현재 값 |
| --- | --- |
| Flutter/Live Activity의 제품명, 서버 구독 안내 | `CloudBoard` |
| 한글 계정·QR·App Intent·인증 SMS 안내 | `클라우드보드` |
| 새 워크아웃/수업 설정의 기본 브랜드 | `CloudBoard` |
| 새 센터 표시 이름 | `CloudBoard Studio` |
| iOS 홈 화면 | `Cloud Board` |
| iOS bundle 표시 이름 | `cloud_board` |
| iOS Live Activity 확장 표시 이름 | `CloudBoard 수업` |
| Android 홈 화면 | `CloudBoard` |
| Web 제목/PWA 이름/짧은 이름 | `cloud_board` |
| macOS/Windows/Linux 사용자 표시 이름 | `cloud_board` |
| 문의 이메일 | `vividxxxxx@gmail.com` |
| 서비스 URL | `https://clyr-landing-20.vercel.app/apps/cloudboard` |
| 개인정보/계정 삭제 안내 | 기존 서비스 URL의 `/privacy`, `/delete-account` |
| 구독 약관 | 기존 Apple 표준 EULA URL |

`AppLinks.support`는 기존 문의 이메일의 `mailto:` 표현이다. 새 지원 화면이나 버튼을 추가하지 않는다.
구독 관리 페이지의 Apple/Google URL은 기술 계약과 함께 기존 사용처에 남겨 둔다.
향후 이름을 바꿀 때에는 `display`와 `platforms`의 값을 각각 검토한다. 플랫폼별 표기를
자동으로 하나로 맞추거나, 사용자 센터 이름을 앱 이름으로 치환하지 않는다.

## 신규 기본값과 과거 데이터

`Workout.empty`, 새 `WorkoutPreferences`, `BrandTemplate.initial`은 현재 설정의 기본값을 쓴다.
기존 문서의 누락 필드를 해석하는 `LegacyBrandDefaults`와 서버 `legacyBrandDefaults`는
별도 호환성 상수다. 브랜드 생성기는 이 파일들을 생성하거나 수정하지 않는다.

| 데이터 상태 | 동작 |
| --- | --- |
| 새 수업/센터 또는 저장된 설정이 전혀 없음 | 현재 AppBrand 기본값 |
| 기존 설정 JSON의 `brandL` 누락/null | 과거 `CloudBoard` 기본값 |
| 기존 센터 JSON의 `storeName` 누락/null | 과거 `CloudBoard Studio` 기본값 |
| 과거 countdown-only 설정 | 기존 decoder와 브랜드 기본값 유지 |
| v2 워크아웃의 화면 렌더링 보조값 | 과거 브랜드 기본값 유지 |
| 이미 저장된 문자열(CloudBoard, 빈 문자열, 사용자가 편집한 이름 포함) | 그대로 읽고 저장 |
| v1 워크아웃 필수 `brandL` 누락 | 기존 필수 필드 검증 실패 유지 |

Freezed의 생성자 기본값과 JSON decoder의 기본값을 구분했다. 변경이 필요할 때에는
`dart run build_runner build --delete-conflicting-outputs`로 생성하며, `.g.dart`에 남은 과거
문자열을 현재 브랜드로 치환하면 안 된다. 실제 저장 데이터를 업데이트하는 마이그레이션은 없다.
센터별 `BrandTemplate`은 사용자 콘텐츠 모델이며 앱 자체의 `AppBrand`와 독립적이다.

## 유지하는 기술 계약과 CI

표시 설정에는 Dart 패키지명, 앱 ID, Firebase, 로그인 URL scheme, 서명, 구독 상품 ID,
MethodChannel, 알림 channel, `cloudboard://pair`, 로컬 저장 키를 넣을 수 없다.
macOS `PRODUCT_NAME`, Windows/Linux 실행 파일명과 내부 이름도 유지한다.

`config/brand-technical-contracts.json`은 기준 커밋 `7f8e2b3`의 22개 파일별 기술 계약을 검증한다.
Firebase 앱/프로젝트·클라이언트 ID, 네이티브 ID/서명 팀, 상품 ID, QR/채널/저장 키의
지정된 값이 바뀌면 CI에서 실패한다. 기술 계약을 바꿔야 하는 별도 작업에서는 이 기준값도
의도적으로 검토해야 하며, 브랜드 변경을 이유로 수정하면 안 된다.
STA-125 초안 저장소 통합에서는 기존 v1 키와 이전 경로를 유지하고 새 v2 메타데이터·자산
키를 이 계약에 추가했다. 이는 초안 이미지 분리 저장을 위한 변경이며 표시 브랜드와 무관하다.

CI는 생성물 불일치와 표시용 코드의 브랜드·문의 이메일·정책 URL 하드코딩을 검사한다.
생성 출력은 설정과 대조하고, DTO 생성 코드·테스트 fixture·과거 릴리즈 기록은 표시 코드와
구분한다. `config/brand-hardcoding-allowlist.json`에는 호환성 상수와 기존 플러그인 등록 ID만
파일·문자열·횟수·이유와 함께 예외로 등록했다. 현재 설정의 새 이름도 검사 대상이다.
저장소에서 CloudBoard 문자열을 모두 없애는 검사는 아니다.

## 디자인 자산과 후속 공개 전환 위치

이번 생성기는 아래 이미지나 색상·테마를 변경하지 않는다.

| 자산 | 원본/생성 위치 |
| --- | --- |
| Flutter 시작 화면 마크 | `lib/src/app/core/widgets/app_startup_screen.dart`의 `StartupMarkPainter` |
| 기존 아이콘 디자인 자료 | `docs/play-store/ko-KR/assets/branding/app-icon-draft.svg` |
| Android launcher | `tool/generate_android_launcher_test.dart` → `android/app/src/main/res/mipmap-*` |
| Native splash | `tool/generate_native_splash.sh`, `tool/generate_splash_assets_test.dart` → `assets/splash` 및 native 리소스 |
| iOS/macOS 아이콘 | 각 Runner의 `Assets.xcassets/AppIcon.appiconset` |
| Windows/Web 아이콘 | `windows/runner/resources/app_icon.ico`, `web/favicon.png`, `web/icons` |
| Android TV 배너 | `tool/android_tv/tv_banner.svg` 및 Android drawable 리소스 |
| 로그인 일러스트 | `assets/images/login_welcome.png`, `assets/images/README.md` |

실제 리브랜딩을 공개할 때에는 설정/자산뿐 아니라 App Store Connect·Google Play의 앱 표시명과
스크린샷, OAuth 동의 화면, 지원 이메일·정책 사이트 콘텐츠/URL, 인증 SMS 이름도 함께 검토한다.
배포/서명/Firebase/스토어 앱 등록을 새로 만들거나 기존 기술 ID를 바꾸는 작업은 포함하지 않는다.
외부 콘솔·스토어·정책 사이트·배포는 이번 작업에서 변경하지 않았다.

인증 SMS는 기존 `type: SMS`와 문구를 유지한다. 실제 한글 이름 교체 시에는 이름을 포함한
전체 인증 문구의 길이도 확인해야 한다. SOLAPI는 SMS를 90 byte로 제한하고 명시된 타입을
자동 전환하지 않으므로, 긴 이름에는 별도의 짧은 SMS 표기 또는 발송 타입 정책 검토가 필요하다.
임시 긴 이름 테스트는 출력/화면 검증이며 외부 SMS 발송을 검증하지 않는다.
([SOLAPI 메시지 규격](https://solapi.com/developers/api/messages),
후속 [STA-132](https://linear.app/clyrdev/issue/STA-132))

## 검증 범위

기존 브랜드의 UI/링크 회귀, 다른 영문·한글·긴 이름의 실제 위젯/데이터 테스트,
과거 문서 round-trip과 신규/누락 값 분리, 생성기 결정성·escaping·누락/중복 필드 실패를 검증한다.
플랫폼 출력의 특수문자 이름은 Swift, XML/plist, Android aapt2, C++/Windows 리소스 문자열의
각 구문에 맞게 검사한다. Windows/Linux 앱 전체 빌드는 해당 OS에서 별도 실행해야 한다.
실기기 사용성 검증은 사용자 요청대로 추후 진행한다.

2026-10-12 구현 검증 결과:

- Flutter 전체 710개, 임시 브랜드 위젯/데이터 63개, Functions 102개 테스트 통과.
- 최신 `develop`의 STA-113 통합 후 스타일 편집·홈·브랜드 데이터 관련 38개 테스트 추가 통과.
- 생성기/플랫폼 테스트와 13개 생성 출력·기술 계약 검사 통과.
- `dart format` 변경 없음, `flutter analyze` 문제 없음, 웹 release, Android debug APK,
  iOS simulator 전체 빌드(App Intents metadata 추출 포함) 통과.
- 기준 `7f8e2b3`과 동일한 Flutter 위젯 테스트 환경(390×844, 캡처 2배, 실제 폰트)에서
  로그인, 복구 로딩/오류, 온보딩 목적/전화, 홈 로딩/완료의 PNG 7개가 바이트까지 동일했다.
  이 결과는 해당 고정 화면의 시각 보존 검증이며 실기기 조작 검증을 대신하지 않는다.
- Android APK 표시명 `CloudBoard`와 기존 앱 ID를 확인했고, 별도 임시 리소스 APK에서
  한글·따옴표·백슬래시·퍼센트·이모지가 컴파일 후에도 원문 그대로임을 확인했다.
- macOS는 plist와 FlutterAppDelegate의 표시명 사용 경로만 확인했다. macOS/Windows/Linux
  전체 앱 빌드 및 실기기 검증은 실행하지 않았다.
