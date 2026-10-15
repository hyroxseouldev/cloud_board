import assert from 'node:assert/strict';
import {readFileSync, appendFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';

export function developmentPlan({eventName, ref, sha, event = {}, changedFiles = []}) {
  assert.equal(ref, 'refs/heads/main', 'Development deployment starts from reviewed main');
  assert.match(sha || '', /^[a-f0-9]{40}$/);
  assert(['push', 'workflow_dispatch'].includes(eventName), 'Unsupported development deployment event');
  if (eventName === 'workflow_dispatch') {
    const scope = event.inputs?.scope;
    assert(['full', 'web', 'backend', 'rules'].includes(scope), 'Choose a development deployment scope');
    return {web: ['full', 'web'].includes(scope), backend: ['full', 'backend'].includes(scope),
      rules: ['full', 'rules'].includes(scope)};
  }
  const shared = changedFiles.some(p => ['firebase.development.json', 'tool/firebase/environments.mjs'].includes(p));
  return {
    web: shared || changedFiles.some(p => /^(lib\/|assets\/|web\/|config\/brand\.json$|pubspec\.(yaml|lock)$|\.fvmrc$)/.test(p)),
    backend: shared || changedFiles.some(p => /^(functions\/(src|certificates)\/|functions\/package(?:-lock)?\.json$|functions-legacy\/src\/|functions-legacy\/(package(?:-lock)?|tsconfig)\.json$|tool\/firebase\/prepare-development-display\.mjs$)/.test(p)),
    rules: shared || changedFiles.some(p => /^(firestore\.rules|firestore\.indexes\.json|database\.rules\.json|storage\.rules)$/.test(p)),
  };
}

export async function requireDevelopmentMain({sha, repository, request}) {
  assert.match(sha || '', /^[a-f0-9]{40}$/);
  assert.match(repository || '', /^[\w.-]+\/[\w.-]+$/);
  const current = await request(`/repos/${repository}/git/ref/heads/main`);
  if (current.object?.sha === sha) return;
  const difference = await request(`/repos/${repository}/compare/${sha}...${current.object?.sha}`);
  const message = 'Newer main contains development changes; retry from latest main';
  assert(difference.status === 'ahead' && difference.merge_base_commit?.sha === sha &&
    Array.isArray(difference.files) && difference.files.length < 300, message);
  // A docs-only main merge must not strand an already building development app.
  const changes = developmentPlan({eventName: 'push', ref: 'refs/heads/main', sha,
    changedFiles: difference.files.flatMap(file => [file.filename, ...(file.previous_filename ? [file.previous_filename] : [])])});
  assert(!Object.values(changes).some(Boolean), message);
}

const deploySteps = {web: 'Deploy stamped development web', backend: 'Deploy development compatibility backend',
  rules: 'Deploy development rules'};
export async function pendingDevelopmentPlan({repository, sha, request, diff, ignoreRunId}) {
  const baseline = {};
  for (let page = 1; page <= 10 && Object.keys(baseline).length < 3; page++) {
    const result = await request(`/repos/${repository}/actions/workflows/firebase-development.yml/runs?per_page=100&page=${page}`);
    const runs = [...(result.workflow_runs || [])].sort((a, b) =>
      Date.parse(b.run_started_at || b.created_at) - Date.parse(a.run_started_at || a.created_at) || b.id - a.id);
    for (const run of runs) {
      if (String(run.id) === String(ignoreRunId) || !['main', 'develop'].includes(run.head_branch) ||
        !['push', 'workflow_dispatch'].includes(run.event) || run.head_repository?.full_name !== repository) continue;
      assert.match(run.head_sha || '', /^[a-f0-9]{40}$/);
      assert(Number.isSafeInteger(run.run_attempt) && run.run_attempt > 0);
      const {jobs} = await request(`/repos/${repository}/actions/runs/${run.id}/attempts/${run.run_attempt}/jobs?per_page=100`);
      for (const [component, name] of Object.entries(deploySteps)) {
        if (Object.hasOwn(baseline, component)) continue;
        const step = jobs?.flatMap(job => job.steps || []).find(step => step.name === name);
        if (step?.conclusion === 'success') baseline[component] = run.head_sha;
        else if (step?.status === 'in_progress' || ['failure', 'cancelled', 'timed_out'].includes(step?.conclusion)) baseline[component] = null;
        // A retry can hide an earlier attempt that already changed a component.
        // Unknown state must be reconciled, including when main reverted it.
        else if (run.run_attempt > 1) baseline[component] = null;
      }
      if (Object.keys(baseline).length === 3) break;
    }
    if (runs.length < 100) break;
  }
  return Object.fromEntries(Object.keys(deploySteps).map(component => [component, !baseline[component] ||
    developmentPlan({eventName: 'push', ref: 'refs/heads/main', sha,
      changedFiles: diff(baseline[component], sha)})[component]]));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const env = process.env;
  const request = async path => {
    assert(env.GITHUB_TOKEN, 'Read-only GitHub token required');
    const response = await fetch(`https://api.github.com${path}`, {headers: {
      Authorization: `Bearer ${env.GITHUB_TOKEN}`, Accept: 'application/vnd.github+json',
    }, signal: AbortSignal.timeout(30_000)});
    assert(response.ok, `Development source check failed (${response.status})`);
    return response.json();
  };
  if (process.argv[2] === 'current') {
    assert.equal(env.GITHUB_REF, 'refs/heads/main');
    await requireDevelopmentMain({sha: env.GITHUB_SHA, repository: env.GITHUB_REPOSITORY, request});
  } else {
    const event = JSON.parse(readFileSync(env.GITHUB_EVENT_PATH, 'utf8'));
    let changedFiles = [];
    if (env.GITHUB_EVENT_NAME === 'push') {
      assert.match(event.before || '', /^(?!0{40}$)[a-f0-9]{40}$/, 'Missing development change baseline');
      changedFiles = execFileSync('git', ['diff', '--no-renames', '--name-only', event.before, env.GITHUB_SHA, '--'], {encoding: 'utf8'}).trim().split('\n');
    }
    let plan = developmentPlan({eventName: env.GITHUB_EVENT_NAME, ref: env.GITHUB_REF, sha: env.GITHUB_SHA, event, changedFiles});
    if (env.GITHUB_EVENT_NAME === 'push' && Object.values(plan).some(Boolean)) {
      plan = await pendingDevelopmentPlan({repository: env.GITHUB_REPOSITORY, sha: env.GITHUB_SHA, request,
        ignoreRunId: env.GITHUB_RUN_ID,
        diff: (base, sha) => execFileSync('git', ['diff', '--no-renames', '--name-only', base, sha, '--'], {encoding: 'utf8'}).trim().split('\n')});
    }
    assert(env.GITHUB_OUTPUT);
    appendFileSync(env.GITHUB_OUTPUT, Object.entries(plan).map(([key, value]) => `${key}=${value}\n`).join(''));
    console.log(`Development only: ${JSON.stringify(plan)}`);
  }
}
