import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';
const root=resolve(import.meta.dirname,'../hosted_backend/public/admin');
const path=resolve(root,'index.html');
let html=readFileSync(path,'utf8');
for(const file of ['runtime.js','app.js','app-release.js','telegram.js','control-center.js','style.css']){
 const version=createHash('sha256').update(readFileSync(resolve(root,file))).digest('hex').slice(0,16);
 html=html.replaceAll(new RegExp('/admin/'+file.replaceAll('.','\\.')+'(?:\\?v=[a-f0-9]+)?(?=["\\x27])','g'),'/admin/'+file+'?v='+version);
}
writeFileSync(path,html);
console.log('Admin script/style URLs stamped with their content hashes.');
