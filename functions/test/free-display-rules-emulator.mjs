import assert from 'node:assert/strict';
import fs from 'node:fs';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {ref, set, update} from 'firebase/database';
assert.match(process.env.FIREBASE_DATABASE_EMULATOR_HOST ?? '', /^(127\.0\.0\.1|localhost):\d+$/);
const [host, port] = process.env.FIREBASE_DATABASE_EMULATOR_HOST.split(':');
const env = await initializeTestEnvironment({projectId:'demo-cloudboard-free-displays', database:{host, port:Number(port), rules:fs.readFileSync('database.rules.json','utf8')}});
const session = (id, targets) => ({id, ownerId:'owner', zoneId:'main', status:'playing', stepIndex:0,
  remainingMs:60000, anchorServerMs:Date.now(), revision:1, updatedByDeviceId:'phone',
  workoutSnapshot:{id:'workout',name:'Test'}, targetDeviceIds:targets});
const current = env.authenticatedContext('owner').database();
async function seed(plan, maxActiveDisplays) {
  await env.withSecurityRulesDisabled(async ctx => {
    const db=ctx.database();
    await set(ref(db), {});
    await set(ref(db,'subscriptionAccess/owner'), {managed:true,plan,maxActiveDisplays,
      displaysUnlimited:false,canStartClass:true,validUntilMs:Date.now()+3600000});
    for (const id of ['a','b','c','d']) {
      await set(ref(db,`users/owner/devices/${id}`), {id,mode:'display',online:true,lastSeenAtMs:Date.now(),paired:true,displayUid:`tv-${id}`,displayState:'auto'});
      await set(ref(db,`displayAccess/tv-${id}`), {ownerId:'owner',deviceId:id});
    }
  });
}
try {
  await seed('free',1);
  await assertSucceeds(set(ref(current,'users/owner/activeSession'),session('one',['a'])));
  await assertFails(set(ref(current,'users/owner/activeSession'),session('two',['a','b'])));
  await assertFails(update(ref(current,'users/owner/devices/a'),{displayState:'black'}));
  await seed('plus',3);
  await assertSucceeds(set(ref(current,'users/owner/activeSession'),session('three',['a','b','c'])));
  await assertFails(set(ref(current,'users/owner/activeSession'),session('four',['a','b','c','d'])));
  await env.withSecurityRulesDisabled(async ctx => {
    await update(ref(ctx.database(),'subscriptionAccess/owner'),{plan:'free',maxActiveDisplays:1});
  });
  await assertSucceeds(update(ref(current,'users/owner/activeSession'),{status:'paused',revision:2}));
  await assertFails(set(ref(current,'users/owner/activeSession'),session('after-downgrade',['a','b'])));
  await assertSucceeds(set(ref(current,'users/owner/activeSession'),session('next',['a'])));
  await seed('plus',1); // Historical server projection keeps its own explicit cap.
  await assertFails(set(ref(current,'users/owner/activeSession'),session('old-plus',['a','b'])));
  console.log('PASS display rules: Free1, Plus3, fourth rejection, server-only activation, ongoing-class downgrade protection');
} finally {await env.cleanup();}
