# STA-162 일반 템플릿 타이포그래피 검수

2026-10-13. 사용자 제보는 새 시안이 아니라 기존 스타터 WARM UP의 과도한 글자 크기·굵기·기울임에 대한 보고다. 관리 화면 글씨나 타이머 숫자를 줄이는 작업과 구분한다.

[검증 결과](validation.md): Flutter 925개·Chrome 15개 통과, 정적 분석 및 웹 릴리스 빌드 성공. [대표 전후 비교](interval-warmup-comparison.jpg), [12종 비교](catalog-comparison.jpg), [예시 9장 비교](starters-comparison.jpg), [실제 크기 측정표](metrics-comparison.md), [역할별 정책](typography-policy.md).

## 기준과 재현

변경 전 기준은 `322d985dfc22f5c4a8a1d9fe879fc3c18560b6d9`, 렌더러 버전 1이다. production 수정 전 전용 Flutter 슬롯에서 12개 일반 카탈로그와 3개 스타터 수업의 9개 슬라이드를 모두 캡처했다. [before/manifest.json](before/manifest.json)에 기준 소스 SHA와 화면 크기를 기록했고 이 폴더는 이후 덮어쓰지 않는다.

- [일반 12종 변경 전](catalog-before-contact.jpg)
- [스타터 9개 변경 전](starters-before-contact.jpg)
- [사용자 제보에 대응하는 인터벌 WARM UP 원본](before/interval-starter_warmup.png)

## 변경 후 결과

- [대표 WARM UP 큰 전후 비교](interval-warmup-comparison.jpg)
- [일반 12종 전후 비교](catalog-comparison.jpg) · [변경 후 모아보기](catalog-after-contact.jpg)
- [스타터 9개 전후 비교](starters-comparison.jpg) · [변경 후 모아보기](starters-after-contact.jpg)
- [역할별 21개 크기·긴 내용·보존 측정표](metrics-comparison.md)

대표 새 웜업의 본문은 112→92px, 제목은 100→84px, 번호는 87.36→69.92px다. 본문은 900 기울임에서 700 일반체로 바뀌고 샘플 안내가 이미지에서 빠졌다. 본문 행 사이 여백은 103.8→40px로 줄어 운동 목록이 한 덩어리로 읽힌다. 타이머/세트는 기존과 같은 위치·크기를 유지한다. 카탈로그 12종의 색상과 고딕/명조 서체·모티프는 보존했다.

모든 본문을 고정 배율로 줄이지 않는다. 원래 내용에 맞추느라 90px였던 editorial은 92px, cream-classic은 92px 그대로다. 긴 혼합 6행은 고정된 이전 입력으로 66→76px, 24행 단일열은 16→18px이며 작은 글씨 경고를 유지한다. [동일 24행의 2열 결과](paths/24-rows-columns.png)는 36px로 경고가 없다. 이는 짧은 fixture 문장에 대한 결과이며 모든 24행 문장이 읽힌다는 보장은 아니다.

변경 전 21장, 변경 후 21장, 추가 경로 16장의 원본 PNG를 보관한다. 21개 after+경로 캡처 테스트 2/2 및 선택 화면 스크롤 보정 후 경로 재실행 1/1을 통과했다. 두 Dart harness의 정적 분석도 오류가 없다. `tool/sta162_metrics.py`는 21개 입력의 내용/시간/색상/타이머 영역 불변과 기존 저장 웜업의 명시적 스타일 보존을 별도로 확인한다.

전체 화면은 실제 `WorkoutSlidePreview` → `WorkoutSlideCanvas`와 타이머/세트 표시를 사용한 1920×1080, DPR 1의 PNG다. 앱 제공 기본 수업 시간으로 정지시켰으므로 제보 이미지의 데모 `0:08 · 2/2세트`와 달리 웜업은 `3:00 · 1/1세트`다. 내용과 타이포그래피 비교를 위한 재현이며 제보 이미지 자체를 수정하지 않았다.

```sh
# 기준 checkout에서 최초 1회만; 이미 생성한 before 증거는 덮어쓰기 방지
flutter test --no-pub --dart-define=STA162_PHASE=before tool/sta162_capture_test.dart

# 구현 완료 후 동일한 21개 생산 경로 및 추가 UI/해상도 증빙
flutter test --no-pub --dart-define=STA162_PHASE=after tool/sta162_capture_test.dart
flutter test --no-pub tool/sta162_paths_capture_test.dart

# Pillow가 설치된 Python; 원본 PNG를 수정하지 않고 썸네일 JPEG만 합성
python3 tool/sta162_contact_sheets.py
python3 tool/sta162_metrics.py
```

`modules.json`은 당시의 실제 입력 전체, `metrics.json`은 실제 렌더러 측정값이다. 비교표의 본문 크기는 `textRuns.role == body`에 해당하는 최소/최대값이다. 전체 `minFontSize`는 헤더 라벨과 보조 정보까지 포함하므로 본문 크기로 해석하지 않는다. 변경 후 `frozen-input-metrics.json`은 **변경 전 입력을 그대로** 새 렌더러로 측정하여 새 기본값 변경과 기존 데이터의 표시 변경을 구분한다.

## 선택·편집·저장·재생 경로

