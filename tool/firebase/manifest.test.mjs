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
  const keys = ['GITHUB_SHA', 'RELEASE_SOURCE_SHA', 'GITHUB_RUN_ID', 'GITHUB_RUN_ATTEMPT', 'FIREBASE_DEPLOY_SCOPE'];
  const previous = keys.map(k => process.env[k]);
  const id = {sha: 'a'.repeat(40), runId: '123', attempt: '2'};
  Object.assign(process.env, {GITHUB_SHA: id.sha, RELEASE_SOURCE_SHA: id.sha, GITHUB_RUN_ID: id.runId, GITHUB_RUN_ATTEMPT: id.attempt, FIREBASE_DEPLOY_SCOPE: 'full'});
  const write = (file, content) => { mkdirSync(dirname(join(dir, file)), {recursive: true}); writeFileSync(join(dir, file), content); };
  const json = (file, value) => write(file, JSON.stringify(value));
  try {
    for (const file of ['tool/firebase/release.mjs', 'tool/firebase/common.mjs', 'tool/firebase/support_retirements.mjs', 'firebase.json', 'firestore.rules', 'database.rules.json', 'storage.rules']) write(file, readFileSync(file));
    for (const directory of ['functions/src', 'functions/tools', 'functions/certificates', 'functions/test/fixtures']) write(`${directory}/example.js`, 'verified');
    for (const file of ['firestore.indexes.json', 'functions/package.json', 'functions/package-lock.json', 'build/contracts/app-current.json', 'build/contracts/workout-save-current.json', 'tool/firebase/compatibility-policy.json']) json(file, {});
    const sourceCommit = 'b'.repeat(40);
    const retirementPolicyFile = 'tool/firebase/support-retirements.json';
    const retirementBytes = readFileSync(retirementPolicyFile);
    const retirementPolicy = JSON.parse(retirementBytes);
    write(retirementPolicyFile, retirementBytes);
    json('tool/firebase/supported-clients.json', {clients: [{client: 'released', sourceCommit},
      ...retirementPolicy.retirements.flatMap(entry => entry.clients.map(client => ({client, sourceCommit: entry.sourceCommit}))),
    ]});
    write('tool/firebase/released_reader_contract_test.dart', 'actual released reader harness');
    const readerReport = {format: 1, status: 'success', harnessSha256: hash('actual released reader harness'), policySha256: hash('{}'), retirementPolicySha256: hash(retirementBytes),
      candidateFiles: {'build/contracts/app-current.json': hash('{}'), 'build/contracts/workout-save-current.json': hash('{}')},
      sources: [{sourceCommit, clients: ['released'], status: 'success', retirement: null},
        ...retirementPolicy.retirements.map(retirement => ({sourceCommit: retirement.sourceCommit, clients: retirement.clients, status: 'retired', retirement})),
      ]};
    json('build/contracts/released-readers/report.json', readerReport);
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
    assert.equal(manifest.files[retirementPolicyFile], hash(retirementBytes));
    assert.equal(manifest.files['tool/firebase/support_retirements.mjs'], hash(readFileSync('tool/firebase/support_retirements.mjs')));
    for (const retirementPolicySha256 of [undefined, '0'.repeat(64)]) {
      json('build/contracts/released-readers/report.json', {...readerReport, retirementPolicySha256});
      assert.throws(() => makeManifest(), /Support retirement policy changed/);
    }
    for (const retirement of [undefined, {...readerReport.sources[1].retirement, authorization: {remotelyVerified: true}}]) {
      const changed = structuredClone(readerReport); changed.sources[1].retirement = retirement;
      json('build/contracts/released-readers/report.json', changed);
      assert.throws(() => makeManifest(), /retirement evidence mismatch/);
    }
    for (const [index, status] of [[0, 'retired'], [1, 'success']]) {
      const changed = structuredClone(readerReport); changed.sources[index].status = status;
      json('build/contracts/released-readers/report.json', changed);
      assert.throws(() => makeManifest(), /Released reader did not pass/);
    }
    json('build/contracts/released-readers/report.json', readerReport);
    for (const file of [retirementPolicyFile, 'tool/firebase/support_retirements.mjs']) {
      const missing = structuredClone(manifest); delete missing.files[file];
      assert.throws(() => verifyManifest(missing), /Missing tool\/firebase\/support/);
    }
    const removedPolicy = {...retirementPolicy, retirements: retirementPolicy.retirements.slice(1)};
    json(retirementPolicyFile, removedPolicy);
    assert.throws(() => verifyManifest(manifest), /Artifact changed/);
    assert.throws(() => makeManifest(), /Support retirement policy changed/);
    // Updating the digest alone cannot hide that a retired source lost its
    // authorization: it must become a passing active reader again.
    json('build/contracts/released-readers/report.json', {...readerReport, retirementPolicySha256: hash(JSON.stringify(removedPolicy))});
    assert.throws(() => makeManifest(), /Released reader did not pass/);
    write(retirementPolicyFile, retirementBytes);
    json('build/contracts/released-readers/report.json', readerReport);
    verifyManifest(manifest);
    json('build/contracts/released-readers/report.json', {...readerReport, sources: []});
    assert.throws(() => makeManifest(), /Missing released source reader/);
    json('build/contracts/released-readers/report.json', {...readerReport, status: 'skipped'});
    assert.throws(() => makeManifest(), /Released readers did not pass/);
    json('build/contracts/released-readers/report.json', readerReport);
    process.env.FIREBASE_DEPLOY_SCOPE = 'backend';
    assert.throws(() => verifyManifest(manifest), /scope mismatch/);
    const repair = makeManifest(); verifyManifest(repair);
    assert.equal(repair.scope, 'backend');
    process.env.FIREBASE_DEPLOY_SCOPE = 'full';
    assert.throws(() => verifyManifest(repair), /scope mismatch/);

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
    rmSync(join(dir, 'build/web/rules'));
    process.env.FIREBASE_DEPLOY_SCOPE = 'backend';
    rmSync(join(dir, 'build/web'), {recursive: true});
    const backendOnly = makeManifest(); verifyManifest(backendOnly);
    assert(!Object.keys(backendOnly.files).some(path => path.startsWith('build/web/')));
    process.env.FIREBASE_DEPLOY_SCOPE = 'web';
    write('build/web/index.html', '<html>verified</html>');
    rmSync(join(dir, 'build/contracts'), {recursive: true});
    rmSync(join(dir, 'build/firebase-contracts'), {recursive: true});
    const webOnly = makeManifest(); verifyManifest(webOnly);
    assert(!Object.keys(webOnly.files).some(path => path.startsWith('build/firebase-contracts/')));

  } finally {
    keys.forEach((key, i) => previous[i] === undefined ? delete process.env[key] : process.env[key] = previous[i]);
    rmSync(dir, {recursive: true, force: true});
  }
});
