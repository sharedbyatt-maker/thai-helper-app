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
    ['overview','⌂','Overview','Live rates, draft and daily tasks'],
    ['rates','⇄','Exchange Rates','Edit, preview and publish'],
    ['advertising','▣','Ads & Sponsors','Web, Android, iOS configuration'],
    ['notifications','♧','Notifications','Announcements and Telegram'],
    ['history','◷','Publication History','Previous rates and recovery'],
    ['system','⚙','App & System','App release and admin access'],
  ];
  for(const [id,icon,name,description] of info){
    const link=el('button','control-link');
    link.type='button';link.dataset.page=id;
    link.append(el('span','control-icon',icon),el('span','control-link-name',name));
    link.addEventListener('click',()=>activate(id));
    aside.append(link);
    const page=el('section','control-page');
    page.id='control-'+id;page.dataset.page=id;
    page.hidden=true;
    page.append(el('h2','control-page-title',name),el('p','control-page-description',description));
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

  function activate(id){
    if(!panels.has(id))id='overview';
    for(const [key,page] of panels)page.hidden=key!==id;
    for(const btn of aside.querySelectorAll('button[data-page]')){
      const active=btn.dataset.page===id;
      btn.setAttribute('aria-current',active?'page':'false');
      btn.classList.toggle('active',active);
    }
    if(window.innerWidth<780)panels.get(id).scrollIntoView({behavior:'auto',block:'start'});
  }
  activate('overview');

  const overviewActions=el('div','control-shortcuts');
  for(const [label,target] of [['ပြင်ဆင် / Publish','rates'],['Ads Control','advertising'],['Telegram / Noti','notifications'],['History','history']]){
    const button=el('button','control-shortcut',label);
    button.type='button';button.addEventListener('click',()=>activate(target));
    overviewActions.append(button);
  }
  panels.get('overview').insertBefore(overviewActions,panels.get('overview').children[2]||null);

  const adPage=panels.get('advertising');
  const disclosure=el('p','control-notice','Ads are OFF by default. No AdMob or AdSense SDK is installed by these settings alone. Google ad identifiers, approved accounts, consent and native builds are separate release requirements.');
  adPage.append(disclosure);
  const status=el('p','control-ad-status');
  status.id='ad-config-status';status.setAttribute('role','status');status.setAttribute('aria-live','polite');
  adPage.append(status);
  const controls=el('form','control-ad-form');
  controls.id='ad-config-form';
  const categories=[
    ['Master switch',[['enabled','All advertising ON / OFF']]],
    ['Platform controls',[['platforms.web','Web/PWA'],['platforms.android','Android'],['platforms.ios','iOS']]],
    ['Ad formats (SDK integration required)',[['formats.banner','Banner'],['formats.native','Native'],['formats.interstitial','Interstitial'],['formats.rewarded','Rewarded']]],
    ['Allowed user-app positions',[['placements.home','Home'],['placements.history','Exchange history'],['placements.calculator','Calculator (default OFF)'],['placements.budget','Personal money (default OFF)']]],
    ['Direct sponsored campaigns',[['sponsors_enabled','Enable approved sponsors']]],
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
  const emergency=el('button','control-danger','Emergency OFF — disable all ads');
  emergency.type='button';emergency.id='ad-emergency-off';
  const save=el('button','primary','Save & Publish Ads Settings');
  save.type='submit';save.id='ad-config-save';
  const reload=el('button','','Reload configuration');
  reload.type='button';reload.id='ad-config-reload';
  const row=el('div','control-action-row');row.append(save,reload,emergency);
  controls.append(row);adPage.append(controls);

  const sponsorPanel=el('section','panel control-sponsors');
  sponsorPanel.append(el('h3','','Direct Sponsor Campaigns'));
  sponsorPanel.append(el('p','muted','Sponsors have separate explicit approval, a disclosure label, start/end times and safe HTTPS image/link URLs.'));
  const sponsorEditor=el('div','control-sponsor-editor');
  const sponsorList=el('div','control-sponsor-list');sponsorList.id='ad-sponsor-list';
  const addSponsor=el('button','','＋ Add Sponsor');
  addSponsor.type='button';addSponsor.id='ad-add-sponsor';
  sponsorPanel.append(sponsorList,addSponsor);
  adPage.append(sponsorPanel);

  let loaded=null,dirty=false;
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
  function markDirty(){dirty=true;indicator('Unsaved changes — click Save & Publish');}
  controls.addEventListener('change',markDirty);

  const formField=(parent,title,type='text',value='')=>{
    const wrap=el('label','control-ad-field');
    wrap.append(el('span','',title));
    const input=el('input');input.type=type;input.value=value||'';
    wrap.append(input);parent.append(wrap);
    return input;
  };
  const toInputDate=(iso)=>iso?new Date(iso).toISOString().slice(0,16):'';
  const toIso=(value)=>value?new Date(value).toISOString():null;
  function renderSponsors(){
    sponsorList.replaceChildren();
    for(const sponsor of loaded.config.sponsors){
      const editor=el('details','control-sponsor-item');
      const heading=el('summary','',sponsor.name+' · '+(sponsor.enabled?'Enabled':'Paused'));
      editor.append(heading);
      const fields=el('div','control-sponsor-grid');
      const name=formField(fields,'Sponsor name','text',sponsor.name);
      const label=formField(fields,'Ad description','text',sponsor.label);
      const image=formField(fields,'Creative image HTTPS URL','url',sponsor.image_url);
      const destination=formField(fields,'Destination HTTPS URL','url',sponsor.destination_url);
      const start=formField(fields,'Start (optional)','datetime-local',toInputDate(sponsor.start_at));
      const end=formField(fields,'End (optional)','datetime-local',toInputDate(sponsor.end_at));
      const priority=formField(fields,'Priority 0-100','number',String(sponsor.priority||0));
      priority.min='0';priority.max='100';
      const placementLabel=el('label','control-ad-field','Placement');
      const placement=el('select');
      for(const val of ['home','history','calculator','budget']){
        const o=el('option','',val);o.value=val;placement.append(o);
      }
      placement.value=sponsor.placements[0]||'home';placementLabel.append(placement);fields.append(placementLabel);
      const languageLabel=el('label','control-ad-field','Language');
      const language=el('select');
      for(const val of ['both','my','en']){
        const o=el('option','',val);o.value=val;language.append(o);
      }
      language.value=sponsor.language||'both';languageLabel.append(language);fields.append(languageLabel);
      const enabledLabel=el('label','control-switch-row');
      const enabled=el('input');enabled.type='checkbox';enabled.checked=sponsor.enabled;
      enabledLabel.append(enabled,el('span','', 'Campaign enabled'));fields.append(enabledLabel);
      const update=()=>{
        sponsor.name=name.value.trim();sponsor.label=label.value.trim();
        sponsor.image_url=image.value.trim();sponsor.destination_url=destination.value.trim();
        sponsor.start_at=toIso(start.value);sponsor.end_at=toIso(end.value);
        sponsor.priority=Number(priority.value)||0;sponsor.placements=[placement.value];
        sponsor.language=language.value;sponsor.enabled=enabled.checked;
        heading.textContent=(sponsor.name||'Untitled')+' · '+(sponsor.enabled?'Enabled':'Paused');
        markDirty();
      };
      fields.addEventListener('change',update);
      fields.addEventListener('input',()=>{try{update();}catch(e){indicator('Check campaign date fields before saving',true);}});
      editor.append(fields);
      const buttons=el('div','control-action-row');
      const preview=el('button','','Preview link');preview.type='button';
      preview.addEventListener('click',()=>{const url=destination.value.trim();if(!url.startsWith('https://')){indicator('HTTPS link required',true);return;}window.open(url,'_blank','noopener,noreferrer');});
      const remove=el('button','control-danger','Delete campaign');remove.type='button';
      remove.addEventListener('click',()=>{
        if(!confirm('Remove this sponsor from your draft ads settings?'))return;
        loaded.config.sponsors=loaded.config.sponsors.filter(x=>x!==sponsor);
        markDirty();renderSponsors();
      });
      buttons.append(preview,remove);editor.append(buttons);
      sponsorList.append(editor);
    }
    if(!loaded.config.sponsors.length)sponsorList.append(el('p','muted','No sponsors yet. Add a campaign with an image URL and an approved link.'));
  }
  async function request(path,method='GET',body){
    const response=await fetch('/api/admin/'+path,{
      method,credentials:'same-origin',
      headers:{'Content-Type':'application/json','X-Admin-Request':'1'},
      ...(body===undefined?{}:{body:JSON.stringify(body)}),
    });
    const data=await response.json();
    if(!response.ok)throw Error(data.error||'Request failed');
    return data;
  }
  // Owner identity is checked by the server for every request. Never cache
  // admin advertising settings in the public app's browser storage.
  async function refreshAds(){
    indicator('Loading advertising settings…');
    try{
      loaded=await request('ads');dirty=false;
      displayControls();renderSponsors();
      indicator('Config v'+loaded.version+' · Last saved '+loaded.updated_at+' · Off by default / API-backed');
    }catch(e){indicator('Could not load ads: '+e.message,true);}
  }
  async function saveAds(configOverride){
    if(!loaded)return;
    try{
      const config=configOverride||getConfigFromForm();
      const res=await request('ads','PUT',{config,expected_version:loaded.version});
      loaded.version=res.version;loaded.config=config;loaded.updated_at=res.updated_at;dirty=false;
      displayControls();renderSponsors();
      indicator('Ads settings saved — version '+res.version);
    }catch(e){indicator('Save failed: '+e.message,true);}
  }
  controls.addEventListener('submit',event=>{event.preventDefault();saveAds();});
  reload.addEventListener('click',()=>{
    if(dirty&&!confirm('Discard unsaved ad settings?'))return;refreshAds();
  });
  emergency.addEventListener('click',()=>{
    if(!loaded||!confirm('Turn OFF advertising globally, all platforms and sponsors now?'))return;
    const config=getConfigFromForm();config.enabled=false;
    config.sponsors_enabled=false;
    config.platforms={web:false,android:false,ios:false};
    saveAds(config);
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
  const adNav=aside.querySelector('[data-page=advertising]');
  adNav?.addEventListener('click',()=>{if(!loaded)refreshAds();});
  // Expose navigation only to integration tests; no remote scripting.
  window.bahtzayAdminNavigate=activate;
})();
