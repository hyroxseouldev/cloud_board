import {appendFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';

const workflow = 'firebase-hosting-merge.yml';

// A passing Flutter build alone is insufficient: the exact commit must have
// passed the rules contracts AND finished deploying its backend and web app.
export async function requireBackend({repository, sha, ref, request, sleep, timeoutMs = 45 * 60_000, now = Date.now}) {
  if (ref !== 'refs/heads/main' || !/^[a-f0-9]{40}$/.test(sha || '')) {
    throw new Error('Production upload requires an exact main commit.');
  }
  const started = now();
  do {
    const head = await request(`/repos/${repository}/git/ref/heads/main`);
    if (head.object.sha !== sha) throw new Error('This commit is no longer main. Upload the latest verified commit.');
    const result = await request(`/repos/${repository}/actions/workflows/${workflow}/runs?branch=main&event=push&head_sha=${sha}&per_page=100`);
    const run = result.workflow_runs
      .filter(r => r.head_sha === sha && r.head_branch === 'main' && r.event === 'push' && r.head_repository?.full_name === repository)
      .sort((a, b) => b.id - a.id)[0];
    // Never fall back to an older successful run when its retry/latest run fails.
    if (run?.status === 'completed') {
      if (run.conclusion !== 'success') throw new Error(`Backend deployment ${run.id} ended with ${run.conclusion}. Client upload blocked.`);
      // Also require the concrete deploy step. A future workflow skip must not
      // accidentally turn a green validation-only run into a release permit.
      const jobs = await request(`/repos/${repository}/actions/runs/${run.id}/attempts/${run.run_attempt}/jobs?per_page=100`);
      const job = jobs.jobs.find(j => j.name === 'build_and_deploy' && j.conclusion === 'success');
      const deployed = job?.steps?.some(s => s.name === 'Deploy account deletion functions and data rules' && s.conclusion === 'success');
      if (!deployed) throw new Error('No successful backend deployment step for this exact run attempt.');
      return run;
    }
    if (now() - started >= timeoutMs) break;
    await sleep(Math.min(15_000, timeoutMs - (now() - started)));
  } while (now() - started <= timeoutMs);
  throw new Error('Timed out waiting for the matching rules test and backend deployment. Client upload blocked.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const {GITHUB_TOKEN: token, GITHUB_REPOSITORY: repository, GITHUB_SHA: sha, GITHUB_REF: ref} = process.env;
  if (!token || !repository) throw new Error('Missing GitHub release gate credentials.');
  const run = await requireBackend({repository, sha, ref,
    timeoutMs: process.argv.includes('--check-only') ? 0 : undefined,
    sleep: ms => new Promise(resolve => setTimeout(resolve, ms)),
    request: async path => {
      const response = await fetch(`https://api.github.com${path}`, {
        headers: {Authorization: `Bearer ${token}`, Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28'},
        signal: AbortSignal.timeout(30_000),
      });
      if (!response.ok) throw new Error(`Release gate GitHub request failed (${response.status}).`);
      return response.json();
    },
  });
  const message = `Backend ready for ${sha}: ${run.html_url}`;
  console.log(message);
  if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${message}\n`);
}
