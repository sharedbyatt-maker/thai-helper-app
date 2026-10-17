import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import {readFileSync,readdirSync} from 'node:fs';
import {confirmedDays,confirmedSheets,replacementId,replacementPath,replaceConfirmedHistory} from '../lib/confirmed-history.mjs';
import {handle} from '../lib/api.mjs';
import {publicHistory} from '../lib/history.mjs';
const now=Date.parse('2026-10-17T11:00:00Z');
class D1 {
 constructor(){this.sqlite=new DatabaseSync(':memory:');this.failAt=-1;}
 prepare(sql){const s=this.sqlite.prepare(sql);const wrap=(values=[])=>({bind:(...v)=>wrap(v),first:async()=>s.get(...values)??null,all:async()=>({results:s.all(...values)}),run:async()=>{const r=s.run(...values);return {meta:{changes:Number(r.changes)}};}});return wrap();}
 async batch(statements){this.beforeBatch?.();this.sqlite.exec('BEGIN');try{const results=[];for(let i=0;i<statements.length;i++){if(i===this.failAt)throw new Error('Simulated write failure');results.push(await statements[i].run());}this.sqlite.exec('COMMIT');return results;}catch(e){this.sqlite.exec('ROLLBACK');throw e;}}
}
function setup(){const db=new D1();const dir=new URL('../drizzle/',import.meta.url);for(const f of readdirSync(dir).filter(x=>x.endsWith('.sql')).sort())db.sqlite.exec(readFileSync(new URL(f,dir),'utf8'));
 db.sqlite.prepare('INSERT INTO admin_owner VALUES(1,?)').run('existing-owner');
 db.sqlite.prepare('INSERT INTO telegram_settings(id,sealed,username,owner_id,generation) VALUES(1,?,?,?,?)').run('sealed-test-only','existing-bot','existing-chat',3);
 db.sqlite.prepare('INSERT INTO telegram_pending VALUES(?,?,?,?,?)').run('old-button','existing-chat','{}',now+86400000,0);
 const old={notice:'old sample',quotes:[{...confirmedSheets(now)[0].quotes[0],rate_micros:123000000}]};
 db.sqlite.prepare('INSERT INTO revisions(payload,published_at) VALUES(?,?)').run(JSON.stringify(old),'2026-10-16T10:00:00Z');
 db.sqlite.prepare('INSERT INTO draft VALUES(1,?,8)').run(JSON.stringify({notice:'old draft',quotes:[]}));
 return db;
}
test('the confirmed six daily prices preserve separate directions, dates, source times and 24-hour freshness',()=>{
 const sheets=confirmedSheets(now);assert.equal(sheets.length,6);
 assert.deepEqual(confirmedDays.map(x=>x.slice(2)),[[738,760],[733,755],[720,745],[706,740],[724,748],[724,748]]);
 for(let i=0;i<6;i++){for(const q of sheets[i].quotes){assert.equal(q.source_checked,true);assert.equal(q.flat_fee_minor,0);assert.equal(q.fee_bps,0);assert.equal(Date.parse(q.valid_until)-Date.parse(q.observed_at),86400000);const day=new Date(Date.parse(q.observed_at)+7*3600000).toISOString().slice(0,10);assert.equal(day,confirmedDays[i][0]);}}
 assert.equal(sheets[5].quotes[0].observed_at,'2026-10-17T05:31:00.000Z');
 assert.equal(Math.round(1e11/sheets[5].quotes[0].rate_micros),724);
 assert.equal(Math.round(1e11/sheets[5].quotes[1].rate_micros),748);
});
test('replacement is atomic, archives old prices/draft, retains owner/bot and invalidates old confirmation buttons',async()=>{
 const db=setup();const settings=db.sqlite.prepare('SELECT * FROM telegram_settings').get();const result=await replaceConfirmedHistory(db,1,now);assert.equal(result.status,200);assert.equal(result.data.already_applied,false);
 const rows=db.sqlite.prepare('SELECT * FROM revisions ORDER BY id DESC').all();assert.equal(rows.length,6);assert.equal(rows.at(-1).id,2);assert.equal(rows[0].id,7);assert.ok(rows.every(r=>r.published_at===new Date(now).toISOString()));
 const archive=db.sqlite.prepare('SELECT * FROM history_replacements').get();assert.equal(archive.id,replacementId);assert.ok(archive.applied_at);const backup=JSON.parse(archive.backup_json);assert.equal(backup.revisions.length,1);assert.equal(JSON.parse(backup.revisions[0].payload).notice,'old sample');assert.equal(backup.draft.version,8);
 const draft=db.sqlite.prepare('SELECT * FROM draft').get();assert.equal(draft.version,9);assert.deepEqual(JSON.parse(draft.payload),JSON.parse(rows[0].payload));assert.equal(JSON.parse(draft.payload).notice,'');
 assert.deepEqual(db.sqlite.prepare('SELECT * FROM telegram_settings').get(),settings);assert.equal(db.sqlite.prepare('SELECT user_id FROM admin_owner').get().user_id,'existing-owner');assert.equal(db.sqlite.prepare('SELECT used FROM telegram_pending').get().used,1);
 const history=publicHistory(rows,now);assert.equal(history.points.length,12);assert.equal(history.observations.length,12);assert.deepEqual([...new Set(history.points.map(p=>p.day))],confirmedDays.map(x=>x[0]));db.sqlite.close();
});
test('one-use replay cannot delete later owner publications or reset the draft again',async()=>{
 const db=setup();await replaceConfirmedHistory(db,1,now);db.sqlite.prepare('INSERT INTO revisions(payload,published_at) VALUES(?,?)').run(JSON.stringify({notice:'new owner update',quotes:[]}),new Date(now+1).toISOString());db.sqlite.prepare('UPDATE draft SET version=version+1 WHERE id=1').run();
 const again=await replaceConfirmedHistory(db,8,now+1000);assert.equal(again.data.already_applied,true);assert.equal(db.sqlite.prepare('SELECT COUNT(*) n FROM revisions').get().n,7);assert.equal(db.sqlite.prepare('SELECT version FROM draft').get().version,10);assert.equal(JSON.parse(db.sqlite.prepare('SELECT payload FROM revisions ORDER BY id DESC').get().payload).notice,'new owner update');db.sqlite.close();
});
test('a stale revision or concurrently edited draft leaves every live record intact',async()=>{
 const db=setup();assert.equal((await replaceConfirmedHistory(db,0,now)).status,409);assert.equal((await replaceConfirmedHistory(db,-1,now)).status,400);
 db.beforeBatch=()=>db.sqlite.prepare('UPDATE draft SET version=version+1 WHERE id=1').run();assert.equal((await replaceConfirmedHistory(db,1,now)).status,409);assert.equal(db.sqlite.prepare('SELECT COUNT(*) n FROM revisions').get().n,1);assert.equal(db.sqlite.prepare('SELECT COUNT(*) n FROM history_replacements').get().n,0);assert.equal(db.sqlite.prepare('SELECT used FROM telegram_pending').get().used,0);db.sqlite.close();
});
test('write failure rolls back deletion, archive, draft and pending changes and allows a safe retry',async()=>{
 const db=setup();db.failAt=3;await assert.rejects(replaceConfirmedHistory(db,1,now),/Simulated write failure/);assert.equal(db.sqlite.prepare('SELECT COUNT(*) n FROM revisions').get().n,1);assert.equal(db.sqlite.prepare('SELECT COUNT(*) n FROM history_replacements').get().n,0);assert.equal(db.sqlite.prepare('SELECT version FROM draft').get().version,8);assert.equal(db.sqlite.prepare('SELECT used FROM telegram_pending').get().used,0);db.failAt=-1;assert.equal((await replaceConfirmedHistory(db,1,now)).status,200);db.sqlite.close();
});
test('anonymous and wrong-token operation calls cannot mutate prices; GET never applies replacement',async()=>{
 const db=setup();for(const [method,token,expected] of [['GET','',404],['POST','',401],['POST','Bearer '+('a'.repeat(64)),401]]){const r=await handle(new Request('https://rates.example'+replacementPath,{method,headers:{Authorization:token},...(method==='POST'?{body:JSON.stringify({expected_revision:1})}:{})}),db,null,'');assert.equal(r.status,expected);}
 assert.equal(db.sqlite.prepare('SELECT COUNT(*) n FROM revisions').get().n,1);assert.equal(db.sqlite.prepare('SELECT COUNT(*) n FROM history_replacements').get().n,0);db.sqlite.close();
});
