# 구독 · 첫 사용 애니메이션 · 앱 버전 관리

관련 이슈: [STA-40](https://linear.app/clyrdev/issue/STA-40), [STA-41](https://linear.app/clyrdev/issue/STA-41), [STA-42](https://linear.app/clyrdev/issue/STA-42).

2026-09-28 사용자 결정이 기존 구독 기획의 환경 분리 항목보다 우선한다. Firebase는 기존 `cloud-board-stationd` 하나다. 별도 Firebase 프로젝트, flavor, Neon 연동을 만들지 않는다. Apple 거래의 Sandbox/Production 구분은 검증된 영수증의 속성이며 Firebase 환경 분리가 아니다.

## 구현 범위

- iOS App Store 월간 플러스/프리미엄 구매와 복원, Apple 구독 관리 연결, 내 구독 페이지. 가격은 StoreKit의 현지화된 가격만 표시한다.
- Android·Web·TV는 같은 계정의 서버 권한을 공유한다. 기존 STA-40 1차 범위에 맞춰 Google Play 결제 상품 구매 구현은 후속 작업이다.
- 카드 없는 달력 기준 1개월 무료 체험 유지. Apple 무료 체험을 중복 등록하지 않는다. 체험 중 유료 구매는 즉시 과금되므로 이를 화면에 명시한다.
- 로그인 이미지·인사·버튼 등장, 온보딩 단계 이동과 진행 표시. Flutter 내장 애니메이션, 동작 줄이기/접근성 설정 대응. 입력 서브트리를 복제하지 않는다.
- 공개 Firestore 버전 정책과 플랫폼 빌드 숫자 비교. 권장 업데이트 24시간 미루기, 필수 업데이트, 프로필 수동 확인. 수업 중·일시 정지·수업 복구 미확인·편집·구독·온보딩·로그인 처리 중에는 안내를 미룬다. Android TV와 Web에는 모바일 스토어 안내를 띄우지 않는다.

## 결제 서버 구조

`in_app_purchase` StoreKit 2 → `cloudboardBilling` → Apple 공식 `@apple/app-store-server-library`의 JWS 검증 + Server API 현재 구독 상태 조회 → Firestore 원장/요약 → 기존 `subscriptionEntitlements` 및 RTDB `subscriptionAccess`.

- `billingAccounts/{uid}`: 서버 발급 UUID appAccountToken, 기존 권한 스냅샷, 다음 확인 시각.
- `billingTokenOwners/{uuid}`: 거래 소유 계정 역참조. 클라이언트 접근 금지.
- `appStoreSubscriptions/{environment_originalId}`: 소유권, 최신 검증 결과, 갱신 lease.
- `appStoreTransactions/{environment_transactionId}`: 검증한 거래의 최소 메타데이터. 원문 영수증은 저장하지 않는다.
- `appStoreEvents/{environment_notificationUUID}`: 서명 확인 후 영속 큐에 저장. 알림 중복은 같은 문서로 수렴한다. worker와 5분 스케줄러가 재시도한다. 완료 이벤트는 30일 후 정리한다.
- `users/{uid}/billing/summary`: 자기 계정 읽기만 허용. 서버만 수정한다.
- 체험/기존 플랜/Apple 이용권을 각각의 만료 시각으로 계산한다. 짧은 Premium에 긴 Plus 만료일을 붙이지 않는다. 외부 기존 요금제 활성 계정은 중복 구매를 막고 기존 권한을 유지한다.
- 자동 갱신 해지만으로 이미 결제한 기간을 회수하지 않는다. 만료·환불·업그레이드된 이전 거래는 새 권한을 만들지 않는다. 유예 기간은 Apple이 서명한 종료 시각까지만 허용한다.
- 기기 구매 완료 처리는 서버 저장·권한 반영 응답 이후에만 실행한다. 확인 실패 시 재결제 대신 확인 재시도를 안내한다.
- 구독 만료는 진행 중인 수업을 중단시키지 않는다. 기존 RTDB 진행 세션 예외 규칙을 유지한다. App Store 권한 변경으로 초과 즐겨찾기를 자동 해제하지 않으며, 새 추가만 현재 한도를 따른다.
- 계정 삭제가 Apple 자동 갱신을 취소하지 않는다는 안내와 관리 링크를 제공한다. 삭제된 token/originalId는 개인 정보 없는 tombstone으로 예약하여 지연 알림 및 타 계정 복원을 차단한다. uid가 있는 삭제 작업/계정 tombstone은 기존 30일 정리 대상이다. 상거래·개인정보 정책의 최종 보관 문구는 결제 오픈 전 검토해야 한다.
- 삭제된 계정의 미완료 StoreKit 거래는 서명과 삭제 tombstone을 확인한 뒤 권한을 이전하지 않고 완료 처리할 수 있다. 클라이언트에 자동 갱신 별도 해지 안내를 표시한다.

## 오픈 전 외부 준비 사항 — 아직 실결제 활성화 안 함

1. Apple 유료 앱 계약, 세금·정산 정보, 사업/법적 조건을 계정 소유자가 확정한다.
2. 같은 구독 그룹에 아래 2개 상품을 등록한다. Premium을 상위 서비스 등급으로 설정한다. 가족 공유/Apple introductory free trial은 현재 구현 범위에서 활성화하지 않는다.
   - `com.sunmkim.cloudboard.plus.monthly`
   - `com.sunmkim.cloudboard.premium.monthly`
3. 가격·상품 심사·이용약관·개인정보 처리 및 보관 정책을 확정한다. 여기에는 가격을 임의로 정하지 않았다.
4. App Store Connect In-App Purchase API 키를 Secret Manager에 저장한다. 키 내용은 Git·Linear·클라이언트에 넣지 않는다.
   - `APPLE_IAP_PRIVATE_KEY` (p8 내용)
   - `APPLE_IAP_KEY_ID`
   - `APPLE_IAP_ISSUER_ID`
5. 서버와 rules를 배포한다. 새 secret을 연결하는 Functions는 secret 준비 전 배포할 수 없다. 현재 제출되어 심사 중인 바이너리는 이 변경과 별개다.
   ```sh
   firebase deploy --project cloud-board-stationd --only firestore:rules,functions:cloudboardBilling,functions:appStoreNotifications,functions:processAppStoreNotification,functions:reconcileAppStoreBilling,functions:syncAppTrialAccess,functions:syncSlideLibraryPlan,functions:deleteMyAccount,functions:retryAccountDeletions
   ```
6. App Store Server Notifications V2의 Production/Sandbox URL을 모두 배포된 `appStoreNotifications` HTTPS URL로 설정하고 TEST notification 성공을 확인한다.
7. Admin SDK/콘솔로 `billingTesters/{테스트 Firebase uid}`에 `{ "enabled": true }`를 설정한다. 일반 고객에게 Sandbox 권한이 생기지 않는다.
8. 서버 전용 `appConfig/billing` 기본값:
   ```json
   { "legalReady": false, "productsReady": false, "purchasesEnabled": false, "sandboxPurchasesEnabled": false }
   ```
   준비가 끝난 뒤 legalReady/productsReady와 sandboxPurchasesEnabled만 true로 바꿔 지정 계정에서 Sandbox 테스트한다. 일반 결제는 purchasesEnabled가 true여야 열린다. 이 스위치는 새 구매만 막고 복원·검증·갱신 webhook은 계속 작동한다.
9. 실제 Sandbox에서 구매, 재설치 복원, 다른 계정 복원 차단, 가속 갱신, 해지 후 기간 유지, grace/billing retry, 환불, 업/다운그레이드, 오프라인 확인 재시도, 계정 삭제 후 지연 알림을 확인한다. 이 문서의 로컬 테스트는 실제 Apple 결제를 대신하지 않는다.
10. 결제 포함 앱 및 상품 심사를 마치고 purchasesEnabled를 켠다. 장애 시 이 값만 false로 되돌려 신규 결제를 중단한다.

## 앱 버전 정책 운영

문서: `appReleases/ios`, `appReleases/android`. 공개 읽기, Admin만 쓰기. 출시/공개가 실제 완료된 빌드에만 enabled/published를 켠다. 업로드 또는 심사 대기는 공개 완료가 아니다.

```json
{
  "enabled": false,
  "published": false,
  "latestBuild": 537,
  "minimumBuild": 1,
  "publishedBuild": 537,
  "version": "1.0.0",
  "message": "더 편리하고 안정적인 수업을 위해 업데이트해 주세요.",
  "storeUrl": "https://apps.apple.com/app/id6809105126"
}
```

위 숫자는 형식 예시이며 배포/출시 사실을 뜻하지 않는다. Android URL은 `https://play.google.com/store/apps/details?id=com.sunmkim.cloudboard`다. 빌드 번호를 늘리고 최신 빌드 이하에서만 minimumBuild를 설정한다. 이상한 숫자, 타 앱 링크, 미공개, 누락 또는 서버 접속 실패는 앱을 차단하지 않는다. 정책 조회는 서버 우선이며 오래된 캐시로 필수 업데이트를 강제하지 않는다.

```sh
# 기본은 검증 + 출력만. Admin 인증은 GOOGLE_APPLICATION_CREDENTIALS 또는 ADC.
node functions/tools/release-policy.mjs ios /absolute/path/release.json
# 실제 공개 완료를 확인한 뒤에만 저장:
node functions/tools/release-policy.mjs ios /absolute/path/release.json --apply
```

잘못된 정책은 enabled=false로 되돌린다. 앱이 foreground로 돌아오거나 사용자가 다시 확인할 때 재조회하며, 실행 중에는 1시간마다 재조회한다.

## 검증

2026-09-28 확인: Flutter 전체 353개 통과, 추가 보완 테스트 12개 통과, Node 39개 통과, 구독·온보딩·슬라이드 라이브러리 Firestore/RTDB 에뮬레이터 통과. iOS Simulator debug 및 Android debug APK 빌드 성공. Flutter analyze 통과. 신규 native SDK 컴파일만 검증했으며, 운영 배포·스토어 제출·실결제 활성화는 하지 않았다.

서버 정책 단위 테스트, Firestore/RTDB 에뮬레이터(소유권·권한 위조·계정 삭제·복원·환불·체험 전환), Flutter 구독 화면/구매 완료 순서/버전 정책/오프라인/접근성/기존 로그인·온보딩 회귀를 검사한다. 실제 Apple Sandbox, App Store 심사, Google Play 구매는 완료로 간주하지 않는다.

```sh
cd functions && npm test
# 저장소 루트, Java 21 이상:
firebase emulators:exec --project demo-cloudboard-billing --config firebase.onboarding-test.json --only firestore,database 'node functions/test/billing-emulator.mjs'
fvm flutter analyze --no-pub
fvm flutter test
```
