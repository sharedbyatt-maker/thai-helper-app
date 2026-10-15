import {test} from 'node:test';
import assert from 'node:assert/strict';
import {publicHistory} from '../lib/history.mjs';
const now=Date.parse('2026-10-15T12:00:00Z');
const quote={id:'a',direction:'thb_mmk',source_name:'Source A',source_url:'https://example.com',payout_method:'bank',observed_at:'2026-10-14T18:00:00Z',rate_micros:125000000};
const row=(id,quotes)=>({id,payload:JSON.stringify({quotes})});
test('Bangkok dates, source and direction separation, latest daily publication, no filled gaps',()=>{
 const result=publicHistory([row(3,[{...quote,rate_micros:126000000},{...quote,direction:'mmk_thb',rate_micros:127000000}]),row(2,[quote,{...quote,source_name:'Source B',rate_micros:128000000}]),row(1,[{...quote,observed_at:'2026-10-10T12:00:00Z'},{...quote,observed_at:'2026-08-01T00:00:00Z'},{...quote,observed_at:'2026-10-16T00:00:00Z'}])],now);
 assert.equal(result.points.length,4);
 assert.equal(result.points.filter(p=>p.day==='2026-10-15').length,3);
 assert.equal(result.points.find(p=>p.day==='2026-10-15'&&p.direction==='thb_mmk'&&p.source_name==='Source A').rate_micros,126000000);
 assert.equal(result.points[0].day,'2026-10-10');
 assert.equal(result.timezone,'Asia/Bangkok');
 assert.deepEqual(publicHistory([],now).points,[]);
});
