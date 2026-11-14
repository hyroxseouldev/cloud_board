# 기존 Storage 첫 슬라이드의 홈 썸네일

기준 소스는 `origin/develop`의 `a6ea313cab1bdce029acf61432cb6ef5befac1c9`(Dev TestFlight 2.2.1(7))이다. 소스 버전 `2.2.1+13`, 기존 `shadcn_ui 0.59.0`, 의존성·배포 설정·원본 URL과 TV 이미지 품질은 변경하지 않는다. 이 변경은 백엔드이며 홈 UI·캐시 연결 및 위젯 증거는 별도 프런트엔드 인계 범위다.

## 원인과 확인한 원본 형식

기존 홈은 managed 자산의 `home-v1` 또는 이미 존재하는 작은 native 캐시만 사용할 수 있었다. `workoutSummaries.imageSource`가 Firebase Storage 원본인 기존 수업은 cold 요청에서 작은 rendition을 만들 경로가 없었다. 기존 2MiB/4MP 입력 한도는 3840×2160 이미지도 제외했다. 기준 소스의 실제 inspector/renderer로 4K PNG를 실행하면 둘 다 `null`이었다.

현재 업로더 `workout_storage_data_source.dart`의 경로는 `users/{uid}/workouts/{workoutId}/images/{64자리 소문자 SHA256}`다. 경로의 hash는 최적화 **전** bytes로 만들고 실제 저장 bytes는 JPEG/PNG 최적화를 거칠 수 있으므로 경로 hash를 원본 본문의 SHA로 믿지 않는다. 초기 `e96f1ed`의 같은 파일은 `_workoutRoot = users/{uid}/workouts/{workoutId}` 아래 `modules/{moduleId}/background`에 저장했다. `users/{uid}/modules/...` 경로는 확인되지 않았으며 허용하지 않는다.

수업 복사본은 같은 계정의 다른 workout 경로를 참조할 수 있다. 서버는 요청한 수업의 현재 첫 이미지와 요약이 그 URL을 함께 가리키는지 확인하며, path 안의 workout ID가 요청한 수업 ID와 같아야 한다고 제한하지 않는다. 두 namespace 밖의 profile/brand/support/AI-private·외부 URL·다른 계정·다른 bucket은 허용하지 않는다.

## 선택적 기존 HTTP 계약

기존 `cloudboardMedia`에 다음 owner-only GET/HEAD 분기를 추가한다. 등록 함수나 callable 계약을 추가하지 않는다.

```http
GET /cloudboardMedia?rendition=home-v1&workoutId=<summary.id>&sourceHash=<sha256>&updatedAtMs=<milliseconds>
Authorization: Bearer <Firebase ID token>
```

- `sourceHash`: **정확한** `summary.imageSource` 문자열 UTF-8의 SHA256, 소문자 64자리. token/query를 제거하거나 URL을 재조립한 문자열을 hash하지 않는다.
- `workoutId`: ASCII `[A-Za-z0-9_-]{1,128}`. `updatedAtMs`: `summary.updatedAt.millisecondsSinceEpoch`, 정규 십진 문자열 `0..253402300799999`. 쿼리는 위 네 키만 받는다.
- 기존 deployment/demo 미디어 endpoint만 사용한다. legacy 분기는 Media-Lease를 요구하거나 만들지 않는다. client workout detail 읽기·원본 GET·수업 admission은 필요 없다.
- 성공은 `200 image/jpeg`, 실제 65,536 bytes 이하, 최대 변 192px, `Cache-Control: private,no-store`, `ETag: "home-v1-<derived sha256>"`다. HEAD는 이미 있는 파생 manifest만 확인하며 생성·예약·전송 정산을 하지 않는다.
- 잘못된 쿼리 400, 인증/폐기 토큰 401, 익명·다른 계정/TV·소스/수정 시각 불일치·삭제/등록 fence 403, 생성 중/미지원 입력 404, 적용되는 기존 전송 예산 초과 429, Storage 누락/일시 서비스 실패 503이다. 비성공은 placeholder이며 원본 fallback은 없다.
- 기존 `assetId/v` + Media-Lease의 managed `home-v1`, preview/preparation/playback 및 원본 GET/HEAD는 기존 계약을 그대로 따른다.

## 권한과 세대

레거시 요청은 revoked ID token 검사와 non-anonymous 검사를 거친다. 기존 `requireUsageContext`의 계정·RTDB authAccess·device/revocation·삭제 lock 경계를 사용하고 owner preview만 허용한다. authoritative `users/{uid}/workouts/{id}`의 id/ownerId/author.id/첫 imageUrl(누락 시 imageSource fallback)과 `workoutSummaries/{id}`의 id/source/updatedAt을 대조한다. 두 문서의 수정 시각은 클라이언트와 같이 밀리초로 내림한 값이 요청과 같아야 한다. 기존 Timestamp의 마이크로초/나노초는 버리지 않고 서버 binding에 고정하며, 두 문서의 원래 정밀도 값과 I/O 후 revision도 같아야 한다. 따라서 기존 `Timestamp.fromDate(DateTime.now)` 데이터가 정밀도 차이로 제외되지 않는다. 또한 명시적으로 빈 imageUrl을 다른 값으로 대체하지 않는다.

