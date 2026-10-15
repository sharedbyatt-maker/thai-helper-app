import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
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
async function setup(){const db=new D1();db.sqlite.exec(readFileSync(new URL('../drizzle/0000_fantastic_lady_vermin.sql',import.meta.url),'utf8'));return db;}
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
