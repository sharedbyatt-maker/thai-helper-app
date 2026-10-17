import { confirmedSheets } from './confirmed-history.mjs';
import { deletePublishedRevision } from './revision-management.mjs';
export const repairPath='/api/ops/remove-owner-test-20261017';
const tokenHash='ff4a3d485a46ac18c70c36bd7fdeb15cd97a3996618bffb2d81608fa11453308';
export async function repairTestPublication(req,db,expectedHash=tokenHash) {
 const token=req.headers.get('Authorization')?.match(/^Bearer ([a-f0-9]{64})$/)?.[1];
 const digest=token?await crypto.subtle.digest('SHA-256',new TextEncoder().encode(token)):new ArrayBuffer(0);
 const hash=Array.from(new Uint8Array(digest),x=>x.toString(16).padStart(2,'0')).join('');
 if(hash!==expectedHash)return {status:401,data:{error:'Unauthorized'}};
 const done=await db.prepare('SELECT id FROM revision_trash WHERE id=10').first();
 if(done)return {status:200,data:{ok:true,already_deleted:true}};
 const rows=(await db.prepare('SELECT * FROM revisions ORDER BY id').all()).results;
 const latest=rows.at(-1),draft=await db.prepare('SELECT version FROM draft WHERE id=1').first();
 const sameQuotes=(actual,expected)=>actual.length===expected.length&&expected.every(q=>actual.some(a=>a.direction===q.direction&&a.rate_micros===q.rate_micros&&a.observed_at===q.observed_at));
 const six=confirmedSheets();
 const baseline=rows.length===7&&rows.slice(0,6).every((r,i)=>sameQuotes(JSON.parse(r.payload).quotes,six[i].quotes));
 const trial=latest&&JSON.parse(latest.payload).quotes;
 if(!baseline||latest?.id!==10||!trial||trial.length!==2||!trial.some(q=>q.direction==='mmk_thb'&&q.rate_micros===Math.round(100000000000/780))||!trial.some(q=>q.direction==='thb_mmk'&&q.rate_micros===Math.round(100000000000/800)))return {status:409,data:{error:'Live prices changed; nothing removed.'}};
 return deletePublishedRevision(db,10,10,draft?.version);
}
