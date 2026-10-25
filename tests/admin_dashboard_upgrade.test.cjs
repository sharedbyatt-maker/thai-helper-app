const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {JSDOM}=require('jsdom');
const root=path.resolve(__dirname,'../hosted_backend/public/admin');
const wait=()=>new Promise(r=>setTimeout(r,30));
function setup(){
 const dom=new JSDOM(fs.readFileSync(path.join(root,'index.html'),'utf8'),{url:'https://rates.example/admin/index.html',runScripts:'outside-only',pretendToBeVisual:true});
 const w=dom.window;w.structuredClone=structuredClone;w.confirm=()=>true;
 const q={id:'daily',label:'Daily',direction:'thb_mmk',rate_micros:Math.round(100000000000/740),observed_at:'2026-10-24T06:57:00Z',valid_until:'2026-10-25T06:57:00Z',source_checked:true,source_name:'Reference',source_url:'',flat_fee_minor:0,fee_bps:0};
 const state={draft:{notice:'',quotes:[q]},draft_version:0,published:{quotes:[q],revision:25,published_at:q.observed_at},history:Array.from({length:25},(_,i)=>({id:25-i,published_at:new Date(Date.UTC(2026,9,24-i,6,57)).toISOString(),quotes:[{...q,rate_micros:Math.round(100000000000/(740+i))}]})),trash:[]};
 const writes=[];let ads={config:{enabled:false,platforms:{web:false,android:false,ios:false},formats:{banner:false,native:false,interstitial:false,rewarded:false},placements:{home:false,history:false,calculator:false,budget:false},sponsors_enabled:false,sponsors:[{id:'s1',name:'Shop',label:'Sponsored',placements:['home'],language:'both',priority:0,enabled:false,image_url:'https://example.com/a.png',destination_url:'https://example.com',start_at:'2026-10-25T00:30:00Z',end_at:null}]},version:0};
 w.fetch=async(url,options={})=>{
  const endpoint=url.split('/').pop();let data;
  if(options.method&&options.method!=='GET'){writes.push({url,body:JSON.parse(options.body)});if(endpoint==='ads')ads={...ads,config:JSON.parse(options.body).config,version:1};}
  if(endpoint==='state')data=state;else if(endpoint==='ads')data=ads;else if(endpoint==='push-history')data={events:[]};else throw Error('Unexpected request '+url);
  return {ok:true,status:200,json:async()=>structuredClone(data)};
 };
 w.eval(['runtime.js','app.js','app-release.js','control-center.js'].map(f=>fs.readFileSync(path.join(root,f),'utf8')).join('\n'));
 return {dom,w,state,writes,$:id=>w.document.getElementById(id)};
}
test('Dark mode persists without publishing and overview charts use real directional history',async()=>{
 const {dom,w,$,writes}=setup();try{await wait();
 $('admin-theme').value='dark';$('admin-theme').dispatchEvent(new w.Event('change'));
 assert.equal(w.document.documentElement.dataset.theme,'dark');assert.equal(w.localStorage.getItem('bahtzay-admin-theme'),'dark');
 assert.equal($('overview-metrics').children.length,4);assert.equal($('overview-rate-chart').querySelectorAll('circle').length,14);
 assert.match($('overview-rate-chart').textContent,/740.00/);assert.equal($('overview-activity').children.length,7);
 $('overview-direction').value='mmk_thb';$('overview-direction').dispatchEvent(new w.Event('change'));
 assert.equal($('overview-rate-chart').querySelector('svg'),null);assert.match($('overview-rate-chart').textContent,/မရှိသေး/);
 assert.equal(writes.length,0);
 }finally{dom.window.close();}
});
test('History pagination and filtering bound visible rows without losing prior revisions',async()=>{
 const {dom,w,$,writes}=setup();try{await wait();w.bahtzayAdminNavigate('history');
 assert.equal($('history').querySelectorAll('.publication').length,8);assert.match($('history').textContent,/#25/);
 $('history').querySelector('.history-pagination button:last-child').click();assert.match($('history').textContent,/#17/);assert.equal($('history').querySelectorAll('.publication').length,8);
 $('history-search').value='765';$('history-search').dispatchEvent(new w.Event('input'));assert.equal($('history').querySelectorAll('.publication').length,0);
 $('history-search').value='764';$('history-search').dispatchEvent(new w.Event('input'));assert.equal($('history').querySelectorAll('.publication').length,1);assert.match($('history').textContent,/#1/);
 $('history-direction').value='mmk_thb';$('history-direction').dispatchEvent(new w.Event('change'));assert.equal($('history').querySelectorAll('.publication').length,0);assert.equal(writes.length,0);
 }finally{dom.window.close();}
});
test('Notification sections do not send and Bangkok sponsor edits round-trip independently of device timezone',async()=>{
 const {dom,w,$,writes}=setup();try{await wait();w.bahtzayAdminNavigate('notifications');
 assert.equal($('notification-compose').hidden,false);assert.equal($('notification-delivery').hidden,true);
 w.document.querySelector('[data-notification-tab=delivery]').click();assert.equal($('notification-delivery').hidden,false);assert.equal($('notification-compose').hidden,true);
 assert.equal(writes.length,0);w.bahtzayAdminNavigate('advertising');await wait();
 const start=w.document.querySelector('.control-sponsor-grid input[type=datetime-local]');assert.equal(start.value,'2026-10-25T07:30');start.value='2026-10-26T08:30';start.dispatchEvent(new w.Event('input',{bubbles:true}));
 $('ad-config-form').dispatchEvent(new w.Event('submit',{bubbles:true,cancelable:true}));await wait();assert.equal(writes.length,1);assert.equal(writes[0].body.config.sponsors[0].start_at,'2026-10-26T01:30:00.000Z');
 assert.equal($('ad-config-save').getAttribute('form'),'ad-config-form');assert.equal(w.document.querySelector('.ad-advanced').open,false);
 }finally{dom.window.close();}
});
