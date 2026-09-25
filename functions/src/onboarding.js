import {createHmac, randomInt, randomUUID, timingSafeEqual} from 'node:crypto';
import {isDeepStrictEqual} from 'node:util';
import {Timestamp} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';
const fail = (code, message) => new HttpsError(code, message);
// One calendar month in Asia/Seoul, stored as UTC. Clamp missing days at month end.
export function trialEnd(start) {
  const kst = new Date(+start + 9 * 3600000);
  const y = kst.getUTCFullYear(), m = kst.getUTCMonth();
  const day = Math.min(kst.getUTCDate(), new Date(Date.UTC(y, m + 2, 0)).getUTCDate());
  return new Date(Date.UTC(y, m + 1, day, kst.getUTCHours(), kst.getUTCMinutes(), kst.getUTCSeconds(), kst.getUTCMilliseconds()) - 9 * 3600000);
}
export function normalizePhone(value) {
  const raw = typeof value === 'string' ? value.replace(/[\s-]/g, '') : '';
  const phone = raw.startsWith('01') ? '+82' + raw.slice(1) : raw;
  if (!/^\+821[016789]\d{7,8}$/.test(phone)) throw fail('invalid-argument', '휴대폰 번호를 확인해 주세요.');
  return phone;
}
function digest(secret, value) {
  return createHmac('sha256', secret).update(value).digest('hex');
}

