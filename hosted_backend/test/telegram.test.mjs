import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync,readdirSync} from 'node:fs';
import {handle} from '../lib/api.mjs';
import {parseRates,seal,unseal} from '../lib/telegram.mjs';
class D1 {
 constructor(){this.sqlite=new DatabaseSync(':memory:');for(const f of readdirSync(new URL('../drizzle',import.meta.url)).filter(f=>f.endsWith('.sql')).sort())this.sqlite.exec(readFileSync(new URL('../drizzle/'+f,import.meta.url),'utf8'));}
 prepare(sql){const s=this.sqlite.prepare(sql),wrap=(v=[])=>({bind:(...args)=>wrap(args),first:async()=>s.get(...v)||null,all:async()=>({results:s.all(...v)}),run:async()=>{const r=s.run(...v);return {meta:{changes:Number(r.changes)}};}});return wrap();}
 async batch(stmts){let release;const previous=this.tail||Promise.resolve();this.tail=new Promise(resolve=>release=resolve);await previous;try{return await this.transact(stmts);}finally{release();}}
 async transact(stmts){this.sqlite.exec('BEGIN');try{const out=[];for(const stmt of stmts)out.push(await stmt.run());this.sqlite.exec('COMMIT');return out;}catch(e){this.sqlite.exec('ROLLBACK');throw e;}}
}
const key='ab'.repeat(32),token='123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZ_1234567890',origin='https://rates.example';
const user={userId:'owner',email:'owner@test'};
function fixture(){const db=new D1(),calls=[];const runtime={telegramKey:key,fetcher:async(url,options)=>{calls.push({url,data:JSON.parse(options.body)});return {json:async()=>({ok:true,result:url.endsWith('/getMe')?{is_bot:true,username:'bahtzay_test_bot'}:true})};}};return {db,calls,runtime};}
async function call(f,path,method='GET',data,actor=user,headers={}){
 const r=await handle(new Request(origin+path,{method,headers:{Origin:origin,'X-Admin-Request':'1','Content-Type':'application/json',...headers},...(data===undefined?{}:{body:JSON.stringify(data)})}),f.db,actor,'owner@test',f.runtime);
 return {status:r.status,data:await r.json()};
}
async function setup(f){await call(f,'/api/admin/login','POST',{});await call(f,'/api/admin/state');const s=await call(f,'/api/admin/telegram','POST',{token,source_name:'Test Source',source_url:'https://example.com/source',direction:'mmk_thb'});assert.equal(s.status,200);return f.calls.find(x=>x.url.endsWith('/setWebhook')).data.secret_token;}
async function message(f,secret,id,text,actor=42,callback){return call(f,'/api/telegram/webhook','POST',{update_id:id,...(callback?{callback_query:{id:'callback-'+id,from:{id:actor},message:{message_id:1,chat:{id:actor,type:'private'}},data:callback}}:{message:{message_id:id,from:{id:actor},chat:{id:actor,type:'private'},...(text!==null?{text}:{photo:[{}]})}})},null,{'X-Telegram-Bot-Api-Secret-Token':secret});}
async function pair(f,secret){const p=await call(f,'/api/admin/telegram/pair','POST',{});const param=new URL(p.data.url).searchParams.get('start');const r=await message(f,secret,1,'/start '+param);assert.match(r.data.text,/ချိတ်ဆက်ပြီး/);return param;}
const stk=`Now update ဘတ်ဈေး\nကျပ်ပေး ဘတ်ယူ\n3 သိန်းအထက်ဈေး 724\n10 အထက်ဈေး 726\n100 အထက်ဈေး 727\nဘတ်ပေး: - ကျပ်ယူ 748\nတစ်သိန်းအောက် မရောင်းပါ`;
const kumar=`Bank transfer\nSelling (ကျပ်ပေး ဘတ်ယူ)\n10သိန်းအထက် 728\n3သိန်းအထက် 726\n(100-500အထက်-729-730)\nBuying (ဘတ်ပေး ကျပ်ယူ)\n755`;
test('source samples parse directions and choices without tiers or selecting a range',()=>{
 assert.deepEqual(parseRates(stk).candidates,[{rate:724,direction:'mmk_thb'},{rate:726,direction:'mmk_thb'},{rate:727,direction:'mmk_thb'},{rate:748,direction:'thb_mmk'}]);
 const k=parseRates(kumar);assert.equal(k.range,true);assert.deepEqual(k.candidates.map(q=>q.rate),[728,726,755]);
 assert.deepEqual(parseRates('၇၂၆').candidates,[{rate:726,direction:'mmk_thb'}]);
 assert.equal(parseRates('ဖုန်း 09123456789').candidates.length,0);
 assert.equal(parseRates('ကျပ်ပေး ဘတ်ယူ\n16.10.2026\nPhone 12345').candidates.length,0);
});
test('token is authenticated-encrypted and admin setup is owner-only',async()=>{
 const f=fixture();try{
  const secret=await setup(f);assert.ok(secret);const row=f.db.sqlite.prepare('SELECT * FROM telegram_settings').get();assert.ok(!row.sealed.includes(token));assert.equal((await unseal(row.sealed,key)).token,token);
  await assert.rejects(()=>unseal(row.sealed,'cd'.repeat(32)));
  const status=await call(f,'/api/admin/telegram');assert.equal(JSON.stringify(status).includes(token),false);assert.equal(status.data.paired,false);
  assert.equal((await call(f,'/api/admin/telegram','GET',undefined,null)).status,401);
  assert.equal((await call(f,'/api/admin/telegram','POST',{token},{userId:'intruder'})).status,403);
  assert.equal((await call(f,'/api/admin/telegram','POST',{},user,{Origin:'https://evil.example'})).status,403);
 }finally{f.db.sqlite.close();}
});
test('webhook secret, expiring pairing and owner isolation',async()=>{
 const f=fixture();try{
  const secret=await setup(f);
  const bad=await handle(new Request(origin+'/api/telegram/webhook',{method:'POST',body:'{}'}),f.db,null,'',f.runtime);assert.equal(bad.status,403);
  await message(f,secret,2,'726');assert.equal((await call(f,'/api/v2/rates')).data.quotes.length,0);
  const nonce=await pair(f,secret);await message(f,secret,3,'/start '+nonce,99);assert.equal((await call(f,'/api/admin/telegram')).data.owner_id,'42');
  await message(f,secret,4,'726',99);assert.equal((await call(f,'/api/v2/rates')).data.quotes.length,0);
 }finally{f.db.sqlite.close();}
});
test('single text publishes exact units, zeros fees, syncs clean draft, immutable history and retries once',async()=>{
 const f=fixture();try{
  const secret=await setup(f);await pair(f,secret);const r=await message(f,secret,10,'ကျပ်ပေး ဘတ်ယူ ၇၂၆');assert.match(r.data.text,/တင်ပြီး/);
  let p=(await call(f,'/api/v2/rates')).data;assert.equal(p.revision,1);assert.equal(p.quotes[0].direction,'mmk_thb');assert.equal(p.quotes[0].rate_micros,Math.round(100000/726*1e6));assert.equal(p.quotes[0].fee_bps,0);assert.equal(p.quotes[0].flat_fee_minor,0);assert.equal(p.quotes[0].source_name,'Test Source');
  assert.equal((await call(f,'/api/admin/state')).data.draft.quotes[0].rate_micros,p.quotes[0].rate_micros);
  await message(f,secret,10,'ကျပ်ပေး ဘတ်ယူ 726');assert.equal((await call(f,'/api/v2/rates')).data.revision,1);
  await message(f,secret,11,'727');p=(await call(f,'/api/v2/rates')).data;assert.equal(p.revision,2);assert.equal(p.quotes.length,1);
  assert.equal((await call(f,'/api/v2/history')).data.points.length,1);
 }finally{f.db.sqlite.close();}
});
test('multiple rates require exactly one owner choice, stale/reused callback cannot publish again',async()=>{
 const f=fixture();try{
  const secret=await setup(f);await pair(f,secret);await message(f,secret,20,'/stk');
  const r=await message(f,secret,21,stk);const buttons=r.data.reply_markup.inline_keyboard.flat();assert.equal(buttons.length,4);assert.equal((await call(f,'/api/v2/rates')).data.revision,0);
  await message(f,secret,22,null,99,buttons[1].callback_data);assert.equal((await call(f,'/api/v2/rates')).data.revision,0);
  await message(f,secret,23,null,42,buttons[1].callback_data);const p=(await call(f,'/api/v2/rates')).data;assert.equal(p.revision,1);assert.equal(p.quotes[0].source_name,'S.T.K Money Exchange');assert.equal(p.quotes[0].rate_micros,Math.round(100000/726*1e6));
  await message(f,secret,24,null,42,buttons[2].callback_data);assert.equal((await call(f,'/api/v2/rates')).data.revision,1);
 }finally{f.db.sqlite.close();}
});
test('bot preserves unpublished admin draft and invalidates old admin version',async()=>{
 const f=fixture();try{
  const secret=await setup(f);await pair(f,secret);await call(f,'/api/admin/draft','PUT',{expected_version:0,sheet:{notice:'unsaved published work',quotes:[]}});
  await message(f,secret,30,'726');const state=(await call(f,'/api/admin/state')).data;assert.equal(state.draft.notice,'unsaved published work');assert.equal(state.draft_version,2);assert.equal(state.published.quotes.length,1);
  assert.equal((await call(f,'/api/admin/publish','POST',{expected_version:1})).status,409);
 }finally{f.db.sqlite.close();}
});
test('undo restores previous price without refreshing its observation time and cannot undo admin publication',async()=>{
 const f=fixture();try{
  const secret=await setup(f);await pair(f,secret);await message(f,secret,40,'726');const original=(await call(f,'/api/v2/rates')).data.quotes[0];await message(f,secret,41,'727');
  const r=await message(f,secret,42,'/undo');assert.match(r.data.text,/ပြန်ဖျက်ပြီး/);const p=(await call(f,'/api/v2/rates')).data;assert.equal(p.revision,3);assert.equal(p.quotes[0].rate_micros,original.rate_micros);assert.equal(p.quotes[0].observed_at,original.observed_at);
  await message(f,secret,43,'/undo');assert.equal((await call(f,'/api/v2/rates')).data.revision,3);
 }finally{f.db.sqlite.close();}
});
test('photos, ambiguous text, old date and ranges do not silently publish; disconnect blocks webhook',async()=>{
 const f=fixture();try{
  const secret=await setup(f);await pair(f,secret);await message(f,secret,50,null);await message(f,secret,51,'hello');await message(f,secret,52,'2020-01-01\nကျပ်ပေး ဘတ်ယူ 726');
  await message(f,secret,53,kumar);assert.equal((await call(f,'/api/v2/rates')).data.revision,0);
  await call(f,'/api/admin/telegram/disconnect','POST',{});
  const r=await handle(new Request(origin+'/api/telegram/webhook',{method:'POST',headers:{'X-Telegram-Bot-Api-Secret-Token':secret},body:'{}'}),f.db,null,'',f.runtime);assert.equal(r.status,403);
 }finally{f.db.sqlite.close();}
});

