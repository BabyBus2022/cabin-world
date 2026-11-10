#!/usr/bin/env node
// 从 game/ 源码导出 Windows 版 CabinWorld.exe。
// Export the game from source. Needs Godot 4.7.2 and its export templates (Editor → Manage Export Templates,
// or install Godot_v4.7.2-stable_export_templates.tpz once).
// Usage: node tools/export-game.mjs <Godot_v4.7.2-stable_win64_console.exe> [output exe]
import fs from 'node:fs'; import path from 'node:path'; import { spawnSync } from 'node:child_process'; import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const godot = process.argv[2], out = path.resolve(process.argv[3] || path.join(root, 'build', 'CabinWorld.exe'));
if (!godot || !fs.existsSync(godot)) { console.error('用法: node tools/export-game.mjs <Godot 4.7.2 console exe> [输出路径]'); process.exit(2); }
fs.mkdirSync(path.dirname(out), { recursive: true });
const game = path.join(root, 'game');
const run = args => { const r = spawnSync(godot, args, { stdio: 'inherit', timeout: 900000 }); if (r.status !== 0) { console.error('Godot 退出码 ' + r.status); process.exit(1); } };
run(['--headless', '--path', game, '--import']);
run(['--headless', '--path', game, '--export-release', 'Windows Desktop', out]);
console.log('导出完成: ' + out + '（' + Math.round(fs.statSync(out).size / 1048576) + ' MB）');
