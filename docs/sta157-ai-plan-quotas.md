# STA-157 AI 슬라이드 도우미 사용량

## 서버 계약과 출시

`plan-entitlements-v2`로 전환한 권한 문서에 한해 Free 0회, Plus 월 10회, Premium 월 30회를 적용한다. 활성 Premium 체험도 30회다. 이미지 타이머 인식은 별도 카운터로 Premium 월 100회를 유지한다. 미전환 Plus는 기존 AI 차단 정책을 유지한다. 배포만으로 v2 정책을 일괄 활성화하지 않으며, 활성화는 공통 plan-policy 출시 절차를 따른다.

내용 정리와 디자인 제안은 모두 `users/{uid}/aiSlidesUsage/{YYYY-MM}`를 사용한다. 내용 정리 1회와 디자인 제안 1회는 합산 2회다. 결과는 한 장의 슬라이드를 만들기 위한 도우미이며 수업 전체 자동 생성이나 슬라이드 장수 과금이 아니다. 타이머는 `aiTimerUsage`를 사용한다. 사용자 ID와 KST 달이 키이므로 업그레이드·다운그레이드·재구독으로 카운터를 지우지 않는다. 매월 1일 00:00 KST에 새 월 문서를 사용하며 앱이 열려 있어도 초기화 시각에 권한을 다시 읽는다.

응답의 기존 `premium`, `enabled`, `remaining`, `limit`, `resetsAtMs`를 유지하고 `allowed`, `plan`, `used`, `availabilityReason`, `policyVersion`을 추가했다. `premium`은 실제 Premium 의미를 유지한다. 새 앱은 `allowed`를 사용하고 구 서버 응답에만 `premium`으로 fallback한다. 권한 문서 누락·만료·취소/환불·알 수 없는 상태·조회 실패를 정상 Free로 바꾸지 않는다. 사용량을 읽지 못하면 요청을 시작하지 않는다.

동일 계정의 완료 결과는 30일 캐시에서 추가 차감 없이 재조회할 수 있다. 한도가 0회 남아도 서버가 캐시 여부를 판단하도록 앱 요청 버튼을 유지한다. 동시 요청은 트랜잭션에서 예약하며 내용/디자인의 마지막 한 슬롯도 공유한다. 확인된 제공자/검증 실패는 사용자 횟수를 환급하되 비용을 알 수 없으므로 서비스 비용 예약은 남긴다. 프로세스가 종료되어 성공 여부를 확인할 수 없는 요청은 자동 환급하지 않는다. 계정 삭제나 새 작업이 이전 작업을 대체한 경우, 늦은 완료가 사용자 데이터를 재생성하거나 새 예약을 환급하지 않는다.

## 비용 차단과 관측

기존 전체 서비스 공통 월 한도는 그대로 유지했다: `aiTimerBudgets/{YYYY-MM}`의 2,000 provider 요청 또는 USD 4,000,000 micro-units($4). 각 호출 전에 USD 10,000 micro-units($0.01)를 원자적으로 예약한다. 세 AI 진입점이 같은 예산을 공유한다. 이는 현재 운영 비용 추정값을 새로 검증한 숫자가 아니라 기존 코드의 보호 한도다. 사용자별 제공량이 늘면 전체 예산이 먼저 소진될 수 있으므로 활성화 전 운영자가 이용자 수와 실제 토큰 비용으로 재산정해야 한다.

`appConfig/aiSlides.enabled=false`와 `appConfig/aiTimer.enabled=false`는 각 기능을 중단한다. 키 미설정, 기능 점검, 서비스 비용/호출 한도, 개인 월 한도, 반복 요청 제한, 제공자 실패는 각각 구분한다. 서비스 예산 중단은 사용자에게 개인 횟수가 소진된 것처럼 안내하지 않는다. 캐시 결과는 서비스 예산을 추가 사용하지 않는다.

