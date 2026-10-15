import {execFileSync} from 'node:child_process';
import {readFileSync, appendFileSync, writeFileSync, rmSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {validateNews, newsForDeployment} from './news.mjs';

export const pipelines = [
  { key: 'web', label: '웹', path: '.github/workflows/firebase-hosting-merge.yml',
    step: 'Deploy to Firebase Hosting', success: '웹 반영 완료' },
  { key: 'android', label: 'Android / TV', path: '.github/workflows/google-play-main.yml',
    step: 'Upload mobile and TV bundle to internal testing', success: '내부 테스트 트랙 업로드 완료',
    previousSteps: {'Upload mobile and TV bundle to closed Alpha testing': '비공개 Alpha 트랙 제출 완료'},
    artifact: /^cloudboard-(?:internal|alpha)-aab-(\d+)$/ },
  { key: 'ios', label: 'iOS', path: '.github/workflows/testflight-main.yml',
    step: 'Upload to TestFlight', success: 'TestFlight 업로드 완료',
    artifact: /^cloudboard-ios-dsyms-(\d+)$/ },
];

export function trustedRun(run, repository) {
  return run?.head_branch === 'main' && run?.head_repository?.full_name === repository &&
    ['push', 'workflow_dispatch'].includes(run.event) && pipelines.some(p => p.path === run.path);
}

export function latestRuns(runs, sha, repository) {
  return pipelines.map(p => runs.filter(r => r.head_sha === sha && r.path === p.path && trustedRun(r, repository))
    .sort((a, b) => Number(b.id) - Number(a.id) || Number(b.run_attempt) - Number(a.run_attempt))[0] ?? null);
}

export function deploymentStatus(pipeline, run, jobs = []) {
  if (!run) return '실행 대기 / 실행 기록 없음';
  const step = jobs.flatMap(j => j.steps ?? []).find(s =>
    s.name === pipeline.step || Object.hasOwn(pipeline.previousSteps ?? {}, s.name));
  // The upload may succeed even if a later cleanup/artifact step fails.
  if (step?.conclusion === 'success') {
    const warning = run.status === 'completed' && run.conclusion !== 'success'
      ? ' (후속 작업 실패·취소: 실행 로그 확인)' : '';
    return (pipeline.previousSteps?.[step.name] ?? pipeline.success) + warning;
  }
  if (run.status !== 'completed') return ['queued', 'waiting', 'pending', 'requested'].includes(run.status)
    ? '대기 중' : '진행 중';
  if (run.conclusion === 'cancelled') return '취소됨 · 배포 완료 미확인';
  if (['failure', 'timed_out', 'action_required', 'startup_failure', 'stale'].includes(run.conclusion)) {
    return '실패 · 배포 완료 미확인';
  }
  if (step?.conclusion === 'skipped' || jobs.every(j => j.conclusion === 'skipped')) {
    return '건너뜀 · 배포되지 않음';
  }
  return '배포 단계 성공 기록 없음 · 확인 필요';
}

export async function requestJson(url, options = {}, fetchImpl = fetch) {
  const response = await fetchImpl(url, {...options, signal: AbortSignal.timeout(30_000)});
  // Never include API response bodies or credentials in diagnostics.
  if (!response.ok) throw new Error(`GitHub API request failed (${new URL(url).hostname}, HTTP ${response.status}).`);
  return response.json();
}

function git(...args) {
  return execFileSync('git', args, { encoding: 'utf8', maxBuffer: 10 * 1024 * 1024 }).trim();
}

// A reviewed correction can repair missing/stale editorial for one already
// deployed SHA without rebuilding that app. Read only committed publisher code;
// each exact-SHA correction is append-only, including across delete/re-adds.
export function readCorrection(sha) {
  if (!/^[a-f0-9]{40}$/.test(sha)) throw new Error('Invalid correction commit SHA.');
  const path = `release-notes/corrections/${sha}.json`;
  if (git('ls-tree', '--name-only', 'HEAD', path) !== path) return null;
  const additions = git('log', '--format=%H', '--diff-filter=A', '--', path).split('\n').filter(Boolean);
  const content = git('show', `HEAD:${path}`);
  if (additions.length !== 1 || git('rev-parse', `HEAD:${path}`) !== git('rev-parse', `${additions[0]}:${path}`)) {
    throw new Error('A deployed-SHA news correction is immutable after its first commit.');
  }
  return {news: validateNews(JSON.parse(content)), path};
}

export function sourceRunId(event, eventName, ref, repository) {
  if (eventName === 'workflow_dispatch') {
    if (ref !== 'refs/heads/main' || !/^\d+$/.test(event.inputs?.deployment_run_id ?? '')) {
      throw new Error('Manual publishing requires main and a numeric deployment run ID.');
    }
    return event.inputs.deployment_run_id;
  }
  if (!trustedRun(event.workflow_run, repository)) throw new Error('Only this repository’s main deployment runs can be published.');
  return event.workflow_run.id;
}

// Prepare only the app feed payload. This process never writes to Linear or Firebase.
export async function publish(env = process.env, fetchImpl = fetch) {
  const dryRun = env.UPDATE_NEWS_DRY_RUN === 'true';
  for (const key of ['GITHUB_EVENT_PATH', 'GITHUB_REPOSITORY', 'GITHUB_TOKEN', ...(!dryRun ? ['UPDATE_NEWS_OUTPUT_PATH'] : [])]) {
    if (!env[key]) throw new Error(`Missing ${key}.`);
  }
  // Do not let an earlier payload survive a skipped or failed preparation.
  if (!dryRun) rmSync(env.UPDATE_NEWS_OUTPUT_PATH, {force: true});
  const repository = env.GITHUB_REPOSITORY;
  if (!/^[\w.-]+\/[\w.-]+$/.test(repository)) throw new Error('Invalid repository.');
  const event = JSON.parse(readFileSync(env.GITHUB_EVENT_PATH, 'utf8'));
  const runId = sourceRunId(event, env.GITHUB_EVENT_NAME, env.GITHUB_REF, repository);
  const gh = path => requestJson(`https://api.github.com/repos/${repository}${path}`, {
    headers: {Authorization: `Bearer ${env.GITHUB_TOKEN}`, Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28'},
  }, fetchImpl);
  const list = async (path, field) => {
    const values = [];
    for (let page = 1; page <= 10; page++) {
      const data = await gh(`${path}${path.includes('?') ? '&' : '?'}per_page=100&page=${page}`);
      values.push(...data[field]);
      if (data[field].length < 100) return values;
    }
    throw new Error('GitHub pagination limit reached; refusing an incomplete deployment report.');
  };
  const trigger = await gh(`/actions/runs/${runId}`);
  if (!trustedRun(trigger, repository)) throw new Error('Deployment source is no longer a trusted main run.');
  const sha = trigger.head_sha;
  if (!/^[a-f0-9]{40}$/.test(sha)) throw new Error('Invalid commit SHA.');
  const newsPath = 'release-notes/current.json';
  const summary = [`## App update news`, '', `Deployment: ${sha}`];
  const finish = result => {
    const body = summary.join('\n') + '\n';
    if (env.GITHUB_STEP_SUMMARY) appendFileSync(env.GITHUB_STEP_SUMMARY, body);
    console.log(body);
    return result;
  };
  // Read the deployed commit, not newer editorial changes in the publisher checkout.
  let news = git('ls-tree', '--name-only', sha, newsPath) === newsPath
    ? validateNews(JSON.parse(git('show', `${sha}:${newsPath}`))) : null;
  const version = git('show', `${sha}:pubspec.yaml`).match(/^version:\s*([^\s+#]+)/m)?.[1];
  if (!news || news.version !== version) {
    const correction = readCorrection(sha);
    if (correction) {
      news = correction.news;
      summary.push(`Editorial correction: ${correction.path}`);
    }
  }
  if (!news) {
    summary.push('', 'Skipped: the deployed commit has no update news.');
    return finish({operation: 'skipped', reason: 'no-news'});
  }
  if (news.version !== version) throw new Error('Update news version must match the deployed app version');
  const allRuns = await list(`/actions/runs?head_sha=${sha}&branch=main`, 'workflow_runs');
  const runs = latestRuns([...allRuns.filter(run => run.id !== trigger.id), trigger], sha, repository);
  const results = [];
  for (let i = 0; i < pipelines.length; i++) {
    const run = runs[i];
    const [jobs, artifacts] = run ? await Promise.all([
      list(`/actions/runs/${run.id}/attempts/${run.run_attempt}/jobs`, 'jobs'),
      list(`/actions/runs/${run.id}/artifacts`, 'artifacts'),
    ]) : [[], []];
    results.push({pipeline: pipelines[i], run, jobs, artifacts});
  }
  const payload = newsForDeployment(news, results);
  summary.push(`News: ${news.id} · version ${version}`, '');
  for (const {pipeline, run, jobs} of results) {
    const build = payload.builds[pipeline.key];
    summary.push(`- ${pipeline.label}: ${deploymentStatus(pipeline, run, jobs)}${build ? ` · build ${build}` : ''}`);
  }
  if (!Object.keys(payload.builds).length) {
    summary.push('', 'Skipped: no successful deployments with confirmed builds.');
    return finish({operation: 'skipped', reason: 'no-deployed-builds'});
  }
  if (dryRun) {
    summary.push('', 'Dry run: no app feed payload written.');
    return finish({operation: 'dry-run', news: payload});
  }
  writeFileSync(env.UPDATE_NEWS_OUTPUT_PATH, JSON.stringify(payload));
  summary.push('', 'App feed payload prepared. The next step publishes it to Firebase.');
  return finish({operation: 'prepared', news: payload});
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  publish().catch(error => {console.error(error.message); process.exitCode = 1;});
}

