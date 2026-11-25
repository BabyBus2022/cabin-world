extends RefCounted
## 2026-11-21 pets: 清溪村宠物规则引擎（纯函数，不建节点、不改存档）。
##
## 业主的三条原则同样落在这里：
##   1. 所有阈值/规则都在 pets_rules.json（可见数据文件，不是代码），这个文件只读它。
##   2. 只算真实存档里已经发生的事：每只宠物的 food/bond/时间戳。不猜、不假设、不预写。
##   3. 每个前提都回答「缺哪一条」和「下一步能做什么」，所以它们永远有一条走得通的路。
##
## 2026-11-21 v2（业主：品种 + 成长 + 喂食待办）：
##   * 品种：6 种（猫 橘猫/狸花/白猫、狗 金毛/柴犬/柯基）。名字、差价、体型、速度、回馈偏好全在
##     pets_rules.json 的 breeds 段；这个文件只查表，不另存一份数字。
##   * 成长：幼崽 baby -> 成体 adult，按真实时间推进；阈值/倍率/文案在 growth 段。
##   * 旧存档兼容：没有 breed 字段 -> 按 breeds.default 降级；没有 stage 字段 -> 当成体（老宠物不会变小）。
##     两处都是**读的时候降级**，不因为缺字段就读不出、更不会清档。
##   * 喂食待办：hungry_rows() 把"谁饿了、饿到多少、该喂什么"算成 look/survey 的 next[]/urgent[] 里的真实条目。
##     数字来自 food.hungry_below / food.feed_raise_to / food.feed_items，文案来自 todo 段——代码里没有 40/90。
##     喂食永远是手动动作：这里只提醒，绝不替任何人喂（系统不自动喂、不自动领养、不自动取名）。
##
## INTERFACE（core/qingxi_host.gd 与测试用；全部是纯函数）
##   rules()                     -> pets_rules.json 的内容（她和我都查得到，读数原样带出）
##   name_ok(text)               -> {ok, text, why}：取名/改名的唯一校验（宠物与牲畜共用）
##   name_text(pet)              -> 「咪咪」 或 猫 #7（没名字时用编号）
##   is_away / wants_follow / guarding / anxious / happy / rub_ready
##                               -> 猫狗行为差异的判据（表现层和测试都读同一份）
##   pet_state(pet, now, hour)   -> 现在这四个字（出门/打盹/跟着/看家/着急/高兴/想玩/饿了）
##   pet_line(pet, now, hour)    -> 读数里的一行（带品种和成长阶段）
##   next_of(pet, now, hour)     -> 下一步能做什么（人话 + 工具名）
##   reading(farm_data, now, hour) -> look/survey 里的 pets / petsDetailed / petRules …
##   ---- v2 ----
##   breed_keys(kind) / breed_rules(kind, breed) / breed_key_of(kind, text) / breed_of(pet)
##   breed_name(pet) / breed_scale / breed_speed / plate_lift / adopt_price_of(kind, breed) / parse_breed(text)
##   stage_of(pet) / stage_rules(pet) / is_baby(pet) / body_scale(pet) / stage_text(pet, now)
##   grow_seconds() / grow_left(pet, now) / advance_stage(pet, now) / ensure_pet(pet)
##   feed_bond_gain_of / play_bond_gain_of / gift_chance_mult / gift_bond_mult / bond_decay_mult / speed_mult
##   hungry_rows(farm_data, now, bag) -> look/survey 的 next[]/urgent[] 里那几条真实的喂食待办
##
## 判据（业主）：她做完之后隔一分钟再「看」，必须能在读数里看到自己做过的那件事。
## 这里的每一条都从 data.pets 现读，不做缓存（只有规则文件本身有缓存）。

const RULES_PATH := "res://qingxi-live/village-center/pets_rules.json"
const LEGACY_NAME_MAX := 12

static var _rules_cache:Dictionary = {}

static func rules() -> Dictionary:
	if _rules_cache.is_empty():
		if not FileAccess.file_exists(RULES_PATH):
			return {}
		var d = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		_rules_cache = d if d is Dictionary else {}
	return _rules_cache

static func ok() -> bool:
	return not rules().is_empty()

static func section(key:String) -> Dictionary:
	var s = rules().get(key, {})
	return s if s is Dictionary else {}

static func kinds() -> Dictionary:
	return section("kinds")

static func kind_cn(kind:String) -> String:
	return str(kinds().get(kind, kind))

static func known_kind(kind:String) -> bool:
	return kinds().has(kind)

## "猫"/"狗"/cat/dog -> cat/dog；认不出来返回 ""。
static func kind_of(text:String) -> String:
	var t := text.strip_edges()
	if known_kind(t):
		return t
	for k in kinds():
		if str(kinds()[k]) == t:
			return str(k)
	return ""

static func adopt_rules() -> Dictionary:
	return section("adopt")

static func cap() -> int:
	return int(adopt_rules().get("cap", 0))

