# TestFlight 자동 배포

`main` 브랜치에 코드가 푸시되거나 병합되면 GitHub Actions가 다음 순서로 동작한다.

1. 포맷, 정적 분석, 테스트를 실행한다.
2. 검증에 성공한 경우에만 macOS에서 서명된 IPA를 만든다.
3. 실행 및 재실행마다 겹치지 않는 빌드 번호를 지정한다.
4. App Store Connect API로 TestFlight에 업로드한다.

`develop` 브랜치 및 Pull Request에서는 TestFlight 업로드가 실행되지 않는다. 필요할 때 GitHub Actions 화면에서 수동으로 실행할 수도 있다.

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
- 빌드 번호: `GitHub 실행 번호 × 100 + 재실행 번호`

매장 배포 전에 GitHub의 `testflight` Environment에 승인 규칙을 추가하면, `main` 병합 뒤에도 승인 버튼을 누른 경우에만 실제 업로드되도록 운영할 수 있다.
