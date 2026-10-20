# STA-202 실제 AI 이미지 생성

2026-10-21 구현 인계. 사용자 승인에 따라 기존 OpenAI secret binding을 재사용한다. 키를 앱·fixture·문서에 넣지 않는다. 새 endpoint/승인 brand 설정은 **미배포**이다. 아래는 재현 절차이며 실제 실행 SHA·결과·재사용 근거는 PR124 및 `output/nightly/sta-202-handoff-2026-10-21.md`에 기록한다. 기존 0~4의 고정 템플릿과 JSON 디자인 제안은 그대로 유지한다.

## 사용자 흐름

수업 편집 → 이미지 만들기 → 만들기 → **센터 참고 디자인으로 AI 이미지 만들기** (`/editor/:id/images/create/raster`). 승인 참고 PNG와 공식 로고를 인증 후 확인하고 수업 원문/선택적 요청을 입력한다. 직접 1~3개 그룹으로 나누기, 그룹 제목과 고정 본문 크기(32/38/42px)를 편집할 수 있다. ‘3개 그룹 / 글자를 작게’ 요청 적용도 명시 버튼이다. 원문 줄의 운동명·숫자·단위·순서는 바꿀 수 없으며 수정은 원문 입력에서 한다. 원문 문자열 자체도 별도로 보존한다.

선택적인 **AI로 그룹 정리**는 Luna가 줄 끝 인덱스만 결정한다. 실제 원문은 서버가 그대로 잘라 그룹에 넣고 누락·추가·순서 변경을 거절한다. **이미지 생성/다시 생성**은 Sunburst로 실제 배경 한 장을 만든다. 공식 로고는 모델에 보내 다시 그리지 않고 원본 픽셀 crop을 앱에서 합성한다. 제목·그룹·본문은 정확한 앱 텍스트로 그리며 1920×1080 출력의 오른쪽 660px은 타이머용 빈 공간이다. 모델에 그림 문자/로고/타이머를 만들지 말도록 요청하고 본문 뒤의 생성 artwork는 보존한다. 우연히 생성되는 문자/장식과 가독성의 품질 판단은 실제 샘플 확인이 필요하다.

생성 중 기존 시안과 입력을 유지한다. 늦은 그룹 응답은 새 입력을 덮지 않는다. 생성 결과는 요청 당시 입력 snapshot이며 화면은 현재 입력과 다른 경우 이를 알린다. ‘표시한 시안을 수업에 추가’는 그 snapshot을 추가한다. 이전 시안 undo는 추가 AI 호출/차감 없이 복원한다. 화면 이탈은 기존 guard로 확인하며 다시 열 때 최근 접수 요청과 마지막 완료 시안을 조회한다. 미접수 로컬 입력을 버릴 때는 안내한다.

미리보기는 private artwork/공식 로고 decode와 공통 `AiRasterLayout` 직접 canvas이다. 입력 중 최종 PNG를 만들지 않는다. Add 시 서버 권한·brand·job 내용을 다시 확인하고 최종 PNG 1회만 합성/재사용한 뒤 다시 확인한다. 저장 결과는 기존 일반 이미지 슬라이드(`imageSource`, 제목, 원문)이며 `showTitle/showBody/showBrand=false`, `showTimer/showSets=false`이다. 앱 타이머는 이후 기존 수업 편집에서 설정한다. 저장/재조회/TV 재생이 AI를 호출하거나 이미 저장한 PNG를 재생성하지 않는다.

## 모델·API 근거와 비용

2026-10-21 공식 문서 확인 기준:

