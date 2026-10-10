import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {github} from './release.mjs';

export const requiredCheck = 'firebase-required';
export const actionsAppId = 15368; // github.com GitHub Actions integration, not any status publisher.
export const protection = {
  required_status_checks: {strict: true, checks: [{context: requiredCheck, app_id: actionsAppId}]},
  enforce_admins: true,
  required_pull_request_reviews: {dismiss_stale_reviews: true, require_code_owner_reviews: false, required_approving_review_count: 0},
  restrictions: null, allow_force_pushes: false, allow_deletions: false, required_conversation_resolution: true,
};
export function validateProtection(value) {
  assert.equal(value.required_status_checks?.strict, true, 'Latest base must be tested');
  assert(value.required_status_checks.checks?.some(c => c.context === requiredCheck && c.app_id === actionsAppId), 'Missing trusted firebase-required check');
  assert(value.required_pull_request_reviews, 'Pull requests must be required');
  assert.equal(value.enforce_admins?.enabled, true, 'Admin bypass must be disabled');
  assert.equal(value.allow_force_pushes?.enabled, false);
  assert.equal(value.allow_deletions?.enabled, false);
  assert.equal(value.required_conversation_resolution?.enabled, true);
  const bypass = value.required_pull_request_reviews.bypass_pull_request_allowances;
  assert(!bypass || ['users', 'teams', 'apps'].every(k => !bypass[k]?.length), 'Unexpected PR bypass');
}
export async function manageProtection({mode, repository, request}) {
  assert.equal(repository, 'hyroxseouldev/cloud_board');
  assert(['plan', 'check', 'apply'].includes(mode));
  if (mode === 'plan') return {mode, branches: ['main', 'develop'], protection};
  if (mode === 'apply') {
    // Check both branches before changing either branch's settings.
    for (const branch of ['main', 'develop']) {
      const head = await request(`/repos/${repository}/git/ref/heads/${branch}`);
      const checks = await request(`/repos/${repository}/commits/${head.object.sha}/check-runs?per_page=100`);
      assert(checks.check_runs.some(c => c.name === requiredCheck && c.conclusion === 'success' && c.app?.id === actionsAppId),
        `Run ${requiredCheck} successfully on ${branch} before applying protection`);
    }
  }
  for (const branch of ['main', 'develop']) {
    if (mode === 'apply') await request(`/repos/${repository}/branches/${branch}/protection`, {method: 'PUT', body: protection});
    validateProtection(await request(`/repos/${repository}/branches/${branch}/protection`));
  }
  return {mode, status: 'success', branches: ['main', 'develop']};
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const mode = process.argv[2] || 'plan';
  console.log(JSON.stringify(await manageProtection({mode, repository: process.env.GITHUB_REPOSITORY || 'hyroxseouldev/cloud_board', request: github}), null, 2));
}
