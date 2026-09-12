# Android 수업 알림 제어 구현 및 배포 인계

2026-09-12. develop `b03e9b7`에서 `codex/android-class-controls` 브랜치와 별도 워크트리를 생성했다. 원래 develop 작업 폴더의 미커밋 UI 변경은 포함하지 않았으며 그대로 보존했다.

## 구현 결정

일반 알림 + 명시적 비공개 BroadcastReceiver + `goAsync()` 안의 짧은 HTTPS 요청을 사용한다. 알림 명령 실행에 Flutter 엔진이나 플레이어 위젯이 필요하지 않다. WorkManager로 실시간 버튼을 대체하거나 foreground service를 계속 실행하지 않는다.

실제 제어 대상은 Firebase Realtime Database의 `users/{owner}/activeSession`이고, TV는 기존 세션 구독과 타임라인 계산으로 변경을 반영한다. 미디어 재생 서비스나 실제로 쓰지 않는 Bluetooth/네트워크 변경 권한을 추가할 필요가 없는 방식이다. `connectedDevice`의 전제조건을 만들기 위한 권한 추가도 하지 않았다.

앱 전체 수명의 Riverpod provider가 로그인, 기기 모드, 활성 세션을 관찰하여 네이티브 알림에 투영한다. 로컬 미리보기와 디스플레이 모드는 Android 제어 알림을 만들지 않는다. 알림은 현재 확인한 운동/휴식/일시정지 상태를 표시하고, 펼치면 이전·일시정지/재개·다음 및 별도의 수업 종료 버튼을 제공한다. 종료는 기존 알림 stop과 같이 별도 확인 없이 연결 수업을 끝낸다. 앱 화면의 종료 확인은 보존했다.

Android의 `AudioService.init` 경로와 미디어 서비스/리시버/foreground service 권한을 제거했다. 실제 효과음에 쓰는 audioplayers는 유지한다. audio_service와 무음 생성 코드는 **iOS에만 남겨 두었다**. iOS 제어의 회귀를 피하기 위한 범위 분리이며, iOS에서 무음 유지 구조를 없애려면 별도의 백그라운드 실행 설계와 기기 검증이 필요하다.

## 명령 안전성과 상태 표시

- 명령마다 현재 Firebase 사용자와 세션 소유자를 대조한다. 토큰을 앱 설정에 저장하지 않으며, Firebase Auth에서 유효한 ID 토큰을 얻는다.
- 최신 세션을 서버에서 읽고 id, 종료 여부, 카운트다운, revision을 검증한다. 다른 기기에서 상태가 바뀌었으면 알림을 새로 표시하고 해당 탭은 실행하지 않는다.
- ETag를 조건으로 PUT하여 읽기 이후의 동시 변경을 덮어쓰지 않는다. 충돌 시 자동 재시도하지 않는다.
- 각 알림의 일회용 토큰을 I/O 전에 소비한다. 처리 중 입력은 대기열에 넣지 않고 무시한다. 빠른 연속 두 번 탭을 두 개의 명령으로 보장하지 않는다. 갱신된 알림에서 다음 조작을 해야 한다.
- Firebase 오프라인 쓰기 큐를 사용하지 않는다. 전체 작업 예산은 약 6.5초, 요청별 최대 2초이며 소켓 연결에도 강제 종료 시한을 둔다. 결과가 불확실하면 성공 표시 대신 상태 확인 버튼을 제공한다.
- 새 명령에 서버 시각 기준 6초 만료를 넣고 **database.rules.json에서 서버가 만료를 거부한다**. 이 규칙은 배포 전 필수다. 로컬 HTTP 시간 초과만으로 서버의 미실행을 보장하지 않는다.
- 앱의 기존 쓰기 경로에도 세션 id/완료 상태 검증을 추가하여 이미 대기 중인 갱신이 종료된 세션을 되살리지 않도록 했다.
- 네이티브 종료가 확인되면 기존 형태의 완료 이벤트도 남긴다. 감사 이벤트 저장은 남은 요청 시간 내 최선 노력이며, 이벤트 저장 실패를 이미 확인된 종료 실패로 표시하지 않는다.
- 서버 쓰기 확인은 TV가 화면에 적용했다는 ACK와 다르다. 실제 디스플레이 반응은 실기기 검증 항목이다.

## 지원 범위와 남은 수용 기준

프로세스가 실행 가능한 동안에는 화면 이동과 무관하게 세션 투영 및 운동 경계에서 알림을 갱신한다. 초마다 알림을 쓰지 않는다. 프로세스가 제거돼도 살아 있는 알림의 명시적 receiver는 Flutter 화면 없이 동작할 수 있지만, Android의 강제 종료 이후 제어를 보장하지 않는다.

**기획서의 모든 실시간 상태 수용 기준을 충족했다고 볼 수는 없다.** OS가 프로세스를 정리/동결한 상태에서는 다른 기기의 종료를 즉시 수신하여 알림을 지우는 것이 보장되지 않는다. 이때도 버튼을 누르면 서버에서 세션을 검증하므로 종료된 수업을 되살리지 않는다. 알림은 마지막 갱신에서 최대 15분 후, 진행 중 수업의 남은 시간이 더 짧으면 그 시점에 사라진다. 15분 이상 정지한 수업의 알림을 다시 보려면 앱을 열어야 할 수 있다. 이 제약 없이 상시 최신 상태가 필수라면 서버 푸시 등 추가 설계가 필요하다.

