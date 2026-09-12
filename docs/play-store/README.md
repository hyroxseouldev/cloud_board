# 클라우드보드 · Google Play 등록 자료

2026-09-11 기준 한국어 스토어 등록 시안입니다. 앱 이름은 **클라우드보드**로 확정하고, 앱의 라벤더 색상과 Pretendard를 사용했습니다. Play Console 업로드나 공개 출시는 수행하지 않았습니다.

[전체 이미지 보기](index.html) · [한 장으로 보기](preview.png) · [에셋 규격 검사 결과](asset-manifest.json)

## 복사해서 입력할 문구

| 입력 항목 | 파일 |
|---|---|
| 앱 이름 | [title.txt](ko-KR/title.txt) |
| 간단한 설명 | [short-description.txt](ko-KR/short-description.txt) |
| 자세한 설명 | [full-description.txt](ko-KR/full-description.txt) |
| 이번 버전의 변경사항 | [release-notes.txt](ko-KR/release-notes.txt) |

분류 초안: 앱 / 건강 및 피트니스. 스토어 기본 언어는 한국어입니다. 가격·배포 국가·타깃 연령은 이 자료에서 임의로 확정하지 않았습니다.

## 업로드할 이미지

| Play Console 입력 항목 | 경로 | 규격 |
|---|---|---|
| 앱 아이콘 시안 | `ko-KR/assets/branding/app-icon-draft-512.png` | 512×512, RGBA PNG |
| 그래픽 이미지 | `ko-KR/assets/branding/feature-graphic-1024x500.png` | 1024×500, RGB PNG |
| 휴대전화 스크린샷 | `ko-KR/assets/phone/01`~`04` | 각 1080×1920, RGB PNG |
| 태블릿 스크린샷 | `ko-KR/assets/tablet/01`~`04` | 각 1080×1920, RGB PNG |
| Android TV 스크린샷 | `ko-KR/assets/tv/01-player.png` | 1920×1080, RGB PNG |
| Android TV 배너 | `ko-KR/assets/tv/banner-1280x720.png` | 1280×720, RGB PNG |

휴대전화는 워크아웃 정리 → 편집 → 브리핑 → 사운드 순서입니다. 세 번째에는 진한 라벤더 배경으로 변화를 줬습니다. 태블릿은 추가 홍보 문구 없이 앱 화면만 담았습니다. TV 배너는 Play Console용이며 앱에 포함되는 320×180 런처 배너와 다른 파일입니다.

아이콘은 기존 TV의 모니터·파형 콘셉트로 새로 그린 벡터 시안입니다. 현재 모바일 앱에는 Flutter 기본 런처 아이콘이 남아 있으며, **이 시안은 앱 런처에 아직 적용하지 않았습니다.** 출시 아이콘을 선택한 뒤 앱 아이콘도 함께 맞춰야 합니다. 수정 가능한 원본은 `app-icon-draft.svg`입니다.

## 스크린샷 출처와 확인 범위

- `source/`는 이 저장소의 실제 Flutter 화면 위젯을 Android 테마로 렌더링한 원본입니다. Android 실기기 캡처는 아닙니다.
- 수업명, 운동 설명과 연결 기기는 로컬 샘플 데이터입니다. 실제 고객·회원 데이터나 외부 이미지·상표는 사용하지 않았습니다.
- 휴대전화 원본은 논리 360×640, 태블릿 원본은 720×1280, TV는 1280×720입니다. 업로드용 PNG는 지정 해상도로 렌더링했고 비율을 유지했습니다.
- 브리핑은 컨트롤러 화면입니다. TV 스크린샷에는 실제 재생 화면을 사용했습니다. 브리핑이 TV에 자동 표시된다는 홍보 문구는 넣지 않았습니다.
- 생성 시 레이아웃 예외, 최종 PNG 크기·알파 채널 및 아이콘 용량을 검사합니다. 최종 Android 릴리스 화면과 글꼴·줄바꿈·동작이 같은지 출시 전에 대조해 주세요.
- 미리보기용 `preview.png`, `index.html`, `source/` 파일은 Play Console 업로드 대상이 아닙니다.

## 이미지 대체 텍스트

| 이미지 | 대체 텍스트 |
|---|---|
| 소개 이미지 | 클라우드보드의 수업 타이머와 운동 설명을 보여주는 디스플레이 화면 |
| 01-workouts | 폴더 검색과 워크아웃 카드로 수업 구성을 정리하는 화면 |
| 02-editor | 운동 순서와 세트, 운동 시간, 휴식 시간을 편집하는 워크아웃 화면 |
| 03-briefing | 수업 시작 전에 운동 구성과 설명을 확인하는 브리핑 화면 |
| 04-sounds | 카운트다운과 운동 전환 소리, 음량을 설정하는 화면 |
| TV 재생 | 운동 설명과 남은 시간, 세트 수를 함께 표시하는 수업 디스플레이 |
| TV 배너 | 모니터와 파형 모양의 클라우드보드 로고 |

## 출시 전에 채울 정보

- 공개 문의 이메일: **미정**
- 개인정보처리방침 URL: **미정**
- 로그인·매장 연결이 필요한 기능의 심사용 접근 안내 및 계정: **미정**
- 데이터 보안, 광고 여부, 콘텐츠 등급, 타깃 연령 등의 Console 설문: **별도 확인 필요**. 코드에는 Firebase 인증·저장소·Crashlytics 등이 있으므로 수집하지 않는다고 일괄 답하지 않습니다.
- 계정 생성·삭제 관련 공개 정책과 앱 내 실제 동작: **확인 필요**

이 문서는 정책 설문 답변이나 개인정보처리방침을 대신하지 않습니다. 현재 저장소 배포 워크플로는 `main` 병합 시 **내부 테스트 트랙**에 업로드하며 공개 프로덕션 출시를 자동으로 수행하지 않습니다.

## 재생성

저장소 루트에서 실행합니다. 샘플 데이터를 바꾸려면 `tool/play_store_capture_test.dart`, 디자인과 문구를 바꾸려면 `tool/render_play_store_assets.cjs`를 수정합니다.

```sh
.fvm/flutter_sdk/bin/flutter test tool/play_store_capture_test.dart
```

Node.js 20+와 Google Chrome이 필요합니다. 렌더러는 `playwright`와 `sharp` 패키지를 사용합니다. 프로젝트 Flutter 의존성을 바꾸지 않으려면 별도 폴더에 설치합니다.

```sh
npm install --prefix /tmp/cloudboard-store-tools playwright sharp
NODE_PATH=/tmp/cloudboard-store-tools/node_modules node tool/render_play_store_assets.cjs
```

첫 명령은 앱 위젯 원본을 생성하며, 두 번째 명령은 배너·아이콘·홍보 스크린샷·갤러리·규격 검사 결과를 만듭니다. 실행 중 서버 연결, 실제 워크아웃 저장, 세션 시작은 하지 않습니다.

## 공식 규격

Google Play 규격 확인일: 2026-09-11.

- [미리보기 에셋 규격](https://support.google.com/googleplay/android-developer/answer/9866151?hl=ko): 아이콘 512×512, 소개 이미지 1024×500, TV 배너 1280×720. 휴대전화·태블릿용으로 1080×1920의 스크린샷을 각각 4장 준비했습니다.
- [앱 생성 및 스토어 등록정보](https://support.google.com/googleplay/android-developer/answer/9859152?hl=ko): 앱 이름 30자, 간단한 설명 80자, 자세한 설명 4,000자 이내로 작성합니다.
