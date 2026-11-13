import {randomUUID} from 'node:crypto';
import {assertUsage, imageUsagePolicyRevision, nowOf, usagePeriods, usageHash, requireUsageMutation,
  requireUsageProject, validUsageId, validBytes, usageConfigEnabled} from './image-usage-policy.js';
import {loadUsageLedger, operationRef, checkOperation} from './image-usage-ledger.js';

export async function handleUsageGrant(ctx) {
  const {input, actor} = ctx, now = nowOf(ctx);
  requireUsageProject(ctx.projectId); requireUsageMutation(input);
  assertUsage(validUsageId(actor?.uid) && actor?.token?.quotaOperator === true && Number.isSafeInteger(actor.token.auth_time) &&
    actor.token.auth_time * 1000 <= now + 5000 && actor.token.auth_time * 1000 >= now - 300000,
  'media_lease_invalid', 'permission-denied');
  assertUsage(validUsageId(input.accountId) && typeof input.reason === 'string' &&
    input.reason.trim().length >= 10 && input.reason.length <= 1000);
  assertUsage(['grant', 'revoke'].includes(input.action));
  const hash = usageHash(input), grantId = randomUUID();
  return ctx.db.runTransaction(async tx => {
    const l = await loadUsageLedger(ctx, tx, input.accountId), op = operationRef(l, 'grant', input.action, input.requestId);
    const prior = checkOperation(await tx.get(op), hash); if (prior) return prior;
    const beforeRevision = l.account.revision ?? 0;
    let result;
    if (input.action === 'grant') {
      const c = l.config?.grantLimits;
      assertUsage(usageConfigEnabled(l.config, ctx.projectId) && c &&
        [c.maxAdditionalDayBytes, c.maxAdditionalMonthBytes, c.maxValidityMs].every(v => validBytes(v) && v > 0),
      'grant_configuration_required');
      const {additionalDayBytes: day, additionalMonthBytes: month, validFromMs: from, validUntilMs: until} = input;
      assertUsage([day, month, from, until].every(validBytes) && day + month > 0 &&
        day <= c.maxAdditionalDayBytes && month <= c.maxAdditionalMonthBytes && until > from &&
        until - from <= c.maxValidityMs && until > now);
      const p = usagePeriods(from), last = usagePeriods(until - 1);
      assertUsage(input.targetDayKey === p.dayKey && input.targetMonthKey === p.monthKey &&
        last.dayKey === p.dayKey && last.monthKey === p.monthKey);
      assertUsage(l.account.mode === 'enrolled' && l.policy, 'policy_or_client_upgrade_required');
      const currentDay = l.grants.reduce((n, g) => n + (g.targetDayKey === p.dayKey ? g.additionalDayBytes : 0), day);
      const currentMonth = l.grants.reduce((n, g) => n + (g.targetMonthKey === p.monthKey ? g.additionalMonthBytes : 0), month);
      assertUsage(Number.isSafeInteger(currentDay) && Number.isSafeInteger(currentMonth));
      l.put(l.base.collection('grants').doc(grantId), {grantId, status: 'active', accountId: input.accountId,
        targetDayKey: p.dayKey, targetMonthKey: p.monthKey, additionalDayBytes: day, additionalMonthBytes: month,
        validFromMs: from, validUntilMs: until, reason: input.reason.trim(), operatorSubject: actor.uid,
        requestId: input.requestId, payloadHash: hash, policyRevision: imageUsagePolicyRevision,
        createdAtMs: now, revokedAtMs: null});
      result = {schemaVersion: 1, grantId, status: 'active', revision: beforeRevision + 1};
    } else {
      assertUsage(validUsageId(input.grantId));
      const ref = l.base.collection('grants').doc(input.grantId), grant = (await tx.get(ref)).data();
      assertUsage(grant, 'media_lease_invalid', 'permission-denied');
      if (grant.status !== 'revoked') l.put(ref, {...grant, status: 'revoked', revokedAtMs: now,
        revokedBy: actor.uid, revokeReason: input.reason.trim()});
      result = {schemaVersion: 1, grantId: input.grantId, status: 'revoked', revision: beforeRevision + 1};
    }
    l.put(l.base.collection('audit').doc(usageHash(['grant', input.action, input.requestId])), {
      type: `grant_${input.action}`, operatorSubject: actor.uid, accountId: input.accountId,
      grantId: result.grantId, requestId: input.requestId, payloadHash: hash, reason: input.reason.trim(),
      beforeRevision, afterRevision: beforeRevision + 1, createdAtMs: now, policyRevision: imageUsagePolicyRevision});
    l.put(op, {payloadHash: hash, result, createdAtMs: now}); l.flush(); return result;
  });
}
