// appReleases remains the only update policy read by installed clients.
// All writes require an explicit project, stale-write token and release evidence.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash, randomUUID} from 'node:crypto';
import {parseArgs} from 'node:util';
import {pathToFileURL} from 'node:url';

const platforms = ['ios', 'android', 'tv'];
const canonical = value => JSON.stringify(value, (_, item) => item && typeof item === 'object' && !Array.isArray(item)
  ? Object.fromEntries(Object.keys(item).sort().map(key => [key, item[key]])) : item);
export const policyHash = value => createHash('sha256').update(canonical(value ?? null)).digest('hex');

export function validateReleasePolicy(platform, value) {
  assert(platforms.includes(platform), 'platform must be ios, android or tv');
  assert(value && typeof value === 'object' && !Array.isArray(value), 'Policy must be an object');
  assert(Object.keys(value).every(k => ['enabled','published','latestBuild','minimumBuild','publishedBuild','version','message','storeUrl'].includes(k)), 'unknown fields');
  assert(typeof value.enabled === 'boolean' && typeof value.published === 'boolean');
  for (const k of ['latestBuild','minimumBuild','publishedBuild']) assert(Number.isSafeInteger(value[k]) && value[k] > 0 && value[k] < 2147483647, k);
  assert(value.minimumBuild <= value.latestBuild && value.latestBuild <= value.publishedBuild, 'invalid build order');
  assert(typeof value.version === 'string' && value.version.trim().length > 0 && value.version.length <= 32);
  assert(typeof value.message === 'string' && value.message.length <= 500);
  const url = new URL(value.storeUrl);
  assert(url.protocol === 'https:' && !url.username && !url.password && !url.port && !url.hash, 'unsafe store URL');
  assert(platform === 'ios'
    ? url.hostname === 'apps.apple.com' && /^\/(?:[a-z]{2}\/)?app\/(?:[^/]+\/)?id6809105126$/.test(url.pathname) && !url.search
    : url.hostname === 'play.google.com' && url.pathname === '/store/apps/details' &&
      [...url.searchParams].length === 1 && url.searchParams.get('id') === 'com.sunmkim.cloudboard', 'wrong app');
  if (value.enabled) assert(value.published, 'never enable an unpublished release');
  return value;
}

export function validateAvailability(platform, policy, evidence, now = Date.now()) {
  if (!policy.enabled) return; // Emergency disabling must not require store access.
  assert(evidence && typeof evidence === 'object', 'Enabled policy requires install availability evidence');
  assert.equal(evidence.platform, platform, 'Evidence platform mismatch');
  assert.equal(evidence.build, policy.publishedBuild, 'Evidence build mismatch');
  assert.equal(evidence.version, policy.version, 'Evidence version mismatch');
  assert.equal(evidence.storeUrl, policy.storeUrl, 'Evidence store URL mismatch');
  assert.equal(evidence.installable, true, 'Upload/processing is not proof of installation');
  assert.equal(evidence.track, 'production', 'Global update policy cannot require an internal/TestFlight-only release');
  assert.match(evidence.sourceSha || '', /^[a-f0-9]{40}$/);
  assert(Array.isArray(evidence.countries) && evidence.countries.length > 0 && evidence.countries.every(x => /^[A-Z]{2}$/.test(x)), 'Verified countries required');
  assert(typeof evidence.deviceVerification === 'string' && evidence.deviceVerification.trim().length >= 10, 'Record OS/device install verification');
  assert(typeof evidence.verifiedBy === 'string' && evidence.verifiedBy.trim().length >= 2, 'Record verifier');
  const verifiedAt = Date.parse(evidence.verifiedAt);
  assert(Number.isFinite(verifiedAt) && verifiedAt <= now && now - verifiedAt <= 7 * 86400000, 'Availability must have been verified within seven days');
  const url = new URL(evidence.verificationUrl);
  assert(url.protocol === 'https:' && !url.username && !url.password && ['appstoreconnect.apple.com', 'apps.apple.com', 'play.google.com'].includes(url.hostname), 'Official store evidence URL required');
}

