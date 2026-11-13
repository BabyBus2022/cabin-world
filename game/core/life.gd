extends Node
## Feelings and daily life: pure rules, no files. Character data comes in and new data goes out.
## Every result matches the host's world-experience.mjs, world-life.mjs and world-agency.mjs; a test runs thousands of random sequences through both.
## This is simulated character state, not a claim about real emotion or sensors.
##
## INTERFACE: functions the game and host messages use. Field lists: ../docs/INTERFACES.md section 7.
##   experience(args)  args: saved, history, who, objectId, use, weather, companions, taste, outcome, product, label, now.  Returns the new feeling.
##   arcade_feeling(args)  args: saved, result ("won", "lost" or "draw"), name, partner, now.  Returns the new feeling.
##   apply_event(saved, event, who, day, now, weather)  Returns { life, joy, notes, memorable, diary }.
##   life_view(args)  args: who, life, feeling, weather, day, now, sleeping.  Returns what she knows about her day.
##   play_outcome(use, weather, umbrella, random, fish_luck, blanks)  Returns { lines, outcome }; outcome is { catch, sizeCm, released }, { flew, height } or { skips }.

const HOUR := 3600000.0
const SATIETY_PER_HOUR := 4.0
const HUNGRY_BELOW := 35.0
const HYDRATION_PER_HOUR := 5.0
const THIRSTY_BELOW := 35.0
const FOOD_FILL := {"hot_milk": 14, "hot_coffee": 2, "hot_latte": 12, "hot_cocoa": 14, "ginger_tea": 5, "hot_honey_lemon": 5, "hot_green_tea": 3, "hot_corn_milk": 16, "bread": 32, "fishcookie": 22, "chips": 20, "choco": 16, "vanilla": 14, "milk": 14, "melonbar": 10, "gummy": 8, "soda": 5, "lemontea": 5, "oolong": 3, "water": 2}
const DRINK_FILL := {"water": 40, "oolong": 30, "lemontea": 30, "hot_green_tea": 30, "hot_honey_lemon": 28, "soda": 25, "milk": 25, "hot_milk": 25, "hot_latte": 25, "hot_cocoa": 25, "ginger_tea": 25, "hot_corn_milk": 22, "hot_coffee": 15}
const SHOP_OBJECT_OF := {"snack": "snack_shelf", "drink": "drink_fridge", "icecream": "freezer", "hotdrink": "hot_cabinet"}
const WARMTH_FADE_HOURS := 0.8
const BATH := {
	"swim": {"warm": 18, "joy": 8, "calm": 2, "energy": -5, "feel": ["在温热的水里划开手臂，水流贴着身子滑过去，游几下就热起来了", "换气时脸上全是水汽，水声闷闷的，浮着的感觉轻飘飘的", "游到池边喘口气，手脚有点酸，心里却很痛快"]},
	"soak": {"warm": 35, "joy": 6, "calm": 12, "energy": 6, "feel": ["热水一点点漫上肩膀，绷了一天的劲全松开了", "刚下水时烫得吸了口气，很快就暖到心里，脸上也慢慢发热", "靠着石头泡着，水汽扑在脸上，连脑子都慢下来了"]},
	"shower": {"warm": 20, "joy": 4, "calm": 5, "energy": 4, "feel": ["热水从头顶淋下来，顺着肩膀往下流，帘子里全是白白的蒸汽", "闭着眼站在热水下，身上的疲倦跟着水流走了", "洗得清清爽爽，皂香混着水汽，呼吸都变轻了"]},
}
const BATH_OBJECTS := ["onsen_pool", "onsen_soak", "onsen_shower"]
const PHYSICAL := {"swing": "秋千升起时风拂过脸，落下来时心口轻轻一颤", "slide": "顺着滑梯滑下，落地后还想回头看一眼", "carousel": "握着栏杆慢慢转，周围花草转成一圈，停下来有点晕", "seesaw": "握住把手，随着同一块木板一上一下", "rider": "小鲸鱼弹簧座轻轻回弹，脚尖跟着一晃一晃", "pier": "看着浮漂和河面的涟漪，心慢慢静下来", "bench": "坐在长椅上，肩膀松下来", "meadow": "草地开阔，风从身边吹过", "flower_bed": "凑近花坛，闻到淡淡的花香", "river": "河水凉凉的，鸭子在旁边游"}
const DAILY_EVENTS := [
	{"id": "sale_snack", "text": "小卖部的零食今天打七折", "sale": "snack"},
	{"id": "sale_drink", "text": "小卖部的饮料今天打七折", "sale": "drink"},
	{"id": "sale_icecream", "text": "小卖部的冰淇淋今天打七折", "sale": "icecream"},
	{"id": "fish_day", "text": "今天河里的鱼特别活跃，很容易上钩", "fishLuck": 1.6},
	{"id": "ducklings", "text": "河边来了一窝毛茸茸的小鸭子", "bonus": {"use": "feed_ducks", "joy": 5, "line": "小鸭子排成一队跟着游过来，太可爱了"}},
	{"id": "butterflies", "text": "花坛的花全开了，蝴蝶比平时多很多", "bonus": {"use": "watch_butterfly", "joy": 5, "line": "好多蝴蝶绕着花坛飞，有一只差点停到手上"}},
]
const WISHES := [
	{"id": "big_fish", "cat": "play", "text": "钓到一条15厘米以上的鱼", "hint": {"objectId": "pier", "use": "fish"}},
	{"id": "two_fish", "cat": "play", "text": "钓上来两条鱼", "need": 2, "hint": {"objectId": "pier", "use": "fish"}},
	{"id": "skip4", "cat": "play", "text": "打水漂跳到4下", "hint": {"objectId": "river", "use": "skip_stones"}},
	{"id": "kite", "cat": "play", "text": "把风筝放起来", "hint": {"objectId": "meadow", "use": "fly_kite"}},
	{"id": "three_plays", "cat": "play", "text": "在公园玩三样不同的东西", "need": 3, "distinct": true, "hint": {"objectId": "swing", "use": "swing"}},
	{"id": "ducks", "cat": "play", "text": "去河边喂一次鸭子", "hint": {"objectId": "river", "use": "feed_ducks"}},
	{"id": "butterfly", "cat": "play", "text": "去花坛看蝴蝶", "hint": {"objectId": "flower_bed", "use": "watch_butterfly"}},
	{"id": "arcade_play", "cat": "play", "text": "去电玩城玩一局"},
	{"id": "arcade_win", "cat": "play", "text": "在电玩城赢一局"},
	{"id": "treat", "cat": "self", "text": "吃到一样自己喜欢的东西"},
	{"id": "new_food", "cat": "self", "text": "尝一样没吃过的东西"},
	{"id": "read", "cat": "self", "text": "翻一会儿书"},
	{"id": "talk", "cat": "bond", "peer_text": ["和", "好好聊一次"]},
	{"id": "gift", "cat": "bond", "peer_text": ["送", "一点好吃的"]},
	{"id": "learn", "cat": "bond", "text": "学到一点新东西"},
]
const ACHIEVEMENT_NAMES := [["first_fish", "第一条鱼"], ["fish_20", "二十厘米俱乐部"], ["fish_50", "河边老手"], ["species_4", "小河图鉴"], ["kite_5", "风的朋友"], ["skip_6", "水漂高手"], ["foods_8", "小卖部美食家"], ["wish_10", "说到做到"], ["perfect_day", "圆满的一天"], ["first_gift", "第一份心意"], ["friend", "成了朋友"], ["close", "最亲近的人"]]
const BOND_LEVELS := [[80, "最亲近的人"], [60, "很要好"], [40, "朋友"], [20, "熟悉起来了"], [8, "说得上话"], [0, "刚认识"]]
const WEEK := ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]

## The real clock in milliseconds. A test can pin it.
var clock_override := -1.0


func clock() -> float:
	return clock_override if clock_override >= 0.0 else SharedFeed.now_ms()


# ---- JavaScript's meanings, spelled out so results match exactly -------------

## Number(x): anything missing is NaN, and every comparison with NaN is false.
static func n(v) -> float:
	if v == null:
		return NAN
	if v is bool:
		return 1.0 if v else 0.0
	if v is String:
		return v.to_float() if v.is_valid_float() else (0.0 if v == "" else NAN)
	return float(v)


## x ?? d
static func nz(v, d):
	return d if v == null else v


## x || d, and whether a value counts as true.
static func truthy(v) -> bool:
	if v == null:
		return false
	if v is bool:
		return v
	if v is String:
		return v != ""
	if v is float or v is int:
		return v != 0 and not is_nan(float(v))
	return true


static func or_(v, d):
	return v if truthy(v) else d


## Math.round: halves go up, including negative ones.
static func js_round(x: float) -> float:
	return floor(x + 0.5)


static func clamp100(x: float) -> float:
	return maxf(0.0, minf(100.0, js_round(x)))


static func cap(x: float, a := 0.0, b := 100.0) -> float:
	return minf(b, maxf(a, x))


static func clip(s, count: int) -> String:
	return str(or_(s, "")).substr(0, count)


## How a number reads inside text: 15, not 15.0.
static func num(v) -> String:
	var f := float(v)
	return str(int(f)) if f == floor(f) and absf(f) < 1e15 else str(f)


static func get_num(d, key: String, fallback: float) -> float:
	if d is Dictionary and d.get(key) != null:
		return float(d[key])
	return fallback


## Array.sort is stable; better is true when a goes before b.
static func stable_sort(rows: Array, better: Callable) -> Array:
	var out: Array = []
	for row in rows:
		var i := out.size()
		while i > 0 and better.call(row, out[i - 1]):
			i -= 1
		out.insert(i, row)
	return out


static func seeded(text: String) -> float:
	var h := 2166136261
	for i in text.length():
		h ^= text.unicode_at(i)
		h = (h * 16777619) & 0xFFFFFFFF
	h ^= h >> 15
	h = (h * 2246822519) & 0xFFFFFFFF
	h ^= h >> 13
	h = (h * 3266489917) & 0xFFFFFFFF
	h ^= h >> 16
	return float(h) / 4294967296.0


static func _unique(rows: Array) -> Array:
	var out: Array = []
	for r in rows:
		if not r in out:
			out.append(r)
	return out


