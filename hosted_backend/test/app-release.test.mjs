import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync,readdirSync} from 'node:fs';
import {handle} from '../lib/api.mjs';
class D1 {
 constructor(){this.sqlite=new DatabaseSync(':memory:');for(const f of readdirSync(new URL('../drizzle',import.meta.url)).filter(f=>f.endsWith('.sql')).sort())this.sqlite.exec(readFileSync(new URL('../drizzle/'+f,import.meta.url),'utf8'));}
 prepare(sql){const s=this.sqlite.prepare(sql),wrap=(v=[])=>({bind:(...x)=>wrap(x),first:async()=>s.get(...v)||null,all:async()=>({results:s.all(...v)}),run:async()=>({meta:{changes:Number(s.run(...v).changes)}})});return wrap();}
}
const owner={userId:'owner',email:'owner@test'},origin='https://rates.example';
async function call(db,path,method='GET',data,user=owner,headers={}){
 const response=await handle(new Request(origin+path,{method,headers:{Origin:origin,'X-Admin-Request':'1','Content-Type':'application/json',...headers},...(data===undefined?{}:{body:JSON.stringify(data)})}),db,user,'owner@test');
 return {status:response.status,data:await response.json(),headers:response.headers};
}
async function setup(){const db=new D1();await call(db,'/api/admin/login','POST',{});return db;}
const blank=()=>({enabled:false,build:0,version:'',url:'',notes:''});
const release=()=>({package_id:'com.test.bahtzay',apk:{enabled:true,build:2,version:'1.0.1',url:'https://github.com/test/bahtzay/releases/download/v1.0.1/app.apk',notes:'ငွေတွက်ရလဒ် ပြင်ထားတယ်။'},play:blank()});
test('Release configuration starts empty; only the owner can publish and public reads hide disabled details',async()=>{
 const db=await setup();const empty=await call(db,'/api/v2/app-release','GET',undefined,null);assert.equal(empty.status,200);assert.equal(empty.headers.get('Access-Control-Allow-Origin'),'*');assert.equal(empty.data.release.apk,null);assert.equal(empty.data.release.play,null);
 assert.equal((await call(db,'/api/admin/app-release','GET',undefined,null)).status,401);
 assert.equal((await call(db,'/api/admin/app-release','PUT',{release:release(),expected_release_version:0},{userId:'other'})).status,403);
 assert.equal((await call(db,'/api/admin/app-release','PUT',{release:release(),expected_release_version:0},owner,{Origin:'https://evil.test'})).status,403);
 const saved=await call(db,'/api/admin/app-release','PUT',{release:release(),expected_release_version:0});assert.equal(saved.status,200);assert.equal(saved.data.release_version,1);assert.equal(saved.data.release.package_locked,true);
 const pub=await call(db,'/api/v2/app-release','GET',undefined,null);assert.equal(pub.data.release.apk.build,2);assert.equal(pub.data.release.play,null);assert.equal(pub.data.release.package_locked,undefined);
 assert.equal(db.sqlite.prepare('SELECT COUNT(*) n FROM revisions').get().n,0);assert.equal(db.sqlite.prepare('SELECT COUNT(*) n FROM notification_events').get().n,0);
});
test('Release edits use their own CAS, preserve drafts, lock identity, and never downgrade build numbers',async()=>{
 const db=await setup();await call(db,'/api/admin/state');const before=db.sqlite.prepare('SELECT * FROM draft').get();
 let value=release();await call(db,'/api/admin/app-release','PUT',{release:value,expected_release_version:0});
 assert.equal((await call(db,'/api/admin/app-release','PUT',{release:value,expected_release_version:0})).status,409);
 value.package_id='com.other.bahtzay';assert.equal((await call(db,'/api/admin/app-release','PUT',{release:value,expected_release_version:1})).status,400);
 value=release();value.apk.build=1;assert.equal((await call(db,'/api/admin/app-release','PUT',{release:value,expected_release_version:1})).status,400);
 value=release();value.apk.enabled=false;assert.equal((await call(db,'/api/admin/app-release','PUT',{release:value,expected_release_version:1})).status,200);
 assert.equal((await call(db,'/api/v2/app-release')).data.release.apk,null);
 assert.deepEqual(db.sqlite.prepare('SELECT * FROM draft').get(),before);
});
test('APK and Play releases are independently published; unsafe URLs and mismatching Play IDs are rejected',async()=>{
 const db=await setup();for(const bad of ['http://example.test/app.apk','javascript:alert(1)','https://user:pass@example.test/app.apk','https://example.test/not-an-apk','https://example.test/app.apk#fake']){
  const value=release();value.apk.url=bad;assert.equal((await call(db,'/api/admin/app-release','PUT',{release:value,expected_release_version:0})).status,400);
 }
 const value=release();value.play={enabled:true,build:3,version:'1.0.2',notes:'Play release',url:'https://play.google.com/store/apps/details?id=com.other.app'};
 assert.equal((await call(db,'/api/admin/app-release','PUT',{release:value,expected_release_version:0})).status,400);
 value.play.url='https://play.google.com/store/apps/details?id=com.test.bahtzay';assert.equal((await call(db,'/api/admin/app-release','PUT',{release:value,expected_release_version:0})).status,200);
 const pub=(await call(db,'/api/v2/app-release')).data.release;assert.equal(pub.apk.build,2);assert.equal(pub.play.build,3);
});
