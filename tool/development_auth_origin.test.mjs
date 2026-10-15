import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = readFileSync(new URL('../web/development_auth_origin.js', import.meta.url), 'utf8');
function navigate(href) {
  const destinations = [];
  vm.runInNewContext(source, {URL, window: {location: {href, replace: value => destinations.push(value)}}});
  return destinations;
}

test('development login and deep links use the auth origin without losing state', () => {
  assert.deepEqual(navigate('https://cloud-board-development.web.app/?source=demo#/login?returnTo=%2Fworkouts'),
    ['https://cloud-board-development.firebaseapp.com/?source=demo#/login?returnTo=%2Fworkouts']);
});

test('canonical development, production, localhost and unrelated domains do not redirect', () => {
  for (const origin of ['https://cloud-board-development.firebaseapp.com',
    'https://cloud-board-stationd.web.app', 'http://localhost:8767',
    'https://cloud-board-development.web.app.example.com']) {
    assert.deepEqual(navigate(`${origin}/#/login`), []);
  }
});
