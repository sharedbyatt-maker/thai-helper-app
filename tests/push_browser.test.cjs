const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const {webcrypto}=require('node:crypto');
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
