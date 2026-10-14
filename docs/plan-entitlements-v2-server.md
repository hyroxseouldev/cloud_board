# STA-154 서버 권한 및 저장 한도

구현과 운영 전환을 구분한다. 이 변경은 운영 배포·계정 전환을 실행하지 않았다. 새 계약의 서버 원본은 `functions/src/plan-policy.js`, 앱/companion 검증 fixture는 `functions/test/fixtures/plan-entitlements-v2.json`이다.

| 항목 | Free | Plus | Premium |
| --- | ---: | ---: | ---: |
| 동시 TV | 1 | 3 | 무제한 |
| 현재 보관 수업 | 7 | 무제한 | 무제한 |
| 재사용 저장 슬라이드 | 3 | 30 | 무제한 |
| AI 내용 정리·디자인 합산 월 한도 | 0 | 10 | 30 |
| 이미지 타이머 인식 월 한도 | 0 | 0 | 100 |
| 대기 화면 커스텀/서비스 로고 숨김/센터 로고 | 불가 | 가능 | 가능 |

`policyVersion: plan-entitlements-v2`, `maxWorkouts`, `workoutsUnlimited`, `maxSavedSlides`, `savedSlidesUnlimited`, `maxActiveDisplays`, `displaysUnlimited`, `idleScreenCustomization`, `canHideCloudBoardLogo`, `canUseCenterLogo`, `aiSlidesMonthlyLimit`, `aiTimerMonthlyLimit`을 공유한다. `maxFavorites/favoritesUnlimited`는 저장 슬라이드 한도의 구버전 별칭이다. 한도의 `null`은 무제한이며 권한 조회 실패와 다르다.

Firestore `subscriptionEntitlements/{uid}`가 서버 원본이고 RTDB `subscriptionAccess/{uid}`에 리비전과 함께 투영된다. `requirePlanEntitlement`는 미래의 `validUntilMs`와 active/trialing/grace_period/canceling/past_due 상태를 요구한다. 유효기간 내 갱신 해지·웹 유예 기간은 보존한다. 누락·만료·환불·미확인 상태를 Free로 간주하지 않는다. 유효 체험은 Premium 계약을 적용하며 각 grant 자신의 만료와 기존 우선순위를 유지한다.

## 단계 전환

1. 함수/규칙/companion/신규 앱을 먼저 배포한다. `appConfig/planPolicy`가 없거나 활성화되지 않았다면 현재 v1 계약을 유지한다. 기존 v1 수업 생성 직접 쓰기는 계속 허용된다.
2. 서버 집계 dry-run으로 기존 초과 자료와 대상 계정을 확인한다. 한도 초과 자료를 삭제하거나 일반 수업 안의 슬라이드를 라이브러리 사용량에 포함하지 않는다.
3. 지원 앱·TV, companion, 운영 검증이 완료된 뒤에만 `appConfig/planPolicy {version:'plan-entitlements-v2', enabled:true}`를 운영자가 적용한다. 다음 서버 권한 갱신에서 v2로 전환된다. 이것은 코드 배포만으로 실행되지 않는다.
4. 이미 v2가 된 계정은 전환 플래그를 꺼도 자동으로 v1로 되돌아가지 않는다. 플래그는 새 전환을 중지한다. 계정 롤백은 검토된 entitlement 재투영과 규칙/함수 버전을 함께 되돌린다.

새 정책이 활성화된 계정에서 구버전 앱의 **직접 신규 생성·복제·복구**는 거절된다. 구버전 앱은 원자적 계정 한도 프로토콜을 모르므로 앱 업데이트가 필요하다. 기존 수업의 읽기·편집·삭제는 유지한다. 아직 v2로 전환하지 않은 계정에는 이 생성 차단을 적용하지 않는다. 진행 세션·기존 TV 등록 목록은 이 저장 정책이 수정하지 않는다.

## 저장 및 사용량

