import test from 'node:test';
import assert from 'node:assert/strict';
import {reduceDisplayRecovery, mutateDisplayConnection, auditDisplayBindingChange} from '../src/display-recovery.js';

const now = 1_800_000_000_000;
const actor = (uid, provider) => ({uid, token: {firebase: {sign_in_provider: provider}}});
const owner = actor('owner', 'password'), tv = actor('tv-user', 'anonymous');
const data = {deviceId: 'tv', operationId: 'operation-1', connectionId: 'connection-1', expectedPairingCode: '123456', appVersion: '1.2.0', appBuild: '220'};
function seed() {
  return {users: {owner: {devices: {tv: {id: 'tv', displayUid: 'tv-user', paired: true,
    pairingCode: '123456', pairedAtMs: 1, recoveryProtocol: 1, name: 'TV', online: true,
    mode: 'display', lastSeenAtMs: now}}, activeSession: {id: 'session-1', revision: 7, status: 'playing'}}},
    displayAccess: {'tv-user': {ownerId: 'owner', deviceId: 'tv', pairingCode: '123456', pairedAtMs: 1}}};
}
const run = (root, auth = tv, action = 'verify', patch = {}, at = now) =>
  reduceDisplayRecovery(root, auth, action, {...data, ...patch}, at);
const code = expected => error => error.details?.code === expected;
function started(root = seed()) {
  root = run(root, owner, 'request').root;
  root = run(root, tv, 'report', {status: 'received'}).root;
  return run(root, tv, 'report', {status: 'recovering'}).root;
}

