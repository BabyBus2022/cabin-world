// Run from a newly extracted public release with both games and bridges closed.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const target=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const read=p=>JSON.parse(fs.readFileSync(p,'utf8').replace(/^\uFEFF/,''));
function inside(root,p){const r=path.relative(root,p);return r===''||(!path.isAbsolute(r)&&r!=='..'&&!r.startsWith('..'+path.sep));}
function copyTree(src,dest) {
  if(!fs.existsSync(src))return;
  fs.cpSync(src,dest,{recursive:true,filter:p=>{
    if(fs.lstatSync(p).isSymbolicLink())throw Error('发现链接，请按升级说明单独复制实际数据目录：'+p);
    const rel=path.relative(src,p).split(path.sep).join('/');
    return !['bridge.json','world/game-link.json'].includes(rel);
  }});
}
function run() {
  const [from,...extra]=process.argv.slice(2);
  if(!from||extra.length)throw Error('用法：runtime/node.exe tools/import-1.1.mjs "旧版 CabinWorld 目录"');
  const old=fs.realpathSync(path.resolve(from));
  if(inside(old,target)||inside(target,old))throw Error('请将 1.2 完整解压到独立的新目录。');
  const configFile='bridge/bridge.config.json';
  const config=read(path.join(old,configFile)), destConfig=path.join(target,configFile);
  const next=read(destConfig);
  const ini=Object.fromEntries(fs.readFileSync(path.join(old,'cabinworld.ini'),'utf8').split(/\r?\n/).filter(s=>s.includes('=')).map(s=>{const i=s.indexOf('=');return [s.slice(0,i).trim(),s.slice(i+1).trim()];}));
  if(process.env.CABINWORLD_DATA||process.env.CABINWORLD_SAVE)throw Error('检测到环境变量覆盖存档位置，请按 INSTALL-AI.md 的自定义路径步骤迁移。');
  const data=path.resolve(old,ini.data||'data'),save=path.resolve(old,ini.save||'data/saves');
  if(path.relative(data,path.resolve(old,'bridge',config.dataDir||'../data'))!=='')throw Error('旧游戏和桥的数据路径不同，请先确认实际使用的存档。');
  if(!fs.existsSync(data)||!fs.statSync(data).isDirectory())throw Error('找不到旧版数据目录：'+data);
  const dest=path.join(target,'data');
  for(const src of [data,save])if(inside(src,target)||inside(target,src))throw Error('新旧数据路径重叠，请使用独立目录。');
  if(next.dataDir!=='../data'||fs.existsSync(dest)&&fs.readdirSync(dest).some(n=>n!=='.gitkeep'))throw Error('新版已有数据或使用了自定义路径，请重新解压到空目录再迁移。');
  for(const k of ['resident','residents','who','displayName','hostName','http','weather','waitMs','launchGame'])if(Object.hasOwn(config,k))next[k]=config[k];
  const stage=fs.mkdtempSync(path.join(target,'.import-'));
  const staged=path.join(stage,'data');
  copyTree(data,staged);
  if(path.relative(save,path.join(data,'saves'))!==''){
    if(!fs.existsSync(save))throw Error('找不到配置中的自定义存档目录：'+save);
    if(fs.existsSync(path.join(staged,'saves'))&&fs.readdirSync(path.join(staged,'saves')).length)throw Error('发现两份存档，请按升级说明选择实际使用的存档副本。');
    copyTree(save,path.join(staged,'saves'));
  }
  if(!fs.existsSync(path.join(staged,'features.json')))fs.writeFileSync(path.join(staged,'features.json'),JSON.stringify({version:1,modules:{},firstRun:'import-from-1.1'}));
  fs.writeFileSync(path.join(staged,'installation-1.2.json'),JSON.stringify({version:1,state:'choose'})+'\n');
  fs.writeFileSync(path.join(stage,'config.json'),JSON.stringify(next,null,2)+'\n');
  const empty=path.join(stage,'prior-data');
  const had=fs.existsSync(dest);
  if(had)fs.renameSync(dest,empty);
  try{
    fs.renameSync(staged,dest);
    try{fs.renameSync(path.join(stage,'config.json'),destConfig);}
    catch(e){fs.renameSync(dest,staged);throw e;}
  }catch(e){if(had)fs.renameSync(empty,dest);throw e;}
  if(had){const keep=path.join(empty,'.gitkeep');if(fs.existsSync(keep))fs.unlinkSync(keep);fs.rmdirSync(empty);}
  fs.rmdirSync(stage);
  console.log('1.1 进度已复制到 '+dest+'。原安装保留。升级助手可读取 bridge/update-cli.mjs --plan。');
}
try{run();}catch(e){console.error(e.message);process.exitCode=1;}
