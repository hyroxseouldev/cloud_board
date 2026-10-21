# 센터 전용 슬라이드 템플릿 운영

STA-193의 센터 템플릿은 브랜드 로고·색상·장식을 유지하면서, 입력한 와드 내용에 맞게 글자와 배치를 조정한다. 기존 7종과 SWEATMONDAY, 총 8종을 서버의 비공개 배경 PNG와 recipe v2로 구성한다. 적용 대상은 개발 프로젝트 `cloud-board-development`의 확인된 테스트 센터이며 운영 프로젝트에는 적용하지 않는다.

변경 범위는 템플릿 조회·내용 편집·운영자 등록과 **생성 단계의 PNG 출력**이다. 완성된 PNG는 기존 이미지 슬라이드로 저장한다. Display, 연결, 수업 시작·진행, 타이머 동작, `WorkoutModule`, `saveWorkout` 계약은 변경하지 않는다. 과거에 저장된 원본 참조 수업과 해당 렌더러·앱 자산도 유지한다.

## 편집과 배치

recipe v2에서는 제목·분류·안내 문구를 별도로 편집하고, 본문 전체를 하나의 **‘와드 내용’** 입력란에 붙여 넣는다. A/B/C 위치별 입력 개수에 맞출 필요가 없다. 입력 순서·운동 번호·글머리표·빈 줄을 보존하며, `A. Running`, `B) Strength`, `## 마무리`처럼 구역을 나눌 수 있다. `## ` 표시는 출력에서 제거하지만 A/B 접두사는 유지한다. `1. Bench Press` 같은 숫자 운동 목록은 구역 제목으로 취급하지 않는다.

본문은 최대 60줄, 한 줄 최대 240자, 줄바꿈을 포함한 전체 최대 6,000자다. 글자 수는 Dart `runes`, 즉 Unicode code point 기준이다. 비어 있는 본문과 탭 등 제어 문자는 허용하지 않는다. 입력란의 CRLF·CR 줄바꿈은 LF로 정규화하고, 개별 줄 안에 줄바꿈을 중복 저장하지 않는다.

렌더러는 한 단부터 최대 세 단까지 비교해 읽기 좋은 배치를 고르며 구역을 단 사이에서 쪼개지 않는다. 긴 구역은 넓은 한 단 배치로도 확인한다. 1920×1080 출력에서 본문 글자를 최소 32px로 유지할 수 없으면 생성하지 않고 ‘내용을 여러 슬라이드로 나눠 주세요’라고 안내한다. 원문을 잘라내거나 자동 삭제하지 않으므로 사용자가 내용을 나누어 다시 생성한다. 글자 수 제한을 만족해도 실제 글자 폭과 구역 구성에 따라 한 장에 들어가지 않을 수 있다.

편집 미리보기는 입력 후 짧게 기다렸다 갱신한다. 같은 계정·센터·recipe를 편집하는 동안에는 새 미리보기를 만드는 중 기존 그림을 유지하고, 계정이나 템플릿이 바뀌면 재사용하지 않는다.

이 변경이 포함된 앱은 recipe v1의 고정 좌표·줄별 편집 방식도 계속 지원한다. 반대로 v2를 모르는 구버전 앱은 v2 항목을 표시하지 못하므로 해당 센터의 앱을 먼저 갱신한 뒤 카탈로그를 전환해야 한다. 기존에 저장된 이미지 수업의 재생에는 영향이 없다. v1에 `body`를 추가하거나 저장된 수업을 일괄 변환하지 않는다. 새 8종을 선택할 때 v2 본문 배치를 사용하며, 열려 있던 편집 내용을 강제로 교체하지 않는다.

## 데이터와 권한

- Firestore: `centers/{centerId}/slideTemplateCatalog/current` 한 문서. 로그인한 비익명 센터 소유자만 정확한 경로를 읽는다. 목록 조회, 초안 문서 읽기, 클라이언트 생성·수정·삭제는 금지한다.
- 배경 PNG: `center-templates/{centerId}/{templateId}/{sha256}.png`. 같은 센터 소유자만 읽는다. 운영 도구가 실제 바이트의 SHA-256으로 새 경로에 올리며, 클라이언트 쓰기·목록 조회와 공개 다운로드 토큰 발급을 허용하지 않는다.
- 센터 소유권은 서버의 `centers/{centerId}.ownerUid`로 판단한다. 역할 문자열, `admin`·`supportOperator` claim, Display의 `accountOwnerId`로 권한을 부여하지 않는다. 탈퇴 처리 중인 계정도 차단한다.
- 앱은 현재 사용자의 인증 토큰을 넣은 Storage 요청으로 배경을 읽는다. 카탈로그에 공개·서명·장기 토큰 URL을 저장하지 않는다. 편집을 마친 **결과 PNG**만 기존 수업 이미지 저장·다운로드 계약을 사용한다.
- 게시할 항목만 서버 카탈로그에 넣는다. 입력의 `published: false` 항목은 공개 문서에서 같은 ID를 제거하는 의미이며, 초안 자체는 로컬에 보관한다. 배경 파일은 자동 삭제하지 않는다.

