import assert from 'node:assert/strict';
import {appendFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';
import {backendFingerprint, functionsFingerprint, github} from './firebase/release.mjs';
import {latestRelease} from './firebase/latest-release.mjs';
import {hash, writeJson} from './firebase/common.mjs';
import {readReleaseArtifact} from './firebase/github-artifact.mjs';

export async function requireBackend({repository, sha, request, readArtifact, mode = 'release', fingerprint, ignoreRunId, functionsOnly = false, candidateFunctionsFingerprint}) {
  assert.match(sha || '', /^[a-f0-9]{40}$/, 'An exact source SHA is required');
  fingerprint ??= backendFingerprint(sha);
  assert(['release', 'qa'].includes(mode), 'Unknown release mode');
  // A release tag remains valid when main advances. QA may use an integrated
  // develop candidate, but never an unrelated branch carrying deployment keys.
  const branches = mode === 'qa' ? ['main', 'develop'] : ['main'];
  let trusted = false;
  for (const branch of branches) {
    const compare = await request(`/repos/${repository}/compare/${sha}...${branch}`);
    if (['ahead', 'identical'].includes(compare.status) && compare.merge_base_commit?.sha === sha) { trusted = true; break; }
  }
  assert(trusted, 'Source must be a trusted main/develop ancestor for the selected mode');
  const result = await latestRelease({repository, request, readArtifact, ignoreRunId});
  assert.equal(result.status, 'success', 'Backend deployment is in progress; retry upload after it completes');
  const {receipt, run} = result;
  assert(receipt.scope !== 'rules' || receipt.manifest.functionsFingerprint, 'Legacy rules-only receipt lacks verified Functions provenance; deploy backend once');
  if (functionsOnly) {
    assert.equal(receipt.manifest.functionsFingerprint || functionsFingerprint(receipt.sha), candidateFunctionsFingerprint || functionsFingerprint(sha),
      'Rules-only deployment cannot publish an undeployed Functions fingerprint; deploy backend first');
  } else if (receipt.manifest.backendFingerprint) {
    assert.equal(receipt.manifest.backendFingerprint, fingerprint, 'Candidate requires a different backend. Deploy the server changes before uploading this app.');
  } else {
    // Backward-compatible transition from old full receipts: compare every
    // deployed server input recorded in the original manifest, not just rules.
    const paths = Object.keys(receipt.manifest.files).filter(path => /^(functions\/(src|certificates)\/|functions\/package(?:-lock)?\.json$|firestore\.(rules|indexes\.json)$|database\.rules\.json$|storage\.rules$)/.test(path));
    assert(paths.some(path => path.startsWith('functions/src/')) && paths.includes('functions/package-lock.json'), 'Legacy receipt lacks backend source evidence');
    for (const path of paths) assert.equal(hash(execFileSync('git', ['show', `${sha}:${path}`])), receipt.manifest.files[path], `Candidate backend differs: ${path}`);
    // Also reject newly added functions/files absent from an old receipt.
    assert.equal(backendFingerprint(receipt.sha), fingerprint, 'Candidate backend differs from the deployed backend');
  }
  return {...run, backendReference: {runId: String(run.id), sha: receipt.sha, fingerprint}};
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = process.argv.slice(2);
  const value = name => args.includes(name) ? args[args.indexOf(name) + 1] : undefined;
  const sha = value('--source-sha') || process.env.SOURCE_SHA || process.env.GITHUB_SHA;
  assert.equal(execFileSync('git', ['rev-parse', 'HEAD'], {encoding: 'utf8'}).trim(), sha, 'Checkout must match the selected source SHA');
  const repository = process.env.GITHUB_REPOSITORY;
  assert(repository && process.env.GITHUB_TOKEN, 'Missing GitHub release gate credentials');
  const run = await requireBackend({repository, sha, mode: value('--mode') || (args.includes('--qa') ? 'qa' : 'release'), request: github,
    functionsOnly: args.includes('--rules'),
    ignoreRunId: args.includes('--web') || args.includes('--rules') ? process.env.GITHUB_RUN_ID : undefined,
    readArtifact: artifact => readReleaseArtifact(artifact, repository, process.env.GITHUB_TOKEN)});
  if (args.includes('--web')) writeJson('build/release/backend-reference.json', run.backendReference);
  const message = `Compatible deployed backend: ${run.html_url || run.id}; candidate ${sha}`;
  console.log(message);
  if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${message}\n`);
}
