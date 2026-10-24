import {readFileSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
const root=resolve(process.argv[2]);
const url=new URL(process.argv[3]);
if(url.protocol!=='https:'||url.username||url.password||url.search||url.hash)throw Error('A plain HTTPS app URL is required');
if(!url.pathname.endsWith('/'))url.pathname+='/';
const file=resolve(root,'index.html');
const html=readFileSync(file,'utf8');
const escaped=value=>value.replaceAll('&','&amp;').replaceAll('"','&quot;').replaceAll('<','&lt;');
writeFileSync(file,html
 .replace(/(<meta property="og:url" content=")[^"]*(">)/,`$1${escaped(url.href)}$2`)
 .replace(/(<meta property="og:image" content=")[^"]*(">)/,`$1${escaped(new URL('og-image-bahtzay-v2.png',url).href)}$2`));
