export function readConfig(env: NodeJS.ProcessEnv = process.env) {
  const required = (key: string) => {
    const value = env[key];
    if (!value) throw new Error(`Missing ${key}`);
    return value;
  };
  const baseURL = new URL(required('BETTER_AUTH_URL'));
  const secret = required('BETTER_AUTH_SECRET');
  if (secret.length < 32) throw new Error('BETTER_AUTH_SECRET must have at least 32 characters');
  const local = ['localhost', '127.0.0.1'].includes(baseURL.hostname);
  if (!local && baseURL.protocol !== 'https:')
    throw new Error('HTTPS is required outside localhost');
  if (baseURL.pathname !== '/' || baseURL.search || baseURL.hash) {
    throw new Error('BETTER_AUTH_URL must be an origin without a path');
  }
  const trustedOrigins = (env.AUTH_TRUSTED_ORIGINS || baseURL.origin).split(',').map((value) => {
    const origin = new URL(value.trim());
    if (origin.origin !== value.trim() || origin.hostname.includes('*'))
      throw new Error('Trusted origins must be exact origins');
    return origin.origin;
  });
  return {
    baseURL: baseURL.origin,
    secret,
    local,
    trustedOrigins,
    databaseURL: required('DATABASE_URL'),
  };
}
