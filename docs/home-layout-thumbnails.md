# 홈 레이아웃과 작은 이미지 썸네일

## 범위

기준은 `origin/develop`의 `c39617c9e6ce031b96ef9db973ed5423142140d7`(Dev TestFlight 2.2.1(6))이며 소스 버전 `2.2.1+13`은 유지한다. 홈의 실제 프로필 인사, 두 줄 환영 문구, 연결 상태, 내 수업 목록을 정리한다. 브랜드·전역 내비게이션·경로·검색·폴더·페이지 전환·첫 수업 안내·활성 수업 편집 잠금은 기존 흐름을 사용한다. 좁은 화면과 큰 글꼴에서는 행의 동작 버튼을 아래로 옮기고 전체 콘텐츠를 스크롤한다.

홈 이미지는 56×56 고정 슬롯 안에 원본 비율을 보존하는 image-only 표시다. `WorkoutImage`, `SlideCanvas`, timer, player/preparation, 공용 이미지 loader/cache는 수정하지 않는다. 이미지가 없거나 실패하면 중립 이미지 아이콘을 표시하며 셀별 토스트는 만들지 않는다.

## 조사 결과와 확장 계약

[STA-14](sta-14-workout-thumbnails.md)의 `workoutSummaries.imageSource`는 첫 슬라이드의 원본 주소이며 작은 rendition이 아니었다. 기존 `workoutImageProvider`의 native `CachedNetworkImageProvider`, web `NetworkImage`, managed provider는 원본 본문을 받는다. `ResizeImage`/`cacheWidth`는 디코딩 메모리를 줄이며 **네트워크 전송 바이트를 줄이지 않는다**. 기존 legacy 업로드의 2560px JPEG / 3840px PNG 최적화 역시 홈 전용 작은 이미지가 아니다. 현재 managed 업로드/registry가 실제로 허용하는 원본은 10MiB 미만이며, 사용량 정책 숫자와 실제 미디어 수락 한도를 혼동하지 않는다.

코디네이터가 승인한 확장은 기존 `cloudboardMedia`의 선택적 `rendition=home-v1` 본문 경로다. `imageSource`, summary/entity 필드, 원본 URL, lease 계약, 구버전 원본 GET은 유지한다. 홈은 기존 summary source에서 자산 ID·generation을 얻으며 workout detail N+1 읽기는 하지 않는다.

- managed source: 정확한 development 프로젝트 또는 명시적인 demo loopback 주소만 사용한다. 기존 callable에서 **owner preview** lease 1회, rendition GET 1회가 최초 표시된 고유 source에 필요하다. 수업 gate/admission/start는 호출하지 않는다. 다른 계정/TV의 preview나 playback/preparation lease로 홈 rendition을 받을 수 없다.
- legacy source: 현재 계정 Storage namespace의 유효한 native disk cache에 **이미** 64KiB 이하 PNG/JPEG가 있을 때만 재사용한다. web legacy, 임의 외부 URL, 없는 캐시는 placeholder다. 캐시 미스에서 원본 GET을 시작하지 않는다.
- embedded source: base64 길이와 실제 64KiB 한도를 확인하고 정적 PNG/JPEG만 표시한다. 잘못된 입력은 placeholder다.
- 이전 서버/미지원 원본/인증 실패: 작은 이미지 경로 실패만 처리하며 원본 GET으로 fallback하지 않는다. 네트워크 썸네일 복원은 새 서버 계약이 개발 환경에 반영된 후 사용 가능하다.

## 서버 비용·실패·보관 경계

`home-image-thumbnail.js`가 기존 `@napi-rs/canvas`로 최대 192px JPEG(품질 72), 실제 64KiB 이하를 생성한다. 원본은 변경하지 않는다. 가능한 업로드 bytes를 재사용하고 cold 요청은 registry의 동일 generation Storage 파일만 읽는다. 임의 URL fetch는 없다.