잠금 화면은 비공개 알림으로 제공하며 OS/사용자 설정을 따른다. 잠금 및 장시간 대기, 제조사 절전 정책, 실제 TV 반응은 미검증이다. 사용자 요청에 따라 이번에는 자동 검증까지만 진행한다.

## 검증

- Flutter analyze: 오류 없음.
- Flutter 전체 테스트: 130개 통과. 위젯 없는 앱 범위 투영, 종료/로그아웃 정리, 권한 거부 처리 포함.
- Kotlin 단위 테스트: 7개 통과. 경과 시간 계산, 재개, 이전의 3초 규칙, 마지막 운동 다음, 완료/다른 계정/다른 세션/카운트다운 차단, 명령 만료 및 ID 확인.
- Firebase Database 에뮬레이터: 권한 분리, 만료/너무 먼 미래 명령 거부, 정상 명령, 기존 쓰기 호환, 오래된 ETag로 완료 상태 덮어쓰기 차단 확인.
- Android 13(API 33) 에뮬레이터: 알림 생성, 표준 3개 제어와 펼친 알림의 종료 버튼, 오래된 토큰 차단, 완료 후 알림 정리 검증.
- 알림 권한 실제 거부 조건: 별도 instrumentation 실행 1개 통과(건너뛰지 않음). 일반 알림 제어/정리도 최종 빌드에서 별도 1개 통과. 통합 테스트에서 이미 권한이 허용되면 거부 케이스는 건너뛰도록 되어 있다.
- Android 실제 제어 기기/연결 디스플레이 없음. Android 14 이상 런타임 검증도 남아 있다. target SDK 36으로 빌드/매니페스트 확인한다.

재실행:

```sh
flutter analyze
flutter test
cd android
./gradlew :app:testDebugUnitTest :app:connectedDebugAndroidTest
```

권한 거부만 검증:

```sh
adb install -r build/app/outputs/apk/debug/app-debug.apk
adb install -r build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
adb shell pm revoke com.sunmkim.cloudboard android.permission.POST_NOTIFICATIONS
adb shell am instrument -w -e class com.sunmkim.cloudboard.ClassNotificationsTest#deniedPermissionDoesNotCrashOrPublish com.sunmkim.cloudboard.test/androidx.test.runner.AndroidJUnitRunner
```

규칙 검증(로컬 데모 프로젝트만 사용, 운영 배포 안 함):

```sh
npm ci --prefix tool/android-controls
firebase emulators:exec --only database --project demo-cloudboard --config firebase.controls-test.json 'node tool/android-controls/rules-test.mjs'
```

## 비공개 테스트 제출 인계

빌드 16에는 이 변경이 없다. versionCode 17을 로컬 검증 후보로 사용하되, 실제 업로드 시에는 Play의 최신 versionCode/CI 번호와 중복되지 않는지 확인해야 한다.

release AAB 빌드 성공. 최종 병합 매니페스트에서 versionCode 17, target SDK 36 및 미디어 서비스/FGS 권한 제거를 확인했다. 인증서는 `CN=Android Debug`로 확인했다. 검증용 산출물은 `build/validation/cloudboard-17-debug-signed.aab`다.

로컬에 ANDROID_KEYSTORE_PATH/PASSWORD, ANDROID_KEY_ALIAS/PASSWORD가 없다. 현재 Gradle은 이 경우 debug 키로 release 빌드도 서명하므로, **로컬 검증용 AAB는 Play 제출용이 아니다.** CI의 기존 Google Play 서명 환경에서 새로운 AAB를 생성해야 한다.

1. 위의 실제 기기 수용 기준과 15분/실시간 상태 제약을 확인한다.
2. 새 database.rules.json을 먼저 배포한다. 현재 작업에서는 운영 규칙을 배포하지 않았다.
3. 기존 CI의 정적 분석/테스트 및 Play 업로드 키를 사용해 새 번호의 서명 AAB를 만든다.
4. 최종 release 매니페스트에 AudioService, MediaButtonReceiver, FOREGROUND_SERVICE 및 FOREGROUND_SERVICE_MEDIA_PLAYBACK이 없는지 확인한다. POST_NOTIFICATIONS와 실제 기능의 권한은 유지한다.
5. 새 AAB를 Alpha에 넣고, 이 빌드에는 foreground service를 사용하지 않는 것으로 신고 내용을 맞춘다. 다른 활성 트랙에 남아 있는 구버전의 권한과 신고는 별도로 확인한다. 형식적인 영상/오디오 연출을 만들지 않는다.
6. 새 빌드의 연결 수업 제어를 검증한 뒤 제출한다. 기존 공개 정책 URL은 제출 시 최신 내용을 확인하며 임의로 다시 작성하지 않는다.

이 작업에서 Play 게시/검토 제출, 운영 Firebase 배포, develop/main 병합은 수행하지 않았다.

## 근거

- https://developer.android.com/develop/background-work/services/fgs/service-types
- https://developer.android.com/reference/android/content/BroadcastReceiver#goAsync()
- https://developer.android.com/develop/ui/compose/notifications/create-notification
- https://firebase.google.com/docs/database/rest/save-data
- https://firebase.google.com/docs/database/rest/auth
- https://support.google.com/googleplay/android-developer/answer/13392821?hl=ko
