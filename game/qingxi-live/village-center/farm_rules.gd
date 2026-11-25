extends RefCounted
## 2026-11-20 Claude (qingxi-farm): 清溪村农活规则引擎。
##
## 业主的三条原则落在这里：
##   1. 所有阈值/规则都在 farm_rules.json（可见数据文件，不是代码），这个文件只读它。
##   2. 只算「真实存档里已经发生的事」：围栏边、食槽、水渠、田格、水槽/食槽的量。不猜、不假设、不预写。
##   3. 每个前提都回答「缺哪一条」和「下一步能做什么」，所以她永远有一条走得通的路。
##
## INTERFACE（core/qingxi_host.gd 与测试用；全部是纯函数，不建节点、不改存档）
##   rules()                          -> farm_rules.json 的内容（她和我都查得到，_farm_reading 会带出去）
##   context(sim, map_id)             -> 这块农场此刻的真实布局：田格、围栏边、食槽、水源格、水井、边界
##   enclosures(ctx)                  -> 由围栏边洪水填充出的闭合围合 [{cells, water, bank}]
##   plot_status(sim, ctx, i)         -> 第 i 块地：开没开垦、旁边有没有水、能不能种、缺什么
##   pen_status(sim, kind, ctx)       -> 某类牲畜：围栏圈住没、食槽在不在、槽里有料没、能喝到水没、缺什么
##   pen_any(sim, kind)               -> 两份存档（开荒农场 / 村中心牧场）里找到的第一个像样的圈
##   missing_text(list)               -> 把缺失清单说成人话（"缺：水源（…）、种子（…）"）
##   reading(sim, map_id)             -> 给 _farm_reading 的完整读数（田/圈/规则/动作/下一步）
##
## 判据（业主）：她做完之后隔一分钟再「看」，必须能在 reading 里看到自己做过的那件事。
## 所以这里的每一条都从 sim.data 现读，不做缓存。

const RULES_PATH := "res://qingxi-live/village-center/farm_rules.json"
const EMPTY_LAYOUT_ZONE := Vector2i(2880, 2016)

static var _rules_cache:Dictionary = {}
static var _json_cache:Dictionary = {}

static func rules() -> Dictionary:
	if _rules_cache.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		_rules_cache = d if d is Dictionary else {}
	return _rules_cache

## 2026-11-21 batch10：物品/器具的中文名同样来自 farm_rules.json（livestock.feeder_name / feed_name、
## plot.seed_name），代码里不写任何中文。查不到返回 ""，由调用方自己回退（查不到就原样给 key）。
## 前缀匹配用 json 里的 livestock.feeder_bag_prefix，不假设是 "feeder_"。
static func goods_label(key:String) -> String:
	var r := rules()
	var stock: Dictionary = r.get("livestock", {})
	var prefix := str(stock.get("feeder_bag_prefix", "feeder_"))
	if prefix != "" and key.begins_with(prefix):
		var feeder: Dictionary = stock.get("feeder_name", {})
		var kind := key.substr(prefix.length())
		if feeder.has(kind): return str(feeder[kind])
	if key.begins_with("feed_"):
		var feed: Dictionary = stock.get("feed_name", {})
		var kind := key.substr(5)
		if feed.has(kind): return str(feed[kind])
	return str(r.get("item_names", {}).get(key, ""))

static func _json(path:String) -> Dictionary:
	if not _json_cache.has(path):
		var d = JSON.parse_string(FileAccess.get_file_as_string(path))
		_json_cache[path] = d if d is Dictionary else {}
	return _json_cache[path]

static func cell_size() -> int:
	return int(rules().get("cell", 64))

static func water_rules() -> Dictionary:
	return rules().get("water", {})

static func livestock_rules() -> Dictionary:
	return rules().get("livestock", {})

static func plot_rules() -> Dictionary:
	return rules().get("plot", {})

static func action_rows() -> Array:
	return rules().get("actions", [])

static func kind_cn(kind:String) -> String:
	return str(livestock_rules().get("kinds", {}).get(kind, kind))

static func feeder_cn(kind:String) -> String:
	return "牧场食槽"

# ---------------- 每只动物自己的饱食度 / 饥渴度 ----------------
## 这两个值本来就存在（a.food / a.drink，0-100），会随时间衰减、低到临界掉血、低到 20 不长不产。
## 这里只做三件事：读出来、翻成人话、告诉她下一步喂/给水。不另存一份，不做平行模型。
static func needs_rules() -> Dictionary:
	return rules().get("needs", {})

static func needs_name(key:String) -> String:
	return str(needs_rules().get("names", {}).get(key, key))

## 文案模板：数字由代码从本文件的阈值算出来填进去，所以文案和数值永远一致。
static func phrases() -> Dictionary:
	return rules().get("phrases", {})

static func phrase(key:String, vars:Dictionary = {}) -> String:
	var t := str(phrases().get(key, ""))
	for k in vars:
		t = t.replace("{%s}" % str(k), str(vars[k]))
	return t

