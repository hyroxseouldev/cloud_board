import assert from 'node:assert/strict';
import test from 'node:test';
import {mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync, symlinkSync} from 'node:fs';
import {join, dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {pathToFileURL} from 'node:url';
import {hash, readJson} from './common.mjs';

test('candidate verification rejects missing evidence, changed artifacts, wrong targets and new files', async () => {
  // A separate repository-shaped directory exercises the actual manifest code
  // without rewriting the developer's build, source or test reports.
  const dir = mkdtempSync(join(tmpdir(), 'sta104-manifest-'));
  const keys = ['GITHUB_SHA', 'GITHUB_RUN_ID', 'GITHUB_RUN_ATTEMPT'];
  const previous = keys.map(k => process.env[k]);
  const id = {sha: 'a'.repeat(40), runId: '123', attempt: '2'};
  Object.assign(process.env, {GITHUB_SHA: id.sha, GITHUB_RUN_ID: id.runId, GITHUB_RUN_ATTEMPT: id.attempt});
  const write = (file, content) => { mkdirSync(dirname(join(dir, file)), {recursive: true}); writeFileSync(join(dir, file), content); };
  const json = (file, value) => write(file, JSON.stringify(value));
  try {
    for (const file of ['tool/firebase/release.mjs', 'tool/firebase/common.mjs', 'firebase.json', 'firestore.rules', 'database.rules.json', 'storage.rules']) write(file, readFileSync(file));
    for (const directory of ['functions/src', 'functions/tools', 'functions/certificates', 'functions/test/fixtures']) write(`${directory}/example.js`, 'verified');
    for (const file of ['firestore.indexes.json', 'functions/package.json', 'functions/package-lock.json', 'tool/firebase/supported-clients.json', 'build/contracts/app-current.json']) json(file, {});
    write('build/web/index.html', '<html>verified</html>');
    const suites = {format: 1, suites: [{id: 'save', file: 'functions/test/save-emulator.mjs', project: 'demo-save', coverage: ['firestore']}]};
    json('tool/firebase/contract-suites.json', suites);
    const evidence = file => { write(file, 'test evidence'); return {file, sha256: hash('test evidence')}; };
    const report = {format: 1, ...id, status: 'success', manifestHash: hash(JSON.stringify(suites)), suites: [
      {...suites.suites[0], status: 'success', log: evidence('build/firebase-contracts/save.log'),
        coverage: ['json', 'html'].map(ext => evidence(`build/firebase-contracts/save-firestore.${ext}.gz`))},
    ]};
    const reportFile = 'build/firebase-contracts/report.json'; json(reportFile, report);
    const {makeManifest, verifyManifest} = await import(pathToFileURL(join(dir, 'tool/firebase/release.mjs')).href);
    const manifest = makeManifest(); verifyManifest(manifest);

    write('build/web/index.html', 'changed after validation');
    assert.throws(() => verifyManifest(manifest), /Artifact changed/);
    write('build/web/index.html', '<html>verified</html>');
    write('build/web/extra.js', 'unverified');
    assert.throws(() => verifyManifest(manifest), /Files added\/removed/);
    rmSync(join(dir, 'build/web/extra.js'));
    write('build/contracts/app-current.json', '{"regenerated":true}');
    assert.throws(() => verifyManifest(manifest), /Artifact changed/);
    json('build/contracts/app-current.json', {});
    rmSync(join(dir, report.suites[0].log.file));
    assert.throws(() => makeManifest());
    evidence(report.suites[0].log.file);

    const missing = structuredClone(report); missing.suites[0].coverage.pop(); json(reportFile, missing);
    assert.throws(() => makeManifest(), /Missing coverage/);
    const skipped = structuredClone(report); skipped.suites[0].status = 'skipped'; json(reportFile, skipped);
    assert.throws(() => makeManifest(), /did not succeed/);
    json(reportFile, report);
    write('build/web/private.map', 'symbols'); assert.throws(() => makeManifest(), /Public source map/);
    rmSync(join(dir, 'build/web/private.map'));
    const config = readJson('firebase.json'); config.storage[0].bucket = 'another-bucket'; json('firebase.json', config);
    assert.throws(() => makeManifest());
    write('firebase.json', readFileSync('firebase.json'));
    symlinkSync(join(dir, 'storage.rules'), join(dir, 'build/web/rules'));
    assert.throws(() => makeManifest(), /Symlink not allowed/);
  } finally {
    keys.forEach((key, i) => previous[i] === undefined ? delete process.env[key] : process.env[key] = previous[i]);
    rmSync(dir, {recursive: true, force: true});
  }
});