## 基础价（不分品种）。品种价用 adopt_price_of(kind, breed)。
static func adopt_price(kind:String) -> int:
	var p = adopt_rules().get("price", {})
	return int(p.get(kind, 0)) if p is Dictionary else 0

static func gauges() -> Dictionary:
	return section("gauges")

static func food_rules() -> Dictionary:
	return section("food")

static func bond_rules() -> Dictionary:
	return section("bond")

static func kind_rules(kind:String) -> Dictionary:
	return section(kind)

static func naming() -> Dictionary:
	return section("naming")

static func display() -> Dictionary:
	return section("display")

static func action_rows() -> Array:
	var a = rules().get("actions", [])
	return a if a is Array else []

static func rewards() -> Dictionary:
	return section("rewards")

static func todo_rules() -> Dictionary:
	return section("todo")

# ---------------- 品种（v2） ----------------
static func breeds() -> Dictionary:
	return section("breeds")

static func breed_table(kind:String) -> Dictionary:
	var t = breeds().get(kind, {})
	return t if t is Dictionary else {}

## 这种猫/狗有几个品种（名字可能为空 = 数据文件没写全）。
static func breed_keys(kind:String) -> Array:
	return breed_table(kind).keys()

static func has_breeds(kind:String) -> bool:
	return not breed_table(kind).is_empty()

static func default_breed(kind:String) -> String:
	var d = breeds().get("default", {})
	if d is Dictionary and d.has(kind):
		return str(d[kind])
	var keys := breed_keys(kind)
	return str(keys[0]) if not keys.is_empty() else ""

## 品种规则；认不出的品种一律降级到这种的默认品种（旧存档兼容）。
static func breed_rules(kind:String, breed:String = "") -> Dictionary:
	var table := breed_table(kind)
	var key := str(breed).strip_edges()
	if key == "" or not table.has(key):
		var def := default_breed(kind)
		if table.has(def):
			key = def
		elif not table.is_empty():
			key = str(table.keys()[0])
		else:
			return {}
	var row = table.get(key, {})
	return row if row is Dictionary else {}

## "橘猫" / "orange" / "cat-orange" / "猫:橘猫" 都认 -> 品种键；认不出返回 ""。
static func breed_key_of(kind:String, text:String) -> String:
	var t := str(text).strip_edges()
	if t == "":
		return default_breed(kind)
	if t.contains(":") or t.contains("："):
		var sp := t.replace("：", ":").split(":", false)
		t = str(sp[sp.size() - 1]).strip_edges()
	var table := breed_table(kind)
	if table.has(t):
		return t
	var want_key := t.to_lower()
	if want_key.begins_with(kind + "-"):
		want_key = want_key.substr(kind.length() + 1)
	if table.has(want_key):
		return want_key
	for k in table:
		var row = table[k]
		if row is Dictionary and str(row.get("name", "")) == t:
			return str(k)
	return ""

## 这只宠物的品种键；旧存档没有 breed -> 默认品种（不写存档、不报错）。
static func breed_of(pet:Dictionary) -> String:
	var kind := str(pet.get("kind", ""))
	return breed_key_of(kind, str(pet.get("breed", "")))

static func breed_name(pet:Dictionary) -> String:
	var kind := str(pet.get("kind", ""))
	return str(breed_rules(kind, breed_of(pet)).get("name", ""))

static func breed_cn(pet:Dictionary) -> String:
	var nm := breed_name(pet)
	return nm if nm != "" else kind_cn(str(pet.get("kind", "")))

static func breed_note(pet:Dictionary) -> String:
	var kind := str(pet.get("kind", ""))
	return str(breed_rules(kind, breed_of(pet)).get("note", ""))

static func breed_scale(pet:Dictionary) -> float:
	return float(breed_rules(str(pet.get("kind", "")), breed_of(pet)).get("scale", 1.0))

## 速度系数（柴犬 1.25 = 跑得最快）；表现层拿它乘自己的基础速度。
static func breed_speed(pet:Dictionary) -> float:
	return float(breed_rules(str(pet.get("kind", "")), breed_of(pet)).get("speed", 1.0))

## 名牌抬高多少（柯基矮，名牌也低）。
static func plate_lift(pet:Dictionary) -> float:
	var def := 28.0 if str(pet.get("kind", "")) == "cat" else 38.0
	var row := breed_rules(str(pet.get("kind", "")), breed_of(pet))
	return float(row.get("plate_lift", def)) if not row.is_empty() else def

## 品种价 = 基础价 + 差价。
static func adopt_price_of(kind:String, breed:String = "") -> int:
	var row := breed_rules(kind, breed)
	return adopt_price(kind) + (int(row.get("price_offset", 0)) if not row.is_empty() else 0)

## 领养菜单：每个品种一行（名字/价格/一句特点）。
static func breed_menu(kind:String) -> Array:
	var out := []
	var table := breed_table(kind)
	for k in table:
		var row = table[k]
		if not row is Dictionary:
			continue
		out.append({
			"key": str(k), "kind": kind, "name": str(row.get("name", k)),
			"price": adopt_price_of(kind, str(k)),
			"scale": float(row.get("scale", 1.0)), "speed": float(row.get("speed", 1.0)),
			"note": str(row.get("note", "")),
		})
	return out

