import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {root, readJson, hash, filesIn} from './common.mjs';

const directory = 'functions/test/fixtures/workout-save/';
export function validateFixtures(registry, files, read, baseline = {}) {
  assert.equal(registry.format, 1);
  assert(registry.clients.length > 0);
  assert.deepEqual(registry.clients.map(c => c.file).sort(), files.sort(), 'Supported-client fixture inventory differs');
  for (const client of registry.clients) {
    assert.match(client.file, /^functions\/test\/fixtures\/workout-save\/[A-Za-z0-9._-]+\.json$/);
    assert.match(client.sourceCommit, /^[a-f0-9]{40}$/);
    assert(client.platforms.length > 0 && client.schemas.length > 0);
    const bytes = read(client.file), data = JSON.parse(bytes);
    assert.equal(hash(bytes), client.sha256, `Frozen fixture changed: ${client.file}`);
    assert.equal(data.client, client.client);
    assert.equal(data.sourceCommit, client.sourceCommit);
  }
  for (const [file, digest] of Object.entries(baseline)) {
    assert(files.includes(file), `Released fixture removed: ${file}`);
    assert.equal(hash(read(file)), digest, `Released fixture overwritten: ${file}`);
  }
}
export function verifyFixtures(base = process.env.CI ? process.env.CONTRACT_BASE_REF : 'origin/main') {
  assert(base, 'Trusted base ref is required in CI');
  const baseline = {};
  // An exact SHA/ref is passed as an argument, never interpolated into a shell.
  const paths = execFileSync('git', ['ls-tree', '-r', '--name-only', base, '--', directory], {cwd: root, encoding: 'utf8'}).trim().split('\n').filter(Boolean);
  for (const path of paths) baseline[path] = hash(execFileSync('git', ['show', `${base}:${path}`], {cwd: root}));
  validateFixtures(readJson('tool/firebase/supported-clients.json'), filesIn(directory).filter(f => f.endsWith('.json')),
    file => readFileSync(resolve(root, file)), baseline);
}
