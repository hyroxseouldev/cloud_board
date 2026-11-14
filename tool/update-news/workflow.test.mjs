// Historical workflow fixtures retain legacy release/receipt contract coverage.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const workflow = readFileSync(new URL('../../.github/workflows/app-update-news.yml', import.meta.url), 'utf8');

test('news keeps manual direct receipt and historical run publishing without retired workflow hooks', () => {
  assert.match(workflow, /^  workflow_dispatch:/m);
  assert.match(workflow, /direct_deployment_id:/);
  assert.match(workflow, /deployment_run_id:/);
  assert.doesNotMatch(workflow, /^  (workflow_run|pull_request|push|verify):/m);
  assert.doesNotMatch(workflow, /node --test/);
});

test('publication keeps actual-step evidence and conditional runtime dependencies after removing self-tests', () => {
  // An upload can succeed before a later cleanup fails: filter by verified steps,
  // not the overall workflow conclusion, or a real installed build loses its news.
  assert.doesNotMatch(workflow, /workflow_run\.conclusion/);
  assert.match(workflow, /run: node tool\/update-news\/publish\.mjs/);
  assert.match(workflow, /run: node functions\/tools\/publish-update-news\.mjs "\$RUNNER_TEMP\/update-news\.json" --apply/);
  for (const name of ['Authenticate update news publisher', 'Cache publisher npm downloads', 'Install update news publisher dependencies', 'Publish app update news']) {
    const step = workflow.split(`- name: ${name}\n`)[1]?.split('\n      - ')[0];
    assert(step, `Missing ${name}`);
    assert.match(step, /if: steps\.news\.outputs\.exists == 'true'/);
  }
  assert.match(workflow, /npm ci --omit=dev --prefix functions/);
  assert.match(workflow, /group: linear-deployment-publisher\s+cancel-in-progress: false/);
});
