import assert from 'node:assert/strict';
import test from 'node:test';
import {firebaseProject} from '../src/firebase-environment.js';
test('server initialization cannot fall back into production or mix projects', () => {
  assert.throws(() => firebaseProject({}));
  assert.throws(() => firebaseProject({GCLOUD_PROJECT: 'unrecognized'}));
  assert.throws(() => firebaseProject({GCLOUD_PROJECT: 'cloud-board-development', GOOGLE_CLOUD_PROJECT: 'cloud-board-stationd'}));
  for (const project of ['cloud-board-development', 'cloud-board-stationd', 'demo-cloudboard-tests']) {
    assert.equal(firebaseProject({GCLOUD_PROJECT: project}), project);
  }
});
