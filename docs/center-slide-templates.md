# 센터 전용 슬라이드 템플릿 운영

STA-193은 템플릿 조회·내용 편집·운영자 등록과 생성 단계의 PNG 출력을 다룬다. 완성된 PNG는 기존 이미지 슬라이드로 저장하며 Display, 연결, 수업 시작·진행, `WorkoutModule`, `saveWorkout` 계약을 변경하지 않는다.

## 데이터와 권한

- Firestore: `centers/{centerId}/slideTemplateCatalog/current` 한 문서. 로그인한 비익명 센터 소유자만 정확한 경로를 읽을 수 있다. 목록 조회, 초안 문서 읽기, 클라이언트 생성·수정·삭제는 금지한다.
- 원본 PNG: `center-templates/{centerId}/{templateId}/{sha256}.png`. 같은 센터 소유자만 가져오며, 목록 조회와 클라이언트 쓰기는 금지한다. 운영 도구가 원본 바이트의 해시를 사용해 새 경로에 올리고 공개 다운로드 토큰은 만들지 않는다.
- 센터 소유권은 서버의 `centers/{centerId}.ownerUid`를 사용한다. 역할 문자열, `admin`·`supportOperator` claim, Display의 `accountOwnerId`는 권한 근거가 아니다. 탈퇴 처리 중인 계정은 읽을 수 없다.
- 앱은 인증된 Storage 요청으로 원본을 가져온다. 공개·서명·장기 토큰 URL을 카탈로그에 저장하지 않는다. 사용자가 편집을 마친 결과 PNG만 기존 수업 이미지 경로를 사용한다.
- 카탈로그에는 게시된 항목만 넣는다. `published: false`인 입력 항목은 로컬 초안으로 남기고, 같은 ID가 기존 카탈로그에 있으면 공개 문서에서 제거한다. 원본 파일은 다른 저장된 작업이 참조할 수 있으므로 자동 삭제하지 않는다.

카탈로그는 `schemaVersion: 1`, 양의 정수 `revision`, `centerName`, 최대 100개 `templates`이며 UTF-8 JSON 최대 768KiB다. 센터명은 빈 문자열을 허용하며 앱에서 ‘우리 센터 템플릿’으로 표시한다. 항목은 `originalTemplateId` 또는 `recipe` 중 하나를 가진다. 레시피·좌표·색·문구·샘플의 정확한 검증은 앱의 `CenterSlideCatalogModel.fromJson(..., rejectInvalidItems: true)`와 `CenterSlideRecipe`를 사용한다. PNG가 주어지면 앱의 생성 전용 렌더러로 디코딩·해시·크기·출력 가능 여부까지 검증한다.

## 개발 환경 등록 도구

현재 도구는 `cloud-board-development`만 허용한다. 운영 프로젝트는 선택할 수 없다. `functions` Node 의존성과 Flutter 패키지가 설치된 저장소 루트에서 실행한다. Flutter 검증은 도구 전용 테스트만 수행한다.

기본 동작은 dry-run이다. 대상 계정·센터·현재 카탈로그를 읽고 로컬 JSON·이미지를 검증하지만 업로드하거나 문서를 쓰지 않는다. 인증은 Application Default Credentials가 기본이며, 로컬 Firebase CLI 로그인 계정을 재사용하려면 `--auth firebase-cli`를 지정한다. 로그인 토큰을 파일·인자·출력으로 복사하지 않는다.

대상은 `--email`의 기존 Firebase Auth 계정 → `users/{uid}/onboarding/progress.storeId` → 해당 센터의 `ownerUid` 일치로 확인한다. 계정·센터가 없거나 소유자가 다르면 실패한다. 계정 생성, 온보딩 변경, 권한·claim 부여는 하지 않는다. `readOnboarding` callable은 내부 상태를 갱신할 수 있으므로 이 도구는 직접 문서만 읽는다.

### 새 PNG 템플릿

입력은 전체 카탈로그 형식의 JSON이지만 기본으로 그 안의 항목만 기존 카탈로그에 합친다. 다른 항목을 모두 바꾸려는 경우에만 `--replace`를 지정한다. `--image`를 사용할 때 입력에는 게시할 `recipe` 항목이 정확히 하나 있어야 한다. 이미지 경로·해시가 비어 있으면 실제 바이트에서 채우고, 이미 들어 있으면 일치하는지 검사한다.

