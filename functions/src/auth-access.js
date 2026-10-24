import {randomUUID} from 'node:crypto';

// Administrative Auth changes must pass through this path. RTDB cannot inspect
// Firebase Auth's disabled/revocation state from security rules. Block existing
// tokens in DB first, then change Auth; a partial failure stays blocked.
export async function revokeAccountSessions({database, auth, uid, disable = false, now = Date.now}) {
  if (typeof uid !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(uid)) throw new Error('Invalid UID');
  const operationId = randomUUID(), path = database.ref(`authAccess/${uid}`);
  const cutoff = Math.ceil(now() / 1000);
  await path.transaction(current => ({...current, disabled: true,
    validAfterSeconds: Math.max(current?.validAfterSeconds || 0, cutoff), operationId}));
  if (disable) await auth.updateUser(uid, {disabled: true});
  await auth.revokeRefreshTokens(uid);
  const record = await auth.getUser(uid);
  await path.transaction(current => current?.operationId !== operationId ? undefined : ({
    disabled: disable || record.disabled,
    validAfterSeconds: Math.max(current.validAfterSeconds, Math.floor(Date.parse(record.tokensValidAfterTime) / 1000)),
  }));
}
