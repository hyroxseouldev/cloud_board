# STA-168 · 재생 슬라이더 진행률

사용자 사진의 `0:11 / 3:00`에서 전체 운동 구간이 진하게 보이던 원인을
`WorkoutIntervalSliderTrack`에서 수정했다. 이전 painter는 현재 interval 전체를
강조했다. 새 painter는 Flutter Slider가 전달한 실제 `thumbCenter`를 기준으로
지난 영역과 남은 영역을 나눈다.

## 표현과 범위

- 지난 시간: `AppColors.accent` (`#526B60`), 남은 시간: `AppColors.selected`
  (`#E3EAE2`). 비활성 지난 시간은 `AppColors.muted`로 구분을 유지한다.
- 운동·휴식 경계는 1 logical px 표시로 보존한다. 좁은 구간은 최소 4 logical px 간격으로
  표시해 경계선이 면을 덮지 않도록 한다. 현재 세트·운동/휴식·남은 시간 문구는 유지한다.
- 11/180초 = 6.111…%. 시각 범위는 전체 180초이고, 사용자 탐색 명령은 기존처럼
  마지막 재생 가능한 179초까지다. 재생으로 도달한 180초는 100%로 표시한다.
- 손잡이·기존 40px Slider 높이·터치·기본 키보드 포커스·접근성 구조는 Slider가 담당한다.
  예상 접근성 이동 값도 실제 탐색 한도로 제한한다.
- 로컬/원격 `WorkoutPlayerScreen`은 공통 `WorkoutControlTimeline`을 사용한다.
  별도 `SlideRehearsalScreen`의 기본 Slider는 원래 전체 duration 기준으로 분리되므로
  동작·디자인을 변경하지 않았다.
- 계정, 저장 데이터, TV 재생 프로토콜, seek 명령 계약은 변경하지 않았다.

## 상태 의미

재생·일시정지에서는 확인된 elapsed 위치를 표시한다. 드래그 중에는 후보 위치와
시간 문구를 표시하고, 놓으면 한 번 탐색한다. 대기 중 입력은 기존대로 막힌다.
후보는 해제되며 부모의 확인된/낙관적 재생 위치를 따르고, 실패 시 기존 컨트롤러의
롤백 위치를 그린다. 취소된 드래그는 명령을 보내지 않는다. RTL에서는 지난 영역이
오른쪽에서 시작한다. 길이 0은 0/0과 비활성 상태를 유지한다.

## 검증 증거

2026-10-14 · Flutter 3.47.0 / Dart 3.13 · 자동 검증 완료.

| 검증 | 결과 |
| --- | --- |
| VM: paint/interaction/timeline/control/pilot/rehearsal 6개 파일 | 62/62 통과 |
| Chrome: actual paint + touch/keyboard/semantics | 32/32 통과 |
| 변경 Dart 파일 6개 analyze | No issues found |
| production 캡처: before/after 각 9개 상태 | 각 1/1 capture test 통과 |

실제 Slider를 rasterize한 25개 painter 테스트는 양방향의 0/11÷180/50/100%,
활성·비활성·색 전환, 운동/휴식 경계, 역방향 이동, 빈 interval/길이 0을 검사한다.
손잡이를 투명하게 그리되 실제 크기는 유지해 thumb 뒤에 가려지는 경계 픽셀까지
검사한다. 터치 후보·확정·취소·대기 중 중복 차단, 원격 실패 롤백, 키보드 좌우 이동,
접근성 시간, 320px 2배 글자도 검증했다. 실제 PlayerController에 clock을 주입한
회귀는 재생 11초 → 드래그 90초 → 91초 계속 재생 때 UI 시간과 remainingMs의
일치를 확인한다.

- [11초 전체 화면 전후](comparison-phone-11s.png)
- [0%, 6.1%, 50%, 100% 상세 비교](comparison-progress.png)
- [구간 경계·비활성 비교](comparison-intervals.png)
- [작은 화면 2배 글자·태블릿·데스크톱](comparison-responsive.png)
- [PNG 크기·SHA-256 및 캡처 소스 해시](capture-manifest.json)

네 비교 이미지를 직접 열어 확인했다. 진한 면이 손잡이를 넘어서 남은 구간까지
채우지 않으며, 구간 경계는 진행률보다 약하게 보인다. 320px 2배 글자에서도
elapsed/total/remaining과 손잡이가 보인다. 이번 범위의 시각 P0/P1/P2 미해결 없음.

재현 명령(프로젝트 루트):

```sh
flutter test --no-pub test/workout_interval_slider_paint_test.dart test/workout_slider_interaction_test.dart test/workout_timeline_seek_test.dart test/workout_control_panel_test.dart test/pilot_playback_regression_test.dart test/slide_rehearsal_redesign_test.dart
flutter test --no-pub --platform chrome test/workout_interval_slider_paint_test.dart test/workout_slider_interaction_test.dart
flutter test --no-pub tool/sta168_capture_test.dart
```

before는 `/tmp/sta168-baseline`에 `git archive 38a2f60`으로 추출한 소스에서
동일 도구를 `--dart-define=STA168_PHASE=before`로 실행했다. 전후 PNG에는 합성한
진행 막대가 없다. comparison 파일만 원본 PNG의 축소/크롭을 나란히 배치했다.

원본 사용자 사진 `/tmp/sta168-reference.jpg`는 읽기 전용 참고다. 저장소 before 캡처는
동일 `tool/sta168_capture_test.dart`를 develop `38a2f60`의 lib/assets/pubspec으로
격리 실행한 결과다. after는 이 변경의 실제 production widget이다. DPR 2, Pretendard,
로컬 fixture를 사용하며 실제 TV나 서버 명령은 발생하지 않는다.

실기기·실제 TV 동기화 검수는 사용자의 요청대로 후속이다. Flutter widget/raster 및
브라우저 자동 검증을 실기기 완료로 표현하지 않는다.
