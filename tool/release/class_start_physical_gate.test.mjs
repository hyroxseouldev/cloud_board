import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {requirePhysicalApproval, requirePhysicalQaWaiver} from './class_start_physical_gate.mjs';
const sha = 'a'.repeat(40);
const fixture = () => ({sha, result: 'passed', approvedBy: 'release-owner', testedAt: '2026-10-14T12:00:00Z',
  evidenceUrl: 'https://example.invalid/private-qa', isolatedTestAccount: true, tvBuilds: ['old 68', 'candidate 70'],
  controllers: Object.fromEntries(['android', 'ios', 'web'].map(p => [p, {starts: 10, tvCount: 3, pauseResumeEnd: true, reconnectAndRestart: true, build: 'candidate 70'}]))});
test('accepts exact candidate human QA attestation', () => assert.equal(requirePhysicalApproval(fixture(), sha).sha, sha));
for (const condition of ['missing', 'changed-sha', 'failed', 'missing-platform', 'one-tv', 'few-starts', 'no-approval', 'no-evidence', 'production-account']) {
  test(`blocks ${condition} physical evidence`, () => {
    const f = fixture();
    if (condition === 'changed-sha') f.sha = 'b'.repeat(40);
    if (condition === 'failed') f.result = 'failed';
    if (condition === 'missing-platform') delete f.controllers.ios;
    if (condition === 'one-tv') f.controllers.web.tvCount = 1;
    if (condition === 'few-starts') f.controllers.android.starts = 9;
    if (condition === 'no-approval') f.approvedBy = '';
    if (condition === 'no-evidence') delete f.evidenceUrl;
    if (condition === 'production-account') f.isolatedTestAccount = false;
    assert.throws(() => requirePhysicalApproval(condition === 'missing' ? null : f, sha));
  });
}

const now = Date.parse('2026-10-15T00:00:00.000Z');
const waiverFixture = (time = now) => ({sha, result: 'waived', approvedBy: 'release-owner',
  approvedAt: new Date(time - 60_000).toISOString(), reason: 'Owner explicitly waived device QA for this release.',
  expiresAt: new Date(time + 60 * 60_000).toISOString(), physicalQaPerformed: false});

test('accepts an explicit exact-candidate waiver without inventing passed QA', () => {
  const waiver = waiverFixture();
  assert.deepEqual(requirePhysicalQaWaiver(JSON.stringify(waiver), sha, now), waiver);
  assert.throws(() => requirePhysicalApproval(waiver, sha));
});

test('accepts the 24-hour validity limit and excludes the expiration instant', () => {
  const waiver = {...waiverFixture(), approvedAt: new Date(now).toISOString(), expiresAt: new Date(now + 24 * 60 * 60_000).toISOString()};
  assert.equal(requirePhysicalQaWaiver(waiver, sha, now).result, 'waived');
  assert.equal(requirePhysicalQaWaiver(waiver, sha, Date.parse(waiver.expiresAt) - 1).result, 'waived');
  assert.throws(() => requirePhysicalQaWaiver(waiver, sha, Date.parse(waiver.expiresAt)), /expired/);
});

test('accepts UTC timestamps without fractional seconds', () => {
  const waiver = {...waiverFixture(), approvedAt: '2026-10-15T00:00:00Z', expiresAt: '2026-10-15T01:00:00Z'};
  assert.equal(requirePhysicalQaWaiver(waiver, sha, now).result, 'waived');
});

const invalidWaivers = {
  'different candidate': {sha: 'b'.repeat(40)},
  'passed result': {result: 'passed'},
  'failed result': {result: 'failed'},
  'missing approver': {approvedBy: undefined},
  'blank approver': {approvedBy: ' '},
  'missing reason': {reason: undefined},
  'blank reason': {reason: ' '},
  'performed QA claim': {physicalQaPerformed: true},
  'missing unperformed QA declaration': {physicalQaPerformed: undefined},
  'string unperformed QA declaration': {physicalQaPerformed: 'false'},
  'missing approval time': {approvedAt: undefined},
  'missing expiry': {expiresAt: undefined},
  'invalid approval time': {approvedAt: 'invalid'},
  'invalid expiry': {expiresAt: 'invalid'},
  'invalid calendar date': {approvedAt: '2026-02-30T00:00:00.000Z'},
  'timezone-free approval': {approvedAt: '2026-10-15T00:00:00'},
  'future approval': {approvedAt: new Date(now + 1).toISOString()},
  'expired waiver': {expiresAt: new Date(now - 1).toISOString()},
  'zero validity': {expiresAt: new Date(now - 60_000).toISOString()},
  'negative validity': {expiresAt: new Date(now - 60_001).toISOString()},
  'over 24 hours': {expiresAt: new Date(now - 60_000 + 24 * 60 * 60_000 + 1).toISOString()},
};
for (const [condition, fields] of Object.entries(invalidWaivers)) {
  test(`rejects waiver with ${condition}`, () => {
    assert.throws(() => requirePhysicalQaWaiver({...waiverFixture(), ...fields}, sha, now));
  });
}
test('missing, malformed, non-object waiver and invalid evaluation contexts fail closed', () => {
  for (const value of [undefined, null, '', 'null', 'true', '[]', '{', 1]) {
    assert.throws(() => requirePhysicalQaWaiver(value, sha, now));
  }
  for (const invalid of [NaN, Infinity, '2026-10-15']) {
    assert.throws(() => requirePhysicalQaWaiver(waiverFixture(), sha, invalid));
  }
  assert.throws(() => requirePhysicalQaWaiver(waiverFixture(), 'not-a-sha', now));
});