Storage URL은 설정된 **정확한** bucket만 받는다. Firebase HTTPS URL 또는 같은 bucket의 `gs://`를 파싱하며, demo에서만 명시적인 loopback Storage emulator를 허용한다. `alt=media`/`token` 이외의 query, 중복 query, fragment, credentials는 거부한다. token은 source identity의 일부일 뿐 접근 권한으로 쓰지 않는다. 실제 원본 읽기는 Admin Storage 파일 API로만 하며 임의 URL을 fetch하지 않는다.

매 요청은 최신 Storage metadata에서 generation을 읽는다. 원본 stream은 그 generation에 고정하며, 캐시 사용 시에도 마지막 본문 전달 전에 **현재 이름의** metadata를 다시 확인한다. 오래된 generation이 보존된 bucket에서도 원본 교체·삭제 후 예전 파생본을 내보내지 않는다. 문서·계정·인증은 생성/본문 I/O 뒤 다시 검증하고, claim 및 전송 예약 transaction에서도 현재 workout/summary/source/revision을 검증한다. Firestore·Storage·RTDB는 하나의 원자 transaction이 아니므로 마지막 검사와 응답 사이의 극소 경합 구간까지 원자성이 있다고 주장하지 않는다.

PR #198 리뷰에서 허용 범위를 명확히 했다. `enrolling` 또는 `enrollmentPending`은 계속 403으로 차단한다. `enrolled`는 **이 인증된 private home-v1 파생본에만** 예외를 둔다. 요청 전후 `requireLedgerEnabled`의 config/project/policyRevision/inventoryComplete/plan/entitlement 검사를 통과해야 하고, GET은 기존 `reserveTransfer` transaction의 day/month 잔여량·grant·`checkTransferCapacity`를 모두 통과한 실제 파생 bytes만 예약·정산한다. HEAD도 정책과 해당 파생 크기의 남은 용량을 확인하되 attempt/예약/사용량을 만들지 않는다. GET 후 검사는 이미 확보한 자기 reservation을 두 번 세지 않는다. I/O 사이 mode 변경은 거부한다.

이는 원본/direct legacy GET이나 Storage rules, enrollment/migration fence의 완화가 아니다. legacy URL을 managed asset으로 등록하지 않으며 원본을 얻으려는 쿼리는 계속 거부한다. 홈에서 계정 enrollment·asset registry·upload·class admission을 만들지 않는다. legacy/observe는 기존 meter-only 정책을 유지하고, enrolled managed 요청의 기존 quota와 원본 GET/lease 계약도 변경하지 않는다.

## 생성·메모리·보관 경계

managed/legacy 공통 입력은 **10MiB 미만**, 16×1024×1024 화소 이하, 각 변 8192 이하의 정적 PNG/JPEG다. APNG, GIF/WebP, 비지원 JPEG frame은 native decode 전에 제외한다. 기존 PNG 16bit 지원은 유지하되 메모리 입장 추정치를 두 배로 계산한다. metadata뿐 아니라 실제 stream에도 byte cap과 10초 제한을 적용한다.

인스턴스당 생성은 한 번이며 무제한 queue는 없다. native decoder 호출 전 현재 RSS + 3개 RGBA8 표면 추정치(화소×12 bytes, PNG 16bit는 ×24 bytes) + 입력 bytes×2 + 작은 출력 여유가 384MiB를 넘으면 임시 실패로 종료한다. 기존 512MiB 함수에 128MiB 여유를 남기는 보수적 입장 조건이며 Linux native allocator의 절대 peak 보장으로 해석하지 않는다. decode 이후에도 크기를 확인하고, 인코딩 완료 후 Image의 native bitmap과 loader callbacks를 즉시 해제한다. 메모리/일시 실패도 영구 무한 재시도하지 않는다.

