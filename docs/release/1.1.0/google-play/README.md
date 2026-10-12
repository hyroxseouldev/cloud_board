# CloudBoard 1.1.0 · Google Play 준비 자료

[STA-143](https://linear.app/clyrdev/issue/STA-143)의 Android 소개·사진 준비 자료다. [STA-116](https://linear.app/clyrdev/issue/STA-116)의 대상·기능 설명과 [STA-119](https://linear.app/clyrdev/issue/STA-119)의 8장 구성을 사용한다. **현재 검토용이며, Play Console에 반영하거나 공개하지 않았다.** iOS 스토어 소개와 이미지는 이 폴더의 범위가 아니다.

## 원고와 이미지

| 자료 | 위치 | 상태 |
|---|---|---|
| 한국어 앱 이름·짧은 설명·자세한 설명 | `ko-KR/*.txt` | 실제 구현과 대조한 원고 |
| 1.1.0 변경사항 | `ko-KR/release-notes.txt` | 최종 출시 범위 대조 후 게시 |
| 8장 제목·설명·대체 텍스트 | [storyboard.json](storyboard.json) | 확정된 Soft Rhythm 방향 반영 |
| 원본 UI | `source-review/*.png` | Android 테마의 실제 Flutter 위젯과 가상 수업 데이터. 설치 APK 캡처가 아님 |
| 8장 검토 이미지·TV·소개 이미지 | [review/index.html](review/index.html) | 검토용, 실제 후보 캡처 교체 전 업로드 금지 |
| 한 장으로 보기 | [review/contact-sheet.png](review/contact-sheet.png) | 순서와 가독성 검토용 |

1~3장은 TV 제어 → 수업 구성 → 복제로 재사용을 설명한다. 4장은 자주색 배경으로 시간 구성을 강조한다. 6장(내 수업 연습)과 8장(가입 전 예시 체험)은 서로 다른 실제 흐름이다. 기종을 특정하는 목업, iPhone 외형, 고객 데이터, 미확인 가격·체험 기간·자동 연결 주장은 넣지 않는다. 앱 UI는 캡처를 그대로 사용하고 스토어 배경만 라벤더·따뜻한 밝은색으로 구성한다.

## 구현과 원고 대조

| 표현 | 구현 근거 | 최종 캡처에서 확인할 것 |
|---|---|---|
| TV 수업을 휴대폰에서 제어 | `workout_player_screen.dart`, `workout_control_panel.dart` | 동일한 후보 앱·TV가 같은 수업을 표시하고 실제 시작/일시정지/재개에 응답 |
| 운동 순서와 내용 구성 | `workout_editor_screen.dart`, `slide_editor_screen.dart` | 샘플 수업 편집 화면의 순서·이름·시간 |
| 저장 수업 복제 | `slide_library_screen.dart`, `workout_controller.dart` | 복제 메뉴와 별도 ID로 저장된 복사본. 원본 보존 |
| 운동·휴식·반복 | `timer_editor_fields.dart` | 인터벌 모드에서 세 입력과 결과가 일치 |
| 색·배경·배치 | `slide_editor_screen.dart`, `slide_appearance_controls.dart` | 스타일 변경이 실제 결과에 반영 |
| 이 기기에서 연습 | `workout_rehearsal_screen.dart` | 내 수업 재생, 원격 세션 미생성 |
| 폴더·검색 | `slide_library_screen.dart` | 실제 저장 자료에 대한 폴더 분류·검색 결과 |
| 가입 전 예시 | `explore_screen.dart`, `exploration_routes.dart` | 로그아웃 상태에서 예시 선택·재생 |
| 브랜드·문의 | `config/brand.json` | CloudBoard / 클라우드보드, `vividxxxxx@gmail.com` |

공개 설명은 지원 기기를 Android TV로 제한하되 **모든 Android TV에서 설치 가능하다고 약속하지 않는다.** Apple TV, AirPlay, 무설치 송출은 설명하지 않는다. 실제 TV 수업의 계정·이용 조건은 앱 안내로 연결하고 미확인 가격이나 체험 기간을 적지 않았다. 원고에서 “수업”은 앱의 “워크아웃”, 수업 안의 개별 화면은 “슬라이드”를 뜻한다.

## Google Play 규격 확인

확인일: 2026-10-12. [Google Play 미리보기 에셋 공식 안내](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en)에 따라 휴대폰은 최대 8장, **1080×1920**, 소개 이미지는 **1024×500**, TV 배너는 **1280×720**로 출력한다. 모두 불투명 RGB PNG다. Android TV용 실제 스크린샷이 최소 1장 필요하다. 이 팩은 **1920×1080**을 사용한다. 제목·설명은 상단 20% 이내에 두고 UI 비율을 유지한다. 태블릿 제출 항목은 별도 실제 태블릿 캡처가 필요하며 휴대폰 이미지를 늘려 채우지 않는다.

[스토어 등록정보 공식 안내](https://support.google.com/googleplay/android-developer/answer/9859152?hl=en)의 앱 이름 30자, 짧은 설명 80자, 자세한 설명 4,000자 제한을 출력 때 검사한다. 순위·가격·설치 유도 문구는 추가하지 않았다. 최종 입력은 Console의 현재 제한도 대조한다.

## 재생성과 실제 후보 캡처 교체

저장소의 Flutter SDK와 기존 Node 도구(Playwright, sharp)를 사용한다. 앱 런타임 의존성이나 UI는 변경하지 않는다.

```sh
# 검토용 UI 캡처. 로컬 샘플만 사용한다.
CAPTURE_SOURCE_SHA=$(git rev-parse HEAD) .fvm/flutter_sdk/bin/flutter test --no-pub tool/release_store_capture_test.dart
# 기존 도구 환경에 playwright, sharp가 설치되어 있으면 바로 실행한다.
node tool/render_release_play_assets.cjs
```

도구가 별도 폴더에 설치돼 있으면 그 `node_modules`를 `NODE_PATH`로 지정한다. 실물 후보에서는 아래 순서로 캡처한다.

1. 검수할 production 1.1.0 APK/AAB의 소스 SHA·versionCode·서명·Firebase 프로젝트와 파일 SHA-256을 출시 원장에서 확정한다.
2. 검수 계정의 가상 수업으로 [storyboard.json](storyboard.json)의 8개 상태를 실행한다. 1장은 휴대폰과 Android TV에 동일한 수업이 표시된 상태를 각각 저장한다. 모든 이미지에 개인 정보·알림·개발 디버그 배너가 없어야 한다.
3. `source-native/`에 원본과 `capture-manifest.json`을 보관한다. 각 파일의 SHA-256, 기기·OS, 촬영 시간, 후보 버전·빌드, 화면 경로와 검사자를 기록한다. `native-capture-manifest.example.json`은 빈칸을 채우기 전 사용 불가다.
4. `node tool/render_release_play_assets.cjs --native-manifest=docs/release/1.1.0/google-play/source-native/capture-manifest.json`을 실행한다. 원본별 빌드·SHA·해시와 실제 TV 구분이 없으면 생성이 실패한다. `ready/`라는 출력 폴더명은 **제출 승인이나 실제 공개 완료를 뜻하지 않는다.**
5. 8장의 UI·자막·잘림·글꼴, 1장의 동일 수업, 원고·이용 조건을 마지막으로 대조한다. 검수한 후보 바이너리가 바뀌면 화면과 manifest도 다시 확인한다.

## 남은 출시 검수

- [ ] 최종 production 1.1.0 설치본의 Android 휴대폰 8개 상태와 Android TV 화면으로 원본 교체
- [ ] 복제본 저장과 TV 원격 명령 실제 동작 확인
- [ ] 필요한 태블릿 제출 항목과 TV 배포 대상 확인
- [ ] 공개 중인 브랜드·문의·가격·지원 환경 사실표(STA-114)와 원고 대조
- [ ] 동일 후보로 기존 설치본 업데이트와 구·신형 앱/TV 조합 검수
- [ ] Play Console의 한국어 소개·이미지 순서 반영, 심사·공개 시점 관리
- [ ] 실제 공개 페이지에서 순서·잘림·설치 가능 여부 확인 후 링크·확인일 기록

마지막 두 항목을 완료하기 전에는 “Google Play 업데이트 완료”로 기록하지 않는다. 검토용 위젯 캡처에는 설치 빌드, 실제 페어링·계정 인증·업데이트 보존을 검증하는 효력이 없다.