function cliFixture(t) {
  const cwd = mkdtempSync(join(tmpdir(), 'physical-qa-gate-'));
  t.after(() => rmSync(cwd, {recursive: true, force: true}));
  const audit = join(cwd, 'build/release/physical-qa-decision.json');
  const summary = join(cwd, 'summary.md');
  return {audit, summary, run: (approval = '', waiver = '') => spawnSync(process.execPath,
    [fileURLToPath(new URL('./class_start_physical_gate.mjs', import.meta.url))], {cwd, encoding: 'utf8', timeout: 10_000,
      env: {...process.env, GITHUB_SHA: sha, GITHUB_RUN_ID: '123', GITHUB_RUN_ATTEMPT: '2', GITHUB_STEP_SUMMARY: summary,
        CLASS_START_PHYSICAL_APPROVAL: approval, CLASS_START_PHYSICAL_WAIVER: waiver}})};
}

test('CLI records an honest waiver in the retained audit and GitHub summary', t => {
  const f = cliFixture(t);
  const waiver = waiverFixture(Date.now());
  const result = f.run('', JSON.stringify(waiver));
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stderr);
  const audit = JSON.parse(readFileSync(f.audit, 'utf8'));
  assert.deepEqual({...audit, recordedAt: undefined, runId: undefined, runAttempt: undefined},
    {...waiver, recordedAt: undefined, runId: undefined, runAttempt: undefined});
  assert.equal(audit.runId, '123');
  assert.equal(audit.runAttempt, '2');
  assert(Number.isFinite(Date.parse(audit.recordedAt)));
  assert.match(result.stdout, /QA waived/);
  assert.match(readFileSync(f.summary, 'utf8'), /Physical QA was not performed/);
  assert.doesNotMatch(result.stdout, /passed/);
});

test('CLI retains the original passed physical approval route', t => {
  const f = cliFixture(t);
  const result = f.run(JSON.stringify(fixture()));
  assert.equal(result.status, 0, result.stderr);
  const audit = JSON.parse(readFileSync(f.audit, 'utf8'));
  assert.equal(audit.result, 'passed');
  assert.equal(audit.physicalQaPerformed, true);
  assert.equal(audit.evidenceUrl, fixture().evidenceUrl);
  assert.match(readFileSync(f.summary, 'utf8'), /passed attestation verified/);
});

test('CLI rejects invalid explicit waiver even with passed QA and removes stale audit', t => {
  const f = cliFixture(t);
  for (const waiver of ['{', JSON.stringify({...waiverFixture(Date.now()), sha: 'b'.repeat(40)})]) {
    mkdirSync(join(f.audit, '..'), {recursive: true});
    writeFileSync(f.audit, '{"result":"passed"}');
    const result = f.run(JSON.stringify(fixture()), waiver);
    assert.notEqual(result.status, 0);
    assert.equal(existsSync(f.audit), false);
    assert.equal(existsSync(f.summary), false);
  }
});

test('CLI without either approval or waiver cannot create release evidence', t => {
  const f = cliFixture(t);
  assert.notEqual(f.run().status, 0);
  assert.equal(existsSync(f.audit), false);
  assert.equal(existsSync(f.summary), false);
});

test('production wires the explicit waiver into the gate before Firebase authentication', () => {
  const workflow = readFileSync(new URL('../../.github/workflows/firebase-hosting-merge.yml', import.meta.url), 'utf8');
  assert.match(workflow, /CLASS_START_PHYSICAL_WAIVER: \$\{\{ vars\.CLASS_START_PHYSICAL_WAIVER \}\}/);
  const gate = workflow.indexOf('run: node tool/release/class_start_physical_gate.mjs');
  assert(gate >= 0);
  assert(gate < workflow.indexOf('name: Authenticate Firebase rule deployment'));
});