static func animal_needs(a:Dictionary) -> Dictionary:
	var n := needs_rules()
	var satiety := float(a.get(str(n.get("satiety_field", "food")), 100.0))
	var thirst := float(a.get(str(n.get("thirst_field", "drink")), 100.0))
	var hungry := satiety <= float(n.get("hungry_below", 48.0))
	var thirsty := thirst <= float(n.get("thirsty_below", 48.0))
	var critical := satiety <= float(n.get("critical_below", 10.0)) or thirst <= float(n.get("critical_below", 10.0))
	var cons:Dictionary = n.get("consequence", {})
	var stop_below := float(cons.get("stop_growing_and_producing_below", 20.0))
	var slow := minf(satiety, thirst) < stop_below
	## 真实后果一句话（数字从 consequence 里算，模板从 phrases 里取；不编）。
	var hp_map:Dictionary = cons.get("hp_loss_per_day_at_critical", {})
	var consequence := ""
	if critical:
		consequence = phrase("critical")
	elif thirsty:
		consequence = phrase("thirsty", {"hp_per_day": snappedf(float(hp_map.get("thirst", 0.0)), 0.1), "hp_per_hour": snappedf(float(hp_map.get("thirst", 0.0)) / 24.0, 0.1)})
	elif hungry:
		consequence = phrase("hungry", {"hp_per_day": snappedf(float(hp_map.get("hunger", 0.0)), 0.1), "hp_per_hour": snappedf(float(hp_map.get("hunger", 0.0)) / 24.0, 0.1)})
	return {
		"satiety": snappedf(satiety, 0.1), "thirst": snappedf(thirst, 0.1),
		"hungry": hungry, "thirsty": thirsty, "critical": critical, "stop_producing": slow,
		"consequence": consequence,
		"satiety_field": str(n.get("satiety_field", "food")), "thirst_field": str(n.get("thirst_field", "drink")),
		"full_at": float(n.get("already_full_at", 90.0)), "raise_to": float(n.get("feed_raise_to", 90.0))
	}

## 一句话状态：饿/渴/危急 + 真切后果（不是数字不好看，是会长不动、不产、掉血、死）。
static func animal_status(a:Dictionary) -> String:
	var nd := animal_needs(a)
	var bits := []
	if bool(nd.hungry): bits.append("%s %.0f" % [needs_name("hungry"), float(nd.satiety)])
	if bool(nd.thirsty): bits.append("%s %.0f" % [needs_name("thirsty"), float(nd.thirst)])
	if bool(nd.critical): bits.append("⚠ 危急（会掉血，掉光会死）")
	elif bool(nd.stop_producing): bits.append("已停止成长和产出")
	return " · ".join(bits)

## 每只动物一条读数（她 look/survey 时看这个）。
static func animals_view(sim) -> Array:
	var out := []
	var Book = load("res://qingxi-live/village-center/breed_catalog.gd")
	for a in sim.livestock.data.get("herd", []):
		var kind := str(a.get("kind", ""))
		var nd := animal_needs(a)
		var line := {
			"id": str(a.get("id", "")), "kind": kind, "kindName": kind_cn(kind),
			"name": Book.breed_name(a), "adult": sim.livestock.adult(a),
			"satiety": nd.satiety, "thirst": nd.thirst,
			"hungry": nd.hungry, "thirsty": nd.thirsty, "critical": nd.critical,
			"stop_producing": nd.stop_producing,
			"hp": snappedf(float(a.get("hp", 0)), 0.1), "hpMax": float(Book.MAX_HP.get(kind, 100)),
			"ready": int(a.get("ready", 0)),
			"status": animal_status(a),
			"consequence": str(nd.consequence),
			"next": _animal_next(kind, str(a.get("id", "")), nd)
		}
		if bool(nd.thirsty) or bool(nd.hungry): line["needs_care"] = true
		out.append(line)
	return out

static func _animal_next(kind:String, id:String, nd:Dictionary) -> String:
	var cn := kind_cn(kind)
	if bool(nd.critical):
		if bool(nd.hungry) and bool(nd.thirsty): return "%s#%s 又快渴又饿：feed %s 和 give_water %s 都要做" % [cn, id, cn, cn]
		if bool(nd.hungry): return "%s#%s 危急：马上 feed %s" % [cn, id, cn]
		return "%s#%s 危急：马上 give_water %s" % [cn, id, cn]
	if bool(nd.hungry) and bool(nd.thirsty): return "%s#%s 又饿又渴：feed %s 和 give_water %s" % [cn, id, cn, cn]
	if bool(nd.hungry): return "%s#%s 饿了：feed %s" % [cn, id, cn]
	if bool(nd.thirsty): return "%s#%s 渴了：give_water %s" % [cn, id, cn]
	return ""


static func coord(key) -> Vector2i:
	var p := str(key).split(":")
	return Vector2i(int(p[0]), int(p[1]))

static func cell_key(c:Vector2i) -> String:
	return "%d:%d" % [c.x, c.y]

# ---------------- 农场上下文 ----------------
## map_id: "meadow"（开荒农场，业主真正在玩的那张）或 "ranch"（村中心牧场）。
static func context(sim, map_id:String = "meadow", seed_default:bool = true) -> Dictionary:
	var m:Dictionary = rules().get("maps", {}).get(map_id, {})
	var L:Dictionary = sim.data.get("layout", {})
	var pen:Dictionary = L.get(str(m.get("pen_key", "")), {})
	if seed_default and map_id == "ranch" and pen.is_empty():
		# 镜像 region.ranch()：第一次进牧场时用烘焙的 default_ranch 播种。
		# 这就是业主说的「一开始就已经有一个大围栏」——必须直接算数。
		var d:Dictionary = _json(str(m.get("layout", ""))).get("default_ranch", {})
		if not d.is_empty():
			pen = {"edges": _default_edges(sim, d), "feeders": d.get("feeders", [])}
	var ctx := {
		"map": map_id, "title": str(m.get("title", map_id)), "cell": cell_size(),
		"plots": L.get("plots", []), "edges": pen.get("edges", {}), "feeders": pen.get("feeders", []),
		"water": {}, "wells": [], "zone": _zone(L, str(m.get("layout", "")))
	}
	# 水渠 / 鱼塘格：开荒农场存在 meadow_ground.cells 里（"channel"）
	var ground:Dictionary = L.get(str(m.get("ground_key", "")), {})
	var tiles:Array = water_rules().get("channel_tiles", ["channel"])
	for k in ground.get("cells", {}):
		if str(ground.cells[k]) in tiles:
			ctx.water[coord(k)] = str(ground.cells[k])
	# 挖出来的塘（村中心牧场用 dug_ponds）
	for pool in L.get("dug_ponds", {}).get("ranch" if map_id=="meadow" else map_id, []):
		if not (pool is Dictionary): continue
		var r := Rect2(float(pool.get("x", 0)), float(pool.get("y", 0)), float(pool.get("w", 0)), float(pool.get("h", 0)))
		var c0 := Vector2i((r.position / cell_size()).floor())
		var c1 := Vector2i((r.end / cell_size()).ceil())
		for y in range(c0.y, c1.y):
			for x in range(c0.x, c1.x):
				ctx.water[Vector2i(x, y)] = "pond"
	# 水井 / 手压水泵：可移动道具，位置在 props_<map>
	for row in L.get(str(m.get("props_key", "props_ranch")), []):
		if not (row is Array) or row.size() < 3: continue
		if str(row[0]) in water_rules().get("prop_names", ["well"]):
			ctx.wells.append({"kind": str(row[0]), "pos": Vector2(float(row[1]), float(row[2])) + Vector2(0, 24)})
	return ctx

