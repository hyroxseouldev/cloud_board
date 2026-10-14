import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  accountAudienceBranding,
  publicAudienceBranding,
  readPublicAudienceBranding,
} from '../src/services/audience-branding.js';

test('account copy requires the linked owner and a current canonical-matching projection, independent of global rollout', () => {
  const now = 1000;
  const entitlement = {
    managed: true,
    canStartClass: true,
    plan: 'plus',
    status: 'active',
    policyVersion: 'plan-entitlements-v2',
    revision: 3,
    validUntilMs: 2000,
    canHideCloudBoardLogo: true,
  };
  const projection = {
    ownerId: 'uid',
    plan: 'plus',
    policyVersion: 'plan-entitlements-v2',
    revision: 3,
    validUntilMs: 2000,
    audienceLogoVersion: 'audience-logo-v1',
    audienceLogoScope: 'all-audience',
    showCloudBoardLogo: false,
  };
  assert.deepEqual(accountAudienceBranding('uid', entitlement, projection, now), {
    version: 'audience-logo-v1',
    scope: 'all-audience',
    validUntilMs: 2000,
    canHideCloudBoardLogo: true,
  });
  for (const patch of [
    { ownerId: 'other' },
    { revision: 2 },
    { validUntilMs: 2001 },
    { plan: 'free' },
    { policyVersion: 'v1' },
    { audienceLogoVersion: 'old' },
    { audienceLogoScope: 'unknown' },
    { showCloudBoardLogo: undefined },
  ])
    assert.equal(
      accountAudienceBranding('uid', entitlement, { ...projection, ...patch }, now).scope,
      'standby',
    );
  for (const patch of [
    { policyVersion: 'plan-entitlements-v1' },
    { status: 'unknown' },
    { validUntilMs: now },
    { canStartClass: false },
    { managed: false },
    { canHideCloudBoardLogo: undefined },
  ])
    assert.equal(
      accountAudienceBranding('uid', { ...entitlement, ...patch }, projection, now).scope,
      'standby',
    );
  const standby = accountAudienceBranding(
    'uid',
    entitlement,
    { ...projection, audienceLogoScope: 'standby' },
    now,
  );
  assert.equal(standby.scope, 'standby');
  assert.equal(standby.canHideCloudBoardLogo, true);
  assert.equal(accountAudienceBranding('uid', entitlement, undefined, now).scope, 'standby');
  const free = accountAudienceBranding(
    'uid',
    { ...entitlement, plan: 'free', canHideCloudBoardLogo: false },
    { ...projection, plan: 'free', showCloudBoardLogo: true },
    now,
  );
  assert.equal(free.scope, 'all-audience');
  assert.equal(free.canHideCloudBoardLogo, false);
});

const active = { version: 'audience-logo-v1', enabled: true, allAccounts: true };
test('public audience branding requires the exact global server rollout, not a pilot or plan sale', () => {
  assert.deepEqual(publicAudienceBranding(active), {
    version: active.version,
    scope: 'all-audience',
  });
  for (const config of [
    undefined,
    null,
    {},
    [],
    true,
    { ...active, version: 'audience-logo-v2' },
    { ...active, enabled: false },
    { ...active, enabled: 'true' },
    { ...active, allAccounts: undefined, ownerIds: ['pilot-owner'] },
    { ...active, allAccounts: 'true' },
    { enabled: true, allAccounts: true, version: 'plan-entitlements-v2' },
    { planSalesReady: true },
  ])
    assert.deepEqual(publicAudienceBranding(config), { version: active.version, scope: 'standby' });
  assert.equal(
    JSON.stringify(publicAudienceBranding({ ...active, ownerIds: ['private-owner'] })).includes(
      'private-owner',
    ),
    false,
  );
});

test('missing, failed and timed-out Firestore reads return standby copy without rejecting config', async () => {
  assert.deepEqual(
    await readPublicAudienceBranding(async () => active),
    publicAudienceBranding(active),
  );
  assert.deepEqual(
    await readPublicAudienceBranding(async () => undefined),
    publicAudienceBranding(undefined),
  );
  assert.deepEqual(
    await readPublicAudienceBranding(async () => {
      throw Error('offline');
    }),
    publicAudienceBranding(undefined),
  );
  assert.deepEqual(
    await readPublicAudienceBranding(() => new Promise(() => {})),
    publicAudienceBranding(undefined),
  );
});
