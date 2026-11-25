// 2026-11-20 Claude (qingxi-farm): 清溪村农活的说法必须对得上真实回执。架构与 meal-truth / location-truth /
// board-conversation 一致：她说"我种了/我喂了/我围好了/我买了"这类话之前，先用这里对一遍。
//
// 为什么需要：业主 2026-11-20 看到她 19:16 说「围栏开始搭了，先沿着田边立了两根，你说圈多大的」——
// 游戏里当时根本没有"搭围栏"这个动作。清溪村农活以前没有任何声称校验，所以她可以零成本编。
//
// INTERFACE
//   farmClaim(text)               -> null 或 {act, label, kind:'done'|'doing', clause}
//   farmReceipts(world)           -> {act: 最近一次成功回执的 at}  读 world._qingxiLog（工具真实回执）
//   farmClaimProblem(world, text) -> '' 或一句"这不是真的 + 真实状态 + 该怎么做"的提醒
//
// DATA（都是程序写的，不是模型写的）
//   world._qingxiLog  [{act, ok, at, text}]  qingxi-visit.mjs 的 qingxiUse 在每次工具调用后追加（成功和拒绝都记）
//   world._qingxiFarm {plots, plotList, pens, animals, next, ...}  游戏最新的农场读数（qingxi-visit.mjs 缓存）
//
// 语气和判据（业主）：做不到就是做不到；照实说没做是**允许的**，不惩罚；但说了做过就必须有回执。

const RECEIPT_MS = 6 * 3600000;   // 六小时内的真实回执才算"刚做过"
const JUST_MS = 30 * 60000;
const nowOf = w => Number(w?.now?.() ?? w?.house?.now?.() ?? Date.now());

const clausesOf = text => String(text || '').split(/[。！？!?，,；;\n~～…]+/u).map(s => s.trim()).filter(Boolean);
const ASK = /[吗么嘛]|啥|什么|哪|几|还是|能不能|可不可以|会不会/;
const OTHERS = /你|您|她|他|小鲸鱼|阿文|主人|大家|你们|牢大/;
const PAST = /昨天|前天|上次|之前|那天|以前|小时候|上回|那次/;
const LATER = /想|要|打算|准备|待会|等会|等下|一会|下次|明天|后天|晚点|如果|要是|该|得去|先去|再去|改天|需要/;
const NEG = /(?:没|不|别|未)[有能想要去打算会]?.{0,4}(?:种|浇|收|开垦|挖|围|喂|加|打水|放|买|配|挤|剪)|还没|没有做|不会/;
// 计划/意愿句不是声称：这里列的是"她自己的打算"。
const PLAN = /想|要|打算|准备|待会|等会|一会|下次|明天|后天|改天|回头/;
const subject = c => !OTHERS.test(c.replace(/我们/g, '')) || /我/.test(c);

