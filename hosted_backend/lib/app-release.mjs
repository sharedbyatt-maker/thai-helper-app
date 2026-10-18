import {Invalid} from './validate.mjs';
const blank=()=>({enabled:false,version:'',build:0,url:'',notes:''});
export const emptyRelease=()=>({schema_version:1,package_id:'',package_locked:false,apk:blank(),play:blank()});
export async function readRelease(db,publicOnly=false){
 const row=await db.prepare('SELECT payload,version,updated_at FROM app_release WHERE id=1').first();
 const release=row?JSON.parse(row.payload):emptyRelease();
 if(publicOnly){delete release.package_locked;for(const channel of ['apk','play'])if(!release[channel].enabled)release[channel]=null;}
 return {release,release_version:row?.version||0,updated_at:row?.updated_at||null};
}
export function releaseUrl(raw,channel,packageId){
 let u;try{u=new URL(raw);}catch{throw new Invalid('Download link ကို ပြန်စစ်ပေးပါ။');}
 if(u.protocol!=='https:'||u.username||u.password||u.port||u.hash)throw new Invalid('HTTPS download link ကိုပဲ သုံးပေးပါ။');
 if(channel==='play'){
  if(u.hostname!=='play.google.com'||u.pathname!=='/store/apps/details'||u.searchParams.get('id')!==packageId)throw new Invalid('Play Store link ရဲ့ app ID ကို ပြန်စစ်ပေးပါ။');
 }else if(!u.pathname.toLowerCase().endsWith('.apk'))throw new Invalid('APK ဖိုင်ကို တိုက်ရိုက် download လုပ်တဲ့ link ထည့်ပေးပါ။');
 return u.href;
}
export async function saveRelease(db,input){
 if(!Number.isSafeInteger(input?.expected_release_version)||input.expected_release_version<0)throw new Invalid('Release version လိုပါတယ်။');
 const previous=await readRelease(db), value=input.release;
 if(input.expected_release_version!==previous.release_version)return {status:409,data:{error:'App update စာရင်း ပြောင်းထားတယ်။ ပြန်ယူပြီး စစ်ပေးပါ။'}};
 if(!value||typeof value!=='object'||Array.isArray(value))throw new Invalid('Release အချက်အလက် လိုပါတယ်။');
 const packageId=typeof value.package_id==='string'?value.package_id.trim():'';
 if(packageId&&!/^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*){2,}$/.test(packageId)||packageId.length>180)throw new Invalid('APK ထဲက app ID အစစ်ကို ဖြည့်ပေးပါ။');
 if(previous.release.package_locked&&packageId!==previous.release.package_id)throw new Invalid('ဖြန့်ပြီးသား app ID ကို ပြောင်းလို့မရပါဘူး။');
 const result={schema_version:1,package_id:packageId,package_locked:previous.release.package_locked};
 for(const channel of ['apk','play']){
  const v=value[channel];if(!v||typeof v.enabled!=='boolean')throw new Invalid('Release channel အချက်အလက် ပြည့်စုံအောင် ဖြည့်ပေးပါ။');
  const version=String(v.version??'').trim(),build=v.build,url=String(v.url??'').trim(),notes=String(v.notes??'').trim();
  if(!Number.isSafeInteger(build)||build<0||build>2100000000||build<previous.release[channel].build)throw new Invalid('Build number ကို အရင်ထက် လျှော့လို့မရပါဘူး။');
  if(version.length>50||notes.length>2000||url.length>2000)throw new Invalid('Release စာသား ရှည်လွန်းနေပါတယ်။');
  if(v.enabled&&(!packageId||build<1||!/^\d+\.\d+\.\d+(?:-[a-zA-Z0-9.-]+)?$/.test(version)))throw new Invalid('App ID၊ version နဲ့ build number အစစ်ကို ဖြည့်ပေးပါ။');
  const checked=url?releaseUrl(url,channel,packageId):'';
  if(v.enabled&&!checked)throw new Invalid('တကယ် download လုပ်လို့ရတဲ့ link ထည့်ပြီးမှ ဖွင့်ပေးပါ။');
  result[channel]={enabled:v.enabled,version,build,url:checked,notes};
  if(v.enabled)result.package_locked=true;
 }
 await db.prepare('INSERT OR IGNORE INTO app_release(id,payload,version,updated_at) VALUES(1,?,0,?)').bind(JSON.stringify(emptyRelease()),new Date().toISOString()).run();
 const updated=await db.prepare('UPDATE app_release SET payload=?,version=version+1,updated_at=? WHERE id=1 AND version=?').bind(JSON.stringify(result),new Date().toISOString(),input.expected_release_version).run();
 return updated.meta.changes?{status:200,data:await readRelease(db)}:{status:409,data:{error:'App update စာရင်း ပြောင်းထားတယ်။ ပြန်ယူပြီး စစ်ပေးပါ။'}};
}
