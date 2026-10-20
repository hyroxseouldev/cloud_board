import test from 'node:test';
import assert from 'node:assert/strict';
import {assertLocalRasterEnvironment,localRasterFixture} from '../tools/prepare-ai-raster-fixture.mjs';
test('fixture rejects omitted, external, wrong-project and unpinned emulator configuration before SDK initialization',()=>{
  const env={GCLOUD_PROJECT:localRasterFixture.projectId,FIREBASE_AUTH_EMULATOR_HOST:localRasterFixture.auth,
    FIRESTORE_EMULATOR_HOST:localRasterFixture.firestore,FIREBASE_DATABASE_EMULATOR_HOST:localRasterFixture.database,
    FIREBASE_STORAGE_EMULATOR_HOST:localRasterFixture.storage};
  assert.doesNotThrow(()=>assertLocalRasterEnvironment(env));
  for(const [key,value] of Object.entries(env)) {
    assert.throws(()=>assertLocalRasterEnvironment({...env,[key]:undefined}));
    assert.throws(()=>assertLocalRasterEnvironment({...env,[key]:key==='GCLOUD_PROJECT'?'cloud-board-development':'external.example:443'}));
    if(key!=='GCLOUD_PROJECT') assert.throws(()=>assertLocalRasterEnvironment({...env,[key]:value.replace('194','190')}));
  }
  assert.throws(()=>assertLocalRasterEnvironment({...env,GOOGLE_APPLICATION_CREDENTIALS:'/not-loaded.json'}));
});
