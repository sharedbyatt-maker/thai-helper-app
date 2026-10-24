'use strict';
const $ = id => document.getElementById(id);
let announcementAttempt=null;
let state, csrf = '', dirty = false, previewed = false, busy = false, bootstrapRequest = null;
function message(text, error=false) {
  const feedback=$('message');
  feedback.setAttribute('role',error?'alert':'status');
  feedback.setAttribute('aria-live',error?'assertive':'polite');
  feedback.textContent=text;
  feedback.classList.toggle('error',error);
  if(error)feedback.scrollIntoView?.({block:'nearest'});
}
window.AdminRuntime.track('rates',()=>dirty);
window.AdminRuntime.track('announcement',()=>Boolean($('announcement-text')?.value.trim()));
window.addEventListener('admin:unauthorized',()=>{$('workspace').hidden=true;$('login-panel').hidden=false;$('logout').hidden=true;});
function changed() { dirty=true; previewed=false; $('publish').disabled=true; $('dirty').textContent='ပြင်ထားတာ မသိမ်းရသေးဘူး'; }
async function api(path, method='GET', body, allowBootstrap=true) {
  const {response,data}=await window.AdminRuntime.fetchJson('/api/admin/'+path,{method,credentials:'same-origin',headers:{'Content-Type':'application/json','X-Admin-Request':'1','X-CSRF-Token':csrf},body:body===undefined?undefined:JSON.stringify(body)});
  if(!response.ok) {
    // First-time enrollment is shared across reads and bounded to one retry.
    // A network failure never retries a mutation whose result is uncertain.
    if(data.bootstrap_ready&&path!=='login'&&allowBootstrap){
      if(!bootstrapRequest)bootstrapRequest=api('login','POST',{},false)
        .finally(()=>{bootstrapRequest=null;});
      await bootstrapRequest;
      return api(path,method,body,false);
    }
    if(response.status===401){$('workspace').hidden=true;$('login-panel').hidden=false;$('logout').hidden=true;}
    const e=new Error(response.status===409
      ?'တခြားနေရာမှာ ပြောင်းထားပါတယ်။ ပြင်ထားတာတွေ မပျောက်အောင် အရင်ကူးထားပြီး Reload နဲ့ ပြန်စစ်ပေးပါ။'
      :data.error||'လုပ်ဆောင်မှု မအောင်မြင်ပါ');
    e.status=response.status;
    throw e;
  }
  if(data.csrf_token)csrf=data.csrf_token;
  return data;
}
async function action(fn) { if(busy)return;busy=true;$('workspace').inert=true;$('workspace').setAttribute('aria-busy','true');$('admin-refresh').disabled=true;$('login-panel').inert=true;try{await fn();}catch(e){message(e.message,true);}finally{busy=false;$('workspace').inert=false;$('workspace').setAttribute('aria-busy','false');$('admin-refresh').disabled=refreshing;$('login-panel').inert=false;} }
function localTime(iso) { const d=new Date(iso); const p=n=>String(n).padStart(2,'0');return `${d.getFullYear()}-${p(d.getMonth()+1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`; }
function thaiTime(iso){return new Date(iso).toLocaleString('en-GB',{timeZone:'Asia/Bangkok'})+' (ထိုင်း)';}
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
 const original={...q};let observedDirty=false,expiresDirty=false,stampedAt,stampedUntil;let checkedRate=q.rate_micros||0, fee=q.flat_fee_minor||0, bps=q.fee_bps||0;
 const row=element('div',undefined,'row');row.append(element('h2',directionName(side)));
 const today=element('button','ဒီဈေးကို အခု ပြန်စစ်ပြီးပြီ');today.type='button';today.dataset.action='today';row.append(today);const remove=element('button','မူကြမ်းကနေ ဖယ်မယ်','danger quiet');remove.type='button';remove.dataset.action='remove';remove.addEventListener('click',()=>{if(!confirm('ဒီဘက်ဈေးကို မူကြမ်းကနေ ဖယ်မလား? User app ပေါ်ကဈေးကို ပြောင်းဖို့ နမူနာစစ်ပြီး အတည်ပြုတင်ရဦးမယ်။'))return;card.remove();changed();message('မူကြမ်းကနေ ဖယ်ထားပြီ။ မတင်ရသေးလို့ User app ပေါ်ကဈေး မပြောင်းသေးဘူး။');});row.append(remove);card.append(row);
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
 const stamp=()=>{observedDirty=true;expiresDirty=true;stampedAt=new Date().toISOString();stampedUntil=new Date(Date.parse(stampedAt)+86400000).toISOString();observed.value=localTime(stampedAt);expires.value=localTime(stampedUntil);};
 today.addEventListener('click',()=>{stamp();box.checked=true;changed();update();});
 rate.addEventListener('input',()=>{checkedRate=0;fee=0;bps=0;stamp();box.checked=false;changed();update();});
 observed.addEventListener('change',()=>{observedDirty=true;expiresDirty=true;stampedAt=undefined;stampedUntil=undefined;const at=new Date(observed.value);if(Number.isFinite(+at))expires.value=localTime(new Date(+at+86400000).toISOString());box.checked=false;changed();});
 expires.addEventListener('change',()=>{expiresDirty=true;stampedUntil=undefined;box.checked=false;changed();});box.addEventListener('change',changed);
 card.readQuote=()=>{
  const value=Number(normalize(rate.value));if(!/^\d+(?:\.\d{1,2})?$/.test(normalize(rate.value))||value<=0||value>100000){rate.focus();throw new Error('ဘတ်ပမာဏကို ပြန်စစ်ပေးပါ။ ဒသမဆို ၂ နေရာအထိ ရပါတယ်။');}
  if(!box.checked)throw new Error('နှုန်းကို ပြန်စစ်ပြီး အမှန်ခြစ်ပေးပါ။');
  const at=new Date(observed.value),until=new Date(expires.value);if(!Number.isFinite(+at)||!Number.isFinite(+until))throw new Error('ဈေးစစ်ချိန်ကို ပြန်စစ်ပေးပါ။');
  return {id:card.dataset.id,label:original.label||directionName(side),direction:side,rate_micros:checkedRate||Math.round(100000/value*1e6),flat_fee_minor:fee,fee_bps:bps,source_name:original.source_name||'နေ့စဉ်ရည်ညွှန်းနှုန်း',source_url:original.source_url||'',payout_method:original.payout_method||'မဖော်ပြထားပါ',note:original.note||'',observed_at:stampedAt||at.toISOString(),valid_until:stampedUntil||until.toISOString(),source_checked:true};
 };
 // Preserve full original timestamps when untouched; datetime-local controls omit seconds.
 const read=card.readQuote;card.readQuote=()=>{const value=read();if(!observedDirty&&observed.value===localTime(original.observed_at||''))value.observed_at=original.observed_at;if(!expiresDirty&&expires.value===localTime(original.valid_until||''))value.valid_until=original.valid_until;return value;};
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
  if(typeof renderAppRelease==='function')renderAppRelease(state.app_release);
  $('login-panel').hidden=true;$('workspace').hidden=false;$('logout').hidden=false;
  $('notice').value=state.draft.notice;$('editors').replaceChildren();state.draft.quotes.forEach(editor);
  $('published-version').textContent='Version '+state.published.revision;
  $('published-time').textContent=state.published.published_at?thaiTime(state.published.published_at):'မထုတ်ပြရသေးပါ';
  $('draft-count').textContent=state.draft.quotes.length+' နှုန်း';renderPublished();renderHistory();
  dirty=false;previewed=false;$('dirty').textContent='မူကြမ်း သိမ်းထားပြီး';$('publish').disabled=true;$('preview').hidden=true;
}
function rateSummary(q) {const rate=Number((100000000000/q.rate_micros).toFixed(2));return q.direction==='thb_mmk'?`ဘတ် ${rate} → ကျပ် ၁ သိန်း`:`ကျပ် ၁ သိန်း → ${rate} ဘတ်`;}
function revisionSummary(rev){return (rev.quotes||[]).map(q=>`${directionName(q.direction)} · ${rateSummary(q)} · ဈေးစစ်ချိန် ${thaiTime(q.observed_at)}`).join('\n')||'နှုန်းအလွတ်';}
function renderPublished(){
 $('published-rates').replaceChildren();
 for(const q of state.published.quotes){const card=element('div',undefined,'live-rate');card.append(element('small',directionName(q.direction)),element('strong',rateSummary(q)),element('small','ဈေးစစ်ချိန် '+thaiTime(q.observed_at)));const stale=Date.parse(q.valid_until)<=Date.now();card.append(element('span',stale?'အဟောင်းဈေး · ပြန်စစ်ဖို့လိုပြီ':'စစ်ထားတဲ့ဈေး','rate-status'+(stale?' expired':'')));$('published-rates').append(card);}
 if(!state.published.quotes.length)$('published-rates').append(element('p','ဈေး မတင်ရသေးဘူး။ အောက်မှာ နှုန်းဖြည့်ပြီး တင်နိုင်တယ်။','muted'));
 $('delete-latest').disabled=!state.published.quotes.length;
}
async function restoreRevision(rev){
 if(!confirm(`တင်ချက် #${rev.id} ကို မူကြမ်းအဖြစ် ပြန်ယူမလား?\n${revisionSummary(rev)}\n\nလက်ရှိမူကြမ်းကို အစားထိုးမယ်။ User app ပေါ် ချက်ချင်း မတင်ပါဘူး။`))return;
 await api('restore','POST',{revision:rev.id,expected_version:state.draft_version});await load();$('edit-panel').scrollIntoView?.({behavior:'smooth',block:'start'});message('မူကြမ်းထဲ ပြန်ယူပြီးပြီ။ နှုန်းနဲ့ စစ်ချိန်ကို ပြန်စစ်ပြီးမှ တင်ပေးပါ။');
}
async function deleteRevision(rev){
 const current=rev.id===state.published.revision;
 if(!confirm(`တင်ချက် #${rev.id} ကို ဖျက်မလား?\n${revisionSummary(rev)}\n\n${current?'လက်ရှိဈေးကို ဖယ်ပြီး အရင်တင်ချက်ဈေးကို မူလစစ်ချိန်အတိုင်း ဆက်ပြမယ်။':'ဒီတင်ချက်ကို စာရင်းကနေ ဖယ်မယ်။ နောက်တင်ချက်တွေက ဈေး မပြောင်းပါဘူး။'} ဖျက်ထားတဲ့စာရင်းမှာ ပြန်ယူနိုင်တယ်။${dirty?'\nမသိမ်းရသေးတဲ့ ပြင်ဆင်ချက်တွေ ပျောက်သွားမယ်။':''}`))return;
 await api('delete-revision','POST',{revision:rev.id,expected_revision:state.published.revision,expected_version:state.draft_version});await load();message('တင်ချက်ကို ဖယ်ပြီးပြီ။ အောက်က “ဖျက်ထားတဲ့တင်ချက်တွေ” မှာ မူကြမ်းအဖြစ် ပြန်ယူနိုင်တယ်။');
}
function renderHistory(){
 $('history').replaceChildren();$('trash').replaceChildren();
 for(const rev of state.history){
  const card=element('article',undefined,'publication');const heading=element('div',undefined,'row');heading.append(element('strong',`တင်ချက် #${rev.id}${rev.id===state.published.revision?' · လက်ရှိပြနေတယ်':''}`),element('small',thaiTime(rev.published_at)));card.append(heading);
  for(const q of rev.quotes||[])card.append(element('p',rateSummary(q)),element('small','ဈေးစစ်ချိန် '+thaiTime(q.observed_at)));
  if(!rev.quotes?.length)card.append(element('p','နှုန်းအလွတ်','muted'));
  const actions=element('div',undefined,'publication-actions');const restore=element('button','မူကြမ်းအဖြစ် ပြန်ယူ');restore.dataset.restore=rev.id;restore.addEventListener('click',()=>action(()=>restoreRevision(rev)));const remove=element('button','ဒီတင်ချက် ဖျက်မယ်','danger');remove.dataset.delete=rev.id;remove.addEventListener('click',()=>action(()=>deleteRevision(rev)));actions.append(restore,remove);card.append(actions);$('history').append(card);
 }
 if(!state.history.length)$('history').append(element('p','တင်ထားတဲ့စာရင်း မရှိသေးဘူး။','muted'));
 for(const rev of state.trash||[]){const card=element('article',undefined,'publication archived');card.append(element('strong',`ဖျက်ထားတဲ့တင်ချက် #${rev.id}`),element('p',revisionSummary(rev)),element('small','ဖျက်ချိန် '+thaiTime(rev.deleted_at)));const restore=element('button','မူကြမ်းအဖြစ် ပြန်ယူ');restore.dataset.trashRestore=rev.id;restore.addEventListener('click',()=>action(()=>restoreRevision(rev)));card.append(restore);$('trash').append(card);}
 $('trash-count').textContent=(state.trash||[]).length+' ခု';
 if(!state.trash?.length)$('trash').append(element('p','ဖျက်ထားတဲ့တင်ချက် မရှိသေးဘူး။','muted'));
}
$('delete-latest').addEventListener('click',()=>action(()=>deleteRevision({...state.published,id:state.published.revision})));
let stateRequest=0,lastSynced=null;
function syncStatus(text,error=false){$('admin-sync').textContent=text;$('admin-connection').classList.toggle('error',error);}
function synced(){lastSynced=new Date();syncStatus('ချိတ်ဆက်ပြီး · '+thaiTime(lastSynced.toISOString()));window.dispatchEvent(new CustomEvent('admin:state',{detail:state}));}
async function load(){const request=++stateRequest;const next=await api('state');if(request!==stateRequest)return;state=next;render();synced();}
let refreshing=false;
async function refreshState(manual=false){
 if(busy||refreshing||document.hidden)return;
 if(window.AdminRuntime.hasUnsaved()||previewed){syncStatus('ပြင်ဆင်မှုကို ထိန်းထားပါတယ် · အလိုအလျောက် Reload ခဏရပ်ထားပါတယ်');return;}
 refreshing=true;$('admin-refresh').disabled=true;
 const request=++stateRequest;
 try{
  const next=await api('state');
  if(request!==stateRequest||busy||window.AdminRuntime.hasUnsaved()||previewed)return;
  const changedVersion=!state||state.draft_version!==next.draft_version||state.published.revision!==next.published.revision;
  state=next;if(changedVersion)render();else {renderPublished();if(typeof renderAppRelease==='function')renderAppRelease(state.app_release);}
  synced();if(manual)message('နောက်ဆုံးအခြေအနေ စစ်ပြီးပါပြီ။');
 }catch(e){syncStatus('ချိတ်ဆက်မှု မအောင်မြင် · ပြထားသော data သည် အဟောင်း ဖြစ်နိုင်ပါတယ်',true);if(manual)message(e.message,true);}
 finally{refreshing=false;$('admin-refresh').disabled=busy;}
}
$('admin-refresh').addEventListener('click',()=>refreshState(true));
window.addEventListener('online',()=>refreshState());
window.addEventListener('offline',()=>syncStatus('အင်တာနက် မရှိပါ · ပြင်ထားတာတွေ မပိတ်ပါနဲ့',true));
window.addEventListener('focus',()=>refreshState());
document.addEventListener('visibilitychange',()=>{if(!document.hidden)refreshState();});
setInterval(()=>refreshState(),60000);
window.bahtzayAdminRefresh=refreshState;
async function save(){const sheet=readSheet();const result=await api('draft','PUT',{sheet,expected_version:state.draft_version});state.draft_version=result.draft_version;state.draft=sheet;dirty=false;$('dirty').textContent='မူကြမ်း သိမ်းထားပြီး';$('draft-count').textContent=sheet.quotes.length+' နှုန်း';return sheet;}
$('notice').addEventListener('input',changed);
$('add').addEventListener('click',()=>addDirection('thb_mmk'));
$('add-mmk').addEventListener('click',()=>addDirection('mmk_thb'));

