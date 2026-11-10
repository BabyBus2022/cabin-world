#!/usr/bin/env node
// 小屋世界桥 / Cabin World bridge — 参考实现，零依赖（Node.js 18+）。
//
// 它做两件事：
//  1. 当游戏的“宿主”：在 127.0.0.1 上监听，把端口和一次性 token 写进 <data>/world/game-link.json，
//     游戏启动后自己连上来（协议见 docs/PROTOCOL.md）。
//  2. 给你的机器人软件（AstrBot、QQAgent、任意语言）一个本机 HTTP 接口：
//     GET /v1/status、/v1/look、/v1/catalog、/v1/events，POST /v1/go、/v1/use、/v1/buy、/v1/eat、/v1/stop、/v1/tool …
//     详见 docs/HTTP-API.md。接口地址和访问 token 写在 <data>/bridge.json，只有本机能连。
//
// 它不调用任何 AI、不登录 QQ、不保存记忆。模型、人设、记忆都留在你的机器人软件里。
//
// 用法 / usage:  node bridge.mjs [--config bridge.config.json] [--no-launch]
import fs from 'node:fs'; import fsp from 'node:fs/promises'; import path from 'node:path'; import http from 'node:http'; import net from 'node:net';
import { spawn } from 'node:child_process'; import { randomBytes, timingSafeEqual } from 'node:crypto'; import { fileURLToPath } from 'node:url';
import { CabinHost } from './cabin-host.mjs';
import { Resident } from './lib/resident.mjs';
import { virtualWeather } from './lib/weather.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const say = (...a) => console.log('[小屋世界桥]', ...a);

/** 读取配置；相对路径都相对于配置文件所在目录。 */
export function loadConfig(file) {
  const raw = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8').replace(/^﻿/, '')) : {};
  const base = path.dirname(path.resolve(file));
  const rel = v => (v ? path.resolve(base, v) : v);
  return {
    resident: raw.resident || 'xiaojingyu',
    who: raw.who || raw.resident || 'xiaojingyu',
    displayName: raw.displayName || '小鲸鱼',
    hostName: String(raw.hostName || '我的机器人').slice(0, 40),
    dataDir: rel(raw.dataDir || '../data'),
    gameExe: rel(raw.gameExe || '../CabinWorld.exe'),
    launchGame: raw.launchGame !== false,
    http: { host: '127.0.0.1', port: Number(raw.http?.port ?? 18790) },
    weather: { mode: raw.weather?.mode === 'push' ? 'push' : 'virtual' },
    waitMs: Math.max(0, Math.min(Number(raw.waitMs ?? 45000), 600000)),
    catalog: rel(raw.catalog || path.join(HERE, 'catalog.json')),
  };
}

/** game-link.json 残留（上次崩溃）就清掉；若另一个宿主真的在用，则拒绝启动。 */
async function clearStaleLink(dataDir) {
  const file = path.join(dataDir, 'world', 'game-link.json');
  let row; try { row = JSON.parse(await fsp.readFile(file, 'utf8')); } catch { return; }
  const alive = await new Promise(resolve => { const s = net.connect({ host: '127.0.0.1', port: Number(row?.port) || 1 }); s.once('connect', () => { s.destroy(); resolve(true); }); s.once('error', () => resolve(false)); setTimeout(() => { s.destroy(); resolve(false); }, 1500); });
  if (alive) throw Error('另一个宿主（可能是另一个桥或 VADS）正在使用这份数据目录：' + file + '。先关掉它，或给这个桥换一个 dataDir。');
  await fsp.unlink(file); say('清理了上次残留的 game-link.json');
}

