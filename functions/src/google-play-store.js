import {GoogleAuth} from 'google-auth-library';
import {playPackageName, purchaseKey} from './google-play-policy.js';

const auth = new GoogleAuth({scopes: ['https://www.googleapis.com/auth/androidpublisher']});
const root = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${playPackageName}/purchases`;

async function request(url, method = 'GET', data = {}) {
  try {
    return (await (await auth.getClient()).request({url, method, ...(method === 'POST' ? {data} : {}), timeout: 20000})).data;
  } catch (error) {
    // Google errors include the token-bearing URL: never expose/log them upstream.
    const safe = new Error('google-play-unavailable');
    safe.httpStatus = Number(error.response?.status) || 0;
    throw safe;
  }
}
export async function latestPlaySubscription(token) {
  purchaseKey(token);
  return request(`${root}/subscriptionsv2/tokens/${encodeURIComponent(token)}`);
}
export async function acknowledgePlaySubscription(token, productId, resubscribeAccountToken) {
  purchaseKey(token);
  await request(`${root}/subscriptions/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(token)}:acknowledge`, 'POST',
    resubscribeAccountToken ? {externalAccountIds: {obfuscatedAccountId: resubscribeAccountToken}} : {});
}