- 원본 metadata와 실제 stream 모두 2MiB 이하, stream 10초 제한. SHA와 generation을 대조한다.
- PNG/JPEG header를 native decode 전에 검사한다. 400만 화소(4×1024×1024), 각 변 8192 이하; APNG/GIF/WebP·지원 외 JPEG frame·잘못된 입력은 제외한다. 서버 네이티브 decode는 인스턴스당 한 번이며 대기 작업을 무제한 쌓지 않는다. 다른 생성 작업으로 바쁘면 placeholder로 종료한다.
- `users/{uid}/homeThumbnails/{assetId}-{originalGeneration}`의 server-only transaction claim은 60초 만료, source revision당 최대 두 번 시도한다. 지원 외 입력은 terminal 상태다. crash/일시 실패는 만료 이후 남은 시도만 허용한다. 두 번 소진한 revision을 자동 무한 재생성하지 않는다. 새 source generation은 새 identity다.
- `users/{uid}/managed-images/home-v1/{assetId}/{originalGeneration}.jpg`에 create-only로 저장하며 원본 SHA·파생 SHA·Storage generation을 고정한다. 다운로드 토큰이 없고 `private,no-store`다. 파생본도 실제 body 길이와 SHA를 검사한다. 디코드 전후 계정 삭제/원본 registry를 확인하고 삭제 중 생성된 파생 generation은 제거한다.
- **파생 저장공간은 시스템 캐시 비용**으로 source revision당 최대 64KiB + 작은 manifest 1개다. 원본 사용자 storage/upload quota를 증가시키지 않는다. 다운로드는 기존 ledger에서 manifest의 실제 rendition 크기를 transaction 검증하고 그 바이트만 예약/정산한다. 원본 크기 검증·기존 원본 quota 의미는 그대로다.
- 공유 이미지의 수업 복사/개별 수업 삭제는 기존 원본 자산 수명과 동일하다. 개별 수업 삭제에서 공유 파생본을 지우지 않으며 별도 TTL/자산 GC를 추가하지 않았다. 기존 계정 삭제의 `users/{uid}/` Storage prefix와 Firestore recursive delete가 파생 파일과 manifest도 삭제한다. 계정 삭제 후 미디어 권한은 기존 계정 잠금/세션 취소로 차단한다.

홈 캐시는 계정/로그인 상태별 auto-dispose, source의 immutable generation과 `home-v1`에 묶인다. legacy/embedded 셀의 변경에는 summary `updatedAt`도 사용한다. 최대 32항목×64KiB compressed bytes, 한 요청씩 실행하며 총 대기 8개를 넘기지 않는다. 뷰포트 밖 셀은 만들지 않고, 스크롤로 사라진 셀의 아직 시작하지 않은 요청은 취소한다. 같은 계정/source를 공유하는 셀은 한 요청을 재사용한다. 실패는 현재 방문에서 placeholder로 유지하고 반복 retry/toast를 만들지 않는다. 화면/계정 scope 폐기 시 전용 bytes와 해당 decoded image key만 해제한다. 전체 앱 이미지 캐시는 지우지 않는다.

## 검증과 한계

증거는 작업 트리 밖 `/Users/sunmkim/CloudBoard-release-artifacts/2026-11-15-ux-polish/home/`에 보관한다. 인계 커밋·실제 검사 커밋과 명령/결과는 PR 및 그 디렉터리의 `report.md`에 기록한다.

- Flutter 3.47.8, 관련 홈·thumbnail widget/unit tests와 변경 파일 analyze.
- 390×844, 320×568, 320×568 글꼴 2.0의 전후 widget fixture PNG와 큰 글꼴 스크롤 후 PNG. 실제 production widgets에 로컬 repository/media를 주입한 화면이며 Firebase 앱 E2E가 아니다.
- deterministic 실제 canvas 이미지 + 로컬 HTTP gateway: 작은 rendition 본문, 원본 cold read 재사용, 동시 생성, 실패/만료 claim, malformed/oversize/animation, account/generation/token/query, stream cap, 원본 호환성.
- `home-thumbnail-emulator.mjs`: 실제 로컬 Firestore·Realtime Database·Storage와 HTTP gateway, 주입한 로컬 auth identity. 원본 12,452B → rendition 2,088B; 두 요청의 4,176B만 day/month 사용량에 정산, 예약 잔여·admission·원본 client GET 0. 위조한 크기/원본 계약 혼용/버전 변경 거부 및 기존 계정 삭제 절차의 파생파일·manifest 정리를 확인한다. 에뮬레이터 rules는 demo 기본 설정으로 보안 규칙 배포 검증은 아니다.
- 개발/운영 서비스 연결, 실제 계정 로그인·저장·클래스 쓰기, 서버 배포, TestFlight 업로드, 전체 Flutter suite, native archive는 **미실행**. 알려진 baseline remote partial-seek 실패 테스트는 수정/삭제/skip하지 않는다.
- 실제 설치 기기에서의 인증된 rendition 로딩과 TestFlight 검수는 **미확인**이며 root의 개발 서버 배포/통합 검증 단계다. legacy/cold oversize/미지원 원본은 의도적으로 placeholder다.
