import { pushPayload } from './notification-events.mjs';

const project = 'bahtzay-6ff5d';
const tokenUrl = 'https://oauth2.googleapis.com/token';
const encoder = new TextEncoder();
let cachedToken;

function base64url(bytes) {
  return btoa(String.fromCharCode(...bytes)).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
}

async function accessToken(secret, fetcher) {
  if (cachedToken?.secret === secret && cachedToken.until > Date.now()) return cachedToken.token;
  const account = JSON.parse(secret);
  if (account.type !== 'service_account' || account.project_id !== project || !account.client_email || !account.private_key) {
    throw new Error('Invalid BahtZay FCM service account');
  }
  const key = Uint8Array.from(atob(account.private_key.replace(/-----[^-]+-----|\s/g, '')), c => c.charCodeAt(0));
  const signingKey = await crypto.subtle.importKey('pkcs8', key, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const now = Math.floor(Date.now() / 1000);
  const encodeJson = value => base64url(encoder.encode(JSON.stringify(value)));
  const assertion = encodeJson({ alg: 'RS256', typ: 'JWT' }) + '.' + encodeJson({
    iss: account.client_email, aud: tokenUrl, scope: 'https://www.googleapis.com/auth/firebase.messaging',
    iat: now, exp: now + 3600,
  });
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', signingKey, encoder.encode(assertion));
  const response = await fetcher(tokenUrl, {
    method: 'POST', redirect: 'error', signal: AbortSignal.timeout(8000),
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: assertion + '.' + base64url(new Uint8Array(signature)),
    }),
  });
  if (!response.ok) throw new Error('FCM authorization failed');
  const { access_token: token, expires_in: seconds } = await response.json();
  if (typeof token !== 'string' || !Number.isFinite(seconds)) throw new Error('Invalid OAuth response');
  cachedToken = { secret, token, until: Date.now() + (seconds - 60) * 1000 };
  return token;
}

export async function deliverAndroidPush(db, secret, eventCurrent, fetcher = fetch) {
  const now = Date.now();
  const events = (await db.prepare(`SELECT e.* FROM notification_events e
    JOIN revisions r ON r.id=e.revision
    LEFT JOIN android_push_delivery d ON d.revision=e.revision
    WHERE e.expires_at>? AND e.created_at >=
      (SELECT enabled_at FROM android_push_delivery WHERE revision=0)
      AND (d.revision IS NULL OR (d.sent=0 AND d.attempts<5 AND d.retry_at<=?))
      AND NOT EXISTS (SELECT 1 FROM notification_events n JOIN revisions nr ON nr.id=n.revision
        WHERE n.kind=e.kind AND n.revision>e.revision)
    ORDER BY e.revision LIMIT 2`).bind(now, now).all()).results;
  for (const event of events) {
    const latest = await db.prepare('SELECT id,payload FROM revisions ORDER BY id DESC LIMIT 1').first();
    if (!eventCurrent(event, latest)) continue;
    const payload = pushPayload(event, Date.now(), JSON.parse(latest.payload).notice);
    if (!payload || payload.expires_at <= Date.now()) continue;
    const at = Date.now();
    const claim = await db.prepare(`INSERT INTO android_push_delivery(revision,attempts,retry_at)
      SELECT ?,1,? WHERE (SELECT MAX(id) FROM revisions)=? AND EXISTS(SELECT 1 FROM revisions WHERE id=?)
      ON CONFLICT(revision) DO UPDATE SET attempts=attempts+1,retry_at=excluded.retry_at
      WHERE sent=0 AND attempts<5 AND retry_at<=?`).bind(event.revision, at+120000, latest.id, event.revision, at).run();
    if (!claim.meta.changes) continue;
    const token = await accessToken(secret, fetcher);
    const ttl = Math.floor((payload.expires_at - Date.now()) / 1000);
    if (ttl <= 0) continue;
    const response = await fetcher('https://fcm.googleapis.com/v1/projects/' + project + '/messages:send', {
      method: 'POST', redirect: 'error', signal: AbortSignal.timeout(8000),
      headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: {
        topic: 'bahtzay_android_updates',
        notification: { title: payload.title, body: payload.body },
        android: { ttl: ttl + 's', collapse_key: payload.tag, notification: { tag: payload.tag } },
      } }),
    });
    if (response.status === 401) cachedToken = undefined;
    if (!response.ok) throw new Error('FCM send failed: HTTP ' + response.status);
    await db.prepare('UPDATE android_push_delivery SET sent=1 WHERE revision=?').bind(event.revision).run();
  }
}

let lastCheck;
export function scheduleAndroidPush(db, runtime, eventCurrent, force) {
  if (!runtime.fcmServiceAccount || !runtime.waitUntil) return;
  const now = Date.now();
  if (!force && lastCheck !== undefined && now - lastCheck < 60000) return;
  lastCheck = now;
  runtime.waitUntil((async () => {
    await db.prepare('INSERT OR IGNORE INTO android_push_delivery(revision,enabled_at) VALUES (0,?)').bind(now).run();
    await deliverAndroidPush(db, runtime.fcmServiceAccount, eventCurrent, runtime.fetcher || fetch);
  })().catch(error => console.error('Android push deferred:', error.name)));
}