## "猫:橘猫" / "dog:shiba" / "猫" / "橘猫" -> {kind, breed}；认不出 kind 返回 {}。
static func parse_breed(text:String) -> Dictionary:
	var t := str(text).strip_edges().replace("，", ":").replace(",", ":")
	if t == "":
		return {"kind": "", "breed": ""}
	var parts := t.split(":", false)
	var head := str(parts[0]).strip_edges()
	var kind := kind_of(head)
	if kind == "":
		# 只写了品种名（"橘猫" / "corgi"）：反查它属于猫还是狗。
		for k in kinds():
			var key := breed_key_of(str(k), head)
			if key != "":
				return {"kind": str(k), "breed": key}
		return {}
	if parts.size() >= 2:
		var breed := breed_key_of(kind, str(parts[1]).strip_edges())
		if breed == "":
			return {}
		return {"kind": kind, "breed": breed}
	return {"kind": kind, "breed": default_breed(kind)}

# ---------------- 成长（v2） ----------------
static func growth() -> Dictionary:
	return section("growth")

static func stage_order() -> Array:
	var o = growth().get("order", [])
	return o if o is Array else ["baby", "adult"]

static func stage_table() -> Dictionary:
	var s = growth().get("stages", {})
	return s if s is Dictionary else {}

static func default_stage() -> String:
	return str(growth().get("default", "adult"))

## 成长阶段键。旧存档没有 stage -> 成体（业主：老宠物不许突然变小）。
static func stage_of(pet:Dictionary) -> String:
	var st := str(pet.get("stage", "")).strip_edges()
	if st == "":
		return default_stage()
	if not stage_table().has(st):
		return default_stage()
	return st

static func stage_rules(pet:Dictionary) -> Dictionary:
	var s = stage_table().get(stage_of(pet), {})
	return s if s is Dictionary else {}

static func is_baby(pet:Dictionary) -> bool:
	return stage_of(pet) == "baby"

static func stage_cn(stage:String) -> String:
	var s = stage_table().get(stage, {})
	return str(s.get("name", stage)) if s is Dictionary else stage

## 幼崽变完成体要多少秒（growth.seconds.baby_to_adult）。
static func grow_seconds() -> float:
	var s = growth().get("seconds", {})
	return float(s.get("baby_to_adult", 259200.0)) if s is Dictionary else 259200.0

## 还要多少秒长大（成体返回 0）。
static func grow_left(pet:Dictionary, now:float) -> float:
	if not is_baby(pet):
		return 0.0
	var born := float(pet.get("born_at", 0.0))
	if born <= 0.0:
		return grow_seconds()
	return maxf(0.0, grow_seconds() - maxf(0.0, now - born))

## "幼崽（还有 2 天长大）" / "幼崽（今天就长大）" / "成体"——文案在 growth.text。
static func stage_text(pet:Dictionary, now:float) -> String:
	var stage := stage_of(pet)
	var t = growth().get("text", {})
	var text:Dictionary = t if t is Dictionary else {}
	if stage != "baby":
		return str(text.get("adult", "成体"))
	var left := grow_left(pet, now)
	var days := int(ceil(left / 86400.0)) if left > 0.0 else 0
	if days <= 0:
		return str(text.get("baby_today", "幼崽（今天就长大）"))
	return str(text.get("baby", "幼崽（还有 {days} 天长大）")).replace("{days}", str(days))

## 体型 = 品种 scale × 阶段 scale（柯基 0.92 × 幼崽 0.65）。
static func body_scale(pet:Dictionary) -> float:
	return breed_scale(pet) * float(stage_rules(pet).get("scale", 1.0))

## 亲密涨幅的阶段倍率（幼崽 1.5：小时候学得快）。
static func bond_gain_mult(pet:Dictionary) -> float:
	return float(stage_rules(pet).get("bond_gain_mult", 1.0))

## 回馈概率的倍率 = 品种 × 阶段。
static func gift_chance_mult(pet:Dictionary) -> float:
	var b := float(breed_rules(str(pet.get("kind", "")), breed_of(pet)).get("gift_chance_mult", 1.0))
	return b * float(stage_rules(pet).get("gift_chance_mult", 1.0))

## 回馈加的亲密的阶段倍率。
static func gift_bond_mult(pet:Dictionary) -> float:
	return float(stage_rules(pet).get("gift_bond_mult", 1.0))

## 亲密衰减的品种倍率（金毛 0.85 掉得慢）。
static func bond_decay_mult(pet:Dictionary) -> float:
	return float(breed_rules(str(pet.get("kind", "")), breed_of(pet)).get("bond_decay_mult", 1.0))

## 移动速度 = 品种 × 阶段。
static func speed_mult(pet:Dictionary) -> float:
	return breed_speed(pet) * float(stage_rules(pet).get("speed_mult", 1.0))

