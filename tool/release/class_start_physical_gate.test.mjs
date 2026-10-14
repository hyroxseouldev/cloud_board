import test from 'node:test';
import assert from 'node:assert/strict';
import {requirePhysicalApproval} from './class_start_physical_gate.mjs';
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
