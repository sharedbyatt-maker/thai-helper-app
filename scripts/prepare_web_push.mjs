import {readFileSync,writeFileSync,existsSync} from 'node:fs';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
const root=resolve(process.argv[2]||'flutter_app/build/web');
const worker=resolve(root,'flutter_service_worker.js');
if(!existsSync(resolve(root,'bahtzay-push-sw.js')))throw Error('Push handler is missing from web build');
const marker='importScripts("bahtzay-push-sw.js");';
let source=existsSync(worker)?readFileSync(worker,'utf8'):'';
// Recent Flutter releases emit a retirement worker which unregisters itself.
// Replace that worker; appending a push handler would still lose subscriptions.
// Older asset-caching workers remain intact.
if(/registration\s*\.\s*unregister\s*\(/.test(source))source='';
if(!source.includes(marker))source+='\n// Phone notifications share the same worker and scope as Flutter.\n'+marker+'\n';
// Asset URLs are versioned without changing the app identity or worker scope.
const brand='// Web identity: bahtzay-v2';
if(!source.includes(brand))source+='\n'+brand+'\n';
// A new deployment must not reuse a ten-minute-old main bundle from Pages.
// Version the loader and entry point without clearing any browser storage.
const main=resolve(root,'main.dart.js'),bootstrap=resolve(root,'flutter_bootstrap.js'),index=resolve(root,'index.html');
if([main,bootstrap,index].every(existsSync)){
 const revision=createHash('sha256').update(readFileSync(main)).digest('hex').slice(0,16);
 const loader=readFileSync(bootstrap,'utf8');
 const mainPath=/"mainJsPath"\s*:\s*"main\.dart\.js(?:\?v=[a-f0-9]+)?"/g;
 if(!mainPath.test(loader))throw Error('Flutter entry point was not found; refusing to ship an unversioned build');
 writeFileSync(bootstrap,loader.replace(mainPath,`"mainJsPath":"main.dart.js?v=${revision}"`));
 const html=readFileSync(index,'utf8');
 const loaderTag=/src="flutter_bootstrap\.js(?:\?v=[a-f0-9]+)?"/g;
 if(!loaderTag.test(html))throw Error('Flutter bootstrap script was not found in index.html');
 writeFileSync(index,html.replace(loaderTag,`src="flutter_bootstrap.js?v=${revision}"`));
 source=source.replace(/\n+\/\/ Web build: [a-f0-9]+\n/g,'\n')+`\n// Web build: ${revision}\n`;
}
writeFileSync(worker,source);
console.log('Phone push handler installed in the app service worker.');
