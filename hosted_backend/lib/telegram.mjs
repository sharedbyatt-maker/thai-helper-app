import { validate, Invalid } from './validate.mjs';
import { subscriberCommand,queueAlerts,deliverAlerts } from './alerts.mjs';
const enc = new TextEncoder();
const hex = bytes => Array.from(bytes, b => b.toString(16).padStart(2, '0')).join('');
const unhex = s => Uint8Array.from(s.match(/../g) || [], b => parseInt(b, 16));
const random = () => hex(crypto.getRandomValues(new Uint8Array(24)));
const sha = async s => hex(new Uint8Array(await crypto.subtle.digest('SHA-256', enc.encode(s))));
const fail = s => { throw new Invalid(s); };
const directionName = d => d === 'mmk_thb' ? 'ကျပ်ပေး → ဘတ်ယူ' : 'ဘတ်ပေး → ကျပ်ယူ';
const APP_URL = 'https://sharedbyatt-maker.github.io/thai-helper-app/';
const DEFAULT_SOURCE = 'နေ့စဉ်ရည်ညွှန်းနှုန်း';
export const normalize = s => s.replace(/[၀-၉๐-๙]/g, c => '၀၁၂၃၄၅၆၇၈၉'.includes(c) ? '၀၁၂၃၄၅၆၇၈၉'.indexOf(c) : '๐๑๒๓๔๕๖๗๘๙'.indexOf(c)).replace(/(?<=\d),(?=\d)/g, '');
export function parseRates(input, defaultDirection = 'mmk_thb') {
 const text = normalize(input).trim();
 if(text.length > 8000) return {candidates:[], error:'စာရှည်လွန်းသည်။ နှုန်းပါတဲ့စာပိုဒ်ကိုပဲ ကူးပို့ပါ။'};
 if(/^\d+(?:\.\d{1,2})?$/.test(text)) return {candidates:[{rate:Number(text),direction:defaultDirection}]};
 let direction = null, found = [], range = false;
 for(const line of text.split(/\n/)) {
  const compact = line.replace(/[\s:：()（）\-–→]/g,'');
  const kyatFirst=/ကျပ်ပေး.*ဘတ်ယူ/.test(compact)||/^(?:k|mmk)(?:to|2)?(?:b|thb)(?=\d|$)/i.test(compact);
  const bahtFirst=/ဘတ်ပေး.*ကျပ်ယူ/.test(compact)||/^(?:b|thb)(?:to|2)?(?:k|mmk)(?=\d|$)/i.test(compact);
  if(kyatFirst)direction='mmk_thb';else if(bahtFirst)direction='thb_mmk';
  const explicit = /(?:ကျပ်|mmk)\s*(?:1\s*သိန်း|100000)\s*(?:=|ကို|အတွက်)\s*(\d+(?:\.\d{1,2})?)\s*(?:ဘတ်|thb)/i.exec(line);
  if(explicit) {found.push({rate:Number(explicit[1]),direction:direction||defaultDirection});continue;}
  if(!direction)continue;
  if(/phone|account|ဖုန်း|အကောင့်|vnd|usd/i.test(line))continue;
  if(!kyatFirst&&!bahtFirst&&!/(?:သိန်း|အထက်)/.test(compact) && !/^\s*\d+(?:\.\d{1,2})?\s*$/.test(line))continue;
  // Only a trailing rate is accepted. Thresholds, dates, phones and bank account numbers are never guessed.
  if(/\d\s*[-–]\s*\d+(?:\.\d+)?\s*[)\s]*$/.test(line)){range=true;continue;}
  const match = /(\d+(?:\.\d{1,2})?)\s*(?:ဘတ်|THB)?\s*[)\s]*$/i.exec(line);
  if(match && !/(?:သိန်း|အထက်|ရက်|နေ့|:|\/)\s*$/.test(match[0]) && !/\d{4}[-/]\d/.test(line)) found.push({rate:Number(match[1]),direction});
 }
 found=found.filter(q=>q.rate>=1&&q.rate<=100000);
 found=found.filter((q,i,a)=>a.findIndex(x=>x.rate===q.rate&&x.direction===q.direction)===i).slice(0,12);
 return {candidates:found,range};
}
async function aesKey(secret) {
 if(!/^[a-f0-9]{64}$/.test(secret||'')) throw new Error('Telegram encryption unavailable');
 return crypto.subtle.importKey('raw',unhex(secret),'AES-GCM',false,['encrypt','decrypt']);
}
export async function seal(value, secret) {
 const iv=crypto.getRandomValues(new Uint8Array(12));
 const data=await crypto.subtle.encrypt({name:'AES-GCM',iv,additionalData:enc.encode('bahtzay.telegram.v1')},await aesKey(secret),enc.encode(JSON.stringify(value)));
 return hex(iv)+'.'+hex(new Uint8Array(data));
}
export async function unseal(value, secret) {
 const [iv,data]=value.split('.');
 return JSON.parse(new TextDecoder().decode(await crypto.subtle.decrypt({name:'AES-GCM',iv:unhex(iv),additionalData:enc.encode('bahtzay.telegram.v1')},await aesKey(secret),unhex(data))));
}
async function telegram(token, method, body, fetcher) {
 let result;
 try {
  const res=await fetcher('https://api.telegram.org/bot'+token+'/'+method,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(12000)});
  result=await res.json();
 } catch {fail('Telegram ကို ဆက်သွယ်မရပါ။ ခဏနေ ပြန်စမ်းပါ။');}
 if(!result?.ok)fail('Telegram ချိတ်ဆက်မှု မအောင်မြင်ပါ။ Bot token နှင့် bot အခြေအနေကို ပြန်စစ်ပါ။');
 return result.result;
}
const configRow = db => db.prepare('SELECT * FROM telegram_settings WHERE id=1').first();
const cleanText = (v,n) => typeof v==='string' && v.trim().length<=n ? v.trim() : '';
const summary = (row,c) => ({configured:!!row,username:row?.username||'',paired:!!row?.owner_id,owner_id:row?.owner_id||'',source_name:c?.source_name||'',source_url:c?.source_url||'',direction:c?.direction||'mmk_thb',enabled:c?.enabled===true});
export async function publicTelegramInfo(db,runtime={}) {
 const row=await configRow(db);
 if(!row)return {available:false,username:''};
 const c=await unseal(row.sealed,runtime.telegramKey);
 return {available:c.enabled===true,username:c.enabled?row.username:''};
}
let lastBackgroundAttempt=0;
export function scheduleAlerts(db,runtime={},force=false) {
 if(!runtime.waitUntil)return;
 // Public minute-by-minute polls share a cheap per-isolate cooldown. Confirmed
 // publications and owner retry requests always bypass it; no request context is cached.
 const now=Date.now();
 if(!force&&now-lastBackgroundAttempt<60000)return;
 lastBackgroundAttempt=now;
 runtime.waitUntil((async()=>{
  const row=await configRow(db);if(!row)return;
  const c=await unseal(row.sealed,runtime.telegramKey);if(!c.enabled)return;
  const deadline=Date.now()+20000;
  for(let i=0;i<10&&Date.now()<deadline;i++){
   await queueAlerts(db,row.username);
   if(!await deliverAlerts(db,c.token,row.username,runtime.fetcher||fetch))break;
  }
 })().catch(()=>console.error('Notification delivery deferred')));
}
export async function adminTelegram(req, db, path, data, runtime={}) {
 const secret=runtime.telegramKey, fetcher=runtime.fetcher||fetch;
 const row=await configRow(db), c=row?await unseal(row.sealed,secret):null;
 if(req.method==='GET' && path==='/api/admin/telegram')return summary(row,c);
 if(req.method!=='POST')return null;
 if(path==='/api/admin/telegram/pair') {
  if(!row||!c?.enabled)fail('Bot ကို အရင်ချိတ်ဆက်ပါ။');
  const nonce=random();
  await db.prepare('UPDATE telegram_settings SET pair_hash=?,pair_until=? WHERE id=1 AND generation=?').bind(await sha(nonce),Date.now()+600000,row.generation).run();
  return {url:'https://t.me/'+row.username+'?start=pair_'+nonce,expires_in:600};
 }
 if(path==='/api/admin/telegram/disconnect') {
  if(row) {
   // Disable locally first: a failed Telegram network call cannot leave publishing enabled.
   await db.prepare('UPDATE telegram_settings SET sealed=?,owner_id=NULL,pair_hash=NULL,pair_until=NULL,generation=generation+1 WHERE id=1').bind(await seal({...c,enabled:false},secret)).run();
   try{await telegram(c.token,'deleteWebhook',{},fetcher);}catch{}
  }
  return {ok:true};
 }
 if(path==='/api/admin/telegram') {
  const token=cleanText(data.token,200)||c?.token;
  if(!/^\d{5,20}:[A-Za-z0-9_-]{20,150}$/.test(token||''))fail('BotFather မှရသော bot token ကို ဖြည့်ပါ။');
  const source=cleanText(data.source_name,150)||DEFAULT_SOURCE;
  const url=cleanText(data.source_url,500);
  if(url){let u;try{u=new URL(url);}catch{fail('Source link မမှန်ပါ။');}if(!['http:','https:'].includes(u.protocol)||u.username||u.password)fail('http/https source link သာ သုံးပါ။');}
  if(!['mmk_thb','thb_mmk'].includes(data.direction))fail('ဦးတည်ချက်ကို ရွေးပါ။');
  const me=await telegram(token,'getMe',{},fetcher);
  if(!me?.is_bot||!/^\w{5,32}$/.test(me.username||''))fail('Bot token ကို ပြန်စစ်ပါ။');
  const same=row?.username===me.username;
  const webhookSecret=same?c.webhookSecret:random();
  const next={token,webhookSecret,source_name:source,source_url:url,direction:data.direction,enabled:true};
  // Stable secret when updating the same bot prevents a config/webhook mismatch.
  await telegram(token,'setWebhook',{url:new URL('/api/telegram/webhook',req.url).href,secret_token:webhookSecret,allowed_updates:['message','callback_query'],drop_pending_updates:!same},fetcher);
  await db.prepare('INSERT INTO telegram_settings(id,sealed,username,owner_id,generation) VALUES(1,?,?,?,0) ON CONFLICT(id) DO UPDATE SET sealed=excluded.sealed,username=excluded.username,owner_id=excluded.owner_id,pair_hash=NULL,pair_until=NULL,generation=telegram_settings.generation+1').bind(await seal(next,secret),me.username,same?row.owner_id:null).run();
  await db.prepare('DELETE FROM telegram_session WHERE id=1').run();
  return {...summary({...row,username:me.username,owner_id:same?row.owner_id:null},next),configured:true};
 }
 return null;
}
const reply = (chat,text,extra={}) => ({method:'sendMessage',chat_id:chat,text,...extra});
async function receipt(db,id,response) {
 await db.prepare('INSERT OR IGNORE INTO telegram_receipts(id,request_id,response,created_at) VALUES(?,?,?,?)').bind(id,random(),JSON.stringify(response),Date.now()).run();
 return response;
}
async function pendingReply(db,row,updateId,chat,payload,makeResponse,previousId=null) {
 const pendingId=random(), requestId=random(), now=Date.now();
 const response=makeResponse(pendingId);
 const check=previousId?' AND EXISTS(SELECT 1 FROM telegram_pending WHERE id=? AND owner_id=? AND used=0 AND expires>?)':'';
 const args=[updateId,requestId,JSON.stringify(response),now,row.generation,chat,...(previousId?[previousId,chat,now]:[])];
 const result=await db.batch([
  db.prepare('INSERT OR IGNORE INTO telegram_receipts(id,request_id,response,created_at) SELECT ?,?,?,? WHERE EXISTS(SELECT 1 FROM telegram_settings WHERE id=1 AND generation=? AND owner_id=?)'+check).bind(...args),
  db.prepare('UPDATE telegram_pending SET used=1 WHERE owner_id=? AND EXISTS(SELECT 1 FROM telegram_receipts WHERE id=? AND request_id=?)').bind(chat,updateId,requestId),
  db.prepare('INSERT INTO telegram_pending(id,owner_id,payload,expires) SELECT ?,?,?,? WHERE EXISTS(SELECT 1 FROM telegram_receipts WHERE id=? AND request_id=?)').bind(pendingId,chat,JSON.stringify({...payload,config_generation:row.generation}),now+600000,updateId,requestId),
 ]);
 if(result[0].meta.changes)return response;
 const cached=await db.prepare('SELECT response FROM telegram_receipts WHERE id=?').bind(updateId).first();
 return cached?JSON.parse(cached.response):reply(chat,'ဒီခလုတ်ကို သုံးပြီးပါပြီ သို့မဟုတ် အချက်အလက်ပြောင်းသွားပါပြီ။ စာအသစ်ပို့ပါ။');
}
async function cancelPending(db,updateId,chat,pendingId) {
 const requestId=random(),response=reply(chat,'မတင်တော့ပါ။ App ပေါ်ရှိ နှုန်း မပြောင်းပါ။ ပြင်ချင်လျှင် နှုန်းစာအသစ်ပို့ပါ။');
 const result=await db.batch([
  db.prepare('INSERT OR IGNORE INTO telegram_receipts(id,request_id,response,created_at) SELECT ?,?,?,? WHERE EXISTS(SELECT 1 FROM telegram_pending WHERE id=? AND owner_id=? AND used=0 AND expires>?)').bind(updateId,requestId,JSON.stringify(response),Date.now(),pendingId,chat,Date.now()),
  db.prepare('UPDATE telegram_pending SET used=1 WHERE id=? AND owner_id=? AND EXISTS(SELECT 1 FROM telegram_receipts WHERE id=? AND request_id=?)').bind(pendingId,chat,updateId,requestId),
 ]);
 if(result[0].meta.changes)return response;
 const cached=await db.prepare('SELECT response FROM telegram_receipts WHERE id=?').bind(updateId).first();
 return cached?JSON.parse(cached.response):reply(chat,'ဤခလုတ်ကို သုံးပြီးသွားပါပြီ။ /status ဖြင့် တင်ထားသောနှုန်းကို ကြည့်နိုင်သည်။');
}
const opposite = direction => direction==='mmk_thb'?'thb_mmk':'mmk_thb';
const lakhRate = q => Number((100000000000/q.rate_micros).toFixed(2));
const rateMeaning = q => q.direction==='mmk_thb'?`ကျပ် ၁ သိန်း ပေး → ဘတ် ${q.rate} ရ`:`ဘတ် ${q.rate} ပေး → ကျပ် ၁ သိန်း ရ`;
async function askOther(db,row,updateId,chat,candidate,source,previousId=null,options=[]) {
 const direction=opposite(candidate.direction);
 const current=await db.prepare('SELECT payload FROM revisions ORDER BY id DESC LIMIT 1').first();
 const existing=current?JSON.parse(current.payload).quotes.find(q=>q.direction===direction):null;
 const text=`ဒီဘက်နှုန်း ရပါပြီ — ${rateMeaning(candidate)}\n\n${directionName(direction)} နှုန်းလည်း ထည့်ဦးမလား?\nနှစ်ဘက်နှုန်း မတူနိုင်သဖြင့် အလိုအလျောက် ပြန်မတွက်ပါ။\n${existing?`မထည့်သေးလျှင် ယခင် ${lakhRate(existing)} ဘတ်နှုန်းကို မူလစစ်ချိန်အတိုင်း ဆက်ထားမည်။`:'မထည့်သေးလျှင် ဒီဘက်နှုန်းကို အလွတ်ထားမည်။'}\n\nရွေးပြီးနောက် Public နမူနာကို စစ်ပေးရမည်။ အခု မတင်ရသေးပါ။`;
 return pendingReply(db,row,updateId,chat,{stage:'ask_other',candidates:[candidate],source,options:options.filter(q=>q.direction===direction)},pendingId=>reply(chat,text,{reply_markup:{inline_keyboard:[[{text:'ဟုတ်တယ်၊ အခြားဘက်ပါ ထည့်မယ်',callback_data:'other:'+pendingId}],[{text:'မထည့်သေးဘူး၊ ဒီဘက်ပဲ ဆက်မယ်',callback_data:'review:'+pendingId}],[{text:'မတင်တော့ဘူး',callback_data:'cancel:'+pendingId}]]}}),previousId);
}
async function requestOther(db,row,updateId,chat,payload,previousId) {
 const direction=opposite(payload.candidates[0].direction);
 return pendingReply(db,row,updateId,chat,{...payload,stage:'await_other',expected_direction:direction},pendingId=>reply(chat,`${directionName(direction)} နှုန်းကို သီးခြားပို့ပါ။\nကျပ် ၁ သိန်းအတွက် ဘတ် ဘယ်လောက်လဲ?\nဥပမာ 748 လို့ ပို့နိုင်သည်။ ဥပမာကိန်းဂဏန်းသာ ဖြစ်သည်။\n\nထည့်ပြီးသား: ${rateMeaning(payload.candidates[0])}\nPublic မတင်ရသေးပါ။ /cancel ဖြင့် ရပ်နိုင်သည်။`,{reply_markup:{inline_keyboard:[...(payload.options||[]).map((q,i)=>[{text:`စာထဲပါ ${directionName(direction)} ${q.rate} ကို သုံးမယ်`,callback_data:`other_rate:${pendingId}:${i}`}]),[{text:'မထည့်သေးဘူး၊ ဒီဘက်ပဲ ဆက်မယ်',callback_data:'review:'+pendingId}],[{text:'မတင်တော့ဘူး',callback_data:'cancel:'+pendingId}]]}}),previousId);
}
async function previewRates(db,row,updateId,chat,candidates,source,previousId=null) {
 const current=await db.prepare('SELECT * FROM revisions ORDER BY id DESC LIMIT 1').first();
 const quotes=current?JSON.parse(current.payload).quotes:[];
 const summaries=candidates.map(candidate=>{
  const previous=quotes.find(q=>q.direction===candidate.direction),oldRate=previous?lakhRate(previous):null;
  const difference=oldRate===null?null:(candidate.rate-oldRate)/oldRate*100;
  return `${directionName(candidate.direction)}\nကျပ် ၁ သိန်း = ဘတ် ${candidate.rate}\n${rateMeaning(candidate)}\n${oldRate===null?'ယခင်နှုန်း မရှိသေးပါ။':`ယခင်နှုန်း: ကျပ် ၁ သိန်း = ဘတ် ${oldRate}`}${difference!==null&&Math.abs(difference)>=3?`\nသတိပြုရန်: ယခင်နှုန်းနှင့် ${Math.abs(difference).toFixed(2)}% ကွာနေသည်။ ပြန်စစ်ပါ။`:''}`;
 }).join('\n\n');
 const other=candidates.length===1?quotes.find(q=>q.direction!==candidates[0].direction):null;
 const retained=candidates.length===2?'နှစ်ဘက်လုံးကို ဖြည့်ထားသော သီးခြားနှုန်းများဖြင့် တင်မည်။':other?`မဖြည့်ထားသော ${directionName(other.direction)} — ယခင် ${lakhRate(other)} ဘတ်နှုန်းကို မူလစစ်ချိန်အတိုင်း ဆက်ထားမည်။`:'မဖြည့်ထားသော အခြားဘက်ကို အလွတ်ထားမည်။ ပြန်တွက်မထည့်ပါ။';
 const text=`Public မတင်ရသေးပါ — စစ်ပေးပါ\n\n${summaries}\n\nပြမည့်အမည်: ${source}\n${retained}\n\nမှန်လျှင် အောက်က Public ခလုတ်ကို နှိပ်ပါ။\nတင်ချိန်ကို အတည်ပြုချိန်အဖြစ် မှတ်မည်။ ၁ ရက်ကျော်လျှင် ပြန်မစစ်ရသေးဟု ပြမည်။\nအတည်ပြုရန် ၁၀ မိနစ်အတွင်း။ စာအသစ်ပို့လျှင် ခလုတ်ဟောင်းကို သုံးမရတော့ပါ။`;
 return pendingReply(db,row,updateId,chat,{stage:'confirm',candidates,source,base_revision:current?.id||0},pendingId=>reply(chat,text,{reply_markup:{inline_keyboard:[[{text:'မှန်တယ်၊ Public တင်မယ်',callback_data:'publish:'+pendingId}],[{text:'မတင်တော့ဘူး',callback_data:'cancel:'+pendingId}]]}}),previousId);
}
async function publish(db,row,c,updateId,chat,candidates,source,pendingId,expectedRevision) {
 for(let attempt=0;attempt<3;attempt++) {
  const previous=await db.prepare('SELECT * FROM revisions ORDER BY id DESC LIMIT 1').first();
  if((previous?.id||0)!==expectedRevision)return receipt(db,updateId,reply(chat,'Public နှုန်းပြောင်းသွားပါပြီ။ ဤနမူနာဟောင်းကို မတင်ထားပါ။ နှုန်းစာကို ပြန်ပို့ပြီး နမူနာအသစ်ကို စစ်ပါ။'));
  const old=previous?JSON.parse(previous.payload):{notice:'',quotes:[]};
  const now=new Date().toISOString();
  const updates=candidates.map(candidate=>({id:old.quotes.find(q=>q.direction===candidate.direction)?.id||'daily-'+candidate.direction,label:directionName(candidate.direction),direction:candidate.direction,rate_micros:Math.round(100000/candidate.rate*1e6),flat_fee_minor:0,fee_bps:0,source_name:source,source_url:source===c.source_name?c.source_url:'',payout_method:'မဖော်ပြထားပါ',note:'Telegram မှ စစ်ပြီးတင်သော ရည်ညွှန်းနှုန်း။ အမှန်တကယ်လဲမည့်နှုန်းကို ငွေလဲသူထံ ပြန်စစ်ပါ။',observed_at:now,valid_until:new Date(Date.now()+86400000).toISOString(),source_checked:true}));
  const sheet=validate({...old,quotes:[...old.quotes.filter(q=>!updates.some(u=>u.direction===q.direction)),...updates]});
  const payload=JSON.stringify(sheet),requestId=random();
  const response=reply(chat,`တင်ပြီးပါပြီ ✓\n${source}\n${candidates.map(rateMeaning).join('\n')}\nတင်ချိန် ${new Date().toLocaleString('en-GB',{timeZone:'Asia/Bangkok'})} (ထိုင်း)\n၁ ရက်ကျော်လျှင် ပြန်မစစ်ရသေးဟု ပြမည်။ မှတ်တမ်း မပျောက်ပါ။\n/undo ဖြင့် နောက်ဆုံး Telegram တင်ချက်ကို ပြန်ဖျက်နိုင်သည်။`,{reply_markup:{inline_keyboard:[[{text:'User app ကြည့်မယ်',url:APP_URL}]]}});
  // The receipt, both explicitly provided prices, and draft version commit together.
  const result=await db.batch([
   db.prepare('INSERT OR IGNORE INTO telegram_receipts(id,request_id,response,created_at) SELECT ?,?,?,? WHERE COALESCE((SELECT MAX(id) FROM revisions),0)=? AND EXISTS(SELECT 1 FROM telegram_settings WHERE id=1 AND generation=? AND owner_id=?) AND EXISTS(SELECT 1 FROM telegram_pending WHERE id=? AND owner_id=? AND used=0 AND expires>?)').bind(updateId,requestId,JSON.stringify(response),Date.now(),previous?.id||0,row.generation,chat,pendingId,chat,Date.now()),
   db.prepare('INSERT INTO revisions(payload,published_at) SELECT ?,? WHERE EXISTS(SELECT 1 FROM telegram_receipts WHERE id=? AND request_id=?)').bind(payload,now,updateId,requestId),
   db.prepare('UPDATE telegram_receipts SET revision=last_insert_rowid() WHERE id=? AND request_id=? AND changes()=1').bind(updateId,requestId),
   db.prepare('INSERT OR IGNORE INTO draft(id,payload,version) VALUES(1,?,0)').bind(previous?.payload||JSON.stringify({notice:'',quotes:[]})),
   db.prepare('UPDATE draft SET payload=CASE WHEN payload=? THEN ? ELSE payload END,version=version+1 WHERE id=1 AND EXISTS(SELECT 1 FROM telegram_receipts WHERE id=? AND request_id=? AND revision IS NOT NULL)').bind(previous?.payload||JSON.stringify({notice:'',quotes:[]}),payload,updateId,requestId),
   db.prepare('UPDATE telegram_pending SET used=1 WHERE owner_id=? AND EXISTS(SELECT 1 FROM telegram_receipts WHERE id=? AND request_id=? AND revision IS NOT NULL)').bind(chat,updateId,requestId),
  ]);
  if(result[0].meta.changes)return response;
  const cached=await db.prepare('SELECT response FROM telegram_receipts WHERE id=?').bind(updateId).first();if(cached)return JSON.parse(cached.response);
  const p=await db.prepare('SELECT used,expires FROM telegram_pending WHERE id=?').bind(pendingId).first();
  if(!p||p.used||p.expires<=Date.now())return receipt(db,updateId,reply(chat,'ဒီခလုတ်ကို သုံးပြီးပါပြီ သို့မဟုတ် အချိန်ကုန်ပါပြီ။ စာအသစ်ပို့ပါ။'));
 }
 return receipt(db,updateId,reply(chat,'တခြားနေရာက နှုန်းပြင်နေပါသည်။ နှုန်းကို ပြန်ပို့ပါ။'));
}
async function undo(db,row,c,updateId,chat) {
 const latest=await db.prepare('SELECT * FROM revisions ORDER BY id DESC LIMIT 1').first();
 const owned=latest&&await db.prepare('SELECT revision FROM telegram_receipts WHERE revision=?').bind(latest.id).first();
 if(!owned)return receipt(db,updateId,reply(chat,'နောက်ဆုံးတင်ချက်သည် Telegram မှ မဟုတ်ပါ။ Admin မှာ ပြန်စစ်ပါ။'));
 const prev=await db.prepare('SELECT * FROM revisions WHERE id<? ORDER BY id DESC LIMIT 1').bind(latest.id).first();
 const restored=prev?JSON.parse(prev.payload):{notice:'',quotes:[]};
 // Retain original observation times; undo never makes an old quote look freshly checked.
 // Expired rates remain visible as last-known information; their original expiry is retained.
 const payload=JSON.stringify(validate(restored)), now=new Date().toISOString(), rid=random();
 const response=reply(chat,'နောက်ဆုံး Telegram တင်ချက်ကို ပြန်ဖျက်ပြီးပါပြီ။ ယခင်သိမ်းထားသောနှုန်းကို မူလစစ်ချိန်အတိုင်း ပြန်ပြထားသည်။');
 const results=await db.batch([
 db.prepare('INSERT OR IGNORE INTO telegram_receipts(id,request_id,response,created_at) SELECT ?,?,?,? WHERE (SELECT MAX(id) FROM revisions)=? AND EXISTS(SELECT 1 FROM telegram_settings WHERE id=1 AND generation=? AND owner_id=?)').bind(updateId,rid,JSON.stringify(response),Date.now(),latest.id,row.generation,row.owner_id),
 db.prepare('INSERT INTO revisions(payload,published_at) SELECT ?,? WHERE EXISTS(SELECT 1 FROM telegram_receipts WHERE id=? AND request_id=?)').bind(payload,now,updateId,rid),
 // Undo receipts intentionally have no revision: /undo cannot toggle back into the deleted price.
 db.prepare('UPDATE draft SET payload=CASE WHEN payload=? THEN ? ELSE payload END,version=version+1 WHERE id=1 AND EXISTS(SELECT 1 FROM telegram_receipts WHERE id=? AND request_id=?)').bind(latest.payload,payload,updateId,rid),
 ]);
 return results[0].meta.changes?response:reply(chat,'နှုန်းပြောင်းနေပါသည်။ /undo ပြန်ပို့ပါ။');
}
export async function webhook(req,db,raw,runtime={}) {
 const row=await configRow(db);if(!row)return new Response('Not configured',{status:403});
 const c=await unseal(row.sealed,runtime.telegramKey);
 const received=req.headers.get('X-Telegram-Bot-Api-Secret-Token')||'';
 if(!c.enabled||await sha(received)!==await sha(c.webhookSecret))return new Response('Forbidden',{status:403});
 let u;try{u=JSON.parse(raw);}catch{return new Response('Bad JSON',{status:400});}
 if(!Number.isSafeInteger(u.update_id)||u.update_id<0)return Response.json({ok:true});
 const m=u.message||u.callback_query?.message, from=u.message?.from||u.callback_query?.from;
 if(!m||m.chat?.type!=='private'||!from||from.is_bot||String(m.chat.id)!==String(from.id))return Response.json({ok:true});
 const chat=String(m.chat.id), id=row.username+':'+u.update_id;
 const text=typeof m.text==='string'?m.text.trim():'';
 const pairing=/^\/start pair_([a-f0-9]{48})$/.exec(text);
 if(pairing) {
  const nonceHash=await sha(pairing[1]);
  const paired=await db.prepare('UPDATE telegram_settings SET owner_id=?,pair_hash=NULL,pair_until=NULL,generation=generation+1 WHERE id=1 AND pair_hash=? AND pair_until>?').bind(chat,nonceHash,Date.now()).run();
  return Response.json(reply(chat,paired.meta.changes?'ချိတ်ဆက်ပြီးပါပြီ ✓\nဒီ account ကပဲ နှုန်းတင်နိုင်ပါသည်။\nChannel ရွေးစရာ မလိုပါ။\nကျပ်ပေး ဘတ်ယူ 726 လို့ ပို့နိုင်ပါတယ်။\n/help ဖြင့် အသုံးပြုပုံ ကြည့်ပါ။':'ချိတ်ဆက် link သက်တမ်းကုန်ပါပြီ။ Admin မှာ link အသစ်ယူပါ။'));
 }
 const subscriberCached=await db.prepare('SELECT response FROM telegram_receipts WHERE id=?').bind(id).first();
 if(subscriberCached)return Response.json(JSON.parse(subscriberCached.response));
 const subscription=await subscriberCommand(db,row,chat,text,u.callback_query?.data);
 if(subscription){if(u.callback_query){try{await telegram(c.token,'answerCallbackQuery',{callback_query_id:u.callback_query.id},runtime.fetcher||fetch);}catch{}}return Response.json(await receipt(db,id,subscription));}
 if(row.owner_id!==chat)return Response.json({ok:true});
 if(u.callback_query){try{await telegram(c.token,'answerCallbackQuery',{callback_query_id:u.callback_query.id},runtime.fetcher||fetch);}catch{}}
 const cached=await db.prepare('SELECT response FROM telegram_receipts WHERE id=?').bind(id).first();if(cached)return Response.json(JSON.parse(cached.response));
 // Keep transient records bounded; revision history remains immutable.
 await db.batch([db.prepare('DELETE FROM telegram_pending WHERE expires<?').bind(Date.now()-86400000),db.prepare('DELETE FROM telegram_receipts WHERE created_at<? AND revision IS NULL').bind(Date.now()-7*86400000)]);
 const say=async s=>Response.json(await receipt(db,id,reply(chat,s)));
 if(/^\/(help|start)(?:@\w+)?$/.test(text))return say(`အသုံးပြုပုံ\nChannel ရွေးစရာမလိုပါ။ ဘယ် channel ကစာမဆို Copy/Paste လုပ်နိုင်သည်။\n\nကျပ်ပေး ဘတ်ယူ 726\nသို့မဟုတ် 726 တစ်ခုတည်း ပို့ပါ။\nကျပ် ၁ သိန်းအတွက် ဘတ်နှုန်းဖြစ်သည်။\nနံပါတ်တစ်ခုတည်းဆို ${directionName(c.direction)} ကို သုံးမည်။\nနှုန်းများပါလျှင် တစ်ခုရွေးခိုင်းမည်။ တစ်ဘက်ပို့လျှင် အခြားဘက်နှုန်း ထည့်ဦးမလား မေးမည်။ ထည့်မယ်ဆို သီးခြားနှုန်းကို ပို့ပါ။ မထည့်သေးလည်း ရသည်။ နမူနာကို စစ်ပြီး “မှန်တယ်၊ Public တင်မယ်” နှိပ်မှ App ပေါ်တင်မည်။ မတင်တော့ဘူးကို နှိပ်လျှင် နှုန်းမပြောင်းပါ။ ပုံဖတ်ခြင်း မပါသေးပါ။\n\n/status — လက်ရှိနှုန်း\n/cancel — နမူနာရပ်မယ်\n/undo — နောက်ဆုံး Telegram တင်ချက် ပြန်ဖျက်\n\nUser app: ${APP_URL}`);
 if(text==='/status') {
  const current=await db.prepare('SELECT * FROM revisions ORDER BY id DESC LIMIT 1').first();
  if(!current)return say('နှုန်းမတင်ရသေးပါ။');
  return say(JSON.parse(current.payload).quotes.map(q=>`${q.source_name}\n${directionName(q.direction)} · ကျပ် ၁ သိန်း ≈ ဘတ် ${Number((100000000000/q.rate_micros).toFixed(2))}\n${Date.parse(q.valid_until)<=Date.now()?'ပြန်မစစ်ရသေးပါ။ နောက်ဆုံးသိမ်းထားသောနှုန်း ဖြစ်သည်။':'နောက်ဆုံးစစ်ချိန် '+new Date(q.observed_at).toLocaleString('en-GB',{timeZone:'Asia/Bangkok'})+' (ထိုင်းအချိန်)'}`).join('\n\n')||'နှုန်းမရှိပါ။');
 }
 if(text==='/undo')return Response.json(await undo(db,row,c,id,chat));
 const source=c.source_name||DEFAULT_SOURCE;
 if(text==='/cancel') {await db.prepare('UPDATE telegram_pending SET used=1 WHERE owner_id=?').bind(chat).run();return say('စောင့်ဆိုင်းနေသော နမူနာများကို ပိတ်ပြီးပါပြီ။ Public တင်ပြီးသားကို ပြန်ဖျက်ရန် /undo ကို သုံးပါ။');}
 if(u.callback_query) {
  const input=u.callback_query.data||'';
  const choice=/^(rate|other_rate):([a-f0-9]{48}):(\d{1,2})$/.exec(input);
  const action=/^(publish|cancel|other|review):([a-f0-9]{48})$/.exec(input);
  if(!choice&&!action)return say('ရွေးချယ်မှု မမှန်ပါ။');
  const pendingId=choice?choice[2]:action[2];
  const pending=await db.prepare('SELECT * FROM telegram_pending WHERE id=? AND owner_id=? AND used=0 AND expires>?').bind(pendingId,chat,Date.now()).first();
  if(!pending)return say('ဒီခလုတ်ကို သုံးပြီးပါပြီ၊ စာအသစ်ပို့ထားပါသည် သို့မဟုတ် အချိန်ကုန်ပါပြီ။ စာအသစ်ပို့ပါ။');
  const payload=JSON.parse(pending.payload);
  if(payload.config_generation!==undefined&&payload.config_generation!==row.generation)return say('Bot settings ပြောင်းသွားပါပြီ။ စာအသစ်ပို့ပါ။');
  if(action?.[1]==='cancel')return Response.json(await cancelPending(db,id,chat,pendingId));
  if(choice) {
   if(choice[1]==='other_rate') {
    if(!['await_other','choose_other'].includes(payload.stage))return say('ဒီခလုတ်ကို သုံးမရပါ။');
    const candidate=payload.options?.[Number(choice[3])];if(!candidate||candidate.direction!==opposite(payload.candidates[0].direction))return say('ရွေးချယ်မှု မမှန်ပါ။');
    return Response.json(await previewRates(db,row,id,chat,[...payload.candidates,candidate],payload.source,pendingId));
   }
   if(payload.stage&&payload.stage!=='choose')return say('ဒီခလုတ်ကို သုံးမရပါ။');
   const candidate=payload.candidates?.[Number(choice[3])];if(!candidate)return say('ရွေးချယ်မှု မမှန်ပါ။');
   return Response.json(await askOther(db,row,id,chat,candidate,payload.source||source,pendingId,payload.candidates));
  }
  if(action[1]==='other') {
   if(payload.stage!=='ask_other')return say('ဒီခလုတ်ကို သုံးမရပါ။');
   return Response.json(await requestOther(db,row,id,chat,payload,pendingId));
  }
  if(action[1]==='review') {
   if(!['ask_other','await_other','choose_other'].includes(payload.stage))return say('ဒီခလုတ်ကို သုံးမရပါ။');
   return Response.json(await previewRates(db,row,id,chat,payload.candidates,payload.source,pendingId));
  }
  if(payload.stage!=='confirm'||!Array.isArray(payload.candidates)||payload.candidates.length<1||payload.candidates.length>2||!Number.isSafeInteger(payload.base_revision)||payload.config_generation!==row.generation)return say('အတည်ပြုနမူနာ မမှန်ပါ။ နှုန်းစာအသစ်ပို့ပါ။');
  return Response.json(await publish(db,row,c,id,chat,payload.candidates,payload.source,pendingId,payload.base_revision));
 }
 if(!text)return say('ပုံဖတ်ခြင်း မပါသေးပါ။ Viber စာသားကို Copy/Paste လုပ်ပါ သို့မဟုတ် ကျပ်ပေး ဘတ်ယူ 726 လို့ ပို့ပါ။');
 if(text.startsWith('/'))return say('Command မသိပါ။ /help ကို ပို့ပါ။');
 // An explicitly old date must never be republished as today's price.
 const today=new Date().toLocaleDateString('en-CA',{timeZone:'Asia/Bangkok'});
 const dates=normalize(text).match(/\b\d{4}-\d{2}-\d{2}\b/g)||[];
 if(dates.some(d=>d!==today))return say('စာထဲကရက်စွဲသည် ယနေ့မဟုတ်ပါ။ ယနေ့နှုန်းကို ပြန်စစ်ပြီး နှုန်းတစ်ခုတည်း ပို့ပါ။');
 const active=await db.prepare('SELECT * FROM telegram_pending WHERE owner_id=? AND used=0 AND expires>? ORDER BY rowid DESC LIMIT 1').bind(chat,Date.now()).first();
 const progress=active?JSON.parse(active.payload):null;
 const awaiting=progress?.stage==='await_other'||progress?.stage==='choose_other';
 if(awaiting&&progress.config_generation!==row.generation)return say('Bot settings ပြောင်းသွားပါပြီ။ /cancel ပို့ပြီး နှုန်းစာအသစ်ပို့ပါ။');
 const parsed=parseRates(text,awaiting?progress.expected_direction:c.direction);
 const safe=parsed.candidates.filter(q=>q.rate>=1&&q.rate<=100000&&(!awaiting||q.direction===progress.expected_direction));
 if(!safe.length)return say(parsed.error||(awaiting?`${directionName(progress.expected_direction)} ဘက်နှုန်းကို ပို့ပေးပါ။ မထည့်သေးလျှင် အပေါ်က “ဒီဘက်ပဲ ဆက်မယ်” ကို နှိပ်ပါ။`:'နှုန်းကို ရှင်းရှင်းမဖတ်နိုင်ပါ။ ကျပ်ပေး ဘတ်ယူ 726 လို့ ပို့ပါ။'));
 if(awaiting) {
  if(safe.length===1&&!parsed.range)return Response.json(await previewRates(db,row,id,chat,[...progress.candidates,safe[0]],progress.source,active.id));
  return Response.json(await pendingReply(db,row,id,chat,{...progress,stage:'choose_other',options:safe},pendingId=>reply(chat,`${directionName(progress.expected_direction)} ဘက်အတွက် နှုန်းတစ်ခုရွေးပါ။ ရွေးပြီးလျှင် နှစ်ဘက်လုံး နမူနာပြမည်။`,{reply_markup:{inline_keyboard:[...safe.map((q,i)=>[{text:rateMeaning(q),callback_data:`other_rate:${pendingId}:${i}`}]),[{text:'ဒီဘက်မထည့်သေးဘူး',callback_data:'review:'+pendingId}],[{text:'မတင်တော့ဘူး',callback_data:'cancel:'+pendingId}]]}}),active.id));
 }
 if(safe.length===2&&safe[0].direction!==safe[1].direction&&!parsed.range)return Response.json(await previewRates(db,row,id,chat,safe,source));
 if(safe.length===1&&!parsed.range)return Response.json(await askOther(db,row,id,chat,safe[0],source));
 return Response.json(await pendingReply(db,row,id,chat,{stage:'choose',candidates:safe,source},pendingId=>reply(chat,`${source}\nအရင်ထည့်မည့်နှုန်းတစ်ခုကို ရွေးပါ။ ပြီးလျှင် အခြားဘက်ပါ ထည့်ဦးမလား မေးမည်။\nPublic မတင်ရသေးပါ။ (၁၀ မိနစ်အတွင်း)${parsed.range?'\nနှုန်းအပိုင်းအခြားကို မရွေးထားပါ။ နှုန်းအတိအကျကို ပို့နိုင်သည်။':''}`,{reply_markup:{inline_keyboard:[...safe.map((q,i)=>[{text:`${directionName(q.direction)} · ${q.rate}`,callback_data:`rate:${pendingId}:${i}`}]),[{text:'မတင်တော့ဘူး',callback_data:'cancel:'+pendingId}]]}})));
}
