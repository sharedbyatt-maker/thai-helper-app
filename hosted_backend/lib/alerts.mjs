// Public notification commands never enter the owner publishing workflow.
const APP='https://sharedbyatt-maker.github.io/thai-helper-app/';
const sideName=d=>d==='thb_mmk'?'ဘတ်ပေး → ကျပ်ယူ':'ကျပ်ပေး → ဘတ်ယူ';
const day=t=>new Date(t+7*3600000).toISOString().slice(0,10);
const reply=(chat,text,extra={})=>({method:'sendMessage',chat_id:chat,text,...extra});
const controls={inline_keyboard:[[{text:'အသိပေးတာ ရပ်မယ်',callback_data:'alerts_stop'}],[{text:'App ကြည့်မယ်',url:APP}]]};
export async function subscriberCommand(db,row,chat,text,callback) {
 if(callback==='alerts_stop'||text==='/stop') {
  await db.prepare('UPDATE alert_subscribers SET active=0,version=version+1 WHERE chat_id=?').bind(chat).run();
  return reply(chat,'ဈေးအသိပေးတာ ရပ်ထားပြီ။ App ထဲက ခေါင်းလောင်းကိုနှိပ်ပြီး ပြန်ဖွင့်နိုင်တယ်။');
 }
 const match=/^\/start (news|watch)_(thb_mmk|mmk_thb)(?:_(\d{1,8}))?$/.exec(text);
 if(!match)return null;
 const [,mode,direction,raw]=match, threshold=mode==='watch'?Number(raw):null;
 if((mode==='watch'&&(!Number.isSafeInteger(threshold)||threshold<100||threshold>10000000))||(mode==='news'&&raw))return reply(chat,'သတ်မှတ်ထားတဲ့ဈေး မမှန်သေးဘူး။ App ကနေ ပြန်ရွေးပေးပါ။');
 const revision=await db.prepare('SELECT id,payload FROM revisions ORDER BY id DESC LIMIT 1').first();
 const initial=revision?JSON.parse(revision.payload).quotes.find(q=>q.direction===direction):null;
 const signature=initial?`${day(Date.parse(initial.observed_at))}:${initial.rate_micros}:${initial.flat_fee_minor||0}:${initial.fee_bps||0}`:'';
 // Reopening a link is an explicit new subscription. Old queued messages cannot leak through its version.
 await db.prepare(`INSERT INTO alert_subscribers(chat_id,bot,direction,mode,threshold,active,version,evaluated_revision,last_signature,created_at) VALUES(?,?,?,?,?,1,1,?,?,?) ON CONFLICT(chat_id) DO UPDATE SET bot=excluded.bot,direction=excluded.direction,mode=excluded.mode,threshold=excluded.threshold,active=1,version=alert_subscribers.version+1,evaluated_revision=excluded.evaluated_revision,last_signature=excluded.last_signature`).bind(chat,row.username,direction,mode,threshold,revision?.id||0,signature,Date.now()).run();
 const meaning=mode==='news'?'ဈေးအသစ်တင်တဲ့အခါ အသိပေးမယ်။ တစ်ရက်တည်း ဈေးမပြောင်းဘဲ ပြန်တင်တာကို ထပ်မပို့ဘူး။':`ကျပ် ၁ သိန်းအတွက် ${threshold/100} ဘတ် ${direction==='thb_mmk'?'သို့မဟုတ် အောက် ပေးရတဲ့ဈေး':'သို့မဟုတ် အထက် ရတဲ့ဈေး'} အသစ်တင်လာရင် တစ်ခါ အသိပေးမယ်။`;
 return reply(chat,`${sideName(direction)}\n${meaning}\n\nဘတ်ဈေး app မှာ စစ်ပြီးတင်ထားတဲ့ နှုန်းအချက်အလက်ကိုပဲ အသုံးပြုပါတယ်။ /stop နဲ့ ရပ်နိုင်တယ်။`,{reply_markup:controls});
}
export async function queueAlerts(db,bot,now=Date.now()) {
 const latest=await db.prepare('SELECT id,payload FROM revisions ORDER BY id DESC LIMIT 1').first();
 if(!latest)return;
 const quotes=JSON.parse(latest.payload).quotes||[];
 const pending=await db.prepare('SELECT * FROM alert_subscribers WHERE active=1 AND bot=? AND evaluated_revision<? ORDER BY evaluated_revision LIMIT 100').bind(bot,latest.id).all();
 for(const sub of pending.results) {
  const q=quotes.find(q=>q.direction===sub.direction);
  const fresh=q&&Date.parse(q.valid_until)>now&&Date.parse(q.observed_at)<=now+300000;
  const signature=fresh?`${day(Date.parse(q.observed_at))}:${q.rate_micros}:${q.flat_fee_minor||0}:${q.fee_bps||0}`:sub.last_signature;
  const rate=fresh?100000000000/q.rate_micros:null;
  const hit=fresh&&signature!==sub.last_signature&&(sub.mode==='news'?signature!==sub.last_signature:sub.direction==='thb_mmk'?rate<=sub.threshold/100+.005:rate>=sub.threshold/100-.005);
  const id=`${sub.chat_id}:${sub.version}:${latest.id}`;
  const text=hit?`${sub.mode==='watch'?'စောင့်ထားတဲ့ဈေး ရောက်လာပြီ':'ဈေးအသစ် တင်ထားပြီ'}\n${sideName(q.direction)}\n${q.direction==='thb_mmk'?`ဘတ် ${Number(rate.toFixed(2))} ပေး → ကျပ် ၁ သိန်း ရ`:`ကျပ် ၁ သိန်း ပေး → ဘတ် ${Number(rate.toFixed(2))} ရ`}\nဈေးစစ်ချိန် ${new Date(q.observed_at).toLocaleString('en-GB',{timeZone:'Asia/Bangkok'})} (ထိုင်း)\n\nငွေမလဲခင် နောက်ဆုံးဈေးကို ပြန်မေးပေးပါ။\n${APP}\n/stop နဲ့ အသိပေးတာ ရပ်နိုင်တယ်။`:'';
  await db.batch([
   db.prepare(`INSERT OR IGNORE INTO alert_outbox(id,chat_id,subscription_version,revision,payload,status,attempts,next_attempt) SELECT ?,?,?,?,?,0,0,0 WHERE ?=1 AND EXISTS(SELECT 1 FROM alert_subscribers WHERE chat_id=? AND version=? AND active=1 AND evaluated_revision<?)`).bind(id,sub.chat_id,sub.version,latest.id,JSON.stringify({message:reply(sub.chat_id,text,{reply_markup:controls}),valid_until:q?.valid_until}),hit?1:0,sub.chat_id,sub.version,latest.id),
   db.prepare('UPDATE alert_subscribers SET evaluated_revision=?,last_signature=? WHERE chat_id=? AND version=? AND evaluated_revision<?').bind(latest.id,signature,sub.chat_id,sub.version,latest.id),
  ]);
 }
}
export async function deliverAlerts(db,token,bot,fetcher=fetch,now=Date.now()) {
 const rows=await db.prepare(`SELECT o.* FROM alert_outbox o JOIN alert_subscribers s ON s.chat_id=o.chat_id AND s.version=o.subscription_version WHERE s.bot=? AND s.active=1 AND o.status=0 AND o.next_attempt<=? AND o.attempts<5 ORDER BY o.revision LIMIT 10`).bind(bot,now).all();
 for(const item of rows.results) {
  const payload=JSON.parse(item.payload);
  if(Date.parse(payload.valid_until)<=now){await db.prepare('UPDATE alert_outbox SET status=2 WHERE id=?').bind(item.id).run();continue;}
  // A bounded lease prevents concurrent API reads from sending the same queued alert.
  const claimed=await db.prepare('UPDATE alert_outbox SET next_attempt=?,attempts=attempts+1 WHERE id=? AND status=0 AND next_attempt<=? AND EXISTS(SELECT 1 FROM alert_subscribers WHERE chat_id=? AND version=? AND active=1)').bind(now+60000,item.id,now,item.chat_id,item.subscription_version).run();
  if(!claimed.meta.changes)continue;
  try {
   const res=await fetcher(`https://api.telegram.org/bot${token}/sendMessage`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload.message),signal:AbortSignal.timeout(8000)});
   const data=await res.json();
   if(data.ok) {
    await db.prepare('UPDATE alert_outbox SET status=1 WHERE id=?').bind(item.id).run();
    const sub=await db.prepare('SELECT mode FROM alert_subscribers WHERE chat_id=? AND version=?').bind(item.chat_id,item.subscription_version).first();
    if(sub?.mode==='watch')await db.prepare('UPDATE alert_subscribers SET active=0 WHERE chat_id=? AND version=?').bind(item.chat_id,item.subscription_version).run();
   } else if(data.error_code===403||data.error_code===400) {
    await db.prepare('UPDATE alert_subscribers SET active=0 WHERE chat_id=? AND version=?').bind(item.chat_id,item.subscription_version).run();
    await db.prepare('UPDATE alert_outbox SET status=2 WHERE id=?').bind(item.id).run();
   } else {
    const delay=Math.min(3600,Math.max(60,Number(data.parameters?.retry_after)||60));
    await db.prepare('UPDATE alert_outbox SET next_attempt=? WHERE id=?').bind(now+delay*1000,item.id).run();
    if(data.error_code===429)break;
   }
  } catch { /* The next publish/read retries the durable item after its lease. */ }
  if(item.attempts>=4)await db.prepare('UPDATE alert_outbox SET status=2 WHERE id=? AND status=0').bind(item.id).run();
 }
 await db.prepare('DELETE FROM alert_outbox WHERE revision<(SELECT COALESCE(MAX(id),0)-100 FROM revisions) AND status<>0').run();
 return rows.results.length;
}
