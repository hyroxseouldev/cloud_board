# STA-165 관객 화면 제품 로고

2026-10-14 로컬 구현·자동 검증 자료다. 운영 계정 정책 활성화, 앱/TV 배포, 실제 TV 거리 검수 완료를 의미하지 않는다. 서버 계약·구버전 지원·계정별 활성화와 되돌리기 순서는 [서버 rollout 문서](../../sta165-server-rollout.md)에 분리했다.

## 화면 계약

`AudienceLogoFrame`은 DisplayMode의 대기/브리핑, 시작 카운트다운, 운동/이미지/휴식/일시정지 화면에서 같은 서버 projection을 사용한다. 제품 로고는 `brandL`/`brandR`, 슬라이드 `showBrand`, 사용자 이미지, 센터 로고와 별개다. 편집·코치 조작 화면에는 추가하지 않는다. 센터 로고를 수업 중 새로 삽입하지 않는다.

- 서버가 확인한 `all-audience` + 표시: 모든 관객 장면에 제품 심벌과 CloudBoard 이름을 1개 표시한다.
- 같은 scope + 숨김: 제품 로고를 숨기고 같은 footer 공간을 유지한다. 설정·플랜 변경이 도착해도 그림 크기나 플레이어/session key는 바뀌지 않는다. 타이머는 계속 진행한다.
- `standby` scope: 대기/브리핑에만 확인된 표시 값을 적용한다. 수업 영역은 기존 크기 그대로다.
- 최초 조회 중/실패/잘못된 응답/미활성 계정: 임의로 Free를 추정하지 않는다. 수업 로고를 새로 표시하지 않고 대기는 기존 effective brand 표시를 유지한다.
- 동일 계정의 확인된 캐시가 있으면 오프라인/재연결 실패/권한 만료 중에도 마지막 표시 선택을 유지한다. 이는 다음 수업 시작 권한이 아니다. 더 최신 서버 projection이 오면 표시만 갱신한다. 계정 변경 시 이전 계정의 policy는 즉시 제외한다.
- 실제 `black` 및 영업 외 검정 화면에는 제품 로고·reserved footer 모두 없다. 기존 기기 전송 OFF는 프로토콜상 `standby`여서 대기 로고가 표시된다. 이 기존 OFF 의미는 바꾸지 않았다.
- 수업 완료 후 별도 종료 장면을 만들지 않고 기존 대기 화면으로 돌아간다.

`null/standby → all-audience` 최초 활성화는 footer 영역이 생기므로 내용 viewport가 한 번 줄어든다. 이후 같은 scope 안에서 Free↔유료 표시/숨김은 동일 geometry다. 둘 다 재생 상태·남은 시간·사용자 콘텐츠는 재설정하지 않는다. 계정 활성화는 배포 준비를 마친 뒤 가능하면 대기 상태에서 수행한다.

## 크기·대비·안전영역

표는 1920×1080 논리 viewport 기준이며 `min(width/1920, height/1080)`로 비례한다. 폰에서는 최소 크기로 제품명을 유지한다.

| 항목 | 대기/브리핑·카운트다운 | 운동·휴식·일시정지 |
| --- | --- | --- |
| 제품 배지 | 320×64 | 240×48 |
| 배지 제한 | 공통 최소 140×28, 최대 640×128 | 동일 |
| 기본 하단 여백 | viewport 높이의 2.5% = 27 | 동일 |
| 내용과 배지 간격 | 12 (최소 6, 최대 24) | 동일 |
| 기본 reserved footer | 103 높이 | 87 높이 |
| 제품명/심벌 원본 크기 | 32 / 40, 배지 안에 비례 맞춤 | 24 / 28, 배지 안에 비례 맞춤 |

배지는 하단 중앙 정렬이다. 좌우·하단 안전 여백은 기본 2.5%, 활성화된 기기 `safeInset`(최대 20%), 시스템 inset 중 큰 값을 쓴다. 테스트는 8% inset과 2배 zoom/offset/cover를 포함한다. 배지는 `DisplayViewport`와 이미지 transform 밖의 별도 Column footer이므로 타이머·운동 문구·사용자 하단 문구·상태 칩과 겹치지 않으며 이미지가 확대되어도 잘리지 않는다. 이미지 crop 자체는 사용자가 정한 cover/zoom 동작을 유지한다.

불투명 oat 배지 `#F7F5EF` + ink 제품명 `#2B332E` 대비는 약 **11.92:1**이다. 밝은 이미지와 어두운 이미지 모두 같은 제품명 대비를 유지한다. 기존 심벌 PNG를 재사용한다. 사용자 타이머/휴식/브랜드 문구의 색상은 수정하지 않는다. 밝은 캡처 샘플은 사용자가 지정할 수 있는 `brandColor`/`setsColor`를 ink로 설정했으며 앱 기본색의 변경이 아니다.

