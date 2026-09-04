const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');

const root = process.argv[2];
const outDir = process.argv[3] || '/tmp/claude-0/shots';
const port = 9900 + Math.floor(Math.random()*90);
fs.mkdirSync(outDir, { recursive: true });

const types = { '.html':'text/html', '.js':'text/javascript', '.mjs':'text/javascript',
  '.json':'application/json', '.wasm':'application/wasm', '.png':'image/png',
  '.ttf':'font/ttf', '.otf':'font/otf', '.wav':'audio/wav', '.ico':'image/x-icon',
  '.symbols':'text/plain', '.bin':'application/octet-stream' };

const server = http.createServer((req, res) => {
  let p = decodeURIComponent(req.url.split('?')[0]);
  if (p === '/') p = '/index.html';
  const f = path.join(root, p);
  fs.readFile(f, (err, data) => {
    if (err) { res.writeHead(404); res.end('nope'); return; }
    res.writeHead(200, {
      'Content-Type': types[path.extname(f)] || 'application/octet-stream',
      'Cache-Control': 'no-store',
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    });
    res.end(data);
  });
});

(async () => {
  await new Promise(r => server.listen(port, r));
  const browser = await chromium.launch({
    executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
    args: ['--no-sandbox', '--use-gl=swiftshader', '--enable-unsafe-swiftshader',
           '--disable-dev-shm-usage', '--autoplay-policy=no-user-gesture-required'],
  });
  const ctx = await browser.newContext({ viewport: { width: 420, height: 900 }, deviceScaleFactor: 2 });
  const page = await ctx.newPage();
  page.on('console', m => { const t = m.text(); if (/error|exception|failed/i.test(t)) console.log('  [console]', t.slice(0,300)); });
  page.on('pageerror', e => console.log('  [pageerror]', String(e).slice(0,400)));

  await page.route('**://fonts.gstatic.com/**', r=>r.abort());
  await page.route('**://www.gstatic.com/**', r=>r.abort());
  await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: 'load' });
  await page.waitForTimeout(14000);

  const cx = 210, cy = 430;
  async function drag(dx, dy, steps = 14) {
    await page.mouse.move(cx, cy);
    await page.mouse.down();
    for (let i = 1; i <= steps; i++) {
      await page.mouse.move(cx + dx * i / steps, cy + dy * i / steps);
      await page.waitForTimeout(12);
    }
    await page.mouse.up();
    await page.waitForTimeout(900);
  }
  async function wheel(dy) { await page.mouse.move(cx, cy); await page.mouse.wheel(0, dy); await page.waitForTimeout(900); }

  const shots = [];
  async function shot(name) {
    const f = path.join(outDir, name + '.png');
    await page.screenshot({ path: f });
    shots.push(f);
    console.log('  shot', name);
  }

  await shot('01-default');
  await wheel(-600);            // zoom in
  await shot('02-close');
  await wheel(900);             // back out
  await drag(0, -190);          // pitch up toward top-down
  await shot('03-topdown');
  await drag(0, 150);
  await drag(240, 0);           // orbit around
  await shot('04-orbit');
  await drag(240, 0);           // keep going, look from behind
  await shot('05-behind');
  await wheel(1400);            // pull way back: the long silhouette
  await shot('06-far');

  // Head-on at eye level: the clearest read on how the courses actually sit.
  await drag(-240, 0); await drag(-240, 0); await drag(-240, 0);
  await page.waitForTimeout(600);
  await shot('07-front');
  await wheel(-1200);
  await shot('08-front-close');

  await browser.close();
  server.close();
  console.log(JSON.stringify(shots));
})().catch(e => { console.error('FAILED', e); process.exit(1); });
