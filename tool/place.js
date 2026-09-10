// Presses the place button and captures the frames right after the landing, so
// the drop, the squash, the ring and the completion flourish can actually be
// looked at instead of guessed at.
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http = require('http'); const fs = require('fs'); const path = require('path');
const root = process.argv[2], outDir = process.argv[3];
const port = 9300 + Math.floor(Math.random()*180);
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

  // What it looks like while it is waiting: the ghost of the next piece.
  await page.screenshot({path: path.join(outDir, 'a-idle.png')});
  await page.mouse.move(220, 795);
  await page.mouse.down();
  await page.waitForTimeout(240);
  await page.screenshot({path: path.join(outDir, 'b-held.png')});
  await page.mouse.up();
  await page.waitForTimeout(2600);

  // Hold the place button long enough for it to fire, then let go.
  const bx = 220, by = 795;
  await page.mouse.move(bx, by);
  await page.mouse.down();
  await page.waitForTimeout(1400);
  await page.mouse.up();

  // The fall is ~0.36s and the flourish runs about two seconds.
  const at = [60, 130, 210, 300, 420, 620, 1000, 1800];
  let prev = 0;
  for (const ms of at) {
    await page.waitForTimeout(ms - prev); prev = ms;
    await page.screenshot({path: path.join(outDir, `t${String(ms).padStart(4,'0')}.png`)});
  }
  console.log('shot', at.length, 'frames');
  await b.close(); server.close();
})().catch(e=>{console.error(e);process.exit(1);});
