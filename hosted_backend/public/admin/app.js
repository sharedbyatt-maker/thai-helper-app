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
function field(parent,label,key,value,type='text',options,placeholder='',help='') {
  const wrap=element('label',label);const input=document.createElement(options?'select':'input');input.dataset.key=key;
  if(options)for(const [v,t]of options){const option=element('option',t);option.value=v;input.append(option);}else input.type=type;
  input.value=value;input.placeholder=placeholder;input.addEventListener('input',changed);wrap.append(input);
  if(help){const hint=element('small',help,'field-help');hint.id='help-'+crypto.randomUUID();input.setAttribute('aria-describedby',hint.id);wrap.append(hint);}
  parent.append(wrap);return input;
}
function normalize(value){return value.trim().replace(/[၀-၉๐-๙]/g,c=>'၀၁၂၃၄၅၆၇၈၉'.includes(c)?'၀၁၂၃၄၅၆၇၈၉'.indexOf(c):'๐๑๒๓๔๕๖๗๘๙'.indexOf(c)).replaceAll(',','');}
function directionName(value){return value==='mmk_thb'?'ကျပ်ပေး / ဘတ်ယူ':'ဘတ်ပေး / ကျပ်ယူ';}
function detail(parent,title,open=false){const box=element('details');box.open=open;box.append(element('summary',title));parent.append(box);return box;}
function editor(q) {
  const card=element('section',undefined,'quote-editor');card.dataset.id=q.id;
  const row=element('div',undefined,'row');const heading=element('h2',q.label||directionName(q.direction));row.append(heading);
  const tools=element('div',undefined,'row compact');const today=element('button','ယနေ့အချိန်နဲ့ ပြန်တင်ရန်');today.type='button';today.dataset.action='today';const remove=element('button','ဖယ်မယ်','danger');remove.type='button';remove.addEventListener('click',()=>{card.remove();changed();});tools.append(today,remove);row.append(tools);card.append(row);
  card.append(element('p','မဖြစ်မနေဖြည့်ရန် — နှုန်းနှင့် source အမည်။ အကွက်ထဲက မှိန်နေသောစာသည် ရေးပုံဥပမာသာဖြစ်သည်။','muted'));
  const grid=element('div',undefined,'grid');card.append(grid);
  const direction=field(grid,'၁။ ဘယ်ဘက် ငွေလဲနှုန်းလဲ?','direction',q.direction||'thb_mmk','text',[['thb_mmk','ဘတ်ပေးပြီး ကျပ်ယူမည့်ဈေး'],['mmk_thb','ကျပ်ပေးပြီး ဘတ်ယူမည့်ဈေး']]);
  const unit=field(grid,'၂။ နှုန်းကို ဘယ်လို ရေးမလဲ?','rate_unit','per_baht','text',[['per_baht','၁ ဘတ်အတွက် ကျပ် ဘယ်လောက်'],['per_lakh','ကျပ် ၁ သိန်းအတွက် ဘတ် ဘယ်လောက်']]);
  const rate=field(grid,'နှုန်း *','rate',q.rate_micros?q.rate_micros/1e6:'','text',null,'ဥပမာ 125','ဥပမာကိန်းဂဏန်းသာ ဖြစ်သည်။ သင်စစ်ထားသော ယနေ့နှုန်းကို ဖြည့်ပါ။');rate.inputMode='decimal';rate.required=true;
  const equivalent=element('div','နှုန်းဖြည့်လျှင် ရေးပုံနှစ်မျိုးလုံးကို ဒီနေရာမှာ ပြပေးမယ်။','rate-equivalent');equivalent.setAttribute('aria-live','polite');grid.append(equivalent);
  const source=field(grid,'၃။ နှုန်းကြည့်ခဲ့သော source အမည် *','source_name',q.source_name||'','text',null,'ဥပမာ သင်နေ့စဉ်ကြည့်သော ငွေလဲဆိုင် / Page အမည်','နေ့တိုင်း source တူလျှင် အမည်တူပဲ သုံးပါ။');source.maxLength=150;source.required=true;
  field(grid,'Source link (ရှိမှ ဖြည့်ပါ)','source_url',q.source_url||'','url',null,'https://www.facebook.com/...','ယနေ့နှုန်းပါသော post / website link ကို ထည့်နိုင်ပါတယ်။').maxLength=500;
  const extra=detail(card,'အမည်၊ လက်ခံနည်း၊ အချိန်နှင့် မှတ်ချက် (လိုမှ ပြင်ရန်)');const extras=element('div',undefined,'grid');extra.append(extras);
  const label=field(extras,'နှုန်းကို ခေါ်မည့်အမည်','label',q.label||directionName(q.direction),'text',null,'ဥပမာ ဘတ်ပေး ယနေ့ဈေး');label.maxLength=100;
  field(extras,'ငွေလက်ခံနည်း (ရှိမှ ဖြည့်ပါ)','payout_method',q.payout_method==='မဖော်ပြထားပါ'?'':q.payout_method||'','text',null,'ဥပမာ KBZ Pay / Wave / ဘဏ်').maxLength=100;
  const observed=field(extras,'စစ်ထားသည့်အချိန် — သင့်ဖုန်းအချိန်','observed_at',localTime(q.observed_at||new Date().toISOString()),'datetime-local');
  const expires=field(extras,'ဒီနှုန်းကို ဘယ်အချိန်အထိ ပြမလဲ?','valid_until',localTime(q.valid_until||new Date(Date.now()+86400000).toISOString()),'datetime-local');
  field(extras,'အခြေအနေ / မှတ်ချက် (ရှိမှ ဖြည့်ပါ)','note',q.note||'','text',null,'ဥပမာ ၅၀၀၀ ဘတ်အထက်အတွက်သာ').maxLength=500;
  const validity=element('p',undefined,'muted validity');card.append(validity);
  const fees=detail(card,'သီးသန့်နုတ်ငွေ ရှိမှ ဖြည့်ရန် (ပုံမှန် အလွတ်ထားပါ)',!!(q.flat_fee_minor||q.fee_bps));
  fees.append(element('p','နှုန်းအတိုင်း တိုက်ရိုက်လဲလျှင် မဖြည့်ပါနှင့်။ ငွေလဲသူက သီးသန့် ထပ်နုတ်မည်ဟု ပြောထားမှသာ ဖြည့်ပါ။','muted'));
  const feeGrid=element('div',undefined,'grid');fees.append(feeGrid);
  const fee=field(feeGrid,'သီးသန့်နုတ်မည့်ငွေ','flat_fee',q.flat_fee_minor?q.flat_fee_minor/100:'','text',null,'ဥပမာ 20','ပေးမည့်ငွေထဲမှ နုတ်သည်။ ဥပမာ ဘတ် ၁၀၀၀ ထဲမှ ၂၀ ဘတ် နုတ်လျှင် 20 ထည့်ပါ။');fee.inputMode='decimal';
  const percent=field(feeGrid,'ရာခိုင်နှုန်းနဲ့ နုတ်မှသာ (%)','fee_percent',q.fee_bps?q.fee_bps/100:'','text',null,'ဥပမာ 1','သီးသန့် ၁% နုတ်လျှင် 1။ မနုတ်လျှင် အလွတ်ထားပါ။');percent.inputMode='decimal';
  const check=element('label',undefined,'check');const box=document.createElement('input');box.type='checkbox';box.dataset.key='source_checked';box.checked=q.source_checked===true;check.append(box,element('span','Source ကို ကြည့်ပြီး ဤနှုန်းမှန်ကြောင်း စစ်ပြီးပါပြီ'));card.append(check);
  const update=()=>{
    const n=Number(normalize(rate.value));const perBaht=unit.value==='per_lakh'?100000/n:n;
    const paying=direction.value==='thb_mmk'?'ဘတ်':'ကျပ်';const deduction=Number(normalize(fee.value)),percentage=Number(normalize(percent.value));
    fee.parentElement.firstChild.textContent=`သီးသန့်နုတ်မည့်ငွေ (${paying})`;
    fee.parentElement.querySelector('.field-help').textContent=`ဥပမာ ${paying} ၁၀၀၀ ထဲမှ ၂၀ ${paying} နုတ်လျှင် 20 ထည့်ပါ။ မနုတ်လျှင် အလွတ်ထားပါ။`;
    fees.querySelector('summary').textContent=deduction>0||percentage>0?`သီးသန့်နုတ်ငွေ ပါရှိသည် — ${deduction||0} ${paying} + ${percentage||0}%`:'သီးသန့်နုတ်ငွေ ရှိမှ ဖြည့်ရန် (ပုံမှန် အလွတ်ထားပါ)';

    rate.placeholder=unit.value==='per_lakh'?'ဥပမာ 800':'ဥပမာ 125';rate.parentElement.firstChild.textContent=unit.value==='per_lakh'?'ကျပ် ၁ သိန်းအတွက် ဘတ် ဘယ်လောက်လဲ? *':'၁ ဘတ်အတွက် ကျပ် ဘယ်လောက်လဲ? *';
    equivalent.textContent=n>0&&Number.isFinite(perBaht)?`၁ ဘတ် = ${Number(perBaht.toFixed(6)).toLocaleString()} ကျပ် · ကျပ် ၁ သိန်း ≈ ${Number((100000/perBaht).toFixed(2)).toLocaleString()} ဘတ်`:'နှုန်းဖြည့်လျှင် ရေးပုံနှစ်မျိုးလုံးကို ဒီနေရာမှာ ပြပေးမယ်။';
    validity.textContent=`စစ်ချိန် ${new Date(observed.value).toLocaleString()} · ပြသမည့်နောက်ဆုံးအချိန် ${new Date(expires.value).toLocaleString()}`;
    validity.classList.toggle('expired',new Date(expires.value).getTime()<=Date.now());
  };
  unit.addEventListener('change',()=>{const old=Number(normalize(rate.value));if(old>0)rate.value=Number((100000/old).toFixed(6));update();});
  direction.addEventListener('change',()=>{if(['ဘတ်ပေး / ကျပ်ယူ','ကျပ်ပေး / ဘတ်ယူ'].includes(label.value))label.value=directionName(direction.value);heading.textContent=label.value;});
  today.addEventListener('click',()=>{observed.value=localTime(new Date().toISOString());expires.value=localTime(new Date(Date.now()+86400000).toISOString());box.checked=false;changed();update();message('ယနေ့အချိန် သတ်မှတ်ပြီးပါပြီ။ နှုန်းနှင့် source ကို ပြန်စစ်ပြီး အမှန်ခြစ်ပေးပါ။');});
  for(const name of ['input','change'])card.addEventListener(name,event=>{if(event.target.dataset.key!=='source_checked')box.checked=false;changed();update();});
  update();$('editors').append(card);return card;
}
function addDirection(direction) {
  const existing=[...$('editors').children].find(card=>card.querySelector('[data-key="direction"]').value===direction);
  if(existing){existing.querySelector('[data-key="rate"]').focus();message('ရှိပြီးသားနှုန်းကို ဒီနေရာမှာ နေ့စဉ်ပြင်ပြီး တင်နိုင်ပါတယ်။');return;}
  const first=$('editors').firstElementChild;const get=k=>first?.querySelector(`[data-key="${k}"]`)?.value||'';
  const card=editor({id:crypto.randomUUID(),direction,source_name:get('source_name'),source_url:get('source_url'),payout_method:get('payout_method')});changed();card.querySelector('[data-key="rate"]').focus();
}
function readSheet() {
  const quotes=[...$('editors').children].map(card=>{
    const get=key=>card.querySelector(`[data-key="${key}"]`);
    const number=(key,optional=false)=>{const v=normalize(get(key).value);if(optional&&!v)return 0;if(!/^\d+(?:\.\d+)?$/.test(v)||!Number.isFinite(Number(v))) {get(key).focus();throw new Error('နှုန်းနှင့် ပမာဏများကို ပြန်စစ်ပါ');}return Number(v);};
    const rate=number('rate');if(rate<=0)throw new Error('နှုန်းသည် 0 ထက်ကြီးရပါမည်');
    const q={id:card.dataset.id};for(const key of ['label','direction','source_name','source_url','payout_method','note'])q[key]=get(key).value.trim();
    q.label=q.label||directionName(q.direction);q.payout_method=q.payout_method||'မဖော်ပြထားပါ';
    if(!q.source_name){get('source_name').focus();throw new Error('နှုန်းကြည့်ခဲ့သော source အမည်ကို ဖြည့်ပေးပါ။');}
    q.rate_micros=Math.round((get('rate_unit').value==='per_lakh'?100000/rate:rate)*1e6);
    for(const key of ['flat_fee','fee_percent'])if(normalize(get(key).value)&&!/^\d+(?:\.\d{1,2})?$/.test(normalize(get(key).value)))throw new Error('နုတ်ငွေကို ဒသမ ၂ နေရာအထိသာ ထည့်ပါ');
    q.flat_fee_minor=Math.round(number('flat_fee',true)*100);q.fee_bps=Math.round(number('fee_percent',true)*100);
    for(const key of ['observed_at','valid_until']){const d=new Date(get(key).value);if(!Number.isFinite(d.getTime()))throw new Error('အချိန်ကို ဖြည့်ပေးပါ');q[key]=d.toISOString();}
    q.source_checked=get('source_checked').checked;if(!q.source_checked)throw new Error('Source ကို ပြန်စစ်ပြီး အမှန်ခြစ်ပေးပါ။');return q;
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
$('add').addEventListener('click',()=>addDirection('thb_mmk'));
$('add-mmk').addEventListener('click',()=>addDirection('mmk_thb'));
$('add-source').addEventListener('click',()=>{editor({id:crypto.randomUUID()});changed();});
$('reload').addEventListener('click',()=>action(async()=>{if(dirty&&!confirm('မသိမ်းရသေးတာများ ပျောက်မည်။ Reload လုပ်မလား?'))return;await load();message('နောက်ဆုံး Draft ရယူပြီးပါပြီ');}));
$('save').addEventListener('click',()=>action(async()=>{await save();previewed=false;$('publish').disabled=true;message('Draft သိမ်းပြီးပါပြီ။ User များ မမြင်ရသေးပါ။');}));
$('preview-button').addEventListener('click',()=>action(async()=>{const sheet=await save();$('preview-cards').replaceChildren();for(const q of sheet.quotes){const card=element('div',undefined,'preview-card');card.append(element('strong',`${q.label} · ${q.direction==='thb_mmk'?'ဘတ်ပေး → ကျပ်ယူ':'ကျပ်ပေး → ဘတ်ယူ'}`),element('p',`၁ ဘတ် = ${(q.rate_micros/1e6).toLocaleString()} ကျပ်${q.flat_fee_minor||q.fee_bps?` · သီးသန့်နုတ်ငွေ ${q.flat_fee_minor/100} + ${q.fee_bps/100}%`:''}`),element('p',`${q.source_name} · ${q.payout_method}`),element('p',`စစ်ချိန် ${new Date(q.observed_at).toLocaleString()} / သက်တမ်း ${new Date(q.valid_until).toLocaleString()}`),element('p',q.note));$('preview-cards').append(card);}if(!sheet.quotes.length)$('preview-cards').append(element('p','နှုန်းအားလုံး ဖယ်ရှားထားသည့်စာမျက်နှာကို ထုတ်ပြမည်။'));$('preview').hidden=false;previewed=true;$('publish').disabled=false;message('Preview ကို စစ်ပေးပါ။ Publish မလုပ်ရသေးပါ။');}));
$('publish').addEventListener('click',()=>action(async()=>{if(dirty||!previewed)return;if(!confirm('ဤနှုန်းများကို user အားလုံးဆီ ထုတ်ပြမလား?'))return;const result=await api('publish','POST',{expected_version:state.draft_version});await load();message('Publish အောင်မြင်ပါသည်။ Version '+result.published.revision);}));
$('logout').addEventListener('click',()=>{if(dirty&&!confirm('မသိမ်းရသေးတာရှိသည်။ ထွက်မလား?'))return;window.location.href='/signout-with-chatgpt?return_to=%2Fadmin%2Findex.html';});
$('export').addEventListener('click',()=>{const blob=new Blob([JSON.stringify(state.published,null,2)],{type:'application/json'});const url=URL.createObjectURL(blob);const a=document.createElement('a');a.href=url;a.download='bahtzay-rates-v'+state.published.revision+'.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);});
window.addEventListener('beforeunload',e=>{if(dirty){e.preventDefault();e.returnValue='';}});
load().catch(e=>{if(!/ပြန်ဝင်/.test(e.message))message(e.message,true);});