test('concurrent webhook updates preserve both revisions and concurrent choices publish only once',async()=>{
 const f=fixture();try{
  const secret=await setup(f);await pair(f,secret);
  await Promise.all([message(f,secret,60,'726'),message(f,secret,61,'727')]);
  assert.equal((await call(f,'/api/v2/rates')).data.revision,2);
  const r=await message(f,secret,62,stk);const choices=r.data.reply_markup.inline_keyboard.flat();
  await Promise.all([message(f,secret,63,null,42,choices[0].callback_data),message(f,secret,64,null,42,choices[1].callback_data)]);
  assert.equal((await call(f,'/api/v2/rates')).data.revision,3);
 }finally{f.db.sqlite.close();}
});
test('expired pairing and pending choices cannot grant access or publish',async()=>{
 const f=fixture();try{
  const secret=await setup(f);const pairLink=await call(f,'/api/admin/telegram/pair','POST',{});
  f.db.sqlite.exec('UPDATE telegram_settings SET pair_until=0');
  await message(f,secret,70,'/start '+new URL(pairLink.data.url).searchParams.get('start'));
  assert.equal((await call(f,'/api/admin/telegram')).data.paired,false);
  await pair(f,secret);const r=await message(f,secret,71,stk);
  f.db.sqlite.exec('UPDATE telegram_pending SET expires=0');
  await message(f,secret,72,null,42,r.data.reply_markup.inline_keyboard[0][0].callback_data);
  assert.equal((await call(f,'/api/v2/rates')).data.revision,0);
 }finally{f.db.sqlite.close();}
});
