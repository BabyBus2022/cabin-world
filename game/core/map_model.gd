extends RefCounted
const Grid=preload("res://core/world_grid.gd")
## Map editor logic (phase 3, docs/MAP-EDITOR-DESIGN.md): the rules of a new map, as pure functions on map data
## (format cabin-map/1, docs/MAP-FORMAT.md). Every edit returns a NEW map; nothing here draws, saves or touches the game.
## Ported from the trial editor the owner tried (prototypes/map-editor-trial/editor.js), same rules:
##  - the map is FORMED, not drawn: floor first; outer walls grow from the floor edge (back wall 3 cells tall above the
##    top edge, thin side walls, a low front wall); interior walls are cells drawn on the floor, with doorways cut in them;
##  - doors and windows sit on a formed wall (back: on the top floor edge row; front: on the bottom floor edge row);
##  - checks: one connected floor of at least 12 cells, room for the back wall, walls styled, at least one door,
##    door fronts clear, every walkable cell reachable from a door, passages 2 cells wide (doorways may be 1).
## Cells: [x, y] from the top-left; map.size = [30, 20] for new maps. "." in floor.rows = no floor.

const WALL_H := 3 ## back wall height in cells
const SIZE := Vector2i(30, 20)
const MIN_FLOOR := 12
const DIRS := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

## Opening types until GPT's piece sets exist (docs/MAP-PIECES-SPEC.md): cut from the current 小卖部 art, as in the trial.
## wall: back|front; w: width in cells; door: characters walk through it; band: openings in the same band can't overlap.
const OPENINGS := {
	"back_door": {"name":"后门","wall":"back","band":"mid","w":2,"door":true},
	"window": {"name":"窗户","wall":"back","band":"mid","w":3},
	"sign": {"name":"招牌","wall":"back","band":"mid","w":4},
	"lamp": {"name":"吸顶灯","wall":"back","band":"top","w":3,"light":true},
	"front_door": {"name":"前门（玻璃门）","wall":"front","band":"mid","w":6,"door":true},
	# Outdoor maps (2026-11-11, owner: "purely outdoor scenes like the park have no walls; paths connect maps"):
	"edge_exit": {"name":"路口（小路通到地图外）","wall":"edge","band":"mid","w":2,"door":true,"outdoor":true},
	"entrance": {"name":"建筑入口","wall":"ground","band":"mid","w":2,"door":true,"outdoor":true},
}
## Ground tiles characters can't walk on (outdoor maps).
const BLOCKING_TILES := ["ground-water"]

## kind: "indoor" (walls form from the floor) or "outdoor" (ground only: no walls; fences/hedges are drawn like interior
## walls; you enter and leave by 路口 on the map edge, or a 建筑入口 on the ground).
static func new_map(id: String, name: String, kind := "indoor") -> Dictionary:
	var rows: Array = []
	for y in SIZE.y: rows.append(".".repeat(SIZE.x))
	var style := {"back":"","side":"","front":""} if kind != "outdoor" else {"edge":"hedge"}
	return {"format":"cabin-map/1","id":id,"name":name,"kind":kind,"size":[SIZE.x,SIZE.y],"cell":Grid.CELL,"revision":id+"-1",
		"floor":{"palette":{},"rows":rows},"walls":{"style":style,"inner":[],"doorways":[]},
		"openings":[],"exits":{},"furniture":{"instances":{},"positions":{},"facings":{},"groups":[]}}
static func outdoor(m: Dictionary) -> bool: return str(m.get("kind", "indoor")) == "outdoor"
## Opening types that belong on this kind of map.
static func openings_for(m: Dictionary) -> Array:
	return OPENINGS.keys().filter(func(t): return bool(OPENINGS[t].get("outdoor", false)) == outdoor(m))

