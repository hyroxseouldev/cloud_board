import assert from 'node:assert/strict';
import {appendFileSync, mkdirSync, rmSync, writeFileSync} from 'node:fs';
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

function waiverTimestamp(value, name) {
  assert(typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z$/.test(value), `${name} must be a UTC ISO timestamp`);
  const timestamp = Date.parse(value);
  const canonical = value.includes('.') ? value : value.replace('Z', '.000Z');
  assert(Number.isFinite(timestamp) && new Date(timestamp).toISOString() === canonical, `Invalid ${name}`);
  return timestamp;
}

// An explicit release-owner waiver is not evidence that device QA passed.
// It applies only to one candidate and expires within 24 hours of approval.
export function requirePhysicalQaWaiver(value, sha, now = Date.now()) {
  assert.match(sha || '', /^[a-f0-9]{40}$/);
  assert(Number.isFinite(now), 'Invalid waiver evaluation time');
  const record = typeof value === 'string' ? JSON.parse(value || 'null') : value;
  assert(record && record.sha === sha, 'Physical QA waiver for this exact candidate SHA is required');
  assert.equal(record.result, 'waived');
  assert.equal(record.physicalQaPerformed, false, 'A waiver must explicitly record that physical QA was not performed');
  assert(typeof record.approvedBy === 'string' && record.approvedBy.trim().length >= 2, 'Missing waiver approver');
  assert(typeof record.reason === 'string' && record.reason.trim(), 'Missing waiver reason');
  const approvedAt = waiverTimestamp(record.approvedAt, 'approvedAt');
  const expiresAt = waiverTimestamp(record.expiresAt, 'expiresAt');
  assert(approvedAt <= now, 'Waiver approval cannot be in the future');
  assert(expiresAt > approvedAt && expiresAt - approvedAt <= 24 * 60 * 60_000, 'Waiver validity must be positive and at most 24 hours');
  assert(now < expiresAt, 'Physical QA waiver has expired');
  return {sha, result: 'waived', approvedBy: record.approvedBy.trim(), approvedAt: record.approvedAt,
    reason: record.reason.trim(), expiresAt: record.expiresAt, physicalQaPerformed: false};
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const auditPath = 'build/release/physical-qa-decision.json';
  // A rejected invocation must not leave an earlier successful decision behind.
  rmSync(auditPath, {force: true});
  const waiver = process.env.CLASS_START_PHYSICAL_WAIVER;
  const decision = waiver
    ? requirePhysicalQaWaiver(waiver, process.env.GITHUB_SHA)
    : {...requirePhysicalApproval(process.env.CLASS_START_PHYSICAL_APPROVAL, process.env.GITHUB_SHA),
      result: 'passed', physicalQaPerformed: true};
  mkdirSync('build/release', {recursive: true});
  writeFileSync(auditPath, `${JSON.stringify({...decision, recordedAt: new Date().toISOString(),
    runId: process.env.GITHUB_RUN_ID || null, runAttempt: process.env.GITHUB_RUN_ATTEMPT || null}, null, 2)}\n`);
  const message = decision.result === 'waived'
    ? `Physical class-start QA waived for ${decision.sha}. Physical QA was not performed.`
    : `Physical class-start QA passed attestation verified for ${decision.sha}.`;
  console.log(message);
  if (process.env.GITHUB_STEP_SUMMARY) {
    appendFileSync(process.env.GITHUB_STEP_SUMMARY, `### Physical QA release decision\n\n${message}\n\nAudit record: \`${auditPath}\`.\n`);
  }
}
