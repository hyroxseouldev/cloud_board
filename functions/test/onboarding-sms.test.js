import {test} from 'node:test';
import assert from 'node:assert/strict';
import {sendOnboardingSms} from '../src/onboarding-sms.js';

const env={SOLAPI_API_KEY:'test-key',SOLAPI_API_SECRET:'test-secret',SOLAPI_FROM:'0212345678'};
const phone='+821012345678',code='123456';

test('SMS accepts the provider registration result and sends the national phone format',async()=>{
  await sendOnboardingSms(phone,code,{env,report:()=>assert.fail('success must not log an error'),request:async(url,options)=>{
    const body=JSON.parse(options.body);
    assert.equal(body.messages[0].to,'01012345678');
    assert.equal(body.messages[0].from,env.SOLAPI_FROM);
    assert.match(options.headers.Authorization,/^HMAC-SHA256 apiKey=test-key/);
    return Response.json({groupInfo:{count:{registeredSuccess:1}},failedMessageList:[]});
  }});
});

test('rejected SMS logs only diagnostic codes, never raw response or authentication data',async()=>{
  const logs=[];
  await assert.rejects(sendOnboardingSms(phone,code,{env,report:(...args)=>logs.push(args),request:async()=>Response.json({
    errorCode:'InvalidSenderId',errorMessage:`${phone} ${code} test-secret`,
    failedMessageList:[{statusCode:'3040',to:phone,text:code}],
  },{status:400})}),/SMS not accepted/);
  assert.deepEqual(logs,[['onboarding_sms_failed',{reason:'provider_rejected',httpStatus:400,errorCode:'InvalidSenderId',rejectionHint:'unknown',statusCodes:['3040']}]]);
});

test('IP restrictions are classified without logging the provider message or address',async()=>{
  const logs=[];
  await assert.rejects(sendOnboardingSms(phone,code,{env,report:(_,detail)=>logs.push(detail),request:async()=>Response.json({
    errorCode:'Forbidden',errorMessage:'IP 192.0.2.123 is not permitted',
  },{status:403})}));
  assert.equal(logs[0].rejectionHint,'ip_restriction');
  assert.ok(!JSON.stringify(logs).includes('192.0.2.123'));
  logs.length=0;
  await assert.rejects(sendOnboardingSms(phone,code,{env,report:(_,detail)=>logs.push(detail),request:async()=>Response.json({
    errorCode:'Forbidden',errorMessage:'Recipient is not permitted',
  },{status:403})}));
  assert.equal(logs[0].rejectionHint,'unknown');
});

test('configuration, timeout and non-JSON failures retain a safe diagnostic reason',async()=>{
  for(const [override,reason] of [
    [{env:{}},'configuration'],
    [{request:async()=>{throw new DOMException('private payload','TimeoutError');}},'network'],
    [{request:async()=>new Response('private payload',{status:502})},'invalid_response'],
  ]) {
    const logs=[];
    await assert.rejects(sendOnboardingSms(phone,code,{env,...override,report:(_,detail)=>logs.push(detail)}));
    assert.equal(logs[0].reason,reason);
    assert.ok(!JSON.stringify(logs).includes('private payload'));
  }
});
