const { chromium } = require('C:/Users/Shadow/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const http=require('http'),fs=require('fs'),path=require('path'),assert=require('assert');
const root=path.resolve('Website');
const server=http.createServer((req,res)=>{const target=path.resolve(root,'.'+decodeURIComponent(req.url.split('?')[0]));if(!target.startsWith(root+path.sep)){res.writeHead(403).end();return;}fs.readFile(target,(err,data)=>{if(err){res.writeHead(404).end();return;}const ext=path.extname(target);res.setHeader('Content-Type',({'.js':'text/javascript','.css':'text/css','.html':'text/html','.png':'image/png'})[ext]||'application/octet-stream');res.end(data);});});
(async()=>{await new Promise(r=>server.listen(8768,'127.0.0.1',r));const browser=await chromium.launch({headless:true,channel:"msedge"});try{
const page=await browser.newPage({viewport:{width:1440,height:1100}});const errors=[];page.on('pageerror',e=>errors.push(e.message));
await page.goto('http://127.0.0.1:8768/club.html');await page.screenshot({path:'.local/valley-club-signin.png',fullPage:true});
let claimed=false, friendship=null, available=false, registered=null;
const svg=fs.readFileSync('.local/club-avatar-fixture.svg','utf8');
const me={user_id:'me',username:'ValleyGardener',avatar_svg:svg},other={user_id:'friend',username:'Meera',avatar_svg:svg};
const row={revision:3,updated_at:'2026-10-02T12:00:00Z',payload:{coins:420,experience:{total:125},summary:{animals:2,day:3},terrain:[0,1,2,3,4,5,6,7],wildlife:{records:{hedgehog:{visit_day:1,resident_day:2}}},harvested:5,crops_growing:3,purchases:4,watered_tiles:9,births:1,deaths:0,elapsed:600,weather:1,wetness:0.3}};
await page.route('https://ruyertoyvplpmzqflwdy.supabase.co/**',async route=>{const url=route.request().url(),body=route.request().postDataJSON()||{};let data={};
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
await page.locator('#email').fill('test@example.invalid');await page.locator('#password').fill('Testing-fixture-123');await page.locator('#username').fill('TakenName');await page.locator('#register').click();await page.waitForFunction(()=>document.querySelector('#status').textContent.includes('taken'));assert.equal(registered,null);
available=true;await page.locator('#password').fill('Testing-fixture-123');await page.locator('#username').fill('ValleyGardener');await page.locator('#register').click();await page.waitForFunction(()=>document.querySelector('#status').textContent.includes('confirm'));assert.equal(registered.data.username,'ValleyGardener');
await page.locator('#password').fill('Testing-fixture-123');await page.getByRole('button',{name:'Sign in',exact:true}).click();await page.locator('#claim').waitFor({state:'visible'});await page.locator('#claim-name').fill('ValleyGardener');await page.getByRole('button',{name:'Claim username'}).click();await page.locator('#social').waitFor({state:'visible'});assert.equal(await page.locator('#identity').textContent(),'ValleyGardener');assert(await page.locator('#portrait').evaluate(e=>e.complete&&e.naturalWidth>0));
await page.locator('#search-name').fill('Mee');await page.getByRole('button',{name:'Search usernames'}).click();await page.getByRole('button',{name:'Add friend'}).click();await page.getByRole('button',{name:'Cancel request'}).waitFor();assert.equal(await page.getByRole('button',{name:'Compare gardens'}).count(),0);
friendship={accepted:false,incoming:true};await page.locator('#refresh').click();await page.getByRole('button',{name:'Accept',exact:true}).click();await page.getByRole('button',{name:'Compare gardens'}).click();await page.locator('#comparison').waitFor({state:'visible'});assert((await page.locator('#compare-rows').textContent()).includes('610'));assert(await page.locator('#compare-rows tr').count()>30);
await page.screenshot({path:'.local/club-friends-comparison.png',fullPage:true});await page.setViewportSize({width:390,height:844});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));await page.screenshot({path:'.local/club-friends-mobile.png',fullPage:true});
await page.getByRole('button',{name:'Remove friend'}).click();await page.locator('#comparison').waitFor({state:'hidden'});await page.locator('#logout').click();await page.locator('#login').waitFor({state:'visible'});assert(await page.locator('#social').isHidden());assert.deepEqual(errors,[]);console.log('CLUB_SOCIAL_PASS: username validation, registration metadata, legacy claim, portrait, search, request/accept/remove, comparison, logout and mobile layout');
}finally{await browser.close();server.close();}})().catch(e=>{console.error(e);server.close();process.exitCode=1;});