# ---------- reading ----------
static func size_of(m: Dictionary) -> Vector2i: return Vector2i(int(m.size[0]), int(m.size[1]))
static func inb(m: Dictionary, c: Vector2i) -> bool: var s := size_of(m); return c.x >= 0 and c.y >= 0 and c.x < s.x and c.y < s.y
static func floor_char(m: Dictionary, c: Vector2i) -> String: return String(m.floor.rows[c.y])[c.x] if inb(m, c) else "."
static func is_floor(m: Dictionary, c: Vector2i) -> bool: return floor_char(m, c) != "."
static func north_edge(m: Dictionary, c: Vector2i) -> bool: return is_floor(m, c) and not is_floor(m, c + Vector2i.UP)
static func south_edge(m: Dictionary, c: Vector2i) -> bool: return is_floor(m, c) and not is_floor(m, c + Vector2i.DOWN)
## Imported pixel rooms can have shorter partition faces. Render and validation
## use the same available height; new maps retain the three-cell wall rule.
static func back_height(m:Dictionary,c:Vector2i)->int:
	if not m.get("walls",{}).get("adaptive",false):return WALL_H
	for h in range(1,WALL_H+1):
		if is_floor(m,c+Vector2i(0,-h)):return h-1
	return WALL_H
static func has_cell(list: Array, c: Vector2i) -> bool:
	for p in list:
		if int(p[0]) == c.x and int(p[1]) == c.y: return true
	return false
