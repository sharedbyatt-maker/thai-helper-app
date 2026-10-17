const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {JSDOM}=require('jsdom');
const root=path.resolve(__dirname,'../hosted_backend/public/admin');
const pause=()=>new Promise(r=>setTimeout(r,5));
async function until(check){for(let i=0;i<150;i++){if(check())return;await pause();}throw Error('Admin UI did not settle');}
function setup(quotes=[]){
 const dom=new JSDOM(fs.readFileSync(path.join(root,'index.html'),'utf8'),{url:'https://rates.example/admin/index.html',runScripts:'outside-only'}),w=dom.window;
 w.confirm=()=>true;
 const state={draft:{notice:'',quotes},draft_version:0,published:{revision:0,quotes:[],published_at:null},history:[]};
 w.fetch=async(url,options={})=>{
  const endpoint=url.split('/').pop(),data=options.body?JSON.parse(options.body):{};
  const ok=data=>({ok:true,status:200,json:async()=>structuredClone(data)});
  if(endpoint==='state')return ok({...state,csrf_token:'same-origin'});
  assert.equal(options.headers['X-Admin-Request'],'1');
  if(endpoint==='draft'){assert.equal(data.expected_version,state.draft_version);state.draft=data.sheet;state.draft_version++;return ok({draft_version:state.draft_version});}
  if(endpoint==='publish'){assert.equal(data.expected_version,state.draft_version);state.draft_version++;state.published={...structuredClone(state.draft),revision:state.published.revision+1,published_at:new Date().toISOString()};return ok({published:state.published});}
  throw Error('Unexpected endpoint '+endpoint);
 };
 // Strict eval has its own declaration scope; expose the classic-script API as a browser would.
 w.eval(fs.readFileSync(path.join(root,'app.js'),'utf8')+'\nwindow.api=api;');
 return {dom,w,state,$:id=>w.document.getElementById(id),get:(card,key)=>card.querySelector(`[data-key="${key}"]`)};
}
test('Daily form uses lakh units, generic provenance, no provider or fee inputs, and requires explicit publish',async()=>{
 const {dom,w,state,$,get}=setup();try{
  await until(()=>$('workspace').hidden===false);$('add').click();const card=$('editors').firstElementChild;
  assert.match(get(card,'rate').placeholder,/748/);assert.equal(get(card,'source_name'),null);assert.equal(get(card,'flat_fee'),null);assert.equal(get(card,'rate_unit'),null);
  get(card,'rate').value='၇၄၈';get(card,'rate').dispatchEvent(new w.Event('input',{bubbles:true}));get(card,'source_checked').checked=true;
  $('preview-button').click();await until(()=>$('publish').disabled===false);
  assert.equal(state.draft.quotes[0].rate_micros,Math.round(100000/748*1e6));assert.equal(state.draft.quotes[0].flat_fee_minor,0);assert.equal(state.draft.quotes[0].fee_bps,0);assert.equal(state.published.revision,0);
  assert.equal(state.draft.quotes[0].source_name,'နေ့စဉ်ရည်ညွှန်းနှုန်း');assert.match($('preview').textContent,/748/);
  $('publish').click();await until(()=>state.published.revision===1);await until(()=>$('message').textContent.includes('Publish အောင်မြင်'));
 }finally{dom.window.close();}
});
test('Daily directions keep stable IDs even after removal and never infer an opposite price',async()=>{
 const {dom,w,$,get}=setup();try{
  await until(()=>$('workspace').hidden===false);$('add').click();const first=$('editors').firstElementChild;
  get(first,'rate').value='748';const id=first.dataset.id;$('add').click();assert.equal($('editors').children.length,1);
  $('add-mmk').click();const second=$('editors').lastElementChild;assert.equal(second.dataset.direction,'mmk_thb');assert.equal(get(second,'rate').value,'');
  first.remove();$('add').click();assert.equal($('editors').lastElementChild.dataset.id,id);
  const card=$('editors').lastElementChild;card.querySelector('[data-action="today"]').click();assert.equal(get(card,'source_checked').checked,true);assert.equal($('publish').disabled,true);
 }finally{dom.window.close();}
});
test('Untouched legacy fees and full timestamps survive; a new rate clears deductions and invalidates preview',async()=>{
 const at=new Date().toISOString();const quote={id:'existing',label:'Existing',direction:'thb_mmk',rate_micros:125000000,flat_fee_minor:2000,fee_bps:100,source_name:'Source',source_url:'',payout_method:'Bank',note:'',observed_at:at,valid_until:new Date(Date.now()+86400000).toISOString(),source_checked:true};
 const {dom,w,state,$,get}=setup([quote]);try{
  await until(()=>$('workspace').hidden===false);const card=$('editors').firstElementChild;
  assert.equal(get(card,'rate').value,'800');assert.equal(get(card,'flat_fee'),null);assert.match(card.textContent,/အဟောင်းမှာ နုတ်ငွေ/);
  $('preview-button').click();await until(()=>$('publish').disabled===false);assert.equal(state.draft.quotes[0].flat_fee_minor,2000);assert.equal(state.draft.quotes[0].observed_at,at);
  get(card,'rate').value='750';get(card,'rate').dispatchEvent(new w.Event('input',{bubbles:true}));assert.equal($('publish').disabled,true);assert.equal(get(card,'source_checked').checked,false);
  get(card,'source_checked').checked=true;$('preview-button').click();await until(()=>$('publish').disabled===false);assert.equal(state.draft.quotes[0].flat_fee_minor,0);assert.equal(state.draft.quotes[0].fee_bps,0);
 }finally{dom.window.close();}
});
test('Telegram setup keeps token out of displayed state and provides an expiring pairing link',async()=>{
 const {dom,w,$}=setup();let configured=false,enabled=false,submitted;
 const original=w.fetch;
 w.fetch=async(url,options={})=>{
  if(!url.includes('/telegram'))return original(url,options);
  const ok=data=>({ok:true,status:200,json:async()=>data});
  const data=options.body?JSON.parse(options.body):{};
  if(url.endsWith('/pair'))return ok({url:'https://t.me/example_bot?start=pair_abc',expires_in:600});
  if(url.endsWith('/disconnect')){enabled=false;return ok({ok:true});}
  if(options.method==='POST'){submitted=data;configured=true;enabled=true;}
  return ok({configured,enabled,paired:false,username:configured?'example_bot':'',source_name:configured?'S.T.K Money Exchange':'',source_url:'',direction:'mmk_thb'});
 };
 try{
  w.eval(fs.readFileSync(path.join(root,'telegram.js'),'utf8'));
  await until(()=>$('tg-status').textContent.includes('Bot မချိတ်ရသေး'));
  await until(()=>$('tg-refresh').disabled===false);
  $('tg-token').value='secret-test-token';$('tg-source').value='S.T.K Money Exchange';$('tg-connect').click();
  await until(()=>$('tg-status').textContent.includes('@example_bot'));
  assert.equal(submitted.token,'secret-test-token');assert.equal(submitted.direction,'mmk_thb');assert.equal($('tg-token').value,'');assert.equal($('tg-status').textContent.includes('secret-test-token'),false);
  await until(()=>$('tg-setup').inert===false);$('tg-pair').click();await until(()=>$('tg-pair-link').hidden===false);
  assert.match($('tg-pair-link').href,/https:\/\/t.me\/example_bot\?start=pair_/);
  await until(()=>$('tg-setup').inert===false);$('tg-disconnect').click();await until(()=>$('tg-status').textContent.includes('ရပ်ထား'));
 }finally{dom.window.close();}
});
