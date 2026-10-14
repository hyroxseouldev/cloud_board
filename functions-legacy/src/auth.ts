import { betterAuth } from 'better-auth';
import { drizzleAdapter } from '@better-auth/drizzle-adapter';
import { phoneNumber } from 'better-auth/plugins';
import { APIError, createAuthMiddleware, getSessionFromCtx } from 'better-auth/api';
import { readConfig } from './config.js';
import { createDatabase } from './db/index.js';
import * as schema from './db/schema.js';
import { sendSmsOTP } from './services/sms.js';
import { z } from 'zod';
import { recoverVerifiedAccount } from './services/verified-access.js';

export function createAuth(config = readConfig(), sendOTP = sendSmsOTP) {
  const { pool, db } = createDatabase(config.databaseURL);
  const googleConfigured = !!process.env.GOOGLE_CLIENT_ID && !!process.env.GOOGLE_CLIENT_SECRET;
  const allowPasswordTest = config.local && process.env.ENABLE_PASSWORD_TEST_AUTH === 'true';
  const auth = betterAuth({
    appName: 'CloudBoard',
    baseURL: config.baseURL,
    basePath: '/api/auth',
    secret: config.secret,
    trustedOrigins: config.trustedOrigins,
    database: drizzleAdapter(db, { provider: 'pg', schema, transaction: true }),
    socialProviders: googleConfigured
      ? {
          google: {
            clientId: process.env.GOOGLE_CLIENT_ID!,
            clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
            prompt: 'select_account',
          },
        }
      : {},
    plugins: [
      phoneNumber({
        sendOTP,
        otpLength: 6,
        expiresIn: 300,
        allowedAttempts: 5,
        phoneNumberValidator: (phone) => /^\+821[016789]\d{7,8}$/.test(phone),
        callbackOnVerification: async ({ user }) => {
          // SQL verification is already committed. Recovery after a transient
          // linking/projection error is available on the account page.
          await recoverVerifiedAccount(pool, user.id, process.env.BILLING_MODE || 'disabled').catch(
            () => {},
          );
        },
      }),
    ],
    emailAndPassword: { enabled: allowPasswordTest, minPasswordLength: 12 },
    account: { accountLinking: { enabled: false }, encryptOAuthTokens: true },
    onAPIError: { errorURL: config.baseURL + '/login?error=oauth' },
    session: { expiresIn: 60 * 60 * 24 * 7, updateAge: 60 * 60 * 24 },
    rateLimit: {
      enabled: true,
      storage: 'database',
      window: 60,
      max: 60,
      customRules: {
        '/phone-number/send-otp': { window: 60, max: 3 },
        '/phone-number/verify': { window: 60, max: 5 },
      },
    },
    hooks: {
      before: createAuthMiddleware(async (ctx) => {
        const allowed = [
          '/sign-in/social',
          '/callback/:id',
          '/get-session',
          '/sign-out',
          '/update-user',
          '/phone-number/send-otp',
          '/phone-number/verify',
          '/ok',
        ];
        if (allowPasswordTest) allowed.push('/sign-up/email', '/sign-in/email');
        if (!allowed.includes(ctx.path))
          throw new APIError('NOT_FOUND', { message: '지원하지 않는 인증 방식입니다.' });
        if (ctx.path === '/callback/:id' && ctx.params?.id !== 'google')
          throw new APIError('NOT_FOUND', { message: 'Google 로그인을 사용해 주세요.' });
        if (ctx.path === '/sign-in/social' && ctx.body?.provider !== 'google')
          throw new APIError('BAD_REQUEST', { message: 'Google 로그인을 사용해 주세요.' });
        if (ctx.path === '/update-user') {
          const input = z
            .object({ name: z.string().trim().min(1).max(100) })
            .strict()
            .safeParse(ctx.body);
          if (!input.success)
            throw new APIError('BAD_REQUEST', { message: '이름을 1~100자로 입력해 주세요.' });
          ctx.body = input.data;
        }
        if (ctx.path.startsWith('/phone-number/')) {
          const session = await getSessionFromCtx(ctx);
          if (!session)
            throw new APIError('UNAUTHORIZED', {
              message: '먼저 Google 계정으로 로그인해 주세요.',
            });
          if (ctx.path === '/phone-number/verify') {
            // Verification only attaches a phone to the signed-in Google account;
            // it must never become a separate phone-login/session path.
            ctx.body.updatePhoneNumber = true;
            ctx.body.disableSession = true;
          }
          if (ctx.path === '/phone-number/send-otp') {
            const key = `sms-user:${session.user.id}`;
            const r = await pool.query(
              `INSERT INTO rate_limit(id,key,count,last_request) VALUES($1,$1,1,$2)
            ON CONFLICT(key) DO UPDATE SET count=CASE WHEN rate_limit.last_request<$2-900000 THEN 1 ELSE rate_limit.count+1 END,
            last_request=CASE WHEN rate_limit.last_request<$2-900000 THEN $2 ELSE rate_limit.last_request END RETURNING count`,
              [key, Date.now()],
            );
            if (r.rows[0].count > 5)
              throw new APIError('TOO_MANY_REQUESTS', {
                message: '인증 문자는 15분에 5회까지 요청할 수 있습니다.',
              });
          }
        }
      }),
    },
    advanced: {
      useSecureCookies: !config.local,
      ipAddress: { ipAddressHeaders: ['x-cloudboard-client-ip'] },
    },
  });
  return { auth, db, pool, config };
}
let runtime: ReturnType<typeof createAuth> | undefined;
export function getAuthRuntime() {
  return (runtime ??= createAuth());
}
