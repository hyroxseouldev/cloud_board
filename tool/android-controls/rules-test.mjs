import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { ref, set, get } from 'firebase/database';
import fs from 'node:fs';
const env = await initializeTestEnvironment({projectId:'demo-cloudboard', database:{host:'127.0.0.1',port:19000,rules:fs.readFileSync(new URL('../../database.rules.json', import.meta.url),'utf8')}});
const owner = env.authenticatedContext('owner',{firebase:{sign_in_provider:'password'}}).database();
const other = env.authenticatedContext('other',{firebase:{sign_in_provider:'password'}}).database();
const path = 'users/owner/activeSession';
const base = {id:'s',ownerId:'owner',zoneId:'main',workoutSnapshot:{name:'test'},status:'playing',stepIndex:0,remainingMs:1000,anchorServerMs:Date.now(),revision:1,updatedByDeviceId:'phone'};
try {
 await env.clearDatabase();
 await assertSucceeds(set(ref(owner,path),base));
 await assertFails(set(ref(other,path),base));
 await assertFails(set(ref(owner,path),{...base,notificationCommand:{id:'expired',expiresAtMs:Date.now()-10000}}));
 await assertFails(set(ref(owner,path),{...base,notificationCommand:{id:'far-future',expiresAtMs:Date.now()+60000}}));
 const current={...base,notificationCommand:{id:'valid',expiresAtMs:Date.now()+5000}};
 await assertSucceeds(set(ref(owner,path),current));
 await assertSucceeds(set(ref(owner,path),{...current,status:'paused',revision:2}));
 await assertFails(set(ref(owner,path),{...current,notificationCommand:{id:'retry-expired',expiresAtMs:Date.now()-1000}}));
 // REST conditional write used by the native receiver: stale ETag cannot overwrite completion.
 const url='http://127.0.0.1:19000/'+path+'.json?ns=demo-cloudboard';
 const first=await fetch(url,{headers:{Authorization:'Bearer owner','X-Firebase-ETag':'true'}});
 const tag=first.headers.get('etag');
 if (!tag) throw Error('Missing ETag');
 await assertSucceeds(set(ref(owner,path),{...current,status:'completed',revision:3}));
 const conflict=await fetch(url,{method:'PUT',headers:{Authorization:'Bearer owner','if-match':tag,'Content-Type':'application/json'},body:JSON.stringify(current)});
 if(conflict.status!==412) throw Error('Expected 412, got '+conflict.status);
 if((await get(ref(owner,path))).val().status!=='completed') throw Error('Resurrected session');
 console.log('PASS: owner isolation, valid/expired deadlines, legacy writes, stale ETag and completed-session preservation');
} finally { await env.cleanup(); }