static func is_inner(m: Dictionary, c: Vector2i) -> bool: return has_cell(m.walls.inner, c)
static func is_doorway(m: Dictionary, c: Vector2i) -> bool: return has_cell(m.walls.doorways, c)
static func solid_inner(m: Dictionary, c: Vector2i) -> bool: return is_inner(m, c) and not is_doorway(m, c)
static func floor_cells(m: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var s := size_of(m)
	for y in s.y:
		for x in s.x:
			if is_floor(m, Vector2i(x, y)): out.append(Vector2i(x, y))
	return out

# ---------- edits (each returns a new map) ----------
## Paints floor tile `tile` (a piece id) on cells; tile "" clears the floor (and any interior wall or doorway there).
static func paint_floor(m: Dictionary, cells: Array, tile: String) -> Dictionary:
	var out := m.duplicate(true)
	var ch := "."
	if tile != "":
		for k in out.floor.palette:
			if out.floor.palette[k] == tile: ch = k
		if ch == ".":
			# Reclaim unused entries; imports must not overflow the old 26-letter palette.
			var used:="".join(out.floor.rows)
			for k in out.floor.palette.keys():
				if not used.contains(k):out.floor.palette.erase(k)
			for k in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789":
				if not out.floor.palette.has(k):ch=k;break
			if ch==".":return m
			out.floor.palette[ch] = tile
	for c in cells:
		if not inb(out, c): continue
		var row: String = out.floor.rows[c.y]
		out.floor.rows[c.y] = row.substr(0, c.x) + ch + row.substr(c.x + 1)
		if ch == ".":
			out.walls.inner = out.walls.inner.filter(func(p): return not (int(p[0]) == c.x and int(p[1]) == c.y))
			out.walls.doorways = out.walls.doorways.filter(func(p): return not (int(p[0]) == c.x and int(p[1]) == c.y))
	return out

static func set_wall_style(m: Dictionary, part: String, style: String) -> Dictionary:
	var out := m.duplicate(true); out.walls.style[part] = style; return out

## Adds (on=true) or removes interior wall cells. Only on floor. Removing a wall cell also removes its doorway.
static func set_inner(m: Dictionary, cells: Array, on: bool) -> Dictionary:
	var out := m.duplicate(true)
	for c in cells:
		var here := has_cell(out.walls.inner, c)
		if on and not here and is_floor(out, c): out.walls.inner.append([c.x, c.y])
		elif not on and here:
			out.walls.inner = out.walls.inner.filter(func(p): return not (int(p[0]) == c.x and int(p[1]) == c.y))
			out.walls.doorways = out.walls.doorways.filter(func(p): return not (int(p[0]) == c.x and int(p[1]) == c.y))
	return out

## Cuts or closes a doorway in an interior wall cell. "" or the reason it can't.
static func doorway_issue(m: Dictionary, c: Vector2i) -> String:
	return "" if is_inner(m, c) else "门洞只能开在内墙上"
static func toggle_doorway(m: Dictionary, c: Vector2i) -> Dictionary:
	var out := m.duplicate(true)
	if not is_inner(out, c): return out
	if has_cell(out.walls.doorways, c): out.walls.doorways = out.walls.doorways.filter(func(p): return not (int(p[0]) == c.x and int(p[1]) == c.y))
	else: out.walls.doorways.append([c.x, c.y])
	return out

## Where a click at cell `c` lands an opening of `type`: [x, y] or null. Back: the top floor edge at or just below the
## click (the click is on the wall face); front: the bottom floor edge at or just above it. Centred on the click.
static func opening_target(m: Dictionary, type: String, c: Vector2i):
	var d: Dictionary = OPENINGS[type]
	var s := size_of(m)
	if d.wall == "edge": # the nearest map edge to the click (within 2 cells); the exit runs along that edge
		var dist := {"W": c.x, "E": s.x - 1 - c.x, "N": c.y, "S": s.y - 1 - c.y}
		var side := "W"
		for k in dist:
			if dist[k] < dist[side]: side = k
		if dist[side] > 2: return null
		if side in ["N", "S"]: return [clampi(c.x - int(d.w) / 2, 0, s.x - int(d.w)), 0 if side == "N" else s.y - 1, side]
		return [0 if side == "W" else s.x - 1, clampi(c.y - int(d.w) / 2, 0, s.y - int(d.w)), side]
	if d.wall == "ground": return [clampi(c.x - int(d.w) / 2, 0, s.x - int(d.w)), c.y]
	var x := clampi(c.x - int(d.w) / 2, 0, size_of(m).x - int(d.w))
	if d.wall == "back":
		for y in range(c.y, c.y + WALL_H + 1):
			if north_edge(m, Vector2i(c.x, y)): return [x, y]
		return null
	for y in range(c.y, c.y - 2, -1):
		if south_edge(m, Vector2i(c.x, y)): return [x, y]
	return null

## The cells an opening covers on the map (its wall row for indoor ones; its path or doorstep cells outdoors).
static func opening_cells(o: Dictionary) -> Array[Vector2i]:
	var d: Dictionary = OPENINGS.get(o.type, {}); var out: Array[Vector2i] = []
	var vertical: bool = d.get("wall") == "edge" and str(o.get("side", "")) in ["W", "E"]
	for k in int(d.get("w", 0)): out.append(Vector2i(int(o.x), int(o.y) + k) if vertical else Vector2i(int(o.x) + k, int(o.y)))
	return out
static func tile_of(m: Dictionary, c: Vector2i) -> String: return str(m.floor.palette.get(floor_char(m, c), ""))
static func walkable_cell(m: Dictionary, c: Vector2i) -> bool:
	return is_floor(m, c) and not solid_inner(m, c) and not tile_of(m, c) in BLOCKING_TILES
static func opening_issue(m: Dictionary, type: String, x: int, y: int, ignore := -1, side := "") -> String:
	if not OPENINGS.has(type): return "没有这种门窗"
	var d: Dictionary = OPENINGS[type]
	if bool(d.get("outdoor", false)) != outdoor(m): return "%s只能放在%s地图上" % [d.name, "室外" if d.get("outdoor", false) else "室内"]
	if d.wall in ["edge", "ground"]:
		var me := {"type": type, "x": x, "y": y, "side": side}
		for c in opening_cells(me):
			if not inb(m, c) or not walkable_cell(m, c): return "%s要放在能走的地面上（%d 格）" % [d.name, int(d.w)]
			if d.wall == "edge" and not (c.x == 0 or c.y == 0 or c.x == size_of(m).x - 1 or c.y == size_of(m).y - 1): return "路口要贴着地图边"
		for i in m.openings.size():
			if i == ignore: continue
			for c in opening_cells(m.openings[i]):
				if c in opening_cells(me): return "和" + OPENINGS[m.openings[i].type].name + "重叠"
		return ""
	for dx in int(d.w):
		var c := Vector2i(x + dx, y)
		if d.wall=="back" and back_height(m,c)<WALL_H:return "这段矮墙放不下门窗，请选择完整后墙"
		if not (north_edge(m, c) if d.wall == "back" else south_edge(m, c)):
			return "要整段放在%s上（%d 格宽）" % ["后墙" if d.wall == "back" else "前墙", int(d.w)]
	for i in m.openings.size():
		if i == ignore: continue
		var o: Dictionary = m.openings[i]; var e: Dictionary = OPENINGS.get(o.type, {})
		if e.is_empty() or e.wall != d.wall or int(o.y) != y or e.band != d.band: continue
		if x < int(o.x) + int(e.w) and int(o.x) < x + int(d.w): return "和" + e.name + "重叠"
	if d.get("door", false):
		for dx in int(d.w):
			for k in 2:
				if is_inner(m, Vector2i(x + dx, y + k if d.wall == "back" else y - k)): return "门前有内墙挡着"
	return ""

static func add_opening(m: Dictionary, type: String, x: int, y: int, side := "") -> Dictionary:
	var out := m.duplicate(true)
	var n := 1
	while out.openings.any(func(o): return o.id == "%s_%d" % [type, n]): n += 1
	var o := {"id":"%s_%d" % [type, n],"type":type,"x":x,"y":y}
	if side != "": o.side = side
	if OPENINGS[type].get("door", false): o.exit = o.id; out.exits[o.id] = {"to":"","entry":""}
	out.openings.append(o)
	return out

## The index of the opening covering cell `c` (on its wall row), or -1.
static func opening_at(m: Dictionary, c: Vector2i) -> int:
	for i in m.openings.size():
		var o: Dictionary = m.openings[i]; var d: Dictionary = OPENINGS.get(o.type, {})
		if d.is_empty(): continue
		if d.wall in ["edge", "ground"]:
			if c in opening_cells(o): return i
			continue
		var rows := range(int(o.y) - WALL_H, int(o.y) + 1) if d.wall == "back" else range(int(o.y), int(o.y) + 2)
		if c.x >= int(o.x) and c.x < int(o.x) + int(d.w) and c.y in rows: return i
	return -1

static func remove_opening(m: Dictionary, index: int) -> Dictionary:
	var out := m.duplicate(true)
	var o: Dictionary = out.openings[index]
	if o.has("exit"): out.exits.erase(o.exit)
	out.openings.remove_at(index)
	return out

# ---------- derived ----------
static func floor_regions(m: Dictionary) -> int:
	var seen := {}; var regions := 0
	for c in floor_cells(m):
		if seen.has(c): continue
		regions += 1; seen[c] = true; var q: Array[Vector2i] = [c]
		while not q.is_empty():
			var j: Vector2i = q.pop_back()
			for d in DIRS:
				var n: Vector2i = j + d
				if is_floor(m, n) and not seen.has(n): seen[n] = true; q.append(n)
	return regions

## Floor cells that break the wall rules: no room for the back wall above a top edge, or floor touching the map edge.
static func wall_space_problems(m: Dictionary) -> Array[Vector2i]:
	var bad: Array[Vector2i] = []; var s := size_of(m)
	for c in floor_cells(m):
		var wrong := c.x == 0 or c.x == s.x - 1 or c.y == s.y - 1
		if north_edge(m, c):
			for k in range(1, back_height(m,c) + 1):
				var up := c + Vector2i(0, -k)
				if not inb(m, up) or is_floor(m, up): wrong = true; break
		if wrong: bad.append(c)
	return bad

## Cells in front of doors (2 deep) and on both sides of a doorway: they must stay free.
static func clearance(m: Dictionary) -> Dictionary:
	var out := {}
	for o in m.openings:
		var d: Dictionary = OPENINGS.get(o.type, {})
		if not d.get("door", false) or d.get("outdoor", false): continue
		for dx in int(d.w):
			for k in 2:
				var c := Vector2i(int(o.x) + dx, int(o.y) + k if d.wall == "back" else int(o.y) - k)
				if is_floor(m, c): out[c] = true
	for p in m.walls.doorways:
		var c := Vector2i(int(p[0]), int(p[1]))
		var horizontal := is_inner(m, c + Vector2i.LEFT) or is_inner(m, c + Vector2i.RIGHT)
		for d in ([Vector2i.UP, Vector2i.DOWN] if horizontal else [Vector2i.LEFT, Vector2i.RIGHT]):
			if is_floor(m, c + d) and not is_inner(m, c + d): out[c + d] = true
	return out

## Walkable cells: floor that is not a solid interior wall. `blocked` = extra cells (furniture) as a Dictionary set.
static func walkable(m: Dictionary, blocked := {}) -> Dictionary:
	var out := {}
	for c in floor_cells(m):
		if walkable_cell(m, c) and not blocked.has(c): out[c] = true
	return out

static func doors(m: Dictionary) -> Array:
	return m.openings.filter(func(o): return OPENINGS.get(o.type, {}).get("door", false))

static func analysis(m: Dictionary, blocked := {}) -> Dictionary:
	var walk := walkable(m, blocked); var reach := {}; var q: Array[Vector2i] = []
	for o in doors(m):
		for c in opening_cells(o):
			if walk.has(c) and not reach.has(c): reach[c] = true; q.append(c)
	while not q.is_empty():
		var j: Vector2i = q.pop_back()
		for d in DIRS:
			var n: Vector2i = j + d
			if walk.has(n) and not reach.has(n): reach[n] = true; q.append(n)
	var unreachable: Array[Vector2i] = []; var narrow: Array[Vector2i] = []
	var door_cells:={}
	for opening in doors(m):
		for cell in opening_cells(opening):door_cells[cell]=true
	for c in walk:
		if not reach.has(c): unreachable.append(c)
		if is_doorway(m, c) or door_cells.has(c): continue
		var wide := false
		for o in [Vector2i(0,0), Vector2i(-1,0), Vector2i(0,-1), Vector2i(-1,-1)]:
			if [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)].all(func(k): return walk.has(c + o + k)): wide = true; break
		if not wide: narrow.append(c)
	return {"walk": walk, "reach": reach, "unreachable": unreachable, "narrow": narrow}