## 到时间就把幼崽推进成体（只改这一只的 stage/grown_at，别的字段不动）。
## 返回是否刚刚长大。
static func advance_stage(pet:Dictionary, now:float) -> bool:
	if not is_baby(pet):
		return false
	if grow_left(pet, now) > 0.0:
		return false
	pet["stage"] = "adult"
	pet["grown_at"] = now
	return true

## 懒迁移：只补缺的字段，不覆盖已有的值。
##   breed 缺 -> 默认品种；stage 缺 -> 成体（老宠物不变小）；born_at 缺 -> 0（不猜出生时间）。
## 返回是否补过东西。
static func ensure_pet(pet:Dictionary) -> bool:
	if not pet is Dictionary:
		return false
	var kind := str(pet.get("kind", ""))
	if not known_kind(kind):
		return false
	var touched := false
	if str(pet.get("breed", "")).strip_edges() == "":
		var def := default_breed(kind)
		if def != "":
			pet["breed"] = def
			touched = true
	if str(pet.get("stage", "")).strip_edges() == "" or not stage_table().has(str(pet.get("stage", ""))):
		pet["stage"] = default_stage()
		touched = true
	if not pet.has("born_at"):
		pet["born_at"] = 0.0
		touched = true
	return touched

# ---------------- 两个值 ----------------
static func food_field() -> String:
	return "food"

static func bond_field() -> String:
	return "bond"

static func food_of(pet:Dictionary) -> float:
	return clampf(float(pet.get(food_field(), 0.0)), 0.0, 100.0)

static func bond_of(pet:Dictionary) -> float:
	return clampf(float(pet.get(bond_field(), 0.0)), 0.0, 100.0)

static func hungry_below() -> float:
	return float(food_rules().get("hungry_below", 40.0))

static func feed_raise_to() -> float:
	return float(food_rules().get("feed_raise_to", 90.0))

static func is_hungry(pet:Dictionary) -> bool:
	return food_of(pet) <= hungry_below()

static func food_seconds_per_point(kind:String) -> float:
	var s = food_rules().get("seconds_per_point", {})
	return float(s.get(kind, 900.0)) if s is Dictionary else 900.0

static func bond_start() -> float:
	return float(bond_rules().get("start", 30.0))

static func bond_patience_hours(kind:String) -> float:
	var s = bond_rules().get("patience_hours", {})
	return float(s.get(kind, 8.0)) if s is Dictionary else 8.0

static func bond_decay_per_hour(kind:String) -> float:
	var s = bond_rules().get("decay_per_hour", {})
	return float(s.get(kind, 1.5)) if s is Dictionary else 1.5

static func feed_items(kind:String) -> Array:
	var s = food_rules().get("feed_items", {})
	return s.get(kind, []) if s is Dictionary else []

static func feed_item_name(key:String) -> String:
	var s = food_rules().get("feed_item_names", {})
	return str(s.get(key, key)) if s is Dictionary else key

## 猫/狗能吃的东西，人话连起来："鱼干或鲜鱼"（待办里就这么写）。
static func feed_items_text(kind:String) -> String:
	var names := []
	for it in feed_items(kind):
		names.append(feed_item_name(str(it)))
	if names.is_empty():
		return ""
	if names.size() == 1:
		return str(names[0])
	return "或".join(names)

## 喂食一次加多少亲密（基础值，不分品种）。真实值用 feed_bond_gain_of(pet)。
static func feed_bond_gain(kind:String) -> float:
	var s = food_rules().get("feed_bond_gain", {})
	return float(s.get(kind, 1.0)) if s is Dictionary else 1.0

static func feed_bond_gain_of(pet:Dictionary) -> float:
	var kind := str(pet.get("kind", ""))
	var b := float(breed_rules(kind, breed_of(pet)).get("feed_bond_mult", 1.0))
	return feed_bond_gain(kind) * b * bond_gain_mult(pet)

static func play_bond_gain(kind:String) -> float:
	return float(kind_rules(kind).get("play_bond_gain", 6.0))

static func play_bond_gain_of(pet:Dictionary) -> float:
	var kind := str(pet.get("kind", ""))
	var b := float(breed_rules(kind, breed_of(pet)).get("play_bond_mult", 1.0))
	var stage_play := float(stage_rules(pet).get("play_bond_mult", 1.0))
	return play_bond_gain(kind) * b * stage_play * bond_gain_mult(pet)

# ---------------- 命名（宠物与牲畜共用这一套） ----------------
## 唯一的取名校验：返回 {ok, text, why}。text 是清理后的名字（"" 表示清除名字）。
static func name_ok(raw:String) -> Dictionary:
	var n := naming()
	var max_chars := int(n.get("max_chars", LEGACY_NAME_MAX))
	var cleaned := ""
	for ch in str(raw):
		var code := ch.unicode_at(0)
		if code < 32 or code == 127:
			continue   # 换行/制表/控制字符直接删掉
		cleaned += ch
	cleaned = cleaned.strip_edges()
	if cleaned.is_empty():
		return {"ok": true, "text": "", "why": ""}
	if cleaned.length() > max_chars:
		return {"ok": false, "text": cleaned, "why": "名字太长：最多 %d 个字（现在是 %d 个）" % [max_chars, cleaned.length()]}
	return {"ok": true, "text": cleaned, "why": ""}

