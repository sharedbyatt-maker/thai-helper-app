import { validate } from './validate.mjs';

// The owner confirmed these six daily closing observations from supplied
// screenshots on 2026-10-17. Both columns are THB per 100,000 MMK.
export const replacementId = 'owner-confirmed-viber-2026-10-12-through-17';
export const replacementPath = '/api/ops/confirmed-history-20261017';
export const tokenHash = 'a455fee97657caac291ee0738cf3b3c8d3a1ca4f0a920e0a3ab22a7abd983651';
export const confirmedDays = Object.freeze([
 ['2026-10-12', '19:28', 738, 760],
 ['2026-10-13', '16:19', 733, 755],
 ['2026-10-14', '19:14', 720, 745],
 ['2026-10-15', '12:00', 706, 740],
 ['2026-10-16', '17:12', 724, 748],
 ['2026-10-17', '12:31', 724, 748],
]);
export function confirmedSheets(now=Date.now()) {
 return confirmedDays.map(([day,time,mmk,thb])=>{
  const observed=new Date(`${day}T${time}:00+07:00`);
  const quotes=[['mmk_thb',mmk,'ကျပ်ပေး → ဘတ်ယူ'],['thb_mmk',thb,'ဘတ်ပေး → ကျပ်ယူ']].map(([direction,price,label])=>({
   id:`daily-${direction}`,label,direction,rate_micros:Math.round(100000000000/price),flat_fee_minor:0,fee_bps:0,
   source_name:'နေ့စဉ်ရည်ညွှန်းနှုန်း',source_url:'',payout_method:'မဖော်ပြထားပါ',note:'',source_checked:true,
   observed_at:observed.toISOString(),valid_until:new Date(+observed+86400000).toISOString(),
  }));
  return validate({notice:'',quotes},now);
 });
}
export async function authorizedReplacement(req) {
 const token=req.headers.get('Authorization')?.match(/^Bearer ([a-f0-9]{64})$/)?.[1];
 if(!token)return false;
 const digest=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(token));
 const hash=Array.from(new Uint8Array(digest),x=>x.toString(16).padStart(2,'0')).join('');
 return hash===tokenHash;
}
export async function replaceConfirmedHistory(db,expectedRevision,now=Date.now()) {
 if(!Number.isSafeInteger(expectedRevision)||expectedRevision<0)return {status:400,data:{error:'expected_revision required'}};
 const prior=await db.prepare('SELECT applied_at,summary_json FROM history_replacements WHERE id=?').bind(replacementId).first();
 if(prior?.applied_at)return {status:200,data:{ok:true,already_applied:true,...JSON.parse(prior.summary_json)}};
 const rows=(await db.prepare('SELECT id,payload,published_at FROM revisions ORDER BY id ASC').all()).results;
 const draft=await db.prepare('SELECT id,payload,version FROM draft WHERE id=1').first();
 const latest=rows.at(-1)?.id??0;
 if(latest!==expectedRevision)return {status:409,data:{error:'Published prices changed. Read the current revision again.'}};
 const sheets=confirmedSheets(now),requestId=crypto.randomUUID(),at=new Date(now).toISOString();
 const summary={replacement_id:replacementId,days:6,observations:12,from:'2026-10-12',to:'2026-10-17'};
 const guard='EXISTS(SELECT 1 FROM history_replacements WHERE id=? AND request_id=? AND applied_at IS NULL)';
 const bindGuard=s=>s.bind(replacementId,requestId);
 const statements=[
  db.prepare('INSERT OR IGNORE INTO history_replacements(id,request_id,created_at,backup_json,summary_json) SELECT ?,?,?,?,? WHERE COALESCE((SELECT MAX(id) FROM revisions),0)=? AND COALESCE((SELECT version FROM draft WHERE id=1),-1)=? AND EXISTS(SELECT 1 FROM admin_owner WHERE id=1)').bind(replacementId,requestId,at,JSON.stringify({revisions:rows,draft}),JSON.stringify(summary),expectedRevision,draft?.version??-1),
  bindGuard(db.prepare(`DELETE FROM revisions WHERE ${guard}`)),
  ...sheets.map(sheet=>db.prepare(`INSERT INTO revisions(payload,published_at) SELECT ?,? WHERE ${guard}`).bind(JSON.stringify(sheet),at,replacementId,requestId)),
  db.prepare(`INSERT INTO draft(id,payload,version) SELECT 1,?,0 WHERE ${guard} ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,version=draft.version+1`).bind(JSON.stringify(sheets.at(-1)),replacementId,requestId),
  bindGuard(db.prepare(`UPDATE telegram_pending SET used=1 WHERE used=0 AND ${guard}`)),
  db.prepare('UPDATE history_replacements SET applied_at=? WHERE id=? AND request_id=? AND applied_at IS NULL').bind(at,replacementId,requestId),
 ];
 const result=await db.batch(statements);
 if(result[0].meta.changes)return {status:200,data:{ok:true,already_applied:false,...summary}};
 const completed=await db.prepare('SELECT applied_at,summary_json FROM history_replacements WHERE id=?').bind(replacementId).first();
 return completed?.applied_at?{status:200,data:{ok:true,already_applied:true,...JSON.parse(completed.summary_json)}}:{status:409,data:{error:'Prices or draft changed; nothing was replaced.'}};
}
