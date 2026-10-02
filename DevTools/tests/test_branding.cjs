const { chromium } = require(process.env.CWTCH_PLAYWRIGHT || 'playwright');
const http=require('http'),fs=require('fs'),path=require('path'),assert=require('assert');
const root=path.resolve('Website');
const server=http.createServer((req,res)=>{const target=path.resolve(root,'.'+decodeURIComponent(req.url.split('?')[0]));if(!target.startsWith(root+path.sep)){res.writeHead(403).end();return;}fs.readFile(target,(err,data)=>{if(err){res.writeHead(404).end();return;}const ext=path.extname(target);res.setHeader('Content-Type',({'.js':'text/javascript','.css':'text/css','.html':'text/html','.png':'image/png'})[ext]||'application/octet-stream');res.end(data);});});
(async()=>{await new Promise(r=>server.listen(8768,'127.0.0.1',r));const browser=await chromium.launch({headless:true,channel:"msedge"});try{
const page=await browser.newPage({viewport:{width:1440,height:1100}});const errors=[];page.on('pageerror',e=>errors.push(e.message));
for(const width of [1440,390]){
 await page.setViewportSize({width,height:1000});
 for(const name of ['index.html','club.html','changelog.html','blog.html']){
  await page.goto('http://127.0.0.1:8768/'+name);
  assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'Horizontal overflow: '+name+' '+width);
  assert.equal(await page.getByAltText('Waldas Game Studios logo').count(),1);
  assert(!((await page.locator('body').innerText()).includes('Waldas Gamer Studios')));
  if(name==='index.html')await page.screenshot({path:'.local/home-club-'+width+'.png',fullPage:true});
 }
}
await page.setViewportSize({width:1440,height:1100});
await page.goto('http://127.0.0.1:8768/club.html');await page.screenshot({path:'.local/valley-club-signin.png',fullPage:true});
await page.route('https://ruyertoyvplpmzqflwdy.supabase.co/**',async route=>{const url=route.request().url();let data;if(url.includes('/token?'))data={access_token:'test-token',refresh_token:'test-refresh',expires_in:3600,user:{email:'test@example.invalid'}};else if(url.includes('/rest/'))data=[{revision:3,updated_at:'2026-10-02T12:00:00Z',payload:{coins:420,experience:{total:125},summary:{animals:2,day:3},terrain:[0,1,2,3,4,5,6,7],wildlife:{records:{hedgehog:{visit_day:1,resident_day:2}}}}}];else data={};await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(data)});});
await page.locator('#email').fill('test@example.invalid');await page.locator('#password').fill('Testing-fixture-123');await page.getByRole('button',{name:'Sign in',exact:true}).click();await page.locator('#dashboard').waitFor({state:'visible'});assert.equal(await page.locator('#coins').textContent(),'420');assert.equal(await page.locator('#animals').textContent(),'2');assert.equal(await page.locator('#level').textContent(),'Lv. 2');assert.equal(await page.locator('#terrain progress').count(),8);assert((await page.locator('#visitors').textContent()).includes('resident: day 2'));assert.equal(await page.locator('#password').inputValue(),'');
await page.getByRole('button',{name:'Sign out',exact:true}).click();await page.locator('#login').waitFor({state:'visible'});assert(await page.locator('#dashboard').isHidden());
await page.setViewportSize({width:390,height:844});await page.screenshot({path:'.local/valley-club-mobile.png',fullPage:true});assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));assert.deepEqual(errors,[]);console.log('CLUB_PASS: mocked login, private stats, land coverage, visits, logout, empty password and mobile layout');
}finally{await browser.close();server.close();}})().catch(e=>{console.error(e);server.close();process.exitCode=1;});

