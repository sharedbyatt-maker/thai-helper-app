// Only immutable published revisions are accepted; drafts never enter this path.
export function publicHistory(rows, now=Date.now()) {
 const today=new Date(now+7*3600000).toISOString().slice(0,10);
 const first=new Date(Date.parse(today+'T00:00:00Z')-29*86400000).toISOString().slice(0,10);
 const daily=new Map();
 // Caller orders revisions newest first: last published observation per source/day wins.
 for(const row of rows){
  const sheet=JSON.parse(row.payload);
  for(const q of sheet.quotes??[]){
   const observed=Date.parse(q.observed_at);
   if(!Number.isFinite(observed)||observed>now+300000)continue;
   const day=new Date(observed+7*3600000).toISOString().slice(0,10);
   if(day<first||day>today)continue;
   const identity=[q.id,q.direction,q.source_name,q.source_url,q.payout_method];
   const key=JSON.stringify([day,...identity]);
   if(daily.has(key))continue;
   daily.set(key,{day,quote_id:q.id,direction:q.direction,source_name:q.source_name,source_url:q.source_url,payout_method:q.payout_method,rate_micros:q.rate_micros});
  }
 }
 return {schema_version:1,timezone:'Asia/Bangkok',from:first,to:today,points:[...daily.values()].sort((a,b)=>a.day.localeCompare(b.day))};
}
