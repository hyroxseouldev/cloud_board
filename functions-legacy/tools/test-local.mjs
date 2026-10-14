import { spawnSync } from 'node:child_process';
import { readdirSync } from 'node:fs';
// No inherited credentials, external database, SMS/billing config or .env files.
const env = Object.fromEntries(['PATH', 'SystemRoot', 'TEMP', 'TMP', 'LANG'].filter(k => process.env[k]).map(k => [k, process.env[k]]));
Object.assign(env, {
  GCLOUD_PROJECT: 'demo-cloudboard-legacy',
  BETTER_AUTH_URL: 'http://localhost:3087',
  BETTER_AUTH_SECRET: 'local-test-only-not-a-secret-'.repeat(2),
  DATABASE_URL: 'postgresql://unused:unused@127.0.0.1:1/unused',
  BILLING_MODE: 'disabled',
  ENTITLEMENT_SYNC_ENABLED: 'false',
});
const files = readdirSync(new URL('../test/', import.meta.url)).filter(n => n.endsWith('.test.ts')).sort();
const result = spawnSync(process.execPath, ['--import', 'tsx', '--test', ...files.map(n => `test/${n}`)], { cwd: new URL('../', import.meta.url), env, stdio: 'inherit' });
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
