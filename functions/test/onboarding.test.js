import {test} from 'node:test';
import assert from 'node:assert/strict';
import {trialEnd,normalizePhone,validateProfile} from '../src/onboarding.js';
test('calendar month clamps in Korean time, including leap February',()=>{
  for(const [start,end] of [
    ['2026-09-25T07:00:00Z','2026-10-25T07:00:00Z'],
    ['2026-01-30T16:00:00Z','2026-02-27T16:00:00Z'],
    ['2028-01-31T05:00:00Z','2028-02-29T05:00:00Z'],
    ['2026-12-31T02:00:00Z','2027-01-31T02:00:00Z'],
  ]) assert.equal(+trialEnd(new Date(start)),+new Date(end));
});
test('profile accepts undecided only for preparing/exploring and rejects privilege payloads',()=>{
  const draft={purpose:'exploring',role:'coach',centerTypes:['gym'],undecidedName:true,undecidedRegion:true};
  assert.equal(validateProfile(draft,true).role,'coach');
  assert.throws(()=>validateProfile({...draft,purpose:'operating'},true));
  assert.throws(()=>validateProfile({...draft,ownerUid:'someone'}));
  assert.throws(()=>validateProfile({...draft,environment:{displays:'unlimited'}}));
  assert.throws(()=>validateProfile({...draft,undecidedName:'true'}));
  assert.throws(()=>validateProfile({...draft,centerName:'x'.repeat(101)}));
});
test('phone normalization accepts Korean national/international formats only',()=>{
  assert.equal(normalizePhone('010-1234-5678'),'+821012345678');
  assert.equal(normalizePhone('+82 10 1234 5678'),'+821012345678');
  assert.throws(()=>normalizePhone('abc'));assert.throws(()=>normalizePhone('+12025550123'));
});