static func _last(rows: Array, count: int) -> Array:
	return rows.slice(maxi(0, rows.size() - count))


static func _join(rows: Array, sep: String) -> String:
	var parts := PackedStringArray()
	for r in rows:
		parts.append(str(r))
	return sep.join(parts)


# ---- Feelings ---------------------------------------------------------------

func thirst_of(h: float) -> String:
	return "渴得嗓子发干" if h < 15 else ("有点渴" if h < THIRSTY_BELOW else "")


func hunger_of(s: float) -> String:
	return "很饿" if s < 20 else ("有点饿" if s < HUNGRY_BELOW else ("不饿" if s < 75 else "饱饱的"))


func liking_of(who: String, feeling, id: String) -> float:
	var base := 3.0 if id in Residents.flavor(who)["favorite_foods"] else 0.0
	var score := 0.0
	if feeling is Dictionary and feeling.get("tastes") is Dictionary:
		var row = feeling["tastes"].get(id)
		if row is Dictionary:
			score = float(or_(row.get("score"), 0))
	return base + score


func liked_foods(who: String, feeling, products: Array, limit := 4) -> Array:
	var rows: Array = []
	for p in products:
		if p.get("kind") != "use" and liking_of(who, feeling, p["id"]) >= 2:
			rows.append(p)
	rows = stable_sort(rows, func(a, b): return liking_of(who, feeling, a["id"]) > liking_of(who, feeling, b["id"]))
	var out: Array = []
	for p in rows.slice(0, limit):
		out.append(p["name"])
	return out


func stomach_note(who: String, feeling: Dictionary, products: Array) -> String:
	var likes := liked_foods(who, feeling, products)
	var thirst := thirst_of(float(nz(feeling.get("hydration"), 70)))
	return "肚子：%s（饱腹感%s/100）%s%s" % [hunger_of(float(feeling["satiety"])), num(feeling["satiety"]), "；" + thirst_of(float(feeling["hydration"])) if thirst != "" else "", "；最近爱吃：" + _join(likes, "、") if not likes.is_empty() else ""]


func choose_food(who: String, feeling: Dictionary, products: Array, weather: Dictionary, now: float, random: Callable):
	var hungry := float(feeling["satiety"]) < HUNGRY_BELOW
	var temp := n(weather.get("temp"))
	var rows: Array = []
	for p in products:
		if p.get("kind") == "use":
			continue
		var fill := float(FOOD_FILL.get(p["id"], 0))
		var last_at := 0.0
		if feeling.get("tastes") is Dictionary and feeling["tastes"].get(p["id"]) is Dictionary:
			last_at = n(or_(feeling["tastes"][p["id"]].get("lastAt"), 0))
		var recent := now - last_at < 18 * HOUR
		var cold := truthy(p.get("cold"))
		var hot := truthy(p.get("hot"))
		var score := liking_of(who, feeling, p["id"]) * 2 + fill * (0.5 if hungry else 0.15) + (-4.0 if cold and temp <= 13 else 0.0) + (2.0 if cold and temp >= 24 else 0.0) + (3.0 if hot and temp <= 13 else 0.0) + (-3.0 if hot and temp >= 26 else 0.0) + (-3.0 if recent else 0.0) + float(random.call()) * 2
		rows.append({"p": p, "score": score})
	rows = stable_sort(rows, func(a, b): return a["score"] > b["score"])
	return rows[0]["p"] if not rows.is_empty() else null


func hunger_plan(who: String, feeling: Dictionary, bag: Array, shop: Array, coins: float, weather: Dictionary, now: float, random: Callable):
	if float(feeling["satiety"]) >= HUNGRY_BELOW:
		return null
	var in_bag: Array = bag.filter(func(p): return float(FOOD_FILL.get(p["id"], 0)) >= 8)
	var from_bag = choose_food(who, feeling, in_bag, weather, now, random)
	if from_bag != null:
		return {"action": "eat", "product": from_bag}
	var can_buy: Array = shop.filter(func(p): return float(FOOD_FILL.get(p["id"], 0)) >= 8 and float(p["price"]) <= coins and SHOP_OBJECT_OF.has(p.get("shelf")))
	var to_buy = choose_food(who, feeling, can_buy, weather, now, random)
	return {"action": "buy", "product": to_buy} if to_buy != null else {"action": "broke"}


func thirst_plan(who: String, feeling: Dictionary, bag: Array, shop: Array, coins: float, weather: Dictionary, now: float, random: Callable):
	if float(nz(feeling.get("hydration"), 70)) >= THIRSTY_BELOW:
		return null
	var from_bag = choose_food(who, feeling, bag.filter(func(p): return p.get("kind") == "drink"), weather, now, random)
	if from_bag != null:
		return {"action": "drink", "product": from_bag}
	var can_buy: Array = shop.filter(func(p): return p.get("kind") == "drink" and float(p["price"]) <= coins and SHOP_OBJECT_OF.has(p.get("shelf")))
	var to_buy = choose_food(who, feeling, can_buy, weather, now, random)
	return {"action": "buy", "product": to_buy} if to_buy != null else {"action": "broke"}


func body_note(feeling: Dictionary, is_cold := false) -> String:
	var w := float(or_(feeling.get("warmth"), 0))
	var from: String = str(or_(feeling.get("warmthFrom"), ""))
	var dry := float(nz(feeling.get("hydration"), 70)) < THIRSTY_BELOW
	if w < 8:
		if dry:
			return "身上：嘴巴有点干，想喝点东西。不用报数。"
		return "身上：手脚有点凉，挺想喝点热的，或者去泡一泡。" if is_cold else ""
	var high := w >= 55
	var mid := w >= 25
	var text := ""
	match from:
		"soak":
			text = "刚泡完汤，身上还热热的，脸颊发红，指尖有点发皱，整个人软绵绵的" if high else ("泡汤的暖意还留在身上，肩膀松松的，有点想睡" if mid else "身上还留着一点泡过汤的暖意")
		"swim":
			text = "刚游完，身上热乎乎的，头发还湿着，手脚有点酸" if high else ("游泳后的热气还没散，手脚酸酸的，挺舒服" if mid else "游过泳的那点酸和暖还在")
		"shower":
			text = "刚冲完热水，浑身清爽，头发半干，还带着皂香" if high else ("热水澡的暖和气还在，身上干干净净的" if mid else "洗过澡之后身上一直清清爽爽的")
		_:
			text = "肚子里暖暖的，手心还留着杯子的热度" if mid else "喝过热的之后身上暖了一点"
	return "身上：" + text + ("，嘴巴有点干" if dry else "") + "。这是你此刻身体的感觉，可以自然流露，不用报数。"


func cheer_need(feeling: Dictionary, mood: Dictionary) -> bool:
	return float(nz(feeling.get("joy"), 45)) < 38 or mood.get("key") in ["down", "bored", "tired"]


func cheer_ideas(feeling: Dictionary, weather: Dictionary, uses: Dictionary, now: float) -> Array:
	var tired := float(nz(feeling.get("energy"), 75)) < 30
	var outside: bool = n(weather.get("rain")) <= 0.5 and weather.get("phase") != "night" and not truthy(weather.get("snow"))
	var rows: Array = [{"objectId": "onsen_soak", "use": "soak", "what": "去汤屋泡一泡", "kind": "bath"}, {"objectId": "onsen_bench", "use": "rest", "what": "在汤屋的长凳上歇一会儿", "kind": "bath", "rest": true}]
	if not tired:
		rows.append_array([{"objectId": "onsen_pool", "use": "swim", "what": "去汤屋游几圈", "kind": "bath"}, {"objectId": "arcade_snake", "use": "play", "what": "去电玩城玩贪吃蛇", "kind": "game"}, {"objectId": "arcade_blocks", "use": "play", "what": "去电玩城玩俄罗斯方块", "kind": "game"}, {"objectId": "arcade_mines", "use": "play", "what": "去电玩城玩扫雷", "kind": "game"}])
		if outside:
			rows.append_array([{"objectId": "swing", "use": "swing", "what": "去公园荡秋千", "kind": "park"}, {"objectId": "slide", "use": "slide", "what": "去公园滑滑梯", "kind": "park"}, {"objectId": "carousel", "use": "spin", "what": "去公园坐转盘", "kind": "park"}, {"objectId": "pier", "use": "fish", "what": "去河边钓鱼", "kind": "park"}, {"objectId": "river", "use": "skip_stones", "what": "去河边打水漂", "kind": "park"}])
	if outside:
		rows.append({"objectId": "bench", "use": "sit_bench", "what": "去公园长椅坐坐", "kind": "park", "rest": true})
	var fresh: Array = rows.filter(func(r):
		var u = uses.get(r["objectId"])
		return not (truthy(u) and now - n(or_(u.get("at"), 0)) < 45 * 60000.0))
	return (fresh if not fresh.is_empty() else rows).filter(func(r): return tired or not r.get("rest", false))


func feeling_now(saved, now: float) -> Dictionary:
	var s: Dictionary = saved if saved is Dictionary else {}
	var hours := maxf(0.0, (now - float(or_(s.get("at"), now))) / HOUR)
	var decay := exp(-hours / 4.0)
	return {
		"joy": clamp100(45.0 + (float(nz(s.get("joy"), 45)) - 45.0) * decay),
		"energy": clamp100(float(nz(s.get("energy"), 75)) + hours * 3.0),
		"calm": clamp100(55.0 + (float(nz(s.get("calm"), 55)) - 55.0) * decay),
		"satiety": clamp100(float(nz(s.get("satiety"), 70)) - hours * SATIETY_PER_HOUR),
		"hydration": clamp100(float(nz(s.get("hydration"), 70)) - hours * HYDRATION_PER_HOUR),
		"warmth": clamp100(float(or_(s.get("warmth"), 0)) * exp(-hours / WARMTH_FADE_HOURS)),
		"warmthFrom": or_(s.get("warmthFrom"), ""),
		"tastes": or_(s.get("tastes"), {}),
		"last": or_(s.get("last"), ""),
		"lastAt": float(or_(s.get("at"), 0)),
		"at": now,
		"source": "simulated-world",
	}


