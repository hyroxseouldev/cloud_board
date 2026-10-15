# TestFlight 자동 배포

`main`에 관련 Flutter/iOS 변경이 병합되면 기존 앱 `com.sunmkim.cloudboard`를
운영 Firebase `cloud-board-stationd`로 빌드해 TestFlight에 올린다. 전체 Flutter/TV CI를
반복하지 않으며, 별도로 실행되는 개발 웹·서버 배포를 기다리지 않는다. 현재 운영 서버와의
호환성 확인과 기능 담당자의 관련 검증 인계는 유지한다.

`vX.Y.Z` 릴리즈 태그의 필수 CI가 성공하면 같은 앱의 release 모드가
`workflow_run`으로 시작한다. 태그의 main 포함 여부, 태그 이동 여부, 앱 버전 일치,
동일 소스의 공통 검증과 현재 운영 백엔드 호환성을 확인한 뒤 업로드한다.
태그 CI가 실패·대기 중이면 release 모드 업로드를 시작하지 않는다.

자동화의 마지막 단계는 TestFlight 업로드다. App Store 공개·심사 제출이나 테스터 그룹 변경은 하지 않는다.
배포 대상 그룹은 App Store Connect의 현재 설정을 따른다. QA 모드는 Apple의
별도 `TestFlight Internal Only` 제한을 뜻하지는 않는다.

QA와 release는 기존 `testflight` GitHub 환경의 Apple 계정 인증, 앱 ID, 빌드 번호 체계를
공유한다. 업로드 작업도 같은 동시 실행 그룹에서 직렬화한다. 별도 `.dev` 스토어 앱이나
`MOBILE_DEVELOPMENT_READY` 설정은 필요 없다. 실제 IPA의 운영 Firebase 연결을 검사한다.
개발 웹·서버는 `cloud-board-development`로 배포되므로 TestFlight에서 그 데이터를 보거나
아직 개발 서버에만 있는 API를 시험할 수는 없다. 운영 연결 QA도 설치 클라이언트 계약 추적에 포함한다.

내보낸 실제 IPA의 Apple 로그인 권한과 내장 프로비저닝 프로파일을 검사하고,
`cloudboard-ios-signing-<빌드 번호>` 아티팩트에 진단 결과를 90일간 보관한다.
앱과 프로비저닝 프로파일의 Apple 로그인 권한, Team/Bundle ID, Firebase Auth 키체인 접근 그룹,
배포용 `get-task-allow` 값을 검사한다. 누락·불일치 시 TestFlight 업로드를 중단한다.
인증서·프로비저닝 원문이나 비밀키는 보고서에 포함하지 않는다.

`flutter build ipa --no-codesign`으로 만든 아카이브에는 소스의 사용자 지정 권한이 서명에 포함되지 않는다.
`xcodebuild -exportArchive`가 이를 누락하지 않도록 `tool/prepare_ios_entitlements.py`가 Runner에만
원본 권한을 임시로 넣는다. 확장 앱에 Runner의 권한을 복사하지 않으며, 최종 배포 서명은 Xcode가 수행한다.
Xcode 빌드 설정의 알 수 없는 변수가 남으면 실패한다. 새 권한·확장 타깃을 추가하면 이 단계도 함께 검토한다.

`develop` 및 Pull Request에서는 자동 업로드하지 않는다. 수동 실행은 main 워크플로에서
`release_mode=qa`와 main/develop 계열 `source_ref`를 선택하거나, `release_mode=release`와
검증된 `vX.Y.Z` 태그를 선택한다. `upload_to_testflight=false`이면 서명 IPA만 보관하며
실제 TestFlight·Crashlytics 업로드는 하지 않는다. QA 업로드는 공개 업데이트 소식과 최소 지원 버전을 바꾸지 않는다.

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

- 번들 ID: QA·release 모두 `com.sunmkim.cloudboard`
- Apple Team ID: `NL7AM62SB9`
- 실행 조건: 관련 `main` push는 QA, 태그 CI 성공은 release, main에서 수동 재실행 가능
- GitHub Environment: `testflight`
- 빌드 번호: 해당 번들의 전체 App Store Connect 이력 중 최대 빌드 번호 `+1`

구체적인 경로·빌드 번호·검증 조건은 [Native release 안내](../tool/release/README.md)를 따른다. 이 문서 수정만으로 실제 스토어 등록이나 GitHub 환경 변수가 설정되지는 않는다.
