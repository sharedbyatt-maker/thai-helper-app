'use strict';
const $ = id => document.getElementById(id);
let state, csrf = '', dirty = false, previewed = false, busy = false;
function message(text, error=false) { $('message').textContent=text; $('message').classList.toggle('error',error); }
function changed() { dirty=true; previewed=false; $('publish').disabled=true; $('dirty').textContent='မသိမ်းရသေးသော အပြောင်းအလဲရှိသည်'; }
async function api(path, method='GET', body) {
  const response=await fetch('/api/admin/'+path,{method,credentials:'same-origin',headers:{'Content-Type':'application/json','X-Admin-Request':'1','X-CSRF-Token':csrf},body:body===undefined?undefined:JSON.stringify(body)});
  const data=await response.json();
  if(!response.ok) { if(data.bootstrap_ready&&path!=='login'){await api('login','POST',{});return api(path,method,body);} if(response.status===401){$('workspace').hidden=true;$('login-panel').hidden=false;$('logout').hidden=true;} throw new Error(data.error||'လုပ်ဆောင်မှု မအောင်မြင်ပါ'); }
  if(data.csrf_token)csrf=data.csrf_token;
  return data;
}
async function action(fn) { if(busy)return;busy=true;$('workspace').inert=true;$('login-panel').inert=true;try{await fn();}catch(e){message(e.message,true);}finally{busy=false;$('workspace').inert=false;$('login-panel').inert=false;} }
function localTime(iso) { const d=new Date(iso); const p=n=>String(n).padStart(2,'0');return `${d.getFullYear()}-${p(d.getMonth()+1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`; }
function element(tag,text,cls) {const el=document.createElement(tag);if(text!==undefined)el.textContent=text;if(cls)el.className=cls;return el;}
function field(parent,label,key,value,type='text',options) {
  const wrap=element('label',label);const input=document.createElement(options?'select':'input');input.dataset.key=key;
  if(options)for(const [v,t]of options){const option=element('option',t);option.value=v;input.append(option);}else input.type=type;
  input.value=value;input.addEventListener('input',changed);wrap.append(input);parent.append(wrap);return input;
}
function editor(q) {
  const card=element('section',undefined,'quote-editor');card.dataset.id=q.id;
  const row=element('div',undefined,'row');row.append(element('h2',q.label||'နှုန်းအသစ်'));const remove=element('button','ဖယ်မယ်','danger');remove.type='button';remove.addEventListener('click',()=>{card.remove();changed();});row.append(remove);card.append(row);
  const grid=element('div',undefined,'grid');card.append(grid);
  field(grid,'အမည် / နှုန်းအမျိုးအစား','label',q.label||'').maxLength=100;
  const direction=field(grid,'အသုံးပြုသူ၏ ဦးတည်ချက်','direction',q.direction||'thb_mmk','text',[['thb_mmk','ဘတ်ပေး → ကျပ်ယူ'],['mmk_thb','ကျပ်ပေး → ဘတ်ယူ']]);
  const unit=field(grid,'ဈေးရေးသည့်ပုံစံ','rate_unit','per_baht','text',[['per_baht','၁ ဘတ်အတွက် ကျပ်'],['per_lakh','ကျပ် ၁ သိန်းအတွက် ဘတ်']]);
  const rate=field(grid,'နှုန်း (နံပါတ်သာ)','rate',q.rate_micros?q.rate_micros/1e6:'','number');rate.min='0.000001';rate.step='any';
  unit.addEventListener('change',()=>{const old=Number(rate.value);if(old>0)rate.value=Number((100000/old).toFixed(6));});
  const fee=field(grid,'Fee — ပေးမည့် currency ဖြင့်','flat_fee',q.flat_fee_minor/100||0,'number');fee.min='0';fee.step='.01';
  const percent=field(grid,'Fee ရာခိုင်နှုန်း (%) — မရှိလျှင် 0','fee_percent',q.fee_bps/100||0,'number');percent.min='0';percent.max='99.99';percent.step='.01';
  field(grid,'Source အမည်','source_name',q.source_name||'').maxLength=150;
  field(grid,'Source link (ရှိလျှင်)','source_url',q.source_url||'','url').maxLength=500;
  field(grid,'လက်ခံမည့်နည်းလမ်း','payout_method',q.payout_method||'ဘဏ် / Wallet').maxLength=100;
  field(grid,'စစ်ဆေးချိန် — သင့်ဖုန်းအချိန်','observed_at',localTime(q.observed_at||new Date().toISOString()),'datetime-local');
  field(grid,'သက်တမ်းကုန်ချိန် — သင့်ဖုန်းအချိန်','valid_until',localTime(q.valid_until||new Date(Date.now()+86400000).toISOString()),'datetime-local');
  field(grid,'မှတ်ချက်','note',q.note||'').maxLength=500;
  const check=element('label',undefined,'check');const box=document.createElement('input');box.type='checkbox';box.dataset.key='source_checked';box.checked=q.source_checked===true;box.addEventListener('change',changed);check.append(box,element('span','Source နှင့် နှုန်း/fee ကို ကိုယ်တိုင် စစ်ဆေးပြီးပါပြီ'));card.append(check);
  direction.addEventListener('change',()=>{fee.parentElement.firstChild.textContent=`Fee — ${direction.value==='thb_mmk'?'ဘတ်':'ကျပ်'} ဖြင့်`;});
  card.addEventListener('input',event=>{if(event.target.dataset.key!=='source_checked')box.checked=false;});
  $('editors').append(card);
}
function readSheet() {
  const quotes=[...$('editors').children].map(card=>{
    const get=key=>card.querySelector(`[data-key="${key}"]`);
    const number=key=>{const v=get(key).value.trim();if(!v||!Number.isFinite(Number(v)))throw new Error('ပမာဏများကို ပြန်စစ်ပါ');return Number(v);};
    const rate=number('rate');if(rate<=0)throw new Error('နှုန်းသည် 0 ထက်ကြီးရပါမည်');
    const q={id:card.dataset.id};for(const key of ['label','direction','source_name','source_url','payout_method','note'])q[key]=get(key).value.trim();
    q.rate_micros=Math.round((get('rate_unit').value==='per_lakh'?100000/rate:rate)*1e6);
    if(!/^\d+(?:\.\d{1,2})?$/.test(get('flat_fee').value)||!/^\d+(?:\.\d{1,2})?$/.test(get('fee_percent').value))throw new Error('Fee ကို ဒသမ ၂ နေရာအထိသာ ထည့်ပါ');
    q.flat_fee_minor=Math.round(number('flat_fee')*100);q.fee_bps=Math.round(number('fee_percent')*100);
    for(const key of ['observed_at','valid_until']){const d=new Date(get(key).value);if(!Number.isFinite(d.getTime()))throw new Error('အချိန်ကို ဖြည့်ပေးပါ');q[key]=d.toISOString();}
    q.source_checked=get('source_checked').checked;return q;
  });
  return {notice:$('notice').value.trim(),quotes};
}
function render() {
  $('login-panel').hidden=true;$('workspace').hidden=false;$('logout').hidden=false;
  $('notice').value=state.draft.notice;$('editors').replaceChildren();state.draft.quotes.forEach(editor);
  $('published-version').textContent='Version '+state.published.revision;
  $('published-time').textContent=state.published.published_at?new Date(state.published.published_at).toLocaleString():'မထုတ်ပြရသေးပါ';
  $('draft-count').textContent=state.draft.quotes.length+' နှုန်း';$('history').replaceChildren();
  for(const rev of state.history){const row=element('div',undefined,'history-row');row.append(element('span',`Version ${rev.id} · ${new Date(rev.published_at).toLocaleString()}`));const button=element('button','Draft အဖြစ် ပြန်ယူ');button.addEventListener('click',()=>action(async()=>{if(!confirm('လက်ရှိ Draft ကို ဤ version ဖြင့် အစားထိုးမလား?'))return;await api('restore','POST',{revision:rev.id,expected_version:state.draft_version});await load();message('Draft ပြန်ယူပြီးပါပြီ။ နှုန်းနှင့် အချိန်ကို ပြန်စစ်ပါ။');}));row.append(button);$('history').append(row);}
  dirty=false;previewed=false;$('dirty').textContent='Draft သိမ်းထားပြီး';$('publish').disabled=true;$('preview').hidden=true;
}
async function load(){state=await api('state');render();}
async function save(){const sheet=readSheet();const result=await api('draft','PUT',{sheet,expected_version:state.draft_version});state.draft_version=result.draft_version;state.draft=sheet;dirty=false;$('dirty').textContent='Draft သိမ်းထားပြီး';$('draft-count').textContent=sheet.quotes.length+' နှုန်း';return sheet;}
$('notice').addEventListener('input',changed);
$('add').addEventListener('click',()=>{editor({id:crypto.randomUUID()});changed();});
$('reload').addEventListener('click',()=>action(async()=>{if(dirty&&!confirm('မသိမ်းရသေးတာများ ပျောက်မည်။ Reload လုပ်မလား?'))return;await load();message('နောက်ဆုံး Draft ရယူပြီးပါပြီ');}));
$('save').addEventListener('click',()=>action(async()=>{await save();previewed=false;$('publish').disabled=true;message('Draft သိမ်းပြီးပါပြီ။ User များ မမြင်ရသေးပါ။');}));
$('preview-button').addEventListener('click',()=>action(async()=>{const sheet=await save();$('preview-cards').replaceChildren();for(const q of sheet.quotes){const card=element('div',undefined,'preview-card');card.append(element('strong',`${q.label} · ${q.direction==='thb_mmk'?'ဘတ်ပေး → ကျပ်ယူ':'ကျပ်ပေး → ဘတ်ယူ'}`),element('p',`၁ ဘတ် = ${(q.rate_micros/1e6).toLocaleString()} ကျပ် · Fee ${q.flat_fee_minor/100} + ${q.fee_bps/100}%`),element('p',`${q.source_name} · ${q.payout_method}`),element('p',`စစ်ချိန် ${new Date(q.observed_at).toLocaleString()} / သက်တမ်း ${new Date(q.valid_until).toLocaleString()}`),element('p',q.note));$('preview-cards').append(card);}if(!sheet.quotes.length)$('preview-cards').append(element('p','နှုန်းအားလုံး ဖယ်ရှားထားသည့်စာမျက်နှာကို ထုတ်ပြမည်။'));$('preview').hidden=false;previewed=true;$('publish').disabled=false;message('Preview ကို စစ်ပေးပါ။ Publish မလုပ်ရသေးပါ။');}));
$('publish').addEventListener('click',()=>action(async()=>{if(dirty||!previewed)return;if(!confirm('ဤနှုန်းများကို user အားလုံးဆီ ထုတ်ပြမလား?'))return;const result=await api('publish','POST',{expected_version:state.draft_version});await load();message('Publish အောင်မြင်ပါသည်။ Version '+result.published.revision);}));
$('logout').addEventListener('click',()=>{if(dirty&&!confirm('မသိမ်းရသေးတာရှိသည်။ ထွက်မလား?'))return;window.location.href='/signout-with-chatgpt?return_to=%2Fadmin%2Findex.html';});
$('export').addEventListener('click',()=>{const blob=new Blob([JSON.stringify(state.published,null,2)],{type:'application/json'});const url=URL.createObjectURL(blob);const a=document.createElement('a');a.href=url;a.download='bahtzay-rates-v'+state.published.revision+'.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);});
window.addEventListener('beforeunload',e=>{if(dirty){e.preventDefault();e.returnValue='';}});
load().catch(e=>{if(!/ပြန်ဝင်/.test(e.message))message(e.message,true);});