func experience(a: Dictionary) -> Dictionary:
	var now: float = float(a["now"])
	var who: String = str(a.get("who", ""))
	var object_id: String = str(nz(a.get("objectId"), ""))
	var use = a.get("use")
	var weather: Dictionary = nz(a.get("weather"), {})
	var companions: Array = nz(a.get("companions"), [])
	var history: Dictionary = nz(a.get("history"), {})
	var outcome = a.get("outcome")
	var product = a.get("product")
	var label = a.get("label")
	var state := feeling_now(a.get("saved"), now)
	if product is Dictionary and product.get("shelf")=="restaurant" and use=="eat":
		# Body consequences only. Subjective food reactions belong to the original resident.
		state.satiety=clamp100(float(state.satiety)+float(product.get("satiety",40)))
		state.last="已吃完"+str(product.get("name","这道菜"))+"，饱食度 "+str(roundi(state.satiety))+"/100；口味评价由自己决定"
		state.lastAt=now;state.objectId=object_id;state.use=use
		state.delta={"joy":0,"energy":0,"calm":0};state.highlight="";state.memorable=false
		return state
	var previous = history.get(object_id)
	var recent: bool = truthy(previous) and now - n(previous.get("at")) < 45 * 60000.0
	var novelty := 0.35 if recent else 1.0
	var preferred: Array = Residents.flavor(who)["preferred_objects"]
	var play: bool = object_id in ["swing", "slide", "carousel", "seesaw", "rider", "pier", "meadow", "river", "xj_beach"]
	var together: Array = companions.filter(func(p): return p.get("near") != false)
	var social := 4.0 if not together.is_empty() and play else 0.0
	var joy := (10.0 if play else (7.0 if object_id == "bag" else 4.0)) * novelty + (3.0 if object_id in preferred else 0.0) + social
	var energy := -4.0 if play else (3.0 if object_id == "bag" else 1.0)
	var calm := 7.0 if object_id == "pier" or object_id == "bench" else 2.0
	if object_id=="xj_beach":
		calm=6 if use=="play_sand" else 10
		energy=-3 if use=="play_sand" else 2
	var rain := n(weather.get("rain"))
	var temp := n(weather.get("temp"))
	var start_energy: float = state["energy"]
	var start_satiety: float = state["satiety"]
	var start_hydration: float = state["hydration"]
	var start_warmth: float = state["warmth"]
	if rain > 0.5 and play:
		joy -= 6
		energy -= 2
	if start_energy < 25 and play:
		joy -= 4
		energy -= 3
	if use in ["rest", "nap", "sit_bench"]:
		energy = 10
		calm = 10
	var bath = BATH.get(use) if object_id in BATH_OBJECTS else null
	if bath != null:
		joy = float(bath["joy"]) * (0.6 if recent else 1.0)
		energy = bath["energy"]
		calm = bath["calm"]
	var bath_line := ""
	if bath != null:
		bath_line = bath["feel"][int(floor(now / 60000.0)) % bath["feel"].size()]
	elif object_id == "onsen_bench":
		bath_line = "坐在干爽的木长凳上慢慢缓过来，身上还带着水里的热气" if start_warmth >= 25 else "坐在木长凳上歇一歇，水汽慢慢飘过来"
	elif object_id == "onsen_locker":
		bath_line = "换上干爽的浴衣，棉布软软的，还带点烘过的暖意" if use == "change" else ("换回自己的衣服，身上还留着汤屋的暖和气" if start_warmth >= 15 else "换回自己的衣服")
	if object_id=="xj_beach":
		bath_line="手指在干沙上勾出一只小鲸鱼，细沙从指尖滑落" if use=="play_sand" else "海浪一阵阵靠近又退开，注意力慢慢落在浪声上" if use=="listen_waves" else "站在岸边看夜色中的海，近处的浪花明暗交替" if weather.get("phase")=="night" else "站在干沙滩看开阔海面，浪花沿着岸边铺开"
	var first: String = str(or_(a.get("taste"), ""))
	if first == "":
		first = bath_line
	if first == "":
		first = str(PHYSICAL.get(object_id, ""))
	if first == "":
		first = "刚才%s，手上有事做，心也跟着定下来" % str(label) if truthy(label) else "认真用过房间里的这件物品"
	var lines: Array = [first]
	var highlight := ""
	var satiety: float = start_satiety - (3.0 if play else 0.0)
	var tastes: Dictionary = state["tastes"]
	if play and start_satiety < 20:
		joy -= 3
		lines.append("肚子饿得咕咕叫，玩得有点没力气")
	var warmth: float = start_warmth
	var warmth_from = state["warmthFrom"]
	var hydration: float = start_hydration
	if object_id == "tea_table" and use == "drink_tea":
		hydration += 25
	if bath != null and use != "shower":
		hydration -= 10.0 if use == "soak" else 8.0
		if hydration < THIRSTY_BELOW:
			lines.append("嘴巴有点干，上去得喝点水")
	if bath != null:
		if start_warmth >= 70 and use == "soak":
			joy -= 4
			energy -= 6
			lines.append("泡得太久了，有点头晕，该上去吹吹风、喝点水")
		elif temp <= 12 and start_warmth < 30:
			joy += 3
			lines.append("外面那么冷，这一下从手脚暖到了心里")
		elif temp >= 28 and use != "shower":
			joy -= 1
			lines.append("外面本来就热，在这里待一会儿就出了一身汗")
		if start_energy < 35 and use != "swim":
			energy += 6
			lines.append("累的时候来这么一下，整个人缓过来了")
		if use == "swim":
			satiety -= 5
			if start_satiety < HUNGRY_BELOW + 5:
				lines.append("游得肚子有点空了")
		if not together.is_empty() and use != "shower":
			joy += 3
			lines.append(_join(together.map(func(p): return p["name"]), "、") + "也在水里，话都变慢了，只是这样待着就很舒服")
		warmth = minf(100.0, warmth + float(bath["warm"]))
		warmth_from = use
	elif object_id == "onsen_bench":
		warmth = js_round(warmth * 0.85)
	if product is Dictionary and truthy(product.get("hot")):
		warmth = minf(100.0, warmth + 10.0)
		if start_warmth < 25:
			warmth_from = "drink"
	if product is Dictionary and truthy(product.get("cold")) and start_warmth >= 30:
		joy += 3
		lines.append("身上正热着，来口冰的太舒服了")
		warmth = js_round(warmth * 0.85)
	if truthy(outcome):
		if outcome.has("catch"):
			if truthy(outcome.get("sizeCm")):
				var size := float(outcome["sizeCm"])
				var big := size >= 20
				joy += 6.0 + minf(5.0, size / 5.0)
				calm += 2
				lines.append("钓到一条约%s厘米的%s，手都在抖，好开心" % [num(size), str(outcome["catch"])] if big else "钓到一条%s，有点小得意" % str(outcome["catch"]))
				if big:
					highlight = "钓到了约%s厘米的%s" % [num(size), str(outcome["catch"])]
			else:
				joy -= 3
				calm += 3
				lines.append("等了好久是空钩，有点失望，不过河边很安静" if outcome["catch"] == "空钩" else "只钓上来一团水草，忍不住笑了一下")
		if outcome.has("flew"):
			if truthy(outcome["flew"]):
				joy += 7.0 if outcome.get("height") == "很高" else 5.0
				lines.append("风筝飞起来的那一刻，忍不住叫出声")
				if outcome.get("height") == "很高":
					highlight = "风筝飞得很高"
			else:
				joy = minf(joy, 0.0) - 2.0
				lines.append("风筝怎么也飞不起来，有点泄气")
		if outcome.has("skips"):
			var skips := float(nz(outcome["skips"], -1))
			if skips >= 4:
				joy += 5
				lines.append("石片跳了%s下，想再来一次" % num(skips))
				if skips >= 6:
					highlight = "打水漂跳了%s下" % num(skips)
			elif skips == 0:
				joy -= 2
				lines.append("石片直接沉了，有点不服气")
	if truthy(product):
		var pid: String = str(product.get("id"))
		var cold := truthy(product.get("cold"))
		var hot := truthy(product.get("hot"))
		if pid in Residents.flavor(who)["favorite_foods"]:
			joy += 4
			lines.append("是我很喜欢的%s" % str(product.get("name")))
		if cold and temp >= 24:
			joy += 3
			energy += 2
			lines.append("天热吃冰，一下子凉快了")
		if cold and temp <= 13:
			joy -= 2
			lines.append("天有点冷，冰得牙酸")
		if hot and temp <= 13:
			joy += 3
			energy += 1
			lines.append("天冷喝口热的，整个人都暖了")
		if hot and temp >= 26:
			joy -= 1
			lines.append("这么热的天喝热的，出了一身汗")
		if start_energy < 35:
			energy += 5
			lines.append("饿了的时候吃东西，整个人又有力气了")
		if product.get("kind") == "drink":
			hydration += float(DRINK_FILL.get(pid, 20))
			if start_hydration < THIRSTY_BELOW:
				joy += 3
				lines.append("渴的时候喝这一口，舒服多了")
		if product.get("kind") != "use":
			var fill := float(FOOD_FILL.get(pid, 0))
			var row: Dictionary = tastes.get(pid, {})
			var again := now - n(or_(row.get("lastAt"), 0)) < 18 * HOUR
			satiety = start_satiety + fill
			if start_satiety < HUNGRY_BELOW and fill >= 8:
				joy += 5
				lines.append("饿的时候吃什么都特别香")
			if start_satiety >= 90 and fill >= 10:
				joy -= 3
				lines.append("已经很饱了，有点吃不下")
			var tired_of: bool = again and n(row.get("count")) >= 2
			if tired_of:
				joy -= 2
				lines.append("这两天老吃这个，有点腻了")
			var liked := joy >= 8 and not tired_of
			tastes = tastes.duplicate(true)
			tastes[pid] = {"score": maxf(-3.0, minf(5.0, float(or_(row.get("score"), 0)) + (-1.0 if tired_of else (0.5 if liked else 0.0)))), "count": float(or_(row.get("count"), 0)) + 1.0 if again else 1.0, "lastAt": now}
	if social > 0:
		lines.append("和" + _join(together.map(func(p): return p["name"]), "、") + "一起玩，比独自玩更有兴致")
	if recent and bath == null:
		lines.append("刚刚已经玩过，熟悉之后新鲜感少了一些，想换一种活动")
	if rain > 0.5 and play:
		lines.append("雨有点大，衣服湿了，开始想回屋休息")
	var emotion := "整个人暖暖的，很放松" if bath != null and joy > 0 else ("开心又有点雀跃" if joy >= 10 else ("心情轻快了一些" if joy >= 5 else ("感觉还不错" if joy > 0 else "有些疲倦，想歇一歇")))
	lines.append(emotion)
	var next_joy := clamp100(float(state["joy"]) + joy)
	var next_energy := clamp100(start_energy + energy)
	var next_calm := clamp100(float(state["calm"]) + calm)
	var bathed_lately := false
	for id in history:
		if id in BATH_OBJECTS and now - float(or_((history[id] if history[id] is Dictionary else {}).get("at"), 0)) < 90 * 60000.0:
			bathed_lately = true
	var out := state.duplicate()
	out.merge({"joy": next_joy, "energy": next_energy, "calm": next_calm, "satiety": clamp100(satiety), "hydration": clamp100(hydration), "warmth": clamp100(warmth), "warmthFrom": warmth_from, "tastes": tastes, "last": _join(lines, "；"), "at": now, "objectId": a.get("objectId"), "use": use, "delta": {"joy": next_joy - float(state["joy"]), "energy": next_energy - start_energy, "calm": next_calm - float(state["calm"])}, "highlight": highlight, "memorable": (object_id=="xj_beach" and not recent and next_joy>float(state["joy"])) or highlight != "" or (bath != null and not bathed_lately)}, true)
	return out