// 每类农活：说法里的关键词、真实动作 id、人话标签、怎么说才有据。
const CLAIMS = [
  // 2026-11-21 pets：宠物相关声称放在最前面，免得被泛化的"喂/养"抢走（要先有宠物工具的回执）。
  { act: 'adopt_pet', label: '领养宠物', re: /(?:领养|抱回来|接回家|养了)[^，。]{0,6}(?:猫|狗|小猫|小狗)|(?:猫|狗)[^，。]{0,4}(?:领养|抱回来|接回家)/, doing: /领养|抱|接|养/ },
  { act: 'name_pet', label: '给宠物取名', re: /(?:取名|改名|起名|叫作|名字叫)[^，。]{0,8}(?:猫|狗|它|宠物|牛|羊|猪|鸡)|(?:猫|狗|宠物|它)[^，。]{0,8}(?:取名|改名|起名|名字叫|叫作)/, doing: /取|改|起|叫/ },
  { act: 'walk_pet', label: '遛狗', re: /(?:遛|带出去走|散过步)[^，。]{0,6}(?:狗|它)|(?:狗|它)[^，。]{0,6}(?:遛|出去走|散步)/, doing: /遛|带|走/ },
  { act: 'play_pet', label: '陪宠物玩', re: /(?:陪|逗|扔球|跟)[^，。]{0,6}(?:猫|狗|它|球)|(?:猫|狗)[^，。]{0,6}(?:玩)/, doing: /陪|逗|扔|玩/ },
  // v2: "我把猫喂了" / "喂过狗" 也算喂宠物（否则会掉到下面的 feed=喂牲畜，指错工具）。
  { act: 'feed_pet', label: '喂宠物', re: /(?:猫|狗|宠物)[^，。]{0,8}(?:吃饱|吃过了|喂饱|喂过|喂了)|(?:喂|添|加)[^，。]{0,4}(?:猫|狗|鱼干|罐头)|(?:喂|喂过|喂了)[^，。]{0,6}(?:猫|狗|宠物)/, doing: /喂|添|加/ },
  { act: 'fence', label: '圈围栏', re: /(?:围栏|栅栏|圈栏|栏杆)/, doing: /搭|立|围|圈|开始|动手/ },
  { act: 'place_feeder', label: '摆食槽', re: /(?:食槽|草槽|草架|食盘)/, doing: /摆|放|装|挪/ },
  { act: 'till', label: '开垦地', re: /(?:开垦|垦荒|荒地|翻地|开地)/, doing: /开|翻|垦/ },
  { act: 'dig', label: '挖水渠', re: /(?:水渠|沟渠|挖渠|挖水|挖沟|开渠)/, doing: /挖|开|修/ },
  { act: 'plant', label: '种地', re: /(?:种|播种|栽)/, doing: /种|播|栽/, notFood: /(?:种|栽)(?:类|植|子|地|田|法)|人种|品种|物种|种群/ },
  { act: 'water', label: '浇水', re: /浇水|浇地|灌溉|浇了/, doing: /浇|灌溉/ },
  { act: 'harvest', label: '收成', re: /(?:收|摘|采|割|收获|收成|收成|拔)/, doing: /收|摘|采|割|拔/, notFood: /(?:收|接|吸|采)(?:到|藏|纳|拾|购|音|集消息)/ },
  { act: 'feed', label: '喂动物', re: /(?:牛|羊|猪|鸡|它|动物|牲口)[^，。]{0,8}(?:吃饱|吃过了|喝饱|喂饱)|(?:喂|添|加|撒)[^，。]{0,4}(?:草|料|食|饲料)|喂(?:了|过|饱)/, doing: /喂|添|加|撒/ },
  { act: 'water_pen', label: '给圈里加水', re: /(?:水槽|加.{0,2}水|换水)/, doing: /加|换|添/ },
  { act: 'fill_water', label: '水井打水', re: /(?:打水|装水|打满|水壶)/, doing: /打|装|灌/ },
  { act: 'release', label: '放养幼畜', re: /(?:放|送|领)(?:了|进|到|在|回)?(?:鸡窝|窝里|畜舍|鸡舍)|(?:放养|放进|放了).{0,8}(?:鸡|猪|羊|牛)|(?:鸡崽|猪崽|羊羔|牛犊|鸡苗).{0,6}(?:放进|放养)/, doing: /放|送|领/ },
  { act: 'buy_young', label: '买幼畜', re: /(?:鸡崽|猪崽|羊羔|牛犊|鸡苗|小鸡|幼畜|幼崽).{0,10}(?:买|到了|下单)|(?:买到|买了|买回|下单).{0,8}(?:鸡|猪|羊|牛|幼崽)/, doing: /买|到了|下单/ },
  { act: 'release', label: '把幼崽放进圈', re: /(?:幼崽|幼畜|小崽|幼牛|幼羊|幼猪|幼鸡)/, doing: /放|丢|撒|领|带/ },
  { act: 'buy', label: '买东西', re: /(?:买|购)/, doing: /买|购/ },
  { act: 'collect', label: '收产物', re: /(?:挤奶|剪毛|收.{0,2}(?:牛奶|羊毛|鸡蛋)|捡蛋)/, doing: /挤|剪|收|捡/ },
  { act: 'pair', label: '配种', re: /(?:配对|配种|配了)/, doing: /配/ },
];

// 有明确"完成"标记的说法，比"开始/正在"更硬。
const DONE = /(?:了|完|好|过|上|下|进|满|成)|已经|刚刚?|刚才/;

