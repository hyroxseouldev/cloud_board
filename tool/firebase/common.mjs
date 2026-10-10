import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync, writeFileSync, mkdirSync, readdirSync} from 'node:fs';
import {dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawn} from 'node:child_process';

export const root = fileURLToPath(new URL('../../', import.meta.url));
export const readJson = path => JSON.parse(readFileSync(resolve(root, path), 'utf8'));
export const hash = bytes => createHash('sha256').update(bytes).digest('hex');
export const hashFile = path => hash(readFileSync(resolve(root, path)));
export const canonical = value => JSON.stringify(value, (_, v) => v && typeof v === 'object' && !Array.isArray(v)
  ? Object.fromEntries(Object.keys(v).sort().map(k => [k, v[k]])) : v);
export function writeJson(path, data) {
  const target = resolve(root, path);
  mkdirSync(dirname(target), {recursive: true});
  writeFileSync(target, `${JSON.stringify(data, null, 2)}\n`);
}
export function filesIn(path) {
  path = path.replace(/\/$/, '');
  return readdirSync(resolve(root, path), {withFileTypes: true}).flatMap(e => {
    assert(!e.isSymbolicLink(), `Symlink not allowed: ${path}/${e.name}`);
    return e.isDirectory() ? filesIn(`${path}/${e.name}`) : [`${path}/${e.name}`];
  }).sort();
}
export function emulatorAddress(value) {
  assert.match(value || '', /^(127\.0\.0\.1|localhost):[0-9]+$/, 'Local emulator required');
  const [host, port] = value.split(':');
  assert(Number(port) > 0 && Number(port) < 65536);
  return {host, port: Number(port)};
}
export function requireDemo(project) {
  assert.match(project || '', /^demo-[a-z0-9-]+$/, 'Demo project required');
  return project;
}
export async function run(command, args, {env = process.env, timeoutMs = 240_000, log} = {}) {
  return new Promise((resolvePromise, reject) => {
    const child = spawn(command, args, {cwd: root, env, detached: process.platform !== 'win32', stdio: ['ignore', log ? 'pipe' : 'inherit', log ? 'pipe' : 'inherit']});
    let timedOut = false;
    const kill = () => {
      try { process.platform === 'win32' ? child.kill('SIGKILL') : process.kill(-child.pid, 'SIGKILL'); } catch { /* already exited */ }
    };
    const timer = setTimeout(() => { timedOut = true; kill(); }, timeoutMs);
    child.stdout?.on('data', bytes => log.write(bytes));
    child.stderr?.on('data', bytes => log.write(bytes));
    child.once('error', e => {clearTimeout(timer); reject(e);});
    child.once('close', (code, signal) => {
      clearTimeout(timer);
      if (timedOut || code !== 0) reject(new Error(timedOut ? 'Suite timed out' : `Process failed (${code ?? signal})`));
      else resolvePromise();
    });
  });
}
export async function jsonRequest(url, options = {}) {
  const response = await fetch(url, {...options, signal: AbortSignal.timeout(30_000)});
  if (!response.ok) throw new Error(`Request failed (${response.status})`);
  return response.json();
}
