import {createHmac,randomBytes} from 'node:crypto';
export async function sendOnboardingSms(phone,code) {
  const key=process.env.SOLAPI_API_KEY, secret=process.env.SOLAPI_API_SECRET, from=process.env.SOLAPI_FROM;
  if(!key||!secret||!from) throw new Error('SMS not configured');
  const date=new Date().toISOString(),salt=randomBytes(16).toString('hex');
  const signature=createHmac('sha256',secret).update(date+salt).digest('hex');
  const response=await fetch('https://api.solapi.com/messages/v4/send-many/detail',{
    method:'POST',headers:{'Content-Type':'application/json',Authorization:`HMAC-SHA256 apiKey=${key}, date=${date}, salt=${salt}, signature=${signature}`},
    body:JSON.stringify({messages:[{to:phone.replace(/^\+82/,'0'),from,type:'SMS',text:`[클라우드보드] 인증번호 ${code} (5분 이내 입력)`}]}),
    signal:AbortSignal.timeout(15000),
  });
  const result=await response.json();
  if(!response.ok||result.failedMessageList?.length||result.groupInfo?.count?.registeredSuccess!==1) throw new Error('SMS not accepted');
}