## default_ranch.paddock = [c, r, w, h]：把外圈边都围成 fence、留一个 gate，跟 region.ranch() 一致。
static func _default_edges(sim, d:Dictionary) -> Dictionary:
	var edges := {}
	var r:Array = d.get("paddock", [])
	if r.size() < 4: return edges
	var c0 := int(r[0]); var y0 := int(r[1]); var w := int(r[2]); var h := int(r[3])
	var passage := Vector2i(-1, -1)
	var L:Dictionary = sim.data.get("layout", {})
	for row in [L.get("meadow_barn", {})]:
		pass
	for c in range(c0, c0 + w):
		edges["h:%d:%d" % [c, y0]] = "fence"
		edges["h:%d:%d" % [c, y0 + h]] = "fence"
	for row in range(y0, y0 + h):
		edges["v:%d:%d" % [c0, row]] = "fence"
		edges["v:%d:%d" % [c0 + w, row]] = "fence"
	edges["h:%d:%d" % [c0 + 3, y0 + h]] = "gate"
	if passage.x >= 0: edges.erase("h:%d:%d" % [passage.x, y0])
	return edges

static func _zone(L:Dictionary, layout_path:String) -> Rect2i:
	var c := cell_size()
	var z = L.get("zone", null)
	if z == null:
		var baked:Dictionary = _json(layout_path)
		z = baked.get("zone", null)
		if z == null and baked.get("pasture_zones", null) is Array and baked.pasture_zones.size() > 0:
			z = baked.pasture_zones[0]
	if z == null or not (z is Array) or z.size() < 4:
		return Rect2i(0, 0, int(ceil(EMPTY_LAYOUT_ZONE.x / float(c))), int(ceil(EMPTY_LAYOUT_ZONE.y / float(c))))
	return Rect2i(int(floor(float(z[0]) / c)), int(floor(float(z[1]) / c)), int(ceil(float(z[2]) / c)), int(ceil(float(z[3]) / c)))

# ---------------- 水源 ----------------
## 到最近水源的距离（像素）。水源 = 水渠/鱼塘格 + 水井/水泵。
static func nearest_water(ctx:Dictionary, p:Vector2) -> Dictionary:
	var cell := float(ctx.get("cell", 64))
	var best := {"found": false, "dist": INF, "kind": "", "pos": Vector2.ZERO}
	for c in ctx.get("water", {}):
		var center := Vector2(c) * cell + Vector2(cell, cell) * 0.5
		var dist := p.distance_to(center)
		if dist < best.dist: best = {"found": true, "dist": dist, "kind": str(ctx.water[c]), "pos": center}
	for w in ctx.get("wells", []):
		var dist := p.distance_to(w.pos)
		if dist < best.dist: best = {"found": true, "dist": dist, "kind": str(w.kind), "pos": w.pos}
	return best

static func water_source_cn(kind:String) -> String:
	return str(water_rules().get("source_names", {}).get(kind, kind))

## 这块地旁边够不够水（业主：田地旁边必须有水源，像我的世界）。
static func plot_water(ctx:Dictionary, index:int) -> Dictionary:
	var plots:Array = ctx.get("plots", [])
	if index < 0 or index >= plots.size():
		return {"ok": false, "why": "这块地还没开垦", "dist": INF, "source": ""}
	var cell := float(ctx.get("cell", 64))
	var row = plots[index]
	var p := Vector2(float(row[0]), float(row[1])) + Vector2(cell, cell) * 0.5
	var near := nearest_water(ctx, p)
	var reach := float(water_rules().get("plot_reach_cells", 3)) * cell
	var ok:bool = bool(near.found) and float(near.dist) <= reach
	return {"ok": ok, "dist": float(near.dist), "source": water_source_cn(str(near.kind)) if near.found else "", "reach": reach}