$('reload').addEventListener('click',()=>action(async()=>{if(dirty&&!confirm('မသိမ်းရသေးတာများ ပျောက်မည်။ Reload လုပ်မလား?'))return;await load();message('နောက်ဆုံး Draft ရယူပြီးပါပြီ');}));
$('save').addEventListener('click',()=>action(async()=>{await save();previewed=false;$('publish').disabled=true;message('Draft သိမ်းပြီးပါပြီ။ User များ မမြင်ရသေးပါ။');}));
$('preview-button').addEventListener('click',()=>action(async()=>{
 const sheet=await save();$('preview-cards').replaceChildren();
 for(const q of sheet.quotes){const card=element('div',undefined,'preview-card'),rate=Number((100000000000/q.rate_micros).toFixed(2));card.append(element('strong',directionName(q.direction)),element('p',q.direction==='thb_mmk'?`ဘတ် ${rate} ပေး → ကျပ် ၁ သိန်း ရ`:`ကျပ် ၁ သိန်း ပေး → ဘတ် ${rate} ရ`),element('p',`ဈေးစစ်ချိန် ${thaiTime(q.observed_at)}`));if(Date.parse(q.valid_until)<=Date.now())card.append(element('p','အဟောင်းဈေး — မူလစစ်ချိန်အတိုင်း ဆက်ပြမယ်။ အသစ်ပြန်စစ်ထားသလို မပြပါဘူး။'));if(q.flat_fee_minor||q.fee_bps)card.append(element('p','အဟောင်းတွင် နုတ်ငွေပါရှိသည်။'));$('preview-cards').append(card);}
 if(!sheet.quotes.length)$('preview-cards').append(element('p','နှုန်းအားလုံး အလွတ်ဖြစ်နေပါတယ်။'));
 const phone=await api('push-preview','POST',{sheet});
 const phoneCard=element('div',undefined,'preview-card');phoneCard.append(element('strong',phone.preview?.title||'သက်တမ်းကုန်နှုန်း — Noti မပို့ပါ'),element('p',phone.preview?.body||''),element('small','Noti နှိပ်ရင် → ဘတ်ဈေး'));$('preview-cards').append(phoneCard);
 $('preview').hidden=false;previewed=true;$('publish').disabled=false;message('User မြင်ရမယ့်နှုန်းကို စစ်ပြီး အတည်ပြုတင်ပေးပါ။');
}));
$('publish').addEventListener('click',()=>action(async()=>{if(dirty||!previewed)return;if(!confirm('ဤနှုန်းများကို user အားလုံးဆီ ထုတ်ပြမလား?'))return;const result=await api('publish','POST',{expected_version:state.draft_version});await load();message('Publish အောင်မြင်ပြီ။ Version '+result.published.revision);}));
$('logout').addEventListener('click',()=>{if(window.AdminRuntime.hasUnsaved()&&!confirm('မသိမ်းရသေးတာရှိသည်။ ထွက်မလား?'))return;window.location.href='/signout-with-chatgpt?return_to=%2Fadmin%2Findex.html';});
$('export').addEventListener('click',()=>{const blob=new Blob([JSON.stringify(state.published,null,2)],{type:'application/json'});const url=URL.createObjectURL(blob);const a=document.createElement('a');a.href=url;a.download='bahtzay-rates-v'+state.published.revision+'.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);});
window.addEventListener('beforeunload',e=>{if(dirty){e.preventDefault();e.returnValue='';}});
load().catch(e=>{syncStatus('ချိတ်ဆက်မှု မအောင်မြင် · ပြန်စစ်မယ်ကို နှိပ်ပါ',true);if(!/ပြန်ဝင်/.test(e.message))message(e.message,true);});

$('insights-refresh').addEventListener('click',()=>action(async()=>{const data=await api('insights');const delivered=data.deliveries.find(x=>x.status===1)?.count||0;const pending=data.deliveries.find(x=>x.status===0)?.count||0;const phones=data.phone_subscribers||0,phoneSent=(data.phone_deliveries||[]).find(x=>x.status===1)?.count||0,phonePending=(data.phone_deliveries||[]).find(x=>x.status===0)?.count||0;$('insights-text').textContent=`ဖုန်း noti ဖွင့်ထားသူ ${phones} ဦး · ပို့ပြီး ${phoneSent} စောင် · စောင့်နေ ${phonePending} စောင်\nTelegram အသိပေးမှု ဖွင့်ထားသူ ${data.active_subscribers} ဦး · ပို့ပြီး ${delivered} စောင် · စောင့်နေ ${pending} စောင်`; }));

$('announcement-publish').addEventListener('click',()=>action(async()=>{
 const notice=$('announcement-text').value.trim();if(!notice){$('announcement-text').focus();throw new Error('ကြေညာစာကို အရင်ဖြည့်ပေးပါ။');}
 if(!confirm(`ကြေညာချက်ကို စစ်ပေးပါ\n\n${notice}\n\nနှိပ်ရင် → ${$('announcement-target').selectedOptions[0].textContent}\n\nအတည်ပြုရင် App ပေါ်တင်ပြီး ဖုန်း noti ဖွင့်ထားသူတွေကို အသိပေးမယ်။ ဈေးနှုန်းနဲ့ မူလစစ်ချိန် မပြောင်းပါဘူး။${dirty?'\nမသိမ်းရသေးတဲ့ ပြင်ဆင်ချက်တွေ ပျောက်သွားမယ်။':''}`))return;
 if(!announcementAttempt)announcementAttempt={notice,expected_revision:state.published.revision,expected_version:state.draft_version,target:$('announcement-target').value};
 await api('announcement','POST',announcementAttempt);announcementAttempt=null;$('announcement-text').value='';updateNotificationPreview();await load();message('ကြေညာချက် တင်ပြီးပြီ။ Noti ဖွင့်ထားသူတွေဆီ ပို့ဖို့ စာရင်းထည့်ထားတယ်။');
}));

$('announcement-template').addEventListener('change',event=>{
 const next=event.target.value,field=$('announcement-text');
 if(!next)return;
 if(field.value.trim()&&field.value!==next&&!confirm('ရေးထားတဲ့စာကို ဒီစာတိုနဲ့ အစားထိုးမလား?')){event.target.value='';return;}
 field.value=next;$('announcement-target').value=(next.includes('မှတ်')||next.includes('စီမံ'))?'wallet':next.includes('တွက်')?'calculator':'rates';field.dispatchEvent(new Event('input',{bubbles:true}));field.focus();event.target.value='';
});

function updateNotificationPreview(){
 const parts=[...new Intl.Segmenter('my',{granularity:'grapheme'}).segment($('announcement-text').value.replace(/\s+/gu,' ').trim())].map(x=>x.segment);
 const body=parts.length>90?parts.slice(0,89).join('')+'…':parts.join('');
 const target=$('announcement-target');
 $('announcement-preview').replaceChildren(element('strong','ဘတ်ဈေး'),element('p',body||'ကြေညာစာ ဖြည့်ပေးပါ။'),element('small','နှိပ်ရင် → '+target.selectedOptions[0].textContent));
}
$('announcement-text').addEventListener('input',()=>{announcementAttempt=null;updateNotificationPreview();});
$('announcement-target').addEventListener('change',()=>{announcementAttempt=null;updateNotificationPreview();});
updateNotificationPreview();
$('push-history-refresh').addEventListener('click',()=>action(async()=>{
 const data=await api('push-history');$('push-history').replaceChildren();
 for(const event of data.events){const c=event.counts,card=element('div',undefined,'preview-card');card.append(element('strong',event.preview?.title||'သက်တမ်းကုန်စာ'),element('p',event.preview?.body||''),element('small',thaiTime(new Date(event.created_at).toISOString())),element('p',`ကြိုးစားပို့ ${c.attempted||0} · Service လက်ခံ ${c.accepted||0} · စောင့်နေ ${c.pending||0} · မအောင်မြင် ${c.failed||0} · ကျော်ထား ${c.skipped||0}`));$('push-history').append(card);}
 if(!data.events.length)$('push-history').textContent='ပို့မှတ်တမ်း မရှိသေးပါ။';
}));
$('owner-push-test').addEventListener('click',()=>{
 if(busy)return;
 if(!('Notification' in window)||!('serviceWorker' in navigator)||!('PushManager' in window)){message('ဒီ browser မှာ Noti မရသေးပါ။',true);return;}
 if(!confirm('ဒီ Admin စက်တစ်လုံးဆီပဲ စမ်းပို့မလား?'))return;
 const permission=Notification.requestPermission();
 action(async()=>{
  if(await permission!=='granted')throw Error('Browser Noti ခွင့်ပြုပေးပါ။');
  const response=await fetch('/api/v2/push/config'),config=await response.json();if(!config.available)throw Error('Noti ချိတ်ဆက်မှု မရသေးပါ။');
  const reg=await navigator.serviceWorker.register('/admin/test-push-sw.js',{scope:'/admin/'});
  if(!reg.active)await new Promise((resolve,reject)=>{const worker=reg.installing||reg.waiting;if(!worker){reject(Error('ပြန်စမ်းပါ။'));return;}const timer=setTimeout(()=>reject(Error('ချိတ်ဆက်ချိန် ကြာနေပါတယ်။')),10000);const check=()=>{if(worker.state==='activated'){clearTimeout(timer);resolve();}else if(worker.state==='redundant'){clearTimeout(timer);reject(Error('ပြန်စမ်းပါ။'));}};worker.addEventListener('statechange',check);check();});
  const key=Uint8Array.from(atob(config.public_key.replaceAll('-','+').replaceAll('_','/')+'='.repeat((4-config.public_key.length%4)%4)),x=>x.charCodeAt(0));
  const sub=await reg.pushManager.getSubscription()||await reg.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:key});
  await api('push-test','POST',{subscription:sub.toJSON()});message('ဒီစက်အတွက် Push service က လက်ခံပြီးပါပြီ။ ဖုန်းမှာ ရောက်မရောက် စစ်ပေးပါ။');
 });
});
