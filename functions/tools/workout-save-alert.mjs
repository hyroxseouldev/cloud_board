import {pathToFileURL} from 'node:url';
import {GoogleAuth} from 'google-auth-library';

export const workoutSaveFilter = [
  'resource.type = ("cloud_run_revision" OR "cloud_function")',
  'severity >= ERROR',
  'jsonPayload.message = "client_diagnostic"',
  'jsonPayload.context.action = ("workout.save" OR "workout.duplicate")',
].join('\n');

export function workoutSavePolicy(project, channel) {
  return {
    displayName: 'CloudBoard workout save failures',
    enabled: true,
    userLabels: {managed_by: 'cloudboard', purpose: 'workout-save'},
    documentation: {
      mimeType: 'text/markdown',
      content: `워크아웃 저장 또는 복사가 실패했습니다. 로그에서 eventId, code, context.platform, context.version, context.build를 확인하세요. permission-denied라면 앱 저장 필드와 배포된 Firestore 규칙을 비교하세요.\n\n[오류 로그](https://console.cloud.google.com/logs/query?project=${project}&query=${encodeURIComponent(workoutSaveFilter)})`,
    },
    conditions: [{displayName: 'Handled workout save or duplicate failure', conditionMatchedLog: {filter: workoutSaveFilter}}],
    combiner: 'OR',
    alertStrategy: {notificationRateLimit: {period: '1800s'}, autoClose: '1800s'},
    notificationChannels: [channel],
  };
}

// request(method, path, body) is injectable for tests and authenticated tooling.
export async function configureWorkoutSaveAlert({project, email, request}) {
  if (!/^[a-z][a-z0-9-]+$/.test(project) || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error('Valid project and alert email required.');
  const parent = `projects/${project}`;
  async function list(kind) {
    const items = [];
    let pageToken;
    do {
      const page = await request('GET', `${parent}/${kind}${pageToken ? `?pageToken=${encodeURIComponent(pageToken)}` : ''}`);
      items.push(...(page[kind] || []));
      pageToken = page.nextPageToken;
    } while (pageToken);
    return items;
  }
  let channel = (await list('notificationChannels')).find(c => c.type === 'email' && c.labels?.email_address === email);
  if (!channel) channel = await request('POST', `${parent}/notificationChannels`, {
    type: 'email', displayName: 'CloudBoard save failure alerts', enabled: true, labels: {email_address: email},
  });
  else if (!channel.enabled) channel = await request('PATCH', `${channel.name}?updateMask=enabled`, {name: channel.name, enabled: true});
  const previous = (await list('alertPolicies')).find(p => p.userLabels?.managed_by === 'cloudboard' && p.userLabels?.purpose === 'workout-save');
  const policy = workoutSavePolicy(project, channel.name);
  if (previous) {
    policy.name = previous.name;
    if (previous.conditions?.[0]?.name) policy.conditions[0].name = previous.conditions[0].name;
  }
  const saved = await request(previous ? 'PATCH' : 'POST', previous
    ? `${previous.name}?updateMask=displayName,enabled,userLabels,documentation,conditions,combiner,alertStrategy,notificationChannels`
    : `${parent}/alertPolicies`, policy);
  return {policy: saved.name, channel: channel.name, enabled: saved.enabled, verificationStatus: channel.verificationStatus};
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [project, email, apply] = process.argv.slice(2);
  if (apply !== '--apply') throw new Error('Usage: node functions/tools/workout-save-alert.mjs PROJECT EMAIL --apply');
  const client = await new GoogleAuth({scopes: ['https://www.googleapis.com/auth/cloud-platform']}).getClient();
  const result = await configureWorkoutSaveAlert({project, email, request: async (method, path, data) =>
    (await client.request({method, url: `https://monitoring.googleapis.com/v3/${path}`, data})).data});
  console.log(JSON.stringify(result));
}