- [이미지 생성 가이드](https://developers.openai.com/api/docs/guides/image-generation), [Luna 모델](https://developers.openai.com/api/docs/models/gpt-6-luna): Luna Responses의 이미지 도구 지원과 텍스트 정리 용도를 확인했다. 여기서는 원문 인덱스 정리에 Responses를 쓰고 이미지별 usage를 받는 Images edits를 별도로 호출한다.
- [Images edits 공식 계약](https://developers.openai.com/api/reference/resources/images/methods/edit): `gpt-image-2.5-sunburst-2026-09-08` snapshot, multipart `image[]`, `n=1`, `quality=medium`, `output_format=png`, `background=opaque`, 해시 처리한 `safety_identifier`를 사용한다. 이 snapshot의 임의 크기 지원에 `1536x864`가 예시로 명시되어 있다. 출력은 같은 크기·PNG·4MiB 이하·단일 이미지인지 검증한다. 앱 최종 합성은 1920×1080이다.
- [Sunburst 모델/가격](https://developers.openai.com/api/docs/models/gpt-image-2.5-sunburst): Standard 텍스트 입력 $5/M, 이미지 입력 $8/M, 이미지 출력 $30/M token이다. usage 필드가 완전할 때 해당 토큰 수로 정산하며 캐시 할인은 예산 계산에 적용하지 않는 보수적 상한이다. 실제 청구액·지연·샘플 품질 측정은 아직 없다.

이미지 reserve는 **1,000,000 USD micro**로 텍스트의 10,000을 재사용하지 않는다. 이는 사용자 가격이 아니라 기존 서비스 예산 안에서 잠그는 내부 상한이다. 기존 `aiTimerBudgets` 월 $4/호출 상한은 변경하지 않으며 새 `aiSlideRasterBudgets`에 이미지 operation을 별도 기록한다. 성공 시 provider usage 기반 cost로 잠금을 정산한다. usage가 없거나 결과가 불확실하면 reserve를 유지하고 실제 비용을 확정한 것으로 쓰지 않는다. 결과가 명백히 거절된 4xx는 해당 reserve/사용량 1회를 환불한다. 5xx/408/타임아웃은 처리 여부를 알 수 없으므로 자동 환불·재요청하지 않는다.

기존 aiSlides entitlement/월 한도(서버 policy에 따른 Free/Plus/Premium/legacy)를 그대로 쓴다. 명시적 그룹 정리 1회와 이미지 생성 1회가 각각 기존 사용량 1회다. 화면에 남은 횟수·차감 시점·불확실 요청의 추가 차감 없는 상태 확인을 공개한다. 가격/플랜/사용자 한도/minBuild는 바꾸지 않는다.

## 추가 callable 계약

`cloudboardAiSlideRaster`, `asia-northeast3`, timeout 240초. 요청은 인증 사용자와 `centerId`가 필요하며 anonymous를 거절한다. 클라이언트 URL·임의 Storage 경로는 입력으로 받지 않는다.

| action | 입력 | 결과 / AI 실행 |
| --- | --- | --- |
| `context` | centerId | 현재 brand, quota, latest job, last completed job; AI 없음 |
| `organize` | rawWod, brief | 원문으로 만든 groups + quota; 명시적 Luna 1회, 동일 원문/brand 키 재사용 |
| `generate` | requestId, brandKey, draft, optional previousRequestId | job + quota; 같은 requestId/input hash는 한 번만 생성 |
| `status` | requestId | job + quota; 재생성 없음 |
| `asset` | kind=`reference`/`logo`/`artwork`, artwork일 때 requestId | 현재 권한/버전 확인한 bounded base64 PNG; 공개 URL 없음 |
| `confirm` | requestId | 현재 brand/job 재확인; PNG/AI 생성 없음 |

draft는 `{rawWod,title,brief,bodyFontSize,groups:[{heading,lines}]}`이다. job의 공개 필드는 requestId/status/brandKey/draft/artifact 해시·크기/expiresAtMs/message이며 private 경로를 내보내지 않는다. 서버는 Firestore transaction에서 request hash/사용량/shared budget/image budget을 함께 예약한다. 같은 ID의 입력을 바꾸면 거절하며 오래된 lease를 자동 재실행하지 않는다. 클라이언트 통신 실패 후 retry는 `status`만 호출한다. 결과가 불확실할 때 별도 새 요청은 사용자가 추가 차감 문구를 보고 명시적으로 선택한다.

서버 데이터:

- `users/<uid>/aiSlideRasterCenters/<center>`: latestRequestId/latestCompletedRequestId.
- 그 하위 `jobs/<requestId>`: 원문/draft/brandKey/requestHash/상태/reservation/usage/cost. 결과 접근 유효 기간은 완료 후 30일이며 기존 저장 수업 PNG에는 적용하지 않는다. 이 시간 필드는 자동 물리 삭제 설정을 뜻하지 않는다.
- `users/<uid>/ai-slide-raster/<center>/<request>/<hash>.png`: Admin 생성 private artwork. public token 없음. 클라이언트는 인증 callable로만 받는다.
- 기존 account deletion의 사용자 문서/Storage prefix 정리와 연결된다. upload 후 권한 변경/삭제로 final transaction이 거절되면 이 요청이 새로 만든 정확한 artifact만 보상 삭제한다. commit 응답이 불확실하면 durable completed job을 재조회하고 유효한 결과는 지우지 않는다. DB/Storage 모두 실패하는 보상 정리는 best effort이며 private orphan이 남을 수 있다. 이를 삭제 완료/비용 환불로 보고하지 않는다.

## 승인 brand 설정 (배포/쓰기 미실행)

새 server-owned 문서는 `centers/<center>/aiSlideBrand/current`이다. 앱이 이 문서를 쓰지 않으며 기존 rules/client contract 변경이 없다.

```json
{
  "schemaVersion": 1,
  "enabled": true,
  "revision": 1,
  "catalogRevision": 2,
  "recipeRevision": 1,
  "templateId": "approved-template",
  "name": "센터 이름",
  "reference": {"path": "center-templates/<center>/<template>/<sha256>.png", "sha256": "<sha256>", "width": 1672, "height": 941},
  "logo": {"path": "users/<owner>/brand/<file>.png", "sha256": "<sha256>", "width": 1672, "height": 941, "sourceRect": [535,300,615,265]},
  "backgroundColor": "#f4efe5",
  "textColor": "#2d302b",
  "accentColor": "#a8b691"
}
```

기존 앱의 센터 권한과 동일하게 center.ownerUid와 해당 사용자의 onboarding.storeId가 일치해야 한다. 계정 삭제 lock·entitlement도 확인한다. reference는 활성 catalog의 published entry, revision, recipe backgroundPath/hash와 정확히 같아야 한다. logo는 현재 owner의 private brand path만 허용하며 실제 PNG/hash/dimensions/crop을 검사한다. 승인 reference/로고를 공용 앱 asset에 복사하지 않는다. SWEAT 승인 원본 SHA `4b9be3ae2b21c933b507f8cf9b79451df96fdbfb98ba7d25c6836fada714b511`, 최신 로고 사용본 SHA `5c2cdb00a423dc650cd44e1b473a50d921d1e515caf6408f3e8c37367ee2ac72`를 로컬 preparation에서 고정 확인한다. 실제 센터 설정 연결/endpoint 배포는 별도 운영 요청이 필요하며 이번에는 하지 않는다.

인코딩 캐시는 repository의 환경/계정/센터 수명 안에서 brand/version/hash별 2분·20MiB LRU, 최대 동시 3요청이다. cache hit도 현재 계정/센터를 확인한다. decoded 이미지는 기존 private cache(8개, 640px, 2분)를 재사용한다. 보이는 이미지도 TTL에 재인가하며 scope/brand 해제 시 pixels를 폐기한다. 권한 확인 실패 시 offline 캐시를 권한 우회로 쓰지 않는다. 파일/공용 디스크/Flutter 전역 image cache는 사용하지 않는다.

## 관련 검증 및 로컬 준비 경로

기존 0~4 테스트 목록은 별도 handoff에 있다. 새 관련 명령:

```sh
node --test functions/test/ai-slide-raster.test.js functions/test/ai-slide-raster-fixture.test.js
flutter test --no-pub test/ai_raster_controller_test.dart test/ai_raster_page_test.dart test/ai_raster_renderer_test.dart test/ai_raster_repository_test.dart
FIRESTORE_EMULATOR_HOST=127.0.0.1:19480 node functions/test/ai-slide-raster-emulator.mjs
```

Firestore 계약은 `demo-cloudboard-raster-contract`의 별도 문서만 사용하며 provider/Storage는 fake이다. 실제 UI/callable/Storage rules/OpenAI/E2E라고 부르지 않는다. 마지막 명령은 팀장이 19480 emulator를 띄운 다음 실행한다. 전체 CI/플랫폼 빌드 명령은 포함하지 않는다.

private bundle preparation은 외부 호출 없이 아래 파일을 읽는다. 기존 디렉터리를 덮지 않는다:

```sh
node functions/tools/prepare-ai-raster-fixture.mjs \
  --catalog /tmp/sta193-sweatmonday-catalog.json \
  --reference /Users/sunmkim/Dev2026/cloud_board/output/daily-class-test/2026-10-20/sta202-source/approved-sweatmonday-original.png \
  --logo /Users/sunmkim/Dev2026/cloud_board/output/daily-class-test/2026-10-20/sta202-source/brand-asset-0.png \
  --output output/nightly/sta202/raster-local-bundle
```

`--seed-local output/nightly/sta202/raster-local-bundle`은 명시 실행 때만 `demo-cloudboard-studio`, Auth `127.0.0.1:19499`, Firestore `19480`, RTDB `19400`, Storage `19419`로 제한한다. GCLOUD_PROJECT와 4 emulator 환경 값이 모두 정확해야 하며 credentials 파일/외부 주소/다른 포트는 거절한다. uid `studio-preview`, center `studio-preview-center`, 공개 로컬 계정 `studio-preview@example.test`/`local-preview-only`만 준비한다. 기존 사용자/onboarding/entitlement를 덮지 않고 다른 fixture와 충돌하면 중단한다. catalog에는 전용 entry만 추가하며 기존 수업/슬라이드/사용량/job을 지우지 않는다. 이 도구는 키를 읽지 않고 AI 요청을 보내지 않는다. 팀장 자체 harness를 쓰는 경우 중복 seed할 필요 없다.

팀장 실제 앱 확인: 승인 reference/최신 logo → 원문 `TEAM OF 3 / Row 1,000 m / DB Squat 22.5 kg × 12 / 휴식 60초` → 직접 3그룹/작게 → 명시 이미지 1회 → artwork/정확한 로고·텍스트/타이머 blank 확인 → 입력 변경·재생성·undo → 일반 이미지 추가 → 실제 callable 저장 → 재조회/재생. 중간 timeout/status 재조회, 센터/계정 변경, brand revision 변경, quota 소진/실패도 별도 기록한다. 사용 모델/크기/소요 시간/usage/job requestId/앱 SHA/server SHA/연결 환경을 기록하되 키·토큰·개인정보는 기록하지 않는다. 공개 서버/실제 TV/Android 확인·AI 품질 샘플·외부 서비스 비용은 미확인이다.