static func named_by_cn(who:String) -> String:
	var s = naming().get("named_by", {})
	if s is Dictionary and s.has(who):
		return str(s[who])
	return "" if who == "" else "有人"

static func name_text(pet:Dictionary) -> String:
	var nm := str(pet.get("name", "")).strip_edges()
	if nm == "":
		return "%s #%s" % [kind_cn(str(pet.get("kind", ""))), str(pet.get("id", "?"))]
	return "「%s」" % nm

## 待办里的短称呼："猫#2" / "「咪咪」"（业主例子写的就是 猫#2 这种）。
static func short_name(pet:Dictionary) -> String:
	var nm := str(pet.get("name", "")).strip_edges()
	if nm == "":
		return "%s#%s" % [kind_cn(str(pet.get("kind", ""))), str(pet.get("id", "?"))]
	return "「%s」" % nm

static func named_by_of(pet:Dictionary) -> String:
	return str(pet.get("named_by", ""))

static func rename_wait(pet:Dictionary, now:float) -> float:
	var cd := float(naming().get("rename_cooldown_seconds", 30.0))
	var last := float(pet.get("named_at", 0.0))
	return maxf(0.0, cd - (now - last))

# ---------------- 猫 / 狗 的行为判据（差异都在这里，表现层和测试读同一份） ----------------
static func is_cat(pet:Dictionary) -> bool:
	return str(pet.get("kind", "")) == "cat"

static func is_dog(pet:Dictionary) -> bool:
	return str(pet.get("kind", "")) == "dog"

## 猫：自己出门了（不在世界里，也不在家）。
static func is_away(pet:Dictionary, now:float) -> bool:
	if not is_cat(pet) or pet.get("follow",false):
		return false
	return float(pet.get("away_until", 0.0)) > now

## 猫回家还差多少秒。
static func away_left(pet:Dictionary, now:float) -> float:
	if not is_away(pet, now):
		return 0.0
	return maxf(0.0, float(pet.get("away_until", 0.0)) - now)

static func in_window(hours, hour:float) -> bool:
	if not hours is Array or hours.size() < 2:
		return false
	var a := float(hours[0])
	var b := float(hours[1])
	if a <= b:
		return hour >= a and hour < b
	return hour >= a or hour < b   # 跨午夜，例如 19.0–6.5

## 在家的猫在白天打盹；夜里活跃。
static func cat_awake(hour:float) -> bool:
	return in_window(kind_rules("cat").get("night_hours", [19.5, 6.0]), hour)

# ---------------- 狗 ----------------
static func dog_follow_rules() -> Dictionary:
	var d = kind_rules("dog").get("follow", {})
	return d if d is Dictionary else {}

static func dog_follow_min_bond() -> float:
	return float(dog_follow_rules().get("min_bond", 40.0))

static func dog_gap() -> float:
	return float(dog_follow_rules().get("gap_px", 56.0))

static func dog_walk_patience_hours() -> float:
	var w = kind_rules("dog").get("walk", {})
	return float(w.get("patience_hours", 10.0)) if w is Dictionary else 10.0

static func dog_last_company(pet:Dictionary) -> float:
	return maxf(float(pet.get("last_play", 0.0)), float(pet.get("last_walk", 0.0)))

## 狗：着急（太久没遛/没陪）。
static func anxious(pet:Dictionary, now:float) -> bool:
	if not is_dog(pet):
		return false
	var last := dog_last_company(pet)
	if last <= 0.0:
		return true   # 从没遛过：领养那一刻起就在等
	return (now - last) > dog_walk_patience_hours() * 3600.0

## 狗：夜里在看家（在农场、没在遛）。
static func guarding(pet:Dictionary, now:float, hour:float) -> bool:
	if not is_dog(pet):
		return false
	var g = kind_rules("dog").get("guard", {})
	if not g is Dictionary:
		return false
	if not in_window(g.get("hours", [19.0, 6.5]), hour):
		return false
	return (now - float(pet.get("last_walk", 0.0))) > 30.0 * 60.0   # 刚遛完的那一会儿不算

## 猫和狗都能跟随自己的领养人，直到主人让它留下。
static func wants_follow(pet:Dictionary, now:float, hour:float) -> bool:
	return bool(pet.get("follow",false)) and str(pet.get("owner_id",""))!=""

static func happy(pet:Dictionary, now:float) -> bool:
	if not is_dog(pet):
		return false
	var hb := float(kind_rules("dog").get("happy_bond", 70.0))
	if bond_of(pet) < hb:
		return false
	return (now - float(pet.get("last_play", 0.0))) <= 30.0 * 60.0

