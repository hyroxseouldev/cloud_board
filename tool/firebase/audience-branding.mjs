import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
import {audienceLogoVersion, audienceBrandingEnabled, audienceBrandingPublicReady,
  applyBrandEntitlement, projectStandbyBranding} from '../../functions/src/standby-branding.js';

const integer = value => Number.isSafeInteger(value) && value > 0;
const https = value => {try {return new URL(value).protocol === 'https:';} catch {return false;}};
export function validateSupportMatrix(value) {
  assert(value?.audienceLogoVersion === audienceLogoVersion, 'Exact audience logo version required');
  assert(value.platforms && typeof value.platforms === 'object' && !Array.isArray(value.platforms), 'Platform build evidence required');
  assert(Object.keys(value.platforms).length > 0, 'At least one supported platform required');
  for (const [platform, entry] of Object.entries(value.platforms)) {
    assert(['android', 'ios', 'web', 'macos', 'windows', 'linux'].includes(platform), 'Unknown platform');
    if (platform === 'web') {
      // Hosting uses run.attempt build IDs; these are not ordered integers.
      assert(Array.isArray(entry.allowedBuilds) && entry.allowedBuilds.length > 0 &&
        entry.allowedBuilds.every(build => typeof build === 'string' && /^[a-zA-Z0-9._-]{1,80}$/.test(build)) &&
        new Set(entry.allowedBuilds).size === entry.allowedBuilds.length,
      'Web requires exact verified published build IDs');
    } else {
      assert(integer(entry.minimumBuild) && integer(entry.publishedBuild) && entry.publishedBuild >= entry.minimumBuild, 'Published build must cover the first supported build');
    }
    assert(https(entry.evidenceUrl), 'HTTPS release/build evidence required');
  }
  return value;
}

// Build numbers are evidence, not an invented runtime capability. The operator
// supplies the first release containing this implementation; mobile store release
// policy must independently confirm it has actually been published.
export function audienceReadiness(state, support, now = Date.now()) {
  validateSupportMatrix(support);
  const reasons = [], warnings = [];
  const e = state.entitlement;
  if (state.deleted) reasons.push('account-deleting');
  if (e?.policyVersion !== 'plan-entitlements-v2') reasons.push('account-policy-not-v2');
  try { applyBrandEntitlement(state.brandConfig ?? state.brand ?? {}, e, now); }
  catch { reasons.push('branding-entitlement-unavailable'); }
  const accountReady = reasons.length === 0;
  const paired = Object.entries(state.devices ?? {}).filter(([, d]) => d &&
    (Object.hasOwn(d, 'paired') ? d.paired === true : typeof d.pairedAtMs === 'number' && d.pairedAtMs > 0));
  const devices = paired.map(([id, d]) => {
    const platform = d.appPlatform === 'tv' ? 'android' : d.appPlatform;
    const spec = support.platforms[platform];
    const build = platform === 'web' ? d.appBuild :
      typeof d.appBuild === 'string' && /^\d+$/.test(d.appBuild) ? Number(d.appBuild) : d.appBuild;
    const problems = [];
    if (!spec) problems.push('platform-support-unverified');
    else if (platform === 'web') {
      if (typeof build !== 'string' || !spec.allowedBuilds.includes(build)) problems.push('client-build-not-in-published-evidence');
    }
    else {
      if (!integer(build) || build < spec.minimumBuild) problems.push('client-update-required');
      if (integer(build) && build > spec.publishedBuild) problems.push('client-build-not-in-published-evidence');
      if (['android', 'ios'].includes(platform)) {
        const release = state.releases?.[platform];
        if (release?.enabled !== true || release.published !== true || !integer(release.minimumBuild) ||
            !integer(release.latestBuild) || !integer(release.publishedBuild) ||
            release.minimumBuild < spec.minimumBuild || release.latestBuild < release.minimumBuild ||
            release.publishedBuild < release.latestBuild || release.publishedBuild < spec.publishedBuild) {
          problems.push('published-update-policy-unverified');
        }
      }
    }
    if (d.online !== true || !(d.lastSeenAtMs > now - 75000 && d.lastSeenAtMs <= now + 5000)) warnings.push(`device-offline-or-stale:${id}`);
    for (const reason of problems) reasons.push(`${reason}:${id}`);
    return {id, platform: platform ?? 'unknown',
      build: platform === 'web' && typeof build === 'string' ? build : integer(build) ? build : null,
      ready: problems.length === 0};
  });
  if (!devices.length) warnings.push('no-paired-displays-to-inspect');
  if (state.activeSession?.status && state.activeSession.status !== 'completed') warnings.push('ongoing-class-not-interrupted');
  const activationEnabled = audienceBrandingEnabled(state.rollout, state.ownerId);
  return {ownerId: state.ownerId, activationEnabled, publicReady: audienceBrandingPublicReady(state.rollout),
    readyForAllAudience: reasons.length === 0, readyToApply: accountReady && (!activationEnabled || reasons.length === 0),
    expectedScope: activationEnabled ? 'all-audience' : 'standby', reasons, warnings, devices,
    previousProjectionRevision: state.projection?.projectionRevision ?? null};
}