# ---------------- 围栏 / 围合 ----------------
## 洪水填充：围栏边和门都挡住牲畜（跟 region.compute_enclosures 的判据一样），
## 走到地图边界之外的区域算敞地、不算围合。
static func enclosures(ctx:Dictionary) -> Array:
	var edges:Dictionary = ctx.get("edges", {})
	var z:Rect2i = ctx.get("zone", Rect2i())
	var out := []
	var seen := {}
	for y in range(z.position.y, z.end.y):
		for x in range(z.position.x, z.end.x):
			var start := Vector2i(x, y)
			if seen.has(start): continue
			var cells := {start: true}
			var queue := [start]
			var head := 0
			var open := false
			var water := false
			var gate := ""
			seen[start] = true
			while head < queue.size():
				var c:Vector2i = queue[head]
				head += 1
				if ctx.water.has(c): water = true
				for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					var n:Vector2i = c + d
					var edge:=_edge_between(c,n)
					if edges.has(edge):
						if edges[edge]=="gate":gate=edge
						continue
					if not z.has_point(n) or n.x >= z.end.x or n.y >= z.end.y:
						open = true
						continue
					if not seen.has(n):
						seen[n] = true
						cells[n] = true
						queue.append(n)
			if not open: out.append({"cells": cells, "water": water,"gate":gate})
	return out

static func _edge_between(a:Vector2i, b:Vector2i) -> String:
	if a.x == b.x: return "h:%d:%d" % [a.x, maxi(a.y, b.y)]
	return "v:%d:%d" % [maxi(a.x, b.x), a.y]

## 某类牲畜在这张农场上的圈：食槽所在的那个闭合围合。
static func pen_status(sim, kind:String, ctx:Dictionary) -> Dictionary:
	var min_cells := int(livestock_rules().get("min_pen_cells", 4))
	var cell := float(ctx.get("cell", 64))
	var feeders:Array = ctx.get("feeders", [])
	var enclosures_list := enclosures(ctx)
	var home := -1
	for f in feeders:
		if not (f is Array) or f.size() < 3: continue
		var c := Vector2i(int(f[1]), int(f[2]))
		for i in enclosures_list.size():
			if enclosures_list[i].cells.has(c): home = i; break
		if home >= 0: break
	var has_feeder := home>=0
	if not has_feeder:
		for i in enclosures_list.size():
			if enclosures_list[i].cells.size()>=min_cells and (home<0 or enclosures_list[i].water):
				home=i
				if enclosures_list[i].gate!="" and enclosures_list[i].water:break
	var gate:String=enclosures_list[home].gate if home>=0 else ""
	var placed := not feeders.is_empty()
	var cells_n := 0
	var creek := false
	if home >= 0 and enclosures_list[home].cells.size() >= min_cells:
		placed = not feeders.is_empty()
		cells_n = enclosures_list[home].cells.size()
		creek = bool(enclosures_list[home].water)
	## 食槽/水槽的量在 sim.data.livestock.pens（rural_state 的存档结构），不是顶层 pens。
	var pens:Dictionary = {}
	if sim.data.get("pens", null) is Dictionary: pens = sim.data.pens
	elif sim.get("livestock") != null: pens = sim.livestock.data.get("pens", {})
	var pen:Dictionary = pens.get(kind, {})
	var unit := float(livestock_rules().get("feed_unit_seconds", 86400))
	var feed := float(pen.get("feed", 0.0)) + (float(pen.get("grass", 0.0)) if kind == "sheep" else 0.0)
	var water := float(pen.get("water", 0.0))
	var feed_ok := feed >= unit * float(livestock_rules().get("min_feed_units", 1))
	# 能真正喝到的水：圈里有水渠/鱼塘，或者水槽里有水（游戏里 livestock.available 就是这么算的）
	var water_ok := creek or water > 0.0
	var missing := []
	if not water_ok and not sim.livestock.members(kind).is_empty() and ctx.water.is_empty(): missing.append({"code":"water","text":"到牧场 give_water 给牲畜补水，也可在可达的岸边散养"})
	if has_feeder and gate=="":missing.append({"code":"gate","text":"用 qx_pasture 的 gate，item 写圈内一格，安装木门"})
	if not placed:missing.append({"code":"feeder","text":"缺%s，去村中心牧铃畜牧铺 qx_livestock_counter，use=buy item=%s；回来用 place_feeder 摆到空草地上"%[feeder_cn(kind),feeder_cn(kind)]})
	if not feed_ok: missing.append({"code": "feed_in_trough", "text": "食物（%s是空的）：去青芽种子店 qx_seed_counter 买饲料，world_use use=buy item=饲料名" % feeder_cn(kind)})
	return {
		"kind": kind, "map": ctx.get("map", ""), "gate":gate,"fenced": cells_n>=min_cells, "cells": cells_n,
		"feeder": feeder_cn(kind) if placed else "", "feeder_placed": placed,
		"feed_hours": snappedf(feed / 3600.0, 0.1), "feed_ok": feed_ok,
		"water_hours": snappedf(water / 3600.0, 0.1), "water_from": ("水渠/鱼塘" if creek else ("水槽" if water > 0.0 else "")),
		"water_ok": water_ok, "missing": missing
	}

## 两份存档都看一遍：开荒农场 or 村中心牧场，哪个有像样的圈就用哪个（业主：已有大围栏就直接算数）。
static func pen_any(sim, kind:String, map_id:String = "meadow") -> Dictionary:
	var here := pen_status(sim, kind, context(sim, map_id, true))
	if here.fenced: return here
	## 另一张图只看存档里真的有的围栏，不凭空播种 default_ranch：那张图可能一次都没打开过。
	var other_id := "ranch" if map_id != "ranch" else "meadow"
	var other := pen_status(sim, kind, context(sim, other_id, false))
	if other.fenced: return other
	# 都没圈：返回缺得最少的那个（通常是开荒农场），并保留两张图的真实状态
	here["other"] = {"map": other_id, "fenced": other.fenced, "cells": other.cells}
	return here

static func missing_text(list:Array) -> String:
	if list.is_empty(): return ""
	var names := []
	for m in list:
		if m is Dictionary: names.append(str(m.get("text", "")))
	return "缺：" + "、".join(names)

