# 수업 카드 구현과 플랫폼 지원

2026년 9월 30일 기준. 연결된 디스플레이 수업을 앱 밖에서 확인하고 조작하도록 iOS Live Activity와 Android Live Updates 지원을 추가했다. 제어센터에 직접 추가하는 버튼과 음악 미디어 세션은 이번 변경에 포함하지 않는다. 현재 develop의 로컬 구현이며 스토어 업로드는 수행하지 않았다.

## iOS

수업을 앱에서 시작하거나 진행 중 수업을 확인하면 잠금화면과 지원 기기의 Dynamic Island에 수업명과 전체 수업의 남은 시간을 표시한다. 이전 슬라이드, 일시정지 또는 재개, 다음 슬라이드, 상태 새로고침을 제공한다. 카드는 iOS 16.2 이상, 카드 내 버튼은 iOS 17 이상을 지원한다.

WidgetKit 확장은 표시만 담당하고 LiveActivityIntent는 앱 프로세스의 Firebase Auth와 기존 네이티브 수업 명령을 사용한다. 확장에 인증 토큰이나 Firebase 접근 권한을 전달하지 않는다. 오래된 수업 ID, 다른 계정, 종료된 수업과 ETag 충돌을 확인하며 오프라인 명령을 대기열에 저장하지 않는다. 로그아웃 또는 수업 종료가 확인되면 카드를 종료한다.

카운트다운은 매초 네트워크를 호출하지 않고 서버 시간과 종료 시각을 바탕으로 OS가 표시한다. 60초 동안 상태를 확인하지 못한 경우 예상 시간 또는 마지막 확인 상태임을 표시한다. 앱이 정지된 동안 다른 컨트롤러의 변경을 즉시 반영하는 APNs 업데이트는 구현하지 않았다. 버튼을 누르거나 앱에 돌아오면 서버에서 최신 수업을 확인한다. 앱이 정지된 상태에서 서버가 수업을 종료하면 카드 제거가 다음 확인까지 늦어질 수 있다.

새 확장 bundle ID는 `com.sunmkim.cloudboard.ClassActivity`다. Runner가 확장을 빌드하고 포함하며 기존 CI의 자동 서명 설정을 사용한다. 새 bundle ID의 배포용 프로비저닝과 TestFlight 수신은 아직 검증하지 않았다.

## Android

Android 16 이상에서 표준 BigText 알림, ongoing 플래그, `POST_PROMOTED_NOTIFICATIONS`, promotion 요청을 적용한다. 재생 중에는 OS chronometer를 통해 전체 수업 남은 시간을 표시하고, 일시정지 또는 연결 오류 시 타이머를 멈춘다. 연결 상태를 확인할 수 없는 알림은 일반 알림으로 낮춘다.

이전, 일시정지 또는 재개, 다음 버튼은 기존 Firebase 명령 경로를 사용한다. 표준 카드에서는 세 버튼을 제공하며 수업 종료는 카드를 눌러 앱에서 수행한다. Android 15 이하는 기존 커스텀 알림과 종료 버튼을 유지한다. 사용자가 알림을 지우면 수업은 유지하면서 해당 수업의 알림 재표시만 중단한다. 새 수업부터 다시 표시한다.

