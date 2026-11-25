// 1.1 optional modules for the bridge: plan, apply and undo, and the catalogue filtered by what is switched on.
// Same switches as the game (game/core/features.gd); same descriptions (update/modules.json, copied from the game's
// assets/update/modules.json when the package is assembled).
//
// <data>/features.json        {"version":1,"modules":{"<id>":true|false,...},"savedAt":"..."}  read by the game at start
// <data>/features.json.bak    the previous file, kept on every change
// <data>/update-receipts/     one JSON per change: {at, before, after, changed}; undo restores the newest "before"
//
// A module missing from features.json (or no file at all) counts as ON, exactly like the game.
// Nothing here talks to the game: a change takes effect when the game is restarted.
import fs from 'node:fs'; import path from 'node:path';
import { firstRun } from './first-run.mjs';

export function readDescriptions(file) {
  const d = JSON.parse(fs.readFileSync(file, 'utf8').replace(/^﻿/, ''));
  if (!Array.isArray(d.modules)) throw Error('update/modules.json has no modules');
  return d;
}

export function readFlags(dataDir, ids, fallback = true) {
  const file = path.join(dataDir, 'features.json');
  let saved = {};
  if (fs.existsSync(file)) { const d = JSON.parse(fs.readFileSync(file, 'utf8')); if (!d?.modules || typeof d.modules !== 'object' || Array.isArray(d.modules)) throw Error('features.json 的 modules 无效，请先恢复备份；不会重置原选择'); saved = d.modules; }
  return Object.fromEntries(ids.map(id => [id, typeof saved[id] === 'boolean' ? saved[id] : (fs.existsSync(file) ? true : fallback)]));
}

// What the bot may be offered, given the switches. Mirrors the game: the beach object, the second Tetris machine,
// Gomoku at the chess table and the allowance rule.
export function filterCatalog(catalog, flags) {
  const c = JSON.parse(JSON.stringify(catalog));
  if(flags.sharedChest12===false)c.objects=c.objects.filter(o=>o.id!=="qx_shared_chest");
  if(flags.village12===false){c.spaces=c.spaces.filter(s=>s.id!=='qingxi');for(const s of c.spaces)s.links=(s.links||[]).filter(id=>id!=='qingxi');c.objects=c.objects.filter(o=>o.space!=='qingxi');}
  const drop = new Set([...(flags['seaside-path'] ? [] : ['xj_beach']), ...(flags['arcade-renovated'] ? [] : ['arcade_blocks_2'])]);
  c.objects = (c.objects || []).filter(o => !drop.has(o.id));
  if (!flags.gomoku) for(const o of c.objects){
    if(o.uses?.some(u=>u.id==='play_gomoku')){
      o.uses=o.uses.filter(u=>u.id!=='play_gomoku');
      o.description='象棋桌。使用 play 开局，mode=npc 与电脑对战，duo 开桌，join 加入。';
    }
  }
  if (!flags['pocket-money-50'] && c.wallet) c.wallet = { ...c.wallet, daily: 20, cap: 80 };
  return c;
}