# ---------------- 枯萎（2026-11-21，业主："不种田菜就会枯萎"） ----------------
## 成熟后 ripe_seconds 只增不减，按数据文件里的档位一档档枯。
## 代码里没有阈值：start/full/四档/产出比例全读 farm_rules.json 的 wither 段。
static func wither_rules() -> Dictionary:
	return rules().get("wither", {})

static func wither_tiers() -> Array:
	return wither_rules().get("tiers", [])

static func wither_start_seconds() -> float:
	return float(wither_rules().get("start_after_ripe_seconds", 86400.0))

static func wither_full_seconds() -> float:
	return float(wither_rules().get("full_after_ripe_seconds", 172800.0))

## ripe_seconds -> 档位视图 {id,name,look,yield_pct,hours,until_hours,next_at_hours,urgent,dead}
static func wither_tier(ripe_seconds:float) -> Dictionary:
	var tiers := wither_tiers()
	if tiers.is_empty():
		## 数据文件没装：不制造后果（宁可不枯，也不编一条阈值）。
		return {"id": "fresh", "name": "刚好成熟", "look": "熟了", "yield_pct": 100, "hours": snappedf(ripe_seconds / 3600.0, 0.1), "urgent": false, "dead": false}
	var picked:Dictionary = tiers[0]
	for t in tiers:
		var until = t.get("until", null)
		if until == null or ripe_seconds < float(until):
			picked = t
			break
		picked = t
	var until2 = picked.get("until", null)
	return {
		"id": str(picked.get("id", "")), "name": str(picked.get("name", "")), "look": str(picked.get("look", "")),
		"yield_pct": int(picked.get("yield_pct", 100)), "hours": snappedf(ripe_seconds / 3600.0, 0.1),
		"until_hours": (snappedf(float(until2) / 3600.0, 0.1) if until2 != null else -1.0),
		"next_at_hours": _next_tier_hours(ripe_seconds),
		"urgent": str(picked.get("id", "")) in ["warn", "wilting"],
		"dead": str(picked.get("id", "")) == "withered",
		"consequence": _wither_consequence(str(picked.get("id", "")), ripe_seconds)
	}

## 下一档在成熟后第几小时开始（-1 = 已经是最后一档）。
static func _wither_consequence(tier_id:String, ripe_seconds:float) -> String:
	var left := maxf(0.0, (wither_full_seconds() - ripe_seconds) / 3600.0)
	match tier_id:
		"fresh": return ""
		"warn": return phrase("wither_warn", {"hours_to_wither": snappedf(left, 1.0)})
		"wilting": return phrase("wither_soon", {"hours_to_full": snappedf(left, 1.0)})
		"withered": return phrase("withered")
	return ""

static func _next_tier_hours(ripe_seconds:float) -> float:
	var tiers := wither_tiers()
	for t in tiers:
		var until = t.get("until", null)
		if until == null: continue
		if ripe_seconds < float(until): return snappedf(float(until) / 3600.0, 0.1)
	return -1.0

static func crop_ripe_seconds(sim, index:int) -> float:
	var crops:Array = sim.data.get("crops", [])
	if index < 0 or index >= crops.size(): return 0.0
	return float(crops[index].get("ripe_seconds", 0.0))

static func crop_seconds(sim) -> float:
	## 生长秒数是游戏常量（qingxi-live/rural_state.gd 的 CROP_SECONDS），这里现读它的副本，不另写一份。
	var v = sim.get("CROP_SECONDS")
	if v != null: return float(v)
	return float(plot_rules().get("crop_seconds_fallback", 1200.0))

static func crop_state(sim, index:int) -> String:
	var crops:Array = sim.data.get("crops", [])
	if index < 0 or index >= crops.size(): return "未开垦"
	var c:Dictionary = crops[index]
	if not bool(c.get("planted", false)): return "空"
	if float(c.get("progress", 0.0)) >= crop_seconds(sim): return "熟了"
	if float(c.get("water", 0.0)) > 0.0: return "长着"
	return "缺水"

static func plot_status(sim, ctx:Dictionary, index:int) -> Dictionary:
	var plots:Array = ctx.get("plots", [])
	var crops:Array = sim.data.get("crops", [])
	var state := crop_state(sim, index)
	var tilled := index >= 0 and index < plots.size()
	var water := plot_water(ctx, index)
	var seed_item := str(plot_rules().get("seed_item", "seed"))
	var seeds:int=sim.Garden.seed_count(sim.data.bag)
	var planted := state != "空" and state != "未开垦"
	var can_plant: bool = bool(tilled) and seeds > 0 and not bool(planted)
	var missing := []
	if not tilled: missing.append({"code": "tilled", "text": "开垦（第 %d 块地还没开垦）" % (index + 1)})
	if tilled and not planted and seeds <= 0:
		missing.append({"code": "seed", "text": "种子（背包里没有%s）" % str(plot_rules().get("seed_name", "白菜种子"))})
	if tilled and planted: missing.append({"code": "planted", "text": "这块地已经种着东西了"})
	## 枯萎档位只对"成熟"的地有意义。
	var wither := {"id": "", "name": "", "look": "", "yield_pct": 100, "hours": 0.0, "urgent": false, "dead": false}
	var state_text := state
	if state == "熟了":
		wither = wither_tier(crop_ripe_seconds(sim, index))
		state_text = str(wither.look)
		if bool(wither.urgent):
			missing.append({"code": "wither", "text": "快收（第 %d 块%s，成熟后已 %.0f 小时）" % [index + 1, str(wither.look), float(wither.hours)]})
		elif bool(wither.dead):
			missing.append({"code": "withered", "text": "枯了（第 %d 块已经枯了，harvest 铲掉可以重种）" % [index + 1]})
	return {"index": index, "state": state, "stateText": (str(sim.ITEM_NAMES[sim.Garden.book().produce.get(crops[index].get("seed_key","seed"),"veg")])+" · "+state_text) if planted and tilled and index<crops.size() else state_text, "tilled": tilled, "planted": planted, "can_plant": can_plant,
		"water": water.ok, "water_from": water.source, "seeds": seeds, "missing": missing,
		"wither": wither, "can_clear": bool(wither.dead)}

