'use strict';
(() => {
 const el=id=>document.getElementById(id);
 let status=null,working=false;
 const feedback=(text,error=false)=>{el('tg-feedback').textContent=text;el('tg-feedback').classList.toggle('error',error);};
 function render(s){
  status=s;
  el('tg-status').textContent=!s.configured?'Bot မချိတ်ရသေးပါ။ ပထမတစ်ခါ Bot ချိတ်ဆက်ရန်ကို ဖွင့်ပါ။':!s.enabled?'Bot ရပ်ထားပါသည်။':`@${s.username} · ${s.paired?'မင်း Telegram ချိတ်ဆက်ပြီးပါပြီ ✓':'Telegram account ချိတ်ရန် ကျန်ပါသည်။'}`;
  el('tg-source').value=s.source_name||'';el('tg-url').value=s.source_url||'';el('tg-direction').value=s.direction||'mmk_thb';
  el('tg-pair').disabled=!s.configured||!s.enabled;el('tg-disconnect').disabled=!s.enabled;
  if(!s.configured||!s.paired)el('tg-setup').open=true;
 }
 async function run(fn){if(working)return;working=true;el('tg-setup').inert=true;el('tg-refresh').disabled=true;try{await fn();}catch(e){feedback(e.message,true);}finally{working=false;el('tg-setup').inert=false;el('tg-refresh').disabled=false;}}
 async function refresh(){render(await api('telegram'));feedback('ချိတ်ဆက်မှု စစ်ပြီးပါပြီ။');}
 el('tg-refresh').addEventListener('click',()=>run(refresh));
 el('tg-connect').addEventListener('click',()=>run(async()=>{
  feedback('Telegram ကို ချိတ်ဆက်နေပါသည်…');
  const token=el('tg-token').value.trim();
  const s=await api('telegram','POST',{token,source_name:el('tg-source').value.trim(),source_url:el('tg-url').value.trim(),direction:el('tg-direction').value});
  el('tg-token').value='';el('tg-pair-link').hidden=true;render(s);feedback(s.paired?'Settings သိမ်းပြီးပါပြီ။ Bot ဆီ စာပို့နိုင်ပါပြီ။':'Bot ချိတ်ပြီးပါပြီ။ “ငါ့ Telegram ချိတ်မယ်” ကို ဆက်နှိပ်ပါ။');
 }));
 el('tg-pair').addEventListener('click',()=>run(async()=>{
  const result=await api('telegram/pair','POST',{});const link=el('tg-pair-link');link.href=result.url;link.hidden=false;feedback('အပေါ်က Telegram link ကို နှိပ်ပြီး Start နှိပ်ပါ။ Link သက်တမ်း ၁၀ မိနစ်။ ပြီးလျှင် “ချိတ်ဆက်မှု စစ်မယ်” နှိပ်ပါ။');
 }));
 el('tg-disconnect').addEventListener('click',()=>run(async()=>{
  if(!confirm('Telegram မှ နှုန်းတင်ခြင်းကို ရပ်မလား?'))return;
  await api('telegram/disconnect','POST',{});await refresh();el('tg-pair-link').hidden=true;feedback('Telegram မှ နှုန်းတင်ခြင်း ရပ်ထားပြီးပါပြီ။');
 }));
 // Load only once owner authentication has made the workspace visible.
 const workspace=el('workspace');const observer=new MutationObserver(()=>{if(!workspace.hidden&&status===null){observer.disconnect();run(refresh);}});
 observer.observe(workspace,{attributes:true,attributeFilter:['hidden']});
 if(!workspace.hidden){observer.disconnect();run(refresh);}
})();
