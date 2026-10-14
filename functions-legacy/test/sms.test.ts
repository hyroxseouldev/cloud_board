import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createHmac } from 'node:crypto';
import { sendSmsOTP } from '../src/services/sms.js';
test('SOLAPI signs SMS delivery and rejects failed acceptance without exposing codes', async () => {
  const previous = {
      key: process.env.SOLAPI_API_KEY,
      secret: process.env.SOLAPI_API_SECRET,
      from: process.env.SOLAPI_FROM,
    },
    fetcher = globalThis.fetch;
  process.env.SOLAPI_API_KEY = 'fake-key';
  process.env.SOLAPI_API_SECRET = 'fake-secret';
  process.env.SOLAPI_FROM = '0212345678';
  try {
    globalThis.fetch = async (input, options) => {
      assert.equal(String(input), 'https://api.solapi.com/messages/v4/send-many/detail');
      const body = JSON.parse(options!.body as string);
      assert.equal(body.messages.length, 1);
      assert.equal(body.messages[0].to, '01012345678');
      assert.equal(body.messages[0].type, 'SMS');
      const authorization = new Headers(options!.headers).get('Authorization')!;
      const date = /date=([^,]+)/.exec(authorization)![1],
        salt = /salt=([^,]+)/.exec(authorization)![1];
      assert(
        authorization.endsWith(
          'signature=' +
            createHmac('sha256', 'fake-secret')
              .update(date + salt)
              .digest('hex'),
        ),
      );
      return Response.json({
        groupInfo: { count: { registeredSuccess: 1 } },
        failedMessageList: [],
      });
    };
    await sendSmsOTP({ phoneNumber: '+821012345678', code: '123456' });
    globalThis.fetch = async () =>
      Response.json({
        groupInfo: { count: { registeredSuccess: 0 } },
        failedMessageList: [{ statusCode: '3040' }],
      });
    await assert.rejects(
      () => sendSmsOTP({ phoneNumber: '+821012345678', code: '654321' }),
      /문자를 보내지 못했습니다/,
    );
    delete process.env.SOLAPI_API_KEY;
    await assert.rejects(
      () => sendSmsOTP({ phoneNumber: '+821012345678', code: '654321' }),
      /준비 중/,
    );
  } finally {
    globalThis.fetch = fetcher;
    for (const [name, value] of Object.entries({
      SOLAPI_API_KEY: previous.key,
      SOLAPI_API_SECRET: previous.secret,
      SOLAPI_FROM: previous.from,
    })) {
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
  }
});
