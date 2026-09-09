# Android TV 내부 테스트 실행 안내

이 문서는 공개 출시가 아닌 Google Play `internal` 트랙 배포만 다룬다.
내부 테스트 앱은 일반 사용자에게 검색되거나 공개되지 않는다.

## 저장소에서 준비된 항목

- 패키지명: `com.sunmkim.cloudboard`
- 모바일/Android TV 공용 AAB 빌드
- `LEANBACK_LAUNCHER` TV 런처
- 터치스크린이 필요하지 않다는 TV 호환성 선언
- 320x180 TV 배너와 160x160 TV 아이콘
- `main` 푸시 또는 수동 실행으로 내부 트랙에 업로드하는 GitHub Actions
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

1. Play Console의 **내부 테스트 > 테스터**에 이메일을 추가한다.
2. 내부 테스트 참여 URL을 전달한다.
3. 테스터는 TV에 로그인된 것과 같은 Google 계정으로 URL에서 참여한다.
4. 같은 계정의 Android TV/Google TV Play 스토어에서 CloudBoard를 설치한다.

이후 `main` 브랜치에 병합하면 새 AAB가 내부 테스트 트랙으로 자동 업로드된다.
공개 출시나 프로덕션 트랙 승격은 이 워크플로에서 수행하지 않는다.