- 신규 앱은 `saveWorkout` callable로 수업/요약/사용량을 한 transaction에서 저장한다. Dart `WorkoutSaveDocuments`의 기존 필드 보존을 그대로 사용하고 서버가 읽은 수정 리비전을 다시 대조한다. 서버 저장 응답이 성공하기 전에는 저장 성공이나 새 리비전으로 취급하지 않는다.
- 신규 수업만 권한·한도를 요구한다. 기존 자료는 초과 상태나 권한 조회 실패에서도 편집 가능하다. 읽기·재생·삭제는 영향받지 않는다. 삭제 후 같은 ID로 복구하면 신규 보관 슬롯을 소비한다.
- 사용량 문서 `users/{uid}/planUsage/current`는 `workoutCount`, `savedSlideCount`, `policyVersion`, `updatedAt`을 제공한다. owner 읽기, 서버 쓰기 전용이다. `getPlanUsage` callable은 기존 계정의 첫 집계를 초기화한다.
- 한도 판정은 transaction 안의 원본 컬렉션 projection 조회와 공유 사용량 문서의 읽기/쓰기로 직렬화한다. 오래된 클라이언트가 직접 삭제한 직후에도 지연된 trigger의 stale count 때문에 슬롯을 잃지 않는다. 전체 운동/이미지 payload는 집계 조회에 포함하지 않는다. 규모가 큰 무제한 계정의 조회 비용은 계측 대상이다.
- `updateSlideLibrary`는 templates만 센다. 스타일 preset, 수업 내부 장수와 분리한다. 같은 batch의 삭제/추가 순서에 의존하지 않으며 Free 3/Plus 30/Premium 무제한을 판정한다. 기존 초과 자료를 demote/delete하지 않는다.
- 클라이언트의 `migration:true`는 한도 면제 권한이 아니다. 기존 ID/tombstone을 유지하며 서버에 없는 새 항목에는 한도가 적용된다. 구버전 로컬에만 있던 초과 자료는 원본을 유지한 채 별도 관리자 검토가 필요하며 자동 유실·삭제하지 않는다.
- quota 오류: `resource-exhausted`, details `{reason:'plan-limit', resource:'workouts'|'savedSlides', limit, used, policyVersion}`. 권한 확인 불가: `failed-precondition`, reason `entitlement-unavailable`. 충돌: `aborted`, reason `workout-revision-conflict`.

## 집계 dry-run 및 롤백

기본값은 읽기 전용이며 UID를 명시한다. 실제 환경의 ADC와 프로젝트 권한은 운영자가 준비한다. 아래는 **명령 예시**이며 실행 결과가 아니다.

```sh
node functions/scripts/plan-usage-migration.mjs --project PROJECT --uid UID --report /secure/usage-preview.json
node functions/scripts/plan-usage-migration.mjs --project PROJECT --uid UID --report /secure/usage-applied.json --apply --confirm-project PROJECT
node functions/scripts/plan-usage-migration.mjs --project PROJECT --rollback /secure/usage-applied.json --report /secure/usage-rollback.json --confirm-project PROJECT
```

도구는 권한/수업/라이브러리 원본을 바꾸지 않고 집계 문서만 작성한다. 기존 보고서를 덮어쓰지 않는다. 적용 백업을 같은 transaction의 `users/{uid}/planUsageBackups/{runId}`에 남겨 프로세스 종료 시에도 되돌릴 근거를 보존한다. 출력된 runId로 durable backup을 회수할 수 있다. 복구 시 현재 집계가 적용 직후 값과 다르면 `changed-since-apply`로 건너뛰어 이후 저장을 덮어쓰지 않는다. 백업은 account 삭제 시 사용자 하위 문서와 함께 삭제되며, 검수 종료 후 운영자가 보존 기간에 맞춰 정리한다.

집계 문서 롤백은 정책 활성화 롤백과 다르다. v2 entitlement를 그대로 둔 채 callable/rules를 제거하면 신규 저장이 막힐 수 있다. 앱 callable과 구버전 편집 경로를 유지하면서 대상 entitlement 정책·함수·규칙을 같은 릴리스 계획으로 되돌린다. 이미 저장된 수업·PNG·슬라이드는 되돌리거나 삭제하지 않는다.

## 검증 근거

- 집중 Node 테스트 41개 통과: 공통 계약/fixture, 결제 우선순위·만료, Free fallback, 라이브러리 충돌·재시도, dry-run/적용/guarded rollback. `/tmp/sta154-node-final.log`.
- 신규 `plan-quotas-emulator.mjs`와 기존 `slide-library-emulator.mjs` 모두 통과. `/tmp/sta154-emulator-all.log`.
- 실제 Firestore transaction에서 Free 7번째 성공/8번째 거절/삭제 후 재사용, 마지막 슬롯 경합, Free3/Plus30 경계, Premium70개 보관, 다운그레이드 후 보존·편집, missing entitlement, migration/direct-write 우회, retry·restore·ifAbsent, 정책 전환 전후 규칙을 검사했다.
- Flutter datasource/저장 revision 회귀 13개 통과: callable 성공 응답, quota 실패 시 원본·초안 보존, 충돌, offline, ifAbsent, 알 수 없는 필드·중첩 Timestamp 왕복. `/tmp/sta154-flutter-tests.log`.
- 운영 계정·실결제·실기기·진행 중 수업을 이 검증에서 변경하지 않았다. 실제 계정 전환 적용 시점과 지원 클라이언트 출시 순서는 별도 운영 검증으로 확정한다.

