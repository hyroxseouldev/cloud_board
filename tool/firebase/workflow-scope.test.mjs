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

test('native QA requires a development tag and main pushes never deploy', () => {
  for (const file of ['testflight-main.yml', 'google-play-main.yml']) {
    const workflow = readFileSync(`.github/workflows/${file}`, 'utf8');
    const triggers = workflow.match(/^on:\n([\s\S]*?)(?=^\S)/m)?.[1];
    assert.deepEqual([...triggers.matchAll(/^  ([a-z_]+):/gm)].map(match => match[1]), ['push', 'workflow_run', 'workflow_dispatch']);
    const check = (event, branch = 'v1.2.2', conclusion = 'success', repo = 'owner/repo', ref = 'refs/heads/main') => evaluate(jobCondition(file, 'preflight'), {
      github: {event_name: event, ref, repository: 'owner/repo',
        event: {workflow_run: {head_branch: branch, conclusion, head_repository: {full_name: repo}}}},
      startsWith: (value, prefix) => value?.startsWith(prefix) ?? false,
    });
    assert.equal(check('push'), false);
    assert.equal(check('push', undefined, undefined, undefined, 'refs/tags/dev/v1.2.2-1'), true);
    assert.equal(check('push', undefined, undefined, undefined, 'refs/tags/v1.2.2'), false);
    assert.equal(check('workflow_dispatch'), true);
    assert.equal(check('workflow_run'), true);
    assert.equal(check('workflow_run', 'main'), false);
    assert.equal(check('workflow_run', 'v1.2.2', 'failure'), false);
    assert.equal(check('workflow_run', 'v1.2.2', 'success', 'fork/repo'), false);
    assert.equal(check('pull_request'), false);
    assert(workflow.includes('MOBILE_DEVELOPMENT_READY'));
    for (const ready of ['true', 'false', '']) {
      assert.equal(evaluate(jobCondition(file, 'upload'), {needs: {preflight: {outputs: {ready}}}}), ready === 'true');
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

test('production runs after audited CI skips only when both release gates pass', () => {
  const condition = jobCondition('firebase-hosting-merge.yml', 'firebase_production');
  const allowed = ({ancestor = 'skipped', gate = 'success', plan = 'success', cancelled = false,
    event = 'workflow_dispatch', ref = 'refs/tags/v1.3.0', scope = 'full'} = {}) => {
    // GitHub adds success() to expressions without a status function; ancestor
    // skips therefore propagate even when the immediate aggregation job passes.
    const explicitStatus = /\b(?:always|cancelled|failure|success)\s*\(/.test(condition);
    if (!explicitStatus && ancestor !== 'success') return false;
    return evaluate(condition, {
      always: () => true, cancelled: () => cancelled,
      success: () => ancestor === 'success', failure: () => ancestor === 'failure',
      github: {event_name: event, ref},
      needs: {firebase_required: {result: gate}, deployment_plan: {result: plan, outputs: {scope}}},
      startsWith: (value, prefix) => value.startsWith(prefix),
      contains: (values, value) => values.includes(value), fromJSON: JSON.parse,
    });
  };
  assert.equal(allowed(), true, 'audited CI skips must not skip production deployment');
  assert.equal(allowed({ancestor: 'success', event: 'push'}), true);
  for (const result of ['failure', 'cancelled', 'skipped']) {
    assert.equal(allowed({gate: result}), false);
    assert.equal(allowed({plan: result}), false);
  }
  assert.equal(allowed({cancelled: true}), false);
  assert.equal(allowed({event: 'pull_request'}), false);
  assert.equal(allowed({ref: 'refs/heads/main'}), false);
  for (const scope of ['none', 'verify']) assert.equal(allowed({scope}), false);
  for (const scope of ['full', 'web', 'backend', 'rules']) assert.equal(allowed({scope}), true);
});

test('explicit CI skip omits heavy jobs while preserving the selected web build', () => {
  const file = 'firebase-hosting-merge.yml';
  for (const validation_mode of ['required', 'skipped']) {
    for (const scope of ['full', 'web', 'backend', 'rules', 'verify']) {
      const values = {needs: {deployment_plan: {outputs: {scope, release_tag: 'v1.2.3', validation_mode}}},
        contains: (items, value) => items.includes(value), fromJSON: JSON.parse};
      for (const job of ['app_validation', 'class_start_regressions']) {
        assert.equal(evaluate(jobCondition(file, job), values), validation_mode === 'required');
      }
      assert.equal(evaluate(jobCondition(file, 'firebase_contracts'), values), validation_mode === 'required' && scope !== 'web');
      assert.equal(evaluate(jobCondition(file, 'web_build'), values), ['full', 'web', 'verify'].includes(scope));
    }
  }
  const workflow = readFileSync(`.github/workflows/${file}`, 'utf8');
  assert.match(workflow, /skip_ci:\n(?:[^\n]+\n)*?        type: boolean\n        default: false/);
  assert.match(workflow, /name: release-validation-\$\{\{ github.run_id \}\}-\$\{\{ github.run_attempt \}\}/);
  assert.match(workflow, /path: build\/release\/validation\/release.json/);
  const build = workflow.slice(workflow.indexOf('  web_build:'), workflow.indexOf('  firebase_contracts:'));
  for (const command of ['node tool/firebase/environments.mjs check', 'flutter build web --release', 'node tool/web_symbols.mjs seal']) assert(build.includes(command));
  assert(!/flutter test|flutter analyze|node --test/.test(build));
  const deploy = workflow.slice(workflow.indexOf('  firebase_production:'));
  for (const command of ['node tool/firebase/environments.mjs check', 'npm ci --prefix functions', 'node tool/firebase/release.mjs current', 'node tool/firebase/release.mjs verify', 'node functions/tools/release-smoke.mjs']) assert(deploy.includes(command));
  assert.match(workflow, /needs: \[[^\n]*web_build\]/);
});
