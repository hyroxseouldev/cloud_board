import {test} from 'node:test';
import assert from 'node:assert/strict';
import {randomBytes} from 'node:crypto';
import {seal, open} from './web_symbols.mjs';

test('source maps round-trip with randomized encryption and no plaintext', () => {
  const key = randomBytes(32).toString('hex');
  const data = Buffer.from('private source map and deployment version');
  const a = seal(data, key);
  const b = seal(data, key);
  assert.deepEqual(open(a, key), data);
  assert.notDeepEqual(a, b);
  assert.equal(a.includes(data), false);
});

test('wrong key, tampering and truncated files cannot be decrypted', () => {
  const key = randomBytes(32).toString('hex');
  const data = seal(Buffer.from('source map'), key);
  assert.throws(() => open(data, randomBytes(32).toString('hex')));
  for (const index of [0, 15, 25, data.length - 1]) {
    const changed = Buffer.from(data);
    changed[index] ^= 1;
    assert.throws(() => open(changed, key));
  }
  assert.throws(() => open(data.subarray(0, 12), key));
  assert.throws(() => seal(data, ''));
});
