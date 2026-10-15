export class Invalid extends Error {}
const bad = message => { throw new Invalid(message); };
const text = (o,k,n,required=false) => {
 const s=o[k]??'';
 if(typeof s!=='string'||s.trim().length>n||(required&&!s.trim()))bad(k+': စာသားကို ပြန်စစ်ပါ');
 return s.trim();
};
function date(value) {
 if(typeof value!=='string'||!/(?:Z|[+-]\d\d:\d\d)$/.test(value)||!Number.isFinite(Date.parse(value)))bad('Timezone ပါသော အချိန် လိုပါသည်');
 return Date.parse(value);
}
export function validate(value, now=Date.now()) {
 if(!value||typeof value!=='object'||!Array.isArray(value.quotes)||value.quotes.length>30)bad('နှုန်း အများဆုံး ၃၀ ခုသာ ထည့်နိုင်သည်');
 const ids=new Set();
 return {notice:text(value,'notice',500),quotes:value.quotes.map(item=>{
  if(!item||typeof item!=='object')bad('နှုန်းတစ်ခုချင်း object လိုပါသည်');
  const q={};
  for(const [k,n,r] of [['id',80,true],['label',100,true],['source_name',150,true],['source_url',500,false],['payout_method',100,true],['note',500,false]])q[k]=text(item,k,n,r);
  if(ids.has(q.id))bad('နှုန်း ID ထပ်နေပါသည်');ids.add(q.id);
  if(!['thb_mmk','mmk_thb'].includes(item.direction))bad('ဦးတည်ချက်ကို ရွေးပါ');q.direction=item.direction;
  for(const [k,min,max]of [['rate_micros',1,1e12],['flat_fee_minor',0,1e11],['fee_bps',0,9999]]){
   const v=item[k]??0;if(!Number.isSafeInteger(v)||v<min||v>max)bad(k+': ပမာဏ မမှန်ပါ');q[k]=v;
  }
  const observed=date(item.observed_at), expires=date(item.valid_until);
  if(observed>now+300000||expires<=observed||expires>observed+7*86400000)bad('စစ်ချိန် / သက်တမ်းကို ပြန်စစ်ပါ။ အများဆုံး ၇ ရက်သာ။');
  q.observed_at=new Date(observed).toISOString();q.valid_until=new Date(expires).toISOString();
  if(q.source_url){let u;try{u=new URL(q.source_url);}catch{bad('Source link မမှန်ပါ');}if(!['https:','http:'].includes(u.protocol)||u.username||u.password)bad('http/https source link လိုပါသည်');}
  if(item.source_checked!==true)bad('Source စစ်ပြီးကြောင်း အမှန်ခြစ်ပေးပါ');q.source_checked=true;
  return q;
 })};
}
