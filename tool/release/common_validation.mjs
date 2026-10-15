import assert from 'node:assert/strict';
import {appendFileSync} from 'node:fs';
import {parseArgs} from 'node:util';
import {pathToFileURL} from 'node:url';
import {isReleaseTag} from '../firebase/release.mjs';
import {productionRuns} from '../firebase/release-runs.mjs';

export async function requireCommonValidation({repository, sha, request}) {
  assert.match(repository || '', /^[\w.-]+\/[\w.-]+$/);
  assert.match(sha || '', /^[a-f0-9]{40}$/);
  const response = await request(`/repos/${repository}/actions/workflows/firebase-hosting-merge.yml/runs?head_sha=${sha}&per_page=100`);
  assert((response.total_count ?? 0) <= 100, 'Too many validation runs to identify the latest attempt safely');
  const runs = productionRuns(response.workflow_runs ?? [], repository, sha).filter(run => isReleaseTag(run.head_branch));
  const checks = [
    {name: 'app-validation', steps: ['Analyze', 'Test']},
    {name: 'class_start_regressions / Class start lifecycle and TV preparation',
      steps: ['Required native logic regressions', 'Required web regressions']},
  ];
  for (const run of runs) {
    assert(Number.isSafeInteger(run.run_attempt) && run.run_attempt > 0,
      'Latest release validation attempt is missing; an older successful attempt cannot authorize release.');
    // Manual uploads follow the same completion rule as the automatic
    // workflow_run trigger. Passing app checks cannot bypass failed contracts
    // or an unfinished production release attempt.
    assert(run.status === 'completed' && run.conclusion === 'success',
      'Latest release validation workflow has not completed successfully; an older successful attempt cannot authorize release.');
    const {jobs} = await request(`/repos/${repository}/actions/runs/${run.id}/attempts/${run.run_attempt}/jobs?per_page=100`);
    // Every release tag runs both common checks, even for backend-only changes.
    // A skipped or incomplete retry cannot reuse an older green tag attempt.
    for (const check of checks) {
      const job = jobs?.find(job => job.name === check.name);
      assert(job?.conclusion === 'success' && check.steps.every(name =>
        job.steps?.some(step => step.name === name && step.conclusion === 'success')),
      `Latest release validation has not passed ${check.name}; an older successful attempt cannot authorize release.`);
    }
    // The separate backend gate still checks the live deployment at upload time.
    return run;
  }
  assert.fail('No release integration validation for this app source. Run the release-tag validation, or use QA mode for internal testing.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const {values} = parseArgs({options: {'source-sha': {type: 'string'}}});
  const {GITHUB_TOKEN: token, GITHUB_REPOSITORY: repository} = process.env;
  assert(token, 'Read-only GitHub token required');
  const sha = values['source-sha'];
  const run = await requireCommonValidation({repository, sha, request: async path => {
    const response = await fetch(`https://api.github.com${path}`, {headers: {
      Authorization: `Bearer ${token}`, Accept: 'application/vnd.github+json',
    }, signal: AbortSignal.timeout(30_000)});
    assert(response.ok, `Validation lookup failed (${response.status})`);
    return response.json();
  }});
  const message = `Reused release integration validation for app ${sha}: ${run.html_url} (attempt ${run.run_attempt}).`;
  console.log(message);
  if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${message}\n`);
}
