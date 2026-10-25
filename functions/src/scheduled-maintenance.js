import {Timestamp} from 'firebase-admin/firestore';
import {prunePlaybackSnapshots} from './playback-snapshots.js';

// Disabled provider jobs are retained as explicit opt-ins, not deleted APIs.
export function schedulePolicy(env = process.env) {
  return {
    apple: env.APP_STORE_RECONCILIATION_ENABLED === 'true',
    google: env.GOOGLE_PLAY_RECONCILIATION_ENABLED === 'true',
    support: env.SUPPORT_EMAIL_DELIVERY_ENABLED === 'true' &&
      env.SUPPORT_EMAIL_SECRETS_ENABLED === 'true',
  };
}

// Start every independent cleanup before awaiting any one of them. A failed
// branch must not prevent the others from reclaiming expired data.
export async function runMaintenanceTasks(tasks, emit = entry => console.log(JSON.stringify(entry))) {
  const results = await Promise.allSettled(Object.entries(tasks).map(async ([task, run]) => {
    try {
      await run();
      emit({message: 'scheduled_maintenance', task, status: 'completed'});
    } catch {
      // Do not log document paths, account IDs, provider errors or secrets.
      emit({message: 'scheduled_maintenance', task, status: 'failed'});
      throw new Error(task);
    }
  }));
  const failures = results.filter(result => result.status === 'rejected');
  if (failures.length) throw new Error(`scheduled-maintenance-failed:${failures.length}`);
}

function checkDeadline(deadlineMs) {
  if (Date.now() >= deadlineMs) throw new Error('maintenance-deadline');
}

export async function cleanupSnapshots({db, realtime, now = Date.now(), deadlineMs = Infinity}) {
  const cutoff = now - 7 * 86400000;
  let cursor;
  do {
    checkDeadline(deadlineMs);
    let query = db.collection('users').orderBy('__name__').limit(100);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    for (const user of page.docs) {
      checkDeadline(deadlineMs);
      await prunePlaybackSnapshots(realtime.ref(`users/${user.id}`), cutoff);
    }
    cursor = page.docs.at(-1);
    if (page.size < 100) break;
  } while (cursor);
}

export async function cleanupOnboarding({db, now = Date.now(), deadlineMs = Infinity}) {
  for (const [collection, field, cutoff] of [
    ['onboardingPhoneChallenges', 'expiresAtMs', now - 86400000],
    ['onboardingSmsLimits', 'expiresAt', Timestamp.fromMillis(now)],
  ]) {
    let page;
    do {
      checkDeadline(deadlineMs);
      page = await db.collection(collection).where(field, '<', cutoff).limit(400).get();
      const batch = db.batch();
      for (const document of page.docs) batch.delete(document.ref);
      await batch.commit();
    } while (page.size === 400);
  }
}

export async function runDailyMaintenance({db, realtime, bucket, now = Date.now()}) {
  // Leave 30 seconds inside the 540-second function deadline for reporting.
  const deadlineMs = Date.now() + 510000;
  return runMaintenanceTasks({
    diagnostics: async () => (await import('./client-diagnostics.js')).cleanupDiagnosticLimits(db),
    operationLimits: async () => (await import('./operation-telemetry.js')).cleanupOperationLimits(db),
    onboarding: () => cleanupOnboarding({db, now, deadlineMs}),
    playbackSnapshots: () => cleanupSnapshots({db, realtime, now, deadlineMs}),
    supportUploads: async () => (await import('./support-tickets.js')).cleanupSupportUploads({db, bucket, now}),
  });
}

// Same due-account selection and entitlement resolver as the previous two
// provider schedules. Store credentials are intentionally not required.
export async function refreshDueEntitlements({db, realtime, now = Date.now(), refresh}) {
  const refreshAccount = refresh ?? (await import('./billing.js')).refreshEntitlements;
  const accounts = await db.collection('billingAccounts').where('nextCheckAtMs', '<=', now).limit(100).get();
  let failed = 0;
  for (const account of accounts.docs) {
    try { await refreshAccount(db, realtime, account.id); }
    catch { failed++; }
  }
  if (failed) throw new Error(`entitlement-refresh-failed:${failed}`);
  return accounts.size;
}