export function farmClaim(text) {
  for (const raw of clausesOf(text)) {
    const c = raw;
    if (!subject(c) || ASK.test(c) || PAST.test(c)) continue;
    if (NEG.test(c)) continue;
    for (const k of CLAIMS) {
      if (!k.re.test(c)) continue;
      if (k.notFood && k.notFood.test(c)) continue;
      // 计划句不是声称：只要没有完成/已做标记，就当她是在说要做什么。
      if (PLAN.test(c) && !/(?:了|完|好|过|成)|已经|刚刚?|刚才/.test(c)) continue;
      // 只提名词（"我的围栏"/"种子在哪买"）不算声称；要有动作或以完成/进行标记。
      if (!k.doing.test(c) && !DONE.test(c)) continue;
      const kind = DONE.test(c) && !/开始|正在|马上|这就/.test(c) ? 'done' : 'doing';
      return { act: k.act, label: k.label, kind, clause: raw };
    }
  }
  return null;
}

export function farmReceipts(world) {
  const out = {};
  const log = Array.isArray(world?._qingxiLog) ? world._qingxiLog : [];
  for (const row of log) {
    if (!row || row.ok !== true || !row.act) continue;
    if (!out[row.act] || Number(row.at) > out[row.act]) out[row.act] = Number(row.at) || 0;
  }
  return out;
}

export function farmRefusal(world, act) {
  const log = Array.isArray(world?._qingxiLog) ? world._qingxiLog : [];
  const row = [...log].reverse().find(r => r && r.act === act && r.ok === false);
  return row || null;
}

const HOW = {
  plant: '要种就先调用工具：qx_fields 的 use=plant（先 till 开垦、田边 3 格内有水、背包里有种子）。',
  water: '要浇水就先调用工具：qx_fields 的 use=water（水壶空了先 fill_water 打水）。',
  harvest: '要收成就先调用工具：qx_fields 的 use=harvest。',
  till: '要开垦就先调用工具：qx_fields 的 use=till，item 写格子（例如 14:11）。',
  dig: '要挖水渠就先调用工具：qx_fields 的 use=dig。',
  fence: '要围栏就先调用工具：qx_pasture 的 use=fence，item 写 左下:右上 格子。**没有这个动作就不能说在搭。**',
  place_feeder: '要摆食槽就先调用工具：qx_pasture 的 use=place_feeder（先买食槽）。',
  feed: '要喂就先调用工具：qx_pasture 的 use=feed（要先有圈、有能吃到的水）。',
  water_pen: '要加水就先调用工具：qx_pasture 的 use=give_water。',
  fill_water: '要打水就先调用工具：qx_fields 的 use=fill_water。',
  release: '要放幼崽就先调用工具：qx_pasture 的 use=release（围栏+水+食槽里有料才放得进去）。',
  buy: '要买就先调用工具：qx_seed_counter 或 qx_livestock_counter 的 use=buy。',
  collect: '要收产物就先调用工具：qx_pasture 的 use=collect。',
  pair: '要配种就先调用工具：qx_pasture 的 use=pair。',
  // 2026-11-21 pets
  adopt_pet: '要领养就先调用工具：qx_pets 的 use=adopt_pet，item 写 猫 或 狗（想挑品种写 猫:橘猫 / 狗:金毛；花自己的零花钱，当场住进农场）。',
  name_pet: '要取名就先调用工具：qx_pets 的 use=name_pet，item 写 编号:名字（例如 7:咪咪）；牲畜写 牛:3:大黄。',
  feed_pet: '要喂宠物就先调用工具：qx_pets 的 use=feed_pet，item 写编号（例如 7）或 猫/狗（猫吃猫粮/鱼干/鲜鱼，狗吃狗粮/家常菜/猪肉；缺粮去牧铃畜牧铺 qx_livestock_counter，use=buy，item 写猫粮或狗粮，每份 3 币）。喂食只能手动做，系统不会替你喂。',
  play_pet: '要陪宠物玩就先调用工具：qx_pets 的 use=play_pet（狗着急时要先 walk_pet）。',
  walk_pet: '要遛狗就先调用工具：qx_pets 的 use=walk_pet。',
};

const ALLOWED_EXIT = '还没做就直接说还没做（这不算错，也不会被怪）；想做就现在调工具，做完再说。';

