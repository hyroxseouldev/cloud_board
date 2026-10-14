import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import {runInNewContext} from 'node:vm';

function jobCondition(file, job) {
  const text = readFileSync(`.github/workflows/${file}`, 'utf8');
  const block = text.match(new RegExp(`^  ${job}:\\n([\\s\\S]*?)(?=^  [a-z_]+:|$(?![\\s\\S]))`, 'm'))?.[1];
  assert(block, `Missing workflow job: ${job}`);
  return block.match(/^    if: >-\n((?:      .+\n)+)/m)?.[1].trim();
}
const context = (event = 'push', message = 'Release', bootstrapped = 'true', upload = true) => {
  const scheduled = event === 'workflow_dispatch' ||
    (!message.includes('[backend only]') && !message.includes('[skip ') && bootstrapped === 'true');
  return {
    github: {event_name: event, event: {head_commit: {message}}},
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

test('real native workflow conditions suppress every automatic backend-only upload job', () => {
  for (const [file, jobs, skip] of [
    ['testflight-main.yml', ['backend_ready', 'verify', 'upload'], '[skip testflight]'],
    ['google-play-main.yml', ['backend_ready', 'upload'], '[skip google-play]'],
  ]) {
    for (const job of jobs) {
      const condition = jobCondition(file, job);
      assert.equal(evaluate(condition, context()), true);
      assert.equal(evaluate(condition, context('push', '[backend only] Fix rules')), false);
      assert.equal(evaluate(condition, context('push', skip)), false);
      assert.equal(evaluate(condition, context('workflow_dispatch', '[backend only] Fix rules')), true);
      assert.equal(evaluate(condition, context('workflow_dispatch', 'Prepare only', 'true', false)),
        job !== 'backend_ready', 'Build-only dispatch must not wait for or run a deployment');
      if (file === 'google-play-main.yml') assert.equal(evaluate(condition, context('push', 'Release', 'false')), false);
    }
  }
});

test('real Hosting step publishes only the full scope', () => {
  const workflow = readFileSync('.github/workflows/firebase-hosting-merge.yml', 'utf8');
  const condition = workflow.match(/- name: Deploy to Firebase Hosting\n\s+if: ([^\n]+)/)?.[1];
  for (const scope of ['full', 'backend', 'rules']) {
    assert.equal(evaluate(condition, {needs: {deployment_plan: {outputs: {scope}}}}), scope === 'full');
  }
});
