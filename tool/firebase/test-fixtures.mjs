import {targets, ruleFiles, manifestHash} from './release.mjs';
import {hashFile, hash, canonical, readJson} from './common.mjs';

export function receiptFor(id = {sha: 'a'.repeat(40), runId: '12', attempt: '2'}) {
  const manifest = {format: 1, ...id, targets, databaseSemanticHash: hash(canonical(readJson('database.rules.json'))), files: Object.fromEntries(ruleFiles.map(file => [file, hashFile(file)]))};
  return {format: 1, ...id, status: 'success', completedAt: '2026-10-10T03:00:00.000Z', manifest, manifestHash: manifestHash(manifest),
    smoke: {status: 'success', cleanup: 'success', runId: `${id.runId}-${id.attempt}`, checks: ['workout', 'storage', 'tv', 'isolation']},
    rules: {status: 'success', services: Object.fromEntries(['firestore', 'database', 'storage'].map((service, i) => [service, {version: 'verified', sourceHash: manifest.files[ruleFiles[i]], ...(service === 'database' ? {semanticHash: manifest.databaseSemanticHash} : {})}]))}};
}
