import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync,readdirSync} from 'node:fs';
import {handle} from '../lib/api.mjs';
class D1 {
 constructor(sqlite=new DatabaseSync(':memory:')){this.sqlite=sqlite;}
 prepare(sql){
  const s=this.sqlite.prepare(sql), wrap=(values=[])=>({bind:(...v)=>wrap(v),first:async()=>s.get(...values)??null,all:async()=>({results:s.all(...values)}),run:async()=>{const r=s.run(...values);return {meta:{changes:Number(r.changes)}};}});return wrap();
 }
 async batch(statements){this.sqlite.exec('BEGIN');try{const r=[];for(const s of statements)r.push(await s.run());this.sqlite.exec('COMMIT');return r;}catch(e){this.sqlite.exec('ROLLBACK');throw e;}}
}
const user={userId:'owner',email:'owner@test'};
const origin='https://rates.example';
async function setup(){const db=new D1();for(const f of readdirSync(new URL('../drizzle',import.meta.url)).filter(f=>f.endsWith('.sql')).sort())db.sqlite.exec(readFileSync(new URL('../drizzle/'+f,import.meta.url),'utf8'));return db;}
async function call(db,path,method='GET',data,actor=user,extra={}){
 const req=new Request(origin+'/api/'+path,{method,headers:{Origin:origin,'X-Admin-Request':'1','Content-Type':'application/json',...extra},...(data===undefined?{}:{body:JSON.stringify(data)})});
 const res=await handle(req,db,actor,'owner@test');return {status:res.status,data:await res.json(),headers:res.headers};
}
async function enroll(db){assert.equal((await call(db,'admin/login','POST',{})).status,200);await call(db,'admin/state');}
function sheet(){const now=Date.now();return {notice:'Test only',quotes:[{id:'test',label:'test',direction:'thb_mmk',rate_micros:130000000,flat_fee_minor:0,fee_bps:0,source_name:'test',source_url:'https://example.com',payout_method:'bank',note:'',source_checked:true,observed_at:new Date(now-60000).toISOString(),valid_until:new Date(now+3600000).toISOString()}]};}
test('public read, anonymous rejection, owner bootstrap, owner isolation',async()=>{
 const db=await setup();const pub=await call(db,'v2/rates','GET',undefined,null);assert.equal(pub.status,200);assert.equal(pub.headers.get('Access-Control-Allow-Origin'),'*');assert.deepEqual(pub.data.quotes,[]);
 assert.equal((await call(db,'admin/state','GET',undefined,null)).status,401);
 assert.equal((await call(db,'admin/login','POST',{}, {userId:'intruder',email:'other@test'})).status,403);
 await enroll(db);
 assert.equal((await call(db,'admin/state','GET',undefined,{userId:'intruder'})).status,403);
 assert.equal((await call(db,'admin/login','POST',{}, {userId:'second-id',email:'owner@test'})).status,403);
 assert.equal((await call(db,'admin/login','POST',{})).status,200);
 db.sqlite.close();
});
test('draft isolation, stale versions, publish, restore and retained D1 connection',async()=>{
 const db=await setup();await enroll(db);
 assert.equal((await call(db,'admin/draft','PUT',{sheet:sheet(),expected_version:0})).status,200);
 assert.equal((await call(db,'v2/rates')).data.revision,0);
 assert.equal((await call(db,'admin/publish','POST',{expected_version:0})).status,409);
 const published=await call(db,'admin/publish','POST',{expected_version:1});assert.equal(published.status,200);assert.equal(published.data.published.revision,1);
 assert.equal((await call(db,'admin/publish','POST',{expected_version:1})).status,409);
 assert.equal((await call(db,'admin/draft','PUT',{sheet:{notice:'hidden',quotes:[]},expected_version:2})).status,200);
 assert.equal((await call(db,'v2/rates')).data.quotes.length,1);
 assert.equal((await call(db,'admin/restore','POST',{revision:1,expected_version:3})).status,200);
 const restarted=new D1(db.sqlite);assert.equal((await call(restarted,'v2/rates')).data.revision,1);assert.equal((await call(restarted,'admin/state')).data.draft_version,4);
 db.sqlite.close();
});
test('same-origin header, source validation, expiry and oversize bodies',async()=>{
 const db=await setup();await enroll(db);
 assert.equal((await call(db,'admin/publish','POST',{expected_version:0},user,{Origin:'https://evil.example'})).status,403);
 assert.equal((await call(db,'admin/publish','POST',{expected_version:0},user,{'X-Admin-Request':''})).status,403);
 let s=sheet();s.quotes[0].source_checked=false;
 assert.equal((await call(db,'admin/draft','PUT',{sheet:s,expected_version:0})).status,400);
 s=sheet();s.quotes[0].source_url='javascript:alert(1)';assert.equal((await call(db,'admin/draft','PUT',{sheet:s,expected_version:0})).status,400);
 s=sheet();s.quotes[0].observed_at=new Date(Date.now()-86400000).toISOString();s.quotes[0].valid_until=new Date(Date.now()-1000).toISOString();
 assert.equal((await call(db,'admin/draft','PUT',{sheet:s,expected_version:0})).status,200);
 assert.equal((await call(db,'admin/publish','POST',{expected_version:1})).status,400);
 assert.equal((await call(db,'admin/draft','PUT',{sheet:{notice:'a'.repeat(140000),quotes:[]},expected_version:1})).status,413);
 db.sqlite.close();
});
test('public trend contains published observations only and permits cross-origin reads',async()=>{
 const db=await setup();await enroll(db);
 await call(db,'admin/draft','PUT',{sheet:sheet(),expected_version:0});
 assert.deepEqual((await call(db,'v2/history','GET',undefined,null)).data.points,[]);
 await call(db,'admin/publish','POST',{expected_version:1});
 const h=await call(db,'v2/history','GET',undefined,null);
 assert.equal(h.status,200);assert.equal(h.headers.get('Access-Control-Allow-Origin'),'*');assert.equal(h.data.points.length,1);
 assert.equal(h.data.points[0].quote_id,'test');assert.equal(h.data.timezone,'Asia/Bangkok');
 db.sqlite.close();
});

