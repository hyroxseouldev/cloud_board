# STA-122: 수업 준비 성능 및 오류 안내

기준 커밋은 `develop`의 `7f8e2b396f076c5034c1b41035cacf5da98292cd`이며,
STA-123부터 STA-129까지의 구현과 회귀 검증을 포함한다.
**실기기 검증은 사용자 요청으로 추후 진행한다. 이 문서의 연산 횟수와 호스트 테스트 결과를
iPhone/태블릿의 메모리·속도 개선 측정값으로 해석하면 안 된다.**

## 변경 내용

| 이슈 | 구현 |
| --- | --- |
| STA-123 | 화면 안 카드만 미리보기를 생성하고, 표시 너비 × DPR × 확대 배율로 원본을 축소 디코딩한다. 사용 중 이미지와 캐시의 소유권을 분리한다. |
| STA-124 | renderer version, 시각 입력, 저장 객체 해시를 묶은 fingerprint가 일치하면 저장 이미지를 재사용한다. |
| STA-125 | 초안 이미지 바이너리를 native 파일 또는 web IndexedDB에 한 번 저장하고, 반복 편집에는 작은 메타데이터만 기록한다. |
| STA-126 | 편집기/폴더 선택에서 전체 워크아웃 조회를 제거한다. 현재 폴더·캐시·폴더 메타데이터 및 기존 폴더 이름 조회를 사용한다. |
| STA-127 | 페이지별 새 DTO만 전달하고 변경된 항목만 변환한다. 정렬된 목록에 새 항목을 병합한다. |
| STA-128 | 라이브러리 로딩, 실패, 실제 빈 목록, 검색 불일치를 구분한다. 실패 시 기존 결과·필터를 유지하고 재시도한다. |
| STA-129 | 워크아웃·재생 오류를 상황별 안내로 바꾸고 상세 조회 재시도와 단일 SnackBar를 제공한다. 원본 예외는 진단에 유지한다. |

## 캐시 및 저장 정책

- 원본 미리보기 캐시 예산은 **16 MiB**, 전체 해상도 export 캐시는 **64 MiB**다.
  LRU 순서로 예산 초과 항목을 퇴출하며 메모리 압박 알림에서 두 캐시를 비운다.
  예산은 캐시 소유 이미지 핸들의 RGBA 크기다. 화면에서 사용하는 clone, 일시적 디코딩,
  GPU 및 전체 프로세스 RSS의 상한을 의미하지 않는다.
- 미리보기 너비는 64px 단위로 올림하고 실제 원본 크기 이하로 제한한다.
  내보내기는 전체 원본을 사용해 기존 **1920×1080** 결과와 문구·타이머 배치를 유지한다.
  사용자는 clone을 소유하고 화면 해제 후 또는 export 종료 시 dispose한다.
  실패한 decode는 캐시에 남기지 않고 다시 시도할 수 있다.
- `designFingerprint`는 선택적 DTO 필드이며 `v1:<visual SHA>:<asset SHA>` 형식이다.
  동일 Firebase bucket 및 현재 사용자/워크아웃의 immutable 객체만 재사용하고,
  `getDownloadURL`로 객체 존재와 접근 가능 여부를 확인한다. 확인은 최대 3개 병렬,
  새 이미지 렌더링은 순차 실행한다. 구문서/누락 객체는 다시 생성하고 인증·네트워크
  실패는 저장 실패로 전달한다. renderer 동작/번들 자산 변경 시 version을 올려야 한다.
- 초안 v1 → v2 이전은 이미지와 메타데이터 기록 성공 후 기존 값을 지운다.
  파일은 임시 파일 후 rename, IndexedDB는 transaction 완료 후 성공 처리한다.
  계정/워크아웃/슬라이드별 범위를 분리하고, 작업 순서 보장과 삭제 tombstone으로
  늦은 저장의 초안 부활을 방지한다. 메타데이터가 가리키지 않는 이미지는 후속 읽기/저장에서 정리한다.
- 폴더 이름 repository 캐시는 화면을 닫은 뒤 30초간 공유한다. 구자료 호환용 callable은
  서버에서 워크아웃의 `folder` 필드만 projection한다. **서버의 N개 문서 읽기는 여전히 발생한다.**
  클라이언트 전체 DTO 다운로드·변환 및 여러 페이지 완료 대기를 제거한 것이며 과금 절감을 보장하지 않는다.

## 확인한 결과

| fixture | 변경 전 | 변경 후 | 측정 범위 |
| --- | --- | --- | --- |
| 서로 다른 디자인 1/8/9/30장, 재시작 후 변경 없이 저장 | 전체 이미지 준비 경로 | PNG 준비 0, 신규 업로드 0 | 실제 storage datasource, 렌더 횟수 spy 및 가짜 storage |
| 5 MiB 사진, 최초 저장 + 500ms 간격 편집 20회 | 전체 JSON 약 146.8 MB | 바이너리 5 MiB 1회 + 메타데이터 약 21.6 KB | controller debounce, 저장 횟수/바이트 계측 |
| 요약 24개 DTO 변환 | 48회 | 24회 | 마지막 빈 페이지를 포함한 동일 fixture |
| 요약 100개 DTO 변환 | 340회 | 100회 | 페이지당 24개 |
| 요약 500개 DTO 변환 | 5,540회 | 500회 | 페이지당 24개 |
| 10/100/500개 계정의 기존 워크아웃 편집기 | 폴더용 catalog 전체 조회 | 상세 1개, catalog 조회 0 | cold-cache widget fixture |

