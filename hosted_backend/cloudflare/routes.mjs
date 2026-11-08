import { handle } from '../lib/api.mjs';

const publicReads = new Set([
  '/api/health', '/api/rates', '/api/v2/rates', '/api/v2/history',
  '/api/v2/alerts', '/api/v2/ads', '/api/v2/app-release',
]);
const pushRoutes = new Set(['config', 'subscribe', 'status', 'unsubscribe', 'test']
  .map(name => '/api/v2/push/' + name));

function runtime(env, ctx) {
  return {
    waitUntil: promise => ctx.waitUntil(promise),
    telegramKey: env.TELEGRAM_CONFIG_KEY,
    publicApiOrigin: env.PUBLIC_API_ORIGIN,
    includeLegacyHistory: true,
  };
}

export function publicFetch(request, env, ctx) {
  const { pathname } = new URL(request.url);
  const allowed = (publicReads.has(pathname) && request.method === 'GET') ||
    pushRoutes.has(pathname) ||
    (pathname === '/api/telegram/webhook' && request.method === 'POST');
  return allowed
    ? handle(request, env.DB, null, null, runtime(env, ctx))
    : new Response('Not found', { status: 404 });
}

export async function adminFetch(request, env, ctx, assets) {
  const owner = env.ADMIN_OWNER_EMAIL?.trim().toLowerCase();
  // Access authenticates the direct Worker invocation. Never trust request
  // headers supplied by a browser to establish the owner's identity.
  if (!owner || !ctx.access) return new Response('Access required', { status: 403 });
  const identity = await ctx.access.getIdentity();
  const email = identity?.email?.trim().toLowerCase();
  if (!email || email !== owner) return new Response('Access denied', { status: 403 });

  const url = new URL(request.url);
  if (url.pathname === '/api/v2/push/config' && request.method === 'GET') {
    return handle(request, env.DB, null, null, runtime(env, ctx));
  }
  if (url.pathname.startsWith('/api/admin/')) {
    return handle(request, env.DB, { email, userId: 'cloudflare-access:' + email },
      owner, runtime(env, ctx));
  }
  if (!['GET', 'HEAD'].includes(request.method)) {
    return new Response('Method not allowed', { status: 405 });
  }
  if (['/', '/admin', '/admin/'].includes(url.pathname)) {
    return Response.redirect(new URL('/admin/index.html', url), 302);
  }
  if (!Object.hasOwn(assets, url.pathname)) return new Response('Not found', { status: 404 });
  const [contentType, body] = assets[url.pathname];
  return new Response(request.method === 'HEAD' ? null : body, {
    headers: {
      'Content-Type': contentType,
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
      'Content-Security-Policy': "frame-ancestors 'none'",
    },
  });
}