## 她现在有几块地、几块空的、几块能立刻种、几块快枯/已枯。
static func plot_summary(sim, ctx:Dictionary) -> Dictionary:
	var plots:Array = ctx.get("plots", [])
	var out := {"total": plots.size(), "empty": 0, "planted": 0, "ripe": 0, "dry": 0, "can_plant": 0, "watered": 0,
		"withering": 0, "withered": 0, "rows": []}
	for i in plots.size():
		var row := plot_status(sim, ctx, i)
		out.rows.append(row)
		match str(row.state):
			"空": out.empty += 1
			"熟了": out.ripe += 1; out.planted += 1
			"长着": out.planted += 1; out.watered += 1
			"缺水": out.planted += 1; out.dry += 1
		if row.can_plant: out.can_plant += 1
		if bool(row.can_clear): out.withered += 1
		elif bool(row.wither.urgent): out.withering += 1
	return out

# ---------------- 围栏诊断 / 范围内障碍 / 教程（业主 2026-11-21：④ 先定范围 ⑤ 围小怎么扩 ⑥ 拆建筑） ----------------
## 从该类食槽所在格洪水填充：这个圈闭合吗？哪里漏了？（"一大圈+中间一道墙"会在这里报 leaks>0）
static func pen_diagnosis(sim, kind:String, ctx:Dictionary) -> Dictionary:
	var z:Rect2i = ctx.get("zone", Rect2i())
	var edges:Dictionary = ctx.get("edges", {})
	var cell := Vector2i(-1, -1)
	for f in ctx.get("feeders", []):
		if f is Array and f.size() >= 3 : cell = Vector2i(int(f[1]), int(f[2])); break
	var min_cells := int(livestock_rules().get("min_pen_cells", 4))
	if cell.x < 0:
		return {"ok": false, "has_feeder": false, "closed": false, "cells": 0, "leaks": [], "leak_count": 0,
			"why": "圈里还没有%s的食槽：去村中心的牧铃畜牧铺（qx_livestock_counter）用 world_use 的 use=buy、item=%s 买一个，回来 place_feeder 摆上，再 survey 这个圈" % [feeder_cn(kind), feeder_cn(kind)]}
	var seen := {cell: true}
	var queue := [cell]
	var head := 0
	var leaks := []
	while head < queue.size():
		var c:Vector2i = queue[head]
		head += 1
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n:Vector2i = c + d
			if edges.has(_edge_between(c, n)): continue
			if not (n.x >= z.position.x and n.x < z.end.x and n.y >= z.position.y and n.y < z.end.y):
				if not leaks.has(c) and leaks.size() < 12: leaks.append(c)
				continue
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	var closed: bool = leaks.is_empty()
	var cells: int = seen.size()
	var has_gate:=false
	for c in seen:
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			if edges.get(_edge_between(c,c+d),"")=="gate" and not seen.has(c+d):has_gate=true;break
		if has_gate:break
	var ok: bool = closed and cells >= min_cells and has_gate
	var why := ""
	if not ok:
		if closed and not has_gate:
			why="缺可通行的木门：gate，item 写圈内一格。"
		elif not closed:
			why = "围栏没围成闭合的圈：从%s的食槽往外走，有 %d 处能直接走到围栏外面（缺口在 %s 一带）。只在中间拉一道墙不算圈。" % [kind_cn(kind), leaks.size(), _cells_text(leaks)]
		else:
			why = "圈太小：只有 %d 格，数据文件要求至少 %d 格（一开始就围够，别围最小圈再反复扩）。" % [cells, min_cells]
	return {"ok": ok, "has_feeder": true, "closed": closed, "cells": cells, "min_cells": min_cells,
		"leaks": _cells_list(leaks), "leak_count": leaks.size(), "why": why}

static func _cells_list(cells:Array) -> Array:
	var out := []
	for c in cells: out.append("%d:%d" % [c.x, c.y])
	return out

static func _cells_text(cells:Array) -> String:
	var parts := _cells_list(cells)
	return "、".join(parts) if not parts.is_empty() else "?"

