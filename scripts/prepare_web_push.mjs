import {readFileSync,writeFileSync,existsSync} from 'node:fs';
import {resolve} from 'node:path';
const root=resolve(process.argv[2]||'flutter_app/build/web');
const worker=resolve(root,'flutter_service_worker.js');
if(!existsSync(resolve(root,'bahtzay-push-sw.js')))throw Error('Push handler is missing from web build');
const marker='importScripts("bahtzay-push-sw.js");';
let source=existsSync(worker)?readFileSync(worker,'utf8'):'';
// Recent Flutter releases emit a retirement worker which unregisters itself.
// Replace that worker; appending a push handler would still lose subscriptions.
// Older asset-caching workers remain intact.
if(/registration\s*\.\s*unregister\s*\(/.test(source))source='';
if(!source.includes(marker))writeFileSync(worker,source+'\n// Phone notifications share the same worker and scope as Flutter.\n'+marker+'\n');
console.log('Phone push handler installed in the app service worker.');