export async function startBridge(cfg, { launch = cfg.launchGame, engineArgs = [], userArgs = [], quiet = false } = {}) {
  const log = quiet ? () => {} : say;
  const catalog = JSON.parse(fs.readFileSync(cfg.catalog, 'utf8'));
  await fsp.mkdir(path.join(cfg.dataDir, 'world'), { recursive: true });
  await clearStaleLink(cfg.dataDir);
  let pushed = null; // POST /v1/weather 推送的真实天气
  const weather = () => (cfg.weather.mode === 'push' && pushed?.reading ? pushed.reading : virtualWeather(Date.now()));
  let resident;
  const host = new CabinHost({ dataDir: cfg.dataDir, name: cfg.hostName, audioSettings: false,
    onPanelGet: async frame => resident.panel(frame), onPanelDo: async () => ({ ok: false, error: '这项由机器人软件自己提供' }) });
  resident = new Resident({ host, key: cfg.resident, who: cfg.who, name: cfg.displayName, catalog, weather });
  const events = []; let eventSeq = 0;
  const pushEvent = e => { events.push({ seq: ++eventSeq, at: Date.now(), ...e }); if (events.length > 200) events.shift(); };
  resident.on('event', pushEvent);
  // 游戏每 15 秒收到一次天气；local（城市、温度…）只用于右上角的天气牌，可选。
  // 没有推送城市天气时，天气牌显示虚拟天气（标明来源），不会显示“天气待更新”。
  const localOf = r => ({ city: '小屋世界', condition: r.name, temperature: r.temp, wind: Math.round(r.wind * 6 * 10) / 10, source: '虚拟天气（未接真实天气）', at: Date.now(), fetchedAt: Date.now() });
  const sendWeather = () => { if (!host.connected) return; const reading = weather(); host.send({ type: 'weather', reading, local: pushed?.local && Date.now() - pushed.local.at < 90 * 60000 ? pushed.local : localOf(reading) }); };
  host.on('connected', caps => {
    log('游戏已连接（' + (caps.game || 'cabin-world') + '）');
    pushEvent({ type: 'game', connected: true });
    sendWeather();
    resident.open().then(() => log(`${cfg.displayName} 已就位：零花钱 ${resident.state?.wallet?.coins ?? '?'} 元`), e => log('初始化住户失败：' + e.message));
  });
  host.on('disconnected', () => { log('游戏断开（关闭窗口不会关闭桥，重新打开游戏会自动连回）'); pushEvent({ type: 'game', connected: false }); });
  host.on('frame', f => { if (f.type === 'quit') log('游戏窗口关闭了'); });
  await host.start();
  const timer = setInterval(() => { sendWeather(); resident.publish(); }, 15000); timer.unref();

  // ---- HTTP ----
  const token = randomBytes(24).toString('hex');
  const authed = req => { const h = String(req.headers.authorization || '').replace(/^Bearer\s+/i, '') || String(req.headers['x-cabin-token'] || ''); const a = Buffer.from(h), b = Buffer.from(token); return a.length === b.length && timingSafeEqual(a, b); };
  const waitTask = async (task, waitMs) => { if (waitMs > 0) await Promise.race([task.promise, new Promise(r => setTimeout(r, waitMs).unref())]); return taskView(task); };
  const taskView = t => ({ taskId: t.id, status: t.status, label: t.label, ...(t.status === 'done' ? { result: t.result } : {}), ...(t.status === 'failed' ? { error: t.error } : {}), ...(t.status === 'running' ? { hint: '还在进行中：稍后用 GET /v1/tasks/' + t.id + ' 查询，完成前不要当作已经做完' } : {}) });
  const need = () => { if (!host.connected) throw Object.assign(Error('游戏没有打开或还没连上。请先打开小屋世界。'), { status: 503 }); };
  const TOOLS = {
    cabin_status: () => ({ ok: true, ...resident.status() }),
    cabin_look: () => ({ ok: true, ...resident.look() }),
    cabin_go: a => { need(); return resident.go(a.place, a.zone); },
    cabin_use: a => { need(); return resident.use(a.object, a.use, { item: a.item, feeling: a.feeling }); },
    cabin_buy: a => { need(); return resident.buy(a.product, { feeling: a.feeling }); },
    cabin_eat: a => { need(); return resident.eat(a.product, { feeling: a.feeling }); },
    cabin_stop: () => resident.stop(),
  };
  const runTool = async (name, args = {}, waitMs = cfg.waitMs) => {
    const fn = TOOLS[name]; if (!fn) throw Object.assign(Error('没有这个工具：' + name), { status: 404 });
    const out = await fn(args || {});
    return out && out.promise ? waitTask(out, Number.isFinite(args.waitMs) ? args.waitMs : waitMs) : out;
  };
  const server = http.createServer(async (req, res) => {
    const send = (code, body) => { res.writeHead(code, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' }); res.end(JSON.stringify(body)); };
    try {
      // 浏览器网页不能调用（防止网页借你的浏览器操纵角色）/ refuse browser cross-site calls
      if (req.headers.origin) return send(403, { ok: false, error: 'browser requests are not allowed' });
      const url = new URL(req.url, 'http://127.0.0.1');
      if (url.pathname === '/v1/health') return send(200, { ok: true, game: host.connected, resident: cfg.resident });
      if (!authed(req)) return send(401, { ok: false, error: '缺少或错误的 token（见 data/bridge.json）' });
      let body = {};
      if (req.method === 'POST') {
        let raw = ''; for await (const c of req) { raw += c; if (raw.length > 65536) return send(413, { ok: false, error: 'too large' }); }
        try { body = raw ? JSON.parse(raw) : {}; } catch { return send(400, { ok: false, error: 'body must be JSON' }); }
        if (!body || typeof body !== 'object' || Array.isArray(body)) return send(400, { ok: false, error: 'body must be a JSON object' });
      }
      const route = req.method + ' ' + url.pathname;
      if (route === 'GET /v1/status') return send(200, await runTool('cabin_status'));
      if (route === 'GET /v1/look') return send(200, await runTool('cabin_look'));
      if (route === 'GET /v1/catalog') return send(200, catalog);
      if (route === 'GET /v1/tools') return send(200, JSON.parse(fs.readFileSync(path.join(HERE, 'openai-tools.json'), 'utf8')));
      if (route === 'GET /v1/events') { const after = Number(url.searchParams.get('after') || 0); return send(200, { ok: true, last: eventSeq, events: events.filter(e => e.seq > after) }); }
      if (req.method === 'GET' && url.pathname.startsWith('/v1/tasks/')) { const t = resident.tasks.get(url.pathname.slice(10)); return t ? send(200, taskView(t)) : send(404, { ok: false, error: '没有这个任务' }); }
      const map = { 'POST /v1/go': 'cabin_go', 'POST /v1/use': 'cabin_use', 'POST /v1/buy': 'cabin_buy', 'POST /v1/eat': 'cabin_eat', 'POST /v1/stop': 'cabin_stop' };
      if (map[route]) return send(200, await runTool(map[route], body));
      if (route === 'POST /v1/tool') {
        let args = body.arguments; if (typeof args === 'string') { try { args = JSON.parse(args || '{}'); } catch { return send(400, { ok: false, error: 'arguments must be JSON' }); } }
        return send(200, await runTool(String(body.name || ''), args || {}));
      }
      if (route === 'POST /v1/weather') {
        if (body.reading && typeof body.reading !== 'object') return send(400, { ok: false, error: 'reading must be an object' });
        pushed = { reading: body.reading ? { ...virtualWeather(Date.now()), ...body.reading } : null, local: body.local && typeof body.local === 'object' ? { ...body.local, at: Date.now(), fetchedAt: Date.now() } : null };
        sendWeather(); return send(200, { ok: true, mode: cfg.weather.mode, note: cfg.weather.mode === 'push' ? '已采用' : 'local 已显示；reading 需要把 weather.mode 设为 push 才会替代虚拟天气' });
      }
      return send(404, { ok: false, error: 'unknown endpoint, see docs/HTTP-API.md' });
    } catch (error) { send(error.status || (error.code === 'busy' ? 409 : 400), { ok: false, error: String(error.message || error) }); }
  });
  await new Promise((resolve, reject) => { server.once('error', e => reject(e.code === 'EADDRINUSE' ? Error(`端口 ${cfg.http.port} 已被占用：可能桥已经在运行；或在 bridge.config.json 里换一个 http.port（0 = 自动）`) : e)); server.listen(cfg.http.port, cfg.http.host, resolve); });
  const url = `http://127.0.0.1:${server.address().port}`;
  const infoFile = path.join(cfg.dataDir, 'bridge.json');
  await fsp.writeFile(infoFile, JSON.stringify({ url, token, resident: cfg.resident, pid: process.pid, at: Date.now() }, null, 2) + '\n', { mode: 0o600 });
  log('HTTP 接口：' + url + '（token 在 ' + infoFile + '）');

  let child = null;
  if (launch) {
    if (!fs.existsSync(cfg.gameExe)) log('找不到游戏：' + cfg.gameExe + '（只启动桥，可以手动打开游戏）');
    else {
      // 不传 --unit：桥退出时游戏不会被强制关闭；数据目录与桥一致。
      const owned = engineArgs.length > 0 || userArgs.length > 0; // 自检时由桥管理游戏进程
      child = spawn(cfg.gameExe, [...engineArgs, '--', '--data', cfg.dataDir, ...userArgs], { stdio: 'ignore', detached: !owned, windowsHide: owned });
      child.on('error', e => log('启动游戏失败：' + e.message)); if (!owned) child.unref();
      log('已打开游戏窗口');
    }
  }
  const close = async () => { clearInterval(timer); await new Promise(r => server.close(r)); await host.close(); try { const row = JSON.parse(await fsp.readFile(infoFile, 'utf8')); if (row.token === token) await fsp.unlink(infoFile); } catch { /* 已删除 */ } };
  return { host, resident, server, url, token, close, child, runTool };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2), ci = args.indexOf('--config');
  const cfgFile = ci >= 0 ? path.resolve(args[ci + 1]) : path.join(HERE, 'bridge.config.json');
  if (!fs.existsSync(cfgFile)) say('没有找到 ' + cfgFile + '，使用默认设置（可复制 bridge.config.example.json 修改）');
  const cfg = loadConfig(cfgFile);
  startBridge(cfg, { launch: !args.includes('--no-launch') && cfg.launchGame }).then(b => {
    say('准备好了。按 Ctrl+C 关闭桥（游戏窗口可以单独关）。');
    const stop = () => { void b.close().then(() => process.exit(0)); };
    process.once('SIGINT', stop); process.once('SIGTERM', stop);
  }, e => { say('启动失败：' + e.message); process.exit(1); });
}
