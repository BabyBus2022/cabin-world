import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {randomUUID} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {loadConfig} from '../bridge/bridge.mjs';
import {firstRun} from '../bridge/lib/first-run.mjs';
import {readDescriptions} from '../bridge/lib/update.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const config = loadConfig(path.join(root,'bridge/bridge.config.json'));
const data = config.dataDir;
const marker = path.join(data,'installation-1.2.json');
const desc = readDescriptions(path.join(root,'bridge/update/modules.json'));
const read = file => JSON.parse(fs.readFileSync(file,'utf8').replace(/^\uFEFF/,''));
function status() {
  if (fs.existsSync(marker)) {
    const state = read(marker).state;
    if (!['choose','fresh','ready'].includes(state)) throw Error('安装记录损坏，请保留当前目录并重新解压安装包。');
    return state;
  }
  return 'ask';
}
function record(state) {
  fs.mkdirSync(data,{recursive:true});
  const temp=marker+'.'+randomUUID()+'.tmp';
  fs.writeFileSync(temp,JSON.stringify({version:1,state})+'\n');
  fs.renameSync(temp,marker);
}
function setup(action,args) {
  const state=status();
  if (action==='status') return state;
  if (action==='finish' && state==='ready') return state;
  if (action==='finish' && state==='choose') {record('ready');return 'ready';}
  if (action==='fresh' && (state==='ask' || state==='fresh')) {
    if (state==='ask') {
      const files=fs.existsSync(data)?fs.readdirSync(data).filter(n=>n!=='.gitkeep'):[];
      if (files.length) throw Error('当前目录已有数据。请把完整 ZIP 解压到另一个新目录再安装，已有游戏进度会保留。');
      record('fresh');
    }
    firstRun({dataDir:data,installDir:root,descriptions:desc});
    record('ready');
    return 'ready';
  }
  if (state!=='ask') throw Error('已有安装进度，请继续当前步骤。');
  if (action==='import' && args.length===1) {
    let from=path.resolve(args[0].trim().replace(/^"(.*)"$/,'$1'));
    if (path.basename(from).toLowerCase()==='cabinworld.exe') from=path.dirname(from);
    if (!fs.existsSync(path.join(from,'cabinworld.ini')) && fs.existsSync(path.join(from,'CabinWorld','cabinworld.ini'))) from=path.join(from,'CabinWorld');
    if (!fs.existsSync(path.join(from,'CabinWorld.exe')) || !fs.existsSync(path.join(from,'bridge/bridge.config.json'))) throw Error('没有找到旧版小屋世界，请选择包含 CabinWorld.exe 的旧游戏文件夹。');
    const result=spawnSync(process.execPath,[path.join(root,'tools/import-1.1.mjs'),from],{encoding:'utf8',windowsHide:true});
    if (result.error) throw result.error;
    if (result.status!==0) throw Error(result.stderr.trim()||'未能导入旧存档。');
    return status();
  }
  throw Error('请按安装顺序使用 status、fresh、import <旧游戏目录> 或 finish。');
}
try {
  console.log(setup(process.argv[2],process.argv.slice(3)));
} catch (e) {console.error(e.message);process.exitCode=1;}