// 真实的农场状态一句话：她可以照实说的东西。
function truthLine(world) {
  const f = world?._qingxiFarm;
  if (!f) return '现在还没有清溪村农场的真实读数，可以先 house_look 看一眼再说。';
  const bits = [];
  if (f.plotTotal !== undefined) {
    const rows = Array.isArray(f.plotList) ? f.plotList : [];
    const planted = rows.filter(r => r && r.planted).length;
    bits.push(`田里有 ${rows.length} 块地${planted ? `，种着 ${planted} 块` : '，都还空着'}`);
  }
  const pens = f.pens || {};
  const fenced = Object.entries(pens).filter(([, p]) => p && p.fenced).map(([k]) => ({ cow: '牛', sheep: '羊', pig: '猪', chicken: '鸡' }[k] || k));
  bits.push(fenced.length ? `圈住的有：${fenced.join('、')}` : '还没有圈住任何牲畜的围栏');
  // 每只动物自己的饱食度/饥渴度：她可以照实说的真实数字。
  const animals = Array.isArray(f.animalsDetailed) ? f.animalsDetailed : [];
  if (animals.length) {
    const hungry = animals.filter(a => a.hungry).length, thirsty = animals.filter(a => a.thirsty).length;
    const worst = animals.slice().sort((a, b) => Math.min(a.satiety, a.thirst) - Math.min(b.satiety, b.thirst))[0];
    bits.push(`圈里 ${animals.length} 只动物：${hungry} 只饿着、${thirsty} 只渴着` + (worst ? `（最紧的 #${worst.id} 饱食度 ${Math.round(worst.satiety)}、饥渴度 ${Math.round(worst.thirst)}）` : ''));
  }
  // 2026-11-21 pets：猫狗的真实状态（名字/只数/谁饿了/谁出门了），她可以照实说。
  const pets = Array.isArray(f.petsDetailed) ? f.petsDetailed : [];
  if (pets.length) {
    const names = pets.slice(0, 6).map(p => p.displayName || `${p.kindName || p.kind}#${p.id}`).join('、');
    const hungry = pets.filter(p => p.hungry).length, away = pets.filter(p => p.away).length;
    bits.push(`农场有 ${Number(f.petsTotal ?? pets.length)} 只宠物（${names}${pets.length > 6 ? '…' : ''}）` + (hungry ? `，${hungry} 只饿着` : '') + (away ? `，${away} 只出门了` : ''));
  } else if (Number(f.petsTotal ?? 0) === 0 && f.petsTotal !== undefined) {
    bits.push('农场里还没有宠物');
  }
  return bits.join('；') + '。';
}

export function farmClaimProblem(world, text) {
  if (!world) return '';
  const claim = farmClaim(text);
  if (!claim) return '';
  const at = nowOf(world);
  const receipts = farmReceipts(world);
  const seenAt = Number(receipts[claim.act] || 0);
  const latest = [...(world._qingxiLog || [])].reverse().find(r=>r.act===claim.act);
  if (seenAt && at - seenAt < RECEIPT_MS && latest?.ok) {
    if (['buy_young','release'].includes(claim.act)) {
      const stated = String(text).match(/([一二两三四五六七八九十\d]+)\s*只/);
      const actual = String(latest.text).match(/(\d+)\s*只/);
      if (stated && actual) {
        const n = ({一:1,二:2,两:2,三:3,四:4,五:5,六:6,七:7,八:8,九:9,十:10})[stated[1]] ?? Number(stated[1]);
        if (Number.isFinite(n) && n!==Number(actual[1])) return '这次游戏回执是：'+latest.text+'。请按实际只数描述。';
      }
    }
    return '';
  }
  // 进行中（"开始搭了/正在种"）也要有回执：没有工具确认，就没有这件事在做。
  const refusal = farmRefusal(world, claim.act);
  const tail = refusal ? `（上一次想${claim.label}时游戏说：${String(refusal.text || '').slice(0, 60)}）` : '';
  const what = claim.kind === 'doing' ? '（还没有在发生）' : '';
  return `「${claim.clause}」不是真的${what}：小屋世界里没有你在清溪村${claim.label}的真实回执。`
    + `${tail}真实情况：${truthLine(world)}`
    + `${HOW[claim.act] || '要用游戏里的工具真的做一次。'}${ALLOWED_EXIT}`;
}