## 실제 위젯 캡처

데이터 transport만 fixture로 대체했고 실제 `DisplayModeScreen`, `WorkoutPlayerScreen`, `StoreWelcomeBoard`, 카운트다운, 캔버스와 공통 프레임을 사용했다. 폰은 논리 390×844 / DPR 2, 나머지는 DPR 1이다. 웹은 Chrome 회귀 테스트로 같은 Dart 위젯 경로를 검증했다. 아래 PNG는 VM widget rendering이며 실기기 캡처가 아니다.

| 장면 | 증거 |
| --- | --- |
| 대기 | [standby.png](screenshots/standby.png) |
| 시작 카운트다운 | [countdown.png](screenshots/countdown.png) |
| 어두운 운동 | [exercise-dark.png](screenshots/exercise-dark.png) |
| 밝은 운동 | [exercise-light.png](screenshots/exercise-light.png) |
| 업로드 이미지 | [uploaded-image.png](screenshots/uploaded-image.png) |
| 휴식 | [rest.png](screenshots/rest.png) |
| 일시정지 | [pause.png](screenshots/pause.png) |
| Plus 숨김 | [plus-hidden.png](screenshots/plus-hidden.png) |
| 검정 | [black.png](screenshots/black.png) |
| 8% safe inset + cover + 1.4× zoom | [safe-area-cover.png](screenshots/safe-area-cover.png) |
| 세로 폰 | [phone-portrait.png](screenshots/phone-portrait.png) |
| 태블릿 1024×768 | [tablet.png](screenshots/tablet.png) |
| 4K 3840×2160 | [tv-4k.png](screenshots/tv-4k.png) |

`safe-area-cover`는 확대에 따른 사용자 슬라이드의 실제 crop을 보여준다. 잘린 사용자 내용을 임의로 축소하지 않으며, 제품 로고만 crop 범위 밖 안전영역을 보장한다. `uploaded-image`는 네트워크 없는 320×180 컬러 체크 PNG fixture를 실제 이미지 provider로 decode한 경로다.

## 재현 및 회귀

```sh
flutter test test/audience_logo_test.dart test/audience_branding_data_test.dart test/billing_test.dart test/store_operations_screen_test.dart test/plan_usage_branding_test.dart test/display_mode_flow_test.dart
flutter test --platform chrome test/audience_logo_test.dart test/audience_branding_data_test.dart test/display_mode_flow_test.dart
flutter test tool/sta165_capture_test.dart
```

- 신규 UI 테스트: 5개 해상도에서 안전영역과 내용 겹침 없음, 대기→브리핑→카운트다운→운동→휴식→정지→대기, 검정/예약 검정, 유료 숨김 후 동일 플레이어 element와 viewport·남은 시간 감소, unknown/standby scope, 빈 사용자 문구·showBrand false, 업로드 이미지 decode/zoom/cover, 코치 화면 제외.
- 데이터 테스트: strict projection, owner별 캐시, 조회 오류·누락·재연결, stale revision, 직렬 캐시 write, 만료 정책과 안내의 분리, 상품 문구 scope gate.
- 기존 DisplayMode 회귀: 진행 수업 중 effective brand/영업시간 변화로 수업이 끊기지 않음, 종료 후 대기, 재연결과 resume, 기기 모드 전환.

기존 결제·매장 운영·대기 브랜딩·DisplayMode를 포함한 VM 회귀 묶음 50/50, 기존 DisplayMode를 포함한 Chrome 묶음 22/22가 통과했다. 최종 데이터 테스트 **12/12**와 컬러 이미지 fixture 기준 UI 테스트 **9/9**를 각각 VM·Chrome에서 검증했고, 실제 위젯 캡처 **13/13**, `flutter analyze`도 오류 없이 완료했다. 최초 캐시 저장이 끝나기 전 재접속·만료 상황의 메모리 유지, 구독 종료 후 지연된 캐시 쓰기, 첫 조회에서 만료된 서버 기록 거부, 서버 시각 차이가 있어도 최신 projection revision 적용을 추가로 확인했다.

실제 TV/모바일 기기의 overscan, 3–5m 거리 가독성, 디스플레이 밝기 및 구버전 업데이트 설치는 사용자가 추후 검수할 항목으로 남긴다. 이번 캡처나 로컬 통과를 실제 운영 적용으로 표현하지 않는다.
