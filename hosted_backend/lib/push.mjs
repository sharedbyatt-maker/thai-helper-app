import {seal,unseal} from './secrets.mjs';
import {vapidKeys,validatePushSubscription,webPushRequest} from './web-push-crypto.mjs';
import {pushPayload,APP_URL} from './notification-events.mjs';
const hash=async text=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(text))),b=>b.toString(16).padStart(2,'0')).join('');
export async function ensurePushConfig(db,secret){
 if(!/^[a-f0-9]{64}$/.test(secret||''))throw new Error('Push encryption unavailable');
 let row=await db.prepare('SELECT * FROM push_config WHERE id=1').first();
 if(!row){const keys=await vapidKeys();await db.prepare('INSERT OR IGNORE INTO push_config(id,public_key,sealed) VALUES(1,?,?)').bind(keys.publicKey,await seal(keys,secret)).run();row=await db.prepare('SELECT * FROM push_config WHERE id=1').first();}
 return row;
}
const tokenOK=token=>typeof token==='string'&&/^[a-f0-9]{64}$/.test(token);
export async function pushApi(req,db,path,data,runtime={}){
 if(path==='/api/v2/push/config'&&req.method==='GET'){
  try{const row=await ensurePushConfig(db,runtime.telegramKey);return {status:200,data:{available:true,public_key:row.public_key}};}catch{return {status:200,data:{available:false}};}
 }
 if(req.method!=='POST')return {status:404,data:{error:'Not found'}};
 const origin=req.headers.get('Origin');
 if(!origin||![new URL(APP_URL).origin,'https://sharedbyatt-maker.github.io',new URL(req.url).origin].includes(origin))return {status:403,data:{error:'Origin rejected'}};
 if(!data||!tokenOK(data.token))return {status:400,data:{error:'Invalid device token'}};
 const manage=await hash(data.token);
 if(path==='/api/v2/push/subscribe'){
  let sub;try{sub=await validatePushSubscription(data.subscription);}catch{return {status:400,data:{error:'ဒီ browser ရဲ့ noti ချိတ်ဆက်မှု မပြည့်စုံသေးဘူး။'}};}
  const id=await hash(sub.endpoint),old=await db.prepare('SELECT manage_hash FROM push_subscribers WHERE id=?').bind(id).first();
  if(old&&old.manage_hash!==manage)return {status:403,data:{error:'Device ownership mismatch'}};
  const revision=await db.prepare('SELECT COALESCE(MAX(id),0) AS id FROM revisions').first();
  const now=Date.now();
  await ensurePushConfig(db,runtime.telegramKey);
  const result=await db.prepare(`INSERT INTO push_subscribers(id,endpoint,keys_json,manage_hash,active,version,start_revision,created_at,updated_at) SELECT ?,?,?,?,1,1,?,?,? WHERE (SELECT COUNT(*) FROM push_subscribers)<10000 OR EXISTS(SELECT 1 FROM push_subscribers WHERE id=?) ON CONFLICT(id) DO UPDATE SET endpoint=excluded.endpoint,keys_json=excluded.keys_json,active=1,version=push_subscribers.version+1,start_revision=excluded.start_revision,updated_at=excluded.updated_at WHERE push_subscribers.manage_hash=excluded.manage_hash`).bind(id,sub.endpoint,JSON.stringify(sub.keys),manage,revision.id,now,now,id).run();
  return result.meta.changes?{status:200,data:{ok:true,id,active:true}}:{status:429,data:{error:'Noti ချိတ်ဆက်မှု ခဏမရသေးဘူး။ နောက်မှ ပြန်စမ်းပါ။'}};
 }
 if(typeof data.id!=='string'||!/^[a-f0-9]{64}$/.test(data.id))return {status:400,data:{error:'Invalid device'}};
 const row=await db.prepare('SELECT * FROM push_subscribers WHERE id=? AND manage_hash=?').bind(data.id,manage).first();
 if(!row)return {status:403,data:{error:'Device ownership mismatch'}};
 if(path==='/api/v2/push/status')return {status:200,data:{active:row.active===1}};
 if(path==='/api/v2/push/unsubscribe'){
  await db.batch([db.prepare("UPDATE push_subscribers SET active=0,endpoint='',keys_json='{}',version=version+1,updated_at=? WHERE id=? AND manage_hash=?").bind(Date.now(),row.id,manage),db.prepare('UPDATE push_outbox SET status=2 WHERE subscriber_id=? AND status=0').bind(row.id)]);
  return {status:200,data:{ok:true,active:false}};
 }
 if(path==='/api/v2/push/test'){
  if(!row.active)return {status:409,data:{error:'Noti ကို အရင်ဖွင့်ပေးပါ။'}};
  const testNow=Date.now();
  const claimed=await db.prepare(`INSERT INTO push_outbox(id,subscriber_id,subscription_version,revision,status,attempts,next_attempt,last_error) VALUES(?,?,?,0,1,0,?,'') ON CONFLICT(id) DO UPDATE SET next_attempt=excluded.next_attempt,subscription_version=excluded.subscription_version WHERE push_outbox.next_attempt<=?`).bind('test:'+row.id,row.id,row.version,testNow+15000,testNow).run();
  if(!claimed.meta.changes)return {status:429,data:{error:'ခဏစောင့်ပြီး ပြန်စမ်းပါ။'}};
  const config=await ensurePushConfig(db,runtime.telegramKey),keys=await unseal(config.sealed,runtime.telegramKey);
  try{
   const request=await webPushRequest({endpoint:row.endpoint,keys:JSON.parse(row.keys_json)},{title:'ဘတ်ဈေး 🔔',body:'Noti ချိတ်ဆက်ပြီးပြီနော်။',url:APP_URL,tag:'bahtzay-test'},keys);
   const response=await (runtime.fetcher||fetch)(row.endpoint,request);
   return response.status>=200&&response.status<300?{status:200,data:{ok:true}}:{status:503,data:{error:'ဖုန်းကို ပို့မရသေးဘူး။ Browser noti ခွင့်ကို ပြန်စစ်ပေးပါ။'}};
  }catch{return {status:503,data:{error:'လိုင်းမရသေးဘူး။ ခဏနေ ပြန်စမ်းပေးပါ။'}};}
 }
 return {status:404,data:{error:'Not found'}};
}
function eventCurrent(event,latest){
 if(!latest)return false;
 const posted=JSON.parse(event.payload),current=JSON.parse(latest.payload);
 if(event.kind==='announcement')return current.notice===posted.notice;
 const a=posted.quotes||[],b=current.quotes||[];
 return a.length===b.length&&a.every(q=>b.some(x=>x.id===q.id&&x.direction===q.direction&&['rate_micros','flat_fee_minor','fee_bps','observed_at','valid_until'].every(k=>x[k]===q[k])));
}
export async function queuePush(db,now=Date.now()){
 const events=(await db.prepare(`SELECT e.* FROM notification_events e JOIN revisions r ON r.id=e.revision WHERE e.expires_at>? AND NOT EXISTS(SELECT 1 FROM notification_events n JOIN revisions nr ON nr.id=n.revision WHERE n.kind=e.kind AND n.revision>e.revision) ORDER BY e.revision`).bind(now).all()).results;
 for(const event of events){
  const payload=pushPayload(event,now);if(!payload)continue;
  const latest=await db.prepare('SELECT id,payload FROM revisions ORDER BY id DESC LIMIT 1').first();if(!eventCurrent(event,latest))continue;
  const subscribers=(await db.prepare(`SELECT s.id,s.version FROM push_subscribers s WHERE active=1 AND start_revision<? AND NOT EXISTS(SELECT 1 FROM push_outbox o WHERE o.subscriber_id=s.id AND o.subscription_version=s.version AND o.revision=?) LIMIT 100`).bind(event.revision,event.revision).all()).results;
  if(subscribers.length)await db.batch(subscribers.map(s=>db.prepare(`INSERT OR IGNORE INTO push_outbox(id,subscriber_id,subscription_version,revision,status,attempts,next_attempt) SELECT ?,?,?,?,0,0,0 WHERE EXISTS(SELECT 1 FROM push_subscribers WHERE id=? AND version=? AND active=1)`).bind(`${s.id}:${s.version}:${event.revision}`,s.id,s.version,event.revision,s.id,s.version)));
 }
}
export async function deliverPush(db,secret,fetcher=fetch,clock=Date.now){
 const now=clock();
 await db.prepare(`UPDATE push_outbox SET status=2 WHERE status=0 AND (attempts>=5 OR NOT EXISTS(SELECT 1 FROM push_subscribers s WHERE s.id=push_outbox.subscriber_id AND s.version=push_outbox.subscription_version AND s.active=1) OR NOT EXISTS(SELECT 1 FROM revisions r WHERE r.id=push_outbox.revision))`).run();
 const config=await db.prepare('SELECT * FROM push_config WHERE id=1').first();if(!config)return 0;
 const keys=await unseal(config.sealed,secret);
 const rows=(await db.prepare(`SELECT o.*,s.endpoint,s.keys_json,e.payload,e.kind,e.expires_at FROM push_outbox o JOIN push_subscribers s ON s.id=o.subscriber_id AND s.version=o.subscription_version JOIN notification_events e ON e.revision=o.revision WHERE o.status=0 AND o.attempts<5 AND o.next_attempt<=? AND s.active=1 ORDER BY o.revision LIMIT 20`).bind(now).all()).results;
 const deadline=now+18000;
 for(let start=0;start<rows.length&&clock()<deadline;start+=4){await Promise.all(rows.slice(start,start+4).map(async item=>{
  const time=clock(),payload=pushPayload(item,time);
  const newer=await db.prepare(`SELECT e.revision FROM notification_events e JOIN revisions r ON r.id=e.revision WHERE e.kind=? AND e.revision>? LIMIT 1`).bind(item.kind,item.revision).first();
  const latest=await db.prepare('SELECT id,payload FROM revisions ORDER BY id DESC LIMIT 1').first();
  const obsolete=!eventCurrent(item,latest);
  if(item.expires_at<=time||!payload||newer||obsolete){await db.prepare('UPDATE push_outbox SET status=2 WHERE id=? AND status=0').bind(item.id).run();return;}
  const lease=await db.prepare(`UPDATE push_outbox SET attempts=attempts+1,next_attempt=? WHERE id=? AND status=0 AND next_attempt<=? AND EXISTS(SELECT 1 FROM push_subscribers WHERE id=? AND version=? AND active=1) AND EXISTS(SELECT 1 FROM revisions WHERE id=?) AND (SELECT MAX(id) FROM revisions)=?`).bind(time+60000,item.id,time,item.subscriber_id,item.subscription_version,item.revision,latest.id).run();
  if(!lease.meta.changes)return;
  let status=0,error='',delay=Math.min(1800,60*2**item.attempts);
  try{
   const response=await fetcher(item.endpoint,await webPushRequest({endpoint:item.endpoint,keys:JSON.parse(item.keys_json)},payload,keys,time));
   if(response.status>=200&&response.status<300)status=1;
   else if(response.status===404||response.status===410){status=2;await db.prepare("UPDATE push_subscribers SET active=0,endpoint='',keys_json='{}',updated_at=? WHERE id=? AND version=?").bind(time,item.subscriber_id,item.subscription_version).run();}
   else{error='HTTP '+response.status;const raw=response.headers?.get('Retry-After');const after=raw?(Number(raw)||Math.ceil((Date.parse(raw)-time)/1000)):0;if(Number.isFinite(after)&&after>0)delay=Math.max(delay,after);}
  }catch{error='Network retry';}
  if(item.attempts>=4&&status===0)status=2;
  await db.prepare('UPDATE push_outbox SET status=?,next_attempt=?,last_error=? WHERE id=?').bind(status,time+delay*1000,error,item.id).run();
 }));}
 await db.prepare('DELETE FROM push_subscribers WHERE active=0 AND updated_at<?').bind(now-30*86400000).run();
 await db.prepare('DELETE FROM push_outbox WHERE revision IN(SELECT revision FROM notification_events WHERE expires_at<?) AND status<>0').bind(now-30*86400000).run();
 return rows.length;
}
let lastAttempt=0;
export function schedulePush(db,runtime={},force=false){
 if(!runtime.waitUntil)return;
 const now=Date.now();if(!force&&now-lastAttempt<60000)return;lastAttempt=now;
 runtime.waitUntil((async()=>{await db.prepare('DELETE FROM push_subscribers WHERE active=0 AND updated_at<?').bind(Date.now()-30*86400000).run();const active=await db.prepare('SELECT COUNT(*) AS n FROM push_subscribers WHERE active=1').first();if(!active.n)return;const deadline=Date.now()+20000;for(let i=0;i<5&&Date.now()<deadline;i++){await queuePush(db);if(!await deliverPush(db,runtime.telegramKey,runtime.fetcher||fetch))break;}})().catch(()=>console.error('Phone notifications deferred')));
}