초안 측정 원문과 한계는 [draft-storage-benchmark.json](draft-storage-benchmark.json)에 있다.
호스트 debug CPU 시간은 JIT/워밍업 영향이 커 일반적인 속도 개선율로 제시하지 않는다.
서버 projection 검증 역시 가짜 데이터소스이며 실제 네트워크 지연 측정이 아니다.

## 회귀 검증 재현

```sh
flutter analyze --no-pub
flutter test --no-pub
flutter test --no-pub --platform chrome \
  test/library_management_test.dart test/workout_error_message_test.dart \
  test/slide_draft_assets_test.dart test/draft_asset_store_web_test.dart \
  test/workout_catalog_incremental_test.dart test/original_slide_cache_test.dart \
  test/slide_design_asset_reuse_test.dart
npm test --prefix functions
```

핵심 테스트는 원본 7종 선택/편집과 픽셀/배치 보존, decode 실패 재시도와 clone 수명,
fingerprint 변경·재시작·타 계정/워크아웃 경계, v1 초안 이전·저장 실패·복구·GC,
부분 페이지·로컬 수정/삭제·계정 전환, 로딩/오류/검색/재시도 상태를 포함한다.
Firestore 규칙 검증에는 현재 DTO의 fingerprint와 변경하지 않은 구버전 fixture를 함께 사용한다.
Chrome의 Flutter 테스트 엔진은 `flutter/assets` 플랫폼 요청에 응답하지 않으므로,
캐시 테스트에서만 PNG fixture 응답을 주입해 실제 codec/cache 경로를 실행한다.
원본 7개 파일과 픽셀 품질은 VM에서 검증하고, 실제 앱의 web release bundle에도
7개 원본이 동일 해시로 포함되는 것을 별도로 확인했다.
규칙 테스트 전체 실행 명령은 `node tool/firebase_contracts.mjs`이며 Flutter, Java 21 및
Node가 PATH에 있어야 한다. `tool/firebase/contract-suites.json`에 workout-save suite가 등록되어 있다.

Release 오류 안내는 별도 진입점 `tool/sta122_release_error_check.dart`에서 실제 production
오류 위젯을 렌더링해 확인한다. 원본 예외 문구와 오류 상세 버튼이 나타나지 않는지 검사한다.
실제 계정/네트워크 장애를 일으키는 E2E 검증과는 구분한다.
실행 결과는 [release-error-ui.json](release-error-ui.json), 캡처는
[release-safe-errors.png](release-safe-errors.png)에 보존한다.

## 추후 실기기 profile 절차

`tool/sta122_device_profile.dart`는 gallery 3회 왕복의 RSS/프레임, 5 MiB 초안 편집 20회,
서로 다른 디자인 30장 저장/재저장, 24/100/500개 catalog 처리 결과를
`STA122_PROFILE` 접두사의 JSON으로 출력한다. 데이터/네트워크는 fixture를 사용한다.
저장 시간 중 PNG 준비 단계는 첫 upload 호출 이전의 실제 렌더/PNG/Base64 준비 구간이며,
encoder만의 시간이나 실제 원격 저장 지연을 뜻하지 않는다.

1. 별도 복사본에서 benchmark 전용 application ID와 signing을 설정한다. 기존 앱을 덮어쓰지 않는다.
2. 기준 커밋과 변경 커밋 각각에 `sta122_device_profile.dart`, `sta122_storage_profile.dart`,
   `sta122_catalog_profile.dart`를 동일하게 복사한다. tool 코드는 구버전 repository API와 호환된다.
3. 같은 기기·화면 크기·열 상태에서 아래 명령을 각 커밋에 실행한다.

```sh
# 기준 커밋: 누적 DTO 페이지
flutter run --profile -d DEVICE_ID -t tool/sta122_device_profile.dart \
  --dart-define=BENCH_LABEL=before --dart-define=BENCH_DELTA=false
# 변경 커밋: delta DTO 페이지
flutter run --profile -d DEVICE_ID -t tool/sta122_device_profile.dart \
  --dart-define=BENCH_LABEL=after --dart-define=BENCH_DELTA=true
```

4. 기기/OS/Flutter 버전, 각 gallery 진입 전·peak·닫은 후 RSS, 긴 프레임 수와 p95,
   저장 준비/전체 시간, catalog raw samples와 변환 횟수를 양쪽 JSON에 보존한다.
   RSS는 프로세스 수치이며 GPU 사용량을 별도 주장하지 않는다. 프레임 수집 단계 경계에는
   배치 전달 오차가 있을 수 있으므로 정밀 구간 비교는 DevTools timeline도 함께 확인한다.
5. 실제 사진 선택 → 텍스트/타이머 편집 → 앱 종료/재진입 복구, 7종 템플릿 스크롤/선택,
   오래된 폴더 및 오프라인 재진입을 직접 확인한다.

## 배포 순서

새 `listLibraryFolders` callable을 포함한 functions를 클라이언트보다 먼저 배포해야 한다.
기존 파이프라인은 functions → 데이터 규칙 → hosting 순서다. 이번 작업은 PR까지만 진행하며
서버/앱을 배포하지 않는다. 실기기 profile 및 수동 QA 결과는 이후 이 문서/이슈에 추가한다.
