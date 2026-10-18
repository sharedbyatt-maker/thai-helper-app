// Imported by the app service worker; retains Flutter asset caching.
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',event=>event.waitUntil(self.clients.claim()));
self.addEventListener('push',event=>{
 event.waitUntil((async()=>{
  let data;try{data=event.data?.json()||{};}catch{data={};}
  const expired=data.expires_at&&data.expires_at<=Date.now();
  const title=typeof data.title==='string'?data.title:'ဘတ်ဈေး · အသိပေးချက်';
  const body=expired?'နောက်ဆုံးဈေးနဲ့ ကြေညာချက်ကို App မှာ ပြန်စစ်ပေးပါ။':typeof data.body==='string'?data.body:'App မှာ အချက်အလက်အသစ် ကြည့်နိုင်ပြီ။';
  // Every received push displays a notification, including a safe expired fallback.
  await self.registration.showNotification(title,{body,tag:typeof data.tag==='string'?data.tag:'bahtzay-news',icon:new URL('icons/Icon-192-bahtzay-v1.png',self.registration.scope).href,badge:new URL('icons/Icon-192-bahtzay-v1.png',self.registration.scope).href,data:{url:self.registration.scope},renotify:true});
 })());
});
self.addEventListener('notificationclick',event=>{
 event.notification.close();
 event.waitUntil((async()=>{
  const target=self.registration.scope;
  const windows=await self.clients.matchAll({type:'window',includeUncontrolled:true});
  for(const client of windows){if(client.url.startsWith(target)&&'focus' in client){await client.focus();if('navigate' in client)await client.navigate(target);return;}}
  await self.clients.openWindow(target);
 })());
});
