import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync, writeFileSync, mkdtempSync, rmSync, mkdirSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {execFileSync} from 'node:child_process';
import {validateNews, newsForDeployment, mergeNewsFeed, compareBuild} from './news.mjs';
import {pipelines, renderUpdate, publish} from '../linear-deploy/publish.mjs';

const note = JSON.parse(readFileSync(new URL('../../release-notes/current.json', import.meta.url), 'utf8'));
const deployed = builds => ({...note, builds});
const results = pipelines.map(pipeline => ({pipeline,
  run: {run_number: 82, run_attempt: 10}, jobs: [{steps: [{name: pipeline.step, conclusion: 'success'}]}],
  artifacts: [{name: pipeline.key === 'ios' ? 'cloudboard-ios-dsyms-542' : 'cloudboard-alpha-aab-52'}],
}));

test('editorial source validates and is the same summary shown in Linear', () => {
  assert.equal(validateNews(note), note);
  const markdown = renderUpdate({repository: 'test/repo', sha: 'a'.repeat(40), date: note.date,
    commits: [], results: [], news: note, version: note.version});
  assert.ok(markdown.includes(note.title));
  for (const item of note.items) assert.ok(markdown.includes(item.body));
  assert.throws(() => validateNews({...note, debugLog: 'not-public'}), /Unknown/);
  assert.throws(() => validateNews({...note, date: '2026-02-31'}), /date/);
  assert.throws(() => validateNews({...note, items: []}), /items/);
});

test('only successful deployment steps with confirmed platform builds enter feed', () => {
  assert.deepEqual(newsForDeployment(note, results).builds, {web: '82.10', android: '52', ios: '542'});
  const missing = structuredClone(results);
  missing[0].jobs[0].steps[0].conclusion = 'skipped';
  missing[1].artifacts[0].expired = true;
  missing[2].artifacts.push({name: 'cloudboard-ios-dsyms-543'});
  assert.deepEqual(newsForDeployment(note, missing).builds, {});
  assert.deepEqual(mergeNewsFeed(undefined, deployed({})), {schemaVersion: 1, entries: []});
});

test('platform arrivals and reruns preserve earliest compatible build and one item', () => {
  let feed = mergeNewsFeed(undefined, deployed({web: '82.10'}));
  feed = mergeNewsFeed(feed, deployed({web: '83.1', ios: '542'}));
  feed = mergeNewsFeed(feed, deployed({web: '82.2', android: '52'}));
  assert.equal(feed.entries.length, 1);
  assert.deepEqual(feed.entries[0].builds, {web: '82.2', ios: '542', android: '52'});
  assert.deepEqual(mergeNewsFeed(feed, deployed({ios: '543'})), feed);
  assert.throws(() => mergeNewsFeed(feed, {...deployed({web: '84.1'}), title: 'different'}), /immutable/);
});

test('Android news keeps confirmed builds from both internal and historical Alpha uploads', () => {
  const pipeline = pipelines.find(p => p.key === 'android');
  for (const [step, artifact, build] of [
    ['Upload mobile and TV bundle to internal testing', 'cloudboard-internal-aab-59', '59'],
    ['Upload mobile and TV bundle to closed Alpha testing', 'cloudboard-alpha-aab-58', '58'],
  ]) {
    const result = {pipeline, run: {}, jobs: [{steps: [{name: step, conclusion: 'success'}]}], artifacts: [{name: artifact}]};
    assert.deepEqual(newsForDeployment(note, [result]).builds, {android: build});
    result.jobs[0].steps[0].conclusion = 'skipped';
    assert.deepEqual(newsForDeployment(note, [result]).builds, {});
  }
});

test('history stays newest first and bounded without exposing extra fields', () => {
  let feed;
  for (let i = 0; i < 110; i++) {
    feed = mergeNewsFeed(feed, {...deployed({ios: String(500 + i)}), id: `news-${String(i).padStart(3, '0')}`});
  }
  assert.equal(feed.entries.length, 100);
  assert.equal(feed.entries[0].id, 'news-109');
  assert.equal(compareBuild('82.10', '82.2'), 1);
  assert.equal(compareBuild('82', '82.0'), 0);
  assert.throws(() => compareBuild('82.beta', '82.1'));
  assert.throws(() => validateNews(deployed({other: '10'}), {withBuilds: true}));
});

test('publisher uses deployed commit copy and exports only confirmed builds after Linear success', async () => {
  const previousCwd = process.cwd();
  const directory = mkdtempSync(join(tmpdir(), 'cloudboard-news-'));
  const git = (...args) => execFileSync('git', args, {encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']}).trim();
  try {
    process.chdir(directory);
    git('init', '-b', 'main'); git('config', 'user.email', 'test@example.invalid'); git('config', 'user.name', 'Test');
    writeFileSync('pubspec.yaml', `version: ${note.version}+2\n`);
    git('add', '.'); git('commit', '-m', 'initial');
    mkdirSync('release-notes');
    writeFileSync('release-notes/current.json', JSON.stringify(note));
    git('add', '.'); git('commit', '-m', 'news');
    const sha = git('rev-parse', 'HEAD');
    // The checkout can be ahead of the workflow's triggering deployment.
    writeFileSync('release-notes/current.json', JSON.stringify({...note, title: 'Not deployed yet'}));
    const run = {id: 123, run_number: 82, run_attempt: 2, head_sha: sha, head_branch: 'main',
      head_repository: {full_name: 'test/repo'}, event: 'push', path: pipelines[0].path, status: 'completed', conclusion: 'success'};
    writeFileSync('event.json', JSON.stringify({workflow_run: run}));
    let linearBody;
    const fakeFetch = async (url, options) => {
      let data;
      if (url.includes('api.linear.app')) {
        const {query, variables} = JSON.parse(options.body);
        if (query.includes('query DeploymentUpdate')) data = {data: {projectUpdates: {nodes: []}}};
        else {
          linearBody = variables.input.body;
          data = {data: {projectUpdateCreate: {success: true, projectUpdate: {
            id: variables.input.id, url: 'https://linear.app/test', project: {id: 'project'}, body: linearBody}}}};
        }
      } else {
        const path = new URL(url).pathname;
        if (path.endsWith('/jobs')) data = {jobs: results[0].jobs};
        else if (path.endsWith('/artifacts')) data = {artifacts: []};
        else if (path.endsWith('/runs/123')) data = run;
        else data = {workflow_runs: [run]};
      }
      return {ok: true, json: async () => data};
    };
    const output = join(directory, 'output.json');
    await publish({GITHUB_EVENT_PATH: join(directory, 'event.json'), GITHUB_REPOSITORY: 'test/repo',
      GITHUB_TOKEN: 'test-only', LINEAR_PROJECT_ID: 'project', LINEAR_API_KEY: 'test-only',
      GITHUB_EVENT_NAME: 'workflow_run', UPDATE_NEWS_OUTPUT_PATH: output}, fakeFetch);
    const published = JSON.parse(readFileSync(output, 'utf8'));
    assert.equal(published.title, note.title);
    assert.deepEqual(published.builds, {web: '82.2'});
    assert.ok(linearBody.includes(note.title));
    assert.ok(!linearBody.includes('Not deployed yet'));
  } finally {process.chdir(previousCwd); rmSync(directory, {recursive: true, force: true});}
});
