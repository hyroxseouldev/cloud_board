import fs from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import {randomUUID} from 'node:crypto';
import {isDeepStrictEqual} from 'node:util';
import {initializeApp,deleteApp} from 'firebase-admin/app';
import {getFirestore,Timestamp} from 'firebase-admin/firestore';
import {readPlanUsage,planUsageRef} from '../src/plan-usage.js';
import {planPolicyVersion} from '../src/plan-policy.js';

export function options(args) {
  const result={uids:[],apply:false};
  for(let i=0;i<args.length;i++) {
    const key=args[i];
    if(key==='--apply') result.apply=true;
    else if(key==='--uid') result.uids.push(args[++i]);
    else if(['--project','--report','--rollback','--confirm-project'].includes(key)) result[key.slice(2)]=args[++i];
    else throw Error(`Unsupported option: ${key}`);
  }
  if(!result.project || !result.report || (!result.rollback && !result.uids.length)) throw Error('Use --project PROJECT --uid UID [--uid UID] --report FILE; dry-run is default. --apply requires --confirm-project PROJECT. Rollback: --rollback REPORT --report RESULT.');
  if(result.apply && result.rollback) throw Error('Choose apply or rollback');
  if((result.apply || result.rollback) && result['confirm-project']!==result.project) throw Error('Mutations require matching --confirm-project');
  if(result.uids.some(uid=>typeof uid!=='string'||!uid||uid.includes('/'))) throw Error('Invalid UID');
  result.uids=[...new Set(result.uids)];
  return result;
}
export const encode=value=>value instanceof Timestamp ? {__timestampMillis:value.toMillis()} :
  Array.isArray(value)?value.map(encode):value && typeof value==='object'?
    Object.fromEntries(Object.entries(value).map(([k,v])=>[k,encode(v)])):value;
const decode=value=>value && typeof value==='object' && Object.keys(value).length===1 && Number.isSafeInteger(value.__timestampMillis)?Timestamp.fromMillis(value.__timestampMillis):
  Array.isArray(value)?value.map(decode):value && typeof value==='object'?
    Object.fromEntries(Object.entries(value).map(([k,v])=>[k,decode(v)])):value;

export async function migrateUsage(db,config,backup) {
  if(backup && (backup.project!==config.project || backup.mode!=='apply')) throw Error('Rollback requires an applied report from this project');
  const report={format:1,project:config.project,mode:backup?'rollback':config.apply?'apply':'dry-run',runId:config.runId ?? randomUUID(),accounts:[]};
  for(const uid of backup?backup.accounts.map(row=>row.uid):config.uids) {
    const prior=backup?.accounts.find(row=>row.uid===uid);
    const row=await db.runTransaction(async tx=>{
      const ref=planUsageRef(db,uid);
      const [lock,current]=await tx.getAll(db.doc(`accountDeletions/${uid}`),ref);
      if(lock.exists) return {uid,status:'deletion-locked'};
      const before=current.exists?encode(current.data()):null;
      if(backup) {
        if(prior.status!=='applied') return {uid,status:'not-applied'};
        if(!isDeepStrictEqual(before,prior.after)) return {uid,status:'changed-since-apply'};
        if(prior.before===null) tx.delete(ref); else tx.set(ref,decode(prior.before));
        return {uid,status:'rolled-back'};
      }
      const counts=await readPlanUsage(tx,db,uid);
      const after={policyVersion:planPolicyVersion,workoutCount:counts.workoutCount,
        savedSlideCount:counts.savedSlideCount,updatedAt:Timestamp.now(),migrationRunId:report.runId};
      if(config.apply) {
        // Durable backup is atomic with the projection update. A process crash
        // before writing the local report cannot lose rollback information.
        tx.set(db.doc(`users/${uid}/planUsageBackups/${report.runId}`),
          {uid,project:config.project,runId:report.runId,before,after:encode(after)});
        tx.set(ref,after);
      }
      return {uid,status:config.apply?'applied':'preview',before,after:encode(after)};
    });
    report.accounts.push(row);
  }
  return report;
}

async function main(){
  const config=options(process.argv.slice(2));
  config.runId=randomUUID();
  // Reserve the output path before touching Firestore; never overwrite an old
  // rollback artifact after mutation has already happened.
  const output=await fs.open(config.report,'wx',0o600);
  const app=initializeApp({projectId:config.project});
  const db=getFirestore(app);
  try {
    const backup=config.rollback?JSON.parse(await fs.readFile(config.rollback,'utf8')):null;
    console.log(`runId ${config.runId}`);
    const report=await migrateUsage(db,config,backup);
    await output.writeFile(JSON.stringify(report,null,2)+'\n');
    console.log(`${report.mode}: ${report.accounts.length} accounts; report ${config.report}`);
  }finally{await output.close();await db.terminate();await deleteApp(app);}
}
if(process.argv[1] && import.meta.url===pathToFileURL(process.argv[1]).href) await main();
