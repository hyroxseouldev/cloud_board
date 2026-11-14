# 홈 레이아웃과 작은 이미지 썸네일

## 범위

이번 FAB/legacy 후속 작업의 기준은 `origin/develop`의 `a6ea313cab1bdce029acf61432cb6ef5befac1c9`(Dev TestFlight 2.2.1(7))이며 소스 버전 `2.2.1+13`은 유지한다. 홈의 실제 프로필 인사, 두 줄 환영 문구, 연결 상태, 내 수업 목록을 정리한다. 브랜드·전역 내비게이션·경로·검색·폴더·페이지 전환·첫 수업 안내·활성 수업 편집 잠금은 기존 흐름을 사용한다. 좁은 화면과 큰 글꼴에서는 행의 동작 버튼을 아래로 옮기고 전체 콘텐츠를 스크롤한다.

사용자 선택 2번 목록/3번 그리드를 제공하고 미설정 계정의 기본은 그리드다. 홈 이미지는 16:9 슬롯 안에 원본 비율을 보존하는 image-only 표시다(목록 96px, 그리드 카드 폭). `WorkoutImage`, `SlideCanvas`, timer, player/preparation, 공용 이미지 loader/cache는 수정하지 않는다. 이미지가 없거나 실패하면 중립 이미지 아이콘을 표시하며 셀별 토스트는 만들지 않는다.

## 조사 결과와 확장 계약

[STA-14](sta-14-workout-thumbnails.md)의 `workoutSummaries.imageSource`는 첫 슬라이드의 원본 주소이며 작은 rendition이 아니었다. 기존 `workoutImageProvider`의 native `CachedNetworkImageProvider`, web `NetworkImage`, managed provider는 원본 본문을 받는다. `ResizeImage`/`cacheWidth`는 디코딩 메모리를 줄이며 **네트워크 전송 바이트를 줄이지 않는다**. 기존 legacy 업로드의 2560px JPEG / 3840px PNG 최적화 역시 홈 전용 작은 이미지가 아니다. 현재 managed 업로드/registry가 실제로 허용하는 원본은 10MiB 미만이며, 사용량 정책 숫자와 실제 미디어 수락 한도를 혼동하지 않는다.

코디네이터가 승인한 확장은 기존 `cloudboardMedia`의 선택적 `rendition=home-v1` 본문 경로다. `imageSource`, summary/entity 필드, 원본 URL, lease 계약, 구버전 원본 GET은 유지한다. 홈은 기존 summary source에서 자산 ID·generation을 얻으며 workout detail N+1 읽기는 하지 않는다.

- managed source: 정확한 development 프로젝트 또는 명시적인 demo loopback 주소만 사용한다. 기존 callable에서 **owner preview** lease 1회, rendition GET 1회가 최초 표시된 고유 source에 필요하다. 수업 gate/admission/start는 호출하지 않는다. 다른 계정/TV의 preview나 playback/preparation lease로 홈 rendition을 받을 수 없다.
- legacy source: 이전 클라이언트의 native small disk-cache-only 경로를 인증된 `home-v1` GET으로 대체한다. 보이는 셀의 summary `id`, 정확한 `imageSource` UTF-8 SHA-256, `updatedAt.millisecondsSinceEpoch`를 사용한다. 원본 URL/Storage token은 요청 주소·헤더에 보내지 않고 hash 계산에만 사용한다. endpoint는 개발 프로젝트의 고정 Functions origin 또는 명시적으로 주입한 demo loopback이다. 임의 origin·다른 계정·다른 bucket·운영 프로젝트는 거부한다. 원본 GET/상세 문서 N+1/legacy callable·lease·admission은 없다. 캐시가 없는 원본은 서버가 작은 파생본으로 생성하며 현재 수업·요약을 검증한다. 정확한 경로·권한·세대·등록 완료 계정의 예산 검사는 [레거시 홈 썸네일](legacy-home-thumbnails.md)을 따른다.
- embedded source: base64 길이와 실제 64KiB 한도를 확인하고 정적 PNG/JPEG만 표시한다. 잘못된 입력은 placeholder다.
- 이전 서버/미지원 원본/인증 실패: 작은 이미지 경로 실패만 처리하며 원본 GET으로 fallback하지 않는다. 네트워크 썸네일 복원은 새 서버 계약이 개발 환경에 반영된 후 사용 가능하다.

## 서버 비용·실패·보관 경계