export class Updater {
  constructor({ dataDir, installDir = path.dirname(dataDir), descriptions, now = () => new Date() }) {
    Object.assign(this, { dataDir, installDir, now }); this.desc = descriptions; this.ids = descriptions.modules.map(m => m.id);
    this.file = path.join(dataDir, 'features.json'); this.receipts = path.join(dataDir, 'update-receipts');
  }
  selectedFlags() {
    const prior=fs.existsSync(this.file)?JSON.parse(fs.readFileSync(this.file,'utf8')):null;
    const hasProgress = ['world','saves'].some(dir => {
      const p = path.join(this.dataDir, dir);
      return fs.existsSync(p) && fs.readdirSync(p).length > 0;
    }) || fs.existsSync(path.join(this.dataDir, 'bridge.json'));
    const fresh = !prior && !hasProgress;
    const flags=readFlags(this.dataDir,this.ids,true);
    if (!prior && hasProgress) for (const m of this.desc.modules) flags[m.id]=!m.ask && Boolean(m.default);
    for(const m of this.desc.modules) if(m.generation===12 && typeof prior?.modules?.[m.id]!=='boolean')flags[m.id]=fresh||prior?.release12===true;
    return flags;
  }
  flags() {
    const flags = this.selectedFlags();
    for (const group of this.desc.modules) {
      for (const child of group.includes || []) flags[child] = flags[group.id];
    }
    return flags;
  }
  // For the model and the update menu: every module, its state and the plain-words explanation.
  plan() {
    const flags = this.selectedFlags();
    return {
      ok: true, release: this.desc.release, file: this.file, restartNeeded: 'A change takes effect after the game is restarted.',
      selectionStage: 'ai-assisted-upgrade', selectionMode: 'multiple', coreFixes: 'always', existingChoices: fs.existsSync(this.file),
      advice: '安装时主动先问是否有旧存档。选有则请玩家给旧游戏路径，导入后展示多选；选无则直接安装完整版。1.1 的选择已保留。请一起列出本次新增项，清溪村及配套内容作为一项。只提交玩家选择，取消或未答复均保持原状。',
      modules: this.desc.modules.filter(m => m.generation === 12).map(m => ({ id: m.id, name: m.name, state: flags[m.id] ? 'on' : 'off', default: m.default ? 'on' : 'off', askUser: true, options: [{label:'更新 / 启用这一项',value:true},{label:fs.existsSync(this.file)?'保留当前选择':'不更新，保留原版',value:flags[m.id]},{label:'关闭这一项 / 使用旧版',value:false}], summary: m.summary, changes: m.changes, keepOriginal: m.offSummary, looksDifferent: m.looksDifferent, touches: m.touches })),
    };
  }
  write(modules) {
    fs.mkdirSync(this.dataDir, { recursive: true });
    if (fs.existsSync(this.file)) fs.copyFileSync(this.file, this.file + '.bak');
    const existing = fs.existsSync(this.file) ? JSON.parse(fs.readFileSync(this.file, 'utf8')) : {};
    const tmp = this.file + '.' + process.pid + '.tmp';
    fs.writeFileSync(tmp, JSON.stringify({ ...existing, version: 1, release12:true, modules: {...existing.modules,...modules}, savedAt: this.now().toISOString() }, null, 2) + '\n');
    fs.renameSync(tmp, this.file);
  }
  // choice: {"<id>": true|false}. Unknown ids are refused; ids left out keep their state.
  apply(choice = {}, reason = '') {
    if (!choice || typeof choice !== 'object' || Array.isArray(choice)) throw Error('modules 必须是 {"模块id": true/false}');
    const unknown = Object.keys(choice).filter(id => !this.ids.includes(id)); if (unknown.length) throw Error('没有这些模块：' + unknown.join(', '));
    const bad = Object.entries(choice).filter(([, v]) => typeof v !== 'boolean').map(([k]) => k); if (bad.length) throw Error('模块的值只能是 true 或 false：' + bad.join(', '));
    const before = this.selectedFlags(), after = { ...before, ...choice };
    const changed = this.ids.filter(id => before[id] !== after[id]);
    if (!Object.keys(choice).length) return { ok: true, changed: [], note: '没有提供选择，保持当前内容' };
    const first = firstRun({dataDir:this.dataDir,installDir:this.installDir,descriptions:this.desc,now:this.now});
    if (!changed.length && first.skipped) return { ok: true, changed: [], note: '没有变化，保留原选择' };
    this.write(after);
    fs.mkdirSync(this.receipts, { recursive: true });
    const at = this.now().toISOString(), receipt = path.join(this.receipts, at.replace(/[:.]/g, '-') + '.json');
    fs.writeFileSync(receipt, JSON.stringify({ at, reason: String(reason || '').slice(0, 200), choice, before, after, changed }, null, 2) + '\n');
    return { ok: true, changed: changed.map(id => ({ id, state: after[id] ? 'on' : 'off' })), receipt, restart: '请完全关闭游戏后重新打开（start.cmd），更改才会生效。' };
  }
  undo() {
    // only dated change receipts (first-run.json is a record, not an undoable change)
    const list = fs.existsSync(this.receipts) ? fs.readdirSync(this.receipts).filter(f => /^\d{4}-.*\.json$/.test(f) && !f.endsWith('.undone.json')).sort() : [];
    if (!list.length) return { ok: false, error: '没有可以撤销的更改' };
    const file = path.join(this.receipts, list.at(-1)), r = JSON.parse(fs.readFileSync(file, 'utf8'));
    if (!r.before || !this.desc.modules.some(m => m.generation === 12 && Object.hasOwn(r.before, m.id))) return {ok:false,error:'已到 1.1 升级前的记录，原选择已保留'};
    this.write(r.before);
    fs.renameSync(file, file.replace(/\.json$/, '.undone.json'));
    return { ok: true, restored: r.before, undid: r.changed, restart: '请完全关闭游戏后重新打开（start.cmd），更改才会生效。' };
  }
}
