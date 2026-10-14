import assert from 'node:assert/strict';
import { test } from 'node:test';
import type { Database } from 'firebase-admin/database';
import { activateDisplay } from '../src/services/display-activation.js';

const current = {
  devices: {
    a: { paired: true, displayState: 'auto' },
    b: { paired: true, displayState: 'black' },
  },
};

function transactionFixture(value: unknown) {
  let completed = false;
  let output: any;
  const database = {
    ref(path: string) {
      if (path.startsWith('accountDeletions/'))
        return { get: async () => ({ exists: () => false }) };
      if (path.startsWith('subscriptionAccess/'))
        return {
          get: async () => ({
            val: () => ({
              managed: true,
              plan: 'free',
              maxActiveDisplays: 1,
              displaysUnlimited: false,
              canStartClass: true,
              validUntilMs: Date.now() + 60_000,
            }),
          }),
        };
      return {
        async transaction(update: (value: unknown) => unknown) {
          // The first pass can be a cold cache; the retry callback must return
          // an abort value, not throw past the SDK's completion/cleanup path.
          assert.equal(update(null), null);
          assert.doesNotThrow(() => {
            output = update(value);
          });
          await Promise.resolve();
          completed = true;
          return { committed: output !== undefined, snapshot: { exists: () => output != null } };
        },
      };
    },
  } as unknown as Database;
  return { database, completed: () => completed, output: () => output };
}

for (const [code, value, replaceDeviceIds] of [
  ['resource-exhausted', current, []],
  ['aborted', current, ['missing']],
  [
    'failed-precondition',
    {
      ...current,
      activeSession: {
        status: 'paused',
        targetDeviceIds: ['a', 'unselected'],
        revision: 1,
      },
    },
    ['a'],
  ],
] as const) {
  test(`${code} policy rejection finishes RTDB abort before reaching caller`, async () => {
    const fixture = transactionFixture(value);
    await assert.rejects(
      () =>
        activateDisplay(fixture.database, 'coach', {
          deviceId: 'b',
          displayState: 'auto',
          replaceDeviceIds,
        }),
      { code },
    );
    assert.equal(fixture.output(), undefined);
    assert.equal(fixture.completed(), true);
  });
}

test('cold-cache retry still commits a valid explicit replacement', async () => {
  const fixture = transactionFixture(current);
  assert.deepEqual(
    await activateDisplay(fixture.database, 'coach', {
      deviceId: 'b',
      displayState: 'auto',
      replaceDeviceIds: ['a'],
    }),
    { changed: true },
  );
  assert.equal(fixture.output().devices.a.displayState, 'black');
  assert.equal(fixture.output().devices.b.displayState, 'auto');
  assert.equal(current.devices.a.displayState, 'auto');
});
