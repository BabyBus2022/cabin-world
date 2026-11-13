#!/usr/bin/env node
// 由 bridge/catalog.json 生成 docs/AI-MANUAL.md（给机器人/AI 读的家具与物品说明书）。
// Regenerate after changing the catalogue:  node tools/gen-manual.mjs
import fs from 'node:fs'; import path from 'node:path'; import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const c = JSON.parse(fs.readFileSync(path.join(root, 'bridge/catalog.json'), 'utf8'));
// 1.1: the tool table comes from the tool file itself, and the hand-written guide (docs/AI-GUIDE.md) goes first.
const toolList = (t => t.tools || t)(JSON.parse(fs.readFileSync(path.join(root, 'bridge/openai-tools.json'), 'utf8')));
const guide = fs.existsSync(path.join(root, 'docs/AI-GUIDE.md')) ? fs.readFileSync(path.join(root, 'docs/AI-GUIDE.md'), 'utf8').replace(/^# .*\n/, '').trim() : '';
const sec = s => (s >= 60 ? Math.round(s / 60) + ' 分钟' : s + ' 秒');
const KIND = { eat: '吃', drink: '喝', use: '用' };
const SHELF = { snack: '零食', drink: '冷饮', hotdrink: '热饮', icecream: '冰淇淋', daily: '日用品' };
const out = [];
const w = (...l) => out.push(...l);
w('# 小屋世界 · 家具与物品说明书（给 AI 读）', '',
  '> 本文件由 `tools/gen-manual.mjs` 从 `bridge/catalog.json`（游戏数据）自动生成。可以整段放进你的机器人的系统提示词或知识库。',
  '> English summary: this is the in-world manual for the AI resident: every room, spot, piece of furniture, what each use does, how long it takes, and every shop item. Tool names refer to `bridge/openai-tools.json`.', '',
  '## 你是谁、在哪里', '',
  '你在“小屋世界”里有一个真实的身体（角色 key `xiaojingyu`，名字可以由使用者改）。身体由游戏掌管：走路要真的走过去，用东西要真的走到旁边做完，钱和背包都记在游戏存档里。',
  '你只能通过工具去做事；**不要凭空描述自己做了什么**，以工具返回的结果为准。工具返回 `status: "running"` 表示还没做完，做完之前不要说“已经做好了”。', '',
  '| 工具 | 用来 |', '|---|---|',
  ...toolList.map(t => `| \`${t.function.name}\` | ${String(t.function.description || '').split(/[。.]/)[0].replace(/\|/g, '/')} |`), '',
  ...(guide ? ['## 1.1 接入规则', '', guide, ''] : []),
  '## 基本规则', '',
  `- **一次只做一件事。** 正在做事时再下指令会被拒绝（“先做完这件事”），可以先 \`cabin_stop\`。`,
  `- **零花钱：** 新住户有 ${c.wallet.start} 元；每天（北京时间）第一次活动时游戏发零花钱：1.1 模块“每天 50 零花钱”打开时每天 50、最多存 300，关闭时每天 20、最多 80（以 \`cabin_status\` 实际的钱为准）。钱不够买不了。价格每天可能有特价，以游戏为准。`,
  `- **背包：** 最多 ${c.wallet.bagSlots} 件。买的东西先进背包，吃/喝/用完才扣掉；中途被打断东西还在。雨伞这类“可以留着的”东西用了也不会消失。`,
  '- **身体感受：** `feeling` 里 `satiety` 饱腹、`hydration` 口渴程度（越低越渴）、`joy` 开心、`energy` 精力、`calm` 平静、`warmth` 暖和，都是 0–100，会随时间慢慢变化。饿了就去买吃的，渴了买喝的；天冷喝热饮、天热吃冰淇淋会更舒服。',
  '- **天气和时间：** 世界跟随北京时间昼夜变化；天气由机器人软件提供（默认是虚拟天气）。下雨时滑梯是湿的，有风才适合放风筝，晴天树荫下凉快。',
  '- **结果由游戏决定：** 钓鱼钓到什么、风筝飞多高、打水漂几下，都是游戏算出来的，照实说就好。',
  '- **汤屋：** 去泡汤、游泳、淋浴前会自动先在更衣处换上浴衣；离开前可以 `onsen_locker / change_back` 换回自己的衣服。',
  '- **别人的家：** 每位住户有自己的家，只有主人能进；去别人家下棋要主人用 `cabin_invite` 邀请。新住户由使用者在设置里添加，或用 `cabin_add_resident`。',
  '- **记忆：** 本插件不保存你的记忆。工具返回的 `happened`（发生了什么、感受）请由你的机器人软件自己记下来。', '');
w('## 地图', '', '```', '小鲸鱼家(xjhome) ── 公园(park) ── 小卖部(shop) ── 汤屋(onsen)', '                     │  └──── 电玩城(arcade)', '                     └─────── 餐厅(restaurant)', '```', '',
  '| 地方 id | 名字 | 室外 | 通往 |', '|---|---|---|---|');
for (const s of c.spaces) w(`| \`${s.id}\` | ${s.fullName} | ${s.outdoor ? '是' : '否'} | ${s.links.map(l => '`' + l + '`').join('、')} |`);
w('', '去某个地方用 `cabin_go {"place":"park"}`；要去房间里的具体位置再加 `zone`。', '');
for (const s of c.spaces) {
  w(`## ${s.fullName}（\`${s.id}\`）`, '');
  const here = c.objects.filter(o => o.space === s.id);
  w('**位置（zone）：** ' + s.zones.map(z => `\`${z.id}\` ${z.name}`).join('，'), '');
  if (!here.length) continue;
  for (const o of here) {
    w(`### ${o.name}（\`${o.id}\`）`, '', o.description, '');
    if (o.seats) w(`座位：${Object.keys(o.seats).length} 个（${Object.values(o.seats).map(z => '`' + z + '`').join('、')}），有人坐着就会自动换一个空位，坐满了要等。`, '');
    if (o.uses.length) {
      w('| use | 做什么 | 大约用时 |', '|---|---|---|');
      for (const u of o.uses) w(`| \`${u.id}\` | ${u.label}${u.shelf ? `（买${SHELF[u.shelf] || u.shelf}，用 \`cabin_buy\`）` : ''} | ${u.seconds ? sec(u.seconds) : '—'} |`);
      w('');
    } else w('（装饰，看看就好。）', '');
    if (o.uses[0] && !o.uses[0].shelf) w(`例：\`cabin_use {"object":"${o.id}","use":"${o.uses[0].id}"}\``, '');
  }
}
w('## 随身小包（`bag`）', '', '吃、喝、用背包里的东西：`cabin_eat {"product":"商品id"}`。按商品种类自动决定是吃、喝还是用。', '');
w('## 小卖部商品', '', '买：`cabin_buy {"product":"商品id"}`。价格是原价，当天可能有特价。', '',
  '| 商品 id | 名字 | 原价 | 种类 | 在哪买 | 味道/说明 |', '|---|---|---|---|---|---|');
for (const p of c.products) w(`| \`${p.id}\` | ${p.name} | ${p.price} 元 | ${KIND[p.kind] || p.kind}${p.keep ? '（用后保留）' : ''}${p.hot ? '·热' : ''}${p.cold ? '·冷' : ''} | ${SHELF[p.shelf] || p.shelf}（\`${p.buyAt?.object}\`） | ${p.taste || ''} |`);
w('', '## 怎么用才自然', '',
  '- 想做什么之前先 `cabin_status` / `cabin_look`，根据饱腹、口渴、心情和天气挑一件事。',
  '- 一次做一件，做完再说下一件；把返回的 `happened` 当作真实经历说给对方听，简短自然就好，不必逐步汇报。',
  '- 钱不多时别乱花；渴了先喝水（最便宜）。',
  '- 失败了（钱不够、有人占着、被打断）就照实说，换一件事做。', '');
fs.writeFileSync(path.join(root, 'docs/AI-MANUAL.md'), out.join('\n'));
console.log('docs/AI-MANUAL.md: ' + out.length + ' lines');