`home-image-thumbnail.js`가 기존 `@napi-rs/canvas`로 최대 192px JPEG(품질 72), 실제 64KiB 이하를 생성한다. 원본은 변경하지 않는다. 가능한 업로드 bytes를 재사용한다. cold 요청에서 managed는 registry의 동일 generation, legacy는 현재 수업·요약으로 확인한 Storage generation만 읽는다. 임의 URL fetch는 없다.

- 후속 입력 상한은 기존 업로드 한도와 같은 **10MiB 미만**이며 metadata와 실제 stream 모두 확인한다. stream은 10초 제한이고 generation을 고정한다. managed 원본은 registry SHA를, legacy는 고정 Storage generation의 실제 본문 SHA를 파생 manifest에 기록한다.
- PNG/JPEG header를 native decode 전에 검사한다. 후속 한도는 16×1024×1024 화소, 각 변 8192 이하이며 PNG 16bit 채널은 decode 메모리 추정치를 두 배로 계산한다. APNG/GIF/WebP·지원 외 JPEG frame·잘못된 입력도 제외한다. 서버 네이티브 decode는 인스턴스당 한 번이며 대기 작업을 무제한 쌓지 않는다. 다른 생성 작업으로 바쁘면 placeholder로 종료한다.
- `users/{uid}/homeThumbnails/{assetId}-{originalGeneration}`의 server-only transaction claim은 60초 만료, source revision당 최대 두 번 시도한다. 지원 외 입력은 terminal 상태다. crash/일시 실패는 만료 이후 남은 시도만 허용한다. 두 번 소진한 revision을 자동 무한 재생성하지 않는다. 새 source generation은 새 identity다. 이전 4MP 정책의 `unsupported` manifest만 새 입력 정책에서 한 번 재평가하며, 이후 같은 정책의 unsupported 결과는 terminal이다. ready manifest와 진행 중 claim은 유지한다.
- `users/{uid}/managed-images/home-v1/{assetId}/{originalGeneration}.jpg`에 create-only로 저장하며 원본 SHA·파생 SHA·Storage generation을 고정한다. 다운로드 토큰이 없고 `private,no-store`다. 파생본도 실제 body 길이와 SHA를 검사한다. 디코드 전후 계정 삭제/원본 registry를 확인하고 삭제 중 생성된 파생 generation은 제거한다.
- **파생 저장공간은 시스템 캐시 비용**으로 source revision당 최대 64KiB + 작은 manifest 1개다. 원본 사용자 storage/upload quota를 증가시키지 않는다. 다운로드는 기존 ledger에서 manifest의 실제 rendition 크기를 transaction 검증하고 그 바이트만 예약/정산한다. 원본 크기 검증·기존 원본 quota 의미는 그대로다.
- 공유 이미지의 수업 복사/개별 수업 삭제는 기존 원본 자산 수명과 동일하다. 개별 수업 삭제에서 공유 파생본을 지우지 않으며 별도 TTL/자산 GC를 추가하지 않았다. 기존 계정 삭제의 `users/{uid}/` Storage prefix와 Firestore recursive delete가 파생 파일과 manifest도 삭제한다. 계정 삭제 후 미디어 권한은 기존 계정 잠금/세션 취소로 차단한다.

홈 캐시는 계정/로그인 상태별 auto-dispose, source의 immutable generation과 `home-v1`에 묶인다. legacy/embedded 셀의 변경에는 summary `id`와 `updatedAt`도 사용한다. 같은 legacy source라도 다른 수업은 서버가 각 summary를 검증하므로 별도 요청 identity이며 managed 복사본은 동일 generation을 공유한다. 최대 32항목×64KiB compressed bytes, 한 요청씩 실행하며 총 대기 8개를 넘기지 않는다. 뷰포트 밖 셀은 만들지 않고, 스크롤로 사라진 셀의 아직 시작하지 않은 요청은 취소한다. 같은 계정/source를 공유하는 셀은 한 요청을 재사용한다. 실패는 현재 방문에서 placeholder로 유지하고 반복 retry/toast를 만들지 않는다. 화면/계정 scope 폐기 시 전용 bytes와 해당 decoded image key만 해제한다. 전체 앱 이미지 캐시는 지우지 않는다.

## 기존 managed home-v1 검증 기록

증거는 작업 트리 밖 `/Users/sunmkim/CloudBoard-release-artifacts/2026-11-15-ux-polish/home/`에 보관한다. 인계 커밋·실제 검사 커밋과 명령/결과는 PR 및 그 디렉터리의 `report.md`에 기록한다.

