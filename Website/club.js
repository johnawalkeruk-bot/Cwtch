import {gardenMetrics} from './garden-metrics.js';
import {config} from './cloud-config.js';
const $=id=>document.getElementById(id);
let session=null, busy=false, profile=null, ownGarden=null;
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
function enter(data){session={...data,expiry:Date.now()+(data.expires_in||3600)*1000-60000};$('login').hidden=true;$('registration').hidden=true;$('auth-switch').hidden=true;$('recovery').hidden=true;$('session').hidden=false;$('identity').textContent=profile?.username||data.user?.email||'Signed in';$('account-title').textContent='Back in the valley.';}
async function fresh(){if(Date.now()<session.expiry)return;enter(await request('/auth/v1/token?grant_type=refresh_token',{refresh_token:session.refresh_token}));}
function render(row){
 ownGarden=row;
 $('own-metrics').replaceChildren();
 for(const [label,value] of Object.entries(gardenMetrics(row))){const tr=document.createElement('tr');for(const text of [label,value??'—']){const td=document.createElement('td');td.textContent=String(text);tr.append(td);}$('own-metrics').append(tr);}
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
async function load(){
 await fresh();const failures=[];
 try{render((await request('/rest/v1/cwtch_saves?select=payload,revision,updated_at',{},'GET',true))[0]);}
 catch(e){failures.push('Garden: '+e.message);}
 try{await loadProfile();}catch(e){failures.push('Profile: '+e.message);}
 if(failures.length)status('You are signed in. Some details could not load. '+failures.join(' ')+' Use Refresh garden to retry.');
}
$('login').addEventListener('submit',event=>{event.preventDefault();const password=$('password').value;$('password').value='';run(async()=>{status('Signing in…');enter(await request('/auth/v1/token?grant_type=password',{email:$('email').value.trim(),password}));await load();});});
function showAuth(register=false){
 $('login').hidden=register;$('registration').hidden=!register;$('auth-switch').hidden=false;
 $('show-login').setAttribute('aria-pressed',String(!register));$('show-register').setAttribute('aria-pressed',String(register));
 $('account-title').textContent=register?'Make yourself at home.':'Welcome back.';
 $('password').value='';$('register-password').value='';
 status(register?'Choose a unique username to join the Valley Club.':'Sign in with the email and password you use in the game.');
 (register?$('username'):$('email')).focus();
}
$('show-login').onclick=()=>showAuth(false);$('show-register').onclick=()=>showAuth(true);
$('registration').addEventListener('submit',event=>{event.preventDefault();const password=$('register-password').value;$('register-password').value='';run(async()=>{
 status('Creating your account…');
 const username=$('username').value.trim(),email=$('register-email').value.trim();
 if(!/^[A-Za-z0-9_]{3,20}$/.test(username))throw new Error('Choose a username with 3–20 letters, numbers or underscores.');
 if(!await request('/rest/v1/rpc/cwtch_username_available',{candidate:username}))throw new Error('That username is taken. Try another.');
 const data=await request('/auth/v1/signup?redirect_to='+encodeURIComponent(config.redirect),{email,password,data:{username}});
 if(data.access_token){enter(data);await load();}else{$('email').value=email;showAuth(false);status('Check your email to confirm your account, then sign in here.');}
});});
$('reset').onclick=()=>{if(!$('email').reportValidity())return;run(async()=>{await request('/auth/v1/recover?redirect_to='+encodeURIComponent(config.redirect),{email:$('email').value.trim()});status('If that account exists, a password reset email is on its way.');});};
$('refresh').onclick=()=>run(load);
$('logout').onclick=()=>run(async()=>{try{await request('/auth/v1/logout?scope=local',{},'POST',true);}finally{session=null;profile=null;ownGarden=null;$('social').hidden=true;$('comparison').hidden=true;$('search-results').replaceChildren();$('friends').replaceChildren();$('portrait').hidden=true;$('session').hidden=true;showAuth(false);$('dashboard').hidden=true;$('empty').hidden=false;$('stamp').textContent='Signed out';$('account-title').textContent='Welcome home.';status('Signed out on this page.');}});
$('recovery').addEventListener('submit',event=>{event.preventDefault();const password=$('new-password').value;$('new-password').value='';run(async()=>{await request('/auth/v1/user',{password},'PUT',true);$('recovery').hidden=true;$('session').hidden=false;status('Password updated. You can now sign in to CWTCH.');});});
setBusy(false);
status('Sign in with the email and password you use in the game.');
const hash=new URLSearchParams(location.hash.slice(1));
if(location.hash)history.replaceState(null,'',location.pathname+location.search);
if(hash.get('access_token')){
 session={access_token:hash.get('access_token'),refresh_token:hash.get('refresh_token'),expiry:Date.now()+Number(hash.get('expires_in')||3600)*1000-60000};
 run(async()=>{const user=await request('/auth/v1/user',{},'GET',true);enter({...session,user,expires_in:Number(hash.get('expires_in')||3600)});if(hash.get('type')==='recovery'){$('session').hidden=true;$('recovery').hidden=false;status('Choose a new password.');}else{await load();}});
}else if(hash.get('error_description'))status(hash.get('error_description'));

function portrait(img,person){img.src='data:image/svg+xml;charset=utf-8,'+encodeURIComponent(person.avatar_svg);img.alt=`${person.username}'s valley portrait`;}
async function rpc(name,body={}){await fresh();return request('/rest/v1/rpc/cwtch_'+name,body,'POST',true);}
async function loadProfile(){
 profile=await rpc('my_profile');$('claim').hidden=!!profile;$('portrait').hidden=!profile;$('social').hidden=!profile;
 if(profile){$('identity').textContent=profile.username;portrait($('portrait'),profile);await loadFriends();}
 else status('Choose a unique username to finish your Valley Club profile. Your existing garden is safe.');
}
$('claim').onsubmit=event=>{event.preventDefault();run(async()=>{await rpc('claim_username',{candidate:$('claim-name').value.trim()});await loadProfile();status('Your profile and portrait are ready.');});};
function personCard(person,container,buttons,note=''){
 const card=document.createElement('article');card.className='person';const img=document.createElement('img');portrait(img,person);const name=document.createElement('strong');name.textContent=person.username;card.append(img,name);
 if(note){const small=document.createElement('small');small.textContent=note;card.append(small);}
 for(const [label,action] of buttons){const b=document.createElement('button');b.textContent=label;b.onclick=()=>run(action);card.append(b);}container.append(card);
}
async function act(person,action){await rpc('friend_action',{target:person.user_id,action});$('comparison').hidden=true;await loadFriends();$('search-results').replaceChildren();status(action==='request'?'Friend request sent.':action==='accept'?'You are now friends. Garden comparisons are available.':'Friendship or invitation removed.');}
async function loadFriends(){
 const people=await rpc('list_friends');$('friends').replaceChildren();
 for(const person of people){const actions=person.accepted?[['Compare gardens',()=>compare(person)],['Remove friend',()=>act(person,'remove')]]:person.incoming?[['Accept',()=>act(person,'accept')],['Decline',()=>act(person,'remove')]]:[['Cancel request',()=>act(person,'remove')]];
 personCard(person,$('friends'),actions,person.accepted?'Friends':person.incoming?'Invitation received':'Waiting for a reply');}
 if(!people.length)$('friends').textContent='No neighbours yet. Search for a username above.';
}
$('find-people').onsubmit=event=>{event.preventDefault();run(async()=>{const people=await rpc('search_people',{query:$('search-name').value.trim()});const friends=await rpc('list_friends');$('search-results').replaceChildren();for(const p of people){const known=friends.find(x=>x.user_id===p.user_id);personCard(p,$('search-results'),known?[]:[['Add friend',()=>act(p,'request')]],known?(known.accepted?'Already friends':'Invitation pending'):'');}if(!people.length)$('search-results').textContent='No matching usernames found.';});};
async function compare(person){
 const friend=await rpc('garden_snapshot',{target:person.user_id});
 // Refresh both snapshots so the comparison never silently uses an older local view.
 const mine=await rpc('garden_snapshot',{target:profile.user_id});
 const left=gardenMetrics(mine),right=gardenMetrics(friend);$('compare-title').textContent=`Your garden & ${person.username}'s`;$('friend-heading').textContent=person.username;
 const stamp=row=>row?new Date(row.updated_at).toLocaleString():'No uploaded garden';$('compare-stamp').textContent=`You: ${stamp(mine)} · ${person.username}: ${stamp(friend)}`;$('compare-rows').replaceChildren();
 for(const name of new Set([...Object.keys(left),...Object.keys(right)])){const tr=document.createElement('tr');for(const value of [name,left[name]??'—',right[name]??'—']){const td=document.createElement('td');td.textContent=String(value);tr.append(td);}$('compare-rows').append(tr);}
 $('comparison').hidden=false;$('comparison').scrollIntoView({behavior:'smooth',block:'start'});
}
