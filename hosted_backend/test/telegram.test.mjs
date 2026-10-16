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
 assert.deepEqual(parseRates('k to b 726').candidates,[{rate:726,direction:'mmk_thb'}]);
 assert.deepEqual(parseRates('B-K 748').candidates,[{rate:748,direction:'thb_mmk'}]);
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
const button=(r,prefix)=>r.data.reply_markup?.inline_keyboard.flat().find(b=>b.callback_data?.startsWith(prefix))?.callback_data;
async function confirm(f,secret,id,preview,actor=42){const action=button(preview,'publish:');assert.ok(action,'Expected an explicit confirmation preview');return message(f,secret,id,null,actor,action);}
async function review(f,secret,id,question){return message(f,secret,id,null,42,button(question,'review:'));}
async function onePreview(f,secret,id,text){const question=await message(f,secret,id,text);return review(f,secret,id+2000,question);}
async function submit(f,secret,id,text){const preview=await onePreview(f,secret,id,text);return confirm(f,secret,id+1000,preview);}

test('every single rate stays private until explicit paired-owner confirmation, with immutable units and retry safety',async()=>{
 const f=fixture();try{
  const secret=await setup(f);await pair(f,secret);
  const question=await message(f,secret,10,'ကျပ်ပေး ဘတ်ယူ ၇၂၆');assert.ok(button(question,'other:'));
  const preview=await review(f,secret,2009,question);
  assert.match(preview.data.text,/Public မတင်ရသေး/);assert.match(preview.data.text,/ကျပ် ၁ သိန်း = ဘတ် 726/);assert.match(preview.data.text,/ကျပ်ပေး → ဘတ်ယူ/);
  assert.equal((await call(f,'/api/v2/rates')).data.revision,0);assert.equal((await call(f,'/api/admin/state')).data.draft_version,0);assert.equal((await call(f,'/api/v2/history')).data.points.length,0);
  await confirm(f,secret,11,preview,99);assert.equal((await call(f,'/api/v2/rates')).data.revision,0);
  const published=await confirm(f,secret,12,preview);assert.match(published.data.text,/တင်ပြီး/);assert.match(published.data.reply_markup.inline_keyboard[0][0].url,/github.io/);
  const sheet=(await call(f,'/api/v2/rates')).data;assert.equal(sheet.revision,1);assert.equal(sheet.quotes.length,1);assert.equal(sheet.quotes[0].direction,'mmk_thb');assert.equal(sheet.quotes[0].rate_micros,Math.round(100000/726*1e6));assert.equal(sheet.quotes[0].fee_bps,0);assert.equal(sheet.quotes[0].flat_fee_minor,0);
  assert.equal((await call(f,'/api/admin/state')).data.draft.quotes[0].rate_micros,sheet.quotes[0].rate_micros);
  await confirm(f,secret,12,preview);await confirm(f,secret,13,preview);assert.equal((await call(f,'/api/v2/rates')).data.revision,1);
 }finally{f.db.sqlite.close();}
});
test('choosing a rate only opens a preview; confirmation publishes exactly that direction',async()=>{
 const f=fixture();try{
  const secret=await setup(f);await pair(f,secret);const choices=await message(f,secret,20,stk);
  const rates=choices.data.reply_markup.inline_keyboard.flat().filter(b=>b.callback_data.startsWith('rate:'));assert.equal(rates.length,4);
  const question=await message(f,secret,21,null,42,rates[1].callback_data);const preview=await review(f,secret,2021,question);
  assert.ok(button(preview,'publish:'));assert.equal((await call(f,'/api/v2/rates')).data.revision,0);
  await confirm(f,secret,22,preview);const q=(await call(f,'/api/v2/rates')).data.quotes;assert.equal(q.length,1);assert.equal(q[0].direction,'mmk_thb');assert.equal(q[0].rate_micros,Math.round(100000/726*1e6));
  await message(f,secret,23,null,42,rates[2].callback_data);assert.equal((await call(f,'/api/v2/rates')).data.revision,1);
 }finally{f.db.sqlite.close();}
});
test('cancel from preview or choices never changes public rates and disables confirm',async()=>{
 const f=fixture();try{
  const secret=await setup(f);await pair(f,secret);const preview=await onePreview(f,secret,30,'726');
  const r=await message(f,secret,31,null,42,button(preview,'cancel:'));assert.match(r.data.text,/မတင်တော့/);
  await confirm(f,secret,32,preview);assert.equal((await call(f,'/api/v2/rates')).data.revision,0);
  const choices=await message(f,secret,33,stk);await message(f,secret,34,null,42,button(choices,'cancel:'));
  await message(f,secret,35,null,42,button(choices,'rate:'));assert.equal((await call(f,'/api/v2/rates')).data.revision,0);
 }finally{f.db.sqlite.close();}
});
test('new text invalidates previous confirmation and choices before any publication',async()=>{
 const f=fixture();try{
  const secret=await setup(f);await pair(f,secret);const old=await onePreview(f,secret,40,'726');const current=await onePreview(f,secret,41,'727');
  await confirm(f,secret,42,old);assert.equal((await call(f,'/api/v2/rates')).data.revision,0);
  await confirm(f,secret,43,current);assert.equal((await call(f,'/api/v2/rates')).data.quotes[0].rate_micros,Math.round(100000/727*1e6));
  const choices=await message(f,secret,44,stk);await message(f,secret,45,'728');await message(f,secret,46,null,42,button(choices,'rate:'));
  assert.equal((await call(f,'/api/v2/rates')).data.revision,1);
 }finally{f.db.sqlite.close();}
});
test('opposite quote is never inferred or overwritten; preview shows the actual change and retains its timestamp',async()=>{
 const f=fixture();try{
  const secret=await setup(f);await pair(f,secret);await submit(f,secret,50,'ဘတ်ပေး ကျပ်ယူ 748');
  const other=(await call(f,'/api/v2/rates')).data.quotes[0];const preview=await onePreview(f,secret,51,'ကျပ်ပေး ဘတ်ယူ 726');
  assert.match(preview.data.text,/ယခင် 748/);await confirm(f,secret,52,preview);
  const q=(await call(f,'/api/v2/rates')).data.quotes;assert.equal(q.length,2);assert.deepEqual(q.find(q=>q.direction==='thb_mmk'),other);
  const changed=await onePreview(f,secret,53,'700');assert.match(changed.data.text,/ယခင်နှုန်း: ကျပ် ၁ သိန်း = ဘတ် 726/);assert.match(changed.data.text,/သတိပြုရန်/);
 }finally{f.db.sqlite.close();}
});
test('confirmed publication preserves an unpublished admin draft and invalidates old admin versions',async()=>{
 const f=fixture();try{
  const secret=await setup(f);await pair(f,secret);await call(f,'/api/admin/draft','PUT',{expected_version:0,sheet:{notice:'admin work',quotes:[]}});
  await submit(f,secret,60,'726');const state=(await call(f,'/api/admin/state')).data;assert.equal(state.draft.notice,'admin work');assert.equal(state.draft_version,2);assert.equal(state.published.quotes.length,1);
  assert.equal((await call(f,'/api/admin/publish','POST',{expected_version:1})).status,409);
 }finally{f.db.sqlite.close();}
});
test('an intervening admin publication or settings change invalidates a confirmation',async()=>{
 const f=fixture();try{
  const secret=await setup(f);await pair(f,secret);await submit(f,secret,70,'726');const preview=await onePreview(f,secret,71,'727');
  const state=(await call(f,'/api/admin/state')).data;const sheet={...state.draft,notice:'new admin publication'};
  await call(f,'/api/admin/draft','PUT',{expected_version:state.draft_version,sheet});await call(f,'/api/admin/publish','POST',{expected_version:state.draft_version+1});
  const blocked=await confirm(f,secret,72,preview);assert.match(blocked.data.text,/Public နှုန်းပြောင်း/);assert.equal((await call(f,'/api/v2/rates')).data.revision,2);
  const next=await onePreview(f,secret,73,'728');await call(f,'/api/admin/telegram','POST',{source_name:'Changed',source_url:'',direction:'mmk_thb'});
  await confirm(f,secret,74,next);assert.equal((await call(f,'/api/v2/rates')).data.revision,2);
 }finally{f.db.sqlite.close();}
});
test('concurrent confirmations or concurrent choices cannot double publish or bypass preview',async()=>{
 const f=fixture();try{
  const secret=await setup(f);await pair(f,secret);const preview=await onePreview(f,secret,80,'726');
  await Promise.all([confirm(f,secret,81,preview),confirm(f,secret,82,preview)]);assert.equal((await call(f,'/api/v2/rates')).data.revision,1);
  const choices=await message(f,secret,83,stk);const action=button(choices,'rate:');
  const responses=await Promise.all([message(f,secret,84,null,42,action),message(f,secret,85,null,42,action)]);
  assert.equal(responses.filter(r=>button(r,'other:')).length,1);assert.equal((await call(f,'/api/v2/rates')).data.revision,1);
 }finally{f.db.sqlite.close();}
});
test('expired confirmation and pairing are rejected; old legacy rate-choice buttons now require preview',async()=>{
 const f=fixture();try{
  const secret=await setup(f);const link=await call(f,'/api/admin/telegram/pair','POST',{});f.db.sqlite.exec('UPDATE telegram_settings SET pair_until=0');
  await message(f,secret,90,'/start '+new URL(link.data.url).searchParams.get('start'));assert.equal((await call(f,'/api/admin/telegram')).data.paired,false);
  await pair(f,secret);const preview=await onePreview(f,secret,91,'726');f.db.sqlite.exec('UPDATE telegram_pending SET expires=0');
  await confirm(f,secret,92,preview);assert.equal((await call(f,'/api/v2/rates')).data.revision,0);
  const choices=await message(f,secret,93,stk);const stored=f.db.sqlite.prepare('SELECT * FROM telegram_pending WHERE used=0 AND expires>0').get();const payload=JSON.parse(stored.payload);delete payload.stage;delete payload.config_generation;
  f.db.sqlite.prepare('UPDATE telegram_pending SET payload=? WHERE id=?').run(JSON.stringify(payload),stored.id);
  const legacy=await message(f,secret,94,null,42,button(choices,'rate:'));assert.ok(button(legacy,'other:'));assert.equal((await call(f,'/api/v2/rates')).data.revision,0);
 }finally{f.db.sqlite.close();}
});
test('any channel uses optional generic label, preview includes it, and old named presets are ignored',async()=>{
 const f=fixture();try{
  const secret=await setup(f);await pair(f,secret);f.db.sqlite.prepare('INSERT INTO telegram_session(id,source) VALUES(1,?)').run('Old preset');
  const help=await message(f,secret,100,'/help');assert.ok(!help.data.text.includes('/stk'));assert.ok(!help.data.text.includes('/kumar'));assert.match(help.data.text,/Public တင်မယ်/);
  const preview=await onePreview(f,secret,101,'726');assert.match(preview.data.text,/Test Source/);await confirm(f,secret,102,preview);
  await call(f,'/api/admin/telegram','POST',{source_name:'',source_url:'',direction:'mmk_thb'});await submit(f,secret,103,'727');assert.equal((await call(f,'/api/v2/rates')).data.quotes[0].source_name,'နေ့စဉ်ရည်ညွှန်းနှုန်း');
 }finally{f.db.sqlite.close();}
});
test('photos, old dates and ranges never bypass review; disconnect blocks publishing',async()=>{
 const f=fixture();try{
  const secret=await setup(f);await pair(f,secret);await message(f,secret,110,null);await message(f,secret,111,'hello');await message(f,secret,112,'2020-01-01\nကျပ်ပေး ဘတ်ယူ 726');
  const range=await message(f,secret,113,kumar);assert.ok(button(range,'rate:'));assert.equal((await call(f,'/api/v2/rates')).data.revision,0);
  await call(f,'/api/admin/telegram/disconnect','POST',{});
  const r=await handle(new Request(origin+'/api/telegram/webhook',{method:'POST',headers:{'X-Telegram-Bot-Api-Secret-Token':secret},body:'{}'}),f.db,null,'',f.runtime);assert.equal(r.status,403);
 }finally{f.db.sqlite.close();}
});
test('undo restores a previously confirmed quote with its original observation time',async()=>{
 const f=fixture();try{
  const secret=await setup(f);await pair(f,secret);await submit(f,secret,120,'726');const original=(await call(f,'/api/v2/rates')).data.quotes[0];await submit(f,secret,121,'727');
  await message(f,secret,122,'/undo');const p=(await call(f,'/api/v2/rates')).data;assert.equal(p.revision,3);assert.deepEqual(p.quotes[0],original);
  await message(f,secret,123,'/undo');assert.equal((await call(f,'/api/v2/rates')).data.revision,3);
 }finally{f.db.sqlite.close();}
});

