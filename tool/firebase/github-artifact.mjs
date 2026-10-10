import assert from 'node:assert/strict';
import {mkdtempSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {execFileSync} from 'node:child_process';
import {hash} from './common.mjs';

export async function readReleaseArtifact(artifact, repository, token) {
  assert.match(artifact.digest || '', /^sha256:[a-f0-9]{64}$/, 'Artifact digest is required');
  assert(Number.isSafeInteger(artifact.id) && artifact.id > 0 && !artifact.expired);
  const response = await fetch(`https://api.github.com/repos/${repository}/actions/artifacts/${artifact.id}/zip`, {
    headers: {Authorization: `Bearer ${token}`, Accept: 'application/vnd.github+json'}, signal: AbortSignal.timeout(30_000),
  });
  assert(response.ok, `Receipt download failed (${response.status})`);
  const bytes = Buffer.from(await response.arrayBuffer());
  assert(bytes.length > 0 && bytes.length <= 5 * 1024 * 1024, 'Unexpected receipt artifact size');
  assert.equal(`sha256:${hash(bytes)}`, artifact.digest, 'Receipt artifact digest mismatch');
  const directory = mkdtempSync(join(tmpdir(), 'cloudboard-receipt-'));
  try {
    const file = join(directory, 'receipt.zip'); writeFileSync(file, bytes);
    // Read one fixed member; never extract arbitrary archive paths.
    return JSON.parse(execFileSync('unzip', ['-p', file, 'release.json'], {encoding: 'utf8', maxBuffer: 1024 * 1024}));
  } finally { rmSync(directory, {recursive: true, force: true}); }
}
