const { chromium } = require('C:/Users/Shadow/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const http=require('http'),fs=require('fs'),path=require('path'),assert=require('assert');
const root=path.resolve('Website');
const server=http.createServer((req,res)=>{const target=path.resolve(root,'.'+decodeURIComponent(req.url.split('?')[0]));if(!target.startsWith(root+path.sep)){res.writeHead(403).end();return;}fs.readFile(target,(err,data)=>{if(err){res.writeHead(404).end();return;}const ext=path.extname(target);res.setHeader('Content-Type',({'.js':'text/javascript','.css':'text/css','.html':'text/html','.png':'image/png'})[ext]||'application/octet-stream');res.end(data);});});
(async()=>{await new Promise(r=>server.listen(8768,'127.0.0.1',r));const browser=await chromium.launch({headless:true,channel:"msedge"});try{
const page=await browser.newPage({viewport:{width:1440,height:1100}});const errors=[];page.on('pageerror',e=>errors.push(e.message));
await page.clock.install();
await page.goto('http://127.0.0.1:8768/club.html');await page.screenshot({path:'.local/valley-club-signin.png',fullPage:true});
let claimed=false, friendship=null, available=false, registered=null, authFails=false, profileFails=false, gardenFails=false, gardenReads=0;
const svg=fs.readFileSync('.local/club-avatar-fixture.svg','utf8');
const me={user_id:'me',username:'ValleyGardener',avatar_svg:svg},other={user_id:'friend',username:'Meera',avatar_svg:svg};
const row={revision:3,updated_at:'2026-10-02T12:00:00Z',payload:{coins:420,experience:{total:125},summary:{animals:2,day:3},terrain:[0,1,2,3,4,5,6,7],wildlife:{records:{hedgehog:{visit_day:1,resident_day:2}}},harvested:5,crops_growing:3,purchases:4,watered_tiles:9,births:1,deaths:0,elapsed:600,weather:1,wetness:0.3}};
await page.route('https://ruyertoyvplpmzqflwdy.supabase.co/**',async route=>{const url=route.request().url(),body=route.request().postDataJSON()||{};let data={};
if(url.includes('/cwtch_saves?')){gardenReads++;if(gardenFails){await route.fulfill({status:503,contentType:'application/json',body:JSON.stringify({message:'Temporarily unavailable'})});return;}}
if(url.includes('/token?')&&authFails){await route.fulfill({status:400,contentType:'application/json',body:JSON.stringify({error_description:'Invalid login credentials'})});return;}
if(url.includes('/cwtch_my_profile')&&profileFails){await route.fulfill({status:503,contentType:'application/json',body:JSON.stringify({message:'Temporarily unavailable'})});return;}
if(url.includes('/token?'))data={access_token:'test-token',refresh_token:'test-refresh',expires_in:3600,user:{email:'test@example.invalid'}};
else if(url.includes('username_available'))data=available;
else if(url.includes('/signup')){registered=body;data={};}
else if(url.includes('/cwtch_saves?'))data=[row];
else if(url.includes('/cwtch_my_profile'))data=claimed?me:null;
else if(url.includes('/cwtch_claim_username')){claimed=true;data=me;}
else if(url.includes('/cwtch_search_people'))data=[other];
else if(url.includes('/cwtch_list_friends'))data=friendship?[{...other,...friendship}]:[];
else if(url.includes('/cwtch_friend_action')){friendship=body.action==='remove'?null:{accepted:body.action==='accept',incoming:false};data=null;}
else if(url.includes('/cwtch_garden_snapshot'))data=body.target==='me'?row:{...row,payload:{...row.payload,coins:610}};
await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(data)});});
assert(await page.locator('#registration').isHidden());assert.equal(await page.locator('#login #username').count(),0);await page.locator('#show-register').click();await page.locator('#register-email').fill('test@example.invalid');await page.locator('#register-password').fill('Testing-fixture-123');await page.locator('#username').fill('TakenName');await page.locator('#register').click();await page.waitForFunction(()=>document.querySelector('#status').textContent.includes('taken'));assert.equal(registered,null);
available=true;await page.locator('#register-password').fill('Testing-fixture-123');await page.locator('#username').fill('ValleyGardener');await page.locator('#register').click();await page.waitForFunction(()=>document.querySelector('#status').textContent.includes('confirm'));assert.equal(registered.data.username,'ValleyGardener');
assert(await page.locator('#registration').isHidden());await page.locator('#password').fill('Testing-fixture-123');await page.getByRole('button',{name:'Sign in to your valley',exact:true}).click();await page.locator('#claim').waitFor({state:'visible'});await page.locator('#claim-name').fill('ValleyGardener');await page.getByRole('button',{name:'Claim username'}).click();await page.locator('#social').waitFor({state:'visible'});assert.equal(await page.locator('#identity').textContent(),'ValleyGardener');assert(await page.locator('#portrait').evaluate(e=>e.complete&&e.naturalWidth>0));
await page.locator('#search-name').fill('Mee');await page.getByRole('button',{name:'Search usernames'}).click();await page.getByRole('button',{name:'Add friend'}).click();await page.getByRole('button',{name:'Cancel request'}).waitFor();assert.equal(await page.getByRole('button',{name:'Compare gardens'}).count(),0);
friendship={accepted:false,incoming:true};await page.locator('#refresh').click();await page.getByRole('button',{name:'Accept',exact:true}).click();await page.getByRole('button',{name:'Compare gardens'}).click();await page.locator('#comparison').waitFor({state:'visible'});assert((await page.locator('#compare-rows').textContent()).includes('610'));assert(await page.locator('#compare-rows tr').count()>30);
await page.screenshot({path:'.local/club-friends-comparison.png',fullPage:true});await page.setViewportSize({width:390,height:844});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));await page.screenshot({path:'.local/club-friends-mobile.png',fullPage:true});
// The latest cloud revision must arrive without clicking Refresh or resetting forms.
row.revision=4;row.payload.coins=919;row.payload.weather=4;row.payload.wetness=0.8;
await page.clock.fastForward(30001);
await page.waitForFunction(()=>document.querySelector('#coins').textContent==='919');
assert((await page.locator('#own-metrics').textContent()).includes('Heavy rain'));
assert((await page.locator('#own-metrics').textContent()).includes('80%'));
assert((await page.locator('#stamp').textContent()).includes('revision 4'));
gardenFails=true;await page.clock.fastForward(30001);
await page.waitForFunction(()=>document.querySelector('#status').textContent.includes('Could not refresh'));
assert.equal(await page.locator('#coins').textContent(),'919','Failed refresh retains the last loaded save');
gardenFails=false;await page.clock.fastForward(30001);
await page.waitForFunction(()=>document.querySelector('#status').textContent.includes('Showing your latest'));
row.revision=5;row.payload.coins=920;await page.evaluate(()=>window.dispatchEvent(new Event('focus')));
await page.waitForFunction(()=>document.querySelector('#coins').textContent==='920');
const metrics=await page.evaluate(async()=>{const {gardenMetrics}=await import('./garden-metrics.js');return gardenMetrics({payload:{terrain:[0,2,4,7],watered:[[1,1,0],[2,1,0.4]],experience:{total:248,worked:{a:true,b:true}},summary:{day:3,animals:2},weather:3,wetness:0.5}});});
assert.equal(metrics['Watered tiles'],1);assert.equal(metrics.Level,3);assert.equal(metrics['Grass coverage'],'25.0%');assert.equal(metrics['Recorded gardening actions'],2);
await page.getByRole('button',{name:'Remove friend'}).click();await page.locator('#comparison').waitFor({state:'hidden'});await page.locator('#logout').click();await page.locator('#login').waitFor({state:'visible'});assert(await page.locator('#social').isHidden());const signedOutReads=gardenReads;await page.clock.fastForward(60001);assert.equal(gardenReads,signedOutReads,'No polling after logout');
// Bad credentials keep the sign-in form available; no registration requirements leak in.
authFails=true;await page.locator('#password').fill('wrong');await page.getByRole('button',{name:'Sign in to your valley'}).click();await page.waitForFunction(()=>document.querySelector('#status').textContent.includes('Invalid login'));assert(await page.locator('#login').isVisible());
authFails=false;profileFails=true;await page.locator('#password').fill('Testing-fixture-123');await page.getByRole('button',{name:'Sign in to your valley'}).click();await page.waitForFunction(()=>document.querySelector('#status').textContent.includes('You are signed in.'));assert(await page.locator('#session').isVisible());
await page.locator('#logout').click();await page.locator('#login').waitFor({state:'visible'});await page.setViewportSize({width:1440,height:1000});await page.screenshot({path:'.local/club-separate-login.png',fullPage:true});await page.locator('#show-register').click();await page.screenshot({path:'.local/club-separate-registration.png',fullPage:true});
// Missing startup imports show a useful error instead of a dead submit button.
await page.route('**/garden-metrics.js',route=>route.fulfill({status:404,body:'missing'}));await page.reload();await page.waitForFunction(()=>document.querySelector('#status').textContent.includes('could not load'));assert(await page.locator('#login button[type=submit]').isDisabled());
assert.deepEqual(errors,[]);console.log('CLUB_SOCIAL_PASS: username validation, registration metadata, legacy claim, portrait, search, request/accept/remove, comparison, logout, mobile layout, automatic refresh, focus refresh, failure/retry, current weather/terrain/coins and watered metrics');
}finally{await browser.close();server.close();}})().catch(e=>{console.error(e);server.close();process.exitCode=1;});

