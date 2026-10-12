import assert from 'node:assert/strict';

export const retirementPolicyFile = 'tool/firebase/support-retirements.json';
const retainedCoverage = ['frozen-fixtures', 'current-reader-of-historical-data', 'historical-writes-against-current-rules'];

// These are the two precisely identified source groups covered by the owner's
// zero-active-user declaration. Further retirement needs a new explicit review;
// a wildcard or relabeling a recent source must never silence its failures.
const authorizedSources = new Set([
  'c85167e863ee5e8e9212722572ab57df65801eeb',
  'c54588cc7733ac8577d11c036c21635d1f283f2a',
]);

export function validateRetirements(registry, policy, baseline = {format: 1, retirements: []}) {
  assert.equal(policy.format, 1);
  assert(Array.isArray(policy.retirements));
  const sources = new Map(), ids = new Set();
  for (const entry of policy.retirements) {
    assert.match(entry.id, /^[a-z0-9-]+$/);
    assert(!ids.has(entry.id), 'Duplicate retirement id'); ids.add(entry.id);
    assert.match(entry.sourceCommit, /^[a-f0-9]{40}$/);
    assert(authorizedSources.has(entry.sourceCommit), 'Source has no explicit retirement authorization');
    assert(!sources.has(entry.sourceCommit), 'Duplicate retirement source');
    const clients = registry.clients.filter(c => c.sourceCommit === entry.sourceCommit);
    assert(clients.length, 'Unknown retirement source');
    assert.deepEqual([...entry.clients].sort(), clients.map(c => c.client).sort(), 'Retirement must identify every client of the exact source');
    assert.equal(entry.scope, 'forward-semantic-reader-only');
    assert.equal(entry.effectiveFromVersion, '1.1.0');
    assert.equal(entry.reason, 'owner-declared-zero-active-users-2026-10-13-KST');
    assert.deepEqual(entry.authorization, {
      kind: 'owner-conversation', date: '2026-10-13', timezone: 'Asia/Seoul', remotelyVerified: false,
      quotes: ['아그럼강제업데이트시키면되잖아근데지금쓰는사람없어서ㄱㅊ음', '쓰는사람없으니까1.1.0로올려'],
    }, 'Retirement evidence must remain the owner declaration, not a remotely verified claim');
    assert.deepEqual(entry.retainedCoverage, retainedCoverage);
    sources.set(entry.sourceCommit, entry);
  }
  // Audit entries are append-only, independently of the immutable client ledger.
  for (const previous of baseline.retirements) {
    assert.deepEqual(policy.retirements.find(entry => entry.id === previous.id), previous,
      `Retirement audit entry changed or removed: ${previous.id}`);
  }
  return sources;
}