카탈로그의 `schemaVersion`은 계속 **1**이다. 양의 정수 `revision`, `centerName`, 최대 100개 `templates`를 가지며 UTF-8 JSON 최대 크기는 768KiB다. 센터명은 빈 문자열을 허용하고 앱에서는 ‘우리 센터 템플릿’으로 표시한다. 항목은 `originalTemplateId` 또는 `recipe` 중 하나를 가지며, 이전 원본 참조를 읽는 호환성은 유지한다.

recipe의 버전은 카탈로그 버전과 별개다. v1은 고정 `fields`를 사용하고, v2는 제목·부제·헤더용 `fields`와 본문용 `body`를 가진다. v2 본문에는 개별 `line` 슬롯을 두지 않는다. 배경 PNG에는 로고·색상·장식만 남기고 편집할 문구와 번호를 포함하지 않는다. 파일은 최대 10MiB이며 recipe의 크기·경로·해시와 일치해야 한다. 실제 검증은 앱의 `CenterSlideCatalogModel`, `CenterSlideRecipe`와 생성 렌더러를 공유한다.

이번 8종 전환은 기존 항목 ID를 유지한다. 카탈로그는 revision 3, 새로 recipe로 바꾸는 기존 7종은 recipe revision 1, SWEATMONDAY는 recipe revision 2를 사용한다. 각 `sample`에는 제목·부제·헤더·전체 본문·시간을 명시한다. SWEATMONDAY의 기본 시간은 운동 300초·휴식 100초·2세트이며, 기존 7종은 보관된 샘플을 우선 사용하고 시간이 없으면 기존 기본값 60초·0초·1세트를 사용한다.

## 8종 배경과 카탈로그 로컬 생성

`tool/center_slide_brand_catalog_export_test.dart`는 이번 전환을 위한 로컬 생성 도구다. Firebase를 초기화하거나 원격 데이터를 변경하지 않는다. 저장소 루트에서 실행하며 recipe v2 모델과 생성 코드가 준비돼 있어야 한다.

| 환경변수 | 의미 |
| --- | --- |
| `CENTER_BRAND_EXPORT=1` | 명시적으로 내보내기를 실행한다. 없으면 테스트를 건너뛴다. |
| `CENTER_BRAND_INPUT` | 전환 전 SWEATMONDAY recipe와 명시적 sample을 포함한 카탈로그 JSON. 기존 7종 항목이 있으면 이름·정렬·샘플을 참조한다. |
| `CENTER_BRAND_SWEAT_IMAGE` | 검토된 1672×941 SWEATMONDAY 원본 PNG의 로컬 경로. |
| `CENTER_BRAND_OUTPUT` | 저장소 원본과 분리된 출력 폴더. 새 폴더 사용을 권장한다. |
| `CENTER_BRAND_PREVIEW_WOD` | 선택 사항. 모든 브랜드에서 추가로 확인할 전체 와드 텍스트 파일. |

```sh
CENTER_BRAND_EXPORT=1 \
CENTER_BRAND_INPUT=/tmp/center-templates-before-v2.json \
CENTER_BRAND_SWEAT_IMAGE=/path/to/sweatmonday-source.png \
CENTER_BRAND_OUTPUT=/tmp/center-templates-v2 \
flutter test tool/center_slide_brand_catalog_export_test.dart --no-pub
```

입력의 SWEATMONDAY 샘플은 전환 전 원문 18줄과 300/100/2 시간을 요구한다. 도구가 여기에 `## A`, `## B`, `## C` 구역 제목을 추가한다. 이미 변환된 21줄 샘플을 다시 원문 입력으로 사용하지 않는다. 이 도구의 전환 출력은 revision 3으로 정해져 있으므로, 나중에 내용을 수정해 재게시할 때는 현재 서버보다 큰 카탈로그 리비전을 별도로 지정해야 한다.

