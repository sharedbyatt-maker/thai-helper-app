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
 w.eval(fs.readFileSync(path.join(root,'app.js'),'utf8'));
 return {dom,w,state,$:id=>w.document.getElementById(id),get:(card,key)=>card.querySelector(`[data-key="${key}"]`)};
}
test('Guided inputs show examples, accept Myanmar digits and keep optional deductions at zero',async()=>{
 const {dom,w,state,$,get}=setup();try{
  await until(()=>$('workspace').hidden===false);$('add').click();const card=$('editors').firstElementChild;
  assert.match(get(card,'rate').placeholder,/125/);assert.match(get(card,'source_name').placeholder,/ဥပမာ/);
  assert.equal(get(card,'flat_fee').closest('details').open,false);
  get(card,'rate').value='၁၂၅';get(card,'rate').dispatchEvent(new w.Event('input',{bubbles:true}));
  get(card,'source_name').value='Test source';get(card,'source_name').dispatchEvent(new w.Event('input',{bubbles:true}));get(card,'source_checked').checked=true;
  $('preview-button').click();await until(()=>$('publish').disabled===false);
  assert.equal(state.draft.quotes[0].rate_micros,125000000);assert.equal(state.draft.quotes[0].flat_fee_minor,0);assert.equal(state.draft.quotes[0].fee_bps,0);assert.equal(state.published.revision,0);
  assert.ok(state.draft.quotes[0].label);assert.equal(state.draft.quotes[0].payout_method,'မဖော်ပြထားပါ');
  $('publish').click();await until(()=>state.published.revision===1);await until(()=>$('message').textContent.includes('Publish အောင်မြင်'));
 }finally{dom.window.close();}
});
test('Daily shortcut reuses quote ID; opposite direction copies source and requires its own rate',async()=>{
 const {dom,w,$,get}=setup();try{
  await until(()=>$('workspace').hidden===false);$('add').click();const first=$('editors').firstElementChild;
  get(first,'source_name').value='Same daily source';get(first,'rate').value='125';const id=first.dataset.id;
  $('add').click();assert.equal($('editors').children.length,1);assert.equal(first.dataset.id,id);
  $('add-mmk').click();const second=$('editors').lastElementChild;
  assert.equal(get(second,'direction').value,'mmk_thb');assert.match(get(second,'flat_fee').parentElement.textContent,/ကျပ်/);assert.equal(get(second,'source_name').value,'Same daily source');assert.equal(get(second,'rate').value,'');assert.equal(get(second,'source_checked').checked,false);
  get(first,'source_checked').checked=true;first.querySelector('[data-action="today"]').click();assert.equal(get(first,'source_checked').checked,false);assert.equal($('publish').disabled,true);
  assert.ok(new Date(get(first,'valid_until').value)>new Date(get(first,'observed_at').value));
 }finally{dom.window.close();}
});
test('Existing deductions remain visible and preserved; edits invalidate a confirmed preview',async()=>{
 const now=new Date();const quote={id:'existing',label:'Existing',direction:'thb_mmk',rate_micros:125000000,flat_fee_minor:2000,fee_bps:100,source_name:'Source',source_url:'',payout_method:'Bank',note:'',observed_at:now.toISOString(),valid_until:new Date(+now+86400000).toISOString(),source_checked:true};
 const {dom,w,state,$,get}=setup([quote]);try{
  await until(()=>$('workspace').hidden===false);const card=$('editors').firstElementChild;
  assert.equal(get(card,'flat_fee').closest('details').open,true);
  $('preview-button').click();await until(()=>$('publish').disabled===false);
  assert.equal(state.draft.quotes[0].flat_fee_minor,2000);assert.equal(state.draft.quotes[0].fee_bps,100);
  get(card,'rate').value='126';get(card,'rate').dispatchEvent(new w.Event('input',{bubbles:true}));assert.equal($('publish').disabled,true);assert.equal(get(card,'source_checked').checked,false);
 }finally{dom.window.close();}
});
test('Unit conversion stays equivalent and preview treats source markup as text',async()=>{
 const {dom,w,state,$,get}=setup();try{
  await until(()=>$('workspace').hidden===false);$('add').click();const card=$('editors').firstElementChild;
  get(card,'rate').value='125';get(card,'rate_unit').value='per_lakh';get(card,'rate_unit').dispatchEvent(new w.Event('change',{bubbles:true}));
  assert.equal(get(card,'rate').value,'800');assert.match(get(card,'rate').placeholder,/800/);
  get(card,'source_name').value='<script>bad()</script>';get(card,'source_checked').checked=true;
  $('preview-button').click();await until(()=>$('publish').disabled===false);
  assert.equal(state.draft.quotes[0].rate_micros,125000000);assert.equal($('preview-cards').querySelector('script,img'),null);assert.match($('preview-cards').textContent,/<script>/);
 }finally{dom.window.close();}
});
