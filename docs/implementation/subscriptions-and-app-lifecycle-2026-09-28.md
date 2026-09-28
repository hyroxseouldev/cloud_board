# 구독 · 첫 사용 애니메이션 · 앱 버전 관리

관련 이슈: [STA-40](https://linear.app/clyrdev/issue/STA-40), [STA-41](https://linear.app/clyrdev/issue/STA-41), [STA-42](https://linear.app/clyrdev/issue/STA-42).

2026-09-28 사용자 결정이 기존 구독 기획의 환경 분리 항목보다 우선한다. Firebase는 기존 `cloud-board-stationd` 하나다. 별도 Firebase 프로젝트, flavor, Neon 연동을 만들지 않는다. Apple Sandbox/Production 및 Google 테스트 구매 구분은 스토어가 검증한 거래 속성이며 Firebase 환경 분리가 아니다. RevenueCat 없이 `in_app_purchase`와 Firebase를 사용한다.

## 구현 범위

- iOS App Store와 Android Google Play의 월간 플러스/프리미엄 구매·복원, 스토어 구독 관리 연결, 내 구독 페이지. 가격은 각 스토어에서 조회한 현지화된 가격만 표시한다.
- 모든 플랫폼은 같은 계정의 서버 권한을 공유한다. Android는 자기 스토어 API로 구매를 검증한다. Web·TV에서 별도 결제 동선을 추가하지 않는다.
- 카드 없는 달력 기준 1개월 무료 체험 유지. 스토어 무료 체험을 중복 등록하지 않는다. 체험 중 유료 구매는 즉시 과금되므로 이를 화면에 명시한다. 무료 체험 만료 후 새 수업 시작은 제한하며, 진행 중인 수업은 유지한다.
- Google은 월간 자동 갱신 기본 요금제만 제공한다. 선불·할부·프로모션 상품은 제외한다. 활성 구독이 있으면 양 스토어 모두 새 구매를 막는다. Google 앱 내 업/다운그레이드 결제는 이번 범위에 포함하지 않는다.
- 로그인 이미지·인사·버튼 등장, 온보딩 단계 이동과 진행 표시. Flutter 내장 애니메이션, 동작 줄이기/접근성 설정 대응. 입력 서브트리를 복제하지 않는다.
- 공개 Firestore 버전 정책과 플랫폼 빌드 숫자 비교. 권장 업데이트 24시간 미루기, 필수 업데이트, 프로필 수동 확인. 수업 중·일시 정지·수업 복구 미확인·편집·구독·온보딩·로그인 처리 중에는 안내를 미룬다. Android TV와 Web에는 모바일 스토어 안내를 띄우지 않는다.

## 결제 서버 구조

`in_app_purchase` StoreKit 2 → `cloudboardBilling` → Apple 공식 `@apple/app-store-server-library`의 JWS 검증 + Server API 현재 구독 상태 조회 → Firestore 원장/요약 → 기존 `subscriptionEntitlements` 및 RTDB `subscriptionAccess`.

Android는 `in_app_purchase_android` → `cloudboardPlayBilling` → Google Play Developer API `purchases.subscriptionsv2.get` → 같은 Firestore/RTDB 권한 처리다. 앱에서 보낸 구매 상태·가격·만료일은 권한 판단에 사용하지 않는다. 런타임 서비스 계정의 ADC를 사용하며 앱이나 저장소에 서비스 계정 키를 넣지 않는다.

- `billingAccounts/{uid}`: 서버 발급 UUID appAccountToken, 기존 권한 스냅샷, 다음 확인 시각.
- `billingTokenOwners/{uuid}`: 거래 소유 계정 역참조. 클라이언트 접근 금지.
- `appStoreSubscriptions/{environment_originalId}`: 소유권, 최신 검증 결과, 갱신 lease.
- `appStoreTransactions/{environment_transactionId}`: 검증한 거래의 최소 메타데이터. 원문 영수증은 저장하지 않는다.
- `appStoreEvents/{environment_notificationUUID}`: 서명 확인 후 영속 큐에 저장. 알림 중복은 같은 문서로 수렴한다. worker와 5분 스케줄러가 재시도한다. 완료 이벤트는 30일 후 정리한다.
- `googlePlaySubscriptions/{sha256(purchaseToken)}`: Firebase 계정 소유권, 서버 검증 결과, 갱신 lease, 다음 확인 시각. 재조회에 필요한 원본 구매 토큰은 이 서버 전용 원장에 보관한다. 클라이언트 읽기/쓰기 금지이며 계정 삭제 시 토큰과 uid를 제거한 tombstone만 남긴다.
- `googlePlayEvents/{PubSub messageId}`: IAM으로 보호된 RTDN 수신 후 영속 큐. 이벤트의 종류나 순서 대신 Google API 최신 상태를 조회한다. 실패는 재시도하며 성공 즉시 토큰을 제거하고 완료 메타데이터는 30일 후 정리한다.
- `users/{uid}/billing/summary`: 자기 계정 읽기만 허용. 서버만 수정한다.
- 체험/기존 플랜/Apple/Google 이용권을 각각의 만료 시각으로 계산한다. 짧은 Premium에 긴 Plus 만료일을 붙이지 않는다. 외부 기존 요금제 활성 계정은 중복 구매를 막고 기존 권한을 유지한다.
- 자동 갱신 해지만으로 이미 결제한 기간을 회수하지 않는다. 만료·환불·업그레이드된 이전 거래는 새 권한을 만들지 않는다. 유예 기간은 Apple이 서명한 종료 시각까지만 허용한다.
- 기기 구매 완료 처리는 서버 저장·권한 반영 응답 이후에만 실행한다. 확인 실패 시 재결제 대신 확인 재시도를 안내한다.
- Google은 권한 저장·RTDB 반영 후 서버가 acknowledge한다. 앱 종료 후에도 알림/스케줄러가 마무리하며, 실패하면 재시도한다. 기기에서 중복 acknowledge하지 않는다. 앱 시작·로그인·복귀 때 구매를 다시 조회해 앱 밖에서 승인된 결제를 복구한다. PENDING은 권한을 주거나 acknowledge하지 않는다.
- Google CANCELED는 이미 결제한 만료일까지 유지한다. GRACE_PERIOD는 Google의 expiry까지만 허용하고 ON_HOLD/PAUSED/EXPIRED는 신규 이용 권한을 주지 않는다. linkedPurchaseToken의 소유권을 확인하고 활성화된 대체 거래만 이전 원장을 종료한다. 미결제/미소유 교체 상품에는 권한을 주지 않는다. 410으로 만료된 토큰은 재조회 대상에서 제외한다.
- 구독 만료는 진행 중인 수업을 중단시키지 않는다. 기존 RTDB 진행 세션 예외 규칙을 유지한다. App Store 권한 변경으로 초과 즐겨찾기를 자동 해제하지 않으며, 새 추가만 현재 한도를 따른다.
- 계정 삭제가 Apple/Google 자동 갱신을 취소하지 않는다는 안내와 양쪽 관리 링크를 제공한다. 삭제된 token/originalId는 개인 정보 없는 tombstone으로 예약하여 지연 알림 및 타 계정 복원을 차단한다. uid가 있는 삭제 작업/계정 tombstone은 기존 30일 정리 대상이다. 상거래·개인정보 정책의 최종 보관 문구는 결제 오픈 전 검토해야 한다.
- 삭제된 계정의 미완료 StoreKit 거래는 서명과 삭제 tombstone을 확인한 뒤 권한을 이전하지 않고 완료 처리할 수 있다. 클라이언트에 자동 갱신 별도 해지 안내를 표시한다.

## 공통 구매 스위치 — 아직 실결제 활성화 안 함

서버 전용 `appConfig/billing`은 필드가 누락돼도 기본 비활성이다. Apple을 열어도 Google이 자동으로 열리지 않는다.

```json
{
  "legalReady": false,
  "productsReady": false,
  "purchasesEnabled": false,
  "sandboxPurchasesEnabled": false,
  "googlePlayProductsReady": false,
  "googlePlayPurchasesEnabled": false,
  "googlePlaySandboxPurchasesEnabled": false
}
```

`billingTesters/{테스트 Firebase uid}`에 `{ "enabled": true }`인 계정만 테스트 구매 권한을 반영한다. 테스트 스위치는 테스트 계정의 구매 버튼을 허용할 뿐 실제 스토어 결제를 Sandbox로 바꾸지 않는다. 반드시 Apple Sandbox 계정 또는 Google 라이선스 테스터로 결제한다. 스위치를 꺼도 기존 구매 복원·검증·갱신 알림은 작동한다.

## Apple 오픈 전 외부 준비

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
7. 테스트 Firebase uid를 위 공통 allowlist에 등록한다.
8. 준비가 끝난 뒤 legalReady/productsReady와 sandboxPurchasesEnabled만 true로 바꿔 지정 계정에서 Sandbox 테스트한다. 일반 결제는 purchasesEnabled가 true여야 열린다.
9. 실제 Sandbox에서 구매, 재설치 복원, 다른 계정 복원 차단, 가속 갱신, 해지 후 기간 유지, grace/billing retry, 환불, 업/다운그레이드, 오프라인 확인 재시도, 계정 삭제 후 지연 알림을 확인한다. 이 문서의 로컬 테스트는 실제 Apple 결제를 대신하지 않는다.
10. 결제 포함 앱 및 상품 심사를 마치고 purchasesEnabled를 켠다. 장애 시 이 값만 false로 되돌려 신규 결제를 중단한다.

## Google Play 오픈 전 외부 준비

2026-09-28 실제 CloudBoard Play Console(`com.sunmkim.cloudboard`)의 정기 결제 페이지를 확인했다. **Google Payments 판매자 계정 미설정으로 상품 페이지가 잠겨 있다.** 상품 등록·가격 설정·실제 테스트 구매는 수행하지 않았다. 프로덕션 액세스 신청은 심사 중으로 표시됐다. 코드 구현 완료와 스토어 설정 완료는 별개다.

1. 계정 소유자가 판매자 계정·정산·세금 및 필요한 법적 조건을 준비한다. 계약에 대신 동의하거나 임의의 사업자 정보를 입력하지 않는다.
2. 다음 구독 2개를 등록한다. 각각 자동 갱신 기본 요금제 ID는 `monthly`, 기간은 1개월이다. 가격은 별도로 확정해야 한다. 앱에 이미 카드 없는 1개월 체험이 있으므로 별도 무료 체험/프로모션 오퍼를 등록하지 않는다.
   - `com.sunmkim.cloudboard.plus.monthly`
   - `com.sunmkim.cloudboard.premium.monthly`
3. Google Play Developer API를 활성화하고 실제 배포된 Functions 런타임 서비스 계정을 확인한다. 이 계정을 Play Console 사용자로 초대해 **이 앱에만** 구독 조회·주문/구독 관리 권한을 부여한다. 서버는 ADC로 인증하므로 JSON 비밀 키를 만들거나 앱에 배포하지 않는다.
4. 새 Functions와 공통 권한/삭제 Functions를 배포한다. 이 문서는 실행 절차이며 이번 작업에서 운영 배포하지 않았다.
   ```sh
   firebase deploy --project cloud-board-stationd --only firestore:rules,functions:cloudboardPlayBilling,functions:googlePlayNotifications,functions:processGooglePlayNotification,functions:reconcileGooglePlayBilling,functions:syncAppTrialAccess,functions:syncSlideLibraryPlan,functions:deleteMyAccount,functions:retryAccountDeletions
   ```
   Apple 서버가 이미 운영 중이면 공유 권한 계산 변경을 반영하도록 위 Apple 배포 항목도 함께 갱신한다. Apple secret 준비가 별도로 필요하다.
5. Pub/Sub 토픽 `projects/cloud-board-stationd/topics/cloudboard-google-play`에 `google-play-developer-notifications@system.gserviceaccount.com`의 Publisher 권한을 부여한다. Play Console의 실시간 개발자 알림(RTDN)에 이 토픽을 연결하고 테스트 알림의 전달 성공을 확인한다. TEST 알림은 권한을 변경하지 않는다. Public HTTP webhook을 만들지 않는다.
6. Play Console 라이선스 테스터와 테스트 트랙 참여자를 지정하고 Play에서 서명된 테스트 버전을 설치한다. 동일 테스터의 Firebase uid를 `billingTesters`에 등록한다.
7. 준비 완료 후 `legalReady`, `googlePlayProductsReady`, `googlePlaySandboxPurchasesEnabled`만 true로 설정한다. `googlePlayPurchasesEnabled`는 false로 유지한다. Google 응답의 `testPurchase`를 확인해 테스트 결제임을 검증한다.
8. 실제 기기에서 두 월간 상품 구매·재설치 복원·다른 Firebase 계정 복원 차단·외부 승인 대기·가속 갱신·해지 후 잔여 기간·결제 실패/보류/유예·환불/회수·오프라인 승인 재시도·계정 삭제 후 지연 알림을 확인한다. RTDN과 5분 재시도 경로도 함께 확인한다.
9. 서비스 이용약관·가격·보관 정책 및 스토어 심사를 완료한 뒤 명시적으로 `googlePlayPurchasesEnabled`를 연다. 장애 시 false로 되돌려 새 구매만 중단한다.

현재 남은 범위: 판매자 계정, 상품/가격 등록, 런타임 API 권한, RTDN 콘솔 연결, 실제 라이선스 테스터 결제. 앱 내 플랜 변경과 관리자가 임의로 부여하는 무료 기간 기능은 이번 Google Play 구현에 포함하지 않았다.

공식 참조: [SubscriptionPurchaseV2](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2), [서버 구매 검증·acknowledge](https://developer.android.com/google/play/billing/security), [RTDN 설정](https://developer.android.com/google/play/billing/getting-ready), [구독 상태](https://developer.android.com/google/play/billing/lifecycle/subscriptions).

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

2026-09-28 기존 Apple/애니메이션/버전 작업에서 iOS Simulator debug 빌드와 구독·온보딩·슬라이드 라이브러리 에뮬레이터를 검증했다. 이번 Google Play 확장에서 Flutter 전체 361개, 최종 결제 보완 테스트 10개, Node 47개, Apple/Google Firestore·RTDB 에뮬레이터가 통과했다. Flutter analyze와 Android debug APK 빌드도 성공했다. 운영 배포·스토어 제출·실결제 활성화는 하지 않았다.

서버 정책 단위 테스트, Firestore/RTDB 에뮬레이터(소유권·권한 위조·삭제 tombstone·복원·환불·체험 전환·승인 대기·acknowledge 실패·중복 알림·교체 토큰·Sandbox 제한), Flutter 양 스토어 구독 화면/구매 완료 순서/버전 정책/오프라인/접근성/기존 로그인·온보딩 회귀를 검사한다. Google Publisher API 응답은 테스트 fixture이므로 실제 Apple Sandbox나 Google 라이선스 테스트 결제의 성공을 뜻하지 않는다.

```sh
cd functions && npm test
# 저장소 루트, Java 21 이상:
firebase emulators:exec --project demo-cloudboard-billing --config firebase.onboarding-test.json --only firestore,database 'node functions/test/billing-emulator.mjs && node functions/test/google-play-emulator.mjs'
fvm flutter analyze --no-pub
fvm flutter test
```
