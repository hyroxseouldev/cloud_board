export const appleSecretNames = Object.freeze([
  'APPLE_IAP_PRIVATE_KEY', 'APPLE_IAP_KEY_ID', 'APPLE_IAP_ISSUER_ID',
]);

// This non-secret deploy setting is passed through the Functions .env file.
// Default deployments do not reference secrets that have not been created yet.
export function appleSecretBindings(env = process.env) {
  return env.APPLE_IAP_SECRETS_ENABLED === 'true' ? [...appleSecretNames] : [];
}

export function appleApiReady(env = process.env) {
  return appleSecretBindings(env).length > 0 &&
    appleSecretNames.every(name => typeof env[name] === 'string' && env[name].trim().length > 0);
}