## 猫：想蹭你（亲密还不高、冷却过了）。
static func rub_ready(pet:Dictionary, now:float) -> bool:
	if not is_cat(pet) or is_away(pet, now):
		return false
	var r = kind_rules("cat").get("rub", {})
	if not r is Dictionary:
		return false
	if bond_of(pet) >= float(r.get("bond_below", 70.0)):
		return false
	return (now - float(pet.get("last_rub", 0.0))) >= float(r.get("cooldown_seconds", 300.0))

static func rub_range() -> float:
	var r = kind_rules("cat").get("rub", {})
	return float(r.get("range_px", 96.0)) if r is Dictionary else 96.0

# ---------------- 一句话状态 ----------------
static func pet_state(pet:Dictionary, now:float, hour:float) -> String:
	if pet.get("follow",false):return "跟着"+preload("res://core/pet_owner.gd").caption(pet)
	var kind := str(pet.get("kind", ""))
	if is_cat(pet):
		if is_away(pet, now):
			return "出门了"
		if not cat_awake(hour):
			return "打盹"
		if rub_ready(pet, now):
			return "想蹭你"
		if is_hungry(pet):
			return "有点饿"
		return "在家"
	if is_dog(pet):
		if guarding(pet, now, hour):
			return "看家"
		if anxious(pet, now):
			return "着急"
		if happy(pet, now):
			return "高兴"
		if wants_follow(pet, now, hour):
			return "跟着你"
		if is_hungry(pet):
			return "饿得直叫"
		return "在家"
	return "在家"

static func minutes_text(seconds:float) -> String:
	var m := ceili(maxf(0.0, seconds) / 60.0)
	if m <= 1:
		return "1 分钟"
	if m < 60:
		return "%d 分钟" % m
	return "%d 小时 %d 分钟" % [m / 60, m % 60]

static func ago_text(now:float, at:float) -> String:
	if at <= 0.0:
		return "还没有过"
	var d := maxf(0.0, now - at)
	if d < 60.0:
		return "刚刚"
	if d < 3600.0:
		return "%d 分钟前" % int(d / 60.0)
	if d < 86400.0:
		return "%d 小时前" % int(d / 3600.0)
	return "%d 天前" % int(d / 86400.0)

## 读数里的一行（人话）：名字 品种 两个值 · 状态 · 成长阶段 · 细节
static func pet_line(pet:Dictionary, now:float, hour:float) -> String:
	var bits := ["%s%s" % [name_text(pet), breed_cn(pet)]]
	bits.append("主人："+preload("res://core/pet_owner.gd").caption(pet))
	bits.append("亲密 %.0f / 饱食度 %.0f" % [bond_of(pet), food_of(pet)])
	bits.append(pet_state(pet, now, hour))
	bits.append(stage_text(pet, now))
	if is_cat(pet) and is_away(pet, now):
		bits.append("约 %s后回来" % minutes_text(away_left(pet, now)))
	if is_dog(pet) and anxious(pet, now):
		bits.append("约 %s没遛了" % minutes_text(now - dog_last_company(pet)) if dog_last_company(pet) > 0.0 else "还没带它出去过")
	var by := named_by_cn(named_by_of(pet))
	if by != "":
		bits.append("名字是%s取的" % by)
	if int(pet.get("gifts", 0)) > 0:
		bits.append("带回来 %d 次东西" % int(pet.get("gifts", 0)))
	return " · ".join(bits)

## 下一步能做什么（人话 + 工具名）。没有可做的就返回空串（不催她）。
static func next_of(pet:Dictionary, now:float, hour:float) -> String:
	var kind := str(pet.get("kind", ""))
	var id := str(pet.get("id", ""))
	if is_hungry(pet):
		return "%s 饿了：feed_pet %s（食物：%s；缺货去牧铃畜牧铺购买）" % [name_text(pet), id, feed_items_text(kind)]
	if is_dog(pet) and anxious(pet, now):
		return "%s 着急了：walk_pet %s 带它出去走走" % [name_text(pet), id]
	if is_cat(pet) and rub_ready(pet, now):
		return "%s 想跟你亲近：play_pet %s 陪它玩一会儿" % [name_text(pet), id]
	if is_dog(pet) and not guarding(pet, now, hour):
		return "%s 想玩：play_pet %s 扔球" % [name_text(pet), id]
	return ""