생성 결과는 `catalog.json`, ID→절대 PNG 경로를 담은 `images.json`, `backgrounds/*.png`, `previews/*.png`, 원본 무변경 확인용 `source-digests.json`이다. 추가 와드 파일을 지정하면 `previews/*-wod.png`도 만든다. 모든 배경은 1920×1080이다. 원본 자산의 해시가 바뀌지 않았는지 확인하고, 전체 샘플 렌더 검증을 마친 뒤 출력한다. 배경의 로고·색상과 샘플 미리보기의 가독성을 확인한 후 게시한다.

`tool/center_slide_export_fonts.dart`는 로컬 내보내기와 등록 검증에서 앱의 Pretendard, RacingSansOne, NotoSerifKR 폰트를 로드한다. Flutter 테스트의 기본 대체 글꼴로 검증하면 실제 폭과 줄바꿈이 달라질 수 있으므로 공통 폰트 로딩을 유지한다.

## 개발 환경 등록 도구

`functions/tools/register-center-slide-templates.mjs`는 **`cloud-board-development`만 허용**한다. 운영 프로젝트는 거부한다. `functions`의 Node 의존성과 Flutter 패키지가 설치된 저장소 루트에서 사용한다. ADC가 기본 인증이며, 로컬 Firebase CLI 로그인 계정을 재사용하려면 `--auth firebase-cli`를 지정한다. 토큰을 인자·출력·문서로 복사하지 않는다.

대상은 `--email`의 기존 Firebase Auth 계정 → `users/{uid}/onboarding/progress.storeId` → 센터 `ownerUid` 일치로 확인한다. `--center-id`를 주면 해당 센터와도 일치해야 한다. 계정·센터 생성, 온보딩 변경, claim 부여는 하지 않는다.

기본 동작은 dry-run이다. 현재 서버 상태를 읽고 파일을 검증하지만 PNG를 올리거나 문서를 쓰지 않는다. 실제 반영은 `--apply`를 명시할 때만 수행한다. 입력 항목은 기본으로 기존 카탈로그에 ID별 병합하며, 입력하지 않은 항목은 유지한다. 전체 교체는 `--replace`를 명시할 때만 수행한다.

### 여러 PNG의 단일 카탈로그 게시

`--images`는 다음과 같은 ID→로컬 PNG 경로 JSON을 받는다. 상대 경로는 대응표 파일의 폴더를 기준으로 해석한다. URL은 받지 않는다.

```json
{
  "reference-stationd-mon-v1": "backgrounds/reference-stationd-mon-v1.png",
  "sweatmonday-team-of-3-v1": "backgrounds/sweatmonday-team-of-3-v1.png"
}
```

대응표는 입력 카탈로그의 게시된 모든 recipe와 정확히 일치해야 한다. 누락·추가·중복 ID, 비공개 또는 원본 참조 항목에 대한 PNG, 잘못된 파일을 거부한다. 일부만 바꾸려면 해당 항목들만 카탈로그 입력과 대응표에 넣어 기본 병합한다. 이번 8종 전환에서는 내보낸 8개 전체를 함께 사용한다.

```sh
node functions/tools/register-center-slide-templates.mjs \
  --project cloud-board-development \
  --email center-owner@example.com \
  --center-id existing-center-id \
  --file /tmp/center-templates-v2/catalog.json \
  --images /tmp/center-templates-v2/images.json \
  --auth firebase-cli \
  --flutter /path/to/flutter \
  --output /tmp/center-templates-v2/validated-catalog.json
```

모든 매핑·PNG·해시·센터 연결을 먼저 확인하고, 공유 Dart 모델과 렌더러로 각 이미지 및 샘플을 전부 검증한다. 그다음 현재 카탈로그와의 병합·리비전을 검사한다. **첫 업로드 전에 전체 검증이 끝나야 하며**, 모든 PNG 업로드와 실제 바이트 재검증이 성공한 뒤 **단일 Firestore 트랜잭션**으로 카탈로그를 게시한다. 이미지 업로드 자체와 Firestore 문서 변경이 하나의 분산 트랜잭션인 것은 아니다.

dry-run 결과를 확인한 뒤 같은 명령에 `--apply`를 추가한다. `--output`은 기존 파일을 덮어쓰지 않으므로 적용 명령에서는 해당 옵션을 빼거나 새 파일명을 쓴다. 결과의 `imageCount`는 준비한 PNG 수이며 새로 쓴 객체 수를 뜻하지 않는다.

### 기존 옵션 호환

`--image /path/to/image.png`는 입력에 게시할 recipe가 하나일 때 계속 사용할 수 있다. `--images`와 동시에 지정할 수 없다. 경로·해시가 비어 있으면 실제 바이트에서 채우고, 이미 있으면 일치하는지 검사한다.

