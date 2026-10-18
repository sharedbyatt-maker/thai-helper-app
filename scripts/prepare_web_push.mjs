import {readFileSync,writeFileSync,existsSync} from 'node:fs';
import {resolve} from 'node:path';
const root=resolve(process.argv[2]||'flutter_app/build/web');
const worker=resolve(root,'flutter_service_worker.js');
if(!existsSync(resolve(root,'bahtzay-push-sw.js')))throw Error('Push handler is missing from web build');
const marker='importScripts("bahtzay-push-sw.js");';
const source=existsSync(worker)?readFileSync(worker,'utf8'):'';
if(!source.includes(marker))writeFileSync(worker,source+'\n// Phone notifications share the same worker and scope as Flutter.\n'+marker+'\n');
console.log('Phone push handler installed in the app service worker.');
