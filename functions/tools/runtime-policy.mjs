import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {parseArgs} from 'node:util';
import {pathToFileURL} from 'node:url';

export const runtimeFeatures = ['splitPlayback', 'aiSlideGeneration'];
export function validateRuntimePolicy(value) {
  assert(value && typeof value === 'object' && !Array.isArray(value), 'Policy must be an object');
  assert.equal(value.schemaVersion, 1, 'Unsupported schemaVersion');
  assert(Number.isSafeInteger(value.revision) && value.revision >= 0, 'revision must be a non-negative integer');
  assert(value.features && typeof value.features === 'object' && !Array.isArray(value.features), 'features must be an object');
  assert.deepEqual(Object.keys(value).sort(), ['features', 'revision', 'schemaVersion']);
  for (const [name, rule] of Object.entries(value.features)) {
    assert(runtimeFeatures.includes(name), `Unknown feature: ${name}`);
    assert(rule && typeof rule === 'object', `Invalid rule: ${name}`);
    assert.deepEqual(Object.keys(rule).sort(), ['enabled', 'rolloutPercent']);
    assert.equal(typeof rule.enabled, 'boolean', `enabled must be boolean: ${name}`);
    assert(Number.isInteger(rule.rolloutPercent) && rule.rolloutPercent >= 0 && rule.rolloutPercent <= 100, `rolloutPercent must be 0–100: ${name}`);
  }
  return value;
}

export async function applyRuntimePolicy(database, next, expectedRevision) {
  validateRuntimePolicy(next);
  assert(Number.isSafeInteger(expectedRevision) && expectedRevision >= -1, 'expected-revision must be an integer (use -1 only for first creation)');
  const reference = database.doc('runtimePolicy/current');
  await database.runTransaction(async transaction => {
    const snapshot = await transaction.get(reference);
    const current = snapshot.exists ? snapshot.data() : null;
    const revision = current?.revision ?? -1;
    assert.equal(revision, expectedRevision, 'Policy changed; read it again before applying');
    assert(next.revision > revision, 'Revision must increase, including rollback/restoration');
    transaction.set(reference, next);
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const {values, positionals} = parseArgs({allowPositionals: true, options: {
    project: {type: 'string'}, file: {type: 'string'}, 'expected-revision': {type: 'string'},
  }});
  const command = positionals[0];
  assert(['validate', 'show', 'apply'].includes(command), 'Usage: runtime-policy.mjs validate|show|apply --project <id> --file <json> --expected-revision <n>');
  const next = command === 'show' ? null : validateRuntimePolicy(JSON.parse(readFileSync(values.file, 'utf8')));
  if (command === 'validate') {
    console.log(`Runtime policy revision ${next.revision} is valid. No remote changes made.`);
  } else {
    assert.match(values.project || '', /^[a-z][a-z0-9-]{4,28}[a-z0-9]$/, 'Explicit Firebase --project is required');
    const {initializeApp, applicationDefault} = await import('firebase-admin/app');
    const {getFirestore} = await import('firebase-admin/firestore');
    const app = initializeApp({projectId: values.project, credential: applicationDefault()});
    const database = getFirestore(app);
    if (command === 'show') {
      const snapshot = await database.doc('runtimePolicy/current').get();
      console.log(JSON.stringify({project: values.project, policy: snapshot.data() ?? null}, null, 2));
    } else {
      assert(values['expected-revision'] !== undefined, 'Explicit --expected-revision is required');
      await applyRuntimePolicy(database, next, Number(values['expected-revision']));
      console.log(`Applied runtime policy revision ${next.revision} to ${values.project}.`);
    }
  }
}
