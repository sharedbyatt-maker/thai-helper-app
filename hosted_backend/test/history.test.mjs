import {test} from 'node:test';
import assert from 'node:assert/strict';
import {publicHistory} from '../lib/history.mjs';
const now=Date.parse('2026-10-15T12:00:00Z');
const quote={id:'a',direction:'thb_mmk',source_name:'Source A',source_url:'https://example.com',payout_method:'bank',observed_at:'2026-10-14T18:00:00Z',rate_micros:125000000};
const row=(id,quotes)=>({id,payload:JSON.stringify({quotes})});
test('Bangkok dates, source and direction separation, latest daily publication, no filled gaps',()=>{
 const result=publicHistory([row(3,[{...quote,rate_micros:126000000},{...quote,direction:'mmk_thb',rate_micros:127000000}]),row(2,[{...quote,source_url:"https://example.com/older-post"},{...quote,source_name:'Source B',rate_micros:128000000}]),row(1,[{...quote,observed_at:'2026-10-10T12:00:00Z'},{...quote,observed_at:'2026-08-01T00:00:00Z'},{...quote,observed_at:'2026-10-16T00:00:00Z'}])],now);
 assert.equal(result.points.length,4);
 assert.equal(result.points.filter(p=>p.day==='2026-10-15').length,3);
 assert.equal(result.points.find(p=>p.day==='2026-10-15'&&p.direction==='thb_mmk'&&p.source_name==='Source A').rate_micros,126000000);
 assert.equal(result.points[0].day,'2026-10-10');
 assert.equal(result.timezone,'Asia/Bangkok');
 assert.deepEqual(publicHistory([],now).points,[]);
});
test('real intraday observations survive daily aggregation and carried unchanged quotes are deduplicated',()=>{
 const first={...quote,observed_at:'2026-10-15T02:00:00Z'},second={...quote,observed_at:'2026-10-15T03:30:00Z',rate_micros:126000000};
 const result=publicHistory([row(4,[second]),row(3,[second,{...first,direction:'mmk_thb'}]),row(2,[first]),row(1,[{...first,source_name:'Old label',observed_at:'2026-10-15T01:00:00Z'}])],now);
 assert.equal(result.points.filter(p=>p.direction==='thb_mmk'&&p.source_name==='Source A').length,1);
 const observed=result.observations.filter(p=>p.direction==='thb_mmk');assert.equal(observed.length,3);
 assert.deepEqual(observed.map(p=>p.observed_at),['2026-10-15T01:00:00.000Z','2026-10-15T02:00:00.000Z','2026-10-15T03:30:00.000Z']);
 assert.equal(observed.at(-1).revision,4);assert.equal(observed.at(-1).rate_micros,126000000);
 assert.equal(publicHistory([],now).observations.length,0);
});