- Flutter 3.47.8, 관련 홈·thumbnail widget/unit tests와 변경 파일 analyze.
- 390×844, 320×568, 320×568 글꼴 2.0의 전후 widget fixture PNG와 큰 글꼴 스크롤 후 PNG. 실제 production widgets에 로컬 repository/media를 주입한 화면이며 Firebase 앱 E2E가 아니다.
- deterministic 실제 canvas 이미지 + 로컬 HTTP gateway: 작은 rendition 본문, 원본 cold read 재사용, 동시 생성, 실패/만료 claim, malformed/oversize/animation, account/generation/token/query, stream cap, 원본 호환성.
- `home-thumbnail-emulator.mjs`: 실제 로컬 Firestore·Realtime Database·Storage와 HTTP gateway, 주입한 로컬 auth identity. 원본 12,452B → rendition 2,088B; 두 요청의 4,176B만 day/month 사용량에 정산, 예약 잔여·admission·원본 client GET 0. 위조한 크기/원본 계약 혼용/버전 변경 거부 및 기존 계정 삭제 절차의 파생파일·manifest 정리를 확인한다. 에뮬레이터 rules는 demo 기본 설정으로 보안 규칙 배포 검증은 아니다.
- 개발/운영 서비스 연결, 실제 계정 로그인·저장·클래스 쓰기, 서버 배포, TestFlight 업로드, 전체 Flutter suite, native archive는 **미실행**. 알려진 baseline remote partial-seek 실패 테스트는 수정/삭제/skip하지 않는다.
- 실제 설치 기기에서의 인증된 rendition 로딩과 TestFlight 검수는 **미확인**이며 root의 개발 서버 배포/통합 검증 단계다. 이 절의 기존 증거 시점에는 legacy cold 원본이 placeholder였다. 후속 legacy/4K 지원 검증과 남은 배포 한계는 [후속 기록](legacy-home-thumbnails.md)에 구분한다. 상한 초과·미지원 원본은 계속 placeholder다.

## 2.2.1(7) 후속: FAB와 기존 이미지 전송

- 헤더의 수업 만들기 버튼을 제거하고 `Scaffold`의 하단 우측 56×56 플러스 FAB 하나로 옮겼다. tooltip/접근성 이름은 `수업 만들기`이며 기존 `allowPlanAddition` 검사를 유지한다. 비동기 검사·편집 화면 진입 중 중복 탭을 막는다.
- 검색/키보드 중 FAB는 숨긴다. 홈 스크롤 viewport 아래 80px를 FAB 영역으로 확보하여 초기 카드와 마지막 행의 메뉴가 FAB와 겹치지 않는다. 기존 `ActiveClassShell`의 Column이 dock·safe area를 확보하므로 dock 높이를 하드코딩하지 않는다. 기존 환영 문구·브랜드·탭 목적지·재생 동작을 유지한다. navbar PR #197의 변경은 develop 동기화로만 포함했다.
- 승인 legacy 요청: `GET cloudboardMedia?rendition=home-v1&workoutId=<summary.id>&sourceHash=<sha256 exact source>&updatedAtMs=<decimal ms>`, `Authorization: Bearer <Firebase ID token>`. legacy에는 Media-Lease 헤더가 없다. managed의 assetId/v 및 owner-preview lease 계약은 그대로다.
- 응답은 `200 image/jpeg`, 실제/선언 body 길이 일치, ≤64KiB, 정적 JPEG 각 변 ≤192px일 때만 표시한다. 400/401/403/404/409/429/503, redirect, malformed, 초과 body, 오래된 summary는 중립 placeholder로 끝난다. 원본 다운로드 fallback이나 끝없는 loading/retry를 추가하지 않는다.
- 서버 담당자가 제공한 legacy 계약은 같은 owner의 현재 canonical workout+summary source/revision, configured bucket, Storage generation, 삭제/등록/인증 fence를 검증한다. 후속 backend의 원본 한도는 managed/legacy 공통 <10MiB, ≤16Mi pixels, 각 변 ≤8192의 정적 PNG/JPEG이며 기존 managed ≤2MiB/4MP 입력 범위를 확장한다. 서버 코드/배포는 별도 PR의 책임이며 이 프런트엔드 PR만으로 가용성을 보장하지 않는다.
- 클라이언트 검증은 관련 홈 widget/unit/transport 테스트와 파일별 analyze이다. real loopback HTTP + injected local auth session 테스트는 실제 client stream 경로를 확인하지만 Firebase 인증·서버 quota/Storage 통합 검사는 아니다.
- 외부 증거: `/Users/sunmkim/CloudBoard-release-artifacts/2026-11-15-home-nav/home/`. `before`는 기준 소스의 embedded-image widget, `after`의 shell 이미지는 현재 production home/router/dock에 legacy HTTP fixture를 주입한 390/320/2x widget이다. `reference/library-current-390.png`는 사용자 시안 선택용 현재 실제 라이브러리 위젯·번들 이미지 참조다. 실기기·TestFlight 검증으로 주장하지 않는다.
- 기존 `static reduced-motion skeleton fits Size(320.0, 568.0) at text scale 2.0`의 첫 viewport skeleton assertion은 기준 a6ea313에서도 재현된다(큰 환영 영역 아래 lazy skeleton이 화면 밖). `baseline-exact-loading.log`에 보관했고 테스트를 삭제/skip하지 않았다. 이번 FAB 안전 영역/기본 grid 레이아웃에서는 해당 기존 테스트도 실행하여 결과를 별도로 기록한다. 기존 remote partial-seek 실패 2개는 이번 범위에서 수정/실행하지 않았다.
- 실제 검사 SHA/명령/결과는 PR 및 외부 `report.md`에 기록한다. 개발/운영 연결·실계정/수업 쓰기·서버 배포·native build·TestFlight·전체 suite는 미실행이며 root의 최종 source 통합/개발 backend 검증이 남는다.


