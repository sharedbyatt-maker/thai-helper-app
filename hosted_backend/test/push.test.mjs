import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync,readdirSync} from 'node:fs';
import {createECDH,randomBytes,hkdfSync,createDecipheriv,createPublicKey,verify} from 'node:crypto';
import {vapidKeys,webPushRequest,validPushEndpoint} from '../lib/web-push-crypto.mjs';
import {ensurePushConfig,pushApi,queuePush,deliverPush} from '../lib/push.mjs';
import {pushPayload,eventInsert,publishAnnouncement} from '../lib/notification-events.mjs';
import {handle} from '../lib/api.mjs';
import {unseal} from '../lib/secrets.mjs';
class D1 {
 constructor(){this.sqlite=new DatabaseSync(':memory:');for(const f of readdirSync(new URL('../drizzle',import.meta.url)).filter(f=>f.endsWith('.sql')).sort())this.sqlite.exec(readFileSync(new URL('../drizzle/'+f,import.meta.url),'utf8'));}
 prepare(sql){const stmt=this.sqlite.prepare(sql),wrap=(v=[])=>({bind:(...args)=>wrap(args),first:async()=>stmt.get(...v)||null,all:async()=>({results:stmt.all(...v)}),run:async()=>({meta:{changes:Number(stmt.run(...v).changes)}})});return wrap();}
 async batch(items){let release;const before=this.tail||Promise.resolve();this.tail=new Promise(r=>release=r);await before;this.sqlite.exec('BEGIN');try{const out=[];for(const item of items)out.push(await item.run());this.sqlite.exec('COMMIT');return out;}catch(e){this.sqlite.exec('ROLLBACK');throw e;}finally{release();}}
}
const secret='ab'.repeat(32),token='cd'.repeat(32),otherToken='ef'.repeat(32),now=Date.now();
function subscription(suffix='one'){const dh=createECDH('prime256v1'),pub=dh.generateKeys(),auth=randomBytes(16);return {dh,auth,sub:{endpoint:'https://fcm.googleapis.com/fcm/send/'+suffix,keys:{p256dh:pub.toString('base64url'),auth:auth.toString('base64url')}}};}
function request(path,origin='https://sharedbyatt-maker.github.io'){return new Request('https://rates.example'+path,{method:'POST',headers:{Origin:origin}});}
const quote=(direction='mmk_thb',rate=724,time=now)=>({id:'daily-'+direction,label:direction,direction,rate_micros:Math.round(100000000000/rate),source_name:'reference',source_url:'',payout_method:'bank',note:'',source_checked:true,flat_fee_minor:0,fee_bps:0,observed_at:new Date(time).toISOString(),valid_until:new Date(time+86400000).toISOString()});
async function publish(db,quotes=[quote()],notice='',kind='rates'){
 const result=db.sqlite.prepare('INSERT INTO revisions(payload,published_at) VALUES(?,?)').run(JSON.stringify({quotes,notice}),new Date(now).toISOString());
 await eventInsert(db,kind,crypto.randomUUID(),now,'id=?',[Number(result.lastInsertRowid)]).run();return Number(result.lastInsertRowid);
}
async function subscribe(db,sub=subscription().sub,deviceToken=token){return pushApi(request('/api/v2/push/subscribe'),db,'/api/v2/push/subscribe',{subscription:sub,token:deviceToken},{telegramKey:secret});}
const accepted=async()=>new Response(null,{status:201});
function decrypt(body,client){
 const b=Buffer.from(body),salt=b.subarray(0,16),server=b.subarray(21,86);assert.equal(b.readUInt32BE(16),4096);assert.equal(b[20],65);
 const ua=client.dh.getPublicKey(),ikm=Buffer.from(hkdfSync('sha256',client.dh.computeSecret(server),client.auth,Buffer.concat([Buffer.from('WebPush: info\0'),ua,server]),32));
 const key=Buffer.from(hkdfSync('sha256',ikm,salt,Buffer.from('Content-Encoding: aes128gcm\0'),16)),iv=Buffer.from(hkdfSync('sha256',ikm,salt,Buffer.from('Content-Encoding: nonce\0'),12));
 const decipher=createDecipheriv('aes-128-gcm',key,iv);decipher.setAuthTag(b.subarray(-16));const plain=Buffer.concat([decipher.update(b.subarray(86,-16)),decipher.final()]);assert.equal(plain.at(-1),2);return JSON.parse(plain.subarray(0,-1).toString());
}
test('Web Push encryption decrypts independently using Node crypto and VAPID signatures verify for the exact push-service origin',async()=>{
 const client=subscription(),keys=await vapidKeys(),payload={title:'ဘတ်ဈေး',body:'ကျပ် ၁ သိန်း → 724 ဘတ်',expires_at:now+60000};
 const req=await webPushRequest(client.sub,payload,keys,now);assert.deepEqual(decrypt(req.body,client),payload);assert.equal(req.headers.TTL,'60');assert.equal(req.redirect,'error');
 const jwt=req.headers.Authorization.match(/^vapid t=([^,]+), k=(.+)$/);assert.equal(jwt[2],keys.publicKey);const parts=jwt[1].split('.');const claims=JSON.parse(Buffer.from(parts[1],'base64url'));assert.equal(claims.aud,'https://fcm.googleapis.com');assert.equal(claims.exp,Math.floor(now/1000)+3600);
 const pub={...keys.privateKey};delete pub.d;assert.ok(verify('sha256',Buffer.from(parts[0]+'.'+parts[1]),{key:createPublicKey({key:pub,format:'jwk'}),dsaEncoding:'ieee-p1363'},Buffer.from(parts[2],'base64url')));
});
test('Only real push-service HTTPS endpoints are accepted, and VAPID private keys remain encrypted',async()=>{
 for(const url of ['http://fcm.googleapis.com/fcm/send/x','https://localhost/x','https://127.0.0.1/x','https://fcm.googleapis.com.evil.test/x','https://fcm.googleapis.com:444/x','https://x:y@fcm.googleapis.com/x','https://updates.push.services.mozilla.com/'])assert.equal(validPushEndpoint(url),false,url);
 for(const url of ['https://web.push.apple.com/a','https://updates.push.services.mozilla.com/wpush/v2/a','https://wns.notify.windows.com/a'])assert.equal(validPushEndpoint(url),true,url);
 const db=new D1();try{const a=await ensurePushConfig(db,secret),b=await ensurePushConfig(db,secret);assert.equal(a.public_key,b.public_key);const keys=await unseal(a.sealed,secret);assert.ok(!a.sealed.includes(keys.privateKey.d));const pub=await pushApi(new Request('https://rates.example/api/v2/push/config'),db,'/api/v2/push/config',{}, {telegramKey:secret});assert.equal(pub.data.public_key,a.public_key);assert.ok(!JSON.stringify(pub.data).includes(keys.privateKey.d));}finally{db.sqlite.close();}
});
test('Subscription writes require an allowed origin, valid keys and a private management token; subscribers cannot manage another device',async()=>{
 const db=new D1();try{
 const sub=subscription().sub;assert.equal((await pushApi(request('/api/v2/push/subscribe','https://evil.example'),db,'/api/v2/push/subscribe',{subscription:sub,token},{telegramKey:secret})).status,403);
 assert.equal((await subscribe(db,{...sub,endpoint:'https://localhost/internal'})).status,400);assert.equal((await subscribe(db,{...sub,keys:{...sub.keys,auth:'x'}})).status,400);
 const enrolled=await subscribe(db,sub);assert.equal(enrolled.status,200);assert.equal((await subscribe(db,sub,otherToken)).status,403);
 const id=enrolled.data.id;assert.equal((await pushApi(request('/api/v2/push/unsubscribe'),db,'/api/v2/push/unsubscribe',{id,token:otherToken},{telegramKey:secret})).status,403);
 assert.equal((await pushApi(request('/api/v2/push/status'),db,'/api/v2/push/status',{id,token},{telegramKey:secret})).data.active,true);
 await pushApi(request('/api/v2/push/unsubscribe'),db,'/api/v2/push/unsubscribe',{id,token},{telegramKey:secret});assert.equal(db.sqlite.prepare('SELECT active FROM push_subscribers').get().active,0);
 }finally{db.sqlite.close();}
});
test('New opt-ins never receive old publications; every new explicit publication queues once even for an unchanged same-day price',async()=>{
 const db=new D1();try{await publish(db);await subscribe(db);await queuePush(db,now);assert.equal(db.sqlite.prepare('SELECT COUNT(*) AS n FROM push_outbox').get().n,0);
 await publish(db);await queuePush(db,now);await queuePush(db,now);assert.equal(db.sqlite.prepare('SELECT COUNT(*) AS n FROM push_outbox').get().n,1);
 let sent=0;await Promise.all([deliverPush(db,secret,async()=>{sent++;return accepted();},()=>now),deliverPush(db,secret,async()=>{sent++;return accepted();},()=>now)]);assert.equal(sent,1);
 await publish(db);await queuePush(db,now);await deliverPush(db,secret,async()=>{sent++;return accepted();},()=>now);assert.equal(sent,2);
 }finally{db.sqlite.close();}
});
test('Announcements notify without refreshing rate observation times or leaking private amounts, while private drafts do not queue',async()=>{
 const db=new D1();try{const q=quote();await publish(db,[q]);db.sqlite.prepare('INSERT INTO draft VALUES(1,?,7)').run(JSON.stringify({quotes:[q],notice:'private'}));await subscribe(db);const result=await publishAnnouncement(db,'ကြေညာစာ အစစ်',1,7,now);assert.equal(result.status,200);
 const latest=JSON.parse(db.sqlite.prepare('SELECT payload FROM revisions ORDER BY id DESC LIMIT 1').get().payload);assert.equal(latest.quotes[0].observed_at,q.observed_at);assert.equal(JSON.parse(db.sqlite.prepare('SELECT payload FROM draft').get().payload).notice,'private');
 await queuePush(db,now);const clientMessages=[];const client=subscription();const event=db.sqlite.prepare('SELECT * FROM notification_events ORDER BY revision DESC LIMIT 1').get();const payload=pushPayload(event,now);assert.equal(payload.body,'ကြေညာစာ အစစ်');assert.equal(payload.kind,'announcement');assert.ok(!JSON.stringify(payload).includes('budget'));
 await deliverPush(db,secret,async(url,opts)=>{clientMessages.push(url);return accepted();},()=>now);assert.equal(clientMessages.length,1);
 }finally{db.sqlite.close();}
});
test('Retries honor backoff; stale, deleted, superseded, stopped and expired subscriptions cannot receive old messages',async()=>{
 const db=new D1();try{await subscribe(db);await publish(db);await queuePush(db,now);let sent=0;
 await deliverPush(db,secret,async()=>{sent++;return new Response(null,{status:429,headers:{'Retry-After':'120'}});},()=>now);await deliverPush(db,secret,async()=>{sent++;return accepted();},()=>now+1000);assert.equal(sent,1);
 await publish(db,[quote('mmk_thb',725)]);await queuePush(db,now);await deliverPush(db,secret,async()=>{sent++;return accepted();},()=>now+121000);assert.equal(sent,2);assert.equal(db.sqlite.prepare('SELECT COUNT(*) AS n FROM push_outbox WHERE status=2').get().n,1);
 await publish(db,[quote('mmk_thb',726)]);await queuePush(db,now);db.sqlite.prepare('DELETE FROM revisions WHERE id=3').run();await deliverPush(db,secret,async()=>{throw Error('deleted message');},()=>now);
 await publish(db,[quote('mmk_thb',727)]);await queuePush(db,now);await deliverPush(db,secret,async()=>new Response(null,{status:410}),()=>now);assert.equal(db.sqlite.prepare('SELECT active FROM push_subscribers').get().active,0);
 }finally{db.sqlite.close();}
});
test('Expired and removed announcements are discarded and an exhausted retry cannot remain pending forever',async()=>{
 const db=new D1();try{await subscribe(db);await publish(db,[quote()],'notice','announcement');await queuePush(db,now);await publish(db,[quote()],'','rates');await deliverPush(db,secret,async()=>{throw Error('removed announcement');},()=>now);assert.equal(db.sqlite.prepare('SELECT status FROM push_outbox').get().status,2);
 await queuePush(db,now);db.sqlite.prepare('UPDATE push_outbox SET attempts=4 WHERE status=0').run();await deliverPush(db,secret,async()=>new Response(null,{status:503}),()=>now);assert.equal(db.sqlite.prepare('SELECT COUNT(*) AS n FROM push_outbox WHERE status=0').get().n,0);
 }finally{db.sqlite.close();}
});
test('Phone endpoints expose CORS preflight but cannot grant admin access or publish an announcement',async()=>{
 const db=new D1();try{const preflight=await handle(new Request('https://rates.example/api/v2/push/subscribe',{method:'OPTIONS'}),db,null,'',{telegramKey:secret});assert.equal(preflight.status,204);assert.match(preflight.headers.get('Access-Control-Allow-Methods'),/POST/);
 const res=await handle(new Request('https://rates.example/api/admin/announcement',{method:'POST',headers:{Origin:'https://rates.example','X-Admin-Request':'1'},body:JSON.stringify({notice:'bad',expected_version:0,expected_revision:0})}),db,null,'',{telegramKey:secret});assert.equal(res.status,401);assert.equal(db.sqlite.prepare('SELECT COUNT(*) AS n FROM revisions').get().n,0);
 }finally{db.sqlite.close();}
});
test('A later undo or administrative rollback without a new notification event cannot deliver a queued obsolete price',async()=>{
 const db=new D1();try{await subscribe(db);const original=[quote('mmk_thb',724)];await publish(db,original);await publish(db,[quote('mmk_thb',780)]);await queuePush(db,now);
 db.sqlite.prepare('INSERT INTO revisions(payload,published_at) VALUES(?,?)').run(JSON.stringify({quotes:original,notice:''}),new Date(now).toISOString());
 let sent=0;await deliverPush(db,secret,async()=>{sent++;return accepted();},()=>now);assert.equal(sent,0);assert.equal(db.sqlite.prepare('SELECT status FROM push_outbox').get().status,2);
 }finally{db.sqlite.close();}
});
test('Each independently entered direction keeps its own observation time in a phone notification',()=>{
 const older=quote('mmk_thb',724,now-3600000),newer=quote('thb_mmk',748,now);
 const event={revision:9,kind:'rates',payload:JSON.stringify({quotes:[older,newer],notice:''}),expires_at:now+86400000};
 const payload=pushPayload(event,now);
 for(const q of [older,newer])assert.ok(payload.body.includes(new Date(q.observed_at).toLocaleString('en-GB',{timeZone:'Asia/Bangkok',day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'})));
 assert.match(payload.body,/724/);assert.match(payload.body,/748/);assert.equal(payload.expires_at,Date.parse(older.valid_until));
});