```sh
node functions/tools/register-center-slide-templates.mjs \
  --project cloud-board-development \
  --email center-owner@example.com \
  --file /tmp/sweatmonday-catalog.json \
  --image /path/to/center-template.png \
  --auth firebase-cli \
  --flutter /path/to/flutter
```

검증된 JSON을 확인하려면 `--output /tmp/validated-center-catalog.json`을 추가한다. 기존 출력 파일은 덮어쓰지 않는다. 실제 반영은 동일 명령에 `--apply`를 추가할 때만 수행한다. 적용 전후의 프로젝트·센터·리비전·항목 수를 기록하며 원시 인증 정보는 출력하지 않는다.

### 기존 7개 템플릿 초기 등록

`--seed-stationd`는 기존 7개 원본 ID를 카탈로그에 넣는 옵션이다. 대상 센터의 실제 소유 관계를 먼저 확인하고 `--center-id`를 명시해야 한다. 옵션 이름은 원본 묶음을 뜻하며 센터 이름을 임의로 설정하거나 권한을 부여하지 않는다.

이번 STA-193의 사용자 승인 범위는 개발 `center-owner@example.com` 센터에 요청 PNG와 기존 7개를 **테스트용**으로 함께 등록하는 것이다. 운영 StationD는 변경하지 않는다. 개발 대상의 실제 센터 ID는 실행 때 다시 소유권을 확인한다.

```sh
node functions/tools/register-center-slide-templates.mjs \
  --project cloud-board-development \
  --email center-owner@example.com \
  --seed-stationd \
  --center-id existing-center-id \
  --revision 1 \
  --auth firebase-cli \
  --flutter /path/to/flutter
```

센터명은 기본 빈 문자열이다. 이미 카탈로그가 있다면 현재보다 큰 리비전을 사용한다. 초기 7개를 리비전 1로 게시했다면 새 PNG 입력 JSON은 리비전 2 이상으로 만들어 기본 병합한다. 기존 7개가 이미 포함된 앱의 과거 설치본에서 원본 파일을 소급 제거하는 작업은 아니다.

## 충돌·재시도·되돌리기

적용 직전에 계정/센터 소유 관계를 다시 확인한다. 새 PNG는 `ifGenerationMatch: 0`으로 생성하므로 기존 객체를 덮어쓰지 않는다. 같은 해시 경로가 존재하면 실제 바이트와 메타데이터, 공개 토큰 부재를 확인한다. 검증 후 원격 카탈로그가 바뀌었으면 덮어쓰지 않고 실패하며, 다시 실행해 최신 내용을 병합한다.

카탈로그 변경은 트랜잭션에서 현재보다 큰 리비전을 요구한다. 완전히 같은 JSON의 재시도는 `unchanged`다. 이전 상태로 되돌릴 때도 이전 JSON의 리비전을 새 값으로 올린다. 이미지 업로드 후 카탈로그 트랜잭션이 실패하면 공개되지 않은 원본 객체가 남을 수 있지만, 기존 카탈로그는 보존된다. 이 도구는 자동 삭제나 다른 센터 재배치를 하지 않는다.

앱·규칙 배포, 카탈로그 데이터 게시, 실제 앱 확인은 별도의 결과다. 도구의 dry-run이나 단위 테스트 통과만으로 서버 반영을 보고하지 않는다.

## 관련 검증

```sh
node --test functions/test/center-slide-template-operator.test.js
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' firebase emulators:exec \
  --only firestore,storage \
  --project demo-cloudboard-center-template-tests \
  --config firebase.security-test.json \
  "node functions/test/center-slide-template-rules-emulator.mjs"
```

단위 검사는 개발 환경 제한, 기본 dry-run, 입력·대상 검증, 병합, 리비전·동시 변경·재시도, immutable 이미지 보호를 확인한다. 규칙 계약 검사는 본인/타인/다른 센터/익명/Display 계정, 카탈로그·원본 목록·쓰기, 초안 접근, 탈퇴 잠금, 기존 개인 라이브러리 격리를 확인한다. 실제 인증 SDK로 이미지를 읽는 웹/iOS/Android 편집 흐름은 통합 후 별도로 확인한다.