새 `aiRequestMetrics/{YYYY-MM}`는 `content`, `design`, `timer`별 집계다. `provider_started`, `completed`, `cached`, `quota_refunded`, `provider_failed`, `request_failed`, `user_limit`, `attempt_limit`, `service_limit`, `feature_disabled`, `not_configured`, `entitlement_unavailable`, `usage_unavailable`, `in_progress`, `cooldown`을 구분한다. uid, 입력 메모, 이미지, 키, 제공자 오류 원문은 기록하지 않는다. 관측 쓰기 실패는 본 요청 결과에 영향을 주지 않는다. 서버 전용 컬렉션이며 클라이언트 읽기/쓰기는 규칙상 허용하지 않는다.

운영 체크: 일별 budget 사용률과 호출 수, 완료 대비 제공자 실패·환급 비율을 확인한다. 80% 예산 경보와 `not_configured`/`service_limit` 발생 알림을 운영 모니터링에 연결하고, 제공자 오류가 급증하면 feature kill switch를 끈다. 이 PR은 집계와 하드 차단을 구현했으며 **운영 알림 채널/Cloud Monitoring 정책 생성은 수행하지 않았다**. 사용자 카운터를 수동 초기화해 장애를 해결하지 않는다. 원인 해결 후 kill switch를 복구하고 소규모 검수 후 확대한다.

## 검증과 확인 한계

Node 단위 테스트는 기존 AI provider 어댑터의 주입된 fetch를 사용한다. 신규 `functions/test/ai-plan-quota-emulator.mjs`는 실제 Firestore emulator 트랜잭션과 주입된 provider로 Plus 10/11, Premium 30/31, timer 100/101, 공유 카운터, 체험, 누락/만료/환불, 플랜 변경 보존, 동시 마지막 슬롯, 캐시, 실패 환급/재시도, KST 월 경계, 기능/키/예산/호출 중단 및 계측을 확인한다. 기존 timer/content/design emulator 회귀도 유지한다.

2026-10-13 읽기 전용 확인: GitHub 저장소 변수 `AI_TIMER_SECRETS_ENABLED=true`이며 callable 세 개는 같은 Secret Manager `OPENAI_API_KEY` opt-in binding을 사용한다. GitHub Actions secret 목록에 같은 이름이 없다는 것은 Secret Manager 키가 없다는 뜻이 아니다. 로컬 gcloud CLI가 없어 운영 Secret Manager 메타데이터, 유효 키/모델 권한, 배포된 함수 환경, 실제 생성 결과, 실제 토큰 비용은 검증하지 않았다. 키 내용을 읽거나 새 키를 생성하지 않았고 실제 유료 AI 요청도 하지 않았다. 기존 모델/API 요청/가격 계산식은 변경하지 않았다. 운영 활성화 전 별도 승인된 실제 호출과 비용/알림 검수가 필요하다.

실행 결과: AI Node 단위 28/28, 신규 정책 emulator 및 기존 timer/content/design emulator 통과. Flutter access/model/content/timer 30/30 및 디자인 data/studio/editor 35/35, 총 65개 통과. 관련 Dart analyze 오류 없음. 세부 실행 로그는 `/tmp/sta157-unit.log`, `/tmp/sta157-emulator.log`, `/tmp/sta157-existing-emulators.log`, `/tmp/sta157-flutter.log`이다.

검증 명령:

```sh
node --test functions/test/ai-timer.test.js functions/test/ai-slides.test.js functions/test/ai-slide-designs.test.js
# Firestore emulator의 로컬 FIRESTORE_EMULATOR_HOST 환경에서
node functions/test/ai-plan-quota-emulator.mjs
node functions/test/ai-timer-emulator.mjs
node functions/test/ai-slides-emulator.mjs
node functions/test/ai-slide-designs-emulator.mjs
flutter test test/ai_plan_access_test.dart test/ai_slides_model_test.dart test/ai_slides_test.dart test/ai_timer_test.dart
```