test('Deleting the latest publication archives it, restores earlier prices and timestamps, and advances the public revision',async()=>{
 const db=await setup();try{
 await enroll(db);const first=sheet(), second=sheet();second.quotes[0].rate_micros=140000000;
 await call(db,'admin/draft','PUT',{sheet:first,expected_version:0});await call(db,'admin/publish','POST',{expected_version:1});
 await call(db,'admin/draft','PUT',{sheet:second,expected_version:2});await call(db,'admin/publish','POST',{expected_version:3});
 assert.equal((await call(db,'admin/delete-revision','POST',{revision:2,expected_revision:2,expected_version:4},null)).status,401);
 assert.equal((await call(db,'admin/delete-revision','POST',{revision:2,expected_revision:2,expected_version:4},{userId:'other'})).status,403);
 assert.equal((await call(db,'admin/delete-revision','POST',{revision:2,expected_revision:1,expected_version:4})).status,409);
 assert.equal((await call(db,'admin/delete-revision','POST',{revision:2,expected_revision:2,expected_version:3})).status,409);
 assert.equal((await call(db,'admin/delete-revision','POST',{revision:2,expected_revision:2,expected_version:4})).status,200);
 const pub=(await call(db,'v2/rates')).data;assert.equal(pub.revision,3);assert.equal(pub.quotes[0].rate_micros,first.quotes[0].rate_micros);assert.equal(pub.quotes[0].observed_at,first.quotes[0].observed_at);
 const state=(await call(db,'admin/state')).data;assert.equal(state.trash[0].id,2);assert.equal(state.history.some(r=>r.id===2),false);assert.equal(state.draft_version,5);assert.deepEqual(state.draft.quotes,first.quotes);
 const retry=await call(db,'admin/delete-revision','POST',{revision:2,expected_revision:2,expected_version:4});assert.equal(retry.data.already_deleted,true);assert.equal((await call(db,'v2/rates')).data.revision,3);
 await call(db,'admin/restore','POST',{revision:2,expected_version:5});assert.equal((await call(db,'admin/state')).data.draft.quotes[0].rate_micros,140000000);assert.equal((await call(db,'v2/rates')).data.quotes[0].rate_micros,first.quotes[0].rate_micros);
 }finally{db.sqlite.close();}
});
test('Deleting a historical publication preserves current prices and an independently edited draft; deleting the final price leaves an empty public sheet',async()=>{
 const db=await setup();try{
 await enroll(db);const a=sheet();await call(db,'admin/draft','PUT',{sheet:a,expected_version:0});await call(db,'admin/publish','POST',{expected_version:1});
 const b=sheet();b.quotes[0].rate_micros=140000000;await call(db,'admin/draft','PUT',{sheet:b,expected_version:2});await call(db,'admin/publish','POST',{expected_version:3});
 const privateDraft={notice:'private',quotes:[]};await call(db,'admin/draft','PUT',{sheet:privateDraft,expected_version:4});
 assert.equal((await call(db,'admin/delete-revision','POST',{revision:1,expected_revision:2,expected_version:5})).status,200);
 let state=(await call(db,'admin/state')).data;assert.deepEqual(state.draft,privateDraft);assert.equal(state.published.quotes[0].rate_micros,140000000);assert.equal(state.published.revision,3);
 }finally{db.sqlite.close();}
 const only=await setup();try{await enroll(only);await call(only,'admin/draft','PUT',{sheet:sheet(),expected_version:0});await call(only,'admin/publish','POST',{expected_version:1});await call(only,'admin/delete-revision','POST',{revision:1,expected_revision:1,expected_version:2});assert.deepEqual((await call(only,'v2/rates')).data.quotes,[]);}finally{only.sqlite.close();}
});
test('Removal cancels stale Telegram previews and queued alerts, and a transaction failure rolls back the archive and public state',async()=>{
 const db=await setup();try{
  await enroll(db);await call(db,'admin/draft','PUT',{sheet:sheet(),expected_version:0});await call(db,'admin/publish','POST',{expected_version:1});
  db.sqlite.prepare('INSERT INTO telegram_pending(id,owner_id,payload,expires,used) VALUES(?,?,?,?,0)').run('pending','42','{}',Date.now()+600000);
  db.sqlite.prepare('INSERT INTO alert_outbox(id,chat_id,subscription_version,revision,payload,status,attempts,next_attempt) VALUES(?,?,?,?,?,0,0,0)').run('queued','1',1,1,'{}');
  db.sqlite.exec("CREATE TRIGGER fail_delete BEFORE DELETE ON revisions BEGIN SELECT RAISE(ABORT,'test failure'); END;");
  assert.equal((await call(db,'admin/delete-revision','POST',{revision:1,expected_revision:1,expected_version:2})).status,500);
  assert.equal(db.sqlite.prepare('SELECT COUNT(*) AS n FROM revision_trash').get().n,0);assert.equal((await call(db,'v2/rates')).data.revision,1);assert.equal((await call(db,'admin/state')).data.draft_version,2);
  db.sqlite.exec('DROP TRIGGER fail_delete');assert.equal((await call(db,'admin/delete-revision','POST',{revision:1,expected_revision:1,expected_version:2})).status,200);
  assert.equal(db.sqlite.prepare('SELECT used FROM telegram_pending').get().used,1);assert.equal(db.sqlite.prepare('SELECT status FROM alert_outbox').get().status,2);
 }finally{db.sqlite.close();}
});
