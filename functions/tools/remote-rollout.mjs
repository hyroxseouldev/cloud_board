import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {parseArgs} from 'node:util';
import {pathToFileURL} from 'node:url';
import {validateRuntimePolicy} from './runtime-policy.mjs';

export const parameter = 'cloudboard_optional_features_v1';
export function rolloutTemplate(template, value, {actor, reason}) {
  validateRuntimePolicy(value);
  assert(typeof actor === 'string' && actor.trim().length >= 2 && actor.length <= 100, 'Operator required');
  assert(typeof reason === 'string' && reason.trim().length >= 5 && reason.length <= 200, 'Change reason required');
  const existing = template.parameters?.[parameter];
  if (existing?.defaultValue?.value) {
    const previous = validateRuntimePolicy(JSON.parse(existing.defaultValue.value));
    assert(value.revision > previous.revision, 'Revision must increase, including restoration');
  }
  assert(!Object.keys(existing?.conditionalValues ?? {}).length, 'Remove per-device conditions through review; cohort selection must remain owner-stable');
  return {...template, parameters: {...template.parameters, [parameter]: {
    defaultValue: {value: JSON.stringify(value)}, valueType: 'JSON',
    description: 'Optional feature rollout; appReleases remains the version policy source.',
  }}, version: {description: `${actor}: ${reason}`}};
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const {values} = parseArgs({options: {project: {type: 'string'}, file: {type: 'string'}, actor: {type: 'string'},
    reason: {type: 'string'}, 'expected-etag': {type: 'string'}, apply: {type: 'boolean', default: false}}});
  assert(['cloud-board-stationd', 'cloud-board-development'].includes(values.project), 'Explicit known --project required');
  const value = validateRuntimePolicy(JSON.parse(readFileSync(values.file, 'utf8')));
  const {initializeApp, applicationDefault} = await import('firebase-admin/app');
  const {getRemoteConfig} = await import('firebase-admin/remote-config');
  const app = initializeApp({credential: applicationDefault(), projectId: values.project});
  const remote = getRemoteConfig(app);
  const current = await remote.getTemplate();
  const next = rolloutTemplate(current, value, values);
  console.log(JSON.stringify({project: values.project, parameter, etag: current.etag,
    before: current.parameters?.[parameter] ?? null, after: next.parameters[parameter], mode: values.apply ? 'apply' : 'dry-run'}, null, 2));
  if (values.apply) {
    assert.equal(values['expected-etag'], current.etag, 'Template changed; inspect it again');
    // The SDK sends If-Match; do not use force:true. Firebase keeps template versions.
    const result = await remote.publishTemplate(next);
    console.log(JSON.stringify({version: result.version?.versionNumber, etag: result.etag}));
  }
}
