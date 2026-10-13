# STA-162 검증 결과

2026-10-13, FVM Flutter 3.47.0, develop `322d985` 기반.

| 검사 | 결과 |
| --- | --- |
| `flutter analyze --no-pub` | 오류/경고 없음 |
| `flutter test --no-pub --reporter expanded` | 925/925 통과 |
| Chrome: `slide_design_asset_reuse_test.dart`, `general_slide_defaults_test.dart` | 15/15 통과 |
| `flutter build web --release --no-pub --dart-define=FIREBASE_ENV=development` | 성공, Wasm dry run 성공 |
| 변경 전·후 캡처 / 선택·편집·PNG·HD·4K 경로 | 전후 각 21 PNG, 추가 16 PNG; 캡처 테스트 통과 |
| `dart format --output=none --set-exit-if-changed lib test` / `git diff --check` | 통과 |

전체 회귀에는 레이아웃·일반 카탈로그·원본 StationD 6종·Brick·AI·샘플 가져오기·타이머·라이브러리·복구·저장 경로가 포함된다. 새 저장 검증은 실제 painter의 PNG와 업로드 입력을 대조하며, v1 fingerprint 재사용 거절, 재저장/복제/라이브러리 삽입, 다음 저장의 PNG 재사용, 실패 시 원본 데이터/서버 revision/캐시 보존을 확인한다. 원격 저장은 테스트 대역을 사용했으며 실제 계정 데이터를 수정하지 않았다.

대표 스타터의 본문은 112→92px, 제목100→84px, 번호87.36→69.92px다. 타이머 위치/크기는 동일하다. 24행 단일열은 16→18px로 여전히 가독성 경고가 나며, 두 열에서는36px로 표시된다. 긴 혼합6행은66→76px로, 이미 작은 글자를 다시 비율 축소하지 않는다. 전체 실제 크기는 [측정표](metrics-comparison.md)를 참고한다.

실기기와 센터 TV 시청 거리 검수는 사용자 요청에 따라 이후에 진행한다. PNG 대체 재생에서 확인한 기존 자동 타이머 색상 문제는 [STA-163](https://linear.app/clyrdev/issue/STA-163)으로 분리했다. 이 제한을 포함한 구버전 적용 정책은 [rollout.md](rollout.md)에 기록했다.
