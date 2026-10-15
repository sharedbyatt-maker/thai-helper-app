const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {JSDOM}=require('jsdom');
const root=path.resolve(__dirname,'../admin');
const pause=()=>new Promise(r=>setTimeout(r,5));
async function waitFor(check){for(let i=0;i<200;i++){if(check())return;await pause();}throw Error('UI did not reach expected state');}
function setup(){
 const dom=new JSDOM(fs.readFileSync(path.join(root,'index.html'),'utf8'),{url:'https://app.example/admin',runScripts:'outside-only'});
 const w=dom.window;w.confirm=()=>true;w.crypto.randomUUID=()=>`quote-${Math.random()}`;
 const backend={draft:{notice:'',quotes:[]},draft_version:0,published:{revision:0,quotes:[],published_at:null},history:[]};
 let authorized=false;
 w.fetch=async(url,options={})=>{
  const endpoint=url.split('/').pop(),method=options.method||'GET',data=options.body?JSON.parse(options.body):{};
  const ok=body=>({ok:true,status:200,json:async()=>structuredClone(body)});
  if(endpoint==='login'){authorized=data.password==='test-password';return authorized?ok({csrf_token:'csrf'}):{ok:false,status:401,json:async()=>({error:'Password မမှန်ပါ'})};}
  if(!authorized)return {ok:false,status:401,json:async()=>({error:'အကောင့် ပြန်ဝင်ပါ'})};
  if(method!=='GET')assert.equal(options.headers['X-CSRF-Token'],'csrf');
  if(endpoint==='state')return ok({...backend,csrf_token:'csrf'});
  if(endpoint==='draft'){assert.equal(data.expected_version,backend.draft_version);backend.draft=structuredClone(data.sheet);backend.draft_version++;return ok({draft_version:backend.draft_version});}
  if(endpoint==='publish'){assert.equal(data.expected_version,backend.draft_version);backend.draft_version++;backend.published={...structuredClone(backend.draft),revision:backend.published.revision+1,published_at:new Date().toISOString()};return ok({published:backend.published});}
  if(endpoint==='logout'){authorized=false;return ok({});}
  throw Error('Unexpected endpoint '+endpoint);
 };
 w.eval(fs.readFileSync(path.join(root,'app.js'),'utf8'));
 return {dom,w,backend,$:id=>w.document.getElementById(id)};
}

test('Admin form saves privately, previews, publishes, and invalidates preview on edits',async()=>{
 const {dom,w,backend,$}=setup();
 try{
  await waitFor(()=>$('login-panel').hidden===false);
  $('password').value='test-password';$('login-form').dispatchEvent(new w.Event('submit',{cancelable:true}));
  await waitFor(()=>$('workspace').hidden===false);
  $('add').click();const card=w.document.querySelector('.quote-editor');
  for(const [key,value]of Object.entries({label:'Test quote',rate:'125',source_name:'Test source'})){
   const input=card.querySelector(`[data-key="${key}"]`);input.value=value;input.dispatchEvent(new w.Event('input'));
  }
  card.querySelector('[data-key="source_checked"]').checked=true;
  $('save').click();await waitFor(()=>backend.draft_version===1);await pause();
  assert.equal(backend.published.revision,0);assert.equal(backend.draft.quotes[0].rate_micros,125000000);
  $('preview-button').click();await waitFor(()=>$('publish').disabled===false);
  assert.match($('preview-cards').textContent,/Test source/);
  $('publish').click();await waitFor(()=>backend.published.revision===1);await pause();
  assert.equal(backend.published.quotes.length,1);
  $('preview-button').click();await waitFor(()=>$('publish').disabled===false);
  $('notice').value='Edited after preview';$('notice').dispatchEvent(new w.Event('input'));
  assert.equal($('publish').disabled,true);
 }finally{dom.window.close();}
});

test('Admin preview renders source content as text, not executable markup',async()=>{
 const {dom,w,backend,$}=setup();
 try{
  $('password').value='test-password';$('login-form').dispatchEvent(new w.Event('submit',{cancelable:true}));await waitFor(()=>$('workspace').hidden===false);
  $('add').click();const card=w.document.querySelector('.quote-editor');
  card.querySelector('[data-key="rate"]').value='125';
  card.querySelector('[data-key="label"]').value='<img src=x onerror=alert(1)>';
  card.querySelector('[data-key="source_name"]').value='<script>bad()</script>';
  $('preview-button').click();await waitFor(()=>$('preview').hidden===false);
  assert.equal($('preview-cards').querySelector('img,script'),null);
  assert.match($('preview-cards').textContent,/<script>/);
  assert.equal(backend.published.revision,0);
 }finally{dom.window.close();}
});
