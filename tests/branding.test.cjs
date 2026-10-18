const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const zlib=require('node:zlib');
const root=path.join(__dirname,'../flutter_app/web');
const read=p=>fs.readFileSync(path.join(root,p));
function png(file){
 const b=read(file);assert.equal(b.subarray(0,8).toString('hex'),'89504e470d0a1a0a');
 const width=b.readUInt32BE(16),height=b.readUInt32BE(20),depth=b[24],color=b[25];
 assert.equal(depth,8);assert.ok(color===6||color===2,'RGB/RGBA PNG');assert.equal(b[28],0,'non-interlaced');
 const channels=color===6?4:3,parts=[];
 for(let i=8;i<b.length;){const n=b.readUInt32BE(i),type=b.subarray(i+4,i+8).toString();if(type==='IDAT')parts.push(b.subarray(i+8,i+8+n));i+=12+n;}
 const raw=zlib.inflateSync(Buffer.concat(parts)),stride=width*channels,pixels=Buffer.alloc(stride*height);
 function paeth(a,b,c){const p=a+b-c,pa=Math.abs(p-a),pb=Math.abs(p-b),pc=Math.abs(p-c);return pa<=pb&&pa<=pc?a:pb<=pc?b:c;}
 for(let y=0;y<height;y++){const filter=raw[y*(stride+1)];assert.ok(filter<=4);for(let x=0;x<stride;x++){
  const i=y*stride+x,a=x>=channels?pixels[i-channels]:0,b=y?pixels[i-stride]:0,c=y&&x>=channels?pixels[i-stride-channels]:0;
  const predict=[0,a,b,Math.floor((a+b)/2),paeth(a,b,c)][filter];pixels[i]=(raw[y*(stride+1)+1+x]+predict)&255;
 }}
 return {width,height,channels,pixels};
}

test('Manifest sizes match every real versioned PNG without changing installed-app identity',()=>{
 const manifest=JSON.parse(read('manifest.json'));assert.equal(manifest.name,'ဘတ်ဈေး');assert.equal(manifest.short_name,'ဘတ်ဈေး');assert.equal(manifest.id,'.');assert.equal(manifest.scope,'.');assert.equal(manifest.start_url,'.');
 assert.equal(manifest.icons.length,4);
 for(const icon of manifest.icons){const p=png(icon.src);assert.equal(icon.sizes,`${p.width}x${p.height}`);assert.equal(p.width,p.height);assert.match(icon.src,/-bahtzay-v2\.png$/);assert.deepEqual(read(icon.src),read(icon.src.replace('-bahtzay-v2','')));assert.ok(['maskable','any'].includes(icon.purpose));}
});

test('Maskable foreground stays inside safe circle, backgrounds are opaque, small icon retains all three colors',()=>{
 for(const file of ['icons/Icon-maskable-192-bahtzay-v2.png','icons/Icon-maskable-512-bahtzay-v2.png','favicon-bahtzay-v2.png']){
  const p=png(file);let gold=0,cream=0,teal=0;
  for(let y=0;y<p.height;y++)for(let x=0;x<p.width;x++){
   const offset=(y*p.width+x)*p.channels,[r,g,b]=p.pixels.subarray(offset,offset+3),alpha=p.channels===4?p.pixels[offset+3]:255;
   const symbol=alpha>128&&r>170&&g>125;
   if(file.includes('maskable')){assert.equal(alpha,255);if(symbol)assert.ok((x+.5-p.width/2)**2+(y+.5-p.height/2)**2<(p.width*.4)**2,'foreground inside radius 40%');}
   if(symbol&&b<190)gold++;if(symbol&&r>235&&g>230&&b>200)cream++;if(alpha>128&&g>r*2&&b>r*2)teal++;
  }
  const count=p.width*p.height;assert.ok(gold/count>.04);assert.ok(cream/count>.01);assert.ok(teal/count>.3);
 }
});

test('Apple, favicon, social and in-app references use actual finished brand assets',()=>{
 const html=read('index.html').toString();assert.match(html,/<title>ဘတ်ဈေး<\/title>/);assert.match(html,/name="theme-color" content="#087F6D"/);
 for(const asset of ['icons/apple-touch-icon-bahtzay-v2.png','favicon-bahtzay-v2.png','og-image-bahtzay-v2.png']){assert.ok(html.includes(asset));assert.ok(read(asset).length>100);}
 assert.equal(png('icons/apple-touch-icon-bahtzay-v2.png').width,180);assert.equal(png('favicon-bahtzay-v2.png').width,32);
 const og=png('og-image-bahtzay-v2.png');assert.equal(og.width,1200);assert.equal(og.height,630);
 assert.deepEqual(read('icons/Icon-192.png'),fs.readFileSync(path.join(root,'../assets/branding/bahtzay-icon.png')));
 const svg=read('branding/bahtzay-icon.svg').toString();assert.ok(svg.includes('bahtzay-icon-1024.png'));assert.ok(!/<text[\s>]/.test(svg),'artwork never depends on device fonts');
 assert.match(read('bahtzay-push-sw.js').toString(),/Icon-192-bahtzay-v2\.png/);
});

// Pin the unchanged export from the exact owner-approved board.
test('Reference export remains byte-for-byte identical to the approved local commit',()=>{
 const {createHash}=require('node:crypto');
 assert.equal(createHash('sha256').update(read('branding/bahtzay-icon-1024.png')).digest('hex'),'41251af70aac9f4ce9a2cd79f1581c1b2cf991aea4fd93d52dae6762e267fd05');
 assert.deepEqual(read('icons/Icon-192.png'),fs.readFileSync(path.join(root,'../assets/branding/bahtzay-icon-bahtzay-v2.png')));
});
