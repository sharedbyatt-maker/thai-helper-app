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
 const side=q.direction||'thb_mmk', card=element('section',undefined,'quote-editor');card.dataset.id=q.id;
 const original={...q};let checkedRate=q.rate_micros||0, fee=q.flat_fee_minor||0, bps=q.fee_bps||0;
 const row=element('div',undefined,'row');row.append(element('h2',directionName(side)));
 const today=element('button','ဒီဈေးကို အခု ပြန်စစ်ပြီးပြီ');today.type='button';today.dataset.action='today';row.append(today);card.append(row);
 card.append(element('p',side==='thb_mmk'?'ကျပ် ၁ သိန်း ရဖို့ ဘတ် ဘယ်လောက်ပေးရလဲ?':'ကျပ် ၁ သိန်း ပေးရင် ဘတ် ဘယ်လောက်ရလဲ?','muted'));
 const grid=element('div',undefined,'grid');card.append(grid);
 const rate=field(grid,'ကျပ် ၁ သိန်းအတွက် ဘတ်','rate',checkedRate?Number((100000000000/checkedRate).toFixed(2)):'','text',null,side==='thb_mmk'?'ဥပမာ 748':'ဥပမာ 724','မင်းစစ်ထားတဲ့ ဒီဘက်ဈေးကိုပဲ ဖြည့်ပါ။ အခြားဘက်ဈေးကို ပြန်မတွက်ပါဘူး။');rate.inputMode='decimal';
 const equivalent=element('p',undefined,'rate-equivalent');grid.append(equivalent);
 const dates=detail(card,'ဈေးစစ်ချိန် ပြင်ချင်မှ ဖွင့်ပါ');
 const observed=field(dates,'ဈေးစစ်ထားတဲ့အချိန် — သင့်ဖုန်းအချိန်','observed_at',localTime(q.observed_at||new Date().toISOString()),'datetime-local');
 const expires=field(dates,'ပြန်စစ်ဖို့လိုမယ့်အချိန်','valid_until',localTime(q.valid_until||new Date(Date.now()+86400000).toISOString()),'datetime-local');
 const legacy=element('p',undefined,'muted');card.append(legacy);
 const check=element('label',undefined,'check'), box=document.createElement('input');box.type='checkbox';box.dataset.key='source_checked';box.checked=q.source_checked===true;check.append(box,element('span','ဒီနှုန်းကို ပြန်စစ်ပြီးပြီ'));card.append(check);
 const update=()=>{const value=Number(normalize(rate.value));equivalent.textContent=value>0?`${side==='thb_mmk'?`ဘတ် ${value} ပေး → ကျပ် ၁ သိန်း ရ`:`ကျပ် ၁ သိန်း ပေး → ဘတ် ${value} ရ`} · ၁ ဘတ် ≈ ${Number((100000/value).toFixed(2))} ကျပ်`:'နှုန်းဖြည့်ပြီးရင် ဒီနေရာမှာ ပြပေးမယ်။';legacy.textContent=fee||bps?'ဒီအဟောင်းမှာ နုတ်ငွေပါခဲ့ပါတယ်။ နှုန်းအသစ် ပြင်ဖြည့်ရင် နုတ်ငွေကို ဖယ်ပေးမယ်။':'';};
 const stamp=()=>{observed.value=localTime(new Date().toISOString());expires.value=localTime(new Date(Date.now()+86400000).toISOString());};
 today.addEventListener('click',()=>{stamp();box.checked=true;changed();update();});
 rate.addEventListener('input',()=>{checkedRate=0;fee=0;bps=0;stamp();box.checked=false;changed();update();});
 observed.addEventListener('change',()=>{const at=new Date(observed.value);if(Number.isFinite(+at))expires.value=localTime(new Date(+at+86400000).toISOString());box.checked=false;changed();});
 expires.addEventListener('change',()=>{box.checked=false;changed();});box.addEventListener('change',changed);
 card.readQuote=()=>{
  const value=Number(normalize(rate.value));if(!/^\d+(?:\.\d{1,2})?$/.test(normalize(rate.value))||value<=0||value>100000){rate.focus();throw new Error('ဘတ်ပမာဏကို ပြန်စစ်ပေးပါ။ ဒသမဆို ၂ နေရာအထိ ရပါတယ်။');}
  if(!box.checked)throw new Error('နှုန်းကို ပြန်စစ်ပြီး အမှန်ခြစ်ပေးပါ။');
  const at=new Date(observed.value),until=new Date(expires.value);if(!Number.isFinite(+at)||!Number.isFinite(+until))throw new Error('ဈေးစစ်ချိန်ကို ပြန်စစ်ပေးပါ။');
  return {id:card.dataset.id,label:original.label||directionName(side),direction:side,rate_micros:checkedRate||Math.round(100000/value*1e6),flat_fee_minor:fee,fee_bps:bps,source_name:original.source_name||'နေ့စဉ်ရည်ညွှန်းနှုန်း',source_url:original.source_url||'',payout_method:original.payout_method||'မဖော်ပြထားပါ',note:original.note||'',observed_at:at.toISOString(),valid_until:until.toISOString(),source_checked:true};
 };
 // Preserve full original timestamps when untouched; datetime-local controls omit seconds.
 const read=card.readQuote;card.readQuote=()=>{const value=read();if(observed.value===localTime(original.observed_at||''))value.observed_at=original.observed_at;if(expires.value===localTime(original.valid_until||''))value.valid_until=original.valid_until;return value;};
 card.dataset.direction=side;update();$('editors').append(card);return card;
}
function addDirection(direction) {
 const existing=[...$('editors').children].find(card=>card.dataset.direction===direction);
 if(existing){existing.querySelector('[data-key="rate"]').focus();return;}
 const prior=state?.published?.quotes.find(q=>q.direction===direction)||state?.draft?.quotes.find(q=>q.direction===direction);
 const card=editor(prior||{id:'daily-'+direction,direction});changed();card.querySelector('[data-key="rate"]').focus();
}
function readSheet(){return {notice:$('notice').value.trim(),quotes:[...$('editors').children].map(card=>card.readQuote())};}
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