- 자산 identity: `legacy-<sha256(bucket/path)>` + 현재 Storage generation. source revision은 bucket/path/generation/size/MIME의 hash다. 실제 원본 본문 SHA는 stream을 읽은 뒤 기록한다.
- claim/manifest: `users/{uid}/homeThumbnails/{assetId}-{generation}`. 60초 claim과 source generation당 최대 두 번 시도를 유지한다. 현재 입력 정책의 unsupported는 terminal이다. 예전 4MP 정책에서 unsupported였던 managed manifest만 새 한도 아래 한 번 재평가한다. 기존 ready manifest는 그대로 재사용한다.
- 파생 파일: `users/{uid}/managed-images/home-v1/{assetId}/{generation}.jpg`. create-only, download token 없음, private/no-store이며 원본/파생 SHA와 source revision을 검증한다. 원본 canonical URL·bytes·token·generation은 바꾸지 않는다.
- 실제 파생 body 크기만 기존 day/month ledger에 예약·정산한다. 전달 전 실패는 0, 전달 결과 불명은 기존 durable unknown 규칙을 따른다. 정산 자체가 실패하면 기존 durable reservation을 유지한다. 홈에서 class admission이나 100MB 준비 예약을 만들지 않는다.
- 파생 저장은 source generation당 최대 64KiB와 작은 manifest의 시스템 캐시 비용이다. 사용자 원본 storage/upload quota를 변경하지 않는다. 다른 수업에서 공유할 수 있으므로 개별 수업 삭제로 캐시를 제거하지 않는다. 기존 계정 삭제의 `users/{uid}/` Storage prefix 및 Firestore recursive delete로 정리하며 새 TTL/GC는 없다. 삭제 lock이 파생 저장과 경합하면 뒤늦게 생긴 파생 generation도 제거한다.

## 검증 기록

외부 아티팩트: `/Users/sunmkim/CloudBoard-release-artifacts/2026-11-15-home-nav/backend/`. PR과 `report.md`가 최종 인계 SHA·실제 검사 소스·명령·제약을 연결한다.

- 관련 Node unit/실제 local HTTP 검사: source 권한/세대/삭제/등록 fence, 두 legacy namespace, 복사 수업, 실제 PNG/JPEG renderer, managed 및 원본 계약, claim 동시성/만료/실패/재사용, header/stream/memory cap, post-I/O 철회 및 late-delete 정리.
- 로컬 Firestore/RTDB/Storage + HTTP: 3840×2160 PNG 66,620B → 192×108 JPEG 3,793B, 기존 2560×1440 JPEG 67,438B → 4,069B. 두 파일 각각 반복 요청에서 원본 stream 1회. generation 교체를 포함한 5회 성공의 **19,517B**를 day/month에 정산, 삭제 경합의 1회 실패는 0B. 남은 reservation/unknown 0, admissions/원본 registry/업로드 0. 실제 계정 삭제와 동일한 prefix/recursive 연산으로 파생 파일·manifest 제거 확인.
- 기존 enrolled managed 에뮬레이터: 12,452B → 2,088B, 두 번 4,176B 정산과 quota 초과 429 유지. managed 원본 GET 정확한 bytes는 기존 HTTP 계약 검사에서 확인한다.
- 별도 renderer 프로세스(Node 22.21.1, macOS x64/Rosetta): 4K PNG peak RSS 약 125.5MiB, 최댓값 4096² PNG 4,108,734B는 약 179.8MiB, 4096² JPEG 8,284,415B는 약 187.8MiB. 4K 원본을 32회 연속 디코드한 별도 프로세스도 모두 성공했고 peak RSS는 약 132.7MiB였다. 테스트용 대형 canvas 생성은 별도 fixture 프로세스로 격리해 서버 RSS 측정에 섞지 않았다. 이는 로컬 측정이며 배포 Linux/Cloud Functions의 실제 cold-start/동시 runtime peak는 미확인이다.

Auth identity는 에뮬레이터 HTTP fixture에 주입했다. 실제 Firebase 로그인/callable 인증, 보안 규칙 배포, 개발·운영 외부 서비스, 실제 계정/수업 쓰기, 배포/backfill/IAM/새 함수 등록, TestFlight 및 native build는 미실행이다. 원본 작업 폴더는 수정하지 않았다. 위젯 전후 PNG와 앱 통합은 홈 프런트엔드 담당 및 root 범위이며 이 백엔드 검사만으로 완료를 주장하지 않는다. 알려진 baseline remote partial-seek 두 실패는 수정·삭제·skip하지 않았다.

### 등록 완료 계정 리뷰 보완 검증

`backend/enrolled-review/`에 추가 증거를 보관한다. 실제 emulator에서 enrolled legacy cold GET과 정확히 한 파생본만 남은 잔여량의 GET, day/month grant 사용을 확인했다. 파생본 3,793B를 세 번 전달한 attempt의 실제 bodyBytes 합계는 11,379B이며 원본 stream은 1회였다. grant는 day/month 각각 3,793B를 정확히 사용했다. day/month 각각 및 동시 quota 초과는 429이며 추가 attempt가 없다. enrolling/pending은 403, 비활성/만료 entitlement·잘못된 account/config policy·비활성/다른 project config·미완료 inventory는 기존 ledger의 오류 매핑에 따른 400으로 막으며 원본 stream/attempt를 만들지 않는다. 실제 derivative I/O 중 entitlement 철회와 account mode 변경은 본문 전달 전 차단하고 0B로 정산한다. 이 확인은 로컬 Firebase와 주입 auth의 서버 계약 검사이며 실제 로그인·설치 앱·배포는 미실행이다. 기존 c372f98의 managed/original 호환 및 native memory 증거는 해당 분기·renderer·Storage rules가 변경되지 않아 재사용한다.
