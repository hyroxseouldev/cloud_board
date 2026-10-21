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

test('mobile-first compatibility runs only for selected mobile without a server deployment and cannot skip its checks', () => {
  const file = 'firebase-hosting-merge.yml';
  const condition = jobCondition(file, 'mobile_backend_compatibility');
  for (const scope of ['full', 'web', 'backend', 'rules', 'none', 'verify']) {
    for (const mobile_requested of ['true', 'false']) for (const validation_mode of ['required', 'skipped']) {
      assert.equal(evaluate(condition, {needs: {deployment_plan: {outputs: {scope, mobile_requested, validation_mode}}},
        contains: (values, value) => values.includes(value), fromJSON: JSON.parse}),
      mobile_requested === 'true' && ['verify', 'web'].includes(scope));
    }
  }
  const workflow = readFileSync(`.github/workflows/${file}`, 'utf8');
  const job = workflow.slice(workflow.indexOf('  mobile_backend_compatibility:'), workflow.indexOf('  web_build:'));
  assert(job.indexOf('verify_mobile_backend.mjs prepare') < job.indexOf('uses: subosito/flutter-action'));
  assert(job.includes('verify_mobile_backend.mjs test'));
  assert(job.includes("if: steps.compatibility.outputs.needs_tests == 'true'"));
  assert(job.includes('mobile-backend-compatibility-${{ github.run_id }}-${{ github.run_attempt }}'));
  assert(!job.includes('secrets.'));
  assert(!job.includes('firebase deploy'));
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
      assert.equal(evaluate(jobCondition(file, 'smoke_inputs'), values), validation_mode === 'skipped' && ['backend', 'rules', 'full'].includes(scope));
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

test('skipped backend CI exports current smoke payloads and validates them before production writes', () => {
  const workflow = readFileSync('.github/workflows/firebase-hosting-merge.yml', 'utf8');
  const inputs = workflow.slice(workflow.indexOf('  smoke_inputs:'), workflow.indexOf('  firebase_required:'));
  assert(inputs.includes('flutter test tool/export_workout_save_fixtures_test.dart tool/export_app_contracts_test.dart'));
  assert(inputs.includes('node tool/firebase/smoke-inputs.mjs prepare'));
  assert(!/firebase_contracts\.mjs|emulators:exec|flutter analyze/.test(inputs));
  assert.match(workflow, /needs: \[[^\n]*smoke_inputs[^\n]*\]/);
  assert.match(workflow, /name: firebase-smoke-inputs-\$\{\{ github.run_id \}\}-\$\{\{ github.run_attempt \}\}\n          path: build\/release\/smoke-inputs/);
  const deploy = workflow.slice(workflow.indexOf('  firebase_production:'));
  assert(deploy.indexOf('node functions/tools/release-smoke.mjs preflight') < deploy.indexOf('name: Authenticate Firebase rule deployment'));
});
