import {HttpsError} from 'firebase-functions/v2/https';

// Callables check revocation again: the callable framework alone does not do so.
export async function invokeUsageCallable(ctx, request, handler) {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', '로그인 후 이용해 주세요.');
  const header = request.rawRequest?.headers?.authorization;
  const bearer = typeof header === 'string' ? /^Bearer\s+(\S+)$/i.exec(header)?.[1] : null;
  let token;
  try {
    token = await ctx.auth.verifyIdToken(bearer ?? '', true);
    if (token.uid !== request.auth.uid) throw new Error('Identity mismatch');
  } catch {
    throw new HttpsError('unauthenticated', '다시 로그인해 주세요.');
  }
  return handler({...ctx, actor: {uid: token.uid, token}, input: request.data});
}
