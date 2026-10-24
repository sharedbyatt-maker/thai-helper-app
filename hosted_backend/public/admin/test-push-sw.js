self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',e=>e.waitUntil(self.clients.claim()));
self.addEventListener('push',e=>e.waitUntil((async()=>{let data={};try{data=e.data.json();}catch{}await self.registration.showNotification('ဘတ်ဈေး 🔔',{body:data.expires_at>Date.now()?'ဒီ Admin စက်ဆီပဲ စမ်းပို့ထားပါတယ်။':'စမ်းသပ်စာ သက်တမ်းကုန်ပါပြီ။',tag:'bahtzay-owner-test'});})()));
self.addEventListener('notificationclick',e=>{e.notification.close();e.waitUntil(self.clients.openWindow('/admin/index.html'));});