export async function applyReleasePolicy(database, {platform, value, expectedHash, actor, reason, evidence = null, restoreFrom = null, now = new Date().toISOString(), id = randomUUID()}) {
  validateReleasePolicy(platform, value);
  assert.match(expectedHash || '', /^[a-f0-9]{64}$/, 'Read current policy hash before writing');
  assert(typeof actor === 'string' && actor.trim().length >= 2 && actor.length <= 200, 'Operator identity required');
  assert(typeof reason === 'string' && reason.trim().length >= 5 && reason.length <= 1000, 'Change/restore reason required');
  assert(Number.isFinite(Date.parse(now)), 'Invalid audit time');
  validateAvailability(platform, value, evidence, Date.parse(now));
  const reference = database.doc(`appReleases/${platform}`);
  const audit = database.doc(`appReleasePolicyHistory/${id}`);
  return database.runTransaction(async transaction => {
    const snapshot = await transaction.get(reference);
    const previous = snapshot.exists ? snapshot.data() : null;
    assert.equal(policyHash(previous), expectedHash, 'Policy changed; inspect the new value before applying');
    // The history row and policy update succeed together; app policy shape stays unchanged.
    transaction.create(audit, {platform, actor, reason, changedAt: now, before: previous, after: value,
      beforeHash: expectedHash, afterHash: policyHash(value), evidence, restoreFrom});
    transaction.set(reference, value);
    return {id, previous, next: value, hash: policyHash(value)};
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const {values, positionals} = parseArgs({allowPositionals: true, options: {
    project: {type: 'string'}, apply: {type: 'boolean', default: false}, show: {type: 'boolean', default: false},
    restore: {type: 'string'}, 'expected-hash': {type: 'string'}, actor: {type: 'string'}, reason: {type: 'string'}, evidence: {type: 'string'},
  }});
  const [platform, file] = positionals;
  assert(platforms.includes(platform), 'Usage: release-policy.mjs ios|android|tv [policy.json] --project <id> [--show|--restore <history-id>|--apply]');
  assert(positionals.length <= 2 && !(values.show && (values.apply || file || values.restore)), 'Invalid command combination');
  assert(!(file && values.restore), 'Choose a policy file or a history entry');
  assert(['cloud-board-stationd', 'cloud-board-development'].includes(values.project), 'Explicit known --project required');
  assert(!process.env.FIRESTORE_EMULATOR_HOST, 'Use a separate emulator test harness');
  let database;
  if (values.show || values.apply || values.restore) {
    const {initializeApp, applicationDefault} = await import('firebase-admin/app');
    const {getFirestore} = await import('firebase-admin/firestore');
    database = getFirestore(initializeApp({credential: applicationDefault(), projectId: values.project}));
  }
  if (values.show) {
    const snapshot = await database.doc(`appReleases/${platform}`).get();
    const current = snapshot.exists ? snapshot.data() : null;
    console.log(JSON.stringify({project: values.project, platform, current, hash: policyHash(current)}, null, 2));
  } else {
    let value;
    if (values.restore) {
      assert.match(values.restore, /^[a-zA-Z0-9_-]{1,100}$/, 'Invalid history ID');
      const history = (await database.doc(`appReleasePolicyHistory/${values.restore}`).get()).data();
      assert.equal(history?.platform, platform, 'History platform mismatch/missing');
      assert(history.before, 'No previous policy; explicitly publish a disabled policy instead');
      value = history.before;
    } else value = JSON.parse(readFileSync(file, 'utf8'));
    validateReleasePolicy(platform, value);
    const evidence = values.evidence ? JSON.parse(readFileSync(values.evidence, 'utf8')) : null;
    validateAvailability(platform, value, evidence);
    console.log(JSON.stringify({project: values.project, platform, mode: values.apply ? 'apply' : 'dry-run', value, restoreFrom: values.restore ?? null}, null, 2));
    if (values.apply) console.log(JSON.stringify(await applyReleasePolicy(database, {platform, value,
      expectedHash: values['expected-hash'], actor: values.actor, reason: values.reason, evidence, restoreFrom: values.restore ?? null})));
  }
}
