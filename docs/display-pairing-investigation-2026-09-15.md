# 디스플레이 등록 오류 조사 — 2026-09-15

## 실제 확인한 기록

로그인된 Chrome의 Firebase Crashlytics에서 Android 앱 최근 7일(9월 9–15일)의 미해결 비정상 종료 기록을 확인했다.

- 오류: `Bad state: 연결된 매장을 찾을 수 없습니다.`
- 이벤트 4건, 사용자 3명.
- 빌드별: 1.0.0 (16) 2건, (8) 1건, (14) 1건.
- 확인한 상세 이벤트 시각: 2026-09-11 16:23:06. 이 기록을 오늘 배포한 빌드의 오류라고 해석하지 않는다.
- 호출 경로: `DeviceModeHomeScreen.checkSchedules` → `ScheduleRunnerController.runDue` → `PlaybackActions.hasRunningSession` → `PlaybackRealtimeDataSource._active` → owner ID 검사 실패.
- [Crashlytics 이슈](https://console.firebase.google.com/u/0/project/cloud-board-stationd/crashlytics/app/android:com.sunmkim.cloudboard/issues/ea00d2006eedb109068b111a99217e92?time=7d&types=crash)

## 원인과 수정

현재 develop에도 모드 로딩이 끝나기 전 `currentMode`의 기본값 controller로 예약 확인 타이머를 시작하는 경로가 남아 있었다. owner ID가 없는 상태에서 예약 확인의 첫 서버 조회가 실행되며, 해당 await는 기존 AsyncValue.guard 바깥에 있어 미처리 오류로 전파됐다.

1. 모드 로딩 완료, controller 모드, 계정 소유자 확인 완료 후에만 예약 확인을 시작한다.
2. 화면/모드가 바뀌어도 이전 프레임 콜백이 뒤늦게 실행되지 않도록 종료 여부를 확인한다.
3. 예약 확인 전체를 오류 처리 범위에 넣고, 첫 조회 전에 로딩 상태를 설정해 중복 실행을 막는다.
4. 각 비동기 작업 후 계정이 동일한지 확인해 변경된 계정에 이전 작업이 이어지지 않게 한다.
5. 처음 수업을 시작한 후 같은 회차에서 다른 예약으로 덮어쓰지 않는다.

## 등록 버튼 오류와 구분

이 Crashlytics 기록은 초기 화면의 예약 확인 오류다. 사용자가 본 모든 등록 실패가 이 경로 때문이라고 단정하지 않는다.

등록 버튼의 예외는 AsyncValue.guard로 처리돼 기존 전역 미처리 오류 핸들러에 도달하지 않는다. 그래서 UI에서 반복적으로 실패해도 해당 실패가 Crashlytics에 남지 않을 수 있다. 이번 수정에는 릴리스 앱에서 다음 실패 단계를 non-fatal로 기록하는 진단 경로를 추가했다.

- 코드 발급, 프로필 조회, 등록 기기 조회, 코드 연결.
- 실패 분류: owner 준비 전, 인증 필요, 대수 제한, 코드 만료/사용됨/없음, 권한 거부, 네트워크, 기타.
- 원본 SDK 메시지·UID·이메일·연결 코드·DB 경로를 전송하지 않고 분류와 스택만 기록한다.
- 웹·디버그에서는 보고하지 않으며, 보고 실패가 재시도를 막지 않는다.
- 이미 발생한 처리된 오류를 소급해 복원할 수는 없다. 새 진단은 수정 빌드가 배포된 후 발생하는 실패부터 적용된다.

앞선 로컬 수정(개발용 Bad state 접두어 제거, 권한 거부를 만료라고 오안내하던 처리 제거, 중복 연결 요청 방지)도 유지했다.

## 검증 및 상태

- 전체 Flutter 테스트 **176개 통과**.
- 추가 회귀: owner 없음/로딩 중에는 서버 조회 없음, 네트워크 오류 처리, 동시 호출 차단, 다음 확인에서 재시도, 오류 문구 및 개인정보 없는 진단 분류.
- Flutter 정적 분석 문제 없음.
- 실제 매장 기기의 등록 실패를 원격으로 재현한 것은 아니다. 현재 운영 Firebase 데이터나 보안 규칙은 변경하지 않았다.
- 변경은 develop 로컬에 있으며, 아직 커밋·푸시·배포하지 않았다.
