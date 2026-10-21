'use strict';
// One bounded transport and dirty-state registry across owner tools. No storage
// or automatic mutation retries: a timed-out write may already have completed.
(() => {
 const guards=new Map();
 const hasUnsaved=()=>[...guards.values()].some(check=>check());
 async function fetchJson(url,options={},timeoutMs=15000){
  const controller=new AbortController();let timer;
  const timeout=new Promise((_,reject)=>{timer=setTimeout(()=>{
   reject(new Error((options.method||'GET')==='GET'
    ?'ချိတ်ဆက်မှု ကြာနေပါတယ်။ ပြန်စစ်မယ်ကို နှိပ်ပြီး စမ်းနိုင်ပါတယ်။'
    :'ရလဒ် အတည်မပြုနိုင်သေးပါ။ ထပ်မသိမ်းခင် နောက်ဆုံးအခြေအနေကို Reload နဲ့ စစ်ပေးပါ။'));
   controller.abort();
  },timeoutMs);});
  try{return await Promise.race([timeout,(async()=>{
   const response=await fetch(url,{...options,cache:'no-store',signal:controller.signal});
   if(response.status===401)window.dispatchEvent(new Event('admin:unauthorized'));
   let data;try{data=await response.json();}catch{data={error:'Server အဖြေ မမှန်ပါ။ ခဏနေရင် ပြန်စစ်ပေးပါ။'};if(response.ok)throw Error(data.error);}
   return {response,data};
  })()]);}catch(error){
   if((options.method||'GET')!=='GET')throw new Error('ရလဒ် အတည်မပြုနိုင်သေးပါ။ ထပ်မသိမ်းခင် နောက်ဆုံးအခြေအနေကို Reload နဲ့ စစ်ပေးပါ။');
   throw error;
  }finally{clearTimeout(timer);}
 }
 window.AdminRuntime={fetchJson,hasUnsaved,track:(name,check)=>guards.set(name,check)};
 window.addEventListener('beforeunload',event=>{if(hasUnsaved()){event.preventDefault();event.returnValue='';}});
})();
