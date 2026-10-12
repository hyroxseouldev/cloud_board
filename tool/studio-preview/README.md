# AI 슬라이드 로컬 미리보기

운영 배포 없이 기본 디자인, AI 제안, 참고 이미지와 센터 템플릿 저장을 확인하는 Debug 전용 진입점입니다. Firebase 데이터는 `demo-cloudboard-studio` 로컬 에뮬레이터에만 저장합니다. AI 생성은 기존 `functions/.secret.local`의 OpenAI 연결을 사용하므로 실제 API 요청입니다. 키 값은 출력하지 마세요.

1. Java 21 이상, Firebase CLI, functions 의존성을 준비합니다.
2. 저장소 루트에서 `AI_TIMER_SECRETS_ENABLED=true firebase emulators:start --config firebase.studio-preview.json --project demo-cloudboard-studio --only auth,firestore,database,storage,functions`를 실행합니다.
3. 다른 터미널에서 `node tool/studio-preview/seed.mjs`로 예제 센터를 준비합니다.
4. `.fvm/flutter_sdk/bin/flutter run --flavor development -t lib/main_studio_preview.dart --dart-define=FIREBASE_ENV=development`로 iOS 시뮬레이터를 실행합니다. iOS 빌드 단계가 설치할 앱의 Firebase 설정만 `demo-cloudboard-studio`로 맞춥니다. 저장소의 개발·운영 설정 파일은 수정하지 않으므로 별도 복원 작업이 필요하지 않습니다.

미리보기 계정 이름은 **디자인 미리보기**입니다. 앱에서 워크아웃을 만들고 **수업 슬라이드 만들기**를 여세요. 이 진입점은 development Debug 빌드에서만 실행됩니다. 일반 개발 앱은 `lib/main.dart`와 development flavor를 사용합니다.

에뮬레이터 종료 시 기본적으로 데이터는 사라집니다. 검수용 템플릿·워크아웃을 보관하려면 Firebase Emulator Suite의 export/import를 사용하세요. 새로운 callable과 Firestore rules는 별도 배포 전에는 운영 앱에서 사용할 수 없습니다.

템플릿 화면에는 프리미엄 원본 7종과 일반 디자인 4종이 표시됩니다. 템플릿 활성화용 `dart-define` 없이 일반 앱과 로컬 미리보기에서 동일하게 선택할 수 있습니다. 운영 계정 검수는 `lib/main.dart`와 production flavor로 별도 빌드하며, Debug 검수가 필요하면 `ALLOW_PRODUCTION_DEBUG=true`도 명시해야 합니다. 로컬 미리보기 진입점에서는 운영 Firebase를 선택할 수 없습니다.