## 单只宠物的完整读数（petsDetailed 的一行）。
static func pet_view(pet:Dictionary, now:float, hour:float) -> Dictionary:
	var kind := str(pet.get("kind", ""))
	var stage := stage_of(pet)
	var left := grow_left(pet, now)
	var breed := breed_of(pet)
	return {
		"id": str(pet.get("id", "")), "kind": kind, "kindName": kind_cn(kind),
		"breed": breed, "breedName": breed_cn(pet), "breedNote": breed_note(pet),
		"stage": stage, "stageName": stage_cn(stage), "adult": stage != "baby",
		"stageText": stage_text(pet, now),
		"growSecondsLeft": snappedf(left, 0.1),
		"growDaysLeft": (ceili(left / 86400.0) if stage == "baby" else 0),
		"bornAt": float(pet.get("born_at", 0.0)),
		"scale": snappedf(body_scale(pet), 0.001),
		"breedScale": snappedf(breed_scale(pet), 0.001),
		"stageScale": snappedf(float(stage_rules(pet).get("scale", 1.0)), 0.001),
		"speedMult": snappedf(speed_mult(pet), 0.001),
		"name": str(pet.get("name", "")), "displayName": name_text(pet), "shortName": short_name(pet),
		"ownerId":str(pet.get("owner_id","")), "ownerName":preload("res://core/pet_owner.gd").caption(pet),
		"named_by": named_by_of(pet), "named_byName": named_by_cn(named_by_of(pet)),
		"satiety": snappedf(food_of(pet), 0.1), "bond": snappedf(bond_of(pet), 0.1),
		"hungry": is_hungry(pet), "hungryBelow": snappedf(hungry_below(), 0.1),
		"away": is_away(pet, now),
		"awake": cat_awake(hour) if is_cat(pet) else true,
		"following": wants_follow(pet, now, hour),
		"guarding": guarding(pet, now, hour),
		"anxious": anxious(pet, now) if is_dog(pet) else false,
		"happy": happy(pet, now) if is_dog(pet) else false,
		"state": pet_state(pet, now, hour),
		"gifts": int(pet.get("gifts", 0)), "guards": int(pet.get("guards", 0)),
		"away_seconds": away_left(pet, now),
		"next": next_of(pet, now, hour),
		"feedItems": feed_items_text(kind),
	}

# ---------------- 喂食待办（v2：喂食是手动，但要让她知道） ----------------
## 把 {模板} 里的占位符换成真数字。只换出现过的键，不猜。
static func _fill(template:String, vars:Dictionary) -> String:
	var out := template
	for k in vars:
		out = out.replace("{%s}" % str(k), str(vars[k]))
	return out

## 40.0 -> "40"，32.5 -> "32.5"（读数里的数字不带多余小数）。
static func _num(v:float) -> String:
	if absf(v - roundf(v)) < 0.05:
		return "%d" % int(roundf(v))
	return "%.1f" % v

## 谁饿了、饿到多少、该喂什么 —— 变成 look/survey 的 next[]/urgent[] 里的真条目。
## 返回 [{kind:"pet", id, petKind, hunger, hungry_below, loss, has_food, text, next, short}]
##   * loss = true：这件事不做的真实后果是"亲密掉、回馈变少"（不是死；宠物不会死，no_death 不变）
##   * has_food = false：背包里现在没有它能吃的，text 会追加"先去 buy"的提示
## 数字全部来自 pets_rules.json（food.hungry_below / food.feed_items），代码里没有阈值。
static func hungry_rows(farm_data:Dictionary, now:float, bag:Dictionary = {}) -> Array:
	var out := []
	if not ok():
		return out
	var t := todo_rules()
	if t.is_empty():
		return out
	var below := hungry_below()
	var prefix := str(t.get("loss_prefix", "【要紧】"))
	var consequence := str(t.get("consequence", ""))
	var line_tpl := str(t.get("hungry_line", "{name} 饿了（饱食度 {food}，低于 {below} 就该喂）：喂它{food_list}"))
	var urgent_tpl := str(t.get("hungry_urgent", "{prefix}{name} 饿了（饱食度 {food}，低于 {below} 就该喂）：喂它{food_list}"))
	var short_tpl := str(t.get("hungry_short", "{name} 饿着（{food} < {below}）"))
	var no_food_tpl := str(t.get("no_food_hint", ""))
	var pets_state = farm_data.get("pets", {})
	if not pets_state is Dictionary or not pets_state.get("list", null) is Array:
		return out
	for pet in pets_state.list:
		if not pet is Dictionary:
			continue
		if not known_kind(str(pet.get("kind", ""))):
			continue
		if not is_hungry(pet):
			continue
		var kind := str(pet.get("kind", ""))
		var food := food_of(pet)
		var vars := {
			"name": short_name(pet), "by_name": name_text(pet),
			"kind_name": kind_cn(kind), "breed": breed_cn(pet),
			"food": _num(food), "below": _num(below), "raise_to": _num(feed_raise_to()),
			"food_list": feed_items_text(kind), "prefix": prefix,
			"consequence": consequence, "id": str(pet.get("id", "")),
		}
		var has_food := false
		for item in feed_items(kind):
			var want := str(item)
			for k in bag:
				if int(bag[k]) > 0 and (str(k) == want or str(k).begins_with(want + ":")):
					has_food = true
					break
			if has_food:
				break
		var text := _fill(urgent_tpl, vars)
		if not has_food and no_food_tpl != "":
			text += "（" + _fill(no_food_tpl, vars) + "）"
		out.append({
			"kind": "pet", "id": str(pet.get("id", "")), "petKind": kind,
			"hunger": snappedf(food, 0.1), "hungry_below": snappedf(below, 0.1),
			"loss": true, "has_food": has_food,
			"text": text,
			"next": _fill(line_tpl, vars),
			"short": _fill(short_tpl, vars),
		})
	return out