test('single direction asks whether to add the other side; each price stays independent and both publish only after review',async()=>{
 const f=fixture();try{
  const secret=await setup(f);await pair(f,secret);const question=await message(f,secret,130,'ကျပ်ပေး ဘတ်ယူ 726');
  assert.ok(button(question,'other:'));assert.ok(button(question,'review:'));assert.equal((await call(f,'/api/v2/rates')).data.revision,0);
  const waiting=await message(f,secret,131,null,42,button(question,'other:'));assert.match(waiting.data.text,/ဘတ်ပေး → ကျပ်ယူ/);
  await message(f,secret,132,'ကျပ်ပေး ဘတ်ယူ 727');assert.equal((await call(f,'/api/v2/rates')).data.revision,0);
  const preview=await message(f,secret,133,'748');assert.ok(button(preview,'publish:'));assert.match(preview.data.text,/ဘတ် 726 ရ/);assert.match(preview.data.text,/ဘတ် 748 ပေး/);
  assert.equal((await call(f,'/api/v2/rates')).data.revision,0);await confirm(f,secret,134,preview);
  const quotes=(await call(f,'/api/v2/rates')).data.quotes;assert.equal(quotes.length,2);
  assert.equal(quotes.find(q=>q.direction==='mmk_thb').rate_micros,Math.round(100000/726*1e6));
  assert.equal(quotes.find(q=>q.direction==='thb_mmk').rate_micros,Math.round(100000/748*1e6));
 }finally{f.db.sqlite.close();}
});
test('two unambiguous pasted directions can be reviewed together without a redundant other-side question',async()=>{
 const f=fixture();try{
  const secret=await setup(f);await pair(f,secret);const preview=await message(f,secret,140,'ကျပ်ပေး ဘတ်ယူ 726\nဘတ်ပေး ကျပ်ယူ 748');
  assert.ok(button(preview,'publish:'));assert.equal((await call(f,'/api/v2/rates')).data.revision,0);await confirm(f,secret,141,preview);
  const q=(await call(f,'/api/v2/rates')).data.quotes;assert.equal(q.length,2);assert.notEqual(q[0].rate_micros,q[1].rate_micros);
 }finally{f.db.sqlite.close();}
});
test('other side found in the copied post can be chosen explicitly, or skipped while waiting for it',async()=>{
 const f=fixture();try{
  const secret=await setup(f);await pair(f,secret);const choices=await message(f,secret,150,stk);
  const rate=choices.data.reply_markup.inline_keyboard.flat().find(b=>b.text.includes('726'));
  const question=await message(f,secret,151,null,42,rate.callback_data);
  const waiting=await message(f,secret,152,null,42,button(question,'other:'));
  assert.ok(button(waiting,'other_rate:'));const preview=await message(f,secret,153,null,42,button(waiting,'other_rate:'));
  await confirm(f,secret,154,preview);assert.equal((await call(f,'/api/v2/rates')).data.quotes.length,2);
  const newQuestion=await message(f,secret,155,'727');const wait=await message(f,secret,156,null,42,button(newQuestion,'other:'));
  const skip=await review(f,secret,157,wait);await confirm(f,secret,158,skip);
  const q=(await call(f,'/api/v2/rates')).data.quotes;assert.equal(q.find(q=>q.direction==='thb_mmk').rate_micros,Math.round(100000/748*1e6));
 }finally{f.db.sqlite.close();}
});
