# TestFlight 자동 배포

`main` 브랜치에 코드가 푸시되거나 병합되면 GitHub Actions가 다음 순서로 동작한다.

1. 포맷, 정적 분석, 테스트를 실행한다.
2. 검증에 성공한 경우에만 macOS에서 서명 없는 아카이브를 만든 뒤, 앱 배포 단계에서만 서명된 IPA로 내보낸다.
3. 실행 및 재실행마다 겹치지 않는 빌드 번호를 지정한다.
4. 아카이브의 dSYM을 Actions 아티팩트에 보관하고 Firebase Crashlytics에 업로드한다.
5. App Store Connect API로 TestFlight에 업로드한다.

`develop` 브랜치 및 Pull Request에서는 TestFlight 업로드가 실행되지 않는다. 필요할 때 GitHub Actions 화면에서 수동으로 실행할 수도 있다.

## Crashlytics 심볼 업로드

Flutter가 내려받은 Swift Package Manager의 Firebase SDK `upload-symbols` 도구로 아카이브 내 전체 dSYM을 업로드한다. Firebase 앱은 아카이브에 포함된 `GoogleService-Info.plist`로 식별하며, 별도 인증 Secret은 필요하지 않다. Runner와 Flutter App의 dSYM 누락 또는 업로드 실패 시 TestFlight 업로드 전에 작업이 실패한다.

`cloudboard-ios-dsyms-<빌드 번호>` 아티팩트는 90일간 보관한다. 재처리가 필요하면 해당 빌드의 아티팩트를 다운로드해 Crashlytics의 dSYMs 화면에 업로드한다. 예전 빌드의 누락 UUID는 그 빌드에서 생성된 dSYM으로만 보충할 수 있다.

참고: [Firebase dSYM 업로드 안내](https://firebase.google.com/docs/crashlytics/ios/get-deobfuscated-reports#upload-dsyms)

## GitHub Environment

저장소에 `testflight` Environment를 만들고 아래 Secrets를 등록한다.

- `IOS_DISTRIBUTION_CERTIFICATE_BASE64`: Apple Distribution 인증서가 포함된 `.p12` 파일의 Base64 값
- `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`: `.p12` 내보내기 암호
- `APP_STORE_CONNECT_API_KEY_BASE64`: App Store Connect의 `AuthKey_*.p8` 파일 Base64 값
- `APP_STORE_CONNECT_KEY_ID`: App Store Connect API Key ID
- `APP_STORE_CONNECT_ISSUER_ID`: App Store Connect Issuer ID

프로비저닝 프로필은 App Store Connect API 키를 사용해 Xcode가 자동으로 준비한다. 비밀 파일은 Git에 추가하지 않는다. 워크플로 실행 중 임시 키체인에 설치되며 작업 종료 시 제거된다.

## 배포 기준

- 번들 ID: `com.sunmkim.cloudboard`
- Apple Team ID: `NL7AM62SB9`
- 실행 조건: `main` push 또는 수동 실행
- GitHub Environment: `testflight`
- 빌드 번호: App Store Connect에 업로드된 최신 빌드 번호 `+1`

매장 배포 전에 GitHub의 `testflight` Environment에 승인 규칙을 추가하면, `main` 병합 뒤에도 승인 버튼을 누른 경우에만 실제 업로드되도록 운영할 수 있다.