## 候选范围里"不能围/不能开垦"的东西清单（业主 ④：动手前先 survey 看清楚）。
## 只报存档里真有的（田格/食槽/水渠/道具/边界）；树和建筑这类只在场景里画的，如实标 scene_only_unknown，不假装知道。
static func area_report(sim, map_id:String, a:Vector2i, b:Vector2i) -> Dictionary:
	var ctx := context(sim, map_id)
	var L:Dictionary = sim.data.get("layout", {})
	var c0 := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var c1 := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	var z:Rect2i = ctx.get("zone", Rect2i())
	var issues := []
	var outside := []
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			var c := Vector2i(x, y)
			if not (c.x >= z.position.x and c.x < z.end.x and c.y >= z.position.y and c.y < z.end.y): outside.append(c)
	for row in ctx.get("plots", []):
		var pc := Vector2i(int(floor(float(row[0]) / cell_size())), int(floor(float(row[1]) / cell_size())))
		if pc.x >= c0.x and pc.x <= c1.x and pc.y >= c0.y and pc.y <= c1.y:
			issues.append({"code": "plot", "at": "%d:%d" % [pc.x, pc.y], "text": "田格 %d:%d（围进去会踩田，要让开）" % [pc.x, pc.y]})
	for f in ctx.get("feeders", []):
		var fc := Vector2i(int(f[1]), int(f[2]))
		if fc.x >= c0.x and fc.x <= c1.x and fc.y >= c0.y and fc.y <= c1.y:
			issues.append({"code": "feeder", "at": "%d:%d" % [fc.x, fc.y], "text": "已有食槽 %s 在 %d:%d" % [feeder_cn(str(f[0])), fc.x, fc.y]})
	for c in ctx.get("water", {}):
		if c.x >= c0.x and c.x <= c1.x and c.y >= c0.y and c.y <= c1.y:
			issues.append({"code": "water", "at": "%d:%d" % [c.x, c.y], "text": "水渠/鱼塘 %d:%d（要算进范围给它们喝）" % [c.x, c.y]})
	for row in L.get(str(rules().get("maps", {}).get(map_id, {}).get("props_key", "props_ranch")), []):
		if not (row is Array) or row.size() < 3: continue
		var pc2 := Vector2i(int(floor(float(row[1]) / cell_size())), int(floor(float(row[2]) / cell_size())))
		if pc2.x >= c0.x and pc2.x <= c1.x and pc2.y >= c0.y and pc2.y <= c1.y:
			issues.append({"code": "prop", "at": "%d:%d" % [pc2.x, pc2.y], "text": "道具 %s 在 %d:%d（别围进圈，也别拿它当围栏）" % [str(row[0]), pc2.x, pc2.y]})
	var cut := 0
	for key in ctx.get("edges", {}):
		var ep := str(key).split(":")
		var ec := Vector2i(int(ep[1]), int(ep[2]))
		if ec.x >= c0.x and ec.x <= c1.x + 1 and ec.y >= c0.y and ec.y <= c1.y + 1: cut += 1
	var cells_n := (c1.x - c0.x + 1) * (c1.y - c0.y + 1)
	var min_cells := int(livestock_rules().get("min_pen_cells", 4))
	return {"rect": "%d:%d..%d:%d" % [c0.x, c0.y, c1.x, c1.y], "cells": cells_n,
		"out_of_zone": _cells_list(outside.slice(0, 12)), "out_of_zone_count": outside.size(),
		"issues": issues, "issue_count": issues.size(), "existing_edges": cut,
		"min_pen_cells": min_cells, "big_enough": cells_n >= min_cells,
		"scene_only_unknown": "树/桥/建筑这类只在场景里画的没进存档，这一份查不到；这些要自己看一眼（教程 ④ 说清了）",
		"ok": outside.is_empty() and issues.is_empty() and cells_n >= min_cells}

## 教程文本：数字全部来自本文件的阈值（min_pen_cells / 水源半径 / 枯萎小时 / 掉血速率）。
static func tutorial_text(kind:String = "") -> String:
	var t:Dictionary = rules().get("tutorial", {})
	var cons:Dictionary = needs_rules().get("consequence", {})
	var vars := {
		"min_pen_cells": int(livestock_rules().get("min_pen_cells", 4)),
		"plot_reach_cells": int(water_rules().get("plot_reach_cells", 3)),
		"wither_warn_hours": int(wither_start_seconds() / 3600.0),
		"wither_half_hours": int((wither_start_seconds() + (wither_full_seconds() - wither_start_seconds()) * 0.5) / 3600.0),
		"wither_full_hours": int(wither_full_seconds() / 3600.0),
		"max_edges": int(rules().get("fence", {}).get("max_edges", 96)),
		"hungry_below": snappedf(float(needs_rules().get("hungry_below", 48.0)), 0.1),
		"hp_hunger": snappedf(float(cons.get("hp_loss_per_day_at_critical", {}).get("hunger", 0.0)), 0.1),
		"hp_thirst": snappedf(float(cons.get("hp_loss_per_day_at_critical", {}).get("thirst", 0.0)), 0.1)
	}
	var parts := ["fence", "keep", "farm", "expand", "demolish"]
	if kind in parts: parts = [kind]
	var out := []
	for part in parts:
		var line := str(t.get(part, ""))
		for k in vars: line = line.replace("{%s}" % k, str(vars[k]))
		if line != "": out.append(line)
	return "\n".join(out)

# ---------------- 给她看的整份读数 ----------------
static func reading(sim, map_id:String = "meadow") -> Dictionary:
	if rules().is_empty():
		## 数据文件没装就老实说：不退回一堆硬编码阈值假装正常。
		return {"map": map_id, "mapTitle": map_id, "zone": "",
			"plots": {"total": 0, "rows": [], "empty": 0, "planted": 0, "ripe": 0, "dry": 0, "can_plant": 0, "watered": 0},
			"pens": {}, "rules": {}, "actions": [],
			"next": ["农活规则文件 qingxi-live/village-center/farm_rules.json 没装好：先别做农活，把这件事告诉主人"]}
	var ctx := context(sim, map_id)
	var plots := plot_summary(sim, ctx)
	var pens := {}
	for kind in livestock_rules().get("kinds", {}):
		pens[kind] = _pen_view(pen_any(sim, kind, map_id))
	var next := next_steps(sim, ctx, plots, pens)
	var urgent := urgent_items(sim, plots, pens)
	return {
		"map": map_id, "mapTitle": str(ctx.get("title", map_id)),
		"plots": plots, "pens": pens,
		"animalsDetailed": animals_view(sim),
		"rules": _rules_view(), "actions": action_rows(),
		"next": next,
		"urgent": urgent,
		"todo": todo_line(urgent, plots, pens)
	}

