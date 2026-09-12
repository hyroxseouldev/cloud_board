// Orchestration is dependency-injected so tests never contact real user data.
export async function eraseAccount(uid, services) {
  // Locks must precede every destructive step. Keep them on partial failure.
  await services.lock(uid);
  await services.stopAndDetach(uid);
  await services.disableAuth(uid);
  await services.deleteFiles(uid);
  await services.deleteDocuments(uid);
  await services.deleteRealtime(uid);
  await services.verifyEmpty(uid);
  // Auth is last: deleting Auth alone does not delete any application data.
  await services.deleteAuth(uid);
  await services.complete(uid);
}

export function requireDeletionIdentity(auth, nowSeconds) {
  if (!auth || auth.token?.firebase?.sign_in_provider !== 'google.com') {
    throw new Error('unauthenticated');
  }
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(auth.uid)) throw new Error('invalid-argument');
  const age = nowSeconds - Number(auth.token.auth_time);
  if (!Number.isFinite(age) || age < -30 || age > 300) throw new Error('reauthentication-required');
  return auth.uid; // Caller-supplied uid is never accepted.
}