func arcade_feeling(a: Dictionary) -> Dictionary:
	var now: float = float(a["now"])
	var state := feeling_now(a.get("saved"), now)
	var result = a.get("result")
	var partner: String = str(or_(a.get("partner"), ""))
	var who := "和" + partner + "玩" if partner != "" else "玩"
	var word := "赢了，好开心" if result == "won" else ("输了，有点难过" if result == "lost" else "平局，还不错")
	var joy := 12.0 if result == "won" else (-7.0 if result == "lost" else 1.0)
	var calm := 2.0 if result == "won" else (-3.0 if result == "lost" else 0.0)
	var next := {"joy": clamp100(float(state["joy"]) + joy), "energy": clamp100(float(state["energy"]) - 4.0), "calm": clamp100(float(state["calm"]) + calm)}
	var out := state.duplicate()
	out.merge(next, true)
	out.merge({"last": "在%s%s%s，%s" % [str(a.get("place","电玩城")), who, str(a.get("name")), word], "at": now, "objectId": "arcade", "use": "play", "delta": {"joy": next["joy"] - state["joy"], "energy": next["energy"] - state["energy"], "calm": next["calm"] - state["calm"]}, "highlight": "在%s%s%s赢了" % [str(a.get("place","电玩城")), who, str(a.get("name"))] if result == "won" else ""}, true)
	return out


# ---- The world's day ----------------------------------------------------------

func world_events(day: String, weather: Dictionary) -> Array:
	var out: Array = []
	var v := seeded("event|" + day)
	if v < 0.72:
		out.append(DAILY_EVENTS[int(floor(v / 0.72 * DAILY_EVENTS.size()))])
	var rain := n(weather.get("rain"))
	var dry := not (rain > 0)
	var awake: bool = weather.get("phase") != "night"
	if truthy(weather.get("recentRain")) and dry and awake and n(weather.get("sun")) > 0.2:
		out.append({"id": "rainbow", "text": "雨刚停，天边挂着一道彩虹", "parkJoy": 3, "line": "抬头还能看见雨后的彩虹"})
	if weather.get("phase") == "night" and dry and n(weather.get("cloud")) < 0.35:
		out.append({"id": "stars", "text": "今晚天很清，星星特别多"})
	var wind := n(weather.get("windLevel"))
	if dry and wind >= 2 and wind <= 4:
		out.append({"id": "kite_wind", "text": "今天的风正好，适合放风筝", "bonus": {"use": "fly_kite", "joy": 3, "line": "风稳稳地托着风筝"}})
	return out


func day_words(day: String) -> String:
	var parts := day.split("-")
	if parts.size() != 3:
		return ""
	var at := Time.get_unix_time_from_datetime_string(day + "T04:00:00")
	var d := Time.get_datetime_dict_from_unix_time(at)
	var m: int = d["month"]
	var season := "春天" if m >= 3 and m <= 5 else ("夏天" if m >= 6 and m <= 8 else ("秋天" if m >= 9 and m <= 11 else "冬天"))
	return "%s，%s" % [season, WEEK[d["weekday"]]]


func _peer(who: String) -> String:
	return Residents.flavor(who)["peer_name"]


## Everyone's wishes plus each resident's own.
func _all_wishes() -> Array:
	var rows: Array = WISHES.duplicate()
	for p in Residents.people():
		rows.append_array(p["own_wishes"])
	return rows


func _wish(id: String):
	for w in _all_wishes():
		if w["id"] == id:
			return w
	return null


func _wish_text(w: Dictionary, who: String) -> String:
	if w.has("peer_text"):
		return w["peer_text"][0] + _peer(who) + w["peer_text"][1]
	return w["text"]


func _pick_wishes(who: String, day: String, carry) -> Array:
	var out: Array = []
	for cat in ["play", "self", "bond"]:
		if cat == "bond" and _peer(who).is_empty(): continue
		var best = null
		var best_score := -1.0
		var rows: Array = WISHES.duplicate()
		rows.append_array(Residents.flavor(who)["own_wishes"])
		for w in rows:
			if w["cat"] != cat:
				continue
			var score := seeded("%s|%s|%s" % [who, day, w["id"]]) * (3.0 if w["id"] == carry else 1.0)
			if score > best_score:
				best_score = score
				best = w
		out.append({"id": best["id"], "text": _wish_text(best, who), "need": best.get("need", 1), "have": 0, "seen": [], "done": false, "carried": best["id"] == carry})
	return out


func _wish_passes(id: String, e: Dictionary) -> bool:
	var type = e.get("type")
	var use = e.get("use")
	var o = e.get("outcome")
	var outcome: Dictionary = o if o is Dictionary else {}
	match id:
		"big_fish":
			return type == "use" and use == "fish" and n(outcome.get("sizeCm")) >= 15
		"two_fish":
			return type == "use" and use == "fish" and n(outcome.get("sizeCm")) > 0
		"skip4":
			return type == "use" and use == "skip_stones" and n(outcome.get("skips")) >= 4
		"kite":
			return type == "use" and use == "fly_kite" and truthy(outcome.get("flew"))
		"three_plays":
			return type == "use" and e.get("space") == "park"
		"ducks":
			return type == "use" and use == "feed_ducks"
		"butterfly":
			return type == "use" and use == "watch_butterfly"
		"arcade_play":
			return type == "arcade"
		"arcade_win":
			return type == "arcade" and e.get("result") == "won"
		"treat":
			return type == "eat" and truthy(e.get("liked"))
		"new_food":
			return type == "eat" and truthy(e.get("firstTime"))
		"read":
			return type == "use" and use == "browse_book"
		"tea":
			return type == "use" and use == "brew_tea"
		"sketch":
			return type == "use" and use == "sketch"
		"plant_q":
			return type == "use" and use == "water"
		"feed_fish":
			return type == "use" and use == "feed_fish"
		"watch_fish":
			return type == "use" and use == "watch_fish"
		"plant_x":
			return type == "use" and use == "water_plant"
		"talk":
			return type == "meet"
		"gift":
			return type == "gift_out"
		"learn":
			return type == "learn"
	return false


func _achieved(id: String, l: Dictionary) -> bool:
	var r: Dictionary = l["records"]
	match id:
		"first_fish":
			return float(r["fish"]["count"]) >= 1
		"fish_20":
			return float(r["fish"]["bestCm"]) >= 20
		"fish_50":
			return float(r["fish"]["count"]) >= 50
		"species_4":
			return r["fish"]["species"].size() >= 4
		"kite_5":
			return float(r["kite"]) >= 5
		"skip_6":
			return float(r["skipBest"]) >= 6
		"foods_8":
			return r["foods"].size() >= 8
		"wish_10":
			return float(r["wishes"]) >= 10
		"perfect_day":
			return float(r["perfectDays"]) >= 1
		"first_gift":
			return float(l["bond"]["given"]) >= 1
		"friend":
			return float(l["bond"]["closeness"]) >= 40
		"close":
			return float(l["bond"]["closeness"]) >= 80
	return false


func bond_word(c) -> String:
	for level in BOND_LEVELS:
		if float(c) >= level[0]:
			return level[1]
	return "刚认识"


func empty_life(now: float) -> Dictionary:
	return {"day": "", "wishes": [], "today": null, "diary": [], "achievements": [], "flash": null, "thought": null, "fun": {"value": 60, "at": now}, "contactAt": now, "care": {"water": now, "feed": now},
		"records": {"fish": {"count": 0, "bestCm": 0, "bestName": "", "species": {}}, "kite": 0, "skipBest": 0, "foods": {}, "wishes": 0, "perfectDays": 0, "days": 0, "arcade": {}, "arcadeMatches": []},
		"bond": {"closeness": 20, "talks": 0, "encounters": 0, "given": 0, "got": 0, "knownLikes": [], "lastEncounterDay": "", "todayGain": 0, "gainDay": ""}}


func _merge_over(base: Dictionary, over) -> Dictionary:
	var out := base.duplicate()
	if over is Dictionary:
		for k in over:
			out[k] = over[k]
	return out


func merged(life, now: float) -> Dictionary:
	var base := empty_life(now)
	var l: Dictionary = life if life is Dictionary else {}
	var out := _merge_over(base, l)
	out["fun"] = _merge_over(base["fun"], l.get("fun"))
	out["care"] = _merge_over(base["care"], l.get("care"))
	var records := _merge_over(base["records"], l.get("records"))
	var their_records = l.get("records")
	records["fish"] = _merge_over(base["records"]["fish"], their_records.get("fish") if their_records is Dictionary else null)
	out["records"] = records
	out["bond"] = _merge_over(base["bond"], l.get("bond"))
	return out


