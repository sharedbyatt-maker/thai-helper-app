/* Opt-in only: this script never prompts for notification permission on load. */
(() => {
 const KEY='bahtzay_phone_notifications_v1';
 const appRoot=new URL('./',document.baseURI);
 const ios=()=>/iPhone|iPad|iPod/.test(navigator.userAgent)||(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1);
 const standalone=()=>window.matchMedia('(display-mode: standalone)').matches||navigator.standalone===true;
 function support(){
  if(ios()&&!standalone())return {supported:false,needs_home_screen:true,active:false,reason:'iPhone မှာ Safari → Share → Add to Home Screen နဲ့ ထည့်ပါ။ ပြီးရင် Home Screen က ဘတ်ဈေး icon ကိုဖွင့်ပြီး noti ခွင့်ပြုပေးပါ။'};
  if(!window.isSecureContext||!('serviceWorker' in navigator)||!('PushManager' in window)||!('Notification' in window))return {supported:false,active:false,reason:'ဒီ browser မှာ ဖုန်း noti မသုံးနိုင်သေးဘူး။ Update လုပ်ထားတဲ့ Safari / Chrome နဲ့ ပြန်ဖွင့်နိုင်တယ်။'};
  return {supported:true,active:false,permission:Notification.permission};
 }
 function saved(){try{return JSON.parse(localStorage.getItem(KEY)||'null');}catch{return null;}}
 function save(value){localStorage.setItem(KEY,JSON.stringify(value));}
 const token=()=>Array.from(crypto.getRandomValues(new Uint8Array(32)),b=>b.toString(16).padStart(2,'0')).join('');
 const bytes=value=>Uint8Array.from(atob(value.replaceAll('-','+').replaceAll('_','/')+'='.repeat((4-value.length%4)%4)),c=>c.charCodeAt(0));
 async function api(base,action,body){
  const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),10000);
  try{const response=await fetch(base.replace(/\/$/,'')+'/api/v2/push/'+action,{method:body?'POST':'GET',headers:body?{'Content-Type':'application/json'}:{},body:body?JSON.stringify(body):undefined,credentials:'omit',signal:controller.signal});const data=await response.json();if(!response.ok)throw Error(data.error||'Noti ချိတ်ဆက်မှု မရသေးဘူး။');return data;}finally{clearTimeout(timer);}
 }
 async function registration(){
  const reg=await navigator.serviceWorker.register(new URL('flutter_service_worker.js',appRoot),{scope:appRoot.pathname,updateViaCache:'none'});
  const worker=reg.installing||reg.waiting;
  if(!worker&&reg.active)return reg;
  if(!worker)throw Error('Noti ချိတ်ဆက်နေဆဲပါ။ ခဏနေ ပြန်စမ်းပါ။');
  await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('Noti ချိတ်ဆက်ချိန် ကြာနေတယ်။ ပြန်စမ်းပါ။')),10000);worker.addEventListener('statechange',()=>{if(worker.state==='activated'){clearTimeout(timer);resolve();}if(worker.state==='redundant'){clearTimeout(timer);reject(Error('Noti ချိတ်မရသေးဘူး။'));}});});
  return reg;
 }
 async function status(base){
  const info=support();if(!info.supported)return info;
  const store=saved(),reg=await navigator.serviceWorker.getRegistration(appRoot.href);
  const sub=await reg?.pushManager.getSubscription();
  if(!sub&&store?.id){try{await api(base,'unsubscribe',{id:store.id,token:store.token});}catch{/* Retry cleanup after connectivity returns. */}return info;}
  if(!sub||!store?.id||Notification.permission!=='granted')return info;
  try{const data=await api(base,'status',{id:store.id,token:store.token});return {...info,active:data.active===true};}catch{return {...info,active:false,error:'Noti အခြေအနေ စစ်မရသေးဘူး။ လိုင်းရရင် ပြန်စမ်းပေးပါ။'};}
 }
 async function action(name,base,permission){
  const info=support();if(!info.supported)return info;
  if(name==='status')return status(base);
  if(name==='enable'){
   if(await permission!=='granted')return {...info,permission:Notification.permission,error:'Noti ခွင့်မပြုရသေးဘူး။ Browser / ဖုန်း Settings ထဲမှာ ခွင့်ပြုပြီး ပြန်ဖွင့်နိုင်တယ်။'};
   const config=await api(base,'config');if(!config.available)throw Error('Noti ဝန်ဆောင်မှု ခဏမရသေးဘူး။ နောက်မှ ပြန်စမ်းပါ။');
   const reg=await registration();let store=saved(),sub=await reg.pushManager.getSubscription();
   if(sub&&!store?.token){await sub.unsubscribe();sub=null;}
   if(!store?.token){store={token:token()};save(store);}
   if(!sub)sub=await reg.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:bytes(config.public_key)});
   const data=await api(base,'subscribe',{subscription:sub.toJSON(),token:store.token});save({...store,id:data.id});
   return {...info,permission:'granted',active:true,message:'ဖုန်း noti ဖွင့်ထားပြီ။ ဈေးနဲ့ ကြေညာချက်အသစ်တင်ရင် အသိပေးမယ်။'};
  }
  const store=saved();if(!store?.id)return {...info,active:false};
  if(name==='disable'){
   const reg=await navigator.serviceWorker.getRegistration(appRoot.href),sub=await reg?.pushManager.getSubscription();
   let removed=false;try{await api(base,'unsubscribe',{id:store.id,token:store.token});removed=true;}finally{if(sub)await sub.unsubscribe();}
   return {...info,active:false,message:removed?'ဖုန်း noti ပိတ်ထားပြီ။ ပြန်ဖွင့်ချင်ရင် ဒီနေရာကနေ ဖွင့်နိုင်တယ်။':'ဖုန်း noti ပိတ်ထားပြီ။'};
  }
  if(name==='test'){await api(base,'test',{id:store.id,token:store.token});return {...info,active:true,message:'စမ်းသပ် noti ပို့ထားပြီ။ ဖုန်းရဲ့ noti နေရာကို ကြည့်ပေးပါ။'};}
  return status(base);
 }
 window.bahtzayPush=(name,base)=>{
  const apiBase=base||location.origin;
  // Invoke the browser prompt synchronously from the user's button gesture.
  const info=support();
  const permission=name==='enable'&&info.supported?Notification.requestPermission():Promise.resolve('default');
  return action(name,apiBase,permission).then(data=>JSON.stringify(data)).catch(error=>JSON.stringify({...support(),active:false,error:error.message||'လိုင်းမရသေးဘူး။ ခဏနေ ပြန်စမ်းပေးပါ။'}));
 };
})();
