import assert from 'node:assert/strict';
import {appendFileSync} from 'node:fs';
import {parseArgs} from 'node:util';
import {pathToFileURL} from 'node:url';

export async function requireCommonValidation({repository, sha, request}) {
  assert.match(repository || '', /^[\w.-]+\/[\w.-]+$/);
  assert.match(sha || '', /^[a-f0-9]{40}$/);
  const response = await request(`/repos/${repository}/actions/workflows/firebase-hosting-merge.yml/runs?branch=main&head_sha=${sha}&per_page=100`);
  assert((response.total_count ?? 0) <= 100, 'Too many validation runs to identify the latest attempt safely');
  const runs = (response.workflow_runs ?? []).filter(run => run.head_sha === sha && run.head_branch === 'main' &&
    run.head_repository?.full_name === repository && ['push', 'workflow_dispatch'].includes(run.event));
  const time = run => Date.parse(run.run_started_at || run.created_at || '') || 0;
  runs.sort((a, b) => time(b) - time(a) || b.id - a.id);
  const checks = [
    {name: 'app-validation', steps: ['Analyze', 'Test']},
    {name: 'class_start_regressions / Class start lifecycle and TV preparation', skippedName: 'class_start_regressions',
      steps: ['Required native logic regressions', 'Required web regressions']},
  ];
  for (const run of runs) {
    assert(Number.isSafeInteger(run.run_attempt) && run.run_attempt > 0,
      'Latest main validation attempt is missing; an older successful attempt cannot authorize release.');
    const {jobs} = await request(`/repos/${repository}/actions/runs/${run.id}/attempts/${run.run_attempt}/jobs?per_page=100`);
    // A planned backend/rules-only or no-op run intentionally performs neither
    // common check. It must not invalidate the earlier app evidence for this SHA.
    const plannedWithoutCommonChecks = run.conclusion !== 'cancelled' &&
      jobs?.some(job => job.name === 'Verify deployment target' && job.conclusion === 'success') &&
      checks.every(check => {
        // GitHub may represent a skipped reusable workflow by its calling job
        // ID instead of expanding the called job's display name.
        const job = jobs?.find(job => job.name === check.name) ||
          jobs?.find(job => check.skippedName && job.name === check.skippedName);
        return job?.conclusion === 'skipped';
      });
    if (plannedWithoutCommonChecks) continue;
    assert(run.conclusion !== 'cancelled',
      'Latest main validation was cancelled; an older successful attempt cannot authorize release.');
    for (const check of checks) {
      const job = jobs?.find(job => job.name === check.name);
      assert(job?.conclusion === 'success' && check.steps.every(name =>
        job.steps?.some(step => step.name === name && step.conclusion === 'success')),
      `Latest main validation has not passed ${check.name}; an older successful attempt cannot authorize release.`);
    }
    // Only validation is reused. Server/Hosting jobs need not finish; the separate
    // backend gate checks compatibility with what is actually deployed now.
    return run;
  }
  assert.fail('No main integration validation for this app source. Run validation-only on main, or use QA mode for internal testing.');
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
  const message = `Reused main integration validation for app ${sha}: ${run.html_url} (attempt ${run.run_attempt}).`;
  console.log(message);
  if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${message}\n`);
}
