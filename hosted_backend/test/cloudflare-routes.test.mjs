import assert from 'node:assert/strict';
import { test } from 'node:test';
import { adminFetch, publicFetch } from '../cloudflare/routes.mjs';

const origin = 'https://bahtzay-admin.example';
const assets = { '/admin/index.html': ['text/html', '<h1>Admin</h1>'] };
const ownerEmail = 'owner@example.com';
const context = email => ({
  access: { getIdentity: async () => ({ email }) },
  waitUntil() {},
});
const env = { ADMIN_OWNER_EMAIL: ownerEmail };
const req = (path, options) => new Request(origin + path, options);

test('Cloudflare admin requires authenticated Access identity for HTML and API', async () => {
  for (const path of ['/admin/index.html', '/api/admin/state']) {
    const spoof = req(path, { headers: {
      'Cf-Access-Authenticated-User-Email': ownerEmail,
      'oai-authenticated-user-email': ownerEmail,
    } });
    assert.equal((await adminFetch(spoof, env, {}, assets)).status, 403);
    assert.equal((await adminFetch(req(path), env, context('other@example.com'), assets)).status, 403);
  }
  const html = await adminFetch(req('/admin/index.html'), env, context(ownerEmail), assets);
  assert.equal(html.status, 200);
  assert.equal(await html.text(), '<h1>Admin</h1>');
  assert.equal((await adminFetch(req('/admin/index.html'), {}, context(ownerEmail), assets)).status, 403);
});

test('Public Worker exposes health and keeps owner and repair routes private', async () => {
  const ctx = context(ownerEmail);
  for (const path of ['/admin/index.html', '/api/admin/state', '/api/ops/remove-owner-test-20261017']) {
    assert.equal((await publicFetch(req(path), env, ctx)).status, 404);
  }
  const db = { prepare: sql => {
    assert.equal(sql, 'SELECT 1');
    return { first: async () => ({ 1: 1 }) };
  } };
  const health = await publicFetch(req('/api/health'), { DB: db }, ctx);
  assert.deepEqual(await health.json(), { ok: true, storage: 'D1' });
});

test('Cloudflare admin keeps same-origin checks and uses its own pinned owner identity', async () => {
  const ctx = context(ownerEmail);
  const headers = { Origin: origin, 'X-Admin-Request': '1' };
  const blocked = await adminFetch(req('/api/admin/login', { method: 'POST' }), env, ctx, assets);
  assert.equal(blocked.status, 403);
  let pinned;
  const db = { prepare: sql => {
    if (sql.startsWith('SELECT user_id')) return { first: async () => pinned };
    assert.match(sql, /^INSERT OR IGNORE INTO admin_owner/);
    return { bind: id => ({ run: async () => { pinned = { user_id: id }; } }) };
  } };
  const login = await adminFetch(req('/api/admin/login', { method: 'POST', headers }), { ...env, DB: db }, ctx, assets);
  assert.equal(login.status, 200);
  assert.equal(pinned.user_id, 'cloudflare-access:' + ownerEmail);
});
