import assert from 'node:assert/strict';
import {readFileSync, appendFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';

export const isDevelopmentTag = value => /^dev\/v(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)-[1-9]\d*$/.test(value || '');
export function compareDevelopmentTags(left, right) {
  assert(isDevelopmentTag(left) && isDevelopmentTag(right), 'Development tag must use dev/vX.Y.Z-N');
  const parts = value => value.slice('dev/v'.length).split(/[.-]/).map(BigInt);
  const a = parts(left), b = parts(right);
  for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return a[i] > b[i] ? 1 : -1;
  return 0;
}
export function developmentChanges(changedFiles) {
  const shared = changedFiles.some(p => ['firebase.development.json', 'tool/firebase/environments.mjs'].includes(p));
  return {
    web: shared || changedFiles.some(p => /^(lib\/|assets\/|web\/|config\/brand\.json$|pubspec\.(yaml|lock)$|\.fvmrc$)/.test(p)),
    backend: shared || changedFiles.some(p => /^(functions\/(src|certificates)\/|functions\/package(?:-lock)?\.json$)/.test(p)),
    rules: shared || changedFiles.some(p => /^(firestore\.rules|firestore\.indexes\.json|database\.rules\.json|storage\.rules)$/.test(p)),
  };
}
export function developmentPlan({eventName, ref, sha, event = {}, changedFiles = []}) {
  assert(isDevelopmentTag(ref?.replace(/^refs\/tags\//, '')) && ref.startsWith('refs/tags/'), 'Development deployment requires a dev/vX.Y.Z-N tag');
  assert.match(sha || '', /^[a-f0-9]{40}$/);
  assert(['push', 'workflow_dispatch'].includes(eventName), 'Unsupported development deployment event');
  if (eventName === 'workflow_dispatch') {
    const scope = event.inputs?.scope;
    assert(['full', 'web', 'backend', 'rules'].includes(scope), 'Choose a development deployment scope');
    return {web: ['full', 'web'].includes(scope), backend: ['full', 'backend'].includes(scope),
      rules: ['full', 'rules'].includes(scope)};
  }
  return developmentChanges(changedFiles);
}

const deploySteps = {web: 'Deploy stamped development web', backend: 'Deploy development compatibility backend',
  rules: 'Deploy development rules'};
async function* developmentRuns({repository, request, tag}) {
  assert.match(repository || '', /^[\w.-]+\/[\w.-]+$/);
  const filter = tag ? `branch=${encodeURIComponent(tag)}&` : '';
  for (let page = 1; ; page++) {
    const result = await request(`/repos/${repository}/actions/workflows/firebase-development.yml/runs?${filter}per_page=100&page=${page}`);
    const runs = result.workflow_runs || [];
    // Keep run creation order: retrying an old run must not promote its old
    // source ahead of a newer release. Retry uncertainty is tracked separately.
    for (const run of runs.filter(run => (isDevelopmentTag(run.head_branch) || ['main', 'develop'].includes(run.head_branch)) &&
      ['push', 'workflow_dispatch'].includes(run.event) && run.head_repository?.full_name === repository)) yield run;
    if (runs.length < 100) return;
  }
}
async function deploymentBaselines({repository, request, ignoreRunId}) {
  const baseline = {}, uncertain = new Set(), guardRuns = new Map();
  for await (const run of developmentRuns({repository, request})) {
    if (String(run.id) === String(ignoreRunId)) continue;
    assert.match(run.head_sha || '', /^[a-f0-9]{40}$/);
    assert(Number.isSafeInteger(run.run_attempt) && run.run_attempt > 0);
    const response = await request(`/repos/${repository}/actions/runs/${run.id}/attempts/${run.run_attempt}/jobs?per_page=100`);
    const jobs = response.jobs || [];
    assert((response.total_count ?? jobs.length) <= 100, 'Development job history is truncated');
    for (const [component, name] of Object.entries(deploySteps)) {
      if (Object.hasOwn(baseline, component)) continue;
      const step = jobs.flatMap(job => job.steps || []).find(step => step.name === name);
      if (step?.conclusion === 'success' || step?.status === 'in_progress' || ['failure', 'cancelled', 'timed_out'].includes(step?.conclusion)) {
        baseline[component] = step.conclusion === 'success' && !uncertain.has(component) ? run.head_sha : null;
        guardRuns.set(run.id, run);
      } else if (run.run_attempt > 1) {
        // A retry can hide an earlier attempt that already changed a component.
        // Reconcile it, but keep looking: this unknown old attempt must not hide
        // a newer tag's actual write evidence from the rollback check.
        uncertain.add(component);
        guardRuns.set(run.id, run);
      }
    }
    if (Object.keys(baseline).length === 3) break;
  }
  return {baseline, guardRuns: [...guardRuns.values()]};
}
export async function pendingDevelopmentPlan({repository, sha, request, diff, ignoreRunId, baseline}) {
  baseline ??= (await deploymentBaselines({repository, request, ignoreRunId})).baseline;
  return Object.fromEntries(Object.keys(deploySteps).map(component => [component, !baseline[component] ||
    developmentChanges(diff(baseline[component], sha))[component]]));
}
export async function requireDevelopmentTag({sha, ref, tag = ref?.replace(/^refs\/tags\//, ''), version, repository, request}) {
  assert.match(sha || '', /^[a-f0-9]{40}$/);
  assert(isDevelopmentTag(tag), 'Development tag must use dev/vX.Y.Z-N');
  assert.equal(ref, `refs/tags/${tag}`, 'Development retry must run on its tag ref');
  assert.equal(tag.match(/^dev\/v(.+)-\d+$/)[1], version, 'Development tag must match pubspec version');
  let object = (await request(`/repos/${repository}/git/ref/tags/${tag}`)).object;
  for (let depth = 0; object?.type === 'tag' && depth < 5; depth++) {
    object = (await request(`/repos/${repository}/git/tags/${object.sha}`)).object;
  }
  assert.equal(object?.type, 'commit', 'Development tag must resolve to a commit');
  assert.equal(object.sha, sha, 'Development tag moved after the workflow was triggered');
  const main = await request(`/repos/${repository}/compare/${sha}...main`);
  assert(['ahead', 'identical'].includes(main.status) && main.merge_base_commit?.sha === sha, 'Development source must be included in main');
  for await (const run of developmentRuns({repository, request, tag})) {
    if (run.head_branch === tag) assert.equal(run.head_sha, sha, 'Development tag was reused for another commit; create a new tag');
  }
}
export async function requireCurrentDevelopment({sha, ref, version, repository, request, ignoreRunId}) {
  const tag = ref?.replace(/^refs\/tags\//, '');
  await requireDevelopmentTag({sha, ref, version, repository, request});
  const {baseline, guardRuns} = await deploymentBaselines({repository, request, ignoreRunId});
  for (const run of guardRuns) {
    if (isDevelopmentTag(run.head_branch)) {
      assert(compareDevelopmentTags(tag, run.head_branch) >= 0, 'A newer development tag already attempted deployment; refusing an older tag');
    }
    if (run.head_sha === sha) continue;
    const comparison = await request(`/repos/${repository}/compare/${run.head_sha}...${sha}`);
    assert(['ahead', 'identical'].includes(comparison.status) && comparison.merge_base_commit?.sha === run.head_sha,
      'A newer development deployment exists; refusing an older source');
  }
  return baseline;
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
  const sha = env.DEVELOPMENT_SOURCE_SHA || env.GITHUB_SHA;
  const ref = env.GITHUB_REF;
  const pubspec = execFileSync('git', ['show', `${sha}:pubspec.yaml`], {encoding: 'utf8'});
  const version = pubspec.match(/^version:\s*([^+\s]+)/m)?.[1];
  if (process.argv[2] === 'current') {
    await requireCurrentDevelopment({sha, ref, version, repository: env.GITHUB_REPOSITORY, request, ignoreRunId: env.GITHUB_RUN_ID});
  } else {
    const event = JSON.parse(readFileSync(env.GITHUB_EVENT_PATH, 'utf8'));
    let plan = developmentPlan({eventName: env.GITHUB_EVENT_NAME, ref, sha, event});
    const baseline = await requireCurrentDevelopment({sha, ref, version, repository: env.GITHUB_REPOSITORY, request, ignoreRunId: env.GITHUB_RUN_ID});
    if (env.GITHUB_EVENT_NAME === 'push') {
      plan = await pendingDevelopmentPlan({repository: env.GITHUB_REPOSITORY, sha, request, baseline,
        ignoreRunId: env.GITHUB_RUN_ID,
        diff: (base, sha) => execFileSync('git', ['diff', '--no-renames', '--name-only', base, sha, '--'], {encoding: 'utf8'}).trim().split('\n')});
    }
    assert(env.GITHUB_OUTPUT);
    appendFileSync(env.GITHUB_OUTPUT, Object.entries({...plan, source_sha: sha, development_tag: ref.slice('refs/tags/'.length)}).map(([key, value]) => `${key}=${value}\n`).join(''));
    console.log(`Development only: ${ref} at ${sha}; ${JSON.stringify(plan)}`);
  }
}
