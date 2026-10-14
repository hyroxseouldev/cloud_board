import test from 'node:test';
import assert from 'node:assert/strict';
import {options,migrateUsage} from '../scripts/plan-usage-migration.mjs';

test('usage migration defaults read-only, scopes UIDs and requires exact project confirmation',()=>{
  assert.equal(options(['--project','demo-a','--uid','owner','--report','out.json']).apply,false);
  for(const args of [[],['--project','demo-a','--uid','owner','--report','out','--apply'],
    ['--project','demo-a','--uid','owner','--report','out','--apply','--confirm-project','demo-b']]) assert.throws(()=>options(args));
});

test('dry run, apply and guarded rollback never modify workouts, slides or entitlements',async()=>{
  const documents=new Map();
  const db={doc:path=>({path}),collection:path=>({select:()=>({path})}),runTransaction:async run=>run({
    getAll:async(...refs)=>refs.map(ref=>({exists:documents.has(ref.path),data:()=>documents.get(ref.path)})),
    get:async ref=>ref.path.endsWith('/workouts')?{size:9,docs:[]}:
      {size:2,docs:[{data:()=>({value:{id:'kept'}})},{data:()=>({deleted:true,value:null})}]},
    set:(ref,value)=>documents.set(ref.path,value),delete:ref=>documents.delete(ref.path),
  })};
  const config={project:'demo-a',uids:['owner'],apply:false};
  const dry=await migrateUsage(db,config);
  assert.equal(documents.size,0);
  assert.deepEqual([dry.accounts[0].after.workoutCount,dry.accounts[0].after.savedSlideCount],[9,1]);
  const applied=await migrateUsage(db,{...config,apply:true});
  assert.equal(documents.size,2, 'atomic durable backup plus projection');
  assert.equal((await migrateUsage(db,config,applied)).accounts[0].status,'rolled-back');
  assert.equal(documents.has('users/owner/planUsage/current'),false);
  const changed=await migrateUsage(db,{...config,apply:true});
  documents.set('users/owner/planUsage/current',{workoutCount:10,savedSlideCount:1});
  assert.equal((await migrateUsage(db,config,changed)).accounts[0].status,'changed-since-apply');
  assert.equal(documents.get('users/owner/planUsage/current').workoutCount,10);
  await assert.rejects(migrateUsage(db,{...config,project:'production'},changed));
});
