import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync,readdirSync} from 'node:fs';
import {confirmedSheets} from '../lib/confirmed-history.mjs';
import {repairTestPublication,repairPath} from '../lib/restore-six-days.mjs';
import {publicHistory} from '../lib/history.mjs';
class D1{
 constructor(){this.sqlite=new DatabaseSync(':memory:');for(const f of readdirSync(new URL('../drizzle',import.meta.url)).filter(f=>f.endsWith('.sql')).sort())this.sqlite.exec(readFileSync(new URL('../drizzle/'+f,import.meta.url),'utf8'));}
 prepare(sql){const s=this.sqlite.prepare(sql),wrap=(v=[])=>({bind:(...args)=>wrap(args),first:async()=>s.get(...v)||null,all:async()=>({results:s.all(...v)}),run:async()=>({meta:{changes:Number(s.run(...v).changes)}})});return wrap();}
 async batch(items){this.sqlite.exec('BEGIN');try{const r=[];for(const x of items)r.push(await x.run());this.sqlite.exec('COMMIT');return r;}catch(e){this.sqlite.exec('ROLLBACK');throw e;}}
}
const token='a'.repeat(64),hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(token))),x=>x.toString(16).padStart(2,'0')).join('');
const req=()=>new Request('https://rates.example'+repairPath,{method:'POST',headers:{Authorization:'Bearer '+token}});
function fixture(){const db=new D1(),sheets=confirmedSheets();db.sqlite.prepare('INSERT INTO admin_owner VALUES(1,?)').run('owner');for(let i=0;i<6;i++)db.sqlite.prepare('INSERT INTO revisions(id,payload,published_at) VALUES(?,?,?)').run(i+4,JSON.stringify(sheets[i]),new Date().toISOString());const trial=structuredClone(sheets[5]);for(const q of trial.quotes)q.rate_micros=Math.round(100000000000/(q.direction==='mmk_thb'?780:800));db.sqlite.prepare('INSERT INTO revisions(id,payload,published_at) VALUES(10,?,?)').run(JSON.stringify(trial),new Date().toISOString());db.sqlite.prepare('INSERT INTO draft(id,payload,version) VALUES(1,?,8)').run(JSON.stringify(trial));return db;}
test('Owner-confirmed repair removes only the known test, restores six real dates and 12 observations, and cannot replay over later prices',async()=>{
 const db=fixture();try{
  assert.equal((await repairTestPublication(req(),db)).status,401);
  assert.equal((await repairTestPublication(req(),db,hash)).status,200);
  const rows=db.sqlite.prepare('SELECT * FROM revisions ORDER BY id DESC').all();const h=publicHistory(rows,Date.parse('2026-10-17T17:00:00Z'));assert.equal(h.points.length,12);assert.equal(h.observations.length,12);assert.equal(new Set(h.points.map(p=>p.day)).size,6);assert.ok(!h.observations.some(p=>[Math.round(100000000000/780),Math.round(100000000000/800)].includes(p.rate_micros)));
  assert.equal(rows[0].id,11);assert.equal(db.sqlite.prepare('SELECT COUNT(*) AS n FROM revision_trash').get().n,1);
  db.sqlite.prepare('INSERT INTO revisions(payload,published_at) VALUES(?,?)').run(rows[0].payload,new Date().toISOString());assert.equal((await repairTestPublication(req(),db,hash)).data.already_deleted,true);assert.equal(db.sqlite.prepare('SELECT MAX(id) AS n FROM revisions').get().n,12);
 }finally{db.sqlite.close();}
});
test('A newer publication blocks the repair without changing any rows',async()=>{const db=fixture();try{db.sqlite.prepare('INSERT INTO revisions(payload,published_at) SELECT payload,published_at FROM revisions WHERE id=10').run();assert.equal((await repairTestPublication(req(),db,hash)).status,409);assert.equal(db.sqlite.prepare('SELECT COUNT(*) AS n FROM revision_trash').get().n,0);}finally{db.sqlite.close();}});
