// Holds the button until a landmark is finished, then captures the moment: the
// turn around it, the card, and the town afterwards.
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http = require('http'); const fs = require('fs'); const path = require('path');
const root = process.argv[2], outDir = process.argv[3];
const port = 9100 + Math.floor(Math.random()*180);
const types = {'.html':'text/html','.js':'text/javascript','.json':'application/json','.wasm':'application/wasm','.png':'image/png','.ttf':'font/ttf','.otf':'font/otf','.wav':'audio/wav','.ico':'image/x-icon','.symbols':'text/plain','.bin':'application/octet-stream'};
const server = http.createServer((q,r)=>{let p=decodeURIComponent(q.url.split('?')[0]);if(p==='/')p='/index.html';const f=path.join(root,p);fs.readFile(f,(e,d)=>{if(e){r.writeHead(404);r.end();return;}r.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream','Cache-Control':'no-store'});r.end(d);});});
(async()=>{
  fs.mkdirSync(outDir,{recursive:true});
  await new Promise(r=>server.listen(port,r));
  const b = await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome',args:['--no-sandbox','--use-gl=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage']});
  const ctx = await b.newContext({viewport:{width:440,height:880},deviceScaleFactor:2});
  const page = await ctx.newPage();
  page.on('pageerror', e=>console.log('[ERR]', String(e).slice(0,300)));
  const ROBOTO = fs.readFileSync('/home/user/sdk/flutter/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf');
  await page.route('**://fonts.gstatic.com/**', r => r.fulfill({status:200, contentType:'font/ttf', body: ROBOTO}));
  await page.goto(`http://127.0.0.1:${port}/`,{waitUntil:'load'});
  await page.waitForTimeout(14000);
  await page.screenshot({path: path.join(outDir, 'a-antes.png')});

  await page.mouse.move(220, 795);
  await page.mouse.down();
  await page.waitForTimeout(1400);
  await page.mouse.up();

  const at = [500, 1200, 2200, 3600];
  let prev = 0;
  for (const ms of at) {
    await page.waitForTimeout(ms - prev); prev = ms;
    await page.screenshot({path: path.join(outDir, `t${String(ms).padStart(4,'0')}.png`)});
  }
  // Dismiss the card and look at the town again.
  await page.mouse.click(220, 300);
  await page.waitForTimeout(1200);
  await page.screenshot({path: path.join(outDir, 'z-despues.png')});
  console.log('ok');
  await b.close(); server.close();
})().catch(e=>{console.error(e);process.exit(1);});
