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

## 웹 조사

PC Chrome 및 Edge에서는 Document Picture-in-Picture로 다른 창 위에 표시되는 수업 미니 컨트롤러를 구현할 수 있다. 일반 HTML 버튼과 타이머를 표시할 수 있지만 사용자가 직접 열어야 하고 원래 페이지가 닫히면 함께 닫힌다. 웹에 적용할 경우 이 방식을 우선 검토한다. 이번에는 웹 코드를 변경하지 않았다. [Chrome 공식 문서](https://developer.chrome.com/docs/web-platform/document-picture-in-picture)

모바일 웹의 Web Push는 알림을 제공하지만 임의 디자인과 지속 카운트다운, 버튼을 모든 브라우저에 동일하게 제공하는 수단은 아니다. 알림 action 지원은 브라우저별로 다르다. iPhone에서는 홈 화면에 설치한 웹앱이 iOS 16.4 이상에서 Web Push를 사용할 수 있으며, 이 기능을 네이티브 Live Activity와 동일하게 취급하지 않는다. [알림 버튼 지원](https://developer.mozilla.org/en-US/docs/Web/API/Notification/actions), [WebKit 안내](https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/)

## 검증

- Flutter 정적 분석과 관련 테스트 4개 통과. 초기 인증 및 세션 로딩 중 네이티브 연결을 지우지 않는 동작 포함.
- Swift 순수 테스트 통과. 서버 시간 차이, 운동 경계, 일시정지, 카운트다운, 잘못된 위치와 종료 처리 확인.
- iOS 시뮬레이터 빌드 및 확장의 unsigned Release 빌드 성공. iPhone 17 Pro에서 Dynamic Island와 잠금화면 표시 확인.
- DEBUG 전용 수업 fixture로 컴파일된 AppIntent 핸들러의 이전, 다음, 일시정지, 재개, 새로고침과 ActivityKit 종료 반영 확인. 실제 Firebase 수업은 변경하지 않았다. 잠금화면 버튼의 실제 터치 전달과 실기기 Firebase 왕복은 미검증이다.
- Android 컴파일 및 Kotlin 단위 테스트 통과. Android 13 에뮬레이터에서 기존 알림, 표준 템플릿의 타이머/정지/오프라인 표시, 사용자 해제 유지 테스트 통과. 권한 거부 테스트는 이미 권한이 허용된 상태라 건너뛰었다.
- Android 16의 실제 promotion, Samsung 등 제조사 UI와 장시간 백그라운드 동작은 미검증이다.

시뮬레이터 fixture는 Debug 빌드의 `--class-activity-preview` 인자로만 활성화되며, `--class-activity-self-test`를 함께 전달하면 AppIntent 및 ActivityKit 검증을 실행한다. 일반 실행과 Release 빌드에는 fixture가 활성화되지 않는다.
