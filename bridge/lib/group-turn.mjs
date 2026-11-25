export function groupTurn(turn, policy, enabled = true, now = Date.now()) {
  const self = String(turn.self || ''), sender = String(turn.sender || '');
  const text = String(turn.text || '').trim();
  const decision = (action, reason) => ({ ok: true, action, reason });
  if (!enabled) return decision('defer', '模块已关闭，由接入方判断');
  if (!self || !sender || !text) throw Error('需要 self、sender 和 text');
  if (sender === self) return decision('listen', '自己的消息');
  const recipients = (turn.mentions || []).map(String);
  if (recipients.includes(self)) return decision('reply', '明确提及自己');
  if (recipients.length) return decision('listen', '明确提及别人');
  if (turn.quotedSender) return decision(String(turn.quotedSender) === self ? 'reply' : 'listen', '按引用的作者判断');
  if (turn.explicitName) return decision('reply', '明确叫自己的名字');
  const recent = (turn.recent || []).filter(row => now >= row.at && now-row.at <= policy.recentSeconds*1000);
  const last = recent.at(-1);
  if (last && String(last.sender) !== self && String(last.sender) !== sender &&
      policy.handoffVerbs.some(verb => last.text.includes('你'+verb) && text.includes('我'+verb))) {
    return decision('listen', '两位群友正在彼此接话');
  }
  if (/^(各位|大家|谁知道)/u.test(text)) return decision('consider', '公开提问，可按当前话题决定是否参与');
  if (last && String(last.sender) === self && /[你您]|刚才说/u.test(text)) return decision('consider', '可能承接自己的上一句');
  return decision('listen', '缺少与自己有关的对话线索');
}

