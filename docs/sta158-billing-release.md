# STA158 월 구독 가격과 출시 준비

2026-10-13 사용자 결정: 기존 유료 고객 없음. Plus **월 49,000원**, Premium **월 99,000원**, KRW·부가세 포함·매월 자동 갱신. 연간 상품과 신규 상품 ID를 추가하지 않는다.

| 구분 | Plus | Premium |
| --- | --- | --- |
| App Store / Google Play 상품 ID | com.sunmkim.cloudboard.plus.monthly | com.sunmkim.cloudboard.premium.monthly |
| Google Play base plan | monthly | monthly |
| 정규 결제 주기 | P1M | P1M |
| 한국 판매 목표 금액 | 49,000원 | 99,000원 |

앱 구매 버튼은 조회된 스토어의 지역화된 `ProductDetails.price`를 표시한다. 금액을 하드코딩하지 않는다. Google Play는 자동갱신 monthly 단일 가격 단계만, Apple은 StoreKit 1/2의 실제 구독 기간이 1개월인 상품만 노출한다. 이름에 monthly가 들어간 연간·3개월·선불 상품은 월 상품으로 표시하지 않는다. 최종 결제 금액은 해당 스토어 결제 화면에서 확인한다.

## 정책과 판매 활성화

새 혜택 노출은 서버 billing summary의 `policyVersion=plan-entitlements-v2`를 기준으로 한다. 권한 정책을 배포한 것만으로 전체 계정을 변경하지 않는다. `appConfig/planPolicy.enabled=true`와 동일 version이 적용돼야 전환하며 이미 전환한 계정은 유지한다. 전환 전에는 기존 실제 혜택과 새 요금제 준비 안내를 보여준다.

전환된 계정의 새 구매는 기존 legal/products/purchases switch 외에 `appConfig/billing.planCatalog.{app_store|google_play}` 증빙이 필요하다. `functions/src/billing-catalog.js`가 version, policyVersion, KRW, P1M, VAT 포함, 두 상품 ID·금액·active, 검증 시각, HTTPS 증빙 링크, sandboxVerified를 검사한다. 미확인 값을 true로 설정하지 않는다. 스토어별로 따로 검증하므로 Play 확인으로 Apple 판매가 열리지 않는다. 이는 출시 담당자의 확인 기록이며 스토어 API를 대신해 가격을 생성하지 않는다. 실제 sandbox 검수의 순환 의존을 피하려면 billingTesters의 명시적 테스트 계정 + 해당 스토어 sandboxPurchasesEnabled + 정식 purchasesEnabled 꺼짐 + 증빙의 sandboxSalesEnabled를 모두 갖춘 경우에만 sandboxVerified 확인을 유예할 수 있다. 가격·주기·상품·정책 증빙은 여전히 필수이며 테스트 계정은 스토어 sandbox/license tester 환경에서만 사용한다. 검증 완료 뒤 sandboxVerified와 증빙을 갱신하고 정식 판매를 연다.

```json
{
  "version": "monthly-krw-2026-10",
  "policyVersion": "plan-entitlements-v2",
  "sandboxVerified": false,
  "taxInclusive": true,
  "currency": "KRW",
  "period": "P1M",
  "verifiedAtMs": 0,
  "evidenceUrl": "",
  "products": {
    "plus": {"id": "com.sunmkim.cloudboard.plus.monthly", "amount": 49000, "active": false},
    "premium": {"id": "com.sunmkim.cloudboard.premium.monthly", "amount": 99000, "active": false}
  }
}
```

위 JSON은 **의도적으로 활성화되지 않는 준비용 양식**이다. 운영 config 쓰기는 이 PR에서 실행하지 않는다. 정책 활성화 전후 구매 복원과 영수증 검증은 계속 가능하며, 판매 gate는 새 prepare에만 적용된다. 기존 billing token 소유권·영수증 원장·notification 중복 방지·trial/paid 우선순위·만료 시각은 유지한다. 이미 결제한 사용자에게 다시 구매를 권하지 않고 스토어 관리/복원으로 보낸다. 유료 갱신을 끄더라도 이미 결제한 기간을 즉시 종료하지 않는다.

## 확인한 사항과 남은 운영 검증

현재 로컬 환경에 App Store Connect / Play 조회 자격 증명이 없고 저장소 Actions secret 목록에도 해당 릴리스 키가 노출된 이름으로 등록되어 있지 않았다. 조직/환경별 자격 증명 존재 여부는 이 결과만으로 단정하지 않는다. **스토어의 현재 실제 가격·심사/판매 가능 상태·샌드박스 구매 결과는 미검증**이다. 콘솔 가격과 실제 고객 데이터를 변경하거나 구매를 실행하지 않았다.

출시 전 App Store Connect의 구독 그룹, 월 주기, KOR 현재/예약 가격, 판매 가능 지역과 상태를 확인한다. Google Play는 `monetization.subscriptions.get`으로 두 상품의 monthly base plan, KR price, 자동 갱신 기간과 ACTIVE 상태를 확인한다. [Apple 구독 가격 API](https://developer.apple.com/documentation/appstoreconnectapi/subscription-price-points-and-subscription-prices), [Google Play 상품 조회 API](https://developers.google.com/android-publisher/api-ref/rest/v3/monetization.subscriptions/get)

스토어 가격을 설정한 후에는 현지화 가격을 실제 앱에서 확인하고 sandbox/license tester로 신규 구독·복원·중복 구매 차단·취소 후 기간 유지·환불·갱신·만료·플랜 변경을 검증한다. 유료 고객이 없다는 결정으로 기존 구독 가격 보존 캠페인은 필요 없지만 기존 코드의 소유권 및 상태 전이는 회귀 테스트한다. 웹은 판매 서버의 quote를 최종 금액으로 사용하며 앱 가격 문자열을 웹 결제 금액으로 재사용하지 않는다.

출시 순서: 두 backend와 rules/client 배포 준비 → 저장량 dry-run과 호환 검증 → v2 제한된 테스트 계정 검증 → store/web 실제 가격·결제 검증 → 증빙 등록 → 유료 판매 gate → STA-159 릴리스 확인. 사용자 요청에 따라 실기기/TV 검증은 뒤에 진행한다. 이 PR과 companion PR은 개발 결과이며 운영 활성화 완료를 뜻하지 않는다.

## 검증

- 새 가격의 누락·다른 통화/주기·금액 불일치·미활성 상품·미검증 sandbox가 구매 gate를 통과하지 못하는 Node 테스트.
- Firestore emulator에서 정책만 활성화한 상태의 prepare 차단, 검증된 스토어 증빙 뒤 허용.
- 기존 token 소유권, trial fallback, notification/renewal/refund, 중복·계정 전환·구매 복원 회귀.
- Flutter 좁은 화면에서 구독 관리/복원, 신규 혜택 문구 및 실제 StoreKit 기간 판정.
