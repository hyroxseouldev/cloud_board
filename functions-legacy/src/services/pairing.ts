import type { Database } from 'firebase-admin/database';
import { HttpsError } from 'firebase-functions/v2/https';
import { z } from 'zod';
import { modernPlan } from './plan-entitlements.js';
export async function pairDisplay(database: Database, uid: string, input: unknown) {
  const parsed = z
    .object({
      code: z.string().regex(/^\d{6}$/),
      name: z.string().trim().max(60).default(''),
      zoneName: z.string().trim().max(60).default(''),
    })
    .safeParse(input);
  if (!parsed.success)
    throw new HttpsError('invalid-argument', '연결 코드와 기기 이름을 확인해 주세요.');
  const { code, name, zoneName } = parsed.data;
  if ((await database.ref(`accountDeletions/${uid}`).get()).exists())
    throw new HttpsError('permission-denied', '삭제 처리 중인 계정입니다.');
  const access = (await database.ref(`subscriptionAccess/${uid}`).get()).val();
  if (!access?.managed)
    throw new HttpsError('failed-precondition', '구독 연결 상태를 확인해 주세요.');
  if (access.status !== 'pending_connection' && !(access.validUntilMs > Date.now()))
    throw new HttpsError(
      'failed-precondition',
      '디스플레이를 새로 등록하려면 구독을 확인해 주세요.',
    );
  const plan = modernPlan(access);
  const limit = plan ? null : Math.min(3, Number(access.displayLimit) || 0);
  if (limit !== null && limit < 1)
    throw new HttpsError('permission-denied', '등록 가능한 디스플레이가 없습니다.');
  const pairingRef = database.ref(`pairingCodes/${code}`);
  const claimed = await pairingRef.transaction((current) => {
    // Cold RTDB transaction caches initially contain null. Return null once so
    // the server can compare and retry with its actual pairing code contents.
    if (current === null) return null;
    if (typeof current.deviceId !== 'string' || typeof current.displayUid !== 'string') return;
    if (current.claimed && current.ownerId !== uid) return;
    if (!current.claimed && current.expiresAtMs <= Date.now()) return;
    return {
      ...current,
      claimed: true,
      ownerId: uid,
      claimedAtMs: current.claimedAtMs || Date.now(),
    };
  });
  if (!claimed.committed || !claimed.snapshot.exists())
    throw new HttpsError(
      'failed-precondition',
      '만료되었거나 사용 중인 연결 코드입니다. 새 코드를 확인해 주세요.',
    );
  const pairing = claimed.snapshot.val(),
    deviceId = pairing.deviceId,
    displayUid = pairing.displayUid;
  if (/[.#$\[\]/]/.test(deviceId) || /[.#$\[\]/]/.test(displayUid))
    throw new HttpsError('invalid-argument', '기기 식별자를 확인해 주세요.');
  const devices = database.ref(`users/${uid}/devices`),
    now = Date.now();
  // All managed-device creation is server-only. One transaction serializes
  // concurrent registrations, including attempts from different controllers.
  const reserved = await devices.transaction((current) => {
    const values = current || {};
    if (values[deviceId]) return values[deviceId].displayUid === displayUid ? values : undefined;
    if (limit !== null && Object.keys(values).length >= limit) return;
    return {
      ...values,
      [deviceId]: {
        id: deviceId,
        displayUid,
        mode: 'display',
        name: name || '매장 디스플레이',
        zoneId: 'main',
        zoneName: zoneName || '메인 구역',
        paired: true,
        pairedAtMs: now,
        pairingCode: code,
        online: true,
        onlineSinceMs: now,
        lastSeenAtMs: now,
        displayState:
          (plan === 'plus' || plan === 'free') &&
          Object.values(values).filter(
            (d: any) => d.paired === true && (d.displayState ?? 'auto') === 'auto',
          ).length >= access.maxActiveDisplays
            ? 'black'
            : 'auto',
      },
    };
  });
  if (!reserved.committed)
    throw new HttpsError(
      'resource-exhausted',
      '등록 디스플레이는 최대 3대입니다. 기존 연결을 해제한 뒤 다시 시도해 주세요.',
    );
  // A failed network response can be retried with the same code and device;
  // the reservation is kept so an uncertain result cannot oversubscribe slots.
  await database
    .ref(`displayAccess/${displayUid}`)
    .update({ ownerId: uid, deviceId, pairingCode: code, pairedAtMs: now });
  return { paired: true, deviceId };
}
