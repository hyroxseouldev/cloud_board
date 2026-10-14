import test from 'node:test';
import assert from 'node:assert/strict';
import {hasVerifiedPhone,hasWebEntitlement,isFreeGrant} from '../src/verified-free-policy.js';

test('only explicit server phone proof authorizes Free; history and truthy strings do not',()=>{
  for(const progress of [null,{}, {phoneVerified:'true'},{phoneVerified:1},{phone:'01012345678'}])
    assert.equal(hasVerifiedPhone(progress,{paidHistory:true,trialUsed:true}),false);
  assert.equal(hasVerifiedPhone({phoneVerified:true}),true);
  assert.equal(hasVerifiedPhone(null,{phoneVerified:true,status:'expired',validUntilMs:0}),true);
  assert.equal(hasVerifiedPhone(null,null,{phoneVerified:true}),true);
  assert.equal(isFreeGrant({plan:'free',source:'legacy'}),true);
  assert.equal(isFreeGrant({plan:'premium',source:'app_free'}),true);
});
test('proof-only web metadata cannot replace a preserved paid baseline',()=>{
  assert.equal(hasWebEntitlement({phoneVerified:true,revision:1}),false);
  assert.equal(hasWebEntitlement({phoneVerified:true,source:'free',plan:'legacy',validUntilMs:0}),true);
});
