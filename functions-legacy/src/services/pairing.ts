import { randomUUID } from 'node:crypto';
import { HttpsError, type FunctionsErrorCode } from 'firebase-functions/v2/https';
import { z } from 'zod';

const project = 'cloud-board-stationd';
const endpoint = `https://asia-northeast3-${project}.cloudfunctions.net/pairDisplayConnection`;
const unavailable = () => new HttpsError('unavailable', '기기 연결을 잠시 후 다시 시도해 주세요.');
const errors: Record<string, readonly [FunctionsErrorCode, string]> = {
  INVALID_ARGUMENT: ['invalid-argument', '연결 코드와 기기 이름을 확인해 주세요.'],
  UNAUTHENTICATED: ['unauthenticated', '다시 로그인해 주세요.'],
  PERMISSION_DENIED: ['permission-denied', '기기를 연결할 수 있는 계정인지 확인해 주세요.'],
  FAILED_PRECONDITION: ['failed-precondition', '구독 상태와 TV의 새 연결 코드를 확인해 주세요.'],
  RESOURCE_EXHAUSTED: ['resource-exhausted', '등록 가능한 디스플레이 수를 확인해 주세요.'],
  ALREADY_EXISTS: ['already-exists', '이미 연결된 기기인지 확인해 주세요.'],
  NOT_FOUND: ['not-found', 'TV의 새 연결 코드를 확인해 주세요.'],
  ABORTED: ['aborted', '연결 상태가 변경되었습니다. 다시 시도해 주세요.'],
};

async function responseBody(response: Response): Promise<unknown> {
  // Never retain or log an arbitrary upstream error page. The real callable
  // response is tiny; cap streamed bytes as well as any declared content length.
  const limit = 16 * 1024;
  if (Number(response.headers.get('content-length')) > limit || !response.body)
    throw unavailable();
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let size = 0, body = '';
  try {
    while (true) {
      const chunk = await reader.read();
      if (chunk.done) break;
      size += chunk.value.byteLength;
      if (size > limit) {
        await reader.cancel();
        throw unavailable();
      }
      body += decoder.decode(chunk.value, { stream: true });
    }
    return JSON.parse(body + decoder.decode());
  } finally {
    reader.releaseLock();
  }
}

// Only call after the legacy callable has verified this original Firebase ID
// token with checkRevoked=true. The canonical callable independently checks it.
// This module deliberately has no Admin database writes or legacy fallback.
export async function pairDisplay(
  bearer: string,
  input: unknown,
  transport: typeof fetch = fetch,
) {
  const parsed = z.object({
    code: z.string().regex(/^\d{6}$/),
    name: z.string().trim().max(60).default(''),
    zoneName: z.string().trim().max(60).default(''),
  }).safeParse(input);
  if (!parsed.success)
    throw new HttpsError('invalid-argument', '연결 코드와 기기 이름을 확인해 주세요.');
  // The runtime project and destination must agree; never send an emulator or
  // another project's bearer to production, nor accept a caller-provided URL.
  if (process.env.GCLOUD_PROJECT !== project) throw unavailable();
  if (!bearer) throw new HttpsError('unauthenticated', '다시 로그인해 주세요.');
  let response: Response, body: any;
  try {
    response = await transport(endpoint, {
      method: 'POST',
      redirect: 'error',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${bearer}` },
      body: JSON.stringify({ data: { ...parsed.data, operationId: `legacy-${randomUUID()}` } }),
      // Leave time to return a sanitized error within the legacy 30s timeout.
      // Native fetch applies this deadline to both headers and response body.
      signal: AbortSignal.timeout(20_000),
    });
    body = await responseBody(response);
  } catch {
    throw unavailable();
  }
  if (body && typeof body === 'object' && 'error' in body) {
    const status = body.error?.status;
    const mapped = typeof status === 'string' && Object.hasOwn(errors, status) ? errors[status] : undefined;
    // Never forward upstream messages/details (which may contain identifiers).
    if (mapped) throw new HttpsError(...mapped);
    throw unavailable();
  }
  if (!response.ok || body?.result?.paired !== true ||
      typeof body.result.deviceId !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(body.result.deviceId))
    throw unavailable();
  // Keep the installed app's exact response shape, even if the new API expands.
  return { paired: true, deviceId: body.result.deviceId as string };
}
