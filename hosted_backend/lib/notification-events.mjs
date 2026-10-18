export const APP_URL='https://sharedbyatt-maker.github.io/thai-helper-app/';
export function eventInsert(db,kind,request,now,revisionSql,args=[]){
 return db.prepare(`INSERT OR IGNORE INTO notification_events(revision,request_id,payload,kind,created_at,expires_at) SELECT id,?,payload,?,?,? FROM revisions WHERE ${revisionSql}`).bind(request,kind,now,now+86400000,...args);
}
export function pushPayload(event,now=Date.now()){
 const sheet=JSON.parse(event.payload);
 const fresh=(sheet.quotes||[]).filter(q=>Date.parse(q.observed_at)<=now&&Date.parse(q.valid_until)>now);
 const prices=fresh.map(q=>{const rate=Number((100000000000/q.rate_micros).toFixed(2));const meaning=q.direction==='mmk_thb'?`ကျပ် ၁ သိန်း → ${rate} ဘတ်`:`${rate} ဘတ် → ကျပ် ၁ သိန်း`;return meaning+' · '+new Date(q.observed_at).toLocaleString('en-GB',{timeZone:'Asia/Bangkok',day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit'});}).join('\n');
 const notice=typeof sheet.notice==='string'?sheet.notice.trim():'';
 if(event.kind==='rates'&&!fresh.length)return null;
 if(event.kind==='announcement'&&!notice)return null;
 return {title:event.kind==='announcement'?'ဘတ်ဈေး · ကြေညာချက်':'ဘတ်ဈေး · ဈေးနှုန်း တင်ထားပြီ',body:event.kind==='announcement'?notice:prices+'\nနှုန်းတစ်ဘက်ချင်းရဲ့ စစ်ချိန် · ထိုင်းအချိန်',url:APP_URL,tag:'bahtzay-'+event.kind,revision:event.revision,kind:event.kind,expires_at:Math.min(event.expires_at,...(event.kind==='rates'?fresh.map(q=>Date.parse(q.valid_until)):[]))};
}
export async function publishAnnouncement(db,notice,expectedRevision,expectedVersion,now=Date.now()){
 if(typeof notice!=='string'||!notice.trim()||notice.trim().length>500||!Number.isSafeInteger(expectedRevision))return {status:400,data:{error:'ကြေညာစာကို စာလုံး ၅၀၀ အတွင်း ဖြည့်ပေးပါ။'}};
 const latest=await db.prepare('SELECT * FROM revisions ORDER BY id DESC LIMIT 1').first();
 if((latest?.id||0)!==expectedRevision)return {status:409,data:{error:'နှုန်းပြောင်းသွားပြီ။ နောက်ဆုံးစာရင်း ပြန်ယူပေးပါ။'}};
 const previous=latest?.payload||JSON.stringify({notice:'',quotes:[]});
 const payload=JSON.stringify({...JSON.parse(previous),notice:notice.trim()});
 const request=crypto.randomUUID(),at=new Date(now).toISOString();
 const guard='EXISTS(SELECT 1 FROM notification_events WHERE request_id=?)';
 const results=await db.batch([
  db.prepare('INSERT INTO revisions(payload,published_at) SELECT ?,? WHERE COALESCE((SELECT MAX(id) FROM revisions),0)=? AND (SELECT version FROM draft WHERE id=1)=?').bind(payload,at,expectedRevision,expectedVersion),
  eventInsert(db,'announcement',request,now,'id=last_insert_rowid() AND changes()=1'),
  db.prepare(`UPDATE draft SET payload=CASE WHEN payload=? THEN ? ELSE payload END,version=version+1 WHERE id=1 AND ${guard}`).bind(previous,payload,request),
  db.prepare(`UPDATE telegram_pending SET used=1 WHERE used=0 AND ${guard}`).bind(request),
 ]);
 return results[0].meta.changes?{status:200,data:{ok:true}}:{status:409,data:{error:'မူကြမ်း ပြောင်းသွားပြီ။ နောက်ဆုံးစာရင်း ပြန်ယူပေးပါ။'}};
}
