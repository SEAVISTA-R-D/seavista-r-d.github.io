// The site's test: load the page in headless Chrome, the way a visitor
// would, and fail on anything a visitor would hit.
//
//   node tools/check.mjs [url]        default: the local preview
//
// Fails on: a request that errors or answers 4xx/5xx; a JavaScript
// exception or console error; a file the rendered page refers to that is
// not committed (so it would not be deployed); link-preview tags that do
// not point at SITE in tools/site.env. No packages: Chrome's DevTools
// protocol over Node's own WebSocket.
import {spawn, execFileSync} from 'node:child_process';
import {readFileSync, mkdtempSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, dirname} from 'node:path';
import {fileURLToPath} from 'node:url';

const S = join(dirname(fileURLToPath(import.meta.url)), '..');
const env = Object.fromEntries(readFileSync(join(S, 'tools/site.env'), 'utf8').split('\n')
  .filter((l) => /^\w+=/.test(l)).map((l) => l.split(/=(.*)/s).slice(0, 2)));
const url = process.argv[2] ?? `http://127.0.0.1:${env.PREVIEW_PORT}/`;
const tracked = new Set(execFileSync('git', ['-C', S, 'ls-files'], {encoding: 'utf8'}).split('\n').filter(Boolean));
const problems = [];

const port = 9300 + Math.floor(Math.random() * 500);
const profile = mkdtempSync(join(tmpdir(), 'site-check-'));
const chrome = spawn('chromium', ['--headless=new', '--no-sandbox', '--disable-crash-reporter', '--disable-breakpad', `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`,
  '--no-first-run', '--mute-audio', '--window-size=1366,900', 'about:blank'], {stdio: 'ignore', env: {...process.env, XDG_CONFIG_HOME: profile, XDG_CACHE_HOME: profile}});
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
try {
  let info;
  for (let i = 0; i < 50 && !info; i++) { await sleep(100); info = await fetch(`http://127.0.0.1:${port}/json/list`).then((r) => r.json()).catch(() => null); }
  const page = info?.find((t) => t.type === 'page') ?? (() => { throw new Error('check: Chrome did not start'); })();
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((ok, no) => { ws.onopen = ok; ws.onerror = no; });
  let id = 0; const pending = new Map(); const handlers = [];
  ws.onmessage = (e) => { const m = JSON.parse(e.data);
    if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); } else handlers.forEach((h) => h(m)); };
  const send = (method, params = {}) => new Promise((ok) => { const n = ++id; pending.set(n, ok); ws.send(JSON.stringify({id: n, method, params})); });

  const urls = new Map();
  handlers.push((m) => {
    if (m.method === 'Network.requestWillBeSent') urls.set(m.params.requestId, m.params.request.url);
    if (m.method === 'Network.responseReceived' && m.params.response.status >= 400)
      problems.push(`HTTP ${m.params.response.status}: ${m.params.response.url}`);
    if (m.method === 'Network.loadingFailed' && !m.params.canceled && !/ERR_ABORTED/.test(m.params.errorText))
      problems.push(`failed (${m.params.errorText}): ${urls.get(m.params.requestId)}`);
    if (m.method === 'Runtime.exceptionThrown') problems.push(`exception: ${m.params.exceptionDetails.exception?.description ?? m.params.exceptionDetails.text}`);
    if (m.method === 'Runtime.consoleAPICalled' && m.params.type === 'error') problems.push(`console error: ${m.params.args.map((a) => a.value ?? a.description).join(' ')}`);
  });
  await send('Network.enable'); await send('Runtime.enable'); await send('Page.enable');
  // A visitor's network, so third-party scripts (the counter) are judged too; the counter's own failures are its business.
  await send('Page.navigate', {url});
  await sleep(2500);
  await send('Runtime.evaluate', {expression: 'window.scrollTo(0, document.body.scrollHeight)'});
  await sleep(1500);
  const r = await send('Runtime.evaluate', {returnByValue: true, expression: `(() => {
    const out = new Set();
    for (const e of document.querySelectorAll('[src],[href],[poster],source,track')) for (const a of ['src', 'href', 'poster'])
      if (e.getAttribute(a)) out.add(new URL(e.getAttribute(a), location.href).href);
    const og = Object.fromEntries([...document.querySelectorAll('meta[property^="og:"]')].map((m) => [m.getAttribute('property'), m.content]));
    return {refs: [...out], og, origin: location.origin};
  })()`});
  const {refs, og, origin} = r.result.result.value;
  for (const ref of refs) {
    if (!ref.startsWith(origin + '/')) continue;
    const path = decodeURIComponent(new URL(ref).pathname.slice(1)) || 'index.html';
    if (!tracked.has(path)) problems.push(`not committed, so not deployed: ${path}`);
  }
  for (const [k, want] of [['og:url', env.SITE + '/'], ['og:image', env.SITE + '/og-card.png']])
    if (og[k] !== want) problems.push(`${k} is ${og[k] ?? 'missing'}, should be ${want}`);
  console.log(`check: ${url} -- ${refs.length} references, ${problems.length ? problems.length + ' problem(s)' : 'all good'}`);
  ws.close();
} finally {
  chrome.kill(); await sleep(200); rmSync(profile, {recursive: true, force: true});
}
for (const p of problems) console.log('  ' + p);
const size = execFileSync('bash', ['-c', `cd '${S}' && git ls-files -z | grep -zv -e '^tools/' -e '^README.md$' -e '^.gitignore$' | du -ch --files0-from=- | tail -1`], {encoding: 'utf8'}).split('\t')[0];
console.log(`check: ${size} would be deployed`);
process.exit(problems.length ? 1 : 0);
