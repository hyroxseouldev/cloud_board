import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { readFileSync, appendFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

export const pipelines = [
  { key: 'web', label: '웹', path: '.github/workflows/firebase-hosting-merge.yml',
    step: 'Deploy to Firebase Hosting', success: '웹 반영 완료' },
  { key: 'android', label: 'Android / TV', path: '.github/workflows/google-play-main.yml',
    step: 'Upload mobile and TV bundle to closed Alpha testing', success: '비공개 Alpha 트랙 제출 완료',
    artifact: /^cloudboard-alpha-aab-(\d+)$/ },
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
  const step = jobs.flatMap(j => j.steps ?? []).find(s => s.name === pipeline.step);
  // The upload may succeed even if a later cleanup/artifact step fails.
  if (step?.conclusion === 'success') {
    const warning = run.status === 'completed' && run.conclusion !== 'success'
      ? ' (후속 작업 실패·취소: 실행 로그 확인)' : '';
    return pipeline.success + warning;
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

// Deterministic UUID means a timeout/rerun cannot create a second post for this SHA.
export function updateId(projectId, repository, sha) {
  const hex = createHash('sha1').update(`cloudboard-deploy-v1:${projectId}:${repository}:${sha}`).digest().subarray(0, 16);
  hex[6] = (hex[6] & 0x0f) | 0x50;
  hex[8] = (hex[8] & 0x3f) | 0x80;
  const value = hex.toString('hex');
  return `${value.slice(0, 8)}-${value.slice(8, 12)}-${value.slice(12, 16)}-${value.slice(16, 20)}-${value.slice(20)}`;
}

function escapeMarkdown(text) {
  return text.replace(/[\r\n]+/g, ' ').replace(/([\\`*_[\]<>|])/g, '\\$1');
}

export function renderUpdate({ repository, sha, base, date, commits, results, version }) {
  const root = `https://github.com/${repository}`;
  const issues = [...new Set(commits.flatMap(c => c.message.match(/\bSTA-\d+\b/g) ?? []))];
  const lines = [
    `## ${date} 업데이트`, '',
    `main 반영: [${sha.slice(0, 7)}](${root}/commit/${sha})${version ? ` · 앱 버전 ${escapeMarkdown(version)}` : ''}`,
    '', '### 변경사항', '',
    ...commits.slice(0, 40).map(c => `- ${escapeMarkdown(c.subject)} ([${c.sha.slice(0, 7)}](${root}/commit/${c.sha}))`),
  ];
  if (!commits.length) lines.push('- 변경사항은 아래 커밋 링크에서 확인해 주세요.');
  if (commits.length > 40) lines.push(`- 나머지 ${commits.length - 40}개 커밋은 전체 변경 내역에서 확인해 주세요.`);
  if (base) lines.push('', `[전체 변경 내역](${root}/compare/${base}...${sha})`);
  if (issues.length) lines.push('', `관련 이슈: ${issues.map(id => `[${id}](https://linear.app/clyrdev/issue/${id})`).join(', ')}`);
  lines.push('', '### 배포 결과', '');
  for (const { pipeline, run, jobs, artifacts } of results) {
    const builds = pipeline.artifact
      ? [...new Set((artifacts ?? []).map(a => a.name.match(pipeline.artifact)?.[1]).filter(Boolean))] : [];
    const build = builds.length === 1 ? ` · 빌드 ${builds[0]}` : '';
    lines.push(`- **${pipeline.label}**: ${deploymentStatus(pipeline, run, jobs)}${build}${run ? ` · [실행 #${run.run_number} (${run.run_attempt}차)](${root}/actions/runs/${run.id})` : ''}`);
  }
  lines.push('', '스토어 제출·업로드 완료는 심사/처리 완료나 설치 가능 상태를 의미하지 않습니다.',
    '실기기 검수 결과와 `테스트 필요` 라벨은 그대로 유지합니다.', '',
    '자동 배포 기록입니다. 플랫폼별 결과가 도착하면 이 글을 갱신합니다.');
  return lines.join('\n');
}

export async function requestJson(url, options = {}, fetchImpl = fetch) {
  const response = await fetchImpl(url, { ...options, signal: AbortSignal.timeout(30_000) });
  const result = await response.json().catch(() => ({}));
  if (result.errors?.length) {
    const details = result.errors.map(error => {
      const code = error.extensions?.code ?? 'UNKNOWN';
      // Only schema and access diagnostics are exposed; never print API bodies or credentials.
      const message = String(error.message).replaceAll(options.headers?.Authorization ?? '\0', '[redacted]').replace(/lin_api_[A-Za-z0-9]+/g, '[redacted]').slice(0, 400);
      return ['GRAPHQL_VALIDATION_FAILED', 'FORBIDDEN'].includes(code)
        ? `${code}: ${message}` : code;
    }).join('; ');
    throw new Error(`Linear GraphQL request failed (HTTP ${response.status ?? 200}): ${details}`);
  }
  if (!response.ok) throw new Error(`API request failed (${new URL(url).hostname}, HTTP ${response.status}).`);
  return result;
}

export function linearClient(key, fetchImpl = fetch) {
  return async (query, variables) => (await requestJson('https://api.linear.app/graphql', {
    method: 'POST', headers: { Authorization: key, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query, variables }),
  }, fetchImpl)).data;
}

export async function upsertUpdate(linear, { id, projectId, body }) {
  const lookup = async () => {
    const data = await linear(`query DeploymentUpdate($id: ID!) {
      projectUpdates(first: 1, includeArchived: true, filter: {id: {eq: $id}}) {
        nodes { id body url archivedAt project { id } }
      }
    }`, { id });
    return data.projectUpdates.nodes[0];
  };
  const existing = await lookup();
  const update = async (post) => {
    if (post.project.id !== projectId || post.archivedAt) throw new Error('Deployment update has been moved or archived; refusing to overwrite it.');
    if (post.body === body) return { url: post.url, operation: 'unchanged' };
    const data = await linear(`mutation RefreshDeployment($id: String!, $input: ProjectUpdateUpdateInput!) {
      projectUpdateUpdate(id: $id, input: $input) { success projectUpdate { id url } }
    }`, { id, input: { body } });
    if (!data.projectUpdateUpdate.success) throw new Error('Linear did not confirm updating the project update.');
    return { url: data.projectUpdateUpdate.projectUpdate.url, operation: 'updated' };
  };
  if (existing) return update(existing);
  try {
    const data = await linear(`mutation PublishDeployment($input: ProjectUpdateCreateInput!) {
      projectUpdateCreate(input: $input) { success projectUpdate { id url } }
    }`, { input: { id, projectId, body } });
    if (!data.projectUpdateCreate.success) throw new Error('Linear did not confirm creating the project update.');
    return { url: data.projectUpdateCreate.projectUpdate.url, operation: 'created' };
  } catch (error) {
    // A successful write with a lost response, or an overlapping rerun, reuses its ID.
    const recovered = await lookup();
    if (recovered) return update(recovered);
    throw error;
  }
}

function git(...args) {
  return execFileSync('git', args, { encoding: 'utf8', maxBuffer: 10 * 1024 * 1024 }).trim();
}

export function changeRange(sha, previousShas) {
  const parents = git('rev-list', '--first-parent', sha).split('\n').slice(1);
  const base = parents.find(parent => previousShas.has(parent)) ?? parents[0] ?? null;
  const range = base ? `${base}..${sha}` : sha;
  const log = git('log', '--reverse', '--no-merges', '--format=%H%x00%B%x00%x1e', range);
  const commits = log.split('\x1e').map(record => record.trim()).filter(Boolean).map(record => {
    const [commitSha, message] = record.split('\0');
    return { sha: commitSha, message, subject: message.split('\n')[0] };
  });
  // A merge message can carry the issue reference even when its commits do not.
  const headMessage = git('show', '-s', '--format=%B', sha);
  const refs = headMessage.match(/\bSTA-\d+\b/g) ?? [];
  if (commits.length) commits[0].message += `\n${refs.join(' ')}`;
  else commits.push({ sha, message: headMessage, subject: headMessage.split('\n')[0] });
  return { base, commits };
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

export async function publish(env = process.env, fetchImpl = fetch) {
  const dryRun = env.LINEAR_DRY_RUN === 'true';
  for (const key of ['GITHUB_EVENT_PATH', 'GITHUB_REPOSITORY', 'GITHUB_TOKEN', 'LINEAR_PROJECT_ID', ...(dryRun ? [] : ['LINEAR_API_KEY'])]) {
    if (!env[key]) throw new Error(`Missing ${key}. Add LINEAR_API_KEY under repository Settings → Secrets and variables → Actions.`);
  }
  const repository = env.GITHUB_REPOSITORY;
  if (!/^[\w.-]+\/[\w.-]+$/.test(repository)) throw new Error('Invalid repository.');
  const event = JSON.parse(readFileSync(env.GITHUB_EVENT_PATH, 'utf8'));
  const runId = sourceRunId(event, env.GITHUB_EVENT_NAME, env.GITHUB_REF, repository);
  const gh = (path) => requestJson(`https://api.github.com/repos/${repository}${path}`, {
    headers: { Authorization: `Bearer ${env.GITHUB_TOKEN}`, Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28' },
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
  const allRuns = await list(`/actions/runs?head_sha=${sha}&branch=main`, 'workflow_runs');
  const runs = latestRuns([...allRuns.filter(r => r.id !== trigger.id), trigger], sha, repository);
  const results = [];
  for (let i = 0; i < pipelines.length; i++) {
    const run = runs[i];
    const [jobs, artifacts] = run ? await Promise.all([
      list(`/actions/runs/${run.id}/attempts/${run.run_attempt}/jobs`, 'jobs'),
      list(`/actions/runs/${run.id}/artifacts`, 'artifacts'),
    ]) : [[], []];
    results.push({ pipeline: pipelines[i], run, jobs, artifacts });
  }
  const recent = await gh('/actions/runs?branch=main&event=push&per_page=100');
  const previousShas = new Set(recent.workflow_runs.filter(r => trustedRun(r, repository) && r.head_sha !== sha).map(r => r.head_sha));
  const { base, commits } = changeRange(sha, previousShas);
  const pubspec = git('show', `${sha}:pubspec.yaml`);
  const version = pubspec.match(/^version:\s*([^\s+#]+)/m)?.[1];
  const date = new Intl.DateTimeFormat('sv-SE', { timeZone: 'Asia/Seoul', year: 'numeric', month: '2-digit', day: '2-digit' })
    .format(new Date(git('show', '-s', '--format=%cI', sha)));
  const body = renderUpdate({ repository, sha, base, date, commits, results, version });
  if (env.GITHUB_STEP_SUMMARY) appendFileSync(env.GITHUB_STEP_SUMMARY, `${body}\n`);
  if (dryRun) { console.log(body); return { body }; }
  const result = await upsertUpdate(linearClient(env.LINEAR_API_KEY, fetchImpl), {
    id: updateId(env.LINEAR_PROJECT_ID, repository, sha), projectId: env.LINEAR_PROJECT_ID, body,
  });
  console.log(`Linear project update ${result.operation}: ${result.url}`);
  if (env.GITHUB_STEP_SUMMARY) appendFileSync(env.GITHUB_STEP_SUMMARY, `\n[Linear 업데이트 보기](${result.url})\n`);
  return result;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  publish().catch(error => { console.error(error.message); process.exitCode = 1; });
}