func _fresh_today() -> Dictionary:
	return {"fish": 0, "bestFish": "", "bestCm": 0, "foods": [], "talks": 0, "gifts": [], "got": [], "plays": [], "places": [], "arcade": []}


func diary_of(who: String, life: Dictionary) -> String:
	var t: Dictionary = life["today"] if life.get("today") is Dictionary else _fresh_today()
	var peer := _peer(who)
	var parts: Array = []
	if truthy(t.get("fish")):
		parts.append("钓到%s条鱼%s" % [num(t["fish"]), "，最大的是" + str(t["bestFish"]) if truthy(t.get("bestFish")) else ""])
	if not t["plays"].is_empty():
		parts.append("玩了" + _join(_unique(t["plays"]).slice(0, 4), "、"))
	if not t["foods"].is_empty():
		parts.append("吃了" + _join(_unique(t["foods"]).slice(0, 4), "、"))
	if truthy(t.get("talks")):
		parts.append("和%s聊了%s次" % [peer, num(t["talks"])])
	for a in _last(nz(t.get("arcade"), []), 4):
		parts.append(str(a) if str(a).begins_with("在") else "在电玩城"+str(a))
	for v in _last(nz(t.get("visits"), []), 2):
		parts.append(v)
	for g in t["gifts"]:
		parts.append("送了%s%s" % [peer, str(g)])
	for g in t["got"]:
		parts.append("收到%s送的%s" % [peer, str(g)])
	var done: Array = []
	var miss: Array = []
	for w in nz(life.get("wishes"), []):
		(done if truthy(w.get("done")) else miss).append(w["text"])
	if not done.is_empty():
		parts.append("实现了心愿：" + _join(done, "、"))
	if not miss.is_empty() and not parts.is_empty():
		parts.append("没来得及：" + str(miss[0]))
	return _join(parts, "；") + "。" if not parts.is_empty() else "这天没怎么出门，安安静静地过了。"


func roll_life(life, who: String, day: String, now: float) -> Dictionary:
	var l := merged(life, now)
	if l["day"] == day and not l["wishes"].is_empty():
		return {"life": l, "diary": null}
	var diary = null
	var next := l.duplicate()
	next["day"] = day
	next["today"] = _fresh_today()
	var records: Dictionary = l["records"].duplicate()
	records["days"] = float(l["records"]["days"]) + 1
	next["records"] = records
	if truthy(l["day"]):
		var count := 0
		for w in l["wishes"]:
			if truthy(w.get("done")):
				count += 1
		diary = {"day": l["day"], "text": diary_of(who, l), "wishes": count}
		next["diary"] = _last(l["diary"] + [diary], 14)
	var carry = null
	for w in l["wishes"]:
		if not truthy(w.get("done")):
			carry = w["id"]
			break
	next["wishes"] = _pick_wishes(who, day, carry)
	return {"life": next, "diary": diary}


# ---- Interests ------------------------------------------------------------------

func interests_now(saved, now: float) -> Array:
	var rows: Array = []
	if saved is Dictionary:
		for k in saved:
			var r: Dictionary = saved[k].duplicate()
			r["urge"] = cap(float(or_(r.get("urge"), 0)) - maxf(0.0, now - float(r.get("at", 0))) / HOUR * 1.5)
			rows.append(r)
	rows = stable_sort(rows, func(a, b): return a["urge"] > b["urge"])
	return rows.slice(0, 24)


func record_interest(saved, event: Dictionary, now: float) -> Dictionary:
	var id = null
	var name_of = null
	var category = null
	var reward := 0.0
	var product = event.get("product")
	var type = event.get("type")
	if type == "arcade" and event.get("result") in ["won", "lost", "draw"]:
		id = "arcade_" + str(event.get("kind"))
		name_of = event.get("name")
		category = "game"
		reward = 12.0 if event["result"] == "won" else (2.0 if event["result"] == "lost" else 6.0)
	elif type == "eat" and product is Dictionary and truthy(product.get("id")):
		id = product["id"]
		name_of = product.get("name")
		category = "food"
		reward = 12.0 if truthy(event.get("liked")) else 4.0
	elif type=="use" and event.get("objectId")=="xj_beach":
		id="xj_beach";name_of="家旁海边";category="seaside"
		reward=clampf(float(event.get("experienceDelta",{}).get("joy",6)),-4,10)
	elif type == "use" and event.get("space") == "park":
		id = event.get("objectId")
		name_of = event.get("label")
		category = "park"
		var o = event.get("outcome")
		reward = 1.0 if o is Dictionary and o.get("flew") == false else 8.0
	var out := {}
	for r in interests_now(saved, now):
		var row: Dictionary = r.duplicate()
		row["at"] = now
		out[row["id"]] = row
	if not truthy(id):
		return out
	var old: Dictionary = out.get(id, {"id": id, "name": name_of, "category": category, "affinity": 20.0, "urge": 0.0, "count": 0.0, "lastUsed": 0.0})
	var fresh := 1.0 if now - float(old["lastUsed"]) > HOUR else 0.25
	var row: Dictionary = old.duplicate()
	row.merge({"name": name_of, "category": category, "affinity": cap(float(old["affinity"]) + reward * fresh - 2.0), "urge": cap(float(old["urge"]) + reward * fresh, 0.0, 75.0), "count": float(old["count"]) + 1.0, "lastUsed": now, "at": now}, true)
	out[id] = row
	var sorted := stable_sort(out.values(), func(a, b): return float(a["at"]) > float(b["at"]) or (float(a["at"]) == float(b["at"]) and float(a["urge"]) > float(b["urge"])))
	var final := {}
	for r in sorted.slice(0, 24):
		final[r["id"]] = r
	return final


func story_when(at, now := -1.0) -> String:
	var clock_now := now if now >= 0.0 else clock()
	var m := js_round((clock_now - float(at)) / 60000.0)
	if m < 60:
		return "刚才" if m < 2 else num(m) + "分钟前"
	var a := _beijing(float(at))
	if a.substr(0, 10) == _beijing(clock_now).substr(0, 10):
		return "今天" + a.substr(11, 5)
	if a.substr(0, 10) == _beijing(clock_now - 864e5).substr(0, 10):
		return "昨天" + a.substr(11, 5)
	return "%d月%d日" % [a.substr(5, 2).to_int(), a.substr(8, 2).to_int()]


func _beijing(ms: float) -> String:
	return Time.get_datetime_string_from_unix_time(int(floor((ms + 288e5) / 1000.0)))


func pending_stories(life, now: float) -> Array:
	var rows: Array = []
	if life is Dictionary:
		for r in nz(life.get("stories"), []):
			if not truthy(r.get("ownerSharedAt")) and now - float(r["at"]) < 30 * 24 * HOUR:
				rows.append(r)
	return _last(rows, 8)


func agency_note(v: Dictionary) -> String:
	var likes: Array = []
	for r in nz(v.get("interests"), []):
		if float(r.get("affinity", 0)) >= 25 or float(r.get("urge", 0)) >= 8:
			if likes.size() < 4:
				var urge := float(r.get("urge", 0))
				likes.append(str(r.get("name")) + "（" + ("自己想先停一阵" if r.get("choice") == "avoid" else ("有点上头，还想再来" if urge >= 35 else ("有点惦记" if urge >= 15 else "渐渐喜欢"))) + "）")
	var stories: Array = []
	for r in _last(nz(v.get("stories"), []), 3):
		stories.append("[%s] %s：%s" % [str(r.get("id")), story_when(r["at"]), str(r.get("text"))])
	var out := ""
	if not likes.is_empty():
		out += "\n【自己的偏好】" + _join(likes, "、") + "。这是自己的念头，不是命令；你可以顺着兴趣，也可以停下、换别的。饥饿、疲劳、预算和眼前的人优先，不必追输赢。"
	if not stories.is_empty():
		out += "\n【还没给主人讲的热记忆】" + _join(stories, "；") + "。下次聊天或路上遇到朋友时，你可以挑一件自然提起，也可以不说，不要逐条汇报或虚构战绩。时间照上面写的说，不是刚发生的不能说“刚才”。"
	return out


# ---- Something happened ----------------------------------------------------------

func _add_closeness(l: Dictionary, amount: float) -> void:
	l["bond"]["closeness"] = minf(100.0, float(l["bond"]["closeness"]) + amount)


func _bump(d: Dictionary, key: String, by := 1.0) -> void:
	d[key] = float(or_(d.get(key), 0)) + by


func _remember_like(l: Dictionary, food_name) -> void:
	var likes: Array = l["bond"]["knownLikes"]
	if not food_name in likes:
		l["bond"]["knownLikes"] = _last(likes + [food_name], 8)