## [label, ok, detail, cells to mark, rule id] for every rule, in the order the editor shows them. Indoor maps: ids
## floor, wallspace, styled, door, doorplace, reach, narrow, linked (this order). Outdoor maps: outdoor_checks().
const INDOOR_RULES := ["floor", "wallspace", "styled", "door", "doorplace", "reach", "narrow", "linked"]
static func checks(m: Dictionary) -> Array:
	var list := outdoor_checks(m) if outdoor(m) else indoor_checks(m)
	if not outdoor(m):
		for i in list.size(): list[i].append(INDOOR_RULES[i])
	list.append(["与家具共用同一格子尺寸",m.get("cell")==Grid.CELL,"每格 %d 游戏像素" % Grid.CELL,[],"grid"])
	return list
static func indoor_checks(m: Dictionary) -> Array:
	var count := floor_cells(m).size(); var regions := floor_regions(m); var ws := wall_space_problems(m)
	var a := analysis(m); var door_list := doors(m)
	var unset: Array = []
	for part in ["back", "side", "front"]:
		if str(m.walls.style.get(part, "")) == "": unset.append({"back":"后墙","side":"侧墙","front":"前墙"}[part])
	var blocked_doors: Array = []
	for i in m.openings.size():
		var o: Dictionary = m.openings[i]
		if OPENINGS.get(o.type, {}).get("door", false) and opening_issue(m, o.type, int(o.x), int(o.y), i) != "": blocked_doors.append(o.id)
	var unlinked: Array = door_list.filter(func(o): return str(m.exits.get(o.get("exit",""), {}).get("to","")) == "")
	return [
		["地板至少 %d 格，且是一整块" % MIN_FLOOR, count >= MIN_FLOOR and regions == 1, ("现在分成 %d 块" % regions) if regions > 1 else ("%d 格" % count), []],
		["后墙留足绘制空间、地板不贴地图边" if m.walls.get("adaptive",false) else "后墙上方留出 %d 格、地板不贴地图边" % WALL_H, ws.is_empty(), ("%d 格不符合" % ws.size()) if not ws.is_empty() else "", ws],
		["每面墙都选了样式", unset.is_empty(), ("未选：" + "、".join(unset)) if not unset.is_empty() else "", []],
		["至少有一扇门", not door_list.is_empty(), ("%d 扇" % door_list.size()) if not door_list.is_empty() else "没有门就走不进来", []],
		["门放在墙上、门前没有内墙", blocked_doors.is_empty(), "、".join(blocked_doors), []],
		["所有能走的地板都能从门走到", not door_list.is_empty() and a.unreachable.is_empty(), ("%d 格走不到" % a.unreachable.size()) if not a.unreachable.is_empty() else "", a.unreachable],
		["通道至少 2 格宽（门洞除外）", a.narrow.is_empty(), ("%d 格太窄" % a.narrow.size()) if not a.narrow.is_empty() else "", a.narrow],
		["每扇门都连到了别的地方（可以稍后再连）", unlinked.is_empty(), ("%d 扇还没连" % unlinked.size()) if not unlinked.is_empty() else "", []],
	]

