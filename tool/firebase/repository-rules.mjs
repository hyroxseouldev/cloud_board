import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {github} from './release.mjs';

// Active branch rules are readable with repository metadata permission. The
// observer never needs a stored administration token or any write permission.
export const releaseRuleset = {
  name: 'CloudBoard verified releases', target: 'branch', enforcement: 'active',
  bypass_actors: [],
  conditions: {ref_name: {include: ['refs/heads/main', 'refs/heads/develop'], exclude: []}},
  rules: [
    {type: 'deletion'}, {type: 'non_fast_forward'},
    {type: 'pull_request', parameters: {required_approving_review_count: 0,
      dismiss_stale_reviews_on_push: true, require_code_owner_review: false,
      require_last_push_approval: false, required_review_thread_resolution: true}},
    {type: 'required_status_checks', parameters: {strict_required_status_checks_policy: true,
      do_not_enforce_on_create: false,
      required_status_checks: [{context: 'firebase-required', integration_id: 15368}]}},
  ],
};

export function validateActiveRules(rules) {
  assert(Array.isArray(rules), 'Missing active repository rules');
  for (const type of ['deletion', 'non_fast_forward', 'pull_request']) {
    assert(rules.some(r => r.type === type), `Missing branch rule: ${type}`);
  }
  assert(rules.some(r => r.type === 'pull_request' && r.parameters?.required_review_thread_resolution),
    'Unresolved review threads must block merge');
  assert(rules.some(r => r.type === 'required_status_checks' &&
    r.parameters?.strict_required_status_checks_policy &&
    r.parameters.required_status_checks?.some(c => c.context === 'firebase-required' && c.integration_id === 15368)),
  'Missing latest-base Firebase check from GitHub Actions');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  if (process.argv[2] === 'plan') console.log(JSON.stringify(releaseRuleset, null, 2));
  else {
    assert.equal(process.argv[2], 'check');
    assert.equal(process.env.GITHUB_REPOSITORY, 'hyroxseouldev/cloud_board');
    for (const branch of ['main', 'develop']) {
      validateActiveRules(await github(`/repos/${process.env.GITHUB_REPOSITORY}/rules/branches/${branch}?per_page=100`));
      console.log(`${branch}: verified active release rules`);
    }
  }
}
