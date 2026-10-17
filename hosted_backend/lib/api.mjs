import { Invalid, validate } from './validate.mjs';
import { publicHistory } from './history.mjs';
import { replacementPath, authorizedReplacement, replaceConfirmedHistory } from './confirmed-history.mjs';
import { adminTelegram, webhook, publicTelegramInfo, scheduleAlerts } from './telegram.mjs';
class TooLarge extends Error {}
async function bodyText(req, limit) {
 if(Number(req.headers.get('Content-Length'))>limit)throw new TooLarge();
 const reader=req.body?.getReader();if(!reader)return '';
 const chunks=[];let size=0;
 while(true){const {done,value}=await reader.read();if(done)break;size+=value.byteLength;if(size>limit){await reader.cancel();throw new TooLarge();}chunks.push(value);}
 const all=new Uint8Array(size);let at=0;for(const part of chunks){all.set(part,at);at+=part.byteLength;}
 return new TextDecoder().decode(all);
}
const EMPTY={schema_version:2,revision:0,published_at:null,notice:'နှုန်းမတင်ရသေးပါ။ ကိုယ်ရထားသောဈေးနှင့် တွက်နိုင်သည်။',quotes:[]};
const conflict={error:'Draft ပြောင်းထားပါသည်။ Reload လုပ်ပါ။'};
export async function handle(req, db, user, bootstrapEmail, runtime={}) {
 const path=new URL(req.url).pathname;
 const publicRoute=['/api/v2/rates','/api/rates','/api/v2/history','/api/v2/alerts'].includes(path);
 const json=(data,status=200)=>Response.json(data,{status,headers:{'Cache-Control':'no-store','X-Content-Type-Options':'nosniff',...(publicRoute?{'Access-Control-Allow-Origin':'*'}:{})}});
 const publicSheet=async()=>{
  const row=await db.prepare('SELECT * FROM revisions ORDER BY id DESC LIMIT 1').first();
  return row?{...JSON.parse(row.payload),schema_version:2,revision:row.id,published_at:row.published_at}:EMPTY;
 };
 try {
  if(path===replacementPath){
   if(req.method!=='POST')return json({error:'Not found'},404);
   if(!await authorizedReplacement(req))return json({error:'Unauthorized'},401);
   let input;try{input=JSON.parse(await bodyText(req,1024));}catch(e){if(e instanceof TooLarge)throw e;return json({error:'JSON required'},400);}
   const result=await replaceConfirmedHistory(db,input?.expected_revision);
   return json(result.data,result.status);
  }
  if(path==='/api/telegram/webhook'&&req.method==='POST'){const response=await webhook(req,db,await bodyText(req,32768),runtime);scheduleAlerts(db,runtime);return response;}
  if(path==='/api/v2/alerts'&&req.method==='GET')return json(await publicTelegramInfo(db,runtime));
  if(path==='/api/v2/history'&&req.method==='GET'){
   const since=new Date(Date.now()-31*86400000).toISOString();
   const rows=await db.prepare('SELECT id,payload,published_at FROM revisions WHERE published_at>=? ORDER BY id DESC LIMIT 400').bind(since).all();
   return json(publicHistory(rows.results));
  }
  if(publicRoute&&req.method==='GET'){scheduleAlerts(db,runtime);return json(await publicSheet());}
  if(path==='/api/health'&&req.method==='GET'){await db.prepare('SELECT 1').first();return json({ok:true,storage:'D1'});}
  if(!path.startsWith('/api/admin/'))return json({error:'Not found'},404);
  if(req.method!=='GET'&&(req.headers.get('X-Admin-Request')!=='1'||!req.headers.get('Origin')||req.headers.get('Origin')!==new URL(req.url).origin))return json({error:'Same-origin admin request လိုပါသည်'},403);
  if(!user)return json({error:'ChatGPT ဖြင့် အကောင့်ဝင်ပါ',signin:true},401);
  let owner=await db.prepare('SELECT user_id FROM admin_owner WHERE id=1').first();
  const canBootstrap=typeof bootstrapEmail==='string'&&bootstrapEmail.length>0&&typeof user.email==='string'&&user.email.toLowerCase()===bootstrapEmail.toLowerCase();
  if(path==='/api/admin/login'&&req.method==='POST'){
   if(!owner){
    if(!canBootstrap)return json({error:'ဤအကောင့်တွင် Admin ခွင့်မရှိပါ'},403);
    await db.prepare('INSERT OR IGNORE INTO admin_owner(id,user_id) VALUES(1,?)').bind(user.userId).run();
    owner=await db.prepare('SELECT user_id FROM admin_owner WHERE id=1').first();
   }
   return owner?.user_id===user.userId?json({ok:true}):json({error:'Admin ခွင့်မရှိပါ'},403);
  }
  if(!owner)return json({error:'Admin အကောင့်ဖြင့် ဝင်ပါ',bootstrap_ready:canBootstrap},403);
  if(owner.user_id!==user.userId)return json({error:'ဤအကောင့်တွင် Admin ခွင့်မရှိပါ'},403);
  if(path==='/api/admin/insights'&&req.method==='GET'){
   scheduleAlerts(db,runtime);
   const subscribers=await db.prepare('SELECT COUNT(*) AS count FROM alert_subscribers WHERE active=1').first();
   const deliveries=await db.prepare('SELECT status,COUNT(*) AS count FROM alert_outbox GROUP BY status').all();
   return json({active_subscribers:subscribers.count,deliveries:deliveries.results});
  }
  if(path==='/api/admin/state'&&req.method==='GET'){
   // Bound seed is idempotent, outside schema migrations.
   await db.prepare('INSERT OR IGNORE INTO draft(id,payload,version) VALUES(1,?,0)').bind(JSON.stringify({notice:'',quotes:[]})).run();
   const row=await db.prepare('SELECT * FROM draft WHERE id=1').first();
   const history=await db.prepare('SELECT id,published_at FROM revisions ORDER BY id DESC LIMIT 50').all();
   return json({draft:JSON.parse(row.payload),draft_version:row.version,published:await publicSheet(),history:history.results,csrf_token:'same-origin'});
  }
  if(path.startsWith('/api/admin/telegram')){
   let input={};if(req.method==='POST'){try{input=JSON.parse(await bodyText(req,8192));}catch(e){if(e instanceof TooLarge)throw e;return json({error:'JSON လိုပါသည်'},400);}}
   if(!input||typeof input!=='object'||Array.isArray(input))return json({error:'JSON object လိုပါသည်'},400);
   const result=await adminTelegram(req,db,path,input,runtime);return result?json(result):json({error:'Not found'},404);
  }
  if(!['PUT','POST'].includes(req.method))return json({error:'Not found'},404);
  const raw=await bodyText(req,131072);
  let data;try{data=JSON.parse(raw);}catch{return json({error:'JSON လိုပါသည်'},400);}
  if(!data||!Number.isSafeInteger(data.expected_version)||data.expected_version<0)return json({error:'Draft version လိုပါသည်'},400);
  const version=data.expected_version;
  if(path==='/api/admin/draft'&&req.method==='PUT'){
   const sheet=validate(data.sheet);
   const result=await db.prepare('UPDATE draft SET payload=?,version=version+1 WHERE id=1 AND version=?').bind(JSON.stringify(sheet),version).run();
   return result.meta.changes?json({ok:true,draft_version:version+1}):json(conflict,409);
  }
  if(path==='/api/admin/publish'&&req.method==='POST'){
   const row=await db.prepare('SELECT payload,version FROM draft WHERE id=1').first();
   if(!row||row.version!==version)return json(conflict,409);
   const sheet=validate(JSON.parse(row.payload));
   const previous=await publicSheet();
   const fresh=sheet.quotes.filter(q=>Date.parse(q.valid_until)>Date.now());
   if(sheet.quotes.length&&fresh.length===0)return json({error:'သက်တမ်းကုန်သောနှုန်း ပါနေပါသည်'},400);
   for(const q of sheet.quotes.filter(q=>Date.parse(q.valid_until)<=Date.now())) {
    const retained=previous.quotes.find(x=>x.id===q.id&&x.direction===q.direction);
    if(!retained||Object.keys(q).some(k=>retained[k]!==q[k]))return json({error:'အဟောင်းနှုန်းကို ပြင်ထားပါသည်။ ပြန်စစ်ထားသော အချိန် သတ်မှတ်ပါ။'},400);
   }
   const now=new Date().toISOString();
   // batch is atomic. SELECT and UPDATE both compare the validated version.
   const result=await db.batch([
    db.prepare('INSERT INTO revisions(payload,published_at) SELECT payload,? FROM draft WHERE id=1 AND version=?').bind(now,version),
    db.prepare('UPDATE draft SET version=version+1 WHERE id=1 AND version=?').bind(version),
   ]);
   if(result[0].meta.changes)scheduleAlerts(db,runtime);
   return result[0].meta.changes?json({ok:true,draft_version:version+1,published:await publicSheet()}):json(conflict,409);
  }
  if(path==='/api/admin/restore'&&req.method==='POST'){
   if(!Number.isSafeInteger(data.revision))return json({error:'Revision လိုပါသည်'},400);
   const row=await db.prepare('SELECT payload FROM revisions WHERE id=?').bind(data.revision).first();
   if(!row)return json({error:'Revision မတွေ့ပါ'},404);
   const result=await db.prepare('UPDATE draft SET payload=?,version=version+1 WHERE id=1 AND version=?').bind(row.payload,version).run();
   return result.meta.changes?json({ok:true,draft_version:version+1}):json(conflict,409);
  }
  return json({error:'Not found'},404);
 }catch(e){
  if(e instanceof TooLarge)return json({error:'ပမာဏကြီးလွန်းသည်'},413);
  if(e instanceof Invalid)return json({error:e.message},400);
  console.error('API failure',e instanceof Error?e.name:'unknown');
  return json({error:'Server တွင် အခက်အခဲရှိသည်။ ပြန်စမ်းပါ။'},500);
 }
}

