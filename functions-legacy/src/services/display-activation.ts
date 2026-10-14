import type { Database } from 'firebase-admin/database';
import { HttpsError } from 'firebase-functions/v2/https';
import { z } from 'zod';
import { modernPlan } from './plan-entitlements.js';

export function applyDisplayState(
  current: any,
  deviceId: string,
  state: string,
  plan: string,
  now: number,
  limit: number | null = plan === 'premium' ? null : plan === 'free' ? 1 : 3,
  replaceDeviceIds: string[] = [],
) {
  if (!current?.devices?.[deviceId]?.paired) return;
  const devices = { ...current.devices };
  const replacing = new Set(replaceDeviceIds);
  if (
    replacing.has(deviceId) ||
    [...replacing].some(
      (id) => devices[id]?.paired !== true || (devices[id]?.displayState ?? 'auto') !== 'auto',
    )
  ) {
    throw new HttpsError('aborted', 'TV 상태가 변경되었어요. 목록을 다시 확인해 주세요.');
  }
  if (state !== 'auto' && replacing.size) {
    throw new HttpsError('invalid-argument', 'TV 전환 대상을 확인해 주세요.');
  }
  const others = Object.entries<any>(devices).filter(
    ([id, device]) =>
      id !== deviceId &&
      device.paired === true &&
      (device.displayState ?? 'auto') === 'auto' &&
      !replacing.has(id),
  );
  if (state === 'auto' && limit !== null && others.length >= limit) {
    throw new HttpsError(
      'resource-exhausted',
      `동시에 송출할 수 있는 TV는 ${limit}대예요. 사용 중인 TV를 끄거나 전환할 대상을 선택해 주세요.`,
    );
  }
  for (const id of replacing)
    devices[id] = { ...devices[id], displayState: 'black', lastCommandAtMs: now };
  devices[deviceId] = { ...devices[deviceId], displayState: state, lastCommandAtMs: now };
  const result = { ...current, devices };
  const session = current.activeSession;
  if (replacing.size && session && session.status !== 'completed') {
    const targets = [
      ...new Set<string>([
        ...(session.targetDeviceIds ?? []).filter((id: string) => !replacing.has(id)),
        deviceId,
      ]),
    ];
    if (limit !== null && targets.length > limit) {
      throw new HttpsError('failed-precondition', '진행 중인 수업의 TV 대상을 먼저 확인해 주세요.');
    }
    result.activeSession = {
      ...session,
      targetDeviceIds: targets,
      revision: (session.revision || 0) + 1,
    };
  }
  return result;
}

export async function activateDisplay(database: Database, uid: string, input: unknown) {
  const parsed = z
    .object({
      deviceId: z
        .string()
        .min(1)
        .max(200)
        .regex(/^[^.#$\[\]/]+$/),
      displayState: z.enum(['auto', 'standby', 'black']),
      replaceDeviceIds: z
        .array(
          z
            .string()
            .min(1)
            .max(200)
            .regex(/^[^.#$\[\]/]+$/),
        )
        .max(100)
        .default([]),
    })
    .safeParse(input);
  if (!parsed.success) throw new HttpsError('invalid-argument', '디스플레이를 확인해 주세요.');
  if ((await database.ref(`accountDeletions/${uid}`).get()).exists())
    throw new HttpsError('permission-denied', '삭제 처리 중인 계정입니다.');
  const access = (await database.ref(`subscriptionAccess/${uid}`).get()).val();
  const plan = modernPlan(access);
  if (!access?.managed || !plan)
    throw new HttpsError('failed-precondition', '플랜 권한을 확인해 주세요.');
  if (
    parsed.data.displayState === 'auto' &&
    !(access.validUntilMs > Date.now()) &&
    access.status !== 'pending_connection'
  )
    throw new HttpsError('failed-precondition', '이용 기간을 확인해 주세요.');
  let transactionError: unknown;
  const result = await database.ref(`users/${uid}`).transaction((current) => {
    // RTDB reruns this callback on conflicts. Throwing from a retry can leave
    // its transaction queue unresolved; abort normally, then surface the
    // original policy error after the SDK has finished its cleanup.
    transactionError = undefined;
    if (current === null) return null;
    try {
      return applyDisplayState(
        current,
        parsed.data.deviceId,
        parsed.data.displayState,
        plan,
        Date.now(),
        plan === 'premium' ? null : access.maxActiveDisplays,
        parsed.data.replaceDeviceIds,
      );
    } catch (error) {
      transactionError = error;
      return undefined;
    }
  });
  if (transactionError !== undefined) throw transactionError;
  if (!result.committed || !result.snapshot.exists())
    throw new HttpsError('not-found', '등록된 디스플레이를 찾을 수 없습니다.');
  return { changed: true };
}
