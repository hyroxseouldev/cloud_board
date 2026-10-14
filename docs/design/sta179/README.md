# STA-179 · 분·초 휠 입력

[이슈](https://linear.app/clyrdev/issue/STA-179)에서 확정한 [선택 시안](reference.png)을 기존 Flutter 타이머 편집 화면에 적용했습니다. 운동·휴식 요약 아래에서 선택한 시간 한 항목의 분/초 휠만 열립니다. 분 0–999, 초 0–59 범위이며 순환하거나 초 경계에서 분으로 자동 이월하지 않습니다.

기존 Oat Sage 색상, Pretendard, 편집기 카드/버튼을 재사용합니다. 중앙 선택 배경은 숫자 뒤에 그리며 콜론은 고정합니다. 큰 글자에서는 요약 버튼을 세로로 배치하고 각 휠 행 높이도 글자 배율에 맞춥니다. 좁거나 낮은 화면에서는 본문을 스크롤하며 하단 ‘타이머 반영’은 고정됩니다.

## 동작과 경계

- 사용자 지정 구간의 운동/휴식, AMRAP·시간제한 For Time의 시간, EMOM 간격, 공통/상세 라운드 휴식을 같은 휠로 편집합니다. 반복/라운드/구간 수는 기존 정수 입력을 유지합니다.
- 연속 운동 시간과 EMOM 간격은 기존 최소 1초를 유지합니다. 사용자 지정 운동 0초/휴식만 구간, 휴식 0초 및 전체 타이머 유효성은 기존 도메인 규칙을 유지합니다.
- 휠은 초 단위 타이머 초안만 갱신합니다. ‘타이머 반영’에서 슬라이드 초안으로 전달하고, 기존 ‘슬라이드 저장’에서 저장합니다. 닫기·변경 취소·저장 실패 처리와 로컬 연습 경계는 유지됩니다.
- 관성 스크롤 중 반영/항목 변경/방식 변경/로컬 연습 진입 시 현재 중앙 항목을 읽어 스크롤을 정지합니다. 반영과 연습은 최신 초안을 읽습니다. 선택 세션과 컨트롤러 위치 검사로 이전 휠의 지연 알림이 새 항목이나 반영된 값을 덮지 않게 합니다.
- 각 열의 접근성 노드는 대상 이름, 단위, 현재 값과 증가/감소 동작을 제공합니다. 요약도 접근성 탭으로 선택할 수 있습니다. 마우스 휠·마우스 드래그·터치와 화살표/Page Up/Down/Home/End 키를 지원합니다. 입력값 범위 끝에서 증감은 멈춥니다.

## 시각 검증

실제 production `TimerEditorScreen`과 저장소 fixture를 사용하는 `tool/sta179_capture_test.dart`에서 Pretendard 파일을 로드해 DPR 2로 캡처합니다. Firebase/TV/결제 서비스는 호출하지 않습니다.

[시안/구현 비교](comparison-reference.png)는 원본 시안을 가로 780px로 비례 축소하고 실제 390×844 화면의 DPR 2 캡처와 나란히 놓았습니다. [반응형 전체 보기](responsive-contact-sheet.jpg)에서도 8개 장면을 직접 확인했습니다. 중앙 숫자, 세이지 선택 배경, 고정 콜론과 Pretendard가 정상이며 별도 읽기 전용 리뷰에서도 추가 시각 차단 사항은 없었습니다.

| 캡처 | 논리 크기 / 글자 배율 | 상태 |
| --- | --- | --- |
| [phone-custom](implemented/phone-custom.png) | 390×844 / 1× | 초기 사용자 지정 화면 |
| [small-custom](implemented/small-custom.png) | 320×568 / 1× | 휠이 보이도록 본문 스크롤 후 |
| [large-text-custom](implemented/large-text-custom.png) | 320×844 / 2× | 휠이 보이도록 본문 스크롤 후 |
| [landscape-custom](implemented/landscape-custom.png) | 844×390 / 1× | 휠이 보이도록 본문 스크롤 후 |
| [tablet-custom](implemented/tablet-custom.png) | 834×1194 / 1× | 초기 사용자 지정 화면 |
| [desktop-custom](implemented/desktop-custom.png) | 1440×900 / 1× | 초기 사용자 지정 화면 |
| [phone-amrap](implemented/phone-amrap.png) | 390×844 / 1× | 초기 AMRAP 시간 입력 |
| [phone-emom](implemented/phone-emom.png) | 390×844 / 1× | 초기 EMOM 구간 시간 입력 |

시안과의 의도적 차이: 위/아래 버튼은 실제 48px 터치 영역을 유지하므로 phone 초기 화면의 두 번째 구간은 본문 스크롤 후 보입니다. 휠에는 표준 `CupertinoPicker`의 원근·가장자리 흐림이 적용됩니다. 편집 중 구간 제목의 시간 요약은 실제 초안과 항상 일치하며, 시안 이미지에 남은 이전 요약값(02:00/00:00)을 재현하지 않습니다. 기존 구간 메뉴·정수 횟수 입력·접근 가능한 라운드 설정을 보존했습니다.

실기기 iOS/Android 스크롤 감각, 실제 OS 화면 읽기 도구, 모바일 브라우저 IME/하드웨어 키보드 검수는 사용자가 후속 수행하기로 한 범위이며 이번 자동 검증의 결과로 주장하지 않습니다.

## 검증

Flutter 3.47.0 / Dart 3.13.0을 사용했습니다. 이 변경은 모델·저장 스키마·타이머 도메인 로직을 수정하지 않아 codegen은 필요하지 않습니다.

- 최종 VM: 기존 타이머 편집·흐름·모드·편집 도메인 48개와 신규 휠 15개를 함께 실행해 **63개 통과** (`/tmp/sta179-vm-final.log`).
- 최종 시각 보완 후 신규 휠 VM 회귀 **15개 + 8장 생성 캡처 테스트 1개 통과** (`/tmp/sta179-capture-final.log`).
- 최종 Chrome: 위 기존 48개와 신규 15개를 함께 실행해 **63개 통과** (`/tmp/sta179-chrome.log`). 마우스 스크롤/드래그, 연속 하드웨어 키, semantics 증감·선택, 분·초 끝값, 0초 휴식/1초 최소값, 관성 중 반영, 구간 전환/삭제된 휠의 지연 콜백, 큰 글자·낮은 뷰포트, 기존 저장·취소·실패 재시도를 포함합니다.
- `flutter analyze --no-pub`: **No issues found** (`/tmp/sta179-analyze-final.log`).
- 새 `timer_duration_wheel_test.dart`를 기존 Chrome CI 목록에도 등록했습니다. 전체 앱 테스트·빌드는 PR CI에서 수행합니다.

```sh
flutter pub get
flutter test --no-pub test/timer_duration_wheel_test.dart test/timer_editor_test.dart test/timer_editor_flow_test.dart test/timer_modes_test.dart test/timer_editing_test.dart
flutter test --no-pub tool/sta179_capture_test.dart test/timer_duration_wheel_test.dart
CHROME_EXECUTABLE='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' \
  flutter test --no-pub --platform chrome test/timer_duration_wheel_test.dart test/timer_editor_test.dart test/timer_editor_flow_test.dart test/timer_modes_test.dart test/timer_editing_test.dart
flutter analyze --no-pub
```

참조 원본: `/Users/sunmkim/orca/workspaces/cloud_board/goldfish/output/design/timer-input-2026-10-15/selected-wheel-picker.png`. [manifest.json](manifest.json)은 참조/캡처/구현 소스의 SHA-256과 화면 크기를 기록합니다. 비교 이미지는 QA용 합성이며 제품 자산을 수정하지 않습니다.
