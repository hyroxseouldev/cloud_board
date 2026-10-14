# STA-177 — 슬라이드 편집 하단 탭

[Linear STA-177](https://linear.app/clyrdev/issue/STA-177)의 최신 내용과 [첨부 화면](reference.png)을 확인하고 v5 Oat Sage의 기존 색상·폰트·탭 컴포넌트를 유지했다.

## 변경

- 타이머·배경·소리·라이브러리 탭을 모든 반응형 분기가 공유하는 본문 마지막 영역으로 이동했다. 설정과 라이브러리 목록을 스크롤해도 탭은 화면 하단에 고정된다. 가로 화면은 미리보기/설정 2열 아래에 전폭 탭을 둔다.
- 본문의 중복 연습 버튼, 바로 아래 로컬 재생 설명과 여백을 제거했다. 상단 재생 아이콘의 tooltip/접근성 tooltip은 **이 기기에서 연습**으로 명확히 했다. 실제 연습 화면의 로컬 전용 안내·뒤로 가기·TV 명령을 만들지 않는 동작은 유지했다.
- 키보드가 열리면 탭은 키보드 위에 남고 미리보기/본문 제목은 숨겨 입력 공간을 확보한다. Scaffold가 body의 keyboard inset을 제거하기 전에 상태를 읽어 상단 제목과 본문이 같은 기준을 사용한다.
- 복구/오류 안내가 긴 경우 본문 높이의 30% 안에서 안내를 스크롤할 수 있다. 작은 높이에서도 설정과 탭 공간을 남긴다. 탭의 기존 SafeArea를 한 번 적용하며 큰 글자의 가변 높이를 유지한다.

## 시각 비교

동일한 실제 `SlideEditorScreen` + 로컬 저장소 fixture를 변경 전 커밋 `73da574c54f3dad503a236c7053af3777934c062`와 변경 후에 각각 렌더링했다. Pretendard Regular/Medium/SemiBold/Bold 및 MaterialIcons를 직접 로드했고 DPR 2로 PNG를 출력했다. 캡처는 편집 화면 자체를 home으로 띄우며 실제 route의 뒤로 가기 동작은 별도 위젯 회귀에서 검증한다.

| 화면 | 논리 크기 / 글자 배율 | 변경 전 | 변경 후 |
| --- | --- | --- | --- |
| 휴대폰 | 390×844 / 1× | [before](before/phone.png) | [after](after/phone.png) |
| 작은 휴대폰 | 320×568 / 1× | [before](before/small.png) | [after](after/small.png) |
| 큰 글자 | 320×844 / 2× | [before](before/large-text.png) | [after](after/large-text.png) |
| 가로 | 844×390 / 1× | [before](before/landscape.png) | [after](after/landscape.png) |
| 태블릿 | 834×1194 / 1× | [before](before/tablet.png) | [after](after/tablet.png) |
| 데스크톱 | 1440×900 / 1× | [before](before/desktop.png) | [after](after/desktop.png) |
| 키보드 | 390×844 / 1×, inset 300 | [before](before/keyboard.png) | [after](after/keyboard.png) |

나란히 비교: [휴대폰](comparison-phone.png) · [가로](comparison-landscape.png) · [큰 글자](comparison-large-text.png) · [키보드](comparison-keyboard.png). 원본 크기와 SHA-256은 [manifest.json](manifest.json)에 기록했다.

키보드 캡처 아래의 빈 영역은 주입한 OS 키보드 공간이다. 실제 OS 키보드 이미지를 합성하지 않았다. 배경 탭 선택, 입력 필드 hit-test와 실제 focus, 키보드 높이, 수정 후 제목 1개/미리보기 숨김/탭 위치를 캡처 fixture에서 확인한다.

직접 시각 검토한 결과 기본 화면은 미리보기 → 설정 → 하단 탭 순서이며 중복 버튼의 빈 영역이 남지 않는다. 가로 화면은 양쪽 본문 아래 전폭 탭이 보인다. 2×에서 ‘라이브러리’는 기존 탭 컴포넌트처럼 두 줄로 표시되며 라벨 잘림/RenderFlex overflow 없이 터치 영역을 유지한다. 키보드 화면의 중복 제목과 미리보기가 사라지고 입력 필드 공간이 넓어졌다. 별도 읽기 전용 코드 리뷰에서도 추가 P0/P1/P2 발견은 없었다.

## 검증

새 `slide_editor_bottom_tabs_test.dart` 14개 회귀:

- 320×568(1×/2×), 390×844, 844×390(1×/2×), 834×1194, 1440×900: 탭 1개, 전폭, 하단 좌표, bottom SafeArea 34, 48px 이상 터치, 설정/라이브러리 스크롤 및 탭 전환 후 위치 불변.
- 320×568(1×/2×), 390×844: 실제 입력 → keyboard inset 300 → 동일 FocusNode/선택 범위/텍스트 유지, 제목 중복 없음, 미리보기 숨김, 탭 접근, 같은 탭 재선택과 다른 탭 전환, draft 유지.
- 320×568 2×+keyboard, 844×390: 복구와 저장소 오류가 함께 있어도 설정/라이브러리 높이와 탭 접근 유지, 긴 안내 스크롤 가능.
- 상단 연습 접근성 tooltip, 저장 전 초안으로 로컬 연습/복귀, TV/수업 명령 provider 미생성.
- 저장 실패 후 초안 유지·재시도, 저장 중 탭/뒤로 가기 차단, 저장 성공 후 이탈, 미저장 이탈 확인.

키보드 resize 직후 포커스/선택 범위 검증은 VM과 Chrome에 동일하게 적용한다. 현재 탭을 다시 클릭하는 경우는 Flutter `EditableText.onTapOutside`의 기존 플랫폼 규칙을 검증한다. native touch는 입력 포커스를 유지하고 웹은 필드 바깥 클릭으로 해제한다. 이 차이를 바꾸는 제품 코드는 추가하지 않았다.

최종 명령과 결과는 아래와 같다. 새 테스트를 기존 Chrome CI 목록에도 추가했다.

```sh
flutter test --no-pub test/slide_editor_bottom_tabs_test.dart test/slide_editor_tabs_test.dart test/slide_editor_features_test.dart test/slide_rehearsal_redesign_test.dart
flutter test --no-pub --platform chrome test/slide_editor_bottom_tabs_test.dart test/slide_editor_tabs_test.dart test/slide_editor_features_test.dart test/slide_rehearsal_redesign_test.dart
flutter test --no-pub tool/sta177_capture_test.dart
flutter analyze
```

- VM: 34/34 통과, 최종 플랫폼 기대 정리 후 신규 14개 재실행도 통과.
- Chrome: 34/34 통과.
- 캡처: before/after 각 1개 fixture 통과, 각각 7개 PNG.
- Analyze: No issues found.

실기기 관찰은 사용자의 요청에 따라 후속이다. 이 기록은 Flutter VM 렌더링/Chrome 자동 회귀 결과이며 iOS·Android 실제 키보드, VoiceOver/TalkBack 수동 검수 또는 TV 실물 검증을 주장하지 않는다.
