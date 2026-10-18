const enc=new TextEncoder();
const hex=bytes=>Array.from(bytes,b=>b.toString(16).padStart(2,'0')).join('');
const unhex=s=>Uint8Array.from(s.match(/../g)||[],b=>parseInt(b,16));
async function aesKey(secret) {
 if(!/^[a-f0-9]{64}$/.test(secret||'')) throw new Error('Telegram encryption unavailable');
 return crypto.subtle.importKey('raw',unhex(secret),'AES-GCM',false,['encrypt','decrypt']);
}
export async function seal(value, secret) {
 const iv=crypto.getRandomValues(new Uint8Array(12));
 const data=await crypto.subtle.encrypt({name:'AES-GCM',iv,additionalData:enc.encode('bahtzay.telegram.v1')},await aesKey(secret),enc.encode(JSON.stringify(value)));
 return hex(iv)+'.'+hex(new Uint8Array(data));
}
export async function unseal(value, secret) {
 const [iv,data]=value.split('.');
 return JSON.parse(new TextDecoder().decode(await crypto.subtle.decrypt({name:'AES-GCM',iv:unhex(iv),additionalData:enc.encode('bahtzay.telegram.v1')},await aesKey(secret),unhex(data))));
}
