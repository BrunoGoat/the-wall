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
  await page.route('**://fonts.gstatic.com/**', r=>r.abort());
  await page.route('**://www.gstatic.com/**', r=>r.abort());
  await page.goto(`http://127.0.0.1:${port}/`,{waitUntil:'load'});
  await page.waitForTimeout(13000);
  await page.screenshot({path: path.join(outDir,'0-before.png')});
  // Sigil positions read off the reference frame.
  const spots = [[126,425],[245,524],[302,511],[75,474],[210,455]];
  for (let i = 0; i < spots.length; i++) {
    await page.mouse.click(spots[i][0], spots[i][1]);
    await page.waitForTimeout(1500);
    await page.screenshot({path: path.join(outDir, `${i+1}-tap.png`)});
    console.log('tapped', spots[i]);
    await page.mouse.click(220, 200); // dismiss whatever opened
    await page.waitForTimeout(700);
  }
  await b.close(); server.close();
})().catch(e=>{console.error(e);process.exit(1);});
