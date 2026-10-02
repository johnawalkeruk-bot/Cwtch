import {config} from './cloud-config.js';
const $=id=>document.getElementById(id);
let session=null, busy=false;
function status(text){$('status').textContent=text;}
function setBusy(value){busy=value;document.querySelectorAll('button').forEach(b=>b.disabled=value);}
async function request(path,body,method='POST',auth=false){
 const headers={'apikey':config.key,'Content-Type':'application/json'};
 if(auth) headers.Authorization=`Bearer ${session.access_token}`;
 const response=await fetch(config.url+path,{method,headers,body:method==='GET'?undefined:JSON.stringify(body),signal:AbortSignal.timeout(15000)});
 const data=await response.json().catch(()=>null);
 if(!response.ok) throw new Error(data?.msg||data?.message||data?.error_description||`Service unavailable (${response.status}).`);
 return data;
}
async function run(action){if(busy)return;setBusy(true);try{await action();}catch(e){status(e.message||'Could not connect. Please try again.');}finally{setBusy(false);}}
function enter(data){session={...data,expiry:Date.now()+(data.expires_in||3600)*1000-60000};$('login').hidden=true;$('recovery').hidden=true;$('session').hidden=false;$('identity').textContent=data.user?.email||'Signed in';$('account-title').textContent='Back in the valley.';}
async function fresh(){if(Date.now()<session.expiry)return;enter(await request('/auth/v1/token?grant_type=refresh_token',{refresh_token:session.refresh_token}));}
function render(row){
 $('dashboard').hidden=!row;$('empty').hidden=!!row;
 if(!row){$('stamp').textContent='No cloud garden yet';status('Open Account & Cloud in the game and upload your local garden.');return;}
 const p=row.payload||{}, summary=p.summary||{};
 $('stamp').textContent=`Day ${summary.day||Math.floor(((p.elapsed||0)+600)/2400)+1} · revision ${row.revision} · ${new Date(row.updated_at).toLocaleString()}`;
 $('coins').textContent=Number(p.coins||0).toLocaleString();$('animals').textContent=summary.animals??'—';
 $('level').textContent=`Lv. ${1+Math.floor((p.experience?.total||0)/100)}`;$('xp').textContent=`${p.experience?.total||0} XP earned`;
 const names=['Dirt','Hard dirt','Grass','Long grass','Water','Deep water','Path','Stone'];
 $('terrain').replaceChildren();names.forEach((name,i)=>{const cells=Array.isArray(p.terrain)?p.terrain:[];const percent=cells.length?100*cells.filter(x=>x===i).length/cells.length:0;const label=document.createElement('label');label.textContent=`${name} · ${percent.toFixed(1)}%`;const bar=document.createElement('progress');bar.max=100;bar.value=percent;label.append(bar);$('terrain').append(label);});
 $('visitors').replaceChildren();Object.entries(p.wildlife?.records||{}).forEach(([name,entry])=>{const li=document.createElement('li');li.textContent=`${name.charAt(0).toUpperCase()+name.slice(1)} — first visit: day ${entry.visit_day}${entry.resident_day?`; resident: day ${entry.resident_day}`:''}`;$('visitors').append(li);});
 if(!$('visitors').children.length){const li=document.createElement('li');li.textContent='No visitors recorded yet. Every garden starts somewhere.';$('visitors').append(li);}
 status('Your private garden snapshot is up to date.');
}
async function load(){await fresh();render((await request('/rest/v1/cwtch_saves?select=payload,revision,updated_at',{},'GET',true))[0]);}
$('login').addEventListener('submit',event=>{event.preventDefault();const password=$('password').value;$('password').value='';run(async()=>{enter(await request('/auth/v1/token?grant_type=password',{email:$('email').value.trim(),password}));await load();});});
$('register').onclick=()=>{if(!$('login').reportValidity())return;const password=$('password').value;$('password').value='';run(async()=>{const data=await request('/auth/v1/signup?redirect_to='+encodeURIComponent(config.redirect),{email:$('email').value.trim(),password});if(data.access_token){enter(data);await load();}else status('Check your email to confirm your account, then sign in.');});};
$('reset').onclick=()=>{if(!$('email').reportValidity())return;run(async()=>{await request('/auth/v1/recover?redirect_to='+encodeURIComponent(config.redirect),{email:$('email').value.trim()});status('If that account exists, a password reset email is on its way.');});};
$('refresh').onclick=()=>run(load);
$('logout').onclick=()=>run(async()=>{try{await request('/auth/v1/logout?scope=local',{},'POST',true);}finally{session=null;$('session').hidden=true;$('login').hidden=false;$('dashboard').hidden=true;$('empty').hidden=false;$('stamp').textContent='Signed out';$('account-title').textContent='Welcome home.';status('Signed out on this page.');}});
$('recovery').addEventListener('submit',event=>{event.preventDefault();const password=$('new-password').value;$('new-password').value='';run(async()=>{await request('/auth/v1/user',{password},'PUT',true);$('recovery').hidden=true;$('session').hidden=false;status('Password updated. You can now sign in to CWTCH.');});});
const hash=new URLSearchParams(location.hash.slice(1));
if(location.hash)history.replaceState(null,'',location.pathname+location.search);
if(hash.get('access_token')){
 session={access_token:hash.get('access_token'),refresh_token:hash.get('refresh_token'),expiry:Date.now()+Number(hash.get('expires_in')||3600)*1000-60000};
 run(async()=>{const user=await request('/auth/v1/user',{},'GET',true);enter({...session,user,expires_in:Number(hash.get('expires_in')||3600)});if(hash.get('type')==='recovery'){$('session').hidden=true;$('recovery').hidden=false;status('Choose a new password.');}else{await load();}});
}else if(hash.get('error_description'))status(hash.get('error_description'));
