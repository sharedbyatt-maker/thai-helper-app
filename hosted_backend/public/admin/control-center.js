'use strict';
/* Progressive enhancement: original rate/Telegram/release controls and IDs
 * are retained; this file only organizes panels and owns independent ad state.
 */
(() => {
  const workspace=document.getElementById('workspace');
  if(!workspace)return;
  const el=(tag,cls,text)=>{
    const node=document.createElement(tag);
    if(cls)node.className=cls;
    if(text!==undefined)node.textContent=text;
    return node;
  };
  const shell=el('div','control-shell');
  const aside=el('nav','control-nav');
  aside.setAttribute('aria-label','Admin sections');
  const pageArea=el('div','control-content');
  const panels=new Map();
  const info=[
    ['overview','⌂','အနှစ်ချုပ်','နောက်ဆုံးနှုန်း၊ မူကြမ်းနဲ့ လုပ်ရန်များ'],
    ['rates','⇄','ငွေလဲနှုန်း','နှုန်းဖြည့် → နမူနာစစ် → အတည်ပြုတင်'],
    ['advertising','▣','ကြော်ငြာ / Sponsor','မူကြမ်း၊ campaign နဲ့ အရေးပေါ်ပိတ်ခြင်း'],
    ['notifications','♧','အသိပေးမှု','ကြေညာချက်နဲ့ Telegram ချိတ်ဆက်မှု'],
    ['history','◷','တင်ထားသောမှတ်တမ်း','ယခင်နှုန်းနဲ့ ပြန်ယူနိုင်သောတင်ချက်များ'],
    ['system','⚙','App / ဆက်တင်','App version၊ download link နဲ့ owner settings'],
  ];
  for(const [id,icon,name,description] of info){
    const link=el('button','control-link');
    link.type='button';link.dataset.page=id;link.setAttribute('aria-controls','control-'+id);
    link.append(el('span','control-icon',icon),el('span','control-link-name',name));
    link.firstElementChild.setAttribute('aria-hidden','true');
    link.addEventListener('click',()=>activate(id,true));
    aside.append(link);
    const page=el('section','control-page');
    page.id='control-'+id;page.dataset.page=id;
    page.hidden=true;
    const title=el('h2','control-page-title',name);title.id='control-title-'+id;title.tabIndex=-1;
    page.setAttribute('aria-labelledby',title.id);
    page.append(title,el('p','control-page-description',description));
    pageArea.append(page);panels.set(id,page);
  }
  const nodes=[...workspace.children];
  const containing=id=>nodes.find(node=>node.querySelector?.('#'+id));
  const append=(page,node)=>{if(node)panels.get(page).append(node);};
  append('overview',nodes.find(n=>n.classList?.contains('guide')));
  append('overview',nodes.find(n=>n.classList?.contains('summary')));
  append('rates',document.getElementById('edit-panel'));
  append('rates',nodes.find(n=>n.classList?.contains('toolbar')));
  append('rates',document.getElementById('preview'));
  append('notifications',containing('announcement-publish'));
  append('notifications',containing('insights-refresh'));
  append('notifications',containing('owner-push-test'));
  append('history',containing('history'));
  append('system',containing('release-save'));
  append('notifications',containing('tg-status'));
  // Any future independent panels remain reachable; never discard a feature.
  for(const node of nodes)if(node.parentElement===workspace)panels.get('system').append(node);
  const brand=el('div','control-brand');
  brand.append(el('strong','', 'ဘတ်ဈေး'),el('small','', 'ADMIN CONTROL CENTER'));
  aside.prepend(brand);
  const footer=el('p','control-nav-foot','Owner-only administration · Thailand time');
  aside.append(footer);
  shell.append(aside,pageArea);
  workspace.append(shell);

  function activate(id,focus=false){
    if(!panels.has(id))id='overview';
    for(const [key,page] of panels)page.hidden=key!==id;
    for(const btn of aside.querySelectorAll('button[data-page]')){
      const active=btn.dataset.page===id;
      btn.setAttribute('aria-current',active?'page':'false');
      btn.classList.toggle('active',active);
    }
    if(focus)panels.get(id).querySelector('.control-page-title').focus({preventScroll:true});
    if(id==='advertising'&&!loaded)refreshAds();
    if(window.innerWidth<780)panels.get(id).scrollIntoView?.({behavior:'auto',block:'start'});
  }
  activate('overview');

  const overviewActions=el('div','control-shortcuts');
  for(const [label,target] of [['ပြင်ဆင် / Publish','rates'],['Ads Control','advertising'],['Telegram / Noti','notifications'],['History','history']]){
    const button=el('button','control-shortcut',label);
    button.type='button';button.addEventListener('click',()=>activate(target,true));
    overviewActions.append(button);
  }
  panels.get('overview').insertBefore(overviewActions,panels.get('overview').children[2]||null);

  const adPage=panels.get('advertising');
  const disclosure=el('p','control-notice','Sponsor မူကြမ်းသိမ်းတာနဲ့ User app ပေါ် မတက်ပါ။ အဓိကခလုတ်၊ Sponsor ခလုတ်နဲ့ သက်ဆိုင်ရာနေရာ ဖွင့်ထားမှ ပြပါတယ်။');
  adPage.append(disclosure);
  const status=el('p','control-ad-status');
  status.id='ad-config-status';status.setAttribute('role','status');status.setAttribute('aria-live','polite');
  adPage.append(status);
  const controls=el('form','control-ad-form');
  controls.id='ad-config-form';
  const categories=[
    ['အဓိက ထိန်းချုပ်မှု',[['enabled','ကြော်ငြာအားလုံး ဖွင့် / ပိတ်']]],
    ['အသုံးပြုမည့် App',[['platforms.web','Web/PWA'],['platforms.android','Android'],['platforms.ios','iOS']]],
    ['Ad formats (SDK integration required)',[['formats.banner','Banner'],['formats.native','Native'],['formats.interstitial','Interstitial'],['formats.rewarded','Rewarded']]],
    ['ပြသမည့်နေရာ',[['placements.home','Home'],['placements.history','Exchange history'],['placements.calculator','Calculator (default OFF)'],['placements.budget','Personal money (default OFF)']]],
    ['Sponsor ဖွင့် / ပိတ်',[['sponsors_enabled','Sponsor များ ပြမယ်']]],
  ];
  for(const [heading,fields] of categories){
    const fieldset=el('fieldset','control-fieldset');
    const legend=el('legend','',heading);fieldset.append(legend);
    const group=el('div','control-check-grid');
    for(const [name,title] of fields){
      const label=el('label','control-switch-row');
      const box=el('input');box.type='checkbox';box.name=name;box.dataset.adField=name;
      label.append(box,el('span','',title));group.append(label);
    }
    fieldset.append(group);controls.append(fieldset);
  }
  const emergency=el('button','control-danger','ကြော်ငြာအားလုံး ပိတ်မယ်');
  emergency.type='button';emergency.id='ad-emergency-off';
  const save=el('button','primary','စစ်ပြီး အတည်ပြုတင်မယ်');
  save.type='submit';save.id='ad-config-save';
  const reload=el('button','','ပြန်စစ်မယ်');
  reload.type='button';reload.id='ad-config-reload';
  const draftSave=el('button','','မူကြမ်းသိမ်းမယ်');draftSave.type='button';draftSave.id='ad-draft-save';
  const draftLoad=el('button','','မူကြမ်းပြန်ယူမယ်');draftLoad.type='button';draftLoad.id='ad-draft-load';
  const row=el('div','control-action-row');row.append(draftSave,draftLoad,save,reload,emergency);
  const revisions=el('div','control-ad-history');revisions.id='ad-revisions';
  controls.append(row);adPage.append(controls,revisions);

  const sponsorPanel=el('section','panel control-sponsors');
  sponsorPanel.append(el('h3','','Sponsor စီမံရန်'));
  sponsorPanel.append(el('p','muted','အမည်၊ စာတိုနဲ့ လင့်ခ်နှစ်ခု ဖြည့်ပါ။ နမူနာစစ်ပြီးမှ အတည်ပြုတင်ပါ။ အချိန်များသည် ထိုင်းအချိန် ဖြစ်ပါတယ်။'));
  const sponsorEditor=el('div','control-sponsor-editor');
  const sponsorList=el('div','control-sponsor-list');sponsorList.id='ad-sponsor-list';
  const addSponsor=el('button','','＋ Sponsor အသစ်');
  addSponsor.type='button';addSponsor.id='ad-add-sponsor';
  sponsorPanel.append(sponsorList,addSponsor);
  adPage.append(sponsorPanel);

  let loaded=null,dirty=false,adWorking=false,adLoading=false,adEpoch=0;
  function ready(){for(const group of controls.querySelectorAll('fieldset'))group.disabled=!loaded;for(const button of [save,draftSave,draftLoad,addSponsor])button.disabled=!loaded;}
  ready();
  window.AdminRuntime?.track('advertising',()=>dirty);
  function indicator(t,error=false){status.textContent=t;status.classList.toggle('error',error);}
  function getConfigFromForm(){
    const data=structuredClone(loaded.config);
    for(const input of controls.querySelectorAll('[data-ad-field]')){
      const keys=input.name.split('.');
      if(keys.length===1)data[keys[0]]=input.checked;
      else data[keys[0]][keys[1]]=input.checked;
    }
    return data;
  }
  function displayControls(){
    for(const field of controls.querySelectorAll('[data-ad-field]')){
      const keys=field.name.split('.');
      field.checked=keys.length===1?loaded.config[keys[0]]:loaded.config[keys[0]][keys[1]];
    }
  }
  function markDirty(){adEpoch++;dirty=true;indicator('Unsaved changes — click Save & Publish');}
  controls.addEventListener('change',markDirty);

  const formField=(parent,title,type='text',value='')=>{
    const wrap=el('label','control-ad-field');
    wrap.append(el('span','',title));
    const input=el('input');input.type=type;input.value=value||'';
    wrap.append(input);parent.append(wrap);
    return input;
  };
  const toInputDate=(iso)=>iso?new Date(Date.parse(iso)+7*3600000).toISOString().slice(0,16):'';
  const toIso=(value)=>value?new Date(value+'+07:00').toISOString():null;
  function renderSponsors(){
    window.dispatchEvent(new CustomEvent('admin:ads',{detail:loaded.config}));
    sponsorList.replaceChildren();
    for(const sponsor of loaded.config.sponsors){
      const editor=el('details','control-sponsor-item');
      const heading=el('summary','',sponsor.name+' · '+(sponsor.enabled?'Enabled':'Paused'));
      editor.append(heading);
      const fields=el('div','control-sponsor-grid');
      const name=formField(fields,'Sponsor အမည်','text',sponsor.name);
      const label=formField(fields,'ကြော်ငြာစာတို','text',sponsor.label);
      const image=formField(fields,'ပုံလင့်ခ် · HTTPS','url',sponsor.image_url);
      const destination=formField(fields,'နှိပ်လျှင် သွားမည့်လင့်ခ် · HTTPS','url',sponsor.destination_url);
      const start=formField(fields,'စတင်ချိန် · ထိုင်းအချိန် (ရှိမှ)','datetime-local',toInputDate(sponsor.start_at));
      const end=formField(fields,'ပြီးဆုံးချိန် · ထိုင်းအချိန် (ရှိမှ)','datetime-local',toInputDate(sponsor.end_at));
      const priority=formField(fields,'Priority 0-100','number',String(sponsor.priority||0));
      priority.min='0';priority.max='100';
      const placementLabel=el('fieldset','control-ad-field');placementLabel.append(el('legend','','Placements'));
      const placementBoxes=[];
      for(const val of ['home','history','calculator','budget']){
        const wrap=el('label','control-switch-row');const box=el('input');box.type='checkbox';box.value=val;
        box.checked=sponsor.placements.includes(val);box.dataset.sponsorPlacement=val;
        placementBoxes.push(box);wrap.append(box,el('span','',val));placementLabel.append(wrap);
      }
      fields.append(placementLabel);
      const languageLabel=el('label','control-ad-field','Language');
      const language=el('select');
      for(const val of ['both','my','en']){
        const o=el('option','',val);o.value=val;language.append(o);
      }
      language.value=sponsor.language||'both';languageLabel.append(language);fields.append(languageLabel);
      const enabledLabel=el('label','control-switch-row');
      const enabled=el('input');enabled.type='checkbox';enabled.checked=sponsor.enabled;
      enabledLabel.append(enabled,el('span','', 'ဒီ Sponsor ကို ဖွင့်မယ်'));fields.append(enabledLabel);
      const update=()=>{
        sponsor.name=name.value.trim();sponsor.label=label.value.trim();
        sponsor.image_url=image.value.trim();sponsor.destination_url=destination.value.trim();
        sponsor.start_at=toIso(start.value);sponsor.end_at=toIso(end.value);
        sponsor.priority=Number(priority.value)||0;sponsor.placements=placementBoxes.filter(x=>x.checked).map(x=>x.value);
        sponsor.language=language.value;sponsor.enabled=enabled.checked;
        heading.textContent=(sponsor.name||'Untitled')+' · '+(sponsor.enabled?'Enabled':'Paused');
        markDirty();
      };
      fields.addEventListener('change',()=>{try{update();}catch(e){indicator('Check campaign dates before saving',true);}});
      fields.addEventListener('input',()=>{try{update();}catch(e){indicator('Check campaign date fields before saving',true);}});
      editor.append(fields);
      const buttons=el('div','control-action-row');
      const preview=el('button','','နမူနာကြည့်မယ်');preview.type='button';
      preview.addEventListener('click',()=>{
        const safe=value=>{try{const u=new URL(value);return u.protocol==='https:'&&!u.username&&!u.password;}catch{return false;}};
        if(!safe(image.value)||!safe(destination.value)){indicator('Valid HTTPS image and destination required',true);return;}
        const dialog=el('dialog','control-sponsor-preview');
        dialog.append(el('h3','','Private preview — not published'),el('p','','Language: '+language.value+' · Placements: '+sponsor.placements.join(', ')),el('small','','Sponsored'));
        const creative=el('img');creative.src=image.value;creative.alt=name.value;creative.referrerPolicy='no-referrer';
        creative.style.cssText='display:block;max-width:100%;max-height:220px;object-fit:contain';
        dialog.append(creative,el('h4','',name.value),el('p','',label.value));
        const visit=el('a','','Visit sponsor');visit.href=destination.value;visit.target='_blank';visit.rel='noopener noreferrer';
        const close=el('button','','Close preview');close.type='button';close.addEventListener('click',()=>dialog.close());
        dialog.addEventListener('close',()=>dialog.remove(),{once:true});
        dialog.append(visit,close);document.body.append(dialog);dialog.showModal();
      });
      const remove=el('button','control-danger','မူကြမ်းမှ ဖယ်မယ်');remove.type='button';
      remove.addEventListener('click',()=>{
        if(!confirm('Remove this sponsor from your draft ads settings?'))return;
        loaded.config.sponsors=loaded.config.sponsors.filter(x=>x!==sponsor);
        markDirty();renderSponsors();
      });
      buttons.append(preview,remove);editor.append(buttons);
      sponsorList.append(editor);
    }
    if(!loaded.config.sponsors.length)sponsorList.append(el('p','muted','Sponsor မရှိသေးပါ။ ပုံလင့်ခ်နဲ့ သွားမယ့်လင့်ခ် ထည့်ပြီး မူကြမ်းအရင် ပြင်နိုင်ပါတယ်။'));
  }
  async function request(path,method='GET',body){
    const write=method!=='GET'&&path!=='ads/off';
    if(write&&adWorking)throw Error('Request တစ်ခု လုပ်ဆောင်နေပါတယ်။ ပြီးမှ ထပ်လုပ်ပေးပါ။');
    const locked=[];
    if(write){adWorking=true;for(const node of [...controls.querySelectorAll('input,select,button'),...sponsorPanel.querySelectorAll('input,select,button'),...row.querySelectorAll('button')]){if(node!==emergency){locked.push([node,node.disabled]);node.disabled=true;}}}
    try{
    const options={method,credentials:'same-origin',headers:{'Content-Type':'application/json','X-Admin-Request':'1'},...(body===undefined?{}:{body:JSON.stringify(body)})};
    const {response,data}=window.AdminRuntime?await window.AdminRuntime.fetchJson('/api/admin/'+path,options):await (async()=>{const response=await fetch('/api/admin/'+path,options);return {response,data:await response.json()};})();
    if(!response.ok)throw Error(data.error||'Request failed');
    return data;
    }finally{if(write){adWorking=false;for(const [node,disabled]of locked)node.disabled=disabled;}}
  }
  // Owner identity is checked by the server for every request. Never cache
  // admin advertising settings in the public app's browser storage.
  async function refreshAds(){
    if(adLoading)return;adLoading=true;const epoch=adEpoch;
    indicator('Loading advertising settings…');
    try{
      const next=await request('ads');
      if(epoch!==adEpoch){indicator('New edits kept — reload skipped');return;}loaded=next;dirty=false;ready();
      displayControls();renderSponsors();renderHistory();
      indicator('Config v'+loaded.version+' · Last saved '+loaded.updated_at+' · Off by default / API-backed');
    }catch(e){indicator('Could not load ads: '+e.message,true);}finally{adLoading=false;}
  }
  async function saveAds(configOverride){
    if(!loaded)return;
    const epoch=adEpoch;
    if(!confirm('Publish these advertising settings to allowed app placements?'))return;
    try{
      const config=configOverride||getConfigFromForm();
      const res=await request('ads','PUT',{config,expected_version:loaded.version});
      if(epoch!==adEpoch)return;
      loaded.version=res.version;loaded.config=config;loaded.updated_at=res.updated_at;dirty=false;
      displayControls();renderSponsors();renderHistory();
      await refreshAds();indicator('Ads settings published — version '+res.version);
    }catch(e){indicator('Save failed: '+e.message,true);}
  }
  controls.addEventListener('submit',event=>{event.preventDefault();saveAds();});
  reload.addEventListener('click',()=>{
    if(dirty&&!confirm('Discard unsaved ad settings?'))return;refreshAds();
  });
  function renderHistory(){
    revisions.replaceChildren(el('h3','','Published advertising history'));
    for(const revision of loaded.history||[]){
      const restore=el('button','','Restore v'+revision.version+' · '+revision.updated_at);restore.type='button';
      restore.addEventListener('click',async()=>{
        if(!confirm('Publish advertising revision '+revision.version+' again? Campaign dates still apply.'))return;
        try{await request('ads/rollback','POST',{revision:revision.version,expected_version:loaded.version});await refreshAds();}
        catch(e){indicator('Restore failed: '+e.message,true);}
      });revisions.append(restore);
    }
  }
  draftSave.addEventListener('click',async()=>{
    if(!loaded)return;
    try{
      const config=getConfigFromForm();
      const result=await request('ads/draft','PUT',{config,expected_version:loaded.draft?.version||0});
      loaded.draft={config:structuredClone(config),version:result.version,updated_at:result.updated_at};dirty=false;
      indicator('Draft saved — public advertising unchanged');
    }catch(e){indicator('Draft save failed: '+e.message,true);}
  });
  draftLoad.addEventListener('click',()=>{
    if(!loaded?.draft){indicator('No saved draft yet');return;}
    if(dirty&&!confirm('Replace unsaved fields with saved draft?'))return;
    loaded.config=structuredClone(loaded.draft.config);displayControls();renderSponsors();markDirty();
  });
  emergency.addEventListener('click',async()=>{
    if(!confirm('Turn OFF all advertising now? Unsaved fields will be discarded.'))return;
    adEpoch++;emergency.disabled=true;
    try{
      loaded=await request('ads/off','POST',{});dirty=false;ready();
      displayControls();renderSponsors();renderHistory();
      indicator('All advertising OFF. Online apps refresh within 60 seconds plus network time. Saved drafts remain separate.');
    }catch(e){indicator('Emergency OFF failed: '+e.message,true);}
    finally{emergency.disabled=false;}
  });
  addSponsor.addEventListener('click',()=>{
    if(!loaded)return;
    if(loaded.config.sponsors.length>=20){indicator('Maximum 20 campaigns',true);return;}
    loaded.config.sponsors.push({
      id:'campaign-'+crypto.randomUUID(),name:'New sponsor',label:'Sponsored',
      image_url:'',destination_url:'',language:'both',placements:['home'],
      start_at:null,end_at:null,enabled:false,priority:0,
    });
    markDirty();renderSponsors();
    sponsorList.lastElementChild.open=true;
  });


  const health=el('section','admin-health panel');health.id='admin-health';
  health.append(el('h3','','အခု လုပ်ရန်'),el('p','','နှုန်းနဲ့ မူကြမ်းကို စစ်ဆေးနေပါတယ်…'));
  panels.get('overview').insertBefore(health,panels.get('overview').children[2]||null);
  window.addEventListener('admin:state',event=>{
    const state=event.detail;const quotes=state.published?.quotes||[];
    const expired=quotes.filter(q=>!Number.isFinite(Date.parse(q.valid_until))||Date.parse(q.valid_until)<=Date.now()).length;
    health.replaceChildren(el('h3','','အခု လုပ်ရန်'));
    for(const text of [quotes.length?'User မြင်နေရသောနှုန်း '+quotes.length+' ခု':'နှုန်း မတင်ရသေးပါ',!quotes.length?'User app အတွက် အတည်ပြုပြီးသောနှုန်း ထည့်ပေးပါ':expired?expired+' နှုန်းကို ပြန်စစ်ဖို့ လိုနေပါတယ်':'ရှိသောနှုန်းများ သက်တမ်းအတွင်း ဖြစ်ပါတယ်','မူကြမ်း v'+state.draft_version+' · တင်ထားသော version '+state.published.revision])health.append(el('p','',text));
    health.dataset.attention=String(expired>0||quotes.length===0);
  });

  function upgradeDashboard(){
    const themeLabel=el('label','admin-theme','အရောင်');
    const theme=el('select');theme.id='admin-theme';theme.setAttribute('aria-label','Dashboard အရောင်');
    for(const [value,label] of [['system','စက်အတိုင်း'],['light','အလင်း'],['dark','အမှောင်']]){const option=el('option','',label);option.value=value;theme.append(option);}
    theme.value=document.documentElement.dataset.themePreference||'system';themeLabel.append(theme);document.querySelector('main>header').append(themeLabel);
    const applyTheme=()=>{
      const value=theme.value;document.documentElement.dataset.themePreference=value;
      document.documentElement.dataset.theme=value==='system'?(window.matchMedia?.('(prefers-color-scheme: dark)').matches?'dark':'light'):value;
      try{localStorage.setItem('bahtzay-admin-theme',value);}catch{}
    };
    theme.addEventListener('change',applyTheme);window.matchMedia?.('(prefers-color-scheme: dark)').addEventListener?.('change',()=>{if(theme.value==='system')applyTheme();});

    const overview=panels.get('overview');
    const guide=overview.querySelector('.guide');
    if(guide){const help=el('details','overview-help');help.append(el('summary','','နေ့စဉ်တင်နည်း ကြည့်ရန်'),guide);overview.append(help);}
    const removeLatest=document.getElementById('delete-latest');
    if(removeLatest){const help=removeLatest.nextElementSibling;const tools=el('details','');tools.append(el('summary','','မှားတင်မိသော နောက်ဆုံးတင်ချက်ကို ဖယ်ရန်'),removeLatest);if(help)tools.append(help);panels.get('rates').append(tools);}
    const hero=el('div','overview-heading');hero.append(el('span','eyebrow','နေ့စဉ် စီမံခန့်ခွဲမှု'),el('p','','နှုန်းအခြေအနေနဲ့ လုပ်ရန်များကို တစ်နေရာတည်းမှာ စစ်ပါ။'));
    const metrics=el('div','overview-metrics');metrics.id='overview-metrics';
    const charts=el('div','overview-charts');
    const trend=el('section','panel');trend.append(el('h3','','နှုန်းလမ်းကြောင်း'));
    const direction=el('select');direction.id='overview-direction';direction.setAttribute('aria-label','Graph ဦးတည်ချက်');
    for(const [val,label] of [['thb_mmk','ဘတ်ပေး → ကျပ်ယူ'],['mmk_thb','ကျပ်ပေး → ဘတ်ယူ']]){const o=el('option','',label);o.value=val;direction.append(o);}
    const chart=el('div','rate-chart');chart.id='overview-rate-chart';trend.append(direction,chart,el('small','','ယူနစ် — ကျပ် ၁ သိန်းအတွက် ဘတ် · လတ်တလောတင်ချက် ၁၄ ခုအထိ'));
    const activity=el('section','panel');activity.append(el('h3','','တင်ချက် အရေအတွက် · ၇ ရက်'));
    const bars=el('div','activity-bars');bars.id='overview-activity';activity.append(bars,el('small','','ထိုင်းရက်စွဲ · ပြန်ရရှိထားသော နောက်ဆုံးမှတ်တမ်း ၅၀ အတွင်းသာ'));
    charts.append(trend,activity);
    overview.insertBefore(hero,overview.children[2]);overview.insertBefore(metrics,hero.nextSibling);overview.insertBefore(charts,metrics.nextSibling);
    let snapshot=null;
    function metric(label,value,note){const card=el('div','metric-card');card.append(el('span','',label),el('strong','',String(value)),el('small','',note));return card;}
    const bangkok=iso=>{const d=new Date(iso);return Number.isFinite(d.getTime())?new Intl.DateTimeFormat('en-GB',{timeZone:'Asia/Bangkok',day:'2-digit',month:'2-digit'}).format(d):'—';};
    function draw(){
      if(!snapshot)return;
      const quotes=snapshot.published?.quotes||[],history=snapshot.history||[];
      const fresh=quotes.filter(q=>Date.parse(q.valid_until)>Date.now()).length;
      metrics.replaceChildren(metric('တင်ထားသောနှုန်း',quotes.length,fresh+' ခု သက်တမ်းအတွင်း'),metric('မူကြမ်းနှုန်း',snapshot.draft?.quotes?.length||0,'User မမြင်ရသေးပါ'),metric('နောက်ဆုံးတင်ချက်','#'+snapshot.published.revision,bangkok(snapshot.published.published_at)),metric('ပြန်ရရှိသောမှတ်တမ်း',history.length,'နောက်ဆုံး ၅၀ ခုအထိ'));
      const points=[...history].sort((a,b)=>Date.parse(a.published_at)-Date.parse(b.published_at)).map(rev=>{
        const q=(rev.quotes||[]).find(q=>q.direction===direction.value&&Number(q.rate_micros)>0);
        return q?{value:100000000000/Number(q.rate_micros),at:rev.published_at}:null;
      }).filter(Boolean).slice(-14);
      chart.replaceChildren();
      if(!points.length)chart.append(el('p','empty-state','ဒီဦးတည်ချက်အတွက် မှတ်တမ်း မရှိသေးပါ။'));
      else{
        const values=points.map(p=>p.value),min=Math.min(...values),max=Math.max(...values),range=max-min||1;
        const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');svg.setAttribute('viewBox','0 0 440 170');svg.setAttribute('role','img');svg.setAttribute('aria-label','ကျပ် ၁ သိန်းအတွက် ဘတ် '+values.map(v=>v.toFixed(2)).join(', '));
        const title=document.createElementNS(svg.namespaceURI,'title');title.textContent='ကျပ် ၁ သိန်းအတွက် ဘတ်နှုန်း';svg.append(title);
        const line=document.createElementNS(svg.namespaceURI,'polyline');line.setAttribute('points',points.map((p,i)=>`${24+i*(392/Math.max(points.length-1,1))},${138-(p.value-min)/range*104}`).join(' '));line.setAttribute('class','chart-line');svg.append(line);
        points.forEach((p,i)=>{const dot=document.createElementNS(svg.namespaceURI,'circle');dot.setAttribute('cx',String(24+i*(392/Math.max(points.length-1,1))));dot.setAttribute('cy',String(138-(p.value-min)/range*104));dot.setAttribute('r','4');dot.setAttribute('class','chart-dot');const hint=document.createElementNS(svg.namespaceURI,'title');hint.textContent=bangkok(p.at)+' · '+p.value.toFixed(2)+' ဘတ်';dot.append(hint);svg.append(dot);});
        chart.append(el('strong','chart-current',values.at(-1).toFixed(2)+' ဘတ်'),svg);
        const labels=el('div','chart-labels');labels.append(el('small','',bangkok(points[0].at)),el('small','',bangkok(points.at(-1).at)));chart.append(labels);
        const details=el('details','chart-data');details.append(el('summary','','နှုန်းအသေးစိတ်'));for(const point of points)details.append(el('p','',bangkok(point.at)+' · '+point.value.toFixed(2)+' ဘတ်'));chart.append(details);
      }
      const dayKey=date=>new Date(new Date(date).getTime()+7*3600000).toISOString().slice(0,10);
      const days=Array.from({length:7},(_,i)=>{const day=new Date(Date.now()-(6-i)*86400000);return {key:dayKey(day),label:bangkok(day),count:0};});
      for(const rev of history){if(!Number.isFinite(Date.parse(rev.published_at)))continue;const d=days.find(d=>d.key===dayKey(rev.published_at));if(d)d.count++;}
      const maximum=Math.max(1,...days.map(d=>d.count));bars.replaceChildren();
      for(const day of days){const column=el('div','activity-column');const bar=el('div','activity-bar');bar.style.height=(day.count/maximum*110)+'px';bar.setAttribute('aria-hidden','true');column.append(el('strong','',String(day.count)),bar,el('small','',day.label));bars.append(column);}
    }
    direction.addEventListener('change',draw);window.addEventListener('admin:state',e=>{snapshot=e.detail;draw();});

    // Keep the daily sponsor workflow visible; SDK configuration is secondary.
    const advanced=el('details','ad-advanced');advanced.append(el('summary','','အဆင့်မြင့် · Google Ads / Platform setting'));
    for(const field of [...controls.querySelectorAll('fieldset')].slice(1,4))advanced.append(field);
    advanced.append(el('p','muted','AdMob / AdSense SDK မချိတ်ရသေးပါ။ ဒီ setting ဖွင့်ရုံနဲ့ Google ကြော်ငြာ မပြပါ။'));
    controls.insertBefore(advanced,row);
    adPage.insertBefore(sponsorPanel,revisions);
    save.setAttribute('form',controls.id);adPage.append(row);row.classList.add('ad-save-bar');
    const revisionsDisclosure=el('details','');revisionsDisclosure.append(el('summary','','ကြော်ငြာ ပြင်ဆင်မှုမှတ်တမ်း'),revisions);adPage.insertBefore(revisionsDisclosure,row);
    const sponsorStats=el('p','sponsor-stats','Sponsor setting မဖွင့်ရသေးပါ။');adPage.insertBefore(sponsorStats,disclosure);
    window.addEventListener('admin:ads',e=>{const config=e.detail,now=Date.now();const running=(config.sponsors||[]).filter(s=>s.enabled&&(!s.start_at||Date.parse(s.start_at)<=now)&&(!s.end_at||Date.parse(s.end_at)>now));sponsorStats.textContent='အဓိကခလုတ် '+(config.enabled?'ဖွင့်':'ပိတ်')+' · Sponsor '+(config.sponsors_enabled?'ဖွင့်':'ပိတ်')+' · Campaign '+config.sponsors.length+' ခု · အချိန်အတွင်းဖွင့်ထား '+running.length+' ခု';});

    const notifications=panels.get('notifications');
    const blocks=[...notifications.children].filter(n=>!n.classList.contains('control-page-title')&&!n.classList.contains('control-page-description'));
    const tabs=el('div','notification-tabs');tabs.setAttribute('role','group');tabs.setAttribute('aria-label','အသိပေးမှု အပိုင်းရွေးရန်');
    const sections=[['compose','စာတိုရေးမယ်',[]],['delivery','ပို့မှတ်တမ်း / အခြေအနေ',[]],['telegram','Telegram',[]]];
    for(const block of blocks){const target=block.querySelector('#announcement-publish')?sections[0]:block.querySelector('#tg-status')?sections[2]:sections[1];target[2].push(block);}
    for(const [key,label,nodes] of sections){const button=el('button','',label);button.type='button';button.dataset.notificationTab=key;button.setAttribute('aria-controls','notification-'+key);const box=el('div','notification-section');box.id='notification-'+key;box.hidden=key!=='compose';box.append(...nodes);notifications.append(box);tabs.append(button);button.setAttribute('aria-pressed',String(key==='compose'));button.addEventListener('click',()=>{for(const node of notifications.querySelectorAll('.notification-section'))node.hidden=node!==box;for(const b of tabs.querySelectorAll('button'))b.setAttribute('aria-pressed',String(b===button));});}
    notifications.insertBefore(tabs,notifications.children[2]);
    const text=document.getElementById('announcement-text');
    const count=el('small','composition-count');count.id='announcement-count';text.after(count);
    const updateCount=()=>{count.textContent=Array.from(text.value).length+' / 500 · တိုတိုနဲ့ အဓိကအချက်ပဲ ရေးပါ။';};text.addEventListener('input',updateCount);document.getElementById('announcement-template').addEventListener('change',updateCount);updateCount();
    const test=document.getElementById('owner-push-test');if(test){const testHelp=test.nextElementSibling;const details=el('details','');details.append(el('summary','','ဒီ Admin စက်တစ်လုံးဆီသာ စမ်းသပ်ရန်'),test);if(testHelp)details.append(testHelp);document.getElementById('notification-delivery').append(details);}
  }

  upgradeDashboard();

  if(typeof state!=='undefined'&&state)window.dispatchEvent(new CustomEvent('admin:state',{detail:state}));
  // Expose navigation only to integration tests; no remote scripting.
  window.bahtzayAdminNavigate=activate;
})();