func apply_event(saved, event_in: Dictionary, who: String, day: String, now: float, weather: Dictionary) -> Dictionary:
	var rolled := roll_life(saved, who, day, now)
	var diary = rolled["diary"]
	var event := event_in.duplicate()
	var type = event.get("type")
	if type == "arcade":
		var settled: bool = event.get("matchId") in nz(rolled["life"]["records"].get("arcadeMatches"), [])
		if not truthy(event.get("matchId")) or not event.get("result") in ["won", "lost", "draw"] or settled:
			return {"life": rolled["life"], "joy": 0, "notes": [], "memorable": [], "diary": diary}
	var l: Dictionary = rolled["life"].duplicate(true)
	var t: Dictionary = l["today"]
	var notes: Array = []
	var memorable: Array = []
	var joy := 0.0
	var feel := func(word: String, icon: String, cause: String): l["flash"] = {"word": word, "icon": icon, "cause": cause, "until": now + 40 * 60000.0}
	if truthy(event.get("thought")):
		var text := clip(str(event["thought"]).strip_edges(), 80)
		if text != "":
			l["thought"] = {"text": text, "at": now}
	l["interests"] = record_interest(l.get("interests"), event, now)
	var fun_now := clamp100(float(l["fun"]["value"]) - (now - float(l["fun"]["at"])) / HOUR * 3.0)
	var fun_gain := 0.0
	var peer := str(or_(event.get("partner"), _peer(who)))
	match type:
		"use":
			if event.get("objectId")=="xj_beach" and event.get("memorable",false):
				var sea_text:String=str(event.get("label","在家旁海边待了一会"))+"："+str(event.get("felt",""))
				memorable.append(sea_text)
				l["stories"]=_last(nz(l.get("stories"),[])+[{"id":"seaside-"+str(roundi(now)),"at":now,"name":"家旁海边","text":sea_text,"ownerSharedAt":0}],24)
			var label_text := clip(event.get("label"), 14)
			var seen: bool = label_text in t["plays"]
			if event.get("space") == "park":
				fun_gain = 5.0 if seen else 14.0
				if label_text != "":
					t["plays"].append(label_text)
			else:
				fun_gain = 2.0 if seen else 6.0
			var o: Dictionary = event["outcome"] if event.get("outcome") is Dictionary else {}
			if event.get("use") == "fish" and truthy(o.get("sizeCm")):
				var size := float(o["sizeCm"])
				var fish: Dictionary = l["records"]["fish"]
				_bump(fish, "count")
				_bump(fish["species"], str(o.get("catch")))
				_bump(t, "fish")
				if size > float(t["bestCm"]):
					t["bestCm"] = size
					t["bestFish"] = "约%s厘米的%s" % [num(size), str(o.get("catch"))]
				if size > float(fish["bestCm"]):
					var had := float(fish["bestCm"]) > 0
					fish["bestCm"] = size
					fish["bestName"] = o.get("catch")
					if had:
						notes.append("破了自己的钓鱼纪录：约%s厘米的%s" % [num(size), str(o.get("catch"))])
						joy += 4
						memorable.append("钓鱼破了纪录，约%s厘米的%s" % [num(size), str(o.get("catch"))])
						feel.call("得意", "😎", "刚破了钓鱼纪录")
			if truthy(o.get("flew")):
				_bump(l["records"], "kite")
			if n(o.get("skips")) > float(l["records"]["skipBest"]):
				var had_skip := float(l["records"]["skipBest"]) > 0
				l["records"]["skipBest"] = n(o["skips"])
				if had_skip:
					notes.append("打水漂的新纪录：%s下" % num(o["skips"]))
					joy += 3
			for e in world_events(day, weather):
				var bonus = e.get("bonus")
				if bonus != null and bonus["use"] == event.get("use"):
					joy += float(bonus["joy"])
					notes.append(bonus["line"])
				if truthy(e.get("parkJoy")) and event.get("space") == "park" and not truthy(t.get("saw_" + e["id"])):
					t["saw_" + e["id"]] = true
					joy += float(e["parkJoy"])
					notes.append(e["line"])
			if event.get("use") == "water" or event.get("use") == "water_plant":
				if now - float(l["care"]["water"]) > 36 * HOUR:
					joy += 4
					notes.append("有点蔫的叶子慢慢精神起来了")
				l["care"]["water"] = now
			if event.get("use") == "feed_fish":
				if now - float(l["care"]["feed"]) > 24 * HOUR:
					joy += 4
					notes.append("小鱼一下子全游过来抢吃的，看来是饿坏了")
				l["care"]["feed"] = now
		"eat":
			var p: Dictionary = event["product"] if event.get("product") is Dictionary else {}
			var key := str(p.get("id", "undefined"))
			var first := not truthy(l["records"]["foods"].get(key))
			_bump(l["records"]["foods"], key)
			if truthy(p.get("name")):
				t["foods"].append(p["name"])
			fun_gain = 3
			event["firstTime"] = first
			if first and truthy(p.get("name")):
				notes.append("第一次尝" + str(p["name"]))
		"meet":
			var same_day: bool = l["bond"]["gainDay"] == day
			var gained := float(l["bond"]["todayGain"]) if same_day else 0.0
			var gain := maxf(1.0, 4.0 - gained)
			_add_closeness(l, gain)
			l["bond"]["todayGain"] = gained + gain
			l["bond"]["gainDay"] = day
			_bump(l["bond"], "talks")
			_bump(t, "talks")
			l["contactAt"] = now
			fun_gain = 8
			joy += 3
			for food_name in nz(event.get("foodsSaid"), []):
				_remember_like(l, food_name)
		"encounter":
			if l["bond"]["lastEncounterDay"] != day:
				l["bond"]["lastEncounterDay"] = day
				_bump(l["bond"], "encounters")
				_add_closeness(l, 1.0)
			l["contactAt"] = maxf(float(l["contactAt"]), now - 4 * HOUR)
		"gift_out":
			var gift_name: String = str(or_((event["product"] if event.get("product") is Dictionary else {}).get("name"), ""))
			var liked := truthy(event.get("liked"))
			_bump(l["bond"], "given")
			_add_closeness(l, 5.0 if liked else 3.0)
			t["gifts"].append(gift_name)
			l["contactAt"] = now
			joy += 5.0 if liked else 3.0
			if liked and gift_name != "":
				_remember_like(l, gift_name)
			notes.append("%s很喜欢这个%s，记住了" % [peer, gift_name] if liked else "把%s送给了%s" % [gift_name, peer])
			feel.call("开心", "🥰", "刚把%s送给了%s" % [gift_name, peer])
			memorable.append("把%s送给了%s，%s" % [gift_name, peer, "对方很喜欢" if liked else "对方收下了"])
		"gift_in":
			var got_name: String = str(or_((event["product"] if event.get("product") is Dictionary else {}).get("name"), ""))
			var liked := truthy(event.get("liked"))
			_bump(l["bond"], "got")
			_add_closeness(l, 5.0 if liked else 3.0)
			t["got"].append(got_name)
			l["contactAt"] = now
			joy += 8.0 if liked else 4.0
			fun_gain = 4
			notes.append("%s送了%s，放进了包里" % [peer, got_name])
			feel.call("心里暖暖的", "🎁", "%s送了%s" % [peer, got_name])
			memorable.append("%s送了我%s" % [peer, got_name])
		"arcade":
			var kind := str(event.get("kind"))
			var row: Dictionary = l["records"]["arcade"].get(kind, {"played": 0, "won": 0, "lost": 0, "draw": 0, "best": 0})
			_bump(row, "played")
			_bump(row, str(event["result"]))
			var score := n(event.get("score"))
			row["best"] = maxf(float(row["best"]), score if truthy(score) else 0.0)
			l["records"]["arcade"][kind] = row
			l["records"]["arcadeMatches"] = _last(nz(l["records"].get("arcadeMatches"), []) + [event["matchId"]], 30)
			fun_gain = 18.0 if float(row["played"]) <= 1 else 12.0
			var word := "赢了" if event["result"] == "won" else ("输了" if event["result"] == "lost" else "打平了")
			var partner: String = str(or_(event.get("partner"), ""))
			var text := ("和" + partner if partner != "" else "") + "玩" + str(event.get("name")) + word
			if not t.has("arcade") or t["arcade"] == null:
				t["arcade"] = []
			var venue := "在"+str(event.get("place","电玩城"))
			t["arcade"].append(text if venue=="在电玩城" else venue+text)
			if partner != "" and not partner in ["Naiwa", "电脑A", "路人甲"]:
				l["contactAt"] = now
				var same: bool = l["bond"]["gainDay"] == day
				var gained := float(l["bond"]["todayGain"]) if same else 0.0
				var gain := maxf(1.0, 3.0 - gained)
				_add_closeness(l, gain)
				l["bond"]["todayGain"] = gained + gain
				l["bond"]["gainDay"] = day
			var reason := "（" + str(event["reason"]) + "）" if truthy(event.get("reason")) else ""
			if event["result"] == "won":
				feel.call("赢了很得意", "😎", "刚" + text)
			if event["result"] == "lost":
				feel.call("有点难过", "😔", "刚" + text)
			memorable.append(venue+text+reason)
			l["stories"] = _last(nz(l.get("stories"), []) + [{"id": event["matchId"], "at": now, "name": event.get("name"), "result": event["result"], "text": venue + text + reason, "ownerSharedAt": 0}], 24)
			notes.append(text + ("：" + str(event["reason"]) if truthy(event.get("reason")) else ""))
		"story_attempt":
			var gate = l.get("storyGate")
			l["storyGate"] = {"day": day, "at": now, "count": float(or_(gate.get("count"), 0)) + 1.0 if gate is Dictionary and gate.get("day") == day else 1}
		"story_shared":
			var ids: Array = nz(event.get("ids"), [])
			var stories: Array = []
			for r in nz(l.get("stories"), []):
				if r["id"] in ids:
					var copy: Dictionary = r.duplicate()
					copy["ownerSharedAt"] = now
					stories.append(copy)
				else:
					stories.append(r)
			l["stories"] = stories
		"preference":
			var r = l["interests"].get(event.get("targetId"))
			if r != null and event.get("choice") in ["seek", "avoid", "neutral"]:
				r["choice"] = event["choice"]
				r["urge"] = 0.0 if event["choice"] == "avoid" else (maxf(float(r["urge"]), 25.0) if event["choice"] == "seek" else r["urge"])
		"visit":
			var text := "%s来家里玩了" % str(event.get("partner")) if truthy(event.get("guest")) else "去了%s家" % str(event.get("partner"))
			if not t.has("visits") or t["visits"] == null:
				t["visits"] = []
			t["visits"].append(text)
			l["contactAt"] = now
			fun_gain = 10
			var same: bool = l["bond"]["gainDay"] == day
			var gained := float(l["bond"]["todayGain"]) if same else 0.0
			var gain := maxf(1.0, 3.0 - gained)
			_add_closeness(l, gain)
			l["bond"]["todayGain"] = gained + gain
			l["bond"]["gainDay"] = day
			memorable.append(text)
		"owner_chat":
			l["contactAt"] = maxf(float(l["contactAt"]), now - 10 * HOUR)
			fun_gain = 2
	l["fun"] = {"value": clamp100(fun_now + fun_gain), "at": now}
	for w in l["wishes"]:
		if truthy(w.get("done")) or not _wish_passes(w["id"], event):
			continue
		var def: Variant = _wish(w["id"])
		if def != null and def.get("distinct", false):
			var key = event.get("objectId") if truthy(event.get("objectId")) else event.get("use")
			if key in w["seen"]:
				continue
			w["seen"].append(key)
		_bump(w, "have")
		if float(w["have"]) >= float(w["need"]):
			w["done"] = true
			w["doneAt"] = now
			_bump(l["records"], "wishes")
			joy += 6
			notes.append("实现了今天的心愿：" + str(w["text"]))
			memorable.append("实现了今天的心愿：" + str(w["text"]))
			feel.call("满足", "😊", "刚实现了心愿：" + str(w["text"]))
	var all_done: bool = not l["wishes"].is_empty()
	for w in l["wishes"]:
		all_done = all_done and truthy(w.get("done"))
	if all_done and not truthy(t.get("perfect")):
		t["perfect"] = true
		_bump(l["records"], "perfectDays")
		joy += 6
		notes.append("今天的心愿全都实现了")
		memorable.append("今天的心愿全都实现了，很圆满的一天")
	for pair in ACHIEVEMENT_NAMES:
		var has_it := false
		for x in l["achievements"]:
			has_it = has_it or x["id"] == pair[0]
		if has_it or not _achieved(pair[0], l):
			continue
		l["achievements"] = l["achievements"] + [{"id": pair[0], "name": pair[1], "at": now}]
		joy += 3
		notes.append("达成了成就：" + pair[1])
		memorable.append("达成了小世界成就：" + pair[1])
	return {"life": l, "joy": joy, "notes": notes, "memorable": memorable, "diary": diary}