// Counts are push-service results, never read receipts. No endpoints or device secrets leave this API.
export async function pushHistory(db){
 const events=(await db.prepare('SELECT * FROM notification_events ORDER BY revision DESC LIMIT 30').all()).results;
 const rows=[];
 for(const event of events){
  const counts=await db.prepare(`SELECT COUNT(*) AS queued,SUM(CASE WHEN attempts>0 THEN 1 ELSE 0 END) AS attempted,SUM(CASE WHEN status=1 THEN 1 ELSE 0 END) AS accepted,SUM(CASE WHEN status=0 THEN 1 ELSE 0 END) AS pending,SUM(CASE WHEN status=2 AND attempts>0 THEN 1 ELSE 0 END) AS failed,SUM(CASE WHEN status=2 AND attempts=0 THEN 1 ELSE 0 END) AS skipped FROM push_outbox WHERE revision=?`).bind(event.revision).first();
  rows.push({revision:event.revision,created_at:event.created_at,preview:pushPayload(event,event.created_at),counts});
 }
 return {events:rows};
}
export async function ownerPushTest(db,data,runtime={}){
 let sub;try{sub=await validatePushSubscription(data?.subscription);}catch{return {status:400,data:{error:'ဒီစက်ရဲ့ noti ချိတ်ဆက်မှု လိုပါတယ်။'}};}
 const config=await ensurePushConfig(db,runtime.telegramKey),now=Date.now();
 // One owner test per minute across devices; atomic claim also blocks double-clicks.
 const claim=await db.prepare(`INSERT INTO push_outbox(id,subscriber_id,subscription_version,revision,status,attempts,next_attempt) VALUES('owner-test','owner',0,0,1,0,?) ON CONFLICT(id) DO UPDATE SET next_attempt=excluded.next_attempt WHERE push_outbox.next_attempt<=?`).bind(now+60000,now).run();
 if(!claim.meta.changes)return {status:429,data:{error:'တစ်မိနစ်စောင့်ပြီး ပြန်စမ်းပါ။'}};
 try{
  const keys=await unseal(config.sealed,runtime.telegramKey);
  const payload={title:'ဘတ်ဈေး 🔔',body:'ဒီ Admin စက်ဆီပဲ စမ်းပို့ထားပါတယ်။',url:APP_URL+'?tab=rates',tag:'bahtzay-owner-test',expires_at:now+60000};
  const response=await (runtime.fetcher||fetch)(sub.endpoint,await webPushRequest(sub,payload,keys,now));
  return response.ok?{status:200,data:{ok:true}}:{status:503,data:{error:'Push service က လက်မခံသေးပါ။'}};
 }catch{return {status:503,data:{error:'စမ်းသပ်ပို့မှု မအောင်မြင်ပါ။'}};}
}
