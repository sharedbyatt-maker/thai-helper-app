// RFC 8291 (aes128gcm) and RFC 8292 (VAPID), using Worker-native Web Crypto.
const enc=new TextEncoder();
export const encode64=bytes=>btoa(String.fromCharCode(...new Uint8Array(bytes))).replaceAll('+','-').replaceAll('/','_').replace(/=+$/,'');
export function decode64(value){if(typeof value!=='string'||!/^[-_A-Za-z0-9]+$/.test(value))throw new Error('Invalid base64url');return Uint8Array.from(atob(value.replaceAll('-','+').replaceAll('_','/')+'='.repeat((4-value.length%4)%4)),c=>c.charCodeAt(0));}
const join=(...chunks)=>{const out=new Uint8Array(chunks.reduce((n,c)=>n+c.length,0));let at=0;for(const c of chunks){out.set(c,at);at+=c.length;}return out;};
async function hkdf(input,salt,info,length){const key=await crypto.subtle.importKey('raw',input,'HKDF',false,['deriveBits']);return new Uint8Array(await crypto.subtle.deriveBits({name:'HKDF',hash:'SHA-256',salt,info},key,length*8));}
export async function vapidKeys(){const pair=await crypto.subtle.generateKey({name:'ECDSA',namedCurve:'P-256'},true,['sign','verify']);return {publicKey:encode64(await crypto.subtle.exportKey('raw',pair.publicKey)),privateKey:await crypto.subtle.exportKey('jwk',pair.privateKey)};}
export function validPushEndpoint(value){
 let url;try{url=new URL(value);}catch{return false;}
 const host=url.hostname;
 return value.length<=2048&&url.protocol==='https:'&&!url.username&&!url.password&&!url.port&&!url.hash&&url.pathname!=='/'&&
 (host==='fcm.googleapis.com'||host.endsWith('.push.apple.com')||host==='updates.push.services.mozilla.com'||host.endsWith('.notify.windows.com'));
}
export async function validatePushSubscription(sub){
 if(!sub||!validPushEndpoint(sub.endpoint))throw new Error('Unsupported push endpoint');
 const publicKey=decode64(sub.keys?.p256dh),auth=decode64(sub.keys?.auth);
 if(publicKey.length!==65||publicKey[0]!==4||auth.length!==16)throw new Error('Invalid subscription keys');
 await crypto.subtle.importKey('raw',publicKey,{name:'ECDH',namedCurve:'P-256'},false,[]);
 return {endpoint:sub.endpoint,keys:{p256dh:encode64(publicKey),auth:encode64(auth)}};
}
export async function webPushRequest(sub,payload,vapid,now=Date.now()){
 if(!validPushEndpoint(sub.endpoint))throw new Error('Unsupported push endpoint');
 const ua=decode64(sub.keys.p256dh),auth=decode64(sub.keys.auth);
 const pair=await crypto.subtle.generateKey({name:'ECDH',namedCurve:'P-256'},true,['deriveBits']);
 const server=new Uint8Array(await crypto.subtle.exportKey('raw',pair.publicKey));
 const peer=await crypto.subtle.importKey('raw',ua,{name:'ECDH',namedCurve:'P-256'},false,[]);
 const shared=new Uint8Array(await crypto.subtle.deriveBits({name:'ECDH',public:peer},pair.privateKey,256));
 const ikm=await hkdf(shared,auth,join(enc.encode('WebPush: info\0'),ua,server),32);
 const salt=crypto.getRandomValues(new Uint8Array(16));
 const key=await hkdf(ikm,salt,enc.encode('Content-Encoding: aes128gcm\0'),16);
 const nonce=await hkdf(ikm,salt,enc.encode('Content-Encoding: nonce\0'),12);
 const text=enc.encode(JSON.stringify(payload));if(text.length>3000)throw new Error('Push payload too large');
 const encrypted=new Uint8Array(await crypto.subtle.encrypt({name:'AES-GCM',iv:nonce},await crypto.subtle.importKey('raw',key,'AES-GCM',false,['encrypt']),join(text,new Uint8Array([2]))));
 const size=new Uint8Array(4);new DataView(size.buffer).setUint32(0,4096);
 const body=join(salt,size,new Uint8Array([65]),server,encrypted);
 const header=encode64(enc.encode(JSON.stringify({typ:'JWT',alg:'ES256'})));
 const claims=encode64(enc.encode(JSON.stringify({aud:new URL(sub.endpoint).origin,exp:Math.floor(now/1000)+3600,sub:'https://sharedbyatt-maker.github.io/thai-helper-app/'})));
 const signing=await crypto.subtle.importKey('jwk',vapid.privateKey,{name:'ECDSA',namedCurve:'P-256'},false,['sign']);
 const sig=await crypto.subtle.sign({name:'ECDSA',hash:'SHA-256'},signing,enc.encode(header+'.'+claims));
 return {method:'POST',headers:{Authorization:`vapid t=${header}.${claims}.${encode64(sig)}, k=${vapid.publicKey}`,TTL:String(payload.expires_at?Math.max(0,Math.min(86400,Math.floor((payload.expires_at-now)/1000))):86400),Urgency:'normal','Content-Type':'application/octet-stream','Content-Encoding':'aes128gcm'},body,redirect:'error',signal:AbortSignal.timeout(8000)};
}
