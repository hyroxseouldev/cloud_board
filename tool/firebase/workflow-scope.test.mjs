import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import {runInNewContext} from 'node:vm';

function jobCondition(file, job) {
  const text = readFileSync(`.github/workflows/${file}`, 'utf8');
  const block = text.match(new RegExp(`^  ${job}:\\n([\\s\\S]*?)(?=^  [a-z_]+:|$(?![\\s\\S]))`, 'm'))?.[1];
  assert(block, `Missing workflow job: ${job}`);
  return block.match(/^    if: >-\n((?:      .+\n)+)/m)?.[1].trim() ?? block.match(/^    if: (.+)$/m)?.[1];
}
const context = (event = 'push', message = 'Release', bootstrapped = 'true', upload = true) => {
  const scheduled = event === 'workflow_dispatch';
  return {
    github: {event_name: event, ref: 'refs/heads/main', event: {head_commit: {message}}},
    vars: {GOOGLE_PLAY_BOOTSTRAPPED: bootstrapped},
    inputs: {upload_to_play: upload, upload_to_testflight: upload},
    needs: {
      class_start_regressions: {result: 'success'},
      backend_ready: {result: scheduled && upload ? 'success' : 'skipped'},
      verify: {result: scheduled ? 'success' : 'skipped'},
    },
    always: () => true,
    cancelled: () => false,
    contains: (text, value) => text?.includes(value) ?? false,
  };
};
const evaluate = (condition, values) => {
  assert(condition, 'Missing deployment condition');
  return runInNewContext(`(${condition})`, values, {timeout: 100});
};

test('native releases run only on explicit dispatch and build-only skips backend deployment', () => {
  for (const [file, jobs] of [
    ['testflight-main.yml', ['upload']],
    ['google-play-main.yml', ['upload']],
  ]) {
    const workflow = readFileSync(`.github/workflows/${file}`, 'utf8');
    const triggers = workflow.match(/^on:\n([\s\S]*?)(?=^\S)/m)?.[1];
    assert(triggers, 'Missing workflow triggers');
    assert.deepEqual([...triggers.matchAll(/^  ([a-z_]+):/gm)].map(match => match[1]), ['workflow_dispatch']);
    for (const job of jobs) {
      const condition = jobCondition(file, job);
      for (const event of ['push', 'pull_request', 'schedule', 'workflow_run']) {
        const values = context(event);
        // Even stale successful prerequisites must not enable an automatic run.
        for (const prerequisite of Object.values(values.needs)) prerequisite.result = 'success';
        assert.equal(evaluate(condition, values), false, `${file}/${job}: ${event}`);
      }
      assert.equal(evaluate(condition, context('workflow_dispatch')), true);
      assert.equal(evaluate(condition, context('workflow_dispatch', '[backend only] Fix rules')), true);
      assert.equal(evaluate(condition, context('workflow_dispatch', 'Prepare only', 'true', false)),
        job !== 'backend_ready', 'Build-only dispatch must not wait for or run a deployment');
    }
  }
});

test('Hosting and Functions are deployed only by their selected scopes', () => {
  const workflow = readFileSync('.github/workflows/firebase-hosting-merge.yml', 'utf8');
  for (const [step, allowed] of [
    ['Deploy to Firebase Hosting', ['web', 'full']],
    ['Deploy account deletion functions and data rules', ['backend', 'full']],
  ]) {
    const condition = workflow.match(new RegExp(`- name: ${step}\\n\\s+if: ([^\\n]+)`))?.[1];
    for (const scope of ['full', 'web', 'backend', 'rules', 'none', 'verify']) {
      assert.equal(evaluate(condition, {needs: {deployment_plan: {outputs: {scope}}},
        contains: (values, value) => values.includes(value), fromJSON: JSON.parse}), allowed.includes(scope));
    }
  }
});

test('validation has no workflow-wide queue while production writes remain serialized', () => {
  const workflow = readFileSync('.github/workflows/firebase-hosting-merge.yml', 'utf8');
  assert(!/^concurrency:/m.test(workflow));
  const production = workflow.slice(workflow.indexOf('  firebase_production:'));
  assert.match(production, /    concurrency:\n      group: firebase-production\n      cancel-in-progress: false/);
});