## 선택된 목록·그리드와 별도 검색 페이지

- 시각 기준: 외부 `card-concepts/displayed-2.png`(가로 이미지 목록), `displayed-3.png`(2열 갤러리). 신규/미설정 계정은 그리드이며 사용자 선택은 기존 SharedPreferences의 계정별 `home.workoutLayout.v1.<uid>` 키로 보관한다. 기존 저장값을 기본값으로 덮어쓰지 않는다. 기존 `WorkoutListMode.continuous/paged`의 의미와 데이터 탐색 동작은 그대로 유지하며 이 파일의 별도 표시 상태만 추가했다.
- 로컬 preference read가 늦게 끝나도 새 선택을 덮지 않는다. 쓰기는 순서를 지키고 계정 변경·로그아웃은 그리드 기본으로 시작한 뒤 해당 계정의 값만 복원한다. 저장 실패는 현재 방문 선택을 유지하고 안전한 안내를 표시한다. 수업/서버 저장 동작은 변경하지 않았다.
- 목록은 96px 가로 16:9 이미지, 제목·폴더/슬라이드·시간, 기존 재생/메뉴다. 390px에서는 같은 행, 좁은 화면·큰 글꼴에서는 동작을 아래로 옮긴다. 그리드는 390px에서 2열, 320px/큰 글꼴에서는 1열, 넓은 화면에서는 최대 3열이다. 일반 크기 grid의 긴 제목/폴더는 ellipsis로 제한하고 접근성 텍스트는 원문을 유지하며 큰 글꼴은 2줄을 허용한다. skeleton은 같은 그리드 크기를 사용한다.
- 보기 버튼은 선택 semantics/tooltip과 48px hit target을 갖는다. 보기 전환은 데이터 provider/filter/page를 재생성하지 않는다. 페이지가 account cache를 보유하여 두 보기를 바꾸거나 검색/탭에서 돌아와도 같은 identity의 body를 다시 받지 않는다. 비활성 route의 셀은 TickerMode에서 queued watch를 해제한다.
- 홈 검색은 `context.push('/search')`로 별도 최상위 route를 연다. 전역 auth redirect는 그대로 적용하고 기존 ShellRoute·MainDestination은 재구성하지 않는다. 홈 셸은 아래에 유지되어 dock 숨김/표시가 홈 viewport를 다시 배치하지 않는다. 검색이 입력·포커스를 소유하고, 뒤로 오면 기존 홈 폴더·페이지·스크롤과 보기 선택을 보존한다. 공유 `WorkoutListBody`로 데이터/카드/실패/액션 가드를 재사용하고 홈의 inline search toggle은 제거했다.
- 검색은 기존 summary catalog와 250ms debounce/loadComplete 동작을 유지한다. 새 all-list prefetch/detail 조회/다른 슬라이드 이미지 조회는 추가하지 않았다. 입력이 사라지면 debounce를 취소하고 계정 전환의 catalog 취소는 기존 controller가 처리한다. 검색 키보드/큰 글꼴은 toolbar 높이와 폴더 선택 폭을 조정한다.
- 최종 시각/전환 증거는 외부 `after-v2/`와 `design-qa.md`, 실행 commit/명령/결과/남은 제한은 `report.md` 및 PR에 기록한다. `after/`는 FAB/transport 중간 단계, `before/`는 최초 기준 소스다.
