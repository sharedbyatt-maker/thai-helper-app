// Archive a publication and publish the remaining latest sheet as a new state.
// The new ID keeps client caches and Telegram confirmation guards monotonic.
export async function deletePublishedRevision(db,id,expectedRevision,expectedVersion,now=Date.now()) {
 if(!Number.isSafeInteger(id)||id<=0||!Number.isSafeInteger(expectedRevision)||!Number.isSafeInteger(expectedVersion))return {status:400,data:{error:'တင်ချက်နံပါတ်နဲ့ လက်ရှိ version လိုပါတယ်။'}};
 const row=await db.prepare('SELECT * FROM revisions WHERE id=?').bind(id).first();
 if(!row){const archived=await db.prepare('SELECT id FROM revision_trash WHERE id=?').bind(id).first();return archived?{status:200,data:{ok:true,already_deleted:true}}:{status:404,data:{error:'ဒီတင်ချက် မရှိတော့ပါဘူး။'}};}
 const latest=await db.prepare('SELECT * FROM revisions ORDER BY id DESC LIMIT 1').first();
 const remaining=await db.prepare('SELECT payload FROM revisions WHERE id<>? ORDER BY id DESC LIMIT 1').bind(id).first();
 const empty=JSON.stringify({notice:'',quotes:[]});
 const fallback=latest.id===id?(remaining?.payload||empty):latest.payload;
 const request=crypto.randomUUID(),at=new Date(now).toISOString();
 const guard='EXISTS(SELECT 1 FROM revision_trash WHERE id=? AND request_id=?)';
 const result=await db.batch([
  db.prepare('INSERT OR IGNORE INTO revision_trash(id,payload,published_at,deleted_at,request_id) SELECT id,payload,published_at,?,? FROM revisions WHERE id=? AND (SELECT MAX(id) FROM revisions)=? AND (SELECT version FROM draft WHERE id=1)=? AND EXISTS(SELECT 1 FROM admin_owner WHERE id=1)').bind(at,request,id,expectedRevision,expectedVersion),
  db.prepare(`DELETE FROM revisions WHERE id=? AND ${guard}`).bind(id,id,request),
  db.prepare(`INSERT INTO revisions(payload,published_at) SELECT ?,? WHERE ${guard}`).bind(fallback,at,id,request),
  db.prepare(`UPDATE draft SET payload=CASE WHEN ?=1 AND payload=? THEN ? ELSE payload END,version=version+1 WHERE id=1 AND ${guard}`).bind(latest.id===id?1:0,row.payload,fallback,id,request),
  db.prepare(`UPDATE telegram_pending SET used=1 WHERE used=0 AND ${guard}`).bind(id,request),
  db.prepare(`UPDATE alert_outbox SET status=2 WHERE status=0 AND ${guard}`).bind(id,request),
 ]);
 return result[0].meta.changes?{status:200,data:{ok:true,already_deleted:false}}:{status:409,data:{error:'နှုန်း ဒါမှမဟုတ် မူကြမ်း ပြောင်းသွားပြီ။ နောက်ဆုံးစာရင်း ပြန်ယူပြီးမှ ဖျက်ပေးပါ။'}};
}
