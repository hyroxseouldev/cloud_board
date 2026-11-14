# 수업 준비 페이지 shadcn_ui 적용 — 2026-11-14

- 기준: `origin/develop` `1780837ad1d7a69c7a2ecd73dcfa9be108f62872` (PR #185 병합).
- 구현·페이지 테스트 소스: `7198e61affb11fccea4f66394fe9e01ade05c3dd`; 이후 fixture 시계와 이 증거 문서만 추가. 최종 인계 SHA는 PR에 기록한다.
- 브랜치: `hyroxseouldev/shadcn-preparation-page`; 버전 `2.2.0+12` 유지.
- 작업 위치: `/Users/sunmkim/orca/workspaces/cloudboardapp/compact-preflight`. 원래 dirty 앱 checkout은 수정하지 않았다.

## 범위와 UI

사용자의 최종 패키지 지정에 따라 **shadcn_ui 0.59.0**을 정확히 고정했다. shadcn_flutter는 pubspec/lock에 없다. 공식 [pub 패키지](https://pub.dev/packages/shadcn_ui)와 [API](https://pub.dev/api/packages/shadcn_ui), 설치 소스를 확인했다. 최소 SDK는 Dart 3.11 / Flutter 3.41이며 지정 Flutter 3.47.8에서 아래 검증을 통과했다.

준비 페이지와 전용 `preparation_shadcn.dart` 안에서 실제 ShadCard, ShadButton, ShadCheckbox, ShadBadge, ShadAccordion, ShadProgress를 사용한다. 기존 sage/cream 색과 Pretendard를 유지하고 요약, 재생 대상/TV 선택, 상태, 넓은 본문 시작 버튼, 수업 구성 순서로 정돈했다. 시작 옆 취소 버튼을 제거하고 상단 뒤로는 유지했다. 고정 footer는 추가하지 않았다.

ShadTheme + ShadAppBuilder + Shad localization은 페이지 하위에만 설치한다. 전역 ShadApp, MaterialApp 교체, Navigator 추가, 전역 theme/router 변경은 없다. 위젯 검사에서 바깥 Scaffold는 ShadTheme를 받지 않고 페이지는 지정 테마를 받으며, 같은 ambient Material Theme와 단일 Navigator가 유지되고 뒤로 이동 시 국소 scope가 사라짐을 확인했다.

기존 draft/applied, 선택 적용 batch, 권한/한도/admission, proof/fingerprint/expiry/exact targets, remote 이미지 0 GET, 명시 solo, start guard는 변경하지 않았다. player/home/display/server는 미수정이다. 서버 저장/실제 callable 변경도 없다. 이미지 보기는 기존 승인과 명시 클릭 조건을 그대로 따른다.

## 의존성

직접 의존성 1개와 전이 의존성 19개가 추가됐으며 기존 패키지 버전 변경/제거는 0개다. 전체 정확한 이름·버전은 [dependency-diff.json](shadcn-preparation-evidence/dependency-diff.json), 공식 API 확인값은 [package-api.json](shadcn-preparation-evidence/package-api.json)에 있다. 무관한 package upgrade는 하지 않았다.

## 검증

SDK: `/Users/sunmkim/fvm/versions/3.47.8/bin/flutter`.

- `flutter test --no-pub test/workout_preflight_dialog_test.dart`: **36개 통과**. 기존 검사는 위젯 종류 변경에 맞춰 finder만 수정했고 skip/삭제하지 않았다. 원격 cold loader/HTTP 0, 명시 solo 양성·실패 gate, late callback, TV 준비/권한/한도/admission, draft 무전송/적용 1회, 320·390 확대 글자 오류와 CTA 접근 검사를 재사용했다. 페이지 국소 shadcn scope 검사를 추가했다. [로그](shadcn-preparation-evidence/page-tests.log)
- `flutter analyze --no-pub lib/src/app/feature/workouts/presentation/widgets/workout_preparation_page.dart lib/src/app/feature/workouts/presentation/widgets/preparation_shadcn.dart test/workout_preflight_dialog_test.dart`: **문제 없음**. [로그](shadcn-preparation-evidence/analyze.log)
- `flutter analyze --no-pub tool/fixtures/compact_preflight.dart`: **문제 없음**. [로그](shadcn-preparation-evidence/fixture-analyze.log)
- `flutter build web --no-pub --target tool/fixtures/compact_preflight.dart --output build/shadcn-ui-web --no-wasm-dry-run`: **성공**, 실제 Flutter fixture. [로그](shadcn-preparation-evidence/fixture-build.log)

마지막 fixture 변경은 정적 가상 TV가 heartbeat를 보내지 않아 오래 열린 리뷰 탭에서 offline으로 바뀌는 것을 막기 위한 fixture 전용 health clock 고정이다. 운영 freshness/expiry 로직은 바꾸지 않았다. 최종 fixture analyze/build에 반영됐으며 앱 소스가 동일하므로 페이지 36개 결과를 재사용한다.

로컬 HTTP 서버의 이미지 경계 기록은 원격 ready/waiting/error/empty/permission 및 320 오류 확인 동안 **본문 GET 0건**([remote-http.json](shadcn-preparation-evidence/remote-http.json))이다. 명시적으로 이 기기에서 재생 → 선택 적용을 누른 뒤 동일 경계에서 **3건**을 확인했다([solo-http.json](shadcn-preparation-evidence/solo-http.json)). 이는 mock loader 횟수와 별도로 실제 localhost 요청을 기록한 것이며 운영 네트워크/실물 TV의 0건 보장을 실측했다고 주장하지 않는다. fixture providers/metadata를 사용했으며 운영 로그인·실제 사용자 API 호출은 하지 않았다.

## 실제 Flutter 캡처

Orca 내부 브라우저, 390×844; 좁은 오류는 320×568 / 글자 배율 2. before는 기준 구현의 기존 실제 Flutter fixture 캡처를 재사용했다.

- [before 390](shadcn-preparation-evidence/before-390.png)
- [ready 390](shadcn-preparation-evidence/ready-390.png), [root review 390](shadcn-preparation-evidence/root-review-390.png)
- [waiting 390](shadcn-preparation-evidence/waiting-390.png), [error 390](shadcn-preparation-evidence/error-390.png)
- [empty 390](shadcn-preparation-evidence/empty-390.png), [permission 390](shadcn-preparation-evidence/permission-390.png)
- [explicit solo 390](shadcn-preparation-evidence/solo-390.png)
- [320 / 2배 글자 오류](shadcn-preparation-evidence/error-320-scale2.png), [스크롤 후 CTA](shadcn-preparation-evidence/error-320-scale2-cta.png)

리뷰 URL: `http://127.0.0.1:8799/?scene=ready` (waiting/error/empty/permission/solo scene 지원). 원래 8796 및 기존 리뷰 서버는 유지했다. root 탭 reload 후 viewport가 desktop으로 초기화된 상황은 390으로 복원했고 요청된 빈 화면은 재현되지 않았다. 실물 iPhone/TV 검증은 미확인, 전체 앱/전 플랫폼 빌드·player 재검사는 미실행이다. PR 병합·배포·archive·TestFlight 업로드는 하지 않았으며 root 통합과 별도 iOS 담당의 후속 작업이다.