## Outdoor rules (no walls): ground, at least one way in/out, ways in/out on walkable ground, everything reachable,
## paths wide enough, every way in/out linked (doesn't block saving).
static func outdoor_checks(m: Dictionary) -> Array:
	var walk := walkable(m); var a := analysis(m); var ways := doors(m)
	var bad: Array = []
	for i in m.openings.size():
		var o: Dictionary = m.openings[i]
		if opening_issue(m, o.type, int(o.x), int(o.y), i, str(o.get("side", ""))) != "": bad.append(o.id)
	var unlinked: Array = ways.filter(func(o): return str(m.exits.get(o.get("exit",""), {}).get("to","")) == "")
	return [
		["能走的地面至少 %d 格" % MIN_FLOOR, walk.size() >= MIN_FLOOR, "%d 格" % walk.size(), [], "ground"],
		["至少有一个出入口（路口或建筑入口）", not ways.is_empty(), ("%d 个" % ways.size()) if not ways.is_empty() else "没有出入口就进不来", [], "door"],
		["出入口都放在能走的地面上", bad.is_empty(), "、".join(bad), [], "doorplace"],
		["所有能走的地面都能从出入口走到", not ways.is_empty() and a.unreachable.is_empty(), ("%d 格走不到" % a.unreachable.size()) if not a.unreachable.is_empty() else "", a.unreachable, "reach"],
		["小路至少 2 格宽", a.narrow.is_empty(), ("%d 格太窄" % a.narrow.size()) if not a.narrow.is_empty() else "", a.narrow, "narrow"],
		["每个出入口都连到了别的地图（可以稍后再连）", unlinked.is_empty(), ("%d 个还没连" % unlinked.size()) if not unlinked.is_empty() else "", [], "linked"],
	]
## One rule by id ([label, ok, detail, cells, id]); a rule this kind of map doesn't have counts as passed.
static func rule(m: Dictionary, id: String) -> Array:
	for r in checks(m):
		if r[4] == id: return r
	return ["", true, "", [], id]

## True when every rule except the last (door links, which come with phase 5) passes.
static func usable(m: Dictionary) -> bool:
	for r in checks(m):
		if r[4] != "linked" and not r[1]: return false
	return true

## The editor's step gates: floor -> walls -> doors (owner pipeline points 4-6).
static func floor_ok(m: Dictionary) -> bool:
	if outdoor(m): return walkable(m).size() >= MIN_FLOOR
	return floor_cells(m).size() >= MIN_FLOOR and floor_regions(m) == 1 and wall_space_problems(m).is_empty()
static func walls_ok(m: Dictionary) -> bool:
	if outdoor(m): return floor_ok(m)
	return floor_ok(m) and ["back","side","front"].all(func(p): return str(m.walls.style.get(p,"")) != "")
