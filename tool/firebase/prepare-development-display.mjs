import assert from 'node:assert/strict';
import {readFileSync, writeFileSync, mkdirSync, rmSync, copyFileSync, cpSync, symlinkSync} from 'node:fs';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {resolve} from 'node:path';

export const developmentDisplaySource = 'build/development-display-functions';
const project = 'cloud-board-development';
const root = fileURLToPath(new URL('../../', import.meta.url));

export async function prepareDevelopmentDisplayPackage(projectId) {
  assert.equal(projectId, project, 'The display package is development-only');
  const {default: ts} = await import('../../functions-legacy/node_modules/typescript/lib/typescript.js');
  const original = readFileSync(resolve(root, 'functions-legacy/lib/index.js'), 'utf8');
  const parsed = ts.createSourceFile('index.js', original, ts.ScriptTarget.ES2022, true, ts.ScriptKind.JS);
  assert.equal(parsed.parseDiagnostics.length, 0, 'Legacy build must be valid JavaScript');
  const statements = parsed.statements.filter(statement => ts.isVariableStatement(statement) &&
    statement.declarationList.declarations.some(declaration =>
      declaration.name.getText(parsed) === 'cloudboardSetDisplayState'));
  assert.equal(statements.length, 1, 'Expected exactly one display output callable');
  assert(statements[0].modifiers?.some(modifier => modifier.kind === ts.SyntaxKind.ExportKeyword));
  const handler = statements[0].getText(parsed);
  const entry = `// Generated from the existing legacy callable; never deploy to production.
import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {setGlobalOptions} from 'firebase-functions/v2';
import {firebaseServices} from './services/firebase.js';
const projectId = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
if (projectId !== '${project}') throw new Error('The display package is development-only');
setGlobalOptions({serviceAccount: 'development-runtime@${project}.iam.gserviceaccount.com', minInstances: 0});
${handler}
`;
  const output = resolve(root, developmentDisplaySource);
  // This directory is generated solely by this tool; source and pinned legacy
  // entrypoint remain untouched. Provider params are never imported by entry.
  rmSync(output, {recursive: true, force: true});
  mkdirSync(output, {recursive: true});
  cpSync(resolve(root, 'functions-legacy/lib'), resolve(output, 'lib'), {recursive: true});
  writeFileSync(resolve(output, 'lib/index.js'), entry);
  for (const name of ['package.json', 'package-lock.json']) {
    copyFileSync(resolve(root, 'functions-legacy', name), resolve(output, name));
  }
  // Firebase CLI discovers endpoints locally using the already installed,
  // locked legacy dependencies. node_modules is excluded from deployment.
  symlinkSync(resolve(root, 'functions-legacy/node_modules'), resolve(output, 'node_modules'), 'dir');
  return {source: developmentDisplaySource, handler};
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  assert.equal(process.argv.length, 3, 'Pass the explicit development project');
  const result = await prepareDevelopmentDisplayPackage(process.argv[2]);
  console.log(`Prepared ${result.source}: cloudboard-auth/cloudboardSetDisplayState only`);
}
