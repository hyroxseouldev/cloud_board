import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';

// The repository variable is set by the release owner only after isolated
// device QA. Automated tests cannot manufacture this human attestation.
export function requirePhysicalApproval(value, sha) {
  assert.match(sha || '', /^[a-f0-9]{40}$/);
  const record = typeof value === 'string' ? JSON.parse(value || 'null') : value;
  assert(record && record.sha === sha, 'Physical class-start approval for this exact candidate SHA is required');
  assert.equal(record.result, 'passed');
  assert(typeof record.approvedBy === 'string' && record.approvedBy.trim().length >= 2, 'Missing release approver');
  assert(Number.isFinite(Date.parse(record.testedAt)), 'Missing physical test time');
  const evidence = new URL(record.evidenceUrl);
  assert.equal(evidence.protocol, 'https:', 'Use the restricted-access evidence record URL');
  assert.equal(record.isolatedTestAccount, true);
  for (const platform of ['android', 'ios', 'web']) {
    const check = record.controllers?.[platform];
    assert(check?.starts >= 10, `${platform}: ten physical starts required`);
    assert.equal(check.tvCount, 3, `${platform}: three physical TVs required`);
    assert.equal(check.pauseResumeEnd, true);
    assert.equal(check.reconnectAndRestart, true);
    assert(typeof check.build === 'string' && check.build.trim(), `${platform}: controller build required`);
  }
  assert(record.tvBuilds?.length >= 2 && record.tvBuilds.every(b => typeof b === 'string' && b.trim()), 'Record supported and candidate TV builds');
  return {sha, evidenceUrl: evidence.href, approvedBy: record.approvedBy};
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const approval = requirePhysicalApproval(process.env.CLASS_START_PHYSICAL_APPROVAL, process.env.GITHUB_SHA);
  console.log(`Physical class-start release approval verified for ${approval.sha}`);
}
