import { onValueCreated } from 'firebase-functions/v2/database';
import { defineSecret } from 'firebase-functions/params';
import { info, warn } from 'firebase-functions/logger';
import { buildWebhookPayload, deliverWebhook } from './operation-event-webhook.js';

const PROJECT = 'cloud-board-stationd';
const project = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
const emulator = process.env.FUNCTIONS_EMULATOR === 'true' && project?.startsWith('demo-');
if (project !== PROJECT && !emulator) throw new Error('Class monitoring is production-only');
const webhookKey = defineSecret('CLASS_MONITORING_WEBHOOK_KEY');
const url = emulator
  ? 'http://127.0.0.1:19404/events'
  : 'https://moring-phi.vercel.app/api/v1/projects/24cc3dbc-6498-4117-a941-57f9c5b7af74/events';

export const forwardClassOperation = onValueCreated({
  ref: '/users/{ownerId}/operations/events/{eventId}',
  instance: emulator ? project + '-default-rtdb' : 'cloud-board-stationd-default-rtdb',
  region: emulator ? 'us-central1' : 'asia-southeast1',
  serviceAccount: `class-monitoring@${PROJECT}.iam.gserviceaccount.com`,
  secrets: [webhookKey],
  retry: true,
  timeoutSeconds: 30,
  maxInstances: 2,
  minInstances: 0,
  concurrency: 10,
  memory: '256MiB',
}, async (event) => {
  const createdAt = Date.parse(event.time);
  // CloudEvent time is stable across retries. Never replay an expired event.
  if (!Number.isFinite(createdAt) || Date.now() - createdAt > 15 * 60 * 1000) {
    warn('class_monitoring_expired', { cloudEventId: event.id });
    return;
  }
  const payload = buildWebhookPayload({
    projectId: PROJECT,
    ownerId: event.params.ownerId,
    eventId: event.params.eventId,
    event: event.data.val(),
    receivedAtMs: createdAt,
  });
  if (!payload) return;
  const result = await deliverWebhook({ payload, key: webhookKey.value(), url, allowLocalEmulator: emulator });
  const log = result.outcome === 'delivered' ? info : warn;
  log('class_monitoring_delivery', { eventId: payload.event_id, ...result });
});
