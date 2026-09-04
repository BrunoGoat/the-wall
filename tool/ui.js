const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http = require('http'); const fs = require('fs'); const path = require('path');
const root = process.argv[2], outDir = process.argv[3];
const port = 9200 + Math.floor(Math.random()*300);
const types = {'.html':'text/html','.js':'text/javascript','.json':'application/json','.wasm':'application/wasm','.png':'image/png','.ttf':'font/ttf','.otf':'font/otf','.wav':'audio/wav','.ico':'image/x-icon','.symbols':'text/plain','.bin':'application/octet-stream'};
const server = http.createServer((q,r)=>{let p=decodeURIComponent(q.url.split('?')[0]);if(p==='/')p='/index.html';const f=path.join(root,p);fs.readFile(f,(e,d)=>{if(e){r.writeHead(404);r.end();return;}r.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream','Cache-Control':'no-store'});r.end(d);});});
(async()=>{
  fs.mkdirSync(outDir,{recursive:true});
  await new Promise(r=>server.listen(port,r));
  const b = await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome',args:['--no-sandbox','--use-gl=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage']});
  const ctx = await b.newContext({viewport:{width:440,height:880},deviceScaleFactor:2});
  const page = await ctx.newPage();
  page.on('pageerror', e=>console.log('[ERR]', String(e).slice(0,400)));
  await page.route('**://fonts.gstatic.com/**', r=>r.abort());
  await page.route('**://www.gstatic.com/**', r=>r.abort());
  await page.goto(`http://127.0.0.1:${port}/`,{waitUntil:'load'});
  await page.waitForTimeout(13000);
  const shot = async n => { await page.screenshot({path: path.join(outDir, n+'.png')}); console.log('shot', n); };
  await shot('a-home');
  // place a brick: tap the first habit chip
  await page.mouse.click(120, 800);
  await page.waitForTimeout(220);
  await shot('b-falling');
  await page.waitForTimeout(1400);
  await shot('c-placed');
  // open the journey sheet from the top bar
  await page.mouse.click(220, 60);
  await page.waitForTimeout(1600);
  await shot('d-journey');
  await page.mouse.click(330, 128);   // ÉPICOS tab
  await page.waitForTimeout(1200);
  await shot('e-epics');
  await page.keyboard.press('Escape');
  await page.mouse.click(220, 300);
  await page.waitForTimeout(1200);
  await shot('f-after');
  await b.close(); server.close();
})().catch(e=>{console.error(e);process.exit(1);});