# ---------------- 给 _farm_reading 的整份读数 ----------------
## farm_data 是农场存档（sim.data）；没有 pets 键时如实说"还没有宠物"。
static func reading(farm_data:Dictionary, now:float, hour:float) -> Dictionary:
	var total := 0
	var rows := []
	var detailed := []
	var pets_state = farm_data.get("pets", {})
	var list:Array = []
	if pets_state is Dictionary and pets_state.get("list", null) is Array:
		list = pets_state.list
	for pet in list:
		if not pet is Dictionary:
			continue
		total += 1
		detailed.append(pet_view(pet, now, hour))
	var max_rows := int(section("display").get("reading", {}).get("max_pets", 40))
	var shown := mini(total, max_rows)
	for i in shown:
		rows.append(pet_line(list[i], now, hour))
	if total == 0:
		rows.append("农场里还没有宠物：在农场的宠物角领养（adopt_pet 猫 / 狗，可选品种）")
	elif total > shown:
		rows.append("……还有 %d 只没列出来（说 look 名字或编号 可以单独看）" % (total - shown))
	var menu := {}
	for k in kinds():
		menu[str(k)] = breed_menu(str(k))
	return {
		"pets": rows,
		"petsDetailed": detailed.slice(0, max_rows),
		"petsTotal": total,
		"petsHidden": maxi(0, total - shown),
		"petRules": {
			"adopt": adopt_rules(), "gauges": gauges(), "food": food_rules(), "bond": bond_rules(),
			"naming": naming(), "display": display(), "rewards": section("rewards"),
			"cat": kind_rules("cat"), "dog": kind_rules("dog"),
			"breeds": breeds(), "growth": growth(), "todo": todo_rules(),
		},
		"petBreeds": menu,
		"petActions": action_rows(),
	}

## 单只详情（look 7 / look 咪咪）：按编号或名字找。
static func find_pet(farm_data:Dictionary, key:String) -> Dictionary:
	var t := key.strip_edges()
	if t == "":
		return {}
	var pets_state = farm_data.get("pets", {})
	if not pets_state is Dictionary or not pets_state.get("list", null) is Array:
		return {}
	for pet in pets_state.list:
		if not pet is Dictionary:
			continue
		if str(pet.get("id", "")) == t:
			return pet
		if str(pet.get("name", "")).strip_edges() == t:
			return pet
	return {}

# ---------------- 把喂食待办并进农场读数（v2，业主特别问的那一条） ----------------
## look/survey 的 next[] / urgent[] / todo 是 farm_rules.gd 从真实存档算出来的（田/圈/牲畜）。
## 这里把"谁饿了"并进去，规则是**和「牛饿了」同级**：
##   * urgent[]：插在所有 kind=="animal" 的条目之后、田的条目之前（同级的会掉回馈的事排一起）
##   * next[]  ：农场把 urgent 的文本排在最前面，所以宠物那几条插在同样的位置
##   * todo    ：农场那句"现在该做"后面接上宠物那句短的（她扫一眼就看见）
## 农场没饿的时候原样返回（一个字段都不加、不编）。
## 绝不自动喂：这里只产生文字，feed_pet 永远是别人手动调用。
static func merge_farm_todo(next_in:Array, urgent_in:Array, todo_in:String, farm_data:Dictionary, bag:Dictionary, now:float) -> Dictionary:
	var rows := hungry_rows(farm_data, now, bag)
	if rows.is_empty():
		return {"next": next_in, "urgent": urgent_in, "todo": todo_in, "petRows": []}
	var urgent_out := urgent_in.duplicate()
	## 找到第一个不是牲畜的条目：宠物就插在这儿（= 和牲畜同级，不抢在它们前面）。
	var at := urgent_out.size()
	for i in urgent_out.size():
		var row = urgent_out[i]
		var kind_of_row := str(row.get("kind", "")) if row is Dictionary else ""
		if kind_of_row != "animal":
			at = i
			break
	for i in rows.size():
		urgent_out.insert(at + i, rows[i])
	var next_out := next_in.duplicate()
	var next_at := mini(at, next_out.size())
	for i in rows.size():
		next_out.insert(next_at + i, str(rows[i].get("next", "")))
	var todo_out := todo_in
	var shorts := []
	for r in rows:
		var s := str(r.get("short", ""))
		if s != "":
			shorts.append(s)
	if not shorts.is_empty():
		var tail := "；".join(shorts)
		todo_out = (todo_in.strip_edges() + "；" + tail) if todo_in.strip_edges() != "" else tail
	return {"next": next_out, "urgent": urgent_out, "todo": todo_out, "petRows": rows}

# ---------------- 缺失话术 ----------------
static func missing_text(list:Array) -> String:
	if list.is_empty():
		return ""
	var names := []
	for m in list:
		if m is Dictionary:
			names.append(str(m.get("text", "")))
	return "缺：" + "、".join(names)