실제 promotion과 상태 표시줄의 칩, 잠금화면 표현은 OS 버전, 사용자 설정과 제조사의 지원 조건에 따라 달라진다. 일반 알림 권한 요청은 기존 흐름을 유지한다. Live Updates에는 커스텀 RemoteViews를 사용할 수 없으므로 iOS와 동일한 디자인을 보장하지 않는다. [Android 공식 조건](https://developer.android.com/develop/ui/views/notifications/live-update)

기존 백그라운드 제약도 유지한다. 프로세스가 중단되면 다른 기기의 변경을 즉시 받지 못하며, 마지막 갱신에서 최대 15분 또는 남은 수업 시간 중 짧은 시간 이후 알림이 사라진다. 서버 푸시나 상시 실행 서비스를 추가하지 않았다. 강제 종료, 장시간 대기와 실제 TV 반응은 실기기 확인이 필요하다.

## 웹과 설치형 PWA 조사

최종 결정: 사용자 요청에 따라 Chrome·Edge와 Windows PWA의 미니 컨트롤러 및 웹 알림 기능은 추가하지 않는다. 기존 웹 컨트롤러를 유지하며 아래 내용은 참고 조사로만 보관한다. 웹 코드 변경과 브라우저·PWA 실증은 수행하지 않았다. 설치형 PWA도 브라우저 엔진으로 실행되므로, 향후 재검토한다면 설치 여부보다 OS와 실제 API 지원 여부를 기준으로 판단한다. [Edge PWA 구조](https://learn.microsoft.com/en-us/microsoft-edge/progressive-web-apps/how-to/)

| 실행 환경 | 권장하는 수업 제어 방식 | 앱 밖에서의 범위 |
| --- | --- | --- |
| PC Chrome·Edge 일반 탭 | Document Picture-in-Picture 미니 컨트롤러 | 다른 창 위에 수업명, 남은 시간, 이전·일시정지/재개·다음 표시 |
| PC Chrome·Edge 설치형 PWA | 같은 미니 컨트롤러를 API 감지 후 제공 | 설치 창에서도 같은 웹 API를 사용하는 설계. 설치 모드별 실증 필요 |
| Android Chrome 웹·설치형 PWA | 화면 안 고정 수업 바 + 선택적 Web Push | 일반 시스템 알림과 지원되는 알림 버튼. 네이티브 Live Updates의 지속 타이머·승격을 약속하지 않음 |
| iPhone·iPad 홈 화면 PWA | 화면 안 고정 수업 바 + 선택적 Web Push | iOS/iPadOS 16.4 이상에서 권한 허용 후 잠금화면 알림. 알림을 누르면 컨트롤러로 복귀 |

Document Picture-in-Picture는 데스크톱 Chrome·Edge 116 이상에서 제공되며 일반 HTML 버튼을 넣을 수 있다. 사용자가 `미니 컨트롤러`를 눌러 열어야 하고 원래 탭 또는 PWA 창을 닫으면 함께 닫힌다. 잠금화면 위젯은 아니다. `documentPictureInPicture` 지원을 확인하고 요청 거절도 처리한다. Android Chrome과 iOS Safari는 현재 이 API를 지원하지 않는다. 설치형 PWA 지원은 브라우저 엔진과 API 범위에 따른 설계 판단이며 실제 설치 창 검증은 아직 하지 않았다. [Chrome 공식 문서](https://developer.chrome.com/docs/web-platform/document-picture-in-picture), [MDN 호환성 데이터](https://github.com/mdn/browser-compat-data/blob/main/api/DocumentPictureInPicture.json)

Web Push를 구현하면 서버 이벤트를 받아 일반 알림을 표시할 수 있다. Android Chrome과 Edge의 알림 버튼은 서비스 워커의 `showNotification`과 `notificationclick`을 사용하며 버튼 개수와 표현은 환경에 따라 달라진다. iOS Safari의 알림 action은 현재 미지원이므로 알림 본문을 눌러 앱으로 돌아오는 흐름을 기본으로 한다. 홈 화면 PWA의 Web Push는 Live Activity 또는 Dynamic Island를 생성하지 않는다. [Edge 알림과 액션](https://learn.microsoft.com/en-us/microsoft-edge/progressive-web-apps/how-to/notifications-badges), [알림 버튼 호환성](https://github.com/mdn/browser-compat-data/blob/main/api/Notification.json), [WebKit 안내](https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/)

PWA를 설치해도 백그라운드 타이머와 Firebase 연결의 상시 실행이 보장되지는 않는다. 브라우저는 숨겨진 페이지를 동결하거나 제거할 수 있고 서비스 워커도 계속 살아 있는 프로세스가 아니다. 초마다 푸시를 보내 타이머를 흉내 내지 않고, 화면에 돌아오면 최신 서버 상태와 시간 기준을 다시 확인해야 한다. [Chrome 페이지 수명 주기](https://developer.chrome.com/docs/web-platform/page-lifecycle-api), [서비스 워커 수명](https://web.dev/learn/pwa/service-workers)

### 보류한 적용안

1. 웹과 PWA 공통으로 진행 중 수업 바를 화면 안에 유지한다. PC에서는 사용자가 미니 컨트롤러를 열어 다른 프로그램을 보면서 조작할 수 있게 한다. 새 컨트롤러가 별도 재생 루프를 만들지 않고 기존 수업 상태와 명령 경로를 공유한다.
2. 미니 창에는 수업명, 남은 시간, 이전·일시정지/재개·다음, 연결 상태를 표시한다. 창 닫기는 수업 종료 명령을 보내지 않는다. 본창으로 돌아오는 버튼도 제공한다.
3. 명령은 최신 수업 ID와 상태를 확인해 실행한다. 연결이 끊겼을 때는 마지막 확인 상태를 표시하고 제어를 비활성화한다. 오프라인에서 누른 다음·이전 명령을 나중에 재생하지 않는다. 재연결 시 서버 상태를 다시 읽는다.
4. 모바일 PWA에는 수업 종료 등 필요한 상태 변화에만 선택적 알림을 제공하는 것을 후속 단계로 검토한다. Android에서 직접 제어 버튼을 넣는다면 서비스 워커용 인증·수업 소유권·명령 유효 기간을 별도로 검증한다. iOS는 알림 터치 후 최신 수업으로 복귀한다. 매초 카운트다운이나 매 세트마다 알림을 보내지 않는다.
5. PC 일반 탭/설치 PWA의 Chrome·Edge, Android Chrome PWA, iOS 홈 화면 PWA를 분리해서 확인한다. 권한 거부, 본창/미니 창 닫기, 절전과 복귀, 네트워크 끊김, 다른 컨트롤러에서 수업 변경·종료를 포함한다.

현재 `web/manifest.json`은 `display: standalone`을 사용하지만 이름·설명·테마는 Flutter 초기값이 남아 있다. `web/index.html`도 기본 메타데이터를 사용한다. 조사한 웹 및 Dart 소스에는 Document PiP나 수업용 Web Push·알림 액션 구현이 없다. Flutter가 빌드 때 생성하는 서비스 워커의 존재만으로 수업 알림이 제공되는 것은 아니다. 구현 시 PWA 이름·아이콘·테마와 업데이트 동작도 함께 점검한다.

## 검증

- Flutter 정적 분석과 관련 테스트 4개 통과. 초기 인증 및 세션 로딩 중 네이티브 연결을 지우지 않는 동작 포함.
- Swift 순수 테스트 통과. 서버 시간 차이, 운동 경계, 일시정지, 카운트다운, 잘못된 위치와 종료 처리 확인.
- iOS 시뮬레이터 빌드 및 확장의 unsigned Release 빌드 성공. iPhone 17 Pro에서 Dynamic Island와 잠금화면 표시 확인.
- DEBUG 전용 수업 fixture로 컴파일된 AppIntent 핸들러의 이전, 다음, 일시정지, 재개, 새로고침과 ActivityKit 종료 반영 확인. 실제 Firebase 수업은 변경하지 않았다. 잠금화면 버튼의 실제 터치 전달과 실기기 Firebase 왕복은 미검증이다.
- Android 컴파일 및 Kotlin 단위 테스트 통과. Android 13 에뮬레이터에서 기존 알림, 표준 템플릿의 타이머/정지/오프라인 표시, 사용자 해제 유지 테스트 통과. 권한 거부 테스트는 이미 권한이 허용된 상태라 건너뛰었다.
- Android 16의 실제 promotion, Samsung 등 제조사 UI와 장시간 백그라운드 동작은 미검증이다.

시뮬레이터 fixture는 Debug 빌드의 `--class-activity-preview` 인자로만 활성화되며, `--class-activity-self-test`를 함께 전달하면 AppIntent 및 ActivityKit 검증을 실행한다. 일반 실행과 Release 빌드에는 fixture가 활성화되지 않는다.
