import {createHmac,randomBytes} from 'node:crypto';
import {error as logError} from 'firebase-functions/logger';

// Keep provider responses, credentials, recipients and OTPs out of logs.
const safeCode = value => typeof value==='string' && /^[A-Za-z0-9_-]{1,80}$/.test(value) ? value : undefined;
function rejectionHint(value) {
  const message=typeof value==='string'?value:'';
  if(/\bip\b|아이피/i.test(message)) return 'ip_restriction';
  if(/country|oversea|국가|해외/i.test(message)) return 'country_restriction';
  if(/permission|scope|권한/i.test(message)) return 'permission';
  if(/verif|인증/i.test(message)) return 'verification';
  if(/balance|cash|잔액/i.test(message)) return 'balance';
  return 'unknown';
}
export async function sendOnboardingSms(phone,code,{env=process.env,request=fetch,report=logError}={}) {
  const key=env.SOLAPI_API_KEY, secret=env.SOLAPI_API_SECRET, from=env.SOLAPI_FROM;
  const missing=['SOLAPI_API_KEY','SOLAPI_API_SECRET','SOLAPI_FROM'].filter(name=>!env[name]);
  if(missing.length) {
    report('onboarding_sms_failed',{reason:'configuration',missing});
    throw new Error('SMS not configured');
  }
  const date=new Date().toISOString(),salt=randomBytes(16).toString('hex');
  const signature=createHmac('sha256',secret).update(date+salt).digest('hex');
  let response;
  try {
    response=await request('https://api.solapi.com/messages/v4/send-many/detail',{
      method:'POST',headers:{'Content-Type':'application/json',Authorization:`HMAC-SHA256 apiKey=${key}, date=${date}, salt=${salt}, signature=${signature}`},
      body:JSON.stringify({messages:[{to:phone.replace(/^\+82/,'0'),from,type:'SMS',text:`[클라우드보드] 인증번호 ${code} (5분 이내 입력)`}]}),
      signal:AbortSignal.timeout(15000),
    });
  } catch(error) {
    report('onboarding_sms_failed',{reason:'network',errorName:safeCode(error?.name)});
    throw new Error('SMS request failed');
  }
  let result;
  try { result=await response.json(); }
  catch {
    report('onboarding_sms_failed',{reason:'invalid_response',httpStatus:response.status});
    throw new Error('SMS response invalid');
  }
  if(!response.ok||result?.failedMessageList?.length||result?.groupInfo?.count?.registeredSuccess!==1) {
    report('onboarding_sms_failed',{
      reason:'provider_rejected',httpStatus:response.status,
      errorCode:safeCode(result?.errorCode),
      rejectionHint:rejectionHint(result?.errorMessage),
      statusCodes:Array.isArray(result?.failedMessageList)?result.failedMessageList.map(item=>safeCode(item.statusCode)).filter(Boolean):[],
    });
    throw new Error('SMS not accepted');
  }
}
