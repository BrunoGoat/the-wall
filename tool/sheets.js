const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http = require('http'); const fs = require('fs'); const path = require('path');
const root = process.argv[2], outDir = process.argv[3];
const port = 9700 + Math.floor(Math.random()*200);
const types = {'.html':'text/html','.js':'text/javascript','.json':'application/json','.wasm':'application/wasm','.png':'image/png','.ttf':'font/ttf','.otf':'font/otf','.wav':'audio/wav','.ico':'image/x-icon','.symbols':'text/plain','.bin':'application/octet-stream'};
const server = http.createServer((q,r)=>{let p=decodeURIComponent(q.url.split('?')[0]);if(p==='/')p='/index.html';const f=path.join(root,p);fs.readFile(f,(e,d)=>{if(e){r.writeHead(404);r.end();return;}r.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream','Cache-Control':'no-store'});r.end(d);});});
(async()=>{
  fs.mkdirSync(outDir,{recursive:true});
  await new Promise(r=>server.listen(port,r));
  const b = await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome',args:['--no-sandbox','--use-gl=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage']});
  const ctx = await b.newContext({viewport:{width:440,height:880},deviceScaleFactor:2});
  const page = await ctx.newPage();
  page.on('pageerror', e=>console.log('[ERR]', String(e).slice(0,400)));
  // Serve the engine's own Roboto instead of letting the blocked CDN fetch
  // stall startup: without a font, every screenshot comes back wordless.
  const ROBOTO = fs.readFileSync('/home/user/sdk/flutter/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf');
  await page.route('**://fonts.gstatic.com/**', r =>
    r.fulfill({status:200, contentType:'font/ttf', body: ROBOTO}));
  await page.goto(`http://127.0.0.1:${port}/`,{waitUntil:'load'});
  await page.waitForTimeout(13000);
  const shot = async n => { await page.screenshot({path: path.join(outDir, n+'.png')}); console.log('shot', n); };

  // open the journey sheet from the top bar
  await page.mouse.click(200, 60);
  await page.waitForTimeout(1400);
  await shot('1-summary');

  // HITOS tab
  await page.mouse.click(213, 208);
  await page.waitForTimeout(900);
  await shot('2-milestones');

  // LEYENDAS tab
  await page.mouse.click(300, 208);
  await page.waitForTimeout(900);
  await shot('3-legends');

  // back to LA MURALLA, scroll to the bottom, open the debug sheet
  await page.mouse.click(120, 208);
  await page.waitForTimeout(700);
  await page.mouse.move(220, 600);
  await page.mouse.wheel(0, 1400);
  await page.waitForTimeout(900);
  await shot('4-settings');
  await b.close(); server.close();
})().catch(e=>{console.error(e);process.exit(1);});