## STA-175 저장 한도 표시 및 웹 배포 전 회귀

저장 수업/재사용 슬라이드 안내는 `StoreEntitlement.limitFor(resource)`로 해당 리소스의 명시적인 유한 한도 또는 무제한 표식을 확인한다. 지원 정책은 v1/v2, 플랜은 Free/Plus/Premium 및 legacy/cloudboard_pro다. 유효 상태와 서버 시각 기준 만료를 확인하며, `null`만 있거나 무제한 표식과 유한 값이 충돌하면 알 수 없는 권한으로 남긴다. 저장 슬라이드의 기존 `maxFavorites`/`favoritesUnlimited` 별칭도 같은 기준으로 해석한다. AI/브랜딩 등 전체 계약의 `policyKnown`, 서버 저장 검증, 정책 전환 플래그는 변경하지 않는다.

2026-10-14 14:02 UTC 제보 계정을 읽기 전용으로 확인했다. 권한은 v1/Premium/trialing이고 미래 만료 시각, `maxWorkouts: null` 및 `workoutsUnlimited: true`였다. 이 계약은 기존 전체 v2 정책 검사에서 탈락하므로 ‘확인 중’ 표시의 원인을 확인했다. 원본 계정 정보는 회귀 fixture에 넣지 않는다. 수정 앱에서 해당 사용자의 실제 브라우저 수신/렌더링은 배포 전 별도 확인해야 한다.

동일 조회에서 서버 `workouts`, `workoutSummaries`, `planUsage.workoutCount`는 모두 1이었다. 제보 화면의 ‘내 수업 2개’는 현재 서버 자료로 재현되지 않았다. 목록은 캐시/페이지/검색·폴더 필터를 거친 `workoutController` 항목 수이고 사용량은 별도 실시간 집계 문서다. 구버전 직접 쓰기/삭제의 사용량 갱신은 trigger이므로 일시적인 시차도 가능하다. 목록 캐시는 완전한 서버 페이지를 받기 전까지 유지되며 오프라인 오류에서는 그대로 남을 수 있다. 이 차이는 entitlement 정책 판정과 별개이며, 목록 수로 서버 집계를 덮어쓰지 않는다. 재발 시 브라우저의 캐시/서버 수신 상태, 목록 필터와 페이지 완료 여부, 각 문서 갱신 시각을 함께 수집해 별도 후속 조사한다.

웹 배포 전 확인 목록:

- [ ] 제보 계정과 같은 v1 Premium/trialing + 명시적 무제한 값에서 `저장 수업 N / 무제한` 및 삭제 유도 문구 미노출 확인.
- [ ] v1/v2, legacy/cloudboard_pro, AI·브랜딩 필드 누락, saved-slide 별칭의 유효한 명시적 값 확인.
- [ ] Free 수업 7/슬라이드 3, Plus 슬라이드 30의 표시와 서버 한도 회귀 확인.
- [ ] 무제한 표식 누락, 유한 값과 표식/별칭 충돌, 잘못된 숫자, 미지원 정책, 만료 경계 및 회수 권한은 무제한으로 표시되지 않음 확인.
- [ ] 최초 로딩→정상, 조회 실패→재시도→정상, 정책 미확인, 사용량 오류를 각각 구별하고 일반 화면·툴바 다이얼로그의 일치 확인.
- [ ] 제보 브라우저의 목록 수와 사용량을 새로 수신한 뒤 대조하고, 캐시/페이지/필터 또는 별도 갱신 지연이면 후속 조사 기록.

자동 회귀는 `plan_resource_limit_test.dart`, `plan_usage_notice_test.dart`, 기존 `store_entitlement_test.dart`, `plan_usage_branding_test.dart`, `profile_plan_entitlements_test.dart`에서 수행하며 59개가 통과했다. 이 수정은 운영 권한/집계 문서 변경이나 웹 배포를 수행하지 않는다.
