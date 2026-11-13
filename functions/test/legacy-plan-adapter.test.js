import test from 'node:test';
import assert from 'node:assert/strict';
import {historicalPlanAccess, receiptPlan} from '../src/legacy-plan-adapter.js';
import {planNames, planAccess, requirePlanEntitlement, projectPlanPolicy} from '../src/plan-policy.js';
import {products, appleGrant, resolveGrants} from '../src/billing-policy.js';
import {monthlyKrwPrices, planSalesReady, billingCatalogVersion} from '../src/billing-catalog.js';

test('new offerings are only Free/Premium; historical receipt remains recognizable without sale',()=>{
  assert.deepEqual(planNames,['free','premium']);
  assert.deepEqual(Object.values(products),['premium']);
  assert.deepEqual(Object.keys(monthlyKrwPrices),['premium']);
  assert.throws(()=>planAccess('plus'),/unknown-plan/);
  assert.equal(receiptPlan('com.sunmkim.cloudboard.plus.monthly'),'plus');
  assert.equal(receiptPlan('foreign.plus'),null);
});
test('historical restoration retains individual rights, expiry, source and revision without image plan inference',()=>{
  const grant={plan:'plus',source:'app_store',status:'active',validUntilMs:2000,revision:17,
    maxActiveDisplays:1,displayLimit:1,maxSavedSlides:17,maxFavorites:17,aiSlidesMonthlyLimit:4};
  const restored=resolveGrants([grant],1000);
  assert.equal(restored.plan,'plus');assert.equal(restored.validUntilMs,2000);
  assert.equal(restored.maxActiveDisplays,1);assert.equal(restored.maxSavedSlides,17);
  assert.equal(requirePlanEntitlement({...restored,revision:17},1000).aiSlidesMonthlyLimit,4);
  assert.equal(historicalPlanAccess(grant).revision,17);
  assert.equal(restored.policyPlan,undefined);
  const previous={...restored,policyVersion:'plan-entitlements-v1'};
  const projected=projectPlanPolicy(restored,previous,{enabled:true,version:'plan-entitlements-v2'});
  assert.equal(projected.policyVersion,'plan-entitlements-v1');assert.equal(projected.maxActiveDisplays,1);
});
test('historical auto-renew receipt and cancellation preserve purchased period without recharge or auto-upgrade',()=>{
  const grant=appleGrant({productId:'com.sunmkim.cloudboard.plus.monthly',expiresDate:5000,environment:'Production'},
    {autoRenewStatus:0,autoRenewProductId:'com.sunmkim.cloudboard.plus.monthly'},1,1000);
  assert.equal(grant.plan,'plus');assert.equal(grant.validUntilMs,5000);assert.equal(grant.autoRenew,false);
  assert.equal(grant.nextProductId,'com.sunmkim.cloudboard.plus.monthly');
});
test('Premium sales readiness requires real Premium proof but no retired product attestation',()=>{
  const proof={version:billingCatalogVersion,policyVersion:'plan-entitlements-v2',sandboxVerified:true,
    taxInclusive:true,currency:'KRW',period:'P1M',verifiedAtMs:1,evidenceUrl:'https://example.test/evidence',
    products:{premium:{id:'com.sunmkim.cloudboard.premium.monthly',amount:99000,active:true}}};
  assert.equal(planSalesReady({planCatalog:{app_store:proof}},'app_store',2),true);
  assert.equal(planSalesReady({planCatalog:{app_store:{...proof,products:{}}}},'app_store',2),false);
});
