import assert from 'node:assert/strict';
import {mkdirSync, readFileSync, writeFileSync} from 'node:fs';
import {join, resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {validateReceipt, ruleFiles} from './release.mjs';
import {hash, writeJson} from './common.mjs';

// Recovery creates a reviewable candidate. It never changes deployed rules, the
// checkout or customer data. The candidate must pass the CURRENT client tests.
export function prepareRecovery({receipt, bundle, output}) {
  validateReceipt(receipt, receipt);
  const destination = resolve(output);
  assert(destination.includes('/build/'), 'Recovery output must be an isolated build directory');
  const values = Object.fromEntries(ruleFiles.map(file => {
    const bytes = readFileSync(join(bundle, file));
    assert.equal(hash(bytes), receipt.manifest.files[file], `Recovery bundle changed: ${file}`);
    return [file, bytes];
  }));
  mkdirSync(destination, {recursive: true});
  for (const [name, bytes] of Object.entries(values)) writeFileSync(join(destination, name), bytes);
  const plan = {format: 1, status: 'requires-current-contracts', previousSha: receipt.sha, previousRunId: receipt.runId,
    targets: receipt.manifest.targets, files: Object.fromEntries(ruleFiles.map(file => [file, receipt.manifest.files[file]])),
    steps: ['Review compatibility with all currently supported clients', 'Apply candidate in an isolated branch',
      'Run node tool/firebase_contracts.mjs', 'Merge a new verified main commit through the normal release gate',
      'Verify client smoke and live-rule read-back', 'Observe save diagnostics; do not infer success from zero errors']};
  writeJson(join(destination, 'recovery-plan.json'), plan);
  return plan;
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [receipt, bundle, output = 'build/recovery'] = process.argv.slice(2);
  assert(receipt && bundle, 'Usage: node tool/firebase/recovery.mjs RELEASE_JSON RULES_DIRECTORY [build/output]');
  console.log(JSON.stringify(prepareRecovery({receipt: JSON.parse(readFileSync(receipt, 'utf8')), bundle, output}), null, 2));
}
