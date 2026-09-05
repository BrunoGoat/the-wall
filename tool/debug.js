const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http = require('http'); const fs = require('fs'); const path = require('path');
const root = process.argv[2]; const port = 9000 + Math.floor(Math.random()*900);
const types = { '.html':'text/html','.js':'text/javascript','.mjs':'text/javascript','.json':'application/json','.wasm':'application/wasm','.png':'image/png','.ttf':'font/ttf','.otf':'font/otf','.wav':'audio/wav','.ico':'image/x-icon','.symbols':'text/plain','.bin':'application/octet-stream'};
const server = http.createServer((req,res)=>{let p=decodeURIComponent(req.url.split('?')[0]);if(p==='/')p='/index.html';const f=path.join(root,p);fs.readFile(f,(e,d)=>{if(e){res.writeHead(404);res.end();return;}res.writeHead(200,{'Content-Type':types[path.extname(f)]||'application/octet-stream','Cache-Control':'no-store'});res.end(d);});});
(async()=>{
  await new Promise(r=>server.listen(port,r));
  const b = await chromium.launch({executablePath:'/opt/pw-browsers/chromium-1194/chrome-linux/chrome',args:['--no-sandbox','--use-gl=swiftshader','--enable-unsafe-swiftshader','--disable-dev-shm-usage']});
  const ctx = await b.newContext({viewport:{width:420,height:900}});
  const page = await ctx.newPage();
  page.on('console', m=>console.log('[c:'+m.type()+']', m.text().slice(0,500)));
  page.on('pageerror', e=>console.log('[ERR]', String(e).slice(0,1500)));
  page.on('response', r=>console.log('[res]', r.status(), r.url()));
  page.on('requestfailed', r=>console.log('[req-fail]', r.url().slice(0,120), r.failure()?.errorText));
  await page.route('**://fonts.gstatic.com/**', r=>r.abort());
  await page.route('**://www.gstatic.com/**', r=>r.abort());
  await page.goto(`http://127.0.0.1:${port}/`,{waitUntil:'load'});
  await page.waitForTimeout(30000);
  const info = await page.evaluate(()=>{
    const tags = [...document.body.querySelectorAll('*')].map(e=>e.tagName.toLowerCase());
    const counts = {}; tags.forEach(t=>counts[t]=(counts[t]||0)+1);
    return { counts, len: document.body.innerHTML.length,
             ck: typeof window.flutterCanvasKit,
             gl: (()=>{try{const c=document.createElement('canvas');return !!(c.getContext('webgl2')||c.getContext('webgl'));}catch(e){return 'throw '+e}})(),
             flutterKeys: Object.keys(window._flutter||{}),
             dartRan: typeof window.$__dart_deferred_initializers__,
             appRunner: !!(window._flutter && window._flutter.loader && window._flutter.loader.didCreateEngineInitializer),
             ua: navigator.userAgent };
  });
  console.log(JSON.stringify(info,null,1));
  await b.close(); server.close();
})();
