import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {setTimeout as delay} from 'node:timers/promises';
const project='demo-cloudboard-monitoring';
if (process.env.GCLOUD_PROJECT !== project || process.env.FIREBASE_DATABASE_EMULATOR_HOST !== '127.0.0.1:19400') throw new Error('Demo emulator only');
const received=[];
const server=createServer(async(req,res)=>{
 let body='';for await(const chunk of req) body+=chunk;
 assert.equal(req.headers.authorization,'Bearer local-demo-webhook-key');
 const payload=JSON.parse(body);assert.deepEqual(Object.keys(payload).sort(),['event_id','message','status','title']);received.push(payload);
 res.writeHead(202,{'Content-Type':'application/json'});res.end('{"accepted":true}');
});
await new Promise(resolve=>server.listen(19404,'127.0.0.1',resolve));
const base=`http://127.0.0.1:19400/users/sta191-demo.json?ns=${project}-default-rtdb`;
const kinds=['playback_started','playback_completed','command_failed','command_receipt_failed','playback_interrupted','playback_restored','connection_failed','connection_recovered','device_online','device_offline','device_shutdown'];
const fixture={operations:{devices:{display1:{enabled:true}},session:{state:'playing'},events:Object.fromEntries(kinds.map((type,i)=>['event'+i,{type,occurredAtMs:Date.now(),sessionId:'local-session',workoutName:'로컬 검증 수업',deviceRole:'display'}]).concat([['ignored',{type:'unrelated'}]]))}};
try {
 const write=await fetch(base,{method:'PUT',headers:{Authorization:'Bearer owner','Content-Type':'application/json'},body:JSON.stringify(fixture)});assert.equal(write.status,200);
 const deadline=Date.now()+45000;
 while(received.length<kinds.length&&Date.now()<deadline)await delay(200);
 assert.equal(received.length,kinds.length,'Every supported create must reach the local receiver');
 assert.equal(new Set(received.map(x=>x.event_id)).size,kinds.length);
 assert.deepEqual(Object.fromEntries(['success','failure','info'].map(status=>[status,received.filter(x=>x.status===status).length])),{success:3,failure:4,info:4});
 const after=await(await fetch(base,{headers:{Authorization:'Bearer owner'}})).json();assert.deepEqual(after,fixture,'The sender must not modify source/device/session data');
 const overwrite=await fetch(base,{method:'PUT',headers:{Authorization:'Bearer owner','Content-Type':'application/json'},body:JSON.stringify(fixture)});assert.equal(overwrite.status,200);
 await delay(1000);assert.equal(received.length,kinds.length,'Unchanged historical events are not forwarded again');
 console.log(JSON.stringify({result:'passed',forwarded:received.length,sourceUnchanged:true,unrelatedFiltered:true,noBackfill:true}));
} finally {await new Promise(resolve=>server.close(resolve));}
