const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http = require('http'); const fs = require('fs'); const path = require('path');
const root = process.argv[2], outDir = process.argv[3];
const port = 9800 + Math.floor(Math.random()*180);
const types = {'.html':'text/html','.js':'text/javascript','.json':'application/json','.wasm':'application/wasm','.png':'image/png','.ttf':'font/ttf','.otf':'font/otf','.wav':'audio/wav','.ico':'image/x-icon','.symbols':'text/plain','.bin':'application/octet-stream'};
const server = http.createServer((q,r)=>{let p=decodeURIComponent(q.url.split('?')[0]);if(p==='/')p='/index.html';const f=path.join(root,p);fs.readFile(f,(e,d)=>{if(e){r.writeHead(404);r.end();return;}r.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream','Cache-Control':'no-store'});r.end(d);});});
(async()=>{
  fs.mkdirSync(outDir,{recursive:true});
  await new Promise(r=>server.listen(port,r));
  const b = await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome',args:['--no-sandbox','--use-gl=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage']});
  const ctx = await b.newContext({viewport:{width:440,height:874},deviceScaleFactor:2});
  const page = await ctx.newPage();
  page.on('pageerror', e=>console.log('[ERR]', String(e).slice(0,300)));
  const ROBOTO = fs.readFileSync('/home/user/sdk/flutter/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf');
  await page.route('**://fonts.gstatic.com/**', r => r.fulfill({status:200, contentType:'font/ttf', body: ROBOTO}));
  await page.goto(`http://127.0.0.1:${port}/`,{waitUntil:'load'});
  await page.waitForTimeout(13000);
  const shot = async n => { await page.screenshot({path: path.join(outDir, n+'.png')}); console.log('shot', n); };

  const drag = async (dx, dy, steps=24) => {
    await page.mouse.move(220, 430);
    await page.mouse.down();
    for (let i=1;i<=steps;i++) await page.mouse.move(220 + dx*i/steps, 430 + dy*i/steps);
    await page.mouse.up();
    await page.waitForTimeout(1400);
  };
  const zoom = async (n) => {
    for (let i=0;i<n;i++) { await page.mouse.move(220,430); await page.mouse.wheel(0, 240); await page.waitForTimeout(60); }
    await page.waitForTimeout(1600);
  };

  await shot('a-start');
  await zoom(14);                    // right out
  await shot('b-zoomed-out');
  await drag(-190, 0);               // spin
  await shot('c-spun');
  await drag(-190, 0);
  await shot('d-spun2');
  await drag(0, 150);                // pitch up towards top-down
  await shot('e-topdown');
  await drag(0, -260);               // pitch all the way down to eye level
  await shot('f-lowangle');
  await drag(-150, 0);
  await shot('g-low-spun');
  await zoom(-10);                   // back in close, still low
  await shot('h-low-close');
  await b.close(); server.close();
})().catch(e=>{console.error(e);process.exit(1);});