export async function reconcileAudienceOwners({owners, support, load, project, apply = false, now = Date.now}) {
  validateSupportMatrix(support);
  const reports = [];
  for (const owner of owners) {
    // No mutation is reachable in the default read-only path. Re-read all
    // readiness inputs immediately before an explicit per-owner apply.
    const state = await load(owner);
    const report = audienceReadiness(state, support, now());
    if (!apply) {reports.push({...report, applied: false}); continue;}
    if (!report.readyToApply) {reports.push({...report, applied: false}); continue;}
    const fresh = audienceReadiness(await load(owner), support, now());
    if (!fresh.readyToApply) {reports.push({...fresh, applied: false}); continue;}
    const committed = await project(owner);
    const after = await load(owner);
    const p = after.projection;
    const verified = committed && p?.ownerId === owner && p.audienceLogoVersion === audienceLogoVersion &&
      p.audienceLogoScope === fresh.expectedScope && typeof p.showCloudBoardLogo === 'boolean' &&
      Number.isSafeInteger(p.projectionRevision) && p.projectionRevision > (fresh.previousProjectionRevision ?? 0);
    reports.push({...fresh, applied: verified, projectionRevision: p?.projectionRevision ?? null,
      ...(verified ? {} : {applyError: 'projection-not-confirmed'})});
  }
  return {audienceLogoVersion, mode: apply ? 'apply' : 'read-only', reports};
}

export function parseArguments(argv) {
  const options = {owners: [], apply: false};
  for (let i = 0; i < argv.length; i++) {
    const key = argv[i];
    if (key === '--apply') {options.apply = true; continue;}
    assert(['--project', '--database-url', '--owner', '--support', '--confirm-project'].includes(key), `Unknown argument: ${key}`);
    const value = argv[++i];
    assert(value && !value.startsWith('--'), `Value required: ${key}`);
    if (key === '--owner') options.owners.push(value);
    else options[{'--project': 'project', '--database-url': 'databaseUrl', '--support': 'supportFile', '--confirm-project': 'confirmProject'}[key]] = value;
  }
  assert(/^[a-z][a-z0-9-]{3,62}$/.test(options.project ?? ''), 'Explicit Firebase project required');
  const database = new URL(options.databaseUrl);
  assert(database.protocol === 'https:' && !database.username && !database.password && database.pathname === '/' && !database.search && !database.hash &&
    (database.hostname === `${options.project}-default-rtdb.asia-southeast1.firebasedatabase.app` || database.hostname === `${options.project}-default-rtdb.firebaseio.com`),
  'Database URL must match the explicit project');
  assert(options.supportFile, 'Explicit supported build evidence file required');
  assert(options.owners.length > 0 && options.owners.length <= 100 && new Set(options.owners).size === options.owners.length &&
    options.owners.every(id => /^[^/\u0000-\u001f]{1,128}$/.test(id)), 'Supply 1–100 distinct owner IDs; bulk wildcard is not supported');
  if (options.apply) assert(options.confirmProject === options.project, '--apply requires --confirm-project matching the target');
  return options;
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  const support = validateSupportMatrix(JSON.parse(readFileSync(options.supportFile, 'utf8')));
  const require = createRequire(new URL('../../functions/package.json', import.meta.url));
  const {initializeApp} = require('firebase-admin/app');
  const {getFirestore} = require('firebase-admin/firestore');
  const {getDatabase} = require('firebase-admin/database');
  const app = initializeApp({projectId: options.project, databaseURL: options.databaseUrl});
  const db = getFirestore(app), realtime = getDatabase(app);
  const load = async uid => {
    const [entitlement, deletion, billing, rollout, android, ios] = await db.getAll(
      ...[`subscriptionEntitlements/${uid}`, `accountDeletions/${uid}`, `billingAccounts/${uid}`,
        'appConfig/audienceBranding', 'appReleases/android', 'appReleases/ios'].map(path => db.doc(path)));
    const [operations, devices, session] = await Promise.all([
      realtime.ref(`users/${uid}/operations`).get(), realtime.ref(`users/${uid}/devices`).get(),
      realtime.ref(`users/${uid}/activeSession`).get()]);
    const data = operations.val() ?? {};
    return {ownerId: uid, entitlement: entitlement.data(), deleted: deletion.exists || billing.data()?.deleted === true,
      rollout: rollout.data(), releases: {android: android.data(), ios: ios.data()},
      brand: data.brand, brandConfig: data.brandConfig, projection: data.brandProjection,
      devices: devices.val(), activeSession: session.val()};
  };
  try {
    const result = await reconcileAudienceOwners({owners: options.owners, support, load,
      project: uid => projectStandbyBranding(db, realtime, uid), apply: options.apply});
    console.log(JSON.stringify({project: options.project, ...result}, null, 2));
    if (result.reports.some(r => options.apply ? !r.applied : !r.readyForAllAudience)) process.exitCode = 2;
  } finally {await app.delete();}
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main().catch(error => {console.error(error.code ?? error.message); process.exitCode = 1;});
}
