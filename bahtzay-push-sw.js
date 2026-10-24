// Imported by the app service worker; retains Flutter asset caching.
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',event=>event.waitUntil(self.clients.claim()));
function notificationTarget(raw){
 const root=self.registration.scope;
 try{const url=new URL(raw||root,root),base=new URL(root);if(url.origin!==base.origin||url.pathname!==base.pathname)return root;const tab=url.searchParams.get('tab');return ['rates','wallet','calculator','history'].includes(tab)?root+'?tab='+tab:root;}catch{return root;}
}
self.addEventListener('push',event=>{
 event.waitUntil((async()=>{
  let data;try{data=event.data?.json()||{};}catch{data={};}
  const expired=data.expires_at&&data.expires_at<=Date.now();
  const title=expired?'ဘတ်ဈေး · အသိပေးချက်':typeof data.title==='string'?data.title:'ဘတ်ဈေး · အသိပေးချက်';
  const body=expired?'နောက်ဆုံးဈေးနဲ့ ကြေညာချက်ကို App မှာ ပြန်စစ်ပေးပါ။':typeof data.body==='string'?data.body:'App မှာ အချက်အလက်အသစ် ကြည့်နိုင်ပြီ။';
  // Every received push displays a notification, including a safe expired fallback.
  await self.registration.showNotification(title,{body,tag:typeof data.tag==='string'?data.tag:'bahtzay-news',icon:new URL('icons/Icon-192-bahtzay-v2.png',self.registration.scope).href,badge:new URL('icons/Icon-192-bahtzay-v2.png',self.registration.scope).href,data:{url:notificationTarget(data.url)},renotify:false});
 })());
});
self.addEventListener('notificationclick',event=>{
 event.notification.close();
 event.waitUntil((async()=>{
  const target=notificationTarget(event.notification.data?.url);
  const windows=await self.clients.matchAll({type:'window',includeUncontrolled:true});
  for(const client of windows){if(new URL(client.url).origin===new URL(self.registration.scope).origin&&new URL(client.url).pathname===new URL(self.registration.scope).pathname&&'focus' in client){await client.focus();if('navigate' in client)await client.navigate(target);return;}}
  await self.clients.openWindow(target);
 })());
});
