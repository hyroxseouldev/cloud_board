import type { IncomingMessage, ServerResponse } from 'node:http';
import { getAuthRuntime } from './auth.js';
import { handleAPI } from './api.js';
import { timingSafeEqual } from 'node:crypto';
import { isIP } from 'node:net';

// Firebase parses the body before onRequest. Reuse rawBody instead of reading
// the already-consumed stream through an Express/Node auth adapter.
export async function handleAuthRequest(
  req: IncomingMessage & { rawBody?: Buffer },
  res: ServerResponse,
  runtime = getAuthRuntime(),
) {
  res.setHeader('Cache-Control', 'no-store');
  const path = new URL(req.url || '/', runtime.config.baseURL);
  if (!runtime.config.local) {
    const expected = process.env.CLOUDBOARD_GATEWAY_SECRET || '',
      supplied = req.headers['x-cloudboard-edge-key'];
    if (
      expected.length < 32 ||
      typeof supplied !== 'string' ||
      Buffer.byteLength(supplied) !== Buffer.byteLength(expected) ||
      !timingSafeEqual(Buffer.from(supplied), Buffer.from(expected))
    ) {
      res.writeHead(403).end();
      return;
    }
  }
  if (!path.pathname.startsWith('/api/')) {
    res.writeHead(404).end();
    return;
  }
  const origin = req.headers.origin;
  if (
    (origin && !runtime.config.trustedOrigins.includes(origin)) ||
    (!origin &&
      !['GET', 'HEAD', 'OPTIONS'].includes(req.method || 'GET') &&
      path.pathname !== '/api/webhooks/toss')
  ) {
    res.writeHead(403).end();
    return;
  }
  if (origin) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Access-Control-Allow-Credentials', 'true');
    res.setHeader('Vary', 'Origin');
  }
  if (req.method === 'OPTIONS') {
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    res.writeHead(204).end();
    return;
  }
  const headers = new Headers();
  for (const [key, value] of Object.entries(req.headers)) {
    if (value && !['host', 'content-length', 'connection'].includes(key)) {
      headers.set(key, Array.isArray(value) ? value.join(', ') : value);
    }
  }
  const edgeIP = headers.get('x-cloudboard-client-ip');
  headers.delete('x-cloudboard-client-ip');
  headers.delete('x-cloudboard-edge-key');
  if (runtime.config.local && req.socket.remoteAddress) {
    headers.set('x-cloudboard-client-ip', req.socket.remoteAddress);
  } else if (!runtime.config.local && edgeIP && isIP(edgeIP))
    headers.set('x-cloudboard-client-ip', edgeIP);
  let body: Buffer | undefined;
  if (!['GET', 'HEAD'].includes(req.method || 'GET')) {
    body = req.rawBody;
    if (!body) {
      const chunks: Buffer[] = [];
      let size = 0;
      for await (const chunk of req) {
        const buffer = Buffer.from(chunk);
        size += buffer.length;
        if (size > 64 * 1024) {
          res.writeHead(413).end();
          return;
        }
        chunks.push(buffer);
      }
      body = Buffer.concat(chunks);
    }
    if (body.length > 64 * 1024) {
      res.writeHead(413).end();
      return;
    }
  }
  // Use the configured origin, never untrusted forwarded host headers.
  const url = new URL(path.pathname + path.search, runtime.config.baseURL);
  const request = new Request(url, {
    method: req.method,
    headers,
    body: body ? new Uint8Array(body) : undefined,
  });
  const response = path.pathname.startsWith('/api/auth/')
    ? await runtime.auth.handler(request)
    : await handleAPI(request, runtime);
  response.headers.forEach((value, key) => {
    if (key !== 'set-cookie') res.setHeader(key, value);
  });
  const cookies = response.headers.getSetCookie();
  if (cookies.length) res.setHeader('Set-Cookie', cookies);
  res.statusCode = response.status;
  res.end(Buffer.from(await response.arrayBuffer()));
}