## 会造成真实损失的事（掉血/枯掉）：有的话排在最前面，让她"扫一眼就看见"。
## 不是强制：她仍然可以去做别的，只是不该"看不见"。
static func urgent_items(sim, plots:Dictionary, pens:Dictionary) -> Array:
	var out := []
	var loss := str(phrases().get("loss_prefix", "【要紧】"))
	for row in animals_view(sim):
		if not (bool(row.get("critical", false)) or bool(row.get("hungry", false)) or bool(row.get("thirsty", false))): continue
		var tip := str(row.get("next", ""))
		var why := str(row.get("consequence", ""))
		out.append({"kind": "animal", "id": str(row.get("id", "")), "loss": bool(row.get("critical", false)),
			"text": loss + tip + ("" if why == "" else "——" + why)})
	for row in plots.get("rows", []):
		if bool(row.get("can_clear", false)):
			out.append({"kind": "plot", "id": str(int(row.get("index", 0)) + 1), "loss": true,
				"text": loss + "第 %d 块%s" % [int(row.get("index", 0)) + 1, phrase("withered")]})
		elif bool(row.get("wither", {}).get("urgent", false)):
			out.append({"kind": "plot", "id": str(int(row.get("index", 0)) + 1), "loss": true,
				"text": loss + "第 %d 块%s" % [int(row.get("index", 0)) + 1, str(row.get("wither", {}).get("consequence", ""))]})
	return out

## 一句人话待办：给她"扫一眼就知道有活"。没活就明说没活，不编。
static func todo_line(urgent:Array, plots:Dictionary, pens:Dictionary) -> String:
	var parts := []
	var loss := str(phrases().get("loss_prefix", "【要紧】"))
	for row in urgent:
		if bool(row.get("loss", false)): parts.append(String(str(row.get("text", ""))).trim_prefix(loss))
	var bits := []
	if int(plots.get("ripe", 0)) > 0: bits.append("%d 块熟了" % int(plots.get("ripe", 0)))
	if int(plots.get("withering", 0)) > 0: bits.append("%d 块快枯了" % int(plots.get("withering", 0)))
	if int(plots.get("withered", 0)) > 0: bits.append("%d 块已枯" % int(plots.get("withered", 0)))
	if int(plots.get("can_plant", 0)) > 0: bits.append("%d 块空着能种" % int(plots.get("can_plant", 0)))
	if parts.is_empty() and bits.is_empty(): return str(phrases().get("no_todo", "农场现在没什么急着做的"))
	var head := str(phrases().get("todo_prefix", "农场："))
	if not parts.is_empty(): return head + "、".join(parts)
	return head + "、".join(bits)

## 圈的读数只留看得懂的部分（去掉内部字段），并且一定带 missing。
static func _pen_view(p:Dictionary) -> Dictionary:
	return {"gate":p.get("gate",""),"fenced": bool(p.get("fenced", false)), "cells": int(p.get("cells", 0)),
		"feeder": str(p.get("feeder", "")), "feed_hours": float(p.get("feed_hours", 0.0)),
		"water_hours": float(p.get("water_hours", 0.0)), "water_from": str(p.get("water_from", "")),
		"missing": p.get("missing", []), "map": str(p.get("map", ""))}

static func _rules_view() -> Dictionary:
	return {"water": water_rules(), "plot": plot_rules(), "livestock": livestock_rules(),
		"fence": rules().get("fence", {}), "needs": needs_rules()}

## 下一步做什么：只按真实缺口给建议，绝不承诺"会自动……"。
static func next_steps(sim, ctx:Dictionary, plots:Dictionary, pens:Dictionary) -> Array:
	var out := []
	## 会造成真实损失的事（掉血/枯掉）排最前面：她仍然可以不去，但不该"看不见"。
	var urgent := urgent_items(sim, plots, pens)
	for row in urgent: out.append(str(row.get("text", "")))
	var seed_item := str(plot_rules().get("seed_item", "seed"))
	if int(plots.get("total", 0)) == 0:
		out.append("农场现在一块地都没有：先用 till 开垦一格（格子编号看 farm.zone）")
	elif int(plots.get("can_plant", 0)) == 0 and int(plots.get("empty", 0)) > 0 and sim.Garden.seed_count(sim.data.bag)==0:
		out.append("想种地的话，背包里没有%s：先去青芽种子店 buy" % str(plot_rules().get("seed_name", "白菜种子")))
	for kind in livestock_rules().get("kinds", {}):
		var p:Dictionary = pens.get(kind, {})
		if sim.livestock.members(kind).is_empty():continue
		var missing:Array = p.get("missing", [])
		if missing.is_empty(): continue
		for m in missing:
			match str(m.get("code", "")):
				"gate","feeder":out.append(str(m.text))
				"pen": out.append("%s还没有圈：先 fence 圈地、dig 确认水源、gate 装门，再摆%s（place_feeder）" % [kind_cn(kind), feeder_cn(kind)])
				"water": out.append("%s的圈里喝不到水：dig 挖一格水渠进圈里，或者 give_water 加水槽" % kind_cn(kind))
				"feed_in_trough": out.append("%s的%s是空的：feed 添一份%s" % [kind_cn(kind), feeder_cn(kind), str(livestock_rules().get("feed_name", {}).get(kind, "饲料"))])
	## 每只动物自己的饱食度/饥渴度：只在她真的能看到缺口时才提示（这是她自己去喂/给水的机会，不是系统替她补）。
	for line in animals_view(sim):
		var tip := str(line.get("next", ""))
		var dup := false
		for row in urgent:
			if str(row.get("kind", "")) == "animal" and str(row.get("id", "")) == str(line.get("id", "")): dup = true
		if tip != "" and not dup: out.append(tip)
	if out.is_empty(): out.append("田和圈都齐了，想种就 plant、想收就 harvest、想喂就 feed")
	return out