# ---- How she is right now -----------------------------------------------------------

func needs_of(life, now: float) -> Dictionary:
	var l := merged(life, now)
	return {"social": clamp100(100.0 - (now - float(l["contactAt"])) / HOUR * 3.5), "fun": clamp100(float(l["fun"]["value"]) - (now - float(l["fun"]["at"])) / HOUR * 3.0)}


func mood_of(who: String, feeling: Dictionary, life, weather: Dictionary, now: float, sleeping: bool) -> Dictionary:
	var need := needs_of(life, now)
	var joy := float(nz(feeling.get("joy"), 45))
	var energy := float(nz(feeling.get("energy"), 75))
	var calm := float(nz(feeling.get("calm"), 55))
	var last := clip(feeling.get("last"), 30)
	if sleeping:
		return {"key": "asleep", "word": "睡着了", "icon": "💤", "cause": "正在睡觉"}
	var flash = life.get("flash") if life is Dictionary else null
	if truthy(flash) and float(flash["until"]) > now:
		return {"key": "flash", "word": flash["word"], "icon": flash["icon"], "cause": flash["cause"]}
	if float(nz(feeling.get("satiety"), 70)) < 20:
		return {"key": "hungry", "word": "饿得慌", "icon": "😣", "cause": "肚子饿得咕咕叫"}
	if float(nz(feeling.get("hydration"), 70)) < 15:
		return {"key": "thirsty", "word": "渴得慌", "icon": "🥤", "cause": "嗓子干干的"}
	if energy < 25:
		return {"key": "tired", "word": "困倦", "icon": "🥱", "cause": "有点累了，想歇一歇"}
	if need["social"] < 25 and not _peer(who).is_empty():
		return {"key": "lonely", "word": "有点想念", "icon": "🥺", "cause": "好久没和%s说话了" % _peer(who)}
	if joy >= 78:
		return {"key": "happy", "word": "很开心", "icon": "😄", "cause": last if last != "" else "今天过得不错"}
	if need["fun"] < 25:
		return {"key": "bored", "word": "有点无聊", "icon": "😑", "cause": "这阵子都没什么新鲜事"}
	if joy < 32:
		return {"key": "down", "word": "提不起劲", "icon": "😔", "cause": last if last != "" else "说不上为什么"}
	if n(weather.get("rain")) > 0.5 and calm >= 50:
		return {"key": "rainy", "word": "安静听雨", "icon": "🌧️", "cause": "外面在下雨"}
	if calm >= 72:
		return {"key": "calm", "word": "平静", "icon": "🍃", "cause": "心里很安静"}
	if joy >= 58:
		return {"key": "good", "word": "心情不错", "icon": "🙂", "cause": last if last != "" else "没什么烦心事"}
	return {"key": "plain", "word": "平平常常", "icon": "😌", "cause": "没什么特别的"}


func thought_of(who: String, life, mood: Dictionary, events: Array, now: float) -> String:
	if life is Dictionary and truthy(life.get("thought")) and now - float(life["thought"]["at"]) < 3 * HOUR:
		return life["thought"]["text"]
	var peer := _peer(who)
	var open: Variant = null
	if life is Dictionary:
		for w in nz(life.get("wishes"), []):
			if not truthy(w.get("done")):
				open = w
				break
	var first_event: Variant = events[0] if not events.is_empty() else null
	var rows := {
		"lonely": ["不知道%s现在在做什么" % peer, "要不要去公园看看，说不定能碰见%s" % peer],
		"hungry": ["先去找点吃的吧", "包里还有吃的吗"], "thirsty": ["得喝点东西", "包里还有喝的吗"], "tired": ["等下找个地方歇一会儿", "眼皮有点沉"],
		"bored": ["得找点没玩过的事做", "要不去" + str(open["text"]) if open != null else "出去走走吧"],
		"down": ["今天好像有点不顺", "吃点喜欢的东西可能会好一点"], "rainy": ["雨声还挺好听的", "这种天适合待着不动"],
		"asleep": ["……"], "happy": ["今天真不错", "待会儿可以讲给%s听" % peer],
	}
	if peer.is_empty(): rows["happy"] = ["今天真不错", "出去走走，看看有什么新鲜事"]
	var idea: String = "今天还想" + str(open["text"]) if open != null else (first_event["text"] if first_event != null else "今天的心愿都实现了，接下来随便逛逛")
	var list: Array = rows.get(mood["key"], [idea, first_event["text"] + "，要不要去看看" if first_event != null else idea])
	return list[int(floor(seeded("%s|%d" % [who, int(floor(now / (2 * HOUR)))]) * list.size()))]


func care_notes(who: String, life, now: float) -> Array:
	var l := merged(life, now)
	var out: Array = []
	if now - float(l["care"]["water"]) > 36 * HOUR:
		out.append(Residents.flavor(who)["care"]["plant_note"])
	if Residents.flavor(who)["care"]["fish"] == true and now - float(l["care"]["feed"]) > 24 * HOUR:
		out.append("鱼缸里的小鱼游到水面讨吃的，该喂了")
	return out


func life_view(a: Dictionary) -> Dictionary:
	var who: String = a["who"]
	var day: String = a["day"]
	var now: float = float(a["now"])
	var weather: Dictionary = nz(a.get("weather"), {})
	var feeling: Dictionary = nz(a.get("feeling"), {})
	var l: Dictionary = roll_life(a.get("life"), who, day, now)["life"]
	var events := world_events(day, weather)
	var mood := mood_of(who, feeling, l, weather, now, truthy(a.get("sleeping")))
	var fish: Dictionary = l["records"]["fish"]
	var wishes: Array = []
	for w in l["wishes"]:
		wishes.append({"id": w["id"], "text": w["text"], "done": w["done"], "progress": "%s/%s" % [num(minf(float(w["have"]), float(w["need"]))), num(w["need"])] if float(w["need"]) > 1 else "", "carried": truthy(w.get("carried"))})
	var achievements: Array = []
	for x in l["achievements"]:
		achievements.append(x["name"])
	var diary: Array = _last(l["diary"], 14)
	diary.reverse()
	var today_arcade = (l["today"] if l["today"] is Dictionary else {}).get("arcade")
	return {
		"interests": interests_now(l.get("interests"), now), "stories": pending_stories(l, now), "today": day_words(day), "mood": mood, "thought": thought_of(who, l, mood, events, now), "needs": needs_of(l, now),
		"wishes": wishes, "events": events.map(func(e): return e["text"]), "care": care_notes(who, l, now),
		"bond": {"with": _peer(who), "word": bond_word(l["bond"]["closeness"]), "closeness": l["bond"]["closeness"], "talks": l["bond"]["talks"], "given": l["bond"]["given"], "got": l["bond"]["got"], "knownLikes": l["bond"]["knownLikes"]},
		"arcadeToday": nz(today_arcade, []),
		"records": {"arcade": nz(l["records"].get("arcade"), {}), "fishCount": fish["count"], "bestFish": "约%s厘米的%s" % [num(fish["bestCm"]), str(fish["bestName"])] if truthy(fish["bestCm"]) else "", "species": fish["species"].keys(), "kite": l["records"]["kite"], "skipBest": l["records"]["skipBest"], "foodsTried": l["records"]["foods"].size(), "wishes": l["records"]["wishes"], "days": l["records"]["days"]},
		"achievements": achievements, "yesterday": str(l["diary"][-1]["text"]) if not l["diary"].is_empty() else "", "diary": diary,
	}


func life_note(v: Dictionary) -> String:
	var open: Array = []
	var done: Array = []
	for w in v["wishes"]:
		if truthy(w["done"]):
			done.append(w["text"])
		else:
			open.append(str(w["text"]) + ("（%s）" % w["progress"] if truthy(w["progress"]) else ""))
	var out := agency_note(v) + "【今天的你】"
	if truthy(v.get("today")):
		out += str(v["today"]) + "。"
	out += "心情：%s（%s）。心里想着：%s。" % [v["mood"]["word"], v["mood"]["cause"], v["thought"]]
	if not open.is_empty():
		out += "今天还想：" + _join(open, "、") + "。"
	if not done.is_empty():
		out += "今天已经实现：" + _join(done, "、") + "。"
	if not nz(v.get("arcadeToday"), []).is_empty():
		out += ("今天的对局：" if v["arcadeToday"].any(func(a): return str(a).begins_with("在")) else "今天在电玩城：") + _join(_last(v["arcadeToday"], 3), "；") + "。"
	if not v["events"].is_empty():
		out += "今天这里：" + _join(v["events"], "；") + "。"
	if not v["care"].is_empty():
		out += _join(v["care"], "；") + "。"
	out += "你和%s：%s。" % [v["bond"]["with"], v["bond"]["word"]]
	if truthy(v.get("yesterday")):
		out += "昨天：" + str(v["yesterday"])
	return out + "这些都是真实发生的；按这个状态自然说话，不用报告数值，也不用每句都提。"


