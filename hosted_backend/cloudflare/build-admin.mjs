import { readdir, readFile, writeFile } from 'node:fs/promises';

const folder = new URL('../public/admin/', import.meta.url);
const types = { html: 'text/html', js: 'application/javascript', css: 'text/css' };
const assets = {};
for (const entry of await readdir(folder, { withFileTypes: true })) {
  const name = entry.name;
  const type = types[name.split('.').at(-1)];
  if (!entry.isFile() || !type) continue;
  let body = await readFile(new URL(name, folder), 'utf8');
  if (name === 'index.html') {
    body = body.replace('/signin-with-chatgpt?return_to=%2Fadmin%2Findex.html', '/admin/index.html')
      .replace('ChatGPT အကောင့်ဖြင့် ဝင်မယ်', 'Cloudflare Access ဖြင့် ဝင်မယ်')
      .replace('ဤ Site ကို ပိုင်ဆိုင်သော ChatGPT အကောင့်ဖြင့်သာ စီမံနိုင်ပါသည်။',
        'သတ်မှတ်ထားသော Admin အီးမေးလ်ဖြင့်သာ စီမံနိုင်ပါသည်။');
  } else if (name === 'app.js') {
    body = body.replace('/signout-with-chatgpt?return_to=%2Fadmin%2Findex.html', '/cdn-cgi/access/logout');
  }
  assets['/admin/' + name] = [type + '; charset=utf-8', body];
}
await writeFile(new URL('admin-assets.generated.mjs', import.meta.url),
  'export default ' + JSON.stringify(assets) + ';\n');
