// Owner-controlled public advertising configuration. Never stores ad-network
// credentials or customer financial records. All advertising defaults to OFF.
const defaultConfig = Object.freeze({
  enabled: false,
  platforms: {web:false,android:false,ios:false},
  formats: {banner:false,native:false,interstitial:false,rewarded:false},
  placements: {home:false,history:false,calculator:false,budget:false},
  sponsors_enabled: false,
  sponsors: [],
});
const own = (x) => !!x && typeof x === 'object' && !Array.isArray(x);
const asBool = (x) => x === true;
const text = (v, max) => typeof v === 'string' ? v.trim().slice(0,max) : '';
const languages = new Set(['my','en','both']);
const slots = new Set(['home','history','calculator','budget']);
function safeHttps(value, optional=false){
  if (optional && !value) return '';
  if (typeof value !== 'string' || value.length>1024) throw Error('HTTPS link လိုပါသည်');
  let url;
  try{ url=new URL(value); } catch { throw Error('HTTPS link မမှန်ပါ'); }
  if (url.protocol!=='https:' || !url.hostname || url.username || url.password || ['localhost','127.0.0.1','::1'].includes(url.hostname)) throw Error('Public HTTPS link လိုပါသည်');
  return url.href;
}
function dateString(v){
  if (v == null || v === '')return null;
  if(typeof v!=='string'||v.length>40||!Number.isFinite(Date.parse(v))||!/\d{4}-\d\d-\d\dT/.test(v))throw Error('Campaign date မမှန်ပါ');
  return new Date(v).toISOString();
}
export function validateAds(input){
  if(!own(input))throw Error('Ads settings object လိုပါသည်');
  if(!own(input.platforms)||!own(input.formats)||!own(input.placements))throw Error('Ads controls မပြည့်စုံပါ');
  if(!Array.isArray(input.sponsors)||input.sponsors.length>20)throw Error('Sponsor အများဆုံး ၂၀ ခု');
  const sponsors=input.sponsors.map((s,i)=>{
    if(!own(s))throw Error('Sponsor မမှန်ပါ');
    const id=text(s.id,64),name=text(s.name,100),label=text(s.label,160);
    if(!/^[A-Za-z0-9_-]{1,64}$/.test(id)||!name)throw Error('Sponsor ID/Name လိုပါသည်');
    if(!Array.isArray(s.placements)||s.placements.length===0||s.placements.length>4||s.placements.some(v=>!slots.has(v)))throw Error('Sponsor placement မမှန်ပါ');
    const language=languages.has(s.language)?s.language:'both';
    const start_at=dateString(s.start_at),end_at=dateString(s.end_at);
    if(start_at&&end_at&&Date.parse(end_at)<=Date.parse(start_at))throw Error('Sponsor end date သည် start ထက် နောက်ကျရမည်');
    const priority=Number.isSafeInteger(s.priority)&&s.priority>=0&&s.priority<=100?s.priority:0;
    return {id,name,label,language,placements:[...new Set(s.placements)],image_url:safeHttps(s.image_url),destination_url:safeHttps(s.destination_url),start_at,end_at,priority,enabled:asBool(s.enabled)};
  });
  if(new Set(sponsors.map(x=>x.id)).size!==sponsors.length)throw Error('Sponsor ID တူနေပါသည်');
  return {
    enabled: asBool(input.enabled),
    platforms:Object.fromEntries(Object.keys(defaultConfig.platforms).map(k=>[k,asBool(input.platforms[k])])),
    formats:Object.fromEntries(Object.keys(defaultConfig.formats).map(k=>[k,asBool(input.formats[k])])),
    placements:Object.fromEntries(Object.keys(defaultConfig.placements).map(k=>[k,asBool(input.placements[k])])),
    sponsors_enabled:asBool(input.sponsors_enabled),
    sponsors,
  };
}
async function seed(db){
  await db.prepare('INSERT OR IGNORE INTO ad_configuration(id,version,payload,updated_at) VALUES(1,0,?,?)')
    .bind(JSON.stringify(defaultConfig),new Date(0).toISOString()).run();
}
export async function readAds(db, publicView=false){
  await seed(db);
  const row=await db.prepare('SELECT version,payload,updated_at FROM ad_configuration WHERE id=1').first();
  const config=validateAds(JSON.parse(row.payload));
  if (!publicView)return {config,version:row.version,updated_at:row.updated_at};
  const now=Date.now();
  const sponsors = config.enabled&&config.sponsors_enabled
    ?config.sponsors.filter(s=>s.enabled&&(s.start_at==null||Date.parse(s.start_at)<=now)&&(s.end_at==null||Date.parse(s.end_at)>now)&&s.placements.some(x=>config.placements[x]))
      .sort((a,b)=>b.priority-a.priority).map(({id,name,label,language,placements,image_url,destination_url})=>({id,name,label,language,placements,image_url,destination_url}))
    :[];
  // Public controls are purely advisory until actual platform-specific SDKs
  // are integrated, and must never contain AdMob credentials or secrets.
  return {version:row.version,enabled:config.enabled,platforms:config.platforms,formats:config.formats,placements:config.placements,sponsors};
}
export async function saveAds(db, input){
  const {config,expected_version}=input||{};
  if(!Number.isSafeInteger(expected_version)||expected_version<0)return {status:400,data:{error:'Ads version လိုပါသည်'}};
  let validated;
  try{validated=validateAds(config);}catch(e){return {status:400,data:{error:e.message}};}
  await seed(db);
  const updated_at=new Date().toISOString();
  const result=await db.prepare('UPDATE ad_configuration SET payload=?,version=version+1,updated_at=? WHERE id=1 AND version=?')
    .bind(JSON.stringify(validated),updated_at,expected_version).run();
  if(!result.meta.changes)return {status:409,data:{error:'Ads settings ကို တခြားနေရာက ပြောင်းထားပြီ။ Reload လုပ်ပါ'}};
  return {status:200,data:{ok:true,version:expected_version+1,updated_at}};
}
