import {readFileSync} from 'node:fs';
import {AppStoreServerAPIClient, SignedDataVerifier, Environment} from '@apple/app-store-server-library';
import {appAppleId, bundleId, validateTransaction} from './billing-policy.js';
import {appleApiReady} from './apple-billing-config.js';

const services = new Map();

function service(environment) {
  if (services.has(environment)) return services.get(environment);
  const roots = ['AppleRootCA-G2.cer', 'AppleRootCA-G3.cer'].map(name =>
    readFileSync(new URL(`../certificates/${name}`, import.meta.url)));
  const verifier = new SignedDataVerifier(roots, true, environment, bundleId, appAppleId);
  const key = process.env.APPLE_IAP_PRIVATE_KEY;
  const keyId = process.env.APPLE_IAP_KEY_ID;
  const issuer = process.env.APPLE_IAP_ISSUER_ID;
  const value = {verifier, client: () => {
    if (!key || !keyId || !issuer) throw new Error('apple-not-configured');
    return new AppStoreServerAPIClient(key, keyId, issuer, bundleId, environment);
  }};
  services.set(environment, value);
  return value;
}

// Try both TRUSTED verifiers; never trust an environment decoded without verification.
export async function verifyApplePayload(payload, notification = false) {
  if (typeof payload !== 'string' || payload.length > 100000 || payload.split('.').length !== 3) {
    throw new Error('invalid-signed-payload');
  }
  for (const env of [Environment.PRODUCTION, Environment.SANDBOX]) {
    try {
      const {verifier} = service(env);
      const decoded = notification ? await verifier.verifyAndDecodeNotification(payload) :
        await verifier.verifyAndDecodeTransaction(payload);
      if (!notification) validateTransaction(decoded, env);
      return {decoded, environment: env};
    } catch (_) { /* No unverified fallback, including Xcode/LocalTesting. */ }
  }
  throw new Error('apple-signature-invalid');
}

export async function latestAppleSubscription(originalId, environment) {
  if (!appleApiReady()) throw new Error('apple-not-configured');
  const {verifier, client} = service(environment);
  const response = await client().getAllSubscriptionStatuses(originalId);
  if (response.environment !== environment || response.bundleId !== bundleId) throw new Error('apple-app-mismatch');
  const rows = response.data?.flatMap(group => group.lastTransactions ?? []) ?? [];
  const item = rows.find(row => row.originalTransactionId === originalId);
  if (!item?.signedTransactionInfo || !item.signedRenewalInfo) throw new Error('apple-subscription-missing');
  const t = validateTransaction(await verifier.verifyAndDecodeTransaction(item.signedTransactionInfo), environment);
  const renewal = await verifier.verifyAndDecodeRenewalInfo(item.signedRenewalInfo);
  if (t.originalTransactionId !== originalId || renewal.originalTransactionId !== originalId ||
      renewal.environment !== environment) throw new Error('apple-renewal-mismatch');
  return {transaction: t, renewal, status: item.status};
}
