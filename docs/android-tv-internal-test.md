# Android / TV 내부 테스트 자동 배포 안내

2026-10-06부터 첫 프로덕션 출시가 승인될 때까지 자동 배포 대상은 기존
Google Play 내부 테스트 `internal` 트랙이다. Alpha와 프로덕션의 진행 중인
심사를 다시 제출하지 않는다. 승인 후 자동으로 Alpha로 전환하지 않으며,
다음 배포 정책은 별도로 결정한다.

## 저장소에서 준비된 항목

- 패키지명: `com.sunmkim.cloudboard`
- 모바일/Android TV 공용 AAB 빌드
- `LEANBACK_LAUNCHER` TV 런처
- 터치스크린이 필요하지 않다는 TV 호환성 선언
- 320x180 TV 배너와 160x160 TV 아이콘
- `main` 푸시 또는 수동 실행으로 기존 내부 테스트 트랙에 업로드하는 GitHub Actions
- 포맷, 정적 분석, 단위/위젯 테스트 관문

## 최초 1회 준비

1. Play Console에서 `com.sunmkim.cloudboard` 앱을 만들고 Play App Signing을
   활성화한다.
2. GitHub의 `google-play` Environment에 README의 Android 서명 Secrets와
   Play 서비스 계정 JSON을 등록한다.
3. 최초 패키지는 Play Console에서 직접 생성해야 하므로, GitHub Actions의
   `Upload Android and TV to Google Play`을 `upload_to_play=false`로 실행한다.
4. 실행 결과의 `cloudboard-internal-aab-*` artifact를 내려받아 Play Console의
   **테스트 및 출시 > 테스트 > 내부 테스트**에 한 번 직접 업로드한다.
5. Play Console 서비스 계정에 해당 앱의 출시 권한을 부여하고 GitHub
   Repository Variable `GOOGLE_PLAY_BOOTSTRAPPED=true`를 등록한다.

## 테스터 이메일을 받은 뒤

1. Play Console의 **내부 테스트 > 테스터**에 Google Play 계정을 등록한 목록을 선택한다.
2. 내부 테스트 참여 URL을 전달한다:
   https://play.google.com/apps/internaltest/4700442584394694197
3. 테스터는 TV에 로그인된 것과 같은 Google 계정으로 URL에서 참여한다.
4. 같은 계정의 Android TV/Google TV Play 스토어에서 CloudBoard를 설치한다.

이후 `main` 브랜치에 병합하면 새 AAB가 기존 내부 테스트 트랙으로 자동 업로드된다.
Alpha에 등록된 계정도 내부 테스트 대상에 포함되고 위 링크에서 참여해야 한다.
내부 테스트 참여자는 Alpha 대신 내부 테스트 버전을 받는다.
공개 출시나 Alpha·프로덕션 트랙 승격은 이 워크플로에서 수행하지 않는다.

`changesNotSentForReview=true`로 추가 심사 자동 제출을 막는다. 내부 테스트
업데이트는 일반적으로 사전 심사 없이 제공되지만, Google이 검토를 요구하면
자동으로 심사 제출 설정을 바꾸거나 게시 개요의 변경사항을 전송하지 않는다.
각 실행 후 내부 테스트의 제공 상태와 기존 심사 제출 시각을 확인한다.
업로드 성공만으로 테스터 제공 완료라고 안내하지 않는다.

자동 배포 일시중지: `gh workflow disable google-play-main.yml`.
재개: `gh workflow enable google-play-main.yml`.
빌드만 필요하면 수동 실행에서 `upload_to_play=false`를 사용한다.
