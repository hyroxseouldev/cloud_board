import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { once } from 'node:events';
import { randomUUID } from 'node:crypto';
import { test } from 'node:test';
import { eq } from 'drizzle-orm';
import { createAuth } from '../src/auth.js';
import { readConfig } from '../src/config.js';
import { handleAuthRequest } from '../src/http.js';
import { account, user } from '../src/db/schema.js';

const developmentOnly = process.env.NEON_BRANCH_NAME === 'development' && readConfig().local;
test(
  'Neon: registration, password hashing, sessions, sign-out and origin checks',
  { skip: !developmentOnly },
  async () => {
    process.env.ENABLE_PASSWORD_TEST_AUTH = 'true';
    const runtime = createAuth();
    delete process.env.ENABLE_PASSWORD_TEST_AUTH;
    const email = `auth-smoke-${randomUUID()}@example.invalid`;
    const password = randomUUID() + '!Aa1';
    // Simulate Firebase: consume the stream before passing rawBody to the handler.
    const server = createServer(async (req, res) => {
      try {
        const chunks: Buffer[] = [];
        for await (const chunk of req) chunks.push(Buffer.from(chunk));
        await handleAuthRequest(
          Object.assign(req, { rawBody: Buffer.concat(chunks) }),
          res,
          runtime,
        );
      } catch {
        res.writeHead(500).end('Test request failed');
      }
    });
    server.listen(0, '127.0.0.1');
    await once(server, 'listening');
    const address = server.address();
    assert(address && typeof address !== 'string');
    const base = `http://127.0.0.1:${address.port}`;
    const post = (path: string, data: object, cookie = '', origin = runtime.config.baseURL) =>
      fetch(`${base}/api/auth/${path}`, {
        method: 'POST',
        headers: { 'content-type': 'application/json', origin, cookie },
        body: JSON.stringify(data),
      });
    const cookieOf = (r: Response) =>
      r.headers
        .getSetCookie()
        .map((value) => value.split(';')[0])
        .join('; ');
    try {
      assert.equal(
        (
          await post(
            'sign-up/email',
            { email, password, name: 'Smoke' },
            '',
            'https://untrusted.invalid',
          )
        ).status,
        403,
      );
      const signup = await post('sign-up/email', { email, password, name: 'Auth smoke test' });
      assert.equal(signup.status, 200, 'Registration through the Firebase rawBody adapter');
      assert.match(signup.headers.get('set-cookie') || '', /HttpOnly/i);
      const payload = await signup.json();
      assert.equal(payload.user.email, email);
      const stored = await runtime.db
        .select()
        .from(account)
        .where(eq(account.userId, payload.user.id));
      assert(stored[0]?.password && stored[0].password !== password, 'Store a password hash');
      const cookie = cookieOf(signup);
      assert(cookie.includes('session_token'));
      const session = await fetch(`${base}/api/auth/get-session`, { headers: { cookie } });
      assert.equal((await session.json()).user.id, payload.user.id);
      assert.equal(await (await fetch(`${base}/api/auth/get-session`)).json(), null);
      assert.equal(
        (await post('sign-in/email', { email, password: 'incorrect-password' })).status,
        401,
      );
      assert.equal((await post('sign-out', {}, cookie)).status, 200);
      const revoked = await fetch(`${base}/api/auth/get-session`, { headers: { cookie } });
      assert.equal(await revoked.json(), null, 'Sign-out invalidates the stored session');
      const login = await post('sign-in/email', { email, password });
      assert.equal(login.status, 200);
      const restored = await fetch(`${base}/api/auth/get-session`, {
        headers: { cookie: cookieOf(login) },
      });
      assert.equal((await restored.json()).user.id, payload.user.id);
      assert.equal(
        (await post('sign-in/email', { email, password: 'x'.repeat(70_000) })).status,
        413,
      );
      const preflight = await fetch(`${base}/api/auth/sign-in/email`, {
        method: 'OPTIONS',
        headers: { origin: runtime.config.baseURL },
      });
      assert.equal(preflight.status, 204);
      assert.equal(preflight.headers.get('access-control-allow-credentials'), 'true');
    } finally {
      await runtime.db.delete(user).where(eq(user.email, email));
      server.closeAllConnections();
      await new Promise<void>((resolve) => server.close(() => resolve()));
      await runtime.pool.end();
    }
  },
);

test('Reject invalid production origin and short secrets', () => {
  const env = {
    DATABASE_URL: 'postgresql://unused',
    BETTER_AUTH_URL: 'https://auth.example.com',
    BETTER_AUTH_SECRET: 'x'.repeat(48),
  };
  assert.equal(readConfig(env).local, false);
  assert.throws(() => readConfig({ ...env, BETTER_AUTH_URL: 'http://auth.example.com' }), /HTTPS/);
  assert.throws(() => readConfig({ ...env, BETTER_AUTH_SECRET: 'short' }), /32/);
  assert.throws(
    () => readConfig({ ...env, AUTH_TRUSTED_ORIGINS: 'https://*.example.com/path' }),
    /exact origins/,
  );
});
