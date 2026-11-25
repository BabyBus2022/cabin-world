const foodTypes = [
  ['chicken','鸡','wheat','小麦'], ['pig','猪','pig_feed','猪饲料'],
  ['cow','牛','hay','干草'], ['sheep','羊','hay','干草']
];
// The game stores feed in portions of 86400 units and consumes 864 per satiety point.
export function supplyNeeds(data) {
  const herd = data?.livestock?.herd;
  if (!Array.isArray(herd)) return [];
  const needs = [];
  for (const [kind, animal, item, food] of foodTypes) {
    const hungry = herd.filter(a => a.kind === kind && Number.isFinite(a.food) && a.food <= 30);
    if (!hungry.length) continue;
    const pen = data.livestock.pens?.[kind] || {};
    const required = hungry.reduce((sum,a) => sum + (90 - a.food) * 864, 0);
    const available = Number(pen.feed || 0) + (kind === 'sheep' ? Number(pen.grass || 0) : 0);
    const portions = Math.min(6, Math.ceil((required - available) / 86400));
    if (portions <= 0) continue;
    needs.push({kind, animal, food, count:hungry.length, lowest:Math.min(...hungry.map(a=>a.food)),
      portions, buy:Math.max(0, portions - Number(data.bag?.[item] || 0))});
  }
  return needs.sort((a,b)=>a.lowest-b.lowest);
}

