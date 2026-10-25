# STA-210 예약 작업 통합

2026-10-25: 구매·인증 API와 수업 명령 계약은 유지한다. 코드 병합과 실제 예약 자원 전환은 별도다.

| 환경 | 유지되는 예약 함수 | 주기 |
| --- | --- | --- |
| 양쪽 | cleanupDailyMaintenance | 24시간 |
| 운영 | refreshBillingEntitlements | 5분 |
| 양쪽 | retryAccountDeletions | 15분, 변경 없음 |
| 양쪽 | recoverTemplateJobs | 5분, 변경 없음 |

권한 갱신은 기존 billingAccounts.nextCheckAtMs <= 현재 시각, 최대100개를 선별하고 기존 refreshEntitlements를 그대로 호출한다. 별도 스토어 자격증명을 요구하지 않는다. Free·체험·관리자·웹 권한과 만료·회수 및 RTDB 반영 정책은 변경하지 않는다. 한 계정 실패 시 나머지도 처리한 뒤 실패를 반환한다.

일일 작업은 진단/작업 제한, 전화 인증, 재생 snapshot, 미제출 문의 첨부 정리를 독립적으로 시작한다. 기존 삭제 대상과 보관 기간은 유지한다. 실패 분기는 task 이름만 기록하고 전체 호출은 실패로 반환해 최대3회 재시도한다. 함수 제한540초, 장시간 순회 분기는510초에서 중단하며 재시도 간격300–3600초/재시도 창21600초다. 중복 호출은 기존 삭제·거래·권한 projection의 멱등 처리를 사용한다. 성공 로그는 `scheduled_maintenance`, `task`, `status`로 구분한다.

## 전환 순서

1. 소스 SHA·프로젝트를 고정하고 실제 구독 수, 기존 함수/Scheduler, 현재 수업 상태를 다시 확인한다. 운영 수업이 없는 시간에 전환한다. 실제 구독이 생겼다면 스토어 재확인 예약을 제거하지 않는다.
2. 개발에는 cleanupDailyMaintenance만, 운영에는 cleanupDailyMaintenance와 refreshBillingEntitlements만 먼저 scoped 배포한다. 전체 codebase 강제 배포로 기존 함수를 먼저 지우지 않는다.
3. 개발 실제 예약 실행과 운영 대체 작업 실행/로그·기존 권한 반영을 확인한다. 운영 확인은 기존 예약이 수행하던 범위이며 고객 수업·기기·정책 값을 테스트용으로 변경하지 않는다. 실패 시 기존 작업을 유지한다.
4. 아래 명시된 기존 함수와 대응 Scheduler만 제거한다. Firebase 함수 삭제 뒤 Scheduler도 실제 삭제됐는지 재조회한다. 단순 pause는 자원 수 감소가 아니다.
5. 양쪽 공통 퇴역5개: cleanupClientDiagnostics, cleanupOnboardingVerification, cleanupPlaybackSnapshots, cleanupSupportTicketUploads, retrySupportTicketNotifications. 운영 추가2개: reconcileAppStoreBilling, reconcileGooglePlayBilling.
6. 개발3개·운영4개 Scheduler와 유지되는 계정 삭제/이미지 복구·스토어 알림 endpoint를 재조회한다. 문의 ticket/outbox는 수정·삭제하지 않는다. 동일 소스의 후속 표준 릴리즈에서 omit 메타데이터로 구 작업이 재생성되지 않는지도 확인한다.

전체 codebase 배포는 omit:true 함수를 제거할 수 있다. 개발 allowlist는 새 daily를 포함하고 common billing을 제외한다. 개발에 별도 배포된 이미지 생성/복구 함수는 이번 퇴역 목록 밖이다. 실행 명령·최종 SHA·전후 자원 수·로그는 릴리즈 보고서에 남긴다.

## 향후 명시적 활성화

- Apple 재확인: `APP_STORE_RECONCILIATION_ENABLED=true`와 기존 Apple 설정/secret 준비 후 reconcileAppStoreBilling만 추가 배포.
- Play 재확인: `GOOGLE_PLAY_RECONCILIATION_ENABLED=true`와 기존 API 권한 준비 후 reconcileGooglePlayBilling만 추가 배포.
- 문의 메일: 기존 `SUPPORT_EMAIL_DELIVERY_ENABLED=true`, `SUPPORT_EMAIL_SECRETS_ENABLED=true`, secret 및 승인된 supportConfig/email을 준비하고 retrySupportTicketNotifications를 명시적으로 배포. 기본 개발 allowlist에는 포함되지 않는다. 런타임 설정이 불완전하면 outbox 조회·상태 갱신 없이 반환한다. 보존된 대기 건은 기존 lease/provider idempotency key로 이어 처리하며 발송됐다고 가정하지 않는다.
- 위 스토어 예약을 다시 켜도 공통 권한 갱신은 refreshBillingEntitlements 한 곳에서만 수행한다. 구매/인증, Pub/Sub/Firestore 알림 endpoint는 계속 유지한다.

## 롤백과 비밀키

직전 검증 소스의 기존 예약 함수를 scoped 복원하고 정상 실행을 확인한 후 신규 daily/common을 제거한다. 단순 예약 pause만으로 원복 완료라고 기록하지 않는다. 기존 API·DB 데이터·secret은 삭제하지 않으므로 이전 클라이언트 계약은 유지된다.

비밀키 후보4개는 이번 감사에서 보존한다. 개발 CLOUDBOARD_DEVELOPMENT_ONBOARDING_SECRET v1은 보존 revision cloudboardapponboarding-00001-nup에서 실제 참조한다. 운영 BETTER_AUTH_SECRET/BILLING_ENCRYPTION_KEY/DATABASE_URL v1은 관찰한 보존 revision에서 미참조이나 외부 소비자·복원 의존성을 확정하지 못했다. 비밀키 저장료 절감은 이번 예약 작업 감소와 구분한다. 값은 로그/PR에 기록하지 않는다.

## 관련 검증

`node --test functions/test/scheduled-maintenance.test.js`는 실제 Firebase endpoint discovery의 운영4/개발3 스케줄, opt-in, 실패 격리, 기한/범위와 비활성 메일 무조회 동작을 확인한다.

`FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 FIREBASE_DATABASE_EMULATOR_HOST=127.0.0.1:9000 node functions/test/scheduled-maintenance-emulator.mjs`는 격리된 demo-cloudboard-maintenance와 실제 DB transaction을 사용한다. 공통 갱신의 Free/체험/관리자/만료/회수·RTDB, 중복 실행, TTL/활성 snapshot·제출 첨부·문의 outbox 보존을 확인한다. 실제 원격 예약 실행·앱 E2E와 구분한다.
