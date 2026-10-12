import assert from 'node:assert/strict';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {mkdtempSync, mkdirSync, copyFileSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {resolve, join} from 'node:path';
import {pathToFileURL} from 'node:url';
import {root, readJson, hashFile, writeJson} from './common.mjs';

const exec = promisify(execFile);
const harness = 'tool/firebase/released_reader_contract_test.dart';
const policyFile = 'tool/firebase/compatibility-policy.json';

export function readerPlans(registry, policy) {
  assert.equal(policy.format, 1);
  const sources = [...new Set(registry.clients.map(client => client.sourceCommit))];
  for (const source of Object.keys(policy.nonSemanticFieldsBySource)) assert(sources.includes(source), `Unknown exception source: ${source}`);
  return sources.map(sourceCommit => {
    assert.match(sourceCommit, /^[a-f0-9]{40}$/);
    const exceptions = policy.nonSemanticFieldsBySource[sourceCommit] || [];
    for (const exception of exceptions) {
      assert.match(exception.path, /^(workout|summary|preferences|playback)\/[a-zA-Z0-9_/*]+$/);
      assert(exception.reason?.length >= 30, 'A non-semantic omission needs an explicit compatibility reason');
      assert(!exception.path.endsWith('/*'), 'Entire objects cannot be exempted');
    }
    return {sourceCommit, clients: registry.clients.filter(c => c.sourceCommit === sourceCommit).map(c => c.client), exceptions};
  });
}

export async function verifyReleasedReaders() {
  const report = {format: 1, status: 'running', harnessSha256: hashFile(harness), policySha256: hashFile(policyFile),
    candidateFiles: Object.fromEntries(['build/contracts/workout-save-current.json', 'build/contracts/app-current.json'].map(file => [file, hashFile(file)])), sources: []};
  const output = resolve(root, 'build/contracts/released-readers');
  mkdirSync(output, {recursive: true});
  try {
    for (const plan of readerPlans(readJson('tool/firebase/supported-clients.json'), readJson(policyFile))) {
      const temporary = mkdtempSync(join(tmpdir(), 'cloudboard-released-reader-'));
      const checkout = join(temporary, 'source');
      let registered = false;
      let log = '';
      const command = async (file, args, cwd = checkout, timeout = 180_000) => {
        try {
          const {stdout, stderr} = await exec(file, args, {cwd, timeout, maxBuffer: 8 * 1024 * 1024});
          log += stdout + stderr;
          return stdout;
        } catch (error) {
          log += (error.stdout || '') + (error.stderr || '') + String(error);
          throw error;
        }
      };
      const started = Date.now();
      try {
        await command('git', ['worktree', 'add', '--detach', checkout, plan.sourceCommit], root);
        registered = true;
        assert.equal((await command('git', ['rev-parse', 'HEAD'])).trim(), plan.sourceCommit);
        // These are the original released sources and dependency lockfile. Only
        // the external harness is injected; candidate lib/ code is never copied.
        await command(process.env.FLUTTER_BIN || 'flutter', ['pub', 'get', '--enforce-lockfile']);
        const relativeHarness = 'test/installed_client_compatibility_test.dart';
        copyFileSync(resolve(root, harness), join(checkout, relativeHarness));
        const exceptionFile = join(temporary, 'exceptions.json');
        writeFileSync(exceptionFile, JSON.stringify(plan.exceptions));
        await command(process.env.FLUTTER_BIN || 'flutter', ['test', '--no-pub', '--reporter', 'expanded',
          `--dart-define=CANDIDATE_CONTRACTS=${resolve(root, 'build/contracts')}`,
          `--dart-define=COMPATIBILITY_EXCEPTIONS=${exceptionFile}`, relativeHarness]);
        report.sources.push({...plan, status: 'success', durationMs: Date.now() - started});
        console.log(`PASS released reader/serializer ${plan.sourceCommit.slice(0, 12)} (${plan.clients.join(', ')})`);
      } catch (error) {
        report.sources.push({...plan, status: 'failure', durationMs: Date.now() - started});
        throw new Error(`Released reader/serializer failed: ${plan.sourceCommit}; see build/contracts/released-readers/${plan.sourceCommit}.log`, {cause: error});
      } finally {
        writeFileSync(join(output, `${plan.sourceCommit}.log`), log);
        if (registered) await exec('git', ['worktree', 'remove', '--force', checkout], {cwd: root});
        rmSync(temporary, {recursive: true, force: true});
      }
    }
    report.status = 'success';
  } catch (error) {
    report.status = 'failure';
    throw error;
  } finally {
    writeJson('build/contracts/released-readers/report.json', report);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) await verifyReleasedReaders();
