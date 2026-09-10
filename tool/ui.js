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

  const BTN = {x: 220, y: 812};
  await shot('a-home');

  // hold the button: half way, then all the way
  await page.mouse.move(BTN.x, BTN.y);
  await page.mouse.down();
  await page.waitForTimeout(700);
  await shot('b-charging');
  await page.waitForTimeout(1200);          // past the 1250ms threshold
  await shot('c-placed');
  await page.mouse.up();
  await page.waitForTimeout(1600);
  await shot('d-settled');

  // tap a stone to open its card
  for (const [x,y] of [[150,470],[210,505],[120,520],[260,480]]) {
    await page.mouse.click(x, y);
    await page.waitForTimeout(900);
    const found = await page.screenshot({encoding:'base64'});
    await shot('e-stone');
    break;
  }
  // open the note editor
  await page.mouse.click(150, 640);
  await page.waitForTimeout(1400);
  await shot('f-editor');
  await page.keyboard.type('Leí');
  await page.waitForTimeout(500);
  await shot('g-typed');
  await page.keyboard.press('Enter');
  await page.waitForTimeout(1600);
  await shot('h-saved');

  await b.close(); server.close();
})().catch(e=>{console.error(e);process.exit(1);});
