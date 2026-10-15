import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {validateNews, newsForDeployment, mergeNewsFeed, compareBuild} from './news.mjs';
import {pipelines} from './publish.mjs';

const note = JSON.parse(readFileSync(new URL('../../release-notes/current.json', import.meta.url), 'utf8'));
const deployed = builds => ({...note, builds});
const results = pipelines.map(pipeline => ({pipeline,
  run: {run_number: 82, run_attempt: 10}, jobs: [{steps: [{name: pipeline.step, conclusion: 'success'}]}],
  artifacts: [{name: pipeline.key === 'ios' ? 'cloudboard-ios-dsyms-542' : 'cloudboard-alpha-aab-52'}],
}));

test('current release news matches the actual app version', () => {
  const pubspec = readFileSync(new URL('../../pubspec.yaml', import.meta.url), 'utf8');
  const version = pubspec.match(/^version:\s*([^\s+#]+)/m)?.[1];
  assert.ok(version, 'App version is missing');
  assert.equal(note.version, version, 'Update current.json when changing the app version');
});

test('editorial source validates without allowing operational fields or malformed content', () => {
  assert.equal(validateNews(note), note);
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

test('platform arrivals and reruns preserve earliest compatible build and one immutable item', () => {
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
