import assert from 'node:assert/strict';
// This test can only run against a local demo project. Never remove these guards.
for(const name of ['FIREBASE_AUTH_EMULATOR_HOST','FIRESTORE_EMULATOR_HOST','FIREBASE_DATABASE_EMULATOR_HOST','FIREBASE_STORAGE_EMULATOR_HOST']) {
 assert.match(process.env[name]||'',/^(127\.0\.0\.1|localhost):\d+$/);
}
assert.match(process.env.GCLOUD_PROJECT||'',/^demo-/);
const {deleteMyAccount}=await import('../src/index.js');
const {getAuth}=await import('firebase-admin/auth');
const {getFirestore}=await import('firebase-admin/firestore');
const {getDatabase}=await import('firebase-admin/database');
const {getStorage}=await import('firebase-admin/storage');
const auth=getAuth(),db=getFirestore(),rtdb=getDatabase(),bucket=getStorage().bucket();
const encode=value=>Buffer.from(JSON.stringify(value)).toString('base64url');
const token=`${encode({alg:'none',typ:'JWT'})}.${encode({sub:'deletion-test-google',email:'delete-test@example.invalid',email_verified:true,name:'Emulator only',iss:'https://accounts.google.com',aud:'demo-client'})}.`;
const response=await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=demo-key`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({postBody:`id_token=${token}&providerId=google.com`,requestUri:'http://localhost',returnSecureToken:true})});
const login=await response.json();assert.ok(login.idToken,JSON.stringify(login));
const decoded=await auth.verifyIdToken(login.idToken);const uid=decoded.uid;
await auth.createUser({uid:'other-account'});
await db.doc(`users/${uid}`).set({uid});
await db.doc(`users/${uid}/workouts/workout/nested/item`).set({private:true});
await db.doc('users/other-account').set({keep:true});
await bucket.file(`users/${uid}/profile/image.png`).save('private-test-image');
await bucket.file('users/other-account/profile/image.png').save('keep');
await rtdb.ref().update({[`users/${uid}`]:{activeSession:{id:'s',status:'playing',revision:1},operations:{brand:{name:'test'}}},[`displayAccess/display-test`]:{ownerId:uid},[`pairingCodes/123456`]:{ownerId:uid},'users/other-account':{keep:true},'displayAccess/other-display':{ownerId:'other-account'}});
const result=await deleteMyAccount.run({auth:{uid,token:decoded},data:{confirm:true,uid:'other-account'},rawRequest:{headers:{authorization:`Bearer ${login.idToken}`}}});
assert.equal(result.status,'completed');
await assert.rejects(auth.getUser(uid),error=>error.code==='auth/user-not-found');
assert.equal((await db.doc(`users/${uid}/workouts/workout/nested/item`).get()).exists,false);
assert.equal((await rtdb.ref(`users/${uid}`).get()).exists(),false);
assert.equal((await rtdb.ref('displayAccess/display-test').get()).exists(),false);
assert.equal((await rtdb.ref('pairingCodes/123456').get()).exists(),false);
assert.equal((await bucket.file(`users/${uid}/profile/image.png`).exists())[0],false);
assert.equal((await db.doc('users/other-account').get()).data().keep,true);
assert.equal((await bucket.file('users/other-account/profile/image.png').exists())[0],true);
assert.equal((await rtdb.ref('users/other-account/keep').get()).val(),true);
assert.equal((await rtdb.ref('displayAccess/other-display/ownerId').get()).val(),'other-account');
assert.equal((await db.doc(`accountDeletions/${uid}`).get()).data().status,'completed');
const {initializeTestEnvironment,assertFails,assertSucceeds}=await import('@firebase/rules-unit-testing');
const {doc,setDoc}=await import('firebase/firestore');
const {ref:databaseRef,set}=await import('firebase/database');
const {ref:storageRef,uploadBytes}=await import('firebase/storage');
const fs=await import('node:fs');
const env=await initializeTestEnvironment({projectId:process.env.GCLOUD_PROJECT,
 firestore:{host:'127.0.0.1',port:19080,rules:fs.readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8')},
 database:{host:'127.0.0.1',port:19000,rules:fs.readFileSync(new URL('../../database.rules.json',import.meta.url),'utf8')},
 storage:{host:'127.0.0.1',port:19199,rules:fs.readFileSync(new URL('../../storage.rules',import.meta.url),'utf8')},
});
const locked=env.authenticatedContext(uid),other=env.authenticatedContext('other-account');
await assertFails(setDoc(doc(locked.firestore(),`users/${uid}`),{uid}));
await assertSucceeds(setDoc(doc(other.firestore(),'users/other-account'),{uid:'other-account',keep:true}));
// Admin initialized the RTDB instance with the project's default-rtdb namespace.
const instance=`https://${process.env.GCLOUD_PROJECT}-default-rtdb.asia-southeast1.firebasedatabase.app`;
await assertFails(set(databaseRef(locked.database(instance),`users/${uid}/operations/brand`),{name:'must-not-recreate'}));
await assertSucceeds(set(databaseRef(other.database(instance),'users/other-account/operations/brand'),{name:'keep'}));
const bucketUrl=`gs://${process.env.GCLOUD_PROJECT}.firebasestorage.app`;
await assertFails(uploadBytes(storageRef(locked.storage(bucketUrl),`users/${uid}/profile/forbidden.png`),new Uint8Array([1]),{contentType:'image/png'}));
await assertSucceeds(uploadBytes(storageRef(other.storage(bucketUrl),'users/other-account/profile/allowed.png'),new Uint8Array([1]),{contentType:'image/png'}));
await env.cleanup();
console.log('PASS: lock rules deny stale-token writes to Firestore, RTDB and Storage; other accounts still work.');
console.log('PASS: real emulator Auth/Firestore recursive/Storage/RTDB cleanup; other account preserved; caller UID ignored.');
process.exit(0);
