import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync,readdirSync} from 'node:fs';
import {subscriberCommand,queueAlerts,deliverAlerts} from '../lib/alerts.mjs';
import {handle} from '../lib/api.mjs';
import {seal,scheduleAlerts} from '../lib/telegram.mjs';
class D1 {
 constructor(){this.sqlite=new DatabaseSync(':memory:');for(const file of readdirSync(new URL('../drizzle',import.meta.url)).filter(f=>f.endsWith('.sql')).sort())this.sqlite.exec(readFileSync(new URL('../drizzle/'+file,import.meta.url),'utf8'));}
 prepare(sql){const stmt=this.sqlite.prepare(sql),wrap=(v=[])=>({bind:(...args)=>wrap(args),first:async()=>stmt.get(...v)||null,all:async()=>({results:stmt.all(...v)}),run:async()=>({meta:{changes:Number(stmt.run(...v).changes)}})});return wrap();}
 async batch(items){this.sqlite.exec('BEGIN');try{const out=[];for(const item of items)out.push(await item.run());this.sqlite.exec('COMMIT');return out;}catch(e){this.sqlite.exec('ROLLBACK');throw e;}}
}
const bot={username:'test_bot'}, key='ab'.repeat(32), now=Date.parse('2026-10-17T12:00:00Z');
const quote=(direction,rate,time=now)=>({id:'daily-'+direction,label:direction,direction,rate_micros:Math.round(100000/rate*1e6),source_name:'reference',source_url:'',payout_method:'မဖော်ပြထားပါ',note:'',source_checked:true,flat_fee_minor:0,fee_bps:0,observed_at:new Date(time).toISOString(),valid_until:new Date(time+86400000).toISOString()});
const publish=(db,quotes)=>db.sqlite.prepare('INSERT INTO revisions(payload,published_at) VALUES(?,?)').run(JSON.stringify({quotes,notice:''}),new Date(now).toISOString());
const count=(db)=>db.sqlite.prepare('SELECT COUNT(*) AS count FROM alert_outbox').get().count;
test('news tracks only explicit direction changes, suppresses same-day unchanged prices, and stop cancels pending sends',async()=>{
 const db=new D1();try{
  const q=quote('thb_mmk',748);publish(db,[q]);
  await subscriberCommand(db,bot,'7','/start news_thb_mmk');
  publish(db,[q,quote('mmk_thb',724)]);await queueAlerts(db,bot.username,now);assert.equal(count(db),0);
  publish(db,[{...q,observed_at:new Date(now+1000).toISOString()}]);await queueAlerts(db,bot.username,now+1000);assert.equal(count(db),0);
  publish(db,[quote('thb_mmk',740)]);await queueAlerts(db,bot.username,now);assert.equal(count(db),1);
  await queueAlerts(db,bot.username,now);assert.equal(count(db),1);
  await subscriberCommand(db,bot,'7','/stop');let sent=0;await deliverAlerts(db,'token',bot.username,async()=>{sent++;return {json:async()=>({ok:true})};},now);assert.equal(sent,0);assert.equal(db.sqlite.prepare('SELECT status FROM alert_outbox').get().status,2);
 }finally{db.sqlite.close();}
});
test('target alerts use opposite threshold inequalities without inventing a reverse price and fire once after successful delivery',async()=>{
 const db=new D1();try{
  publish(db,[quote('thb_mmk',748),quote('mmk_thb',724)]);
  await subscriberCommand(db,bot,'1','/start watch_thb_mmk_74000');await subscriberCommand(db,bot,'2','/start watch_mmk_thb_73000');
  publish(db,[quote('thb_mmk',745),quote('mmk_thb',728)]);await queueAlerts(db,bot.username,now);assert.equal(count(db),0);
  publish(db,[quote('thb_mmk',740),quote('mmk_thb',730)]);await queueAlerts(db,bot.username,now);assert.equal(count(db),2);
  const messages=[];await deliverAlerts(db,'token',bot.username,async(url,opts)=>{messages.push(JSON.parse(opts.body));return {json:async()=>({ok:true})};},now);
  assert.equal(messages.length,2);assert.match(messages[0].text,/740/);assert.match(messages[1].text,/730/);
  assert.equal(db.sqlite.prepare('SELECT COUNT(*) AS count FROM alert_subscribers WHERE active=1').get().count,0);
  publish(db,[quote('thb_mmk',735),quote('mmk_thb',735)]);await queueAlerts(db,bot.username,now);assert.equal(count(db),2);
 }finally{db.sqlite.close();}
});
test('delivery retry is durable, follows Telegram backoff, and stale or superseded subscription messages cannot be sent',async()=>{
 const db=new D1();try{
  await subscriberCommand(db,bot,'1','/start news_mmk_thb');publish(db,[quote('mmk_thb',730)]);await queueAlerts(db,bot.username,now);
  let tries=0;await deliverAlerts(db,'token',bot.username,async()=>{tries++;return {json:async()=>({ok:false,error_code:429,parameters:{retry_after:120}})};},now);
  await deliverAlerts(db,'token',bot.username,async()=>{tries++;},now+1000);assert.equal(tries,1);
  await deliverAlerts(db,'token',bot.username,async()=>{tries++;return {json:async()=>({ok:true})};},now+121000);assert.equal(tries,2);
  publish(db,[quote('mmk_thb',731)]);await queueAlerts(db,bot.username,now);
  await subscriberCommand(db,bot,'1','/start news_thb_mmk');await deliverAlerts(db,'token',bot.username,async()=>{throw Error('superseded delivery');},now);
  publish(db,[quote('thb_mmk',740)]);await queueAlerts(db,bot.username,now);await deliverAlerts(db,'token',bot.username,async()=>{throw Error('expired delivery');},now+86400001);
  assert.equal(db.sqlite.prepare('SELECT COUNT(*) AS count FROM alert_outbox WHERE status=2').get().count,2);
 }finally{db.sqlite.close();}
});
test('public Telegram subscribers cannot publish, acquire owner rights, or change a draft; command retries are idempotent',async()=>{
 const db=new D1();try{
  const secret='secret', token='123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZ_1234567890';
  db.sqlite.prepare('INSERT INTO telegram_settings(id,sealed,username,owner_id,generation) VALUES(1,?,?,?,0)').run(await seal({token,webhookSecret:secret,enabled:true},key),bot.username,'42');
  db.sqlite.prepare('INSERT INTO draft(id,payload,version) VALUES(1,?,4)').run(JSON.stringify({quotes:[],notice:'owner draft'}));
  const call=async(id,text)=>{
   const req=new Request('https://rates.example/api/telegram/webhook',{method:'POST',headers:{'X-Telegram-Bot-Api-Secret-Token':secret},body:JSON.stringify({update_id:id,message:{message_id:id,from:{id:99},chat:{id:99,type:'private'},text}})});
   return handle(req,db,null,'',{telegramKey:key,fetcher:async()=>({json:async()=>({ok:true})})});
  };
  await call(1,'/start news_mmk_thb');await call(1,'/start news_mmk_thb');assert.equal(db.sqlite.prepare('SELECT version FROM alert_subscribers').get().version,1);
  await call(2,'726');assert.equal(db.sqlite.prepare('SELECT COUNT(*) AS count FROM revisions').get().count,0);
  assert.equal(db.sqlite.prepare('SELECT owner_id FROM telegram_settings').get().owner_id,'42');assert.equal(db.sqlite.prepare('SELECT version FROM draft').get().version,4);
 }finally{db.sqlite.close();}
});
test('Admin can update one direction while retaining an unchanged stale opposite quote, but cannot edit a stale quote into a fresh-looking publication',async()=>{
 const db=new D1();try{
  db.sqlite.prepare('INSERT INTO admin_owner(id,user_id) VALUES(1,?)').run('owner');
  const time=Date.now(),stale=quote('mmk_thb',724,time-172800000),fresh=quote('thb_mmk',740,time);
  publish(db,[stale]);db.sqlite.prepare('INSERT INTO draft(id,payload,version) VALUES(1,?,1)').run(JSON.stringify({notice:'',quotes:[stale,fresh]}));
  const call=async()=>{const req=new Request('https://rates.example/api/admin/publish',{method:'POST',headers:{Origin:'https://rates.example','X-Admin-Request':'1'},body:JSON.stringify({expected_version:1})});return handle(req,db,{userId:'owner'},'');};
  const result=await call();assert.equal(result.status,200);const sheet=(await result.json()).published;assert.equal(sheet.quotes[0].observed_at,stale.observed_at);
  db.sqlite.prepare('UPDATE draft SET version=1,payload=? WHERE id=1').run(JSON.stringify({notice:'',quotes:[{...stale,rate_micros:111111111},fresh]}));
  assert.equal((await call()).status,400);
 }finally{db.sqlite.close();}
});

test('Frequent public reads share a cooldown while confirmed publication and owner retry bypass it',async()=>{
 let reads=0;const tasks=[];
 const db={prepare:()=>({first:async()=>{reads++;return null;}})},runtime={waitUntil:task=>tasks.push(task)};
 scheduleAlerts(db,runtime,true);scheduleAlerts(db,runtime);scheduleAlerts(db,runtime);scheduleAlerts(db,runtime,true);
 await Promise.all(tasks);assert.equal(reads,2);assert.equal(tasks.length,2);
});
