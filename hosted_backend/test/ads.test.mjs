import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync,readdirSync} from 'node:fs';
import {handle} from '../lib/api.mjs';

class D1 {
  constructor(){
    this.sqlite=new DatabaseSync(':memory:');
    for(const f of readdirSync(new URL('../drizzle/',import.meta.url)).filter(f=>f.endsWith('.sql')).sort()){
      this.sqlite.exec(readFileSync(new URL('../drizzle/'+f,import.meta.url),'utf8'));
    }
  }
  prepare(sql){
    const stmt=this.sqlite.prepare(sql);
    const wrap=(params=[])=>({
      bind:(...v)=>wrap(v),
      first:async()=>stmt.get(...params)||null,
      all:async()=>({results:stmt.all(...params)}),
      run:async()=>({meta:{changes:Number(stmt.run(...params).changes)}}),
    });
    return wrap();
  }
}
const owner={userId:'owner',email:'owner@test'}, origin='https://rates.example';
async function call(db,path,method='GET',data,user=owner,extra={}){
  const res=await handle(new Request(origin+path,{
    method,headers:{'Origin':origin,'X-Admin-Request':'1','Content-Type':'application/json',...extra},
    ...(data===undefined?{}:{body:JSON.stringify(data)}),
  }),db,user,'owner@test');
  return {status:res.status,data:await res.json(),headers:res.headers};
}
const sponsor={
  id:'stk-01',name:'Example Partner',label:'Sponsored offer',
  image_url:'https://example.com/banner.png',destination_url:'https://example.com/offer',
  placements:['home'],language:'both',priority:10,enabled:true,start_at:null,end_at:null,
};
const config=()=>({
  enabled:true,platforms:{web:true,android:true,ios:false},
  formats:{banner:true,native:false,interstitial:false,rewarded:false},
  placements:{home:true,history:false,calculator:false,budget:false},
  sponsors_enabled:true,sponsors:[sponsor],
});
test('Advertising is OFF by default; public endpoint exposes no admin secrets or personal finance',async()=>{
  const db=new D1();
  const publicRes=await call(db,'/api/v2/ads','GET',undefined,null);
  assert.equal(publicRes.status,200);
  assert.equal(publicRes.headers.get('Access-Control-Allow-Origin'),'*');
  assert.equal(publicRes.data.enabled,false);
  assert.deepEqual(publicRes.data.sponsors,[]);
  assert.equal((await call(db,'/api/admin/ads','GET',undefined,null)).status,401);
  assert.equal((await call(db,'/api/admin/login','POST',{})).status,200);
  const admin=await call(db,'/api/admin/ads');
  assert.equal(admin.data.version,0);
  assert.equal(admin.data.config.platforms.ios,false);
  db.sqlite.close();
});
test('Only owner saves; CAS stops stale writes; sponsor time/visibility respected',async()=>{
  const db=new D1();
  await call(db,'/api/admin/login','POST',{});
  assert.equal((await call(db,'/api/admin/ads','PUT',{expected_version:0,config:config()},{userId:'intruder'})).status,403);
  assert.equal((await call(db,'/api/admin/ads','PUT',{expected_version:0,config:config()},owner,{'Origin':'https://evil.test'})).status,403);
  const saved=await call(db,'/api/admin/ads','PUT',{expected_version:0,config:config()});
  assert.equal(saved.status,200);assert.equal(saved.data.version,1);
  assert.equal((await call(db,'/api/admin/ads','PUT',{expected_version:0,config:config()})).status,409);
  const pub=(await call(db,'/api/v2/ads','GET',undefined,null)).data;
  assert.equal(pub.enabled,true);assert.equal(pub.sponsors.length,1);
  assert.equal(pub.sponsors[0].name,'Example Partner');
  assert.equal(pub.sponsors[0].priority,undefined);
  assert.equal(pub.sponsors[0].start_at,undefined);
  assert.equal(db.sqlite.prepare('SELECT COUNT(*) AS n FROM revisions').get().n,0);
  const next=config();next.sponsors[0]={...sponsor,end_at:new Date(Date.now()-1000).toISOString()};
  assert.equal((await call(db,'/api/admin/ads','PUT',{expected_version:1,config:next})).status,200);
  assert.deepEqual((await call(db,'/api/v2/ads','GET',undefined,null)).data.sponsors,[]);
  db.sqlite.close();
});
test('Rejects unsafe sponsor creatives and date ranges; owner controls stay separate from published rates',async()=>{
  const db=new D1();await call(db,'/api/admin/login','POST',{});
  for(const url of ['javascript:alert(1)','http://example.com/','https://user:pass@example.com/','https://localhost/image.png']){
    const next=config();next.sponsors=[{...sponsor,image_url:url}];
    assert.equal((await call(db,'/api/admin/ads','PUT',{expected_version:0,config:next})).status,400,url);
  }
  const bad=config();bad.sponsors=[{...sponsor,start_at:'2026-12-01T00:00:00Z',end_at:'2026-10-01T00:00:00Z'}];
  assert.equal((await call(db,'/api/admin/ads','PUT',{expected_version:0,config:bad})).status,400);
  const opts=config();opts.enabled=false;
  assert.equal((await call(db,'/api/admin/ads','PUT',{expected_version:0,config:opts})).status,200);
  assert.deepEqual((await call(db,'/api/v2/ads','GET',undefined,null)).data.sponsors,[]);
  assert.equal(db.sqlite.prepare('SELECT COUNT(*) AS n FROM revisions').get().n,0);
  db.sqlite.close();
});
test('Private draft, recoverable publication, and emergency OFF stay independent of browser drafts and rates',async()=>{
 const db=new D1();await call(db,'/api/admin/login','POST',{});
 assert.equal((await call(db,'/api/admin/ads/draft','PUT',{expected_version:0,config:config()})).status,200);
 assert.equal((await call(db,'/api/v2/ads','GET',undefined,null)).data.enabled,false);
 assert.equal((await call(db,'/api/admin/ads/draft','PUT',{expected_version:0,config:config()})).status,409);
 assert.equal((await call(db,'/api/admin/ads','PUT',{expected_version:0,config:config()})).status,200);
 assert.equal((await call(db,'/api/admin/ads/off','POST',{},null)).status,401);
 const off=await call(db,'/api/admin/ads/off','POST',{config:{sponsors:[{image_url:'broken'}]},expected_version:999});
 assert.equal(off.status,200);assert.equal(off.data.config.enabled,false);
 assert.equal(off.data.draft.config.enabled,true);assert.equal(off.data.history.length,3);
 assert.equal((await call(db,'/api/admin/ads/rollback','POST',{revision:1,expected_version:1})).status,409);
 assert.equal((await call(db,'/api/admin/ads/rollback','POST',{revision:1,expected_version:2})).status,200);
 assert.equal((await call(db,'/api/v2/ads','GET',undefined,null)).data.enabled,true);
 assert.equal(db.sqlite.prepare('SELECT COUNT(*) AS n FROM revisions').get().n,0);
 assert.equal(db.sqlite.prepare('SELECT COUNT(*) AS n FROM notification_events').get().n,0);
 db.sqlite.close();
});
