const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const {webcrypto}=require('node:crypto');
const {execFileSync}=require('node:child_process');
const os=require('node:os');
const path=require('node:path');
test('Each changed web build uses fresh loader and main URLs without changing app scope',()=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'bahtzay-release-'));
 try{
  fs.copyFileSync('flutter_app/web/bahtzay-push-sw.js',path.join(root,'bahtzay-push-sw.js'));
  fs.writeFileSync(path.join(root,'main.dart.js'),'first build');
  fs.writeFileSync(path.join(root,'flutter_bootstrap.js'),'_flutter.buildConfig={"builds":[{"mainJsPath":"main.dart.js"}]}');
  fs.writeFileSync(path.join(root,'index.html'),'<base href="/thai-helper-app/"><script src="flutter_bootstrap.js" async></script>');
  const run=()=>execFileSync(process.execPath,['scripts/prepare_web_push.mjs',root]);
  run();
  const html=fs.readFileSync(path.join(root,'index.html'),'utf8'),loader=fs.readFileSync(path.join(root,'flutter_bootstrap.js'),'utf8');
  const revision=html.match(/flutter_bootstrap.js\?v=([a-f0-9]{16})/)[1];
  assert.ok(loader.includes(`main.dart.js?v=${revision}`));
  assert.ok(html.includes('<base href="/thai-helper-app/">'));
  const worker=fs.readFileSync(path.join(root,'flutter_service_worker.js'),'utf8');
  run();assert.equal(fs.readFileSync(path.join(root,'flutter_service_worker.js'),'utf8'),worker);
  fs.writeFileSync(path.join(root,'main.dart.js'),'second build');run();
  assert.ok(!fs.readFileSync(path.join(root,'index.html'),'utf8').includes(revision));
  assert.ok(!fs.readFileSync(path.join(root,'flutter_bootstrap.js'),'utf8').includes(revision));
 }finally{fs.rmSync(root,{recursive:true,force:true});}
});
test('Build replaces Flutter retirement workers and preserves older caching workers',()=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'bahtzay-worker-'));
 try{
  fs.copyFileSync('flutter_app/web/bahtzay-push-sw.js',path.join(root,'bahtzay-push-sw.js'));
  const worker=path.join(root,'flutter_service_worker.js');
  for(const input of ["self.addEventListener('activate',e=>e.waitUntil(self.registration.unregister()));",'// existing asset cache\n']){
   fs.writeFileSync(worker,input);
   execFileSync(process.execPath,['scripts/prepare_web_push.mjs',root]);
   const output=fs.readFileSync(worker,'utf8');
   assert.ok(!output.includes('unregister'));
   assert.equal(output.includes('existing asset cache'),input.includes('existing asset cache'));
   const handlers={},calls=[];
   const self={addEventListener:(kind,fn)=>handlers[kind]=fn,skipWaiting:()=>calls.push('install'),clients:{claim:async()=>calls.push('claim')},registration:{unregister:()=>assert.fail('Push registration must survive activation')}};
   vm.runInNewContext(output,{self,URL,Date,importScripts:file=>vm.runInNewContext(fs.readFileSync(path.join(root,file),'utf8'),{self,URL,Date})});
   handlers.install();handlers.activate({waitUntil:()=>{}});assert.deepEqual(calls,['install','claim']);
   execFileSync(process.execPath,['scripts/prepare_web_push.mjs',root]);
   assert.equal(fs.readFileSync(worker,'utf8'),output);
  }
 }finally{fs.rmSync(root,{recursive:true,force:true});}
});
function client({ios=false,standalone=false,permission='default',granted='granted',subscribed=false}={}){
 const storage=new Map(),calls=[],reg={active:{},pushManager:{getSubscription:async()=>subscribed?sub:null,subscribe:async()=>{subscribed=true;return sub;}}};
 const sub={toJSON:()=>({endpoint:'https://fcm.googleapis.com/fcm/send/self',keys:{p256dh:'a',auth:'b'}}),unsubscribe:async()=>{subscribed=false;calls.push('browser-unsubscribe');return true;}};
 const context={URL,Uint8Array,Promise,JSON,Error,AbortController,setTimeout,clearTimeout,atob,crypto:webcrypto,
 document:{baseURI:'https://sharedbyatt-maker.github.io/thai-helper-app/'},location:{origin:'https://sharedbyatt-maker.github.io'},
 navigator:{userAgent:ios?'iPhone':'Android Chrome',platform:ios?'iPhone':'Linux',maxTouchPoints:1,serviceWorker:{register:async(url,options)=>{calls.push(['register',String(url),options.scope]);return reg;},getRegistration:async()=>reg}},
 localStorage:{getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,v)},
 Notification:{permission,requestPermission:()=>{calls.push('permission');context.Notification.permission=granted;return Promise.resolve(granted);}},
 fetch:async(url,options)=>{const method=url.split('/').pop();calls.push(method);if(method==='config')return {ok:true,json:async()=>({available:true,public_key:Buffer.alloc(65,4).toString('base64url')})};if(method==='subscribe')return {ok:true,json:async()=>({id:'device-id',active:true})};if(method==='status')return {ok:true,json:async()=>({active:subscribed})};return {ok:true,json:async()=>({ok:true})};},
 };
 context.window=context;context.isSecureContext=true;context.PushManager=function(){};context.matchMedia=()=>({matches:standalone});
 vm.runInNewContext(fs.readFileSync('flutter_app/web/push-client.js','utf8'),context);
 return {context,calls,storage,action:async action=>JSON.parse(await context.bahtzayPush(action,'https://rates.example'))};
}
test('The phone client never requests permission on load; permission is requested synchronously only after explicit enable',async()=>{
 const f=client();assert.deepEqual(f.calls,[]);await f.action('status');assert.ok(!f.calls.includes('permission'));
 const pending=f.action('enable');assert.equal(f.calls[0],'permission');const enabled=await pending;assert.equal(enabled.active,true);assert.ok(f.calls.includes('subscribe'));assert.match(f.calls.find(x=>Array.isArray(x))[1],/flutter_service_worker.js$/);
 await f.action('test');assert.ok(f.calls.includes('test'));const stopped=await f.action('disable');assert.equal(stopped.active,false);assert.ok(f.calls.includes('unsubscribe'));assert.ok(f.calls.includes('browser-unsubscribe'));
});
test('iPhone Safari explains Home Screen installation without prompting; denied permission never subscribes',async()=>{
 const safari=client({ios:true});const info=await safari.action('enable');assert.equal(info.needs_home_screen,true);assert.ok(!safari.calls.includes('permission'));assert.ok(!safari.calls.includes('subscribe'));
 const denied=client({granted:'denied'});const result=await denied.action('enable');assert.equal(result.active,false);assert.match(result.error,/ခွင့်မပြု/);assert.ok(!denied.calls.includes('subscribe'));
 const installed=client({ios:true,standalone:true});assert.equal((await installed.action('enable')).active,true);
});
test('Push worker displays a notification even for expired/empty payloads and only opens its own app scope',async()=>{
 const handlers={},notifications=[],opened=[],scope='https://sharedbyatt-maker.github.io/thai-helper-app/';
 const self={addEventListener:(kind,fn)=>handlers[kind]=fn,skipWaiting:()=>{},registration:{scope,showNotification:async(...args)=>notifications.push(args)},clients:{claim:async()=>{},matchAll:async()=>[],openWindow:async url=>opened.push(url)}};
 vm.runInNewContext(fs.readFileSync('flutter_app/web/bahtzay-push-sw.js','utf8'),{self,URL,Date});
 let pending;handlers.push({data:{json:()=>({title:'ဈေး',body:'old price',expires_at:1,url:'https://evil.example/'})},waitUntil:p=>pending=p});await pending;assert.equal(notifications.length,1);assert.ok(!notifications[0][1].body.includes('old price'));
 handlers.notificationclick({notification:{close:()=>{},data:{url:'https://evil.example/'}},waitUntil:p=>pending=p});await pending;assert.deepEqual(opened,[scope]);
 handlers.push({data:null,waitUntil:p=>pending=p});await pending;assert.equal(notifications.length,2);
});

test('Notification clicks allow only known tabs within the exact app path, including already-open windows',async()=>{
 const handlers={},scope='https://sharedbyatt-maker.github.io/thai-helper-app/',navigated=[],opened=[];
 const self={registration:{scope},addEventListener:(k,fn)=>handlers[k]=fn,clients:{matchAll:async()=>[{url:scope+'?old=1',focus:async()=>{},navigate:async url=>navigated.push(url)}],openWindow:async url=>opened.push(url)}};
 vm.runInNewContext(fs.readFileSync('flutter_app/web/bahtzay-push-sw.js','utf8'),{self,URL,Date});
 for(const [url,expected] of [[scope+'?tab=wallet',scope+'?tab=wallet'],[scope+'other?tab=wallet',scope],['https://evil.example/?tab=wallet',scope],[scope+'?tab=unknown',scope]]){
 let pending;handlers.notificationclick({notification:{data:{url},close(){}},waitUntil:p=>pending=p});await pending;assert.equal(navigated.at(-1),expected);
 }
 assert.equal(opened.length,0);
});