test('authenticated display repairs only a missing reverse UID and audits exact before/after', () => {
  const root = seed(); delete root.users.owner.devices.tv.displayUid;
  const result = run(root);
  assert.equal(result.result.status, 'repaired');
  assert.equal(result.root.users.owner.devices.tv.displayUid, 'tv-user');
  assert.deepEqual(result.root.users.owner.devices.tv.connectionVerification,
    {connectionId: 'connection-1', operationId: 'operation-1', verifiedAtMs: now, requestStartedAtMs: now, protocol: 1});
  assert.equal(root.users.owner.devices.tv.displayUid, undefined);
  const [audit] = Object.values(result.root.displayConnectionAudit);
  assert.equal(audit.before.displayUid, undefined); assert.equal(audit.after.displayUid, 'tv-user');
  assert.equal(audit.appVersion, '1.2.0'); assert.equal(audit.serverAtMs, now);
});
test('healthy verification preserves class, preferences and display state', () => {
  const root = seed(); root.users.owner.devices.tv.preferences = {cover: true};
  root.users.owner.devices.tv.displayState = 'black';
  const next = run(root).root;
  assert.deepEqual(next.users.owner.activeSession, root.users.owner.activeSession);
  assert.deepEqual(next.users.owner.devices.tv.preferences, {cover: true});
  assert.equal(next.users.owner.devices.tv.displayState, 'black');
});
test('missing UID repair requires a six-digit string on both sides, while healthy legacy bindings remain supported', () => {
  for (const pairingCode of ['invalid', '12345', '1234567', 123456, null]) {
    const root = seed(); delete root.users.owner.devices.tv.displayUid;
    root.users.owner.devices.tv.pairingCode = pairingCode;
    root.displayAccess['tv-user'].pairingCode = pairingCode;
    const before = structuredClone(root);
    assert.throws(() => run(root), code('connection_conflict'));
    assert.deepEqual(root, before);
  }
  const legacy = seed();
  delete legacy.users.owner.devices.tv.pairingCode;
  delete legacy.displayAccess['tv-user'].pairingCode;
  assert.equal(run(legacy).result.status, 'verified');
  assert.equal(run(seed()).result.status, 'verified');
});
test('old callable completion or duplicate verification cannot replace a newer connection proof', () => {
  const first = run(seed()).root;
  const newer = run(first, tv, 'verify', {operationId: 'new-operation', connectionId: 'new-connection'}, now + 1000).root;
  assert.throws(() => reduceDisplayRecovery(newer, tv, 'verify', {...data, operationId: 'old-in-flight'}, now + 2000,
    {requestStartedAtMs: now - 1000}), code('request_superseded'));
  assert.throws(() => run(newer, tv, 'verify', {}, now + 3000), code('request_superseded'));
  assert.equal(newer.users.owner.devices.tv.connectionVerification.connectionId, 'new-connection');
});
for (const [name, edit, expected] of [
  ['deleted registration', r => delete r.users.owner.devices.tv, 'device_unpaired'],
  ['explicit unpair', r => r.users.owner.devices.tv.paired = false, 'device_unpaired'],
  ['revoked mapping', r => delete r.displayAccess['tv-user'], 'connection_missing'],
  ['wrong UID', r => r.users.owner.devices.tv.displayUid = 'other-tv', 'connection_conflict'],
  ['different device', r => r.displayAccess['tv-user'].deviceId = 'other', 'connection_conflict'],
  ['changed owner', r => r.displayAccess['tv-user'].ownerId = 'other', 'device_unpaired'],
  ['duplicate mapping', r => r.displayAccess['other-tv'] = {...r.displayAccess['tv-user']}, 'connection_conflict'],
  ['duplicate reverse UID', r => r.users.owner.devices.other = {...r.users.owner.devices.tv, id: 'other'}, 'connection_conflict'],
  ['changed pairing code', r => r.displayAccess['tv-user'].pairingCode = '999999', 'connection_conflict'],
  ['different pairing generation', r => r.displayAccess['tv-user'].pairedAtMs = 2, 'connection_conflict'],
  ['account deletion', r => r.accountDeletions = {owner: true}, 'account_unavailable'],
  ['missing repair proof', r => {delete r.users.owner.devices.tv.displayUid; delete r.users.owner.devices.tv.pairingCode;}, 'connection_conflict'],
]) test(`${name} cannot be repaired`, () => {
  const root = seed(); edit(root); const before = structuredClone(root);
  assert.throws(() => run(root), code(expected)); assert.deepEqual(root, before);
});
test('owner, foreign TV, signed-in TV and malformed paths cannot impersonate a display', () => {
  assert.throws(() => run(seed(), owner), code('connection_conflict'));
  assert.throws(() => run(seed(), actor('foreign', 'anonymous')), code('connection_missing'));
  assert.throws(() => run(seed(), actor('tv-user', 'password')), code('device_unpaired'));
  assert.throws(() => run(seed(), tv, 'verify', {deviceId: '../other'}), code('invalid_request'));
});
test('signed legacy TV preserves scoped presence without claiming a separate TV identity', () => {
  const root = seed(); delete root.displayAccess; delete root.users.owner.devices.tv.displayUid;
  delete root.users.owner.devices.tv.recoveryProtocol;
  const result = run(root, owner);
  assert.equal(result.result.recoveryProtocol, 0);
  assert.equal(result.root.users.owner.devices.tv.connectionVerification.connectionId, 'connection-1');
  assert.equal(result.root.users.owner.devices.tv.displayUid, undefined);
});
test('owner request does not claim success or repair identity without actual TV authentication', () => {
  const root = seed(); delete root.users.owner.devices.tv.displayUid;
  const next = run(root, owner, 'request');
  assert.equal(next.result.status, 'requested'); assert.equal(next.result.expiresAtMs, now + 60000);
  assert.equal(next.root.users.owner.devices.tv.displayUid, undefined);
});
test('old TV is explicitly update-required', () => {
  const root = seed(); delete root.users.owner.devices.tv.recoveryProtocol;
  assert.throws(() => run(root, owner, 'request'), code('update_required'));
});
test('duplicate taps join one live request and expired IDs never replace a newer request', () => {
  const first = run(seed(), owner, 'request');
  const second = run(first.root, owner, 'request', {operationId: 'operation-2'}, now + 1);
  assert.equal(second.result.operationId, 'operation-1');
  const third = run(second.root, owner, 'request', {operationId: 'operation-3'}, now + 60001);
  const retry = run(third.root, owner, 'request');
  assert.equal(retry.result.status, 'expired');
  assert.equal(retry.root.users.owner.displayRecovery.tv.current.operationId, 'operation-3');
  const joinedRetry = run(third.root, owner, 'request', {operationId: 'operation-2'}, now + 70000);
  assert.equal(joinedRetry.result.operationId, 'operation-1');
  assert.equal(joinedRetry.result.status, 'expired');
});
test('received and recovering are separate; only latest server session/revision can succeed', () => {
  let root = run(seed(), owner, 'request').root;
  assert.throws(() => run(root, tv, 'report', {status: 'succeeded', sessionId: 'session-1', revision: 7}), code('invalid_request'));
  root = started();
  assert.throws(() => run(root, tv, 'report', {status: 'succeeded', sessionId: 'session-1', revision: 6}), code('latest_session_changed'));
  const result = run(root, tv, 'report', {status: 'succeeded', sessionId: 'session-1', revision: 7});
  assert.equal(result.result.verifiedAtMs, now); assert.equal(result.result.status, 'succeeded');
  assert.deepEqual(result.root.users.owner.activeSession, seed().users.owner.activeSession);
});
test('idle/completed latest state is recoverable without restarting the class', () => {
  for (const state of [null, {id: 'ended', revision: 9, status: 'completed'}]) {
    const root = seed(); root.users.owner.activeSession = state;
    const result = run(started(root), tv, 'report', {status: 'succeeded', sessionId: state?.id ?? null, revision: state?.revision ?? 0});
    assert.equal(result.result.sessionStatus, state?.status ?? 'idle');
    assert.deepEqual(result.root.users.owner.activeSession, state);
  }
});
test('idle clients may omit session/revision or send null without pretending an active revision', () => {
  for (const patch of [{}, {sessionId: null, revision: null}]) {
    const root = seed(); delete root.users.owner.activeSession;
    assert.equal(run(started(root), tv, 'report', {status: 'succeeded', ...patch}).result.status, 'succeeded');
  }
  assert.throws(() => run(started(), tv, 'report', {status: 'succeeded'}), code('latest_session_changed'));
});
test('malformed latest session cannot confirm success but a sanitized failure can still be recorded', () => {
  const root = started(); root.users.owner.activeSession = {id: 'broken'};
  assert.throws(() => run(root, tv, 'report', {status: 'succeeded', sessionId: 'broken'}), code('latest_session_changed'));
  assert.equal(run(root, tv, 'report', {status: 'failed'}).result.status, 'failed');
});
test('expired request, late previous response and revocation reject completion', () => {
  const root = started();
  assert.throws(() => run(root, tv, 'report', {status: 'failed'}, now + 60000), code('request_expired'));
  assert.throws(() => run(root, tv, 'report', {operationId: 'older', status: 'failed'}), code('request_superseded'));
  delete root.displayAccess['tv-user'];
  assert.throws(() => run(root, tv, 'report', {status: 'succeeded', sessionId: 'session-1', revision: 7}), code('connection_missing'));
});
test('failure records only controlled codes and no exception/token data', () => {
  const result = run(started(), tv, 'report', {status: 'failed', errorCode: 'Bearer secret', token: 'secret', message: 'private email'});
  assert.equal(result.result.errorCode, 'recovery_failed'); assert.equal(result.result.errorId, data.operationId);
  assert(!JSON.stringify(result.root).includes('secret')); assert(!JSON.stringify(result.root).includes('private email'));
});
test('terminal result is idempotent and cannot be changed by late failure', () => {
  const done = run(started(), tv, 'report', {status: 'succeeded', sessionId: 'session-1', revision: 7});
  const retry = run(done.root, tv, 'report', {status: 'failed'});
  assert.equal(retry.result.status, 'succeeded');
});
test('atomic pair creates both records, preserves retries and enforces registered legacy limit', () => {
  const root = {users: {owner: {}}, displayAccess: {'tv-user': {deviceId: 'tv', pairingCode: '123456'}},
    pairingCodes: {'123456': {code: '123456', deviceId: 'tv', displayUid: 'tv-user', claimed: false, expiresAtMs: now + 10000}},
    subscriptionAccess: {owner: {managed: true, plan: 'legacy', displayLimit: 1, validUntilMs: now + 10000}}};
  const first = run(root, owner, 'pair', {code: '123456', name: 'Original'});
  assert.equal(first.root.users.owner.devices.tv.displayUid, 'tv-user');
  assert.equal(first.root.displayAccess['tv-user'].ownerId, 'owner');
  assert.equal(first.root.users.owner.devices.tv.online, false);
  const retry = run(first.root, owner, 'pair', {code: '123456', name: 'Overwrite'});
  assert.equal(retry.root.users.owner.devices.tv.name, 'Original');
  assert.equal(Object.keys(retry.root.displayConnectionAudit).length, 1);
  const another = structuredClone(first.root);
  another.pairingCodes['222222'] = {...another.pairingCodes['123456'], claimed: false, ownerId: null, displayUid: 'tv-2', deviceId: 'tv-2'};
  another.displayAccess['tv-2'] = {deviceId: 'tv-2', pairingCode: '222222'};
  assert.throws(() => run(another, owner, 'pair', {code: '222222', operationId: 'new-pair'}), code('display_limit'));
});
test('lost pair response retried after unpair and exact code reuse cannot register another TV', () => {
  const root = seed();
  root.subscriptionAccess = {owner: {managed: true, plan: 'premium', displaysUnlimited: true, validUntilMs: now + 100000}};
  root.pairingCodes = {'123456': {deviceId: 'tv', displayUid: 'tv-user', ownerId: 'owner', claimed: true, expiresAtMs: now + 10000}};
  let state = run(root, owner, 'pair', {code: '123456'}).root;
  state = run(state, owner, 'unpair', {operationId: 'delete-op'}).root;
  state.pairingCodes['123456'] = {deviceId: 'new-tv', displayUid: 'new-tv-user', claimed: false, expiresAtMs: now + 10000};
  state.displayAccess['new-tv-user'] = {deviceId: 'new-tv', pairingCode: '123456'};
  const retry = run(state, owner, 'pair', {code: '123456'});
  assert.deepEqual(retry.result, {paired: true, deviceId: 'tv'});
  assert.equal(retry.root.users.owner.devices['new-tv'], undefined);
  assert.equal(retry.root.displayAccess['new-tv-user'].ownerId, undefined);
  assert.throws(() => run(state, owner, 'pair', {code: '654321'}), code('invalid_request'));
  assert.throws(() => run(state, owner, 'unpair'), code('invalid_request'));
});
test('unpair atomically revokes exact mapping and blocks old reconnection without touching class/other TV', () => {
  const root = started(); root.users.owner.devices.other = {id: 'other', paired: true, displayUid: 'other-tv'};
  const result = run(root, owner, 'unpair');
  assert.equal(result.root.displayAccess['tv-user'], undefined);
  assert.equal(result.root.users.owner.devices.tv, undefined);
  assert.deepEqual(result.root.users.owner.activeSession, root.users.owner.activeSession);
  assert.deepEqual(result.root.users.owner.devices.other, root.users.owner.devices.other);
  assert.equal(result.root.users.owner.displayRecovery.tv.current.errorCode, 'device_unpaired');
  assert.throws(() => run(result.root), code('connection_missing'));
});
test('late legacy Admin pair cannot undo revocation; a fresh pairing generation remains supported', () => {
  const original = seed(), removed = run(original, owner, 'unpair').root;
  // Simulate an old deployed pairing function finishing its captured writes.
  removed.users.owner.devices.tv = {...original.users.owner.devices.tv, pairedAtMs: now + 10};
  removed.displayAccess['tv-user'] = {...original.displayAccess['tv-user'], pairedAtMs: now + 10};
  assert.throws(() => run(removed), code('device_unpaired'));
  removed.users.owner.devices.tv.pairingCode = '999999';
  removed.displayAccess['tv-user'].pairingCode = '999999';
  assert.equal(run(removed, tv, 'verify', {operationId: 'fresh-connection'}).result.status, 'verified');
});
test('unpair retry cannot delete a new pairing generation with the same device ID', () => {
  const root = run(seed(), owner, 'unpair').root;
  root.users.owner.devices.tv = {...seed().users.owner.devices.tv, pairingCode: '222222'};
  root.displayAccess['tv-user'] = {...seed().displayAccess['tv-user'], pairingCode: '222222'};
  const repeated = run(root, owner, 'unpair');
  assert.deepEqual(repeated.root.users.owner.devices.tv, root.users.owner.devices.tv);
  assert.deepEqual(repeated.root.displayAccess, root.displayAccess);
  assert.throws(() => run(root, owner, 'unpair', {operationId: 'new-delete', expectedPairingCode: '123456'}), code('connection_conflict'));
});
test('atomic CAS rechecks binding on retry after concurrent owner removal', async () => {
  const before = seed(), removed = seed(); delete removed.users.owner.devices.tv;
  const database = {ref: () => ({transaction: async fn => {
    assert.equal(fn(null), null); assert(fn(before));
    assert.equal(fn(removed), undefined); return {committed: false};
  }})};
  await assert.rejects(mutateDisplayConnection(database, tv, 'verify', data, {now: () => now}), code('device_unpaired'));
});
test('legacy binding audit ignores heartbeat and is event-idempotent', async () => {
  let writes = 0, value;
  const database = {ref: () => ({transaction: async fn => {writes++; value = fn(value);}})};
  const event = {id: 'event-1', time: new Date(now).toISOString(), params: {ownerId: 'owner', deviceId: 'tv'},
    data: {before: {val: () => ({id: 'tv', displayUid: 'tv-user', paired: true})},
      after: {val: () => ({id: 'tv', displayUid: 'tv-user', paired: true, lastSeenAtMs: now})}}};
  await auditDisplayBindingChange(database, event, 'device'); assert.equal(writes, 0);
  event.data.after.val = () => ({id: 'tv', paired: true});
  await auditDisplayBindingChange(database, event, 'device');
  const first = structuredClone(value); await auditDisplayBindingChange(database, event, 'device');
  assert.deepEqual(value, first); assert.equal(value.actor, 'unavailable_in_database_event');
});