`--seed-stationd --center-id ... --revision ...`도 기존 7개 `originalTemplateId` 참조를 만드는 호환 옵션으로 남긴다. 서버 PNG를 만드는 옵션은 아니므로 이번 v2 전환에는 사용하지 않는다. seed에는 `--image`나 `--images`를 함께 지정하지 않는다.

## 웹 이미지 읽기와 캐시

인증된 비공개 PNG를 브라우저에서 직접 읽으려면 버킷 CORS 설정도 필요하다. 규칙과 OPTIONS가 정상이어도 실제 이미지 GET 응답에 `Access-Control-Allow-Origin`이 없으면 웹에서 실패한다. [Firebase 공식 안내](https://firebase.google.com/docs/storage/web/download-files#cors_configuration)를 따른다.

개발 버킷은 `http://localhost:8080`, `http://127.0.0.1:8080`의 GET을 허용한다. 운영 버킷에는 이번 설정을 적용하지 않았다. CORS는 인증이나 센터 소유권 규칙을 대체하지 않는다. 확인할 때에는 사전 요청뿐 아니라 로그인한 브라우저의 실제 이미지 응답과 생성·저장까지 살핀다.

전환된 8종은 모두 서버 배경을 읽는다. 동일한 최초 요청은 하나로 합치며, 읽은 배경은 현재 프로젝트·계정·센터의 권한 범위에서 메모리 캐시로 재사용한다. 계정·센터 변경이나 권한 오류 때 기존 내용을 공유하지 않는다. 서버에서 확인한 카탈로그 권한은 최대 6시간이며 캐시 이벤트만으로 연장하지 않는다. 비공개 PNG나 인증 토큰을 공개 이미지 캐시·카탈로그 URL에 저장하지 않는다.

## 충돌·재시도·롤백

적용 직전에 대상 소유 관계를 다시 확인한다. PNG는 `ifGenerationMatch: 0`으로 생성해 기존 해시 경로를 덮어쓰지 않는다. 경로가 이미 있으면 메타데이터·실제 SHA·크기와 공개 다운로드 토큰 부재를 확인한다. 적용 중 소유권이나 카탈로그가 바뀌면 해당 변경을 덮어쓰지 않는다.

후반 이미지 업로드나 카탈로그 트랜잭션이 실패하면 기존 카탈로그는 유지된다. 먼저 올라간 PNG는 해당 센터의 비공개 객체로 남을 수 있다. 같은 명령을 재실행하면 기존 객체를 검증하고 이어서 진행한다. 완전히 같은 카탈로그가 이미 게시됐으면 `unchanged`이며, 이미지를 자동 삭제하지 않는다.

전환 전 카탈로그를 별도로 보관한다. 롤백도 현재보다 큰 새 카탈로그 리비전으로 게시한다. 예를 들어 revision 3 전환을 되돌리려면 이전 내용을 revision 4 이상으로 등록하고, 유지할 다른 항목을 함께 확인한다. 이전 revision을 그대로 덮어쓰거나 새 PNG를 삭제하지 않는다. 기존 수업과 열려 있는 편집 내용을 일괄 변환하지 않는다.

## 확인 항목

```sh
node --test functions/test/center-slide-template-operator.test.js
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' firebase emulators:exec \
  --only firestore,storage \
  --project demo-cloudboard-center-template-tests \
  --config firebase.security-test.json \
  "node functions/test/center-slide-template-rules-emulator.mjs"
```

로컬 검증은 v1 호환, v2 본문 입력·구역 보존·최소 글자 크기·넘침 안내, 8종 실제 폰트 렌더링, 다중 PNG 사전 검증·중간 실패·재시도·소유권 보호를 확인한다. 게시 후에는 대상 센터의 카탈로그 리비전·8개 recipe, 원격 PNG의 실제 SHA·크기·공개 토큰 부재를 다시 읽어 확인한다.

실제 웹·iOS·Android 편집 화면에서는 전체 와드 붙여 넣기, 내용 변경, 미리보기, 생성과 저장을 확인한다. 저장된 결과가 기존 이미지 모듈이며 `designTemplate`, `designStyle`, `designFingerprint`를 새 recipe 정보로 채우지 않는지 확인한다. 테스트·dry-run 통과, 서버 게시, 앱에서의 실제 확인은 각각 별도의 결과로 기록한다. 이 문서는 운영 적용이나 수업 재생 검증 완료를 의미하지 않는다.
