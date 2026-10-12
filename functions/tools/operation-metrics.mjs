import {readFileSync} from 'node:fs';
import {summarizeOperations} from '../src/operation-telemetry.js';
// A Cloud Logging JSON export (array or entries response), never raw customer data.
const input = JSON.parse(readFileSync(process.argv[2] ?? 0, 'utf8'));
console.log(JSON.stringify({format: 1, groups: summarizeOperations(Array.isArray(input) ? input : input.entries ?? [])}, null, 2));
