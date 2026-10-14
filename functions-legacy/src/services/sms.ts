import { createHmac, randomBytes } from 'node:crypto';
import { APIError } from 'better-auth/api';
// Better Auth owns codes, attempts, verification and session state. SOLAPI only
// delivers the SMS; credentials, phone numbers and codes never enter logs.
export async function sendSmsOTP({ phoneNumber, code }: { phoneNumber: string; code: string }) {
  const key = process.env.SOLAPI_API_KEY,
    secret = process.env.SOLAPI_API_SECRET,
    from = process.env.SOLAPI_FROM;
  if (!key || !secret || !from)
    throw new APIError('SERVICE_UNAVAILABLE', {
      message: '문자 인증을 준비 중입니다. 잠시 후 다시 시도해 주세요.',
    });
  const date = new Date().toISOString(),
    salt = randomBytes(16).toString('hex');
  const signature = createHmac('sha256', secret)
    .update(date + salt)
    .digest('hex');
  try {
    const response = await fetch('https://api.solapi.com/messages/v4/send-many/detail', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `HMAC-SHA256 apiKey=${key}, date=${date}, salt=${salt}, signature=${signature}`,
      },
      body: JSON.stringify({
        messages: [
          {
            to: phoneNumber.replace(/^\+82/, '0'),
            from,
            type: 'SMS',
            text: `[클라우드보드] 인증번호 ${code} (5분 이내 입력)`,
          },
        ],
      }),
      signal: AbortSignal.timeout(15000),
    });
    const result = await response.json();
    if (
      !response.ok ||
      result.failedMessageList?.length ||
      result.groupInfo?.count?.registeredSuccess !== 1
    )
      throw new Error('SMS not accepted');
  } catch {
    throw new APIError('BAD_GATEWAY', {
      message: '문자를 보내지 못했습니다. 번호를 확인하고 잠시 후 다시 시도해 주세요.',
    });
  }
}
