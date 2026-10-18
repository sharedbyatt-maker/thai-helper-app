'use strict';
let releaseState,releaseEditing=false;
const releaseBlank=()=>({enabled:false,version:'',build:0,url:'',notes:''});
function renderAppRelease(value){
 if(releaseEditing)return;
 releaseState=value||{release:{package_id:'',apk:releaseBlank(),play:releaseBlank()},release_version:0};
 $('release-package').value=releaseState.release.package_id;
 $('release-package').readOnly=releaseState.release.package_locked===true;
 showReleaseChannel();
}
function showReleaseChannel(){
 const channel=$('release-channel').value,v=releaseState?.release[channel]||releaseBlank();
 $('release-enabled').checked=v.enabled;$('release-version').value=v.version;$('release-build').value=v.build||'';$('release-url').value=v.url;$('release-notes').value=v.notes;
 $('release-url').placeholder=channel==='apk'?'https://github.com/owner/repo/releases/download/v1.0.1/bahtzay.apk':'https://play.google.com/store/apps/details?id=com.yourname.bahtzay';
 $('release-state').textContent=v.enabled?`User များကို ပြနေတယ် · v${v.version} (${v.build})`:'ဒီ channel မှာ update မဖြန့်ရသေးဘူး။';
}
$('release-channel').addEventListener('change',()=>{if(releaseEditing&&!confirm('ဒီ channel မှာ မသိမ်းရသေးတာ ပျောက်မယ်။ ပြောင်းမလား?')){$('release-channel').value=$('release-channel').value==='apk'?'play':'apk';return;}releaseEditing=false;showReleaseChannel();});
for(const id of ['release-package','release-enabled','release-version','release-build','release-url','release-notes'])$(id).addEventListener('input',()=>releaseEditing=true);
$('release-reload').addEventListener('click',()=>action(async()=>{if(releaseEditing&&!confirm('မသိမ်းရသေးတာ ပျောက်မယ်။ ပြန်ယူမလား?'))return;const value=await api('app-release');releaseEditing=false;renderAppRelease(value);message('App update စာရင်း ပြန်ယူပြီးပြီ။');}));
$('release-save').addEventListener('click',()=>action(async()=>{
 const channel=$('release-channel').value;
 const release=JSON.parse(JSON.stringify(releaseState.release));
 release.package_id=$('release-package').value.trim();
 release[channel]={enabled:$('release-enabled').checked,version:$('release-version').value.trim(),build:Number($('release-build').value||0),url:$('release-url').value.trim(),notes:$('release-notes').value.trim()};
 const v=release[channel];if(v.enabled&&(!release.package_id||!v.version||!v.build||!v.url))throw new Error('App ID၊ version၊ build နဲ့ download link အစစ်ကို ဖြည့်ပေးပါ။');
 if(!confirm(v.enabled?`${channel==='apk'?'APK':'Play Store'} update ကို စစ်ပေးပါ\n\nv${v.version} · Build ${v.build}\n${release.package_id}\n${v.url}\n\n${v.notes}\n\nLink နဲ့ signing key ကို စစ်ပြီး၊ ဒီ version ကို တကယ် download လုပ်လို့ရမှ အတည်ပြုပါ။`:'ဒီ channel ရဲ့ update အသိပေးမှုကို ပိတ်မလား?'))return;
 const value=await api('app-release','PUT',{release,expected_release_version:releaseState.release_version});
 releaseEditing=false;renderAppRelease(value);message(v.enabled?'App update အသိပေးမှု သိမ်းပြီးပြီ။':'App update အသိပေးမှု ပိတ်ထားပြီ။');
}));
window.addEventListener('beforeunload',e=>{if(releaseEditing){e.preventDefault();e.returnValue='';}});
if(typeof state!=='undefined'&&state)renderAppRelease(state.app_release);