| 경로 | 실제 위젯/산출물 | 검수 |
| --- | --- | --- |
| 선택 카드 | [태블릿 카탈로그](paths/catalog-selection-tablet.png) | 실제 AiSlideDesignStudio의 일반 12종 선택 카드. 밝은 번호 보드 선택 상태. |
| 휴대폰 편집 | [웜업](paths/interval-warmup-editor-phone.png), [카탈로그](paths/catalog-banner-editor-phone.png) | 390×844 논리 px, DPR 2. 실제 SlideEditorScreen, 잘림/overflow 없음. |
| 태블릿 편집 | [웜업](paths/interval-warmup-editor-tablet.png), [카탈로그](paths/catalog-banner-editor-tablet.png) | 834×1194 논리 px, DPR 2. 동일 모듈의 실제 편집 미리보기. |
| 저장 이미지 | [웜업 PNG](paths/interval-warmup-saved-artwork.png), [카탈로그 PNG](paths/catalog-banner-saved-artwork.png) | prepareSlideDesign의 실제 1920×1080 출력. 타이머는 플레이어가 겹쳐 그리므로 PNG에 굽지 않는다. |
| 지원 디자인 재생 | [웜업 1080p](paths/interval-warmup-canvas-1080p.png), [4K](paths/interval-warmup-canvas-4k.png), [카탈로그 4K](paths/catalog-banner-canvas-4k.png) | 실제 WorkoutSlidePreview/Canvas. 3840×2160에서도 동일한 설계 좌표와 비율. |
| 기존 사용자 입력 | [이전 웜업을 그대로 재렌더링](paths/existing-user-warmup-preserved-style.png) | 900·기울임·저장 부제를 유지하며 공통 크기 정책만 적용. |
| PNG 호환 경로 | [웜업](paths/interval-warmup-saved-png-fallback.png), [카탈로그](paths/catalog-banner-saved-png-fallback.png) | 아래 제한과 함께 해석. |

[paths/evidence.json](paths/evidence.json)에 실제 fingerprint·PNG 크기·타이머 좌표 보존과 추가 입력 메트릭을 기록했다. [픽셀 비교](paths/pixel-comparison.json)는 1080p 직접 Canvas와 PNG fallback을 원본 RGB로 비교한다. 카탈로그는 모든 픽셀이 같다. 웜업도 타이머 영역 `[1438, 366, 1787, 714]` 바깥의 본문·번호·배경·세트 표시가 모두 같다.

**PNG-only 시뮬레이션의 알려진 제한:** 현재 harness는 저장 이미지에서 디자인 계약을 제거하여 이미지 경로를 강제한다. 이때 기존 `slideColor`는 지원 디자인으로 판단하지 않아 자동 타이머 색을 흰색으로 선택한다. 흰 배경의 웜업 fallback에서는 타이머 숫자와 링이 보이지 않는다. 색을 fixture에서 덮어쓰지 않고 그대로 증거를 남겼다. 이는 새 타이포그래피 또는 PNG의 글자 배치 변경과 구분되는 기존 호환 경로의 제한이며, 실제 과거 바이너리마다의 동작을 이번 캡처만으로 단정하지 않는다. 최신 지원 디자인 경로의 타이머 색/위치/크기는 보존된다.

## 검수 범위와 판정 기준

- 12종은 banner/focus/editorial/cards 계열과 1열·2열·카드를 포함한다. 이름·횟수·순서·색상·서체 개성을 유지하면서 글자/번호/간격 변화를 본다.
- 카탈로그 샘플은 4행, 스타터는 3~4행이다. 추가 메트릭은 studio 24행/긴 한글·영문 혼합 6행, legacy stationd-v1/v2 각각 3행/긴 혼합 6행/24행이다.
- 24행이면 어떤 배치든 읽을 수 있다고 주장하지 않는다. 기준 studio 24행 단일열은 36px 미만 경고 상태다. 변경 후에도 경고/저장 차단을 유지하는 사례와 2열로 바꾸어 읽을 수 있는 사례를 구분한다. 잘 맞지 않는 내용은 줄 수·배치·타이머 공간을 사용자가 조정해야 한다.
- 추가 증빙은 실제 템플릿 선택 카드, 휴대폰 390×844 및 태블릿 834×1194 편집 화면, `prepareSlideDesign`가 생성한 1920×1080 저장 PNG, 실제 Canvas 1080p/4K, PNG만 사용하는 fallback을 나눠 기록한다. fallback 캡처는 최신 앱에서 렌더러 정보를 제거해 PNG 경로를 검증하는 것이며 구버전 앱 바이너리를 직접 실행한 결과가 아니다.
- 기존 사용자 입력은 변경 전 모듈을 고정해 다시 렌더링한다. 명시된 굵기·기울임·사용자 부제와 타이머 정보는 변경하지 않는다. 새 샘플의 가벼운 기본값과 구별한다.

앱 업데이트·재저장·구버전 TV 혼용과 캐시 적용 범위는 [rollout.md](rollout.md)를 따른다. 실제 TV 크기/시청 거리에서의 검수는 사용자가 나중에 진행하기로 했으므로 이번 로컬 캡처를 실기기 가독성 검수로 표기하지 않는다.