func life_chat_topics(v: Dictionary, random: Callable) -> Array:
	var out: Array = []
	for r in _last(nz(v.get("stories"), []), 2):
		out.append(story_when(r["at"]) + "：" + str(r["text"]) + "，可以自己选择聊聊")
	for w in v["wishes"]:
		if truthy(w["done"]):
			out.append("今天实现了一个心愿：" + str(w["text"]))
		elif float(random.call()) < 0.5:
			out.append("今天很想" + str(w["text"]) + "，可以说说或邀请对方一起")
	for e in v["events"]:
		out.append("今天的新鲜事：" + str(e))
	for a in _last(nz(v.get("arcadeToday"), []), 2):
		out.append("刚才" + (str(a) if str(a).begins_with("在") else "在电玩城"+str(a)) + "，可以聊聊这一局")
	if truthy(v["records"]["bestFish"]):
		out.append("自己的钓鱼纪录是" + str(v["records"]["bestFish"]) + "，可以比一比")
	if truthy(v.get("yesterday")):
		out.append("昨天的事：" + clip(v["yesterday"], 60))
	if v["mood"]["key"] in ["tired", "down", "bored", "happy", "rainy"]:
		out.append("现在的心情：" + str(v["mood"]["word"]) + "，" + str(v["mood"]["cause"]))
	return out


func next_want(who: String, life):
	if not life is Dictionary:
		return null
	for w in nz(life.get("wishes"), []):
		if truthy(w.get("done")):
			continue
		var def: Variant = _wish(w["id"])
		var mine: Dictionary = Residents.flavor(who)["wish_hints"]
		if def != null and mine.has(def["id"]):
			return mine[def["id"]]
		if def != null and def.has("hint"):
			return def["hint"]
	return null


func care_hint(who: String, life, now: float):
	var notes := care_notes(who, life, now)
	if notes.is_empty():
		return null
	for x in notes:
		if "鱼" in x:
			return {"objectId": "fish_tank", "use": "feed_fish"}
	return Residents.flavor(who)["care"]["plant_hint"]


func pick_gift(products: Array, known_likes: Array, random: Callable):
	var food: Array = products.filter(func(p): return p.get("kind") != "use")
	if food.is_empty():
		return null
	for p in food:
		if p["name"] in known_likes:
			return p
	return food[int(floor(float(random.call()) * food.size())) % food.size()]


func likes_gift(who: String, feeling, id: String) -> bool:
	return liking_of(who, feeling, id) >= 2


# ---- What happens at a park object -----------------------------------------------

var _fish: Array = []


func fish_luck_today(day: String) -> float:
	for e in world_events(day, {}):
		if e.has("fishLuck"):
			return float(e["fishLuck"])
	return 1.0


## Returns { lines, outcome }. r is a weather reading: rain, cloud, sun, temp, windLevel, phase.
func play_outcome(use: String, r: Dictionary, umbrella: bool, random: Callable, fish_luck: float, blanks: int) -> Dictionary:
	var rain := n(r.get("rain"))
	var wind := n(r.get("windLevel"))
	var wet := rain > 0
	var lines: Array = []
	var outcome = null
	match use:
		"ride":
			lines.append("坐在跷跷板的一端，木板轻轻起伏")
		"rock":
			lines.append("握住鲸鱼摇摇乐的把手，弹簧轻轻晃动")
		"swing":
			lines.append("荡到最高时风迎面灌过来，心里一下子空了一拍" if wind >= 2 else "荡到最高时肚子里轻飘飘的")
			if wet:
				lines.append("座板湿湿的，坐上去凉了一下")
		"slide":
			lines.append("滑面上有雨水，滑得比平时快好多，差点冲出去" if wet else ("滑面被晒得有点烫" if n(r.get("sun")) > 0.6 and n(r.get("temp")) > 22 else "嗖地一下就滑到底了"))
		"spin":
			lines.append("转起来周围的景色糊成一圈，停下来有点晕乎乎的")
		"fly_kite":
			if wind < 1:
				lines.append("几乎没有风，风筝跑了好几趟都没飞起来")
				outcome = {"flew": false}
			elif wet and not umbrella:
				lines.append("下着雨，风筝纸很快就湿了，只好收起来")
				outcome = {"flew": false}
			else:
				lines.append("风很大，风筝一下子冲上去，线勒得手心发紧" if wind >= 3 else "风筝慢慢升起来，在天上轻轻摇")
				outcome = {"flew": true, "height": "很高" if wind >= 3 else "不太高"}
		"fish":
			var phase = r.get("phase")
			var bonus := fish_luck * (1.3 if n(r.get("cloud")) > 0.5 else 1.0) * (1.4 if phase == "dawn" or phase == "dusk" else 1.0) * (0.7 if rain > 0.5 else 1.0)
			var rows: Array = []
			var total := 0.0
			for f in _fish:
				var w := float(f[1]) * bonus if f[2] != null else (0.0 if blanks >= 2 else float(f[1]) * pow(0.4, blanks))
				rows.append(w)
				total += w
			var left := float(random.call()) * total
			var chosen: Array = _fish[-1]
			for k in _fish.size():
				left -= rows[k]
				if left <= 0:
					chosen = _fish[k]
					break
			var size = null
			if chosen[2] != null:
				size = js_round(float(chosen[2][0]) + float(random.call()) * (float(chosen[2][1]) - float(chosen[2][0])))
			outcome = {"catch": chosen[0], "sizeCm": size, "released": truthy(size)}
			if truthy(size):
				lines.append("浮漂一沉，钓上来一条约%s厘米的%s，看了一会儿就放回河里了" % [num(size), str(chosen[0])])
			else:
				lines.append("等了好久，浮漂动了几下，提起来却是空钩" if chosen[0] == "空钩" else "提起来只挂着一团水草")
			if rain > 0:
				lines.append("雨点在水面上打出一圈圈小涟漪")
		"skip_stones":
			var skips := maxf(0.0, js_round(float(random.call()) * 6.0 - (1.0 if wind >= 3 else 0.0) + (1.0 if wind == 0 else 0.0)))
			outcome = {"skips": skips}
			lines.append("石片在水面上跳了%s下" % num(skips) if skips != 0 else "石片扑通一声直接沉下去了")
		"feed_ducks":
			lines.append("鸭子在雨里也游过来抢面包屑" if rain > 0.5 else "鸭子嘎嘎叫着游过来，抢着啄面包屑")
		"dip_feet":
			lines.append("河水冰得脚趾一缩" if n(r.get("temp")) <= 14 else "河水凉凉的，冲过脚背很舒服")
		"lie_grass":
			lines.append("草地是湿的，衣服背后湿了一片" if wet else "草叶扎在脖子上有点痒，能闻到泥土味")
		"watch_clouds":
			lines.append("天上几乎没有云，只能看着蓝天发呆" if n(r.get("cloud")) < 0.2 else "有一朵云像小鲸鱼")
		"shade":
			lines.append("树荫下一下子凉快了，叶缝里漏下来的光一闪一闪" if n(r.get("sun")) > 0.45 else "没什么太阳，树下有点暗，叶子沙沙响")
		"watch_butterfly":
			lines.append("下雨/天黑了，蝴蝶都躲起来了，一只也没看到" if rain > 0 or r.get("phase") == "night" else "一只白蝴蝶在花坛上绕来绕去")
	return {"lines": lines, "outcome": outcome}


# ---- Test support: runs a list of calls from a file and writes every result ------------

func _ready() -> void:
	var economy = JSON.parse_string(FileAccess.get_file_as_string("res://assets/economy.json"))
	_fish = economy.get("fish", [])
	var args := OS.get_cmdline_user_args()
	var i := args.find("--life-test")
	if i >= 0 and i + 2 < args.size():
		_run_test(args[i + 1], args[i + 2])


func _run_test(input: String, output: String) -> void:
	var calls: Array = JSON.parse_string(FileAccess.get_file_as_string(input))
	var results: Array = []
	for c in calls:
		clock_override = float(c.get("clock", -1))
		var queue: Array = c.get("random", []).duplicate()
		var random := func(): return queue.pop_front()
		results.append(_test_call(str(c["fn"]), c["a"], random))
	var f := FileAccess.open(output, FileAccess.WRITE)
	f.store_string(JSON.stringify(results, "", false, true))
	f.close()


func _test_call(fn: String, a: Dictionary, random: Callable):
	match fn:
		"experience":
			return experience(a)
		"arcade":
			return arcade_feeling(a)
		"now":
			return feeling_now(a.get("saved"), float(a["now"]))
		"event":
			return apply_event(a.get("life"), a["event"], a["who"], a["day"], float(a["now"]), nz(a.get("weather"), {}))
		"view":
			return life_view(a)
		"note":
			return life_note(life_view(a))
		"topics":
			return life_chat_topics(life_view(a), random)
		"mood":
			return mood_of(a["who"], a["feeling"], a.get("life"), nz(a.get("weather"), {}), float(a["now"]), truthy(a.get("sleeping")))
		"hunger":
			return hunger_plan(a["who"], a["feeling"], a["bag"], a["shop"], float(a["coins"]), nz(a.get("weather"), {}), float(a["now"]), random)
		"thirst":
			return thirst_plan(a["who"], a["feeling"], a["bag"], a["shop"], float(a["coins"]), nz(a.get("weather"), {}), float(a["now"]), random)
		"body":
			return body_note(a["feeling"], truthy(a.get("cold")))
		"stomach":
			return stomach_note(a["who"], a["feeling"], a["products"])
		"cheer":
			return cheer_ideas(a["feeling"], nz(a.get("weather"), {}), nz(a.get("uses"), {}), float(a["now"]))
		"cheerNeed":
			return cheer_need(a["feeling"], a["mood"])
		"want":
			return next_want(a["who"], a.get("life"))
		"careHint":
			return care_hint(a["who"], a.get("life"), float(a["now"]))
		"gift":
			return pick_gift(a["products"], a["likes"], random)
		"dayWords":
			return day_words(a["day"])
		"storyWhen":
			return story_when(a["at"], float(a["now"]))
		"play":
			return play_outcome(a["use"], a["r"], truthy(a.get("umbrella")), random, float(a["fishLuck"]), int(a["blanks"]))
	return {"unknown": fn}
