import test from 'node:test';
import assert from 'node:assert/strict';
import {appleGrant, resolveGrants, validateTransaction, purchasesAllowed, bundleId} from '../src/billing-policy.js';
import {verifyApplePayload} from '../src/apple-store.js';

const transaction = {bundleId, environment:'Production', productId:'com.sunmkim.cloudboard.premium.monthly',
  transactionId:'123', originalTransactionId:'120', appAccountToken:'12345678-1234-1234-1234-123456789abc',
  type:'Auto-Renewable Subscription', inAppOwnershipType:'PURCHASED', expiresDate:2000};
test('reject foreign apps, products, family sharing, unsigned account binding and local StoreKit', () => {
  assert.equal(validateTransaction(transaction, 'Production'), transaction);
  for (const change of [{bundleId:'other'}, {productId:'cheap'}, {environment:'Xcode'},
    {appAccountToken:null}, {inAppOwnershipType:'FAMILY_SHARED'}, {expiresDate:Infinity}, {transactionId:'../../uid'}]) {
    assert.throws(() => validateTransaction({...transaction, ...change}, 'Production'));
  }
});
test('forged and malformed JWS never receives a verified payload', async () => {
  await assert.rejects(verifyApplePayload('eyJhbGciOiJub25lIn0.eyJlbnZpcm9ubWVudCI6IlByb2R1Y3Rpb24ifQ.fake'));
  await assert.rejects(verifyApplePayload(''));
});
test('auto-renew cancellation keeps paid access through its own expiration', () => {
  const grant=appleGrant(transaction,{autoRenewStatus:0},1,1000);
  assert.equal(grant.validUntilMs,2000); assert.equal(grant.autoRenew,false);
  assert.equal(appleGrant(transaction,{},1,2000).validUntilMs,0);
});
test('verified grace period grants bounded access, billing retry and refunds do not', () => {
  assert.equal(appleGrant(transaction,{gracePeriodExpiresDate:3000},4,2500).validUntilMs,3000);
  assert.equal(appleGrant(transaction,{isInBillingRetryPeriod:true},3,2500).validUntilMs,0);
  assert.equal(appleGrant({...transaction,revocationDate:900},{},1,1000).validUntilMs,0);
  assert.equal(appleGrant({...transaction,isUpgraded:true},{},1,1000).validUntilMs,0);
});
test('longer Plus never extends Premium, expiry falls back to remaining Plus', () => {
  const grants=[{source:'app_trial',plan:'premium',status:'trialing',validUntilMs:2000},
    {source:'app_store',plan:'plus',status:'active',validUntilMs:5000}];
  assert.equal(resolveGrants(grants,1000).validUntilMs,2000);
  assert.equal(resolveGrants(grants,2000).plan,'plus');
  assert.equal(resolveGrants(grants,5000).canStartClass,false);
});
test('legacy limits survive paid downgrade and nullable limits are preserved', () => {
  const result=resolveGrants([{source:'legacy',plan:'cloudboard_pro',validUntilMs:5000,
    displayLimit:3,maxActiveDisplays:3,favoritesUnlimited:true,maxFavorites:null},
    {source:'app_store',plan:'plus',validUntilMs:8000}],1000);
  assert.equal(result.plan,'cloudboard_pro'); assert.equal(result.displayLimit,3); assert.equal(result.maxFavorites,null);
});
test('purchases default off; kill switch does not decide restore/verification', () => {
  assert.equal(purchasesAllowed({}),false);
  assert.equal(purchasesAllowed({purchasesEnabled:true}),false);
  const config={legalReady:true,productsReady:true,sandboxPurchasesEnabled:true};
  assert.equal(purchasesAllowed(config),false); assert.equal(purchasesAllowed(config,true),true);
  assert.equal(purchasesAllowed({...config,purchasesEnabled:true}),true);
});
