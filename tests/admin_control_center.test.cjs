const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {JSDOM}=require('jsdom');
const root=path.resolve(__dirname,'../hosted_backend/public/admin');
const source=fs.readFileSync(path.join(root,'control-center.js'),'utf8');
const html=fs.readFileSync(path.join(root,'index.html'),'utf8');
const config=()=>({
 enabled:false,platforms:{web:false,android:false,ios:false},
 formats:{banner:false,native:false,interstitial:false,rewarded:false},
 placements:{home:false,history:false,calculator:false,budget:false},
 sponsors_enabled:false,sponsors:[],
});
function setup(initial=config()){
 const dom=new JSDOM(html,{url:'https://rates.example/admin/index.html',runScripts:'outside-only'});
 const w=dom.window;
 w.structuredClone=structuredClone;
 w.confirm=()=>true;
 let version=0,settings=initial,calls=0;
 w.fetch=async(url,init={})=>{
   assert.match(String(url),/\/api\/admin\/ads(?:\/off)?$/);
   if(String(url).endsWith('/off')){settings.enabled=false;settings.sponsors_enabled=false;settings.platforms={web:false,android:false,ios:false};version++;}
   calls++;
   if(init.method==='PUT'){
      const data=JSON.parse(init.body);
      assert.equal(data.expected_version,version);
      version++;settings=data.config;
      return {ok:true,json:async()=>({ok:true,version,updated_at:new Date().toISOString()})};
   }
   return {ok:true,json:async()=>({config:structuredClone(settings),version,updated_at:'2026-10-18T00:00:00Z'})};
 };
 w.eval(fs.readFileSync(path.join(root,'runtime.js'),'utf8'));
 w.eval(source);
 const $=id=>w.document.getElementById(id);
 return {dom,w,$,getSettings:()=>settings,requests:()=>calls};
}
const settle=()=>new Promise(resolve=>setTimeout(resolve,20));
test('Admin reorganizes existing working tools into six responsive sections without dropping controls',()=>{
 const {dom,w,$}=setup();
 try{
   const nav=w.document.querySelectorAll('.control-link[data-page]');
   assert.equal(nav.length,6);
   assert.equal($('edit-panel').closest('[data-page]').dataset.page,'rates');
   assert.equal($('publish').closest('[data-page]').dataset.page,'rates');
   assert.equal($('history').closest('[data-page]').dataset.page,'history');
   assert.equal($('tg-status').closest('[data-page]').dataset.page,'notifications');
   assert.equal($('announcement-publish').closest('[data-page]').dataset.page,'notifications');
   assert.equal($('release-save').closest('[data-page]').dataset.page,'system');
   assert.equal($('control-overview').hidden,false);
   assert.equal($('control-overview').firstElementChild.tagName,'H2');
   w.bahtzayAdminNavigate('rates');
   assert.equal($('control-rates').hidden,false);
   assert.equal($('control-overview').hidden,true);
   assert.equal(w.document.querySelectorAll('[aria-current=page]').length,1);
 }finally{dom.window.close();}
});
test('Ads settings load default OFF, save platform switches, then emergency-disable all',async()=>{
 const {dom,w,$,getSettings}=setup();
 try{
   w.bahtzayAdminNavigate('advertising');
   await settle();
   $('ad-config-reload').click();
   await settle();
   assert.equal($('ad-config-form').elements.namedItem('enabled').checked,false);
   $('ad-config-form').elements.namedItem('enabled').checked=true;
   $('ad-config-form').elements.namedItem('platforms.android').checked=true;
   $('ad-config-form').dispatchEvent(new w.Event('submit',{bubbles:true,cancelable:true}));
   await settle();
   assert.equal(getSettings().enabled,true);
   assert.equal(getSettings().platforms.android,true);
   $('ad-emergency-off').click();await settle();
   assert.equal(getSettings().enabled,false);
   assert.equal(getSettings().platforms.android,false);
   assert.equal(getSettings().sponsors_enabled,false);
 }finally{dom.window.close();}
});

test('Multi-placement campaign edit preserves both slots; OFF ignores invalid unsaved creative',async()=>{
 const initial=config();initial.enabled=true;
 initial.sponsors=[{id:'s1',name:'Partner',label:'Sponsored',placements:['home','history'],language:'both',priority:0,enabled:true,image_url:'https://example.com/a.png',destination_url:'https://example.com',start_at:null,end_at:null}];
 const {dom,w,$,getSettings}=setup(initial);
 try{
  w.bahtzayAdminNavigate('advertising');await settle();
  const input=w.document.querySelector('.control-sponsor-grid input');input.value='Changed';input.dispatchEvent(new w.Event('input',{bubbles:true}));
  $('ad-config-form').dispatchEvent(new w.Event('submit',{bubbles:true,cancelable:true}));await settle();
  assert.deepEqual(getSettings().sponsors[0].placements,['home','history']);
  const image=w.document.querySelector('input[type=url]');image.value='broken';image.dispatchEvent(new w.Event('input',{bubbles:true}));
  $('ad-emergency-off').click();await settle();assert.equal(getSettings().enabled,false);
  assert.equal(getSettings().sponsors[0].image_url,'https://example.com/a.png');
 }finally{dom.window.close();}
});
test('Admin scripts and styles use current content hashes so an old cached asset cannot mask an upgrade',()=>{
 const {createHash}=require('node:crypto');
 for(const file of ['runtime.js','app.js','app-release.js','telegram.js','control-center.js','style.css']){
  const version=createHash('sha256').update(fs.readFileSync(path.join(root,file))).digest('hex').slice(0,16);
  assert.ok(html.includes('/admin/'+file+'?v='+version),file+' needs node scripts/stamp_admin_assets.mjs');
 }
});

test('Ad form changes are protected on close and a late reload cannot erase them',async()=>{
 const initial=config();initial.sponsors=[{id:'s1',name:'Partner',label:'Sponsored',placements:['home'],language:'both',priority:0,enabled:false,image_url:'https://example.com/a.png',destination_url:'https://example.com',start_at:null,end_at:null}];
 const {dom,w,$}=setup(initial);
 try{
  w.bahtzayAdminNavigate('advertising');await settle();
  let resolve;w.fetch=()=>new Promise(r=>resolve=r);$('ad-config-reload').click();
  const input=w.document.querySelector('.control-sponsor-grid input');input.value='Keep this name';input.dispatchEvent(new w.Event('input',{bubbles:true}));
  resolve({ok:true,status:200,json:async()=>({config:initial,version:0,updated_at:'2026-10-21T00:00:00Z'})});await settle();
  assert.equal(w.document.querySelector('.control-sponsor-grid input').value,'Keep this name');
  assert.equal(w.AdminRuntime.hasUnsaved(),true);
  const closing=new w.Event('beforeunload',{cancelable:true});w.dispatchEvent(closing);assert.equal(closing.defaultPrevented,true);
 }finally{dom.window.close();}
});