$('reload').addEventListener('click',()=>action(async()=>{if(dirty&&!confirm('မသိမ်းရသေးတာများ ပျောက်မည်။ Reload လုပ်မလား?'))return;await load();message('နောက်ဆုံး Draft ရယူပြီးပါပြီ');}));
$('save').addEventListener('click',()=>action(async()=>{await save();previewed=false;$('publish').disabled=true;message('Draft သိမ်းပြီးပါပြီ။ User များ မမြင်ရသေးပါ။');}));
$('preview-button').addEventListener('click',()=>action(async()=>{
 const sheet=await save();$('preview-cards').replaceChildren();
 for(const q of sheet.quotes){const card=element('div',undefined,'preview-card'),rate=Number((100000000000/q.rate_micros).toFixed(2));card.append(element('strong',directionName(q.direction)),element('p',q.direction==='thb_mmk'?`ဘတ် ${rate} ပေး → ကျပ် ၁ သိန်း ရ`:`ကျပ် ၁ သိန်း ပေး → ဘတ် ${rate} ရ`),element('p',`ဈေးစစ်ချိန် ${new Date(q.observed_at).toLocaleString()}`));if(Date.parse(q.valid_until)<=Date.now())card.append(element('p','အဟောင်းဈေး — မူလစစ်ချိန်အတိုင်း ဆက်ပြမယ်။ အသစ်ပြန်စစ်ထားသလို မပြပါဘူး။'));if(q.flat_fee_minor||q.fee_bps)card.append(element('p','အဟောင်းတွင် နုတ်ငွေပါရှိသည်။'));$('preview-cards').append(card);}
 if(!sheet.quotes.length)$('preview-cards').append(element('p','နှုန်းအားလုံး အလွတ်ဖြစ်နေပါတယ်။'));
 $('preview').hidden=false;previewed=true;$('publish').disabled=false;message('User မြင်ရမယ့်နှုန်းကို စစ်ပြီး အတည်ပြုတင်ပေးပါ။');
}));
$('publish').addEventListener('click',()=>action(async()=>{if(dirty||!previewed)return;if(!confirm('ဤနှုန်းများကို user အားလုံးဆီ ထုတ်ပြမလား?'))return;const result=await api('publish','POST',{expected_version:state.draft_version});await load();message('Publish အောင်မြင်ပါသည်။ Version '+result.published.revision);}));
$('logout').addEventListener('click',()=>{if(dirty&&!confirm('မသိမ်းရသေးတာရှိသည်။ ထွက်မလား?'))return;window.location.href='/signout-with-chatgpt?return_to=%2Fadmin%2Findex.html';});
$('export').addEventListener('click',()=>{const blob=new Blob([JSON.stringify(state.published,null,2)],{type:'application/json'});const url=URL.createObjectURL(blob);const a=document.createElement('a');a.href=url;a.download='bahtzay-rates-v'+state.published.revision+'.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);});
window.addEventListener('beforeunload',e=>{if(dirty){e.preventDefault();e.returnValue='';}});
load().catch(e=>{if(!/ပြန်ဝင်/.test(e.message))message(e.message,true);});

$('insights-refresh').addEventListener('click',()=>action(async()=>{const data=await api('insights');const delivered=data.deliveries.find(x=>x.status===1)?.count||0;const pending=data.deliveries.find(x=>x.status===0)?.count||0;$('insights-text').textContent=`အသိပေးမှု ဖွင့်ထားသူ ${data.active_subscribers} ဦး · ပို့ပြီး ${delivered} စောင် · စောင့်နေ ${pending} စောင်`; }));
