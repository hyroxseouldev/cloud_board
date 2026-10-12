#!/usr/bin/env node
import {pathToFileURL} from 'node:url';
import {developmentProject, developmentDeployTargets} from '../src/development-backend-config.js';

export function parseDevelopmentAction(args) {
  const [action, ...options] = args;
  const allowed = ['deploy-targets', 'grant-tester', 'revoke-tester', 'read-code'];
  if (!allowed.includes(action) || options.length % 2) throw new Error('Invalid development onboarding command');
  const values = {};
  for (let i = 0; i < options.length; i += 2) {
    const key = options[i];
    if (!['--project', '--uid'].includes(key) || key in values) throw new Error('Invalid or duplicate option');
    values[key] = options[i + 1];
  }
  if (values['--project'] !== developmentProject) throw new Error('Explicit --project cloud-board-development required');
  const uid = values['--uid'];
  if (action !== 'deploy-targets' && (typeof uid !== 'string' || !uid || uid.length > 128 || /[\x00-\x1f\/]/.test(uid))) {
    throw new Error('Explicit valid --uid required');
  }
  return {action, uid, projectId: developmentProject};
}

export async function runDevelopmentAction({action, uid, projectId}, {auth, db, now = Date.now()}) {
  if (projectId !== developmentProject) throw new Error('Development project required');
  if (action === 'grant-tester' || action === 'revoke-tester') {
    const user = await auth.getUser(uid); // Never create an account implicitly.
    const claims = {...user.customClaims};
    if (action === 'grant-tester') claims.developmentTester = true;
    else delete claims.developmentTester;
    await auth.setCustomUserClaims(uid, claims);
    if (action === 'revoke-tester') {
      await auth.revokeRefreshTokens(uid);
      await db.doc(`developmentSmsOutbox/${uid}`).delete();
    }
    return {status: action === 'grant-tester' ? 'tester-granted' : 'tester-revoked', refreshLogin: true};
  }
  if (action !== 'read-code') throw new Error('Invalid development onboarding command');
  const user = await auth.getUser(uid);
  if (user.customClaims?.developmentTester !== true) throw new Error('Development tester required');
  const value = (await db.doc(`developmentSmsOutbox/${uid}`).get()).data();
  const expiresAt = value?.expiresAt?.toMillis();
  if (!Number.isFinite(expiresAt) || expiresAt <= now || !/^\d{6}$/.test(value?.code)) throw new Error('No unexpired development code');
  return {code: value.code, expiresAt: value.expiresAt.toDate().toISOString()};
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const command = parseDevelopmentAction(process.argv.slice(2));
  if (command.action === 'deploy-targets') console.log(developmentDeployTargets(command.projectId));
  else {
    const {initializeApp} = await import('firebase-admin/app');
    const {getAuth} = await import('firebase-admin/auth');
    const {getFirestore} = await import('firebase-admin/firestore');
    const app = initializeApp({projectId: command.projectId});
    const db = getFirestore(app);
    try {
      console.log(JSON.stringify(await runDevelopmentAction(command, {auth: getAuth(app), db})));
    } finally { await db.terminate(); }
  }
}
