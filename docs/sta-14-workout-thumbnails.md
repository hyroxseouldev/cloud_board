# STA-14: 홈 워크아웃 썸네일 누락

## 원인과 수정

홈은 `users/{uid}/workoutSummaries`의 `imageSource`를 읽는다. 앱은 `WorkoutModuleModel.imageUrl`을 도메인의 `imageSource`로 변환한 뒤 요약을 저장하므로 신규 저장 직후 정상 표시될 수 있었다. 서버의 요약 생성·기존 데이터 이전 코드가 원본 Firestore 필드도 `imageSource`라고 가정해 빈 썸네일을 생성했다. 서버 트리거 역시 같은 코드여서 신규 저장 결과도 이후 덮어쓸 수 있었다.

`functions/src/workout-catalog.js`가 원본의 `imageUrl`을 우선 사용하도록 수정했다. `imageUrl` 필드가 없을 때만 `imageSource`를 호환 경로로 읽는다. 빈 `imageUrl`은 사용자가 이미지를 제거한 상태로 존중하며 두 번째 슬라이드의 이미지로 대체하지 않는다.

## 복구 도구

`functions/scripts/repair-workout-thumbnails.mjs`는 기본 읽기 전용이다.

```sh
node functions/scripts/repair-workout-thumbnails.mjs --project cloud-board-stationd
node functions/scripts/repair-workout-thumbnails.mjs --project cloud-board-stationd --apply --backup-dir <새 백업 디렉터리>
```

이미 원본 이미지가 있고 기존 요약의 썸네일만 비어 있는 항목에 한해 트랜잭션으로 `imageSource`만 갱신한다. 원본 워크아웃·수정 시각·세션·카탈로그 완료 표시는 변경하지 않는다. 삭제 진행 중인 계정과 누락된 문서는 건너뛰고, 쓰기 전에 제한 권한의 로컬 JSON 백업을 남긴다. 정상 썸네일은 덮어쓰지 않는다.

## 검증

- Functions 단위 테스트 17개 통과(이번 회귀 테스트 5개 포함).
- 실제 Firestore 에뮬레이터에서 복구 전 읽기 전용, 백업, 원본·기타 필드 보존, 반복 실행, 서버 동기화, 이미지 제거 및 삭제 계정 제외 검증 통과.
- 기존 성능 에뮬레이터의 잘못된 `imageSource` 원본 fixture를 실제 저장 형식 `imageUrl`로 수정하고 이미지 값 자체를 확인하도록 보강했다.
- 운영 읽기 전용 조사: 계정 4개 / 워크아웃 7개 / 썸네일 복구 대상 4개.

현장 확인: 데스크톱 및 Galaxy Tab에서 홈 새로고침 후 첫 슬라이드 이미지 노출 확인. 실제 기기 확인은 담당자 검수가 필요하다.

## 운영 반영 결과 (2026-09-18)

- `syncWorkoutCatalog` 함수만 asia-northeast3에 수정 배포 완료. 앱 바이너리 재빌드·다른 함수/규칙 배포 없음.
- 썸네일 4개 복구, 나머지 3개 변경 없음. 재검사에서 복구 대상 0개 확인.
- 백업: `/Users/sunmkim/.codex/backups/cloud-board/sta14-thumbnails-20260918-2154` (4개 JSON, 디렉터리 700 / 파일 600).
- 홈의 새로고침으로 반영 가능. STA-14는 실제 데스크톱·Galaxy Tab 확인을 위해 In Review로 전달.
