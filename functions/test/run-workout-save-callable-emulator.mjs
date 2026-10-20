// Node 22 + Java 21 + firebase-tools are required. No production resources.
import {mkdtemp, mkdir, writeFile, symlink, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {spawn} from 'node:child_process';

const functions = fileURLToPath(new URL('../', import.meta.url));
const root = await mkdtemp(path.join(tmpdir(), 'sta189-callable-'));
const fixture = path.join(root, 'functions');
const project = 'demo-cloudboard-sta189-callable';
const flutterClient = process.argv.includes('--flutter-client');
const quote = value => `'${value.replaceAll("'", "'\\''")}'`;
try {
  await mkdir(fixture);
  await symlink(path.join(functions, 'node_modules'), path.join(fixture, 'node_modules'), 'dir');
  await writeFile(path.join(fixture, 'package.json'), JSON.stringify({
    name: 'sta189-local-callable-fixture', private: true, type: 'module', main: 'index.js',
    engines: {node: '22'}, dependencies: {'firebase-admin': '^13.0.0', 'firebase-functions': '^6.0.0'},
  }));
  // Re-export the shipped callable wrapper; omit unrelated triggers/endpoints
  // so this local experiment measures the synchronous save path independently.
  await writeFile(path.join(fixture, 'index.js'),
    `export {saveWorkout} from ${JSON.stringify(pathToFileURL(path.join(functions, 'src/index.js')).href)};\n`);
  await writeFile(path.join(root, 'firebase.json'), JSON.stringify({
    functions: [{source: 'functions', codebase: 'sta189-local', runtime: 'nodejs22'}],
    firestore: {rules: path.resolve(functions, '../firestore.rules')},
    ...(flutterClient ? {storage: {rules: path.resolve(functions, '../storage.rules')}} : {}),
    emulators: {
      auth: {host: '127.0.0.1', port: 19490},
      firestore: {host: '127.0.0.1', port: 19480, websocketPort: 19481},
      functions: {host: '127.0.0.1', port: 19401},
      ...(flutterClient ? {storage: {host: '127.0.0.1', port: 19499}} : {}),
      hub: {host: '127.0.0.1', port: 19440},
      logging: {host: '127.0.0.1', port: 19450},
      ui: {enabled: false}, singleProjectMode: true,
    },
  }));
  const script = flutterClient ? 'workout-save-flutter-emulator.mjs' : 'workout-save-callable-emulator.mjs';
  const command = `${quote(process.execPath)} ${quote(path.join(functions, 'test', script))}`;
  const child = spawn('firebase', ['emulators:exec', '--project', project,
    '--config', path.join(root, 'firebase.json'), '--only',
    flutterClient ? 'auth,firestore,functions,storage' : 'auth,firestore,functions', command], {
    cwd: root, stdio: 'inherit', env: {...process.env,
      GCLOUD_PROJECT: project, GOOGLE_CLOUD_PROJECT: project,
      STA189_FUNCTIONS_EMULATOR_HOST: '127.0.0.1:19401'},
  });
  process.exitCode = await new Promise((resolve, reject) => {
    child.once('error', reject);
    child.once('exit', code => resolve(code ?? 1));
  });
} finally {
  await rm(root, {recursive: true, force: true});
}
