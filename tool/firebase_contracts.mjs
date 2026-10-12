import {readFileSync} from 'node:fs';
import {readJson, run} from './firebase/common.mjs';
import {verifyFixtures, validateCurrentContracts} from './firebase/fixtures.mjs';
import {verifyReleasedReaders} from './firebase/released_readers.mjs';

// The only entry point: no credentials, deploy, production host or optional suites.
verifyFixtures(process.env.CONTRACT_BASE_REF);
await run(process.env.FLUTTER_BIN || 'flutter', ['test', 'tool/export_workout_save_fixtures_test.dart',
  'tool/export_starter_workout_fixtures_test.dart', 'tool/export_app_contracts_test.dart',
  'test/released_client_contracts_test.dart'], {timeoutMs: 180_000});
validateCurrentContracts(readJson('tool/firebase/supported-clients.json'), file => readFileSync(file));
await verifyReleasedReaders();
const manifest = readJson('tool/firebase/contract-suites.json');
await run('npx', ['--yes', `firebase-tools@${manifest.firebaseTools}`, 'emulators:exec',
  '--config', 'firebase.security-test.json', '--project', 'demo-cloudboard',
  '--only', 'auth,firestore,database,storage', 'node functions/test/run-contracts.mjs'], {timeoutMs: 30 * 60_000});
