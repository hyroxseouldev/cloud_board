# AI 슬라이드 로컬 미리보기

운영 배포 없이 기본 디자인, AI 제안, 참고 이미지와 센터 템플릿 저장을 확인하는 Debug 전용 진입점입니다. Firebase 데이터는 `demo-cloudboard-studio` 로컬 에뮬레이터에만 저장합니다. AI 생성은 기존 `functions/.secret.local`의 OpenAI 연결을 사용하므로 실제 API 요청입니다. 키 값은 출력하지 마세요.

1. Java 21 이상, Firebase CLI, functions 의존성을 준비합니다.
2. 저장소 루트에서 `AI_TIMER_SECRETS_ENABLED=true firebase emulators:start --config firebase.studio-preview.json --project demo-cloudboard-studio --only auth,firestore,database,storage,functions`를 실행합니다.
3. 다른 터미널에서 `node tool/studio-preview/seed.mjs`로 예제 센터를 준비합니다.
4. `python3 tool/studio-preview/ios_config.py prepare`로 iOS 네이티브 기본 앱을 같은 로컬 프로젝트에 맞춥니다. 원래 설정은 저장소 밖에 임시 보관됩니다.
5. `.fvm/flutter_sdk/bin/flutter run -t lib/main_studio_preview.dart --dart-define=CLOUDBOARD_DATABASE_URL=https://demo-cloudboard-studio-default-rtdb.asia-southeast1.firebasedatabase.app`로 iOS 시뮬레이터를 실행합니다.

6. 빌드 후 `python3 tool/studio-preview/ios_config.py restore`로 원래 iOS 설정을 반드시 복원합니다. 설치한 미리보기 앱은 로컬 연결을 유지합니다.

미리보기 계정 이름은 **디자인 미리보기**입니다. 앱에서 워크아웃을 만들고 **수업 슬라이드 만들기**를 여세요. 운영용 앱은 기존 `lib/main.dart`로 빌드하면 됩니다. 이 진입점은 Release 빌드에서 실행되지 않습니다.

에뮬레이터 종료 시 기본적으로 데이터는 사라집니다. 검수용 템플릿·워크아웃을 보관하려면 Firebase Emulator Suite의 export/import를 사용하세요. 새로운 callable과 Firestore rules는 별도 배포 전에는 운영 앱에서 사용할 수 없습니다.

템플릿 화면에는 프리미엄 원본 7종과 일반 디자인 4종이 표시됩니다. 별도 `dart-define` 없이 일반 앱과 로컬 미리보기에서 동일하게 선택할 수 있습니다. 기존 사용자 계정 검수는 iOS 설정을 복원한 후 `lib/main.dart`로 빌드하며, 에뮬레이터 진입점과 데이터베이스 주소 재정의를 사용하지 않습니다.