const environments = {
  branches:['1','2-3','4+','unknown'], rooms:['1','2','3+','unknown'], classSize:['1-5','6-10','11-20','21+','unknown'],
  coaches:['1','2-5','6+','unknown'], classDuration:['30','45','60','unknown'], displays:['1','2','3+','unknown'],
  displayType:['tv','pc','tablet','unknown'], sound:['tv','speaker','controller','unknown'],
};
export function validateProfile(value, complete=false) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw fail('invalid-argument','센터 정보를 확인해 주세요.');
  const permitted=['purpose','role','centerName','centerTypes','province','district','undecidedName','undecidedRegion','environment','environmentSkipped','classTypes','guidance','priorities','controllers','floorArea'];
  if(Object.keys(value).some(k=>!permitted.includes(k))) throw fail('invalid-argument','지원하지 않는 센터 정보입니다.');
  const p={centerName:'',centerTypes:[],province:'',district:'',undecidedName:false,undecidedRegion:false,environment:{},environmentSkipped:false,classTypes:[],guidance:[],priorities:[],controllers:[],floorArea:'',...value};
  if ((p.purpose!==undefined && !['operating','preparing','exploring'].includes(p.purpose)) ||
      (p.role!==undefined && !['owner','manager','coach','other'].includes(p.role))) throw fail('invalid-argument','선택 정보를 확인해 주세요.');
  for(const [key,limit] of [['centerName',100],['province',30],['district',40],['floorArea',40]]) {
    if(typeof p[key]!=='string' || p[key].length>limit) throw fail('invalid-argument','입력 길이를 확인해 주세요.');
    p[key]=p[key].trim();
  }
  if(!Array.isArray(p.centerTypes)||p.centerTypes.length>5||p.centerTypes.some(v=>!['functional','group','gym','pilates','other'].includes(v)))
    throw fail('invalid-argument','센터 유형을 확인해 주세요.');
  p.centerTypes=[...new Set(p.centerTypes)];
  for(const k of ['undecidedName','undecidedRegion','environmentSkipped']) if(typeof p[k]!=='boolean') throw fail('invalid-argument','입력을 확인해 주세요.');
  if(!p.environment || typeof p.environment!=='object' || Array.isArray(p.environment) ||
    Object.entries(p.environment).some(([k,v])=>!environments[k]?.includes(v))) throw fail('invalid-argument','수업 환경을 확인해 주세요.');
  const multi={classTypes:['pt','group','circuit','open','other'],guidance:['voice','whiteboard','tv','timer','other'],priorities:['instructions','timer','remote','standby'],controllers:['phone','tablet','pc']};
  for(const [key,options] of Object.entries(multi)) {
    if(!Array.isArray(p[key])||p[key].length>(key==='priorities'?2:options.length)||p[key].some(v=>!options.includes(v))) throw fail('invalid-argument','선택 정보를 확인해 주세요.');
    p[key]=[...new Set(p[key])];
  }
  if(complete && (!p.purpose || !p.role || !p.centerTypes.length ||
    (!p.centerName && !(p.purpose!=='operating'&&p.undecidedName)) ||
    ((!p.province||!p.district) && !(p.purpose!=='operating'&&p.undecidedRegion)))) throw fail('invalid-argument','담당자 역할·센터명·유형·지역을 입력해 주세요.');
  return p;
}
function requireAccount(auth) {
  if(!auth?.uid || !['google.com','apple.com'].includes(auth.token?.firebase?.sign_in_provider))
    throw fail('unauthenticated','Apple 또는 Google 계정으로 로그인해 주세요.');
  return auth.uid;
}
const stateRef=(db,uid)=>db.doc(`users/${uid}/onboarding/progress`);
async function assertUnlocked(db,uid) {
  if((await db.doc(`accountDeletions/${uid}`).get()).exists) throw fail('permission-denied','삭제 처리 중인 계정입니다.');
}
export async function sendOnboardingCode(db,uid,rawPhone,secret,send,now=Date.now()) {
  const phone=normalizePhone(rawPhone), code=String(randomInt(100000,1000000));
  const challenge=db.doc(`onboardingPhoneChallenges/${uid}`);
  await db.runTransaction(async tx=>{
    const keys=[db.doc(`onboardingSmsLimits/user_${uid}`),db.doc(`onboardingSmsLimits/phone_${digest(secret,phone)}`)];
    const [lock,old,...limits]=await tx.getAll(db.doc(`accountDeletions/${uid}`),challenge,...keys);
    if(lock.exists) throw fail('permission-denied','사용할 수 없는 계정입니다.');
    if(old.data()?.sentAtMs>now-60000) throw fail('resource-exhausted','1분 뒤에 다시 요청해 주세요.');
    limits.forEach((snapshot,index)=>{
      const data=snapshot.data(), fresh=!data||data.windowAtMs<=now-900000;
      const count=fresh?1:data.count+1;
      if(count>5) throw fail('resource-exhausted','인증 문자는 15분에 5회까지 요청할 수 있습니다.');
      tx.set(keys[index],{count,windowAtMs:fresh?now:data.windowAtMs,expiresAt:Timestamp.fromMillis(now+86400000)});
    });
    tx.set(challenge,{phone,codeHash:digest(secret,uid+':'+phone+':'+code),sentAtMs:now,expiresAtMs:now+300000,attempts:0,verified:false});
  });
  try { await send(phone,code); }
  catch { throw fail('unavailable','문자를 보내지 못했습니다. 1분 뒤에 다시 시도해 주세요.'); }
  return {expiresAtMs:now+300000,resendAtMs:now+60000};
}
export async function verifyOnboardingCode(db,uid,code,secret,now=Date.now()) {
  if(typeof code!=='string'||!/^\d{6}$/.test(code)) throw fail('invalid-argument','인증번호 6자리를 입력해 주세요.');
  const result=await db.runTransaction(async tx=>{
    const challenge=db.doc(`onboardingPhoneChallenges/${uid}`);
    const [lock,snapshot]=await tx.getAll(db.doc(`accountDeletions/${uid}`),challenge);
    if(lock.exists) throw fail('permission-denied','사용할 수 없는 계정입니다.');
    const data=snapshot.data();
    if(!data) return {error:'인증번호를 먼저 요청해 주세요.'};
    if(data.verified) return {phone:data.phone};
    if(data.expiresAtMs<=now||data.attempts>=5||!data.codeHash) return {error:'인증번호가 만료되었습니다. 다시 요청해 주세요.'};
    const hash=digest(secret,uid+':'+data.phone+':'+code);
    if(!timingSafeEqual(Buffer.from(hash),Buffer.from(data.codeHash))) {
      tx.update(challenge,{attempts:data.attempts+1});
      return {error:'인증번호가 일치하지 않습니다.'};
    }
    // Bind phone ownership atomically. A second social account cannot claim it.
    const owner=db.doc(`onboardingPhoneOwners/${digest(secret,data.phone)}`);
    const existing=await tx.get(owner);
    if(existing.exists && existing.data().uid!==uid) return {error:'이 번호로 인증한 계정이 있습니다. 기존 로그인 방식으로 로그인해 주세요.'};
    const progress=stateRef(db,uid), prior=await tx.get(progress);
    const storeId=prior.data()?.storeId || randomUUID();
    const center=db.doc(`centers/${storeId}`);
    // Store creation and membership are server-owned. Reported role is just metadata.
    tx.set(owner,{uid,verifiedAt:Timestamp.fromMillis(now)});
    tx.update(challenge,{verified:true,codeHash:null,verifiedAt:Timestamp.fromMillis(now)});
    if(!prior.exists) {
      tx.create(center,{ownerUid:uid,profile:{},revision:0,createdAt:Timestamp.fromMillis(now),updatedAt:Timestamp.fromMillis(now)});
      tx.create(progress,{storeId,step:0,completed:false,deferred:false,phoneVerified:true,updatedAt:Timestamp.fromMillis(now)});
    } else tx.update(progress,{phoneVerified:true});
    return {phone:data.phone};
  });
  if(result.error) throw fail('invalid-argument',result.error);
  return result.phone;
}
export async function readOnboarding(db,uid,now=Date.now(),realtime) {
  await assertUnlocked(db,uid);
  const progress=(await stateRef(db,uid).get()).data();
  if(!progress?.phoneVerified) return {phoneRequired:true,serverNowMs:now};
  const [center,trial,entitlement]=await Promise.all([db.doc(`centers/${progress.storeId}`).get(),db.doc(`onboardingTrials/${uid}`).get(),db.doc(`subscriptionEntitlements/${uid}`).get()]);
  if(center.data()?.ownerUid!==uid) throw fail('permission-denied','센터 정보를 확인할 수 없습니다.');
  const t=trial.data(), access=entitlement.data();
  const legacy=realtime ? (await realtime.ref(`legacyPilotAccess/${uid}`).get()).val() : null;
  const hasLegacyAccess=legacy?.validUntilMs>now;
  return {phoneRequired:false,storeId:progress.storeId,profile:center.data().profile,revision:center.data().revision,
    step:progress.step,completed:progress.completed,deferred:progress.deferred,status:access?.status??'pending_connection',
    hasAccess:access?.validUntilMs>now || hasLegacyAccess,
    trialEligible:!hasLegacyAccess && !t && (!access?.managed || ['pending_connection','awaiting_web'].includes(access.status)),
    trialStartedAtMs:t?.startedAtMs??0,trialEndsAtMs:t?.endsAtMs??0,serverNowMs:now,suggestedTrialEndsAtMs:+trialEnd(new Date(now))};
}
export async function saveOnboarding(db,uid,input,now=Date.now()) {
  const profile=validateProfile(input.profile,input.action==='complete');
  if(!Number.isInteger(input.revision)||!Number.isInteger(input.step)||input.step<0||input.step>3) throw fail('invalid-argument','진행 상태를 확인해 주세요.');
  await db.runTransaction(async tx=>{
    const progress=stateRef(db,uid);
    const [lock,p]=await tx.getAll(db.doc(`accountDeletions/${uid}`),progress);
    if(lock.exists||!p.data()?.phoneVerified) throw fail('permission-denied','문자 인증을 먼저 완료해 주세요.');
    const center=db.doc(`centers/${p.data().storeId}`), c=await tx.get(center);
    if(c.data()?.ownerUid!==uid) throw fail('permission-denied','센터 정보를 변경할 수 없습니다.');
    if(c.data().revision!==input.revision) {
      if(isDeepStrictEqual(c.data().profile,profile) && p.data().step===input.step &&
        (input.action!=='complete'||p.data().completed) && (input.action!=='defer'||p.data().deferred)) return;
      throw fail('aborted','다른 기기에서 정보가 변경되었습니다. 다시 불러와 주세요.');
    }
    tx.update(center,{profile,revision:input.revision+1,updatedAt:Timestamp.fromMillis(now)});
    tx.update(progress,{step:input.step,completed:input.action==='complete'||p.data().completed,
      deferred:input.action==='defer'||p.data().deferred,updatedAt:Timestamp.fromMillis(now)});
  });
}
export async function startOnboardingTrial(db,realtime,uid,now=Date.now()) {
  // Keep legacy grants unchanged; this is a Firebase-native entitlement issuer.
  const legacy=(await realtime.ref(`legacyPilotAccess/${uid}`).get()).val();
  await db.runTransaction(async tx=>{
    const progress=stateRef(db,uid), trial=db.doc(`onboardingTrials/${uid}`), access=db.doc(`subscriptionEntitlements/${uid}`);
    const [lock,p,t,a]=await tx.getAll(db.doc(`accountDeletions/${uid}`),progress,trial,access);
    if(lock.exists||!p.data()?.phoneVerified) throw fail('permission-denied','문자 인증을 먼저 완료해 주세요.');
    const center=db.doc(`centers/${p.data().storeId}`), c=await tx.get(center);
    if(c.data()?.ownerUid!==uid) throw fail('permission-denied','센터 정보를 확인할 수 없습니다.');
    validateProfile(c.data().profile,true);
    if(t.exists) return; // Idempotent across retries, concurrent devices and reinstalls.
    const previous=a.data();
    if(legacy?.validUntilMs>now || previous?.validUntilMs>now) return;
    // Any historical paid/trial grant is preserved. No automatic retrial.
    if(previous?.managed===true && previous?.status!=='pending_connection' && previous?.status!=='awaiting_web')
      throw fail('failed-precondition','기존 이용 이력이 있습니다. 프로필에서 이용 상태를 확인해 주세요.');
    const startedAtMs=now,endsAtMs=+trialEnd(new Date(now));
    tx.create(trial,{storeId:p.data().storeId,startedAtMs,endsAtMs,policyVersion:'native-trial-1month-v1'});
    tx.set(access,{storeId:p.data().storeId,managed:true,source:'app_trial',status:'trialing',plan:'premium',
      validUntilMs:endsAtMs,revision:(previous?.revision??0)+1,canPrepare:true,canPairDisplay:true,canStartClass:true,
      displaysUnlimited:true,maxActiveDisplays:null,favoritesUnlimited:true,maxFavorites:null,idleScreenCustomization:'custom',
      displayLimit:2147483647,policyVersion:'native-trial-1month-v1',updatedAt:Timestamp.fromMillis(now)});
  });
  if(legacy?.validUntilMs>now) return;
  await syncNativeTrial(db,realtime,uid);
  const [a,r]=await Promise.all([db.doc(`subscriptionEntitlements/${uid}`).get(),realtime.ref(`subscriptionAccess/${uid}`).get()]);
  if(!(a.data()?.validUntilMs>now)||!(r.val()?.validUntilMs>now)) throw fail('failed-precondition','이용 권한을 확인하지 못했습니다. 다시 시도해 주세요.');
}
export async function syncNativeTrial(db,realtime,uid) {
  if((await db.doc(`accountDeletions/${uid}`).get()).exists) return;
  const current=(await db.doc(`subscriptionEntitlements/${uid}`).get()).data();
  if(current?.source!=='app_trial') return;
  const {updatedAt,...wire}=current;
  await realtime.ref(`subscriptionAccess/${uid}`).transaction(old=> {
    if(old && old.source!=='app_trial' && old.validUntilMs>Date.now()) return undefined;
    if(old?.source==='app_trial' && old.revision>wire.revision) return undefined;
    return wire;
  });
}
export async function handleOnboarding({db,realtime,auth,input,secret,send}) {
  const uid=requireAccount(auth),action=input?.action??'load';
  await assertUnlocked(db,uid);
  if(action==='sendCode') return sendOnboardingCode(db,uid,input.phone,secret,send);
  if(action==='verifyCode') await verifyOnboardingCode(db,uid,input.code,secret);
  else if(['save','complete','defer'].includes(action)) await saveOnboarding(db,uid,input);
  else if(action==='startTrial') await startOnboardingTrial(db,realtime,uid);
  else if(action!=='load') throw fail('invalid-argument','지원하지 않는 요청입니다.');
  if(action==='complete') {
    const state=await readOnboarding(db,uid,Date.now(),realtime);
    if(state.profile?.centerName) await realtime.ref(`users/${uid}/operations/brand/storeName`).transaction(value=>value==null?state.profile.centerName:undefined);
  }
  return readOnboarding(db,uid,Date.now(),realtime);
}

export async function deleteOnboardingData(db,uid) {
  for(const collection of ['centers','onboardingPhoneOwners']) {
    const field=collection==='centers'?'ownerUid':'uid';
    for(const document of (await db.collection(collection).where(field,'==',uid).get()).docs) await db.recursiveDelete(document.ref);
  }
  await Promise.all(['onboardingTrials','onboardingPhoneChallenges'].map(collection=>db.doc(`${collection}/${uid}`).delete()));
  await db.doc(`onboardingSmsLimits/user_${uid}`).delete();
  const entitlement=db.doc(`subscriptionEntitlements/${uid}`);
  await db.runTransaction(async tx=>{
    if((await tx.get(entitlement)).data()?.source==='app_trial') tx.delete(entitlement);
  });
}
