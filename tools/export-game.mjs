#!/usr/bin/env node
// 从 game/ 源码导出 Windows 版 CabinWorld.exe。
// Export the game from source. Needs Godot 4.7.2 and its export templates (Editor → Manage Export Templates,
// or install Godot_v4.7.2-stable_export_templates.tpz once).
// Usage: node tools/export-game.mjs <Godot_v4.7.2-stable_win64_console.exe> [output exe]
import fs from 'node:fs'; import path from 'node:path'; import { spawnSync } from 'node:child_process'; import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const options = process.argv.slice(2);
const mochiOnly = options.includes('--mochi-staff');
const [godot, target] = options.filter(value => value !== '--mochi-staff');
const out = path.resolve(target || path.join(root, 'build', 'CabinWorld.exe'));
if (!godot || !fs.existsSync(godot)) { console.error('用法: node tools/export-game.mjs <Godot 4.7.2 console exe> [输出路径]'); process.exit(2); }
fs.mkdirSync(path.dirname(out), { recursive: true });
const game = path.join(root, 'game');
const run = args => {
  const result = spawnSync(path.resolve(godot), args, { encoding:'utf8', maxBuffer:16 * 1024 * 1024, timeout:900000 });
  process.stdout.write(result.stdout || '');
  process.stderr.write(result.stderr || '');
  if (result.status !== 0 || /SCRIPT ERROR:|Failed to load script/.test(result.stderr || '')) {
    throw result.error || Error('Godot 导入或导出失败');
  }
};

// Produce a clean export without changing the working tree or its Godot import cache.
const work = fs.mkdtempSync(path.join(path.dirname(out), '.cabin-export-'));
const staged = mochiOnly ? path.join(work,'game') : game;
const product = path.join(work,path.basename(out));
try {
  if (mochiOnly) {
    fs.cpSync(game, staged, { recursive:true, filter:source => {
      const name = path.basename(source);
      return name !== '.godot' && !/^(naiwa-.*|shop-cashier-.*)\.png(?:\.import)?$/i.test(name);
    }});
    const catalog = path.join(staged, 'assets', 'npcs.json');
    const data = JSON.parse(fs.readFileSync(catalog, 'utf8'));
    delete data.skins.naiwa;
    for (const rows of Object.values(data)) {
      if (!Array.isArray(rows)) continue;
      for (const actor of rows) {
        if (actor?.skin === 'naiwa') actor.skin = 'mochi';
      }
    }
    fs.writeFileSync(catalog, JSON.stringify(data, null, 2) + '\n');
  }
  run(['--headless', '--path', staged, '--import']);
  run(['--headless', '--path', staged, '--export-release', 'Windows Desktop', product]);
  fs.renameSync(product,out);
  console.log('导出完成: ' + out + '（' + Math.round(fs.statSync(out).size / 1048576) + ' MB）');
} finally {
  fs.rmSync(work, { recursive:true, force:true });
}
