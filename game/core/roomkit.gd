class_name RoomKit
extends RefCounted
## Loader for roomkit data (see CabinWorld/roomkit/README.md). Read-only: never writes saves or the live layout.
## One room = <dir>/rooms/<id>/room.json, assets = <dir>/library/<asset>.json.
## Everything here is pure data -> data, so the same functions serve the game, the editor and headless checks.
##
## Coordinates: cells are integers; "px" values are cell * room.cell (32). Footprints are in the asset's
## facing-S frame and swap w/h for E/W (same rule as roomkit.mjs rotSize/rotPt: keep them in sync).

const DIRS := ["N", "E", "S", "W"]
const WALKABLE := [".", "D"] ## plan chars a character may stand on

## Returns {"room":Dictionary,"assets":Dictionary,"error":String}. error=="" means loaded.
static func load_room(dir: String, room_id: String) -> Dictionary:
	var room = _read(dir.path_join("rooms").path_join(room_id).path_join("room.json"))
	if room == null:
		return {"room": {}, "assets": {}, "error": "cannot read room " + room_id}
	var assets := {}
	for p in room.get("placements", []):
		var id: String = p.asset
		if assets.has(id): continue
		var a = _read(dir.path_join("library").path_join(id + ".json"))
		if a == null:
			return {"room": room, "assets": assets, "error": "missing asset " + id}
		assets[id] = a
	return {"room": room, "assets": assets, "error": ""}

static func _read(path: String):
	if not FileAccess.file_exists(path): return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

static func size_for(asset: Dictionary, dir: String) -> Vector2i:
	var w := int(asset.footprint.w); var h := int(asset.footprint.h)
	return Vector2i(h, w) if dir == "E" or dir == "W" else Vector2i(w, h)

## Rotate a point from the asset's own frame (facing S) into the placed direction.
static func rot_pt(pt: Array, asset: Dictionary, dir: String) -> Vector2:
	var x := float(pt[0]); var y := float(pt[1]); var w := float(asset.footprint.w); var h := float(asset.footprint.h)
	match dir:
		"E": return Vector2(h - y, x)
		"W": return Vector2(y, w - x)
		"N": return Vector2(w - x, h - y)
	return Vector2(x, y)

static func plan_char(room: Dictionary, c: Vector2i) -> String:
	var rows: Array = room.plan.rows
	if c.y < 0 or c.y >= rows.size(): return "_"
	var row: String = rows[c.y]
	return row[c.x] if c.x >= 0 and c.x < row.length() else "_"

static func footprint(p: Dictionary, asset: Dictionary) -> Array:
	var s := size_for(asset, p.get("dir", "S")); var out: Array = []
	for dx in s.x:
		for dy in s.y: out.append(Vector2i(int(p.cell[0]) + dx, int(p.cell[1]) + dy))
	return out

## World-pixel position of a named anchor of a placement (centre of the anchor point, not the cell).
static func anchor_px(room: Dictionary, p: Dictionary, asset: Dictionary, name: String) -> Vector2:
	var r := rot_pt(asset.anchors[name].offset, asset, p.get("dir", "S"))
	return (Vector2(float(p.cell[0]), float(p.cell[1])) + r) * float(room.cell)

## Collision rectangles in px from solid footprints only (floor/surface items never block).
## Wall-margin cells (not walkable in the plan) are skipped, matching roomkit validation.
static func obstacles(kit: Dictionary) -> Array:
	var room: Dictionary = kit.room; var s := float(room.cell); var out: Array = []
	## Plan walls ("#") always block a FULL cell, however thin they are drawn (owner rule 2026-11-08).
	for y in room.plan.rows.size():
		for x in room.plan.rows[y].length():
			if room.plan.rows[y][x] == "#": out.append(Rect2(x * s, y * s, s, s))
	for p in room.placements:
		var a: Dictionary = kit.assets[p.asset]
		if a.layer != "solid": continue
		for c in footprint(p, a):
			if plan_char(room, c) in WALKABLE: out.append(Rect2(c.x * s, c.y * s, s, s))
	return out

## Cells reachable from any door by 4-neighbour walking, avoiding solid footprints.
static func reachable(kit: Dictionary) -> Dictionary:
	var room: Dictionary = kit.room; var blocked := {}
	for p in room.placements:
		var a: Dictionary = kit.assets[p.asset]
		if a.layer == "solid":
			for c in footprint(p, a): blocked[c] = true
	var seen := {}; var queue: Array = []
	for y in room.plan.rows.size():
		for x in room.plan.rows[y].length():
			if room.plan.rows[y][x] == "D": seen[Vector2i(x, y)] = true; queue.append(Vector2i(x, y))
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not seen.has(n) and plan_char(room, n) in WALKABLE and not blocked.has(n):
				seen[n] = true; queue.append(n)
	return seen

## Errors for anchors flagged reach:true that cannot be reached; empty array = fine.
static func unreachable_anchors(kit: Dictionary) -> Array:
	var seen := reachable(kit); var bad: Array = []
	for p in kit.room.placements:
		var a: Dictionary = kit.assets[p.asset]
		for n in a.anchors:
			if not a.anchors[n].get("reach", false): continue
			var px := anchor_px(kit.room, p, a, n) / float(kit.room.cell)
			if not seen.has(Vector2i(int(floor(px.x)), int(floor(px.y)))): bad.append(p.id + "." + n)
	return bad

## Bridge to the existing HomeGrid editor: its layout is {version,scene,positions:{id:[cx,cy]}}.
## Only assets imported from the old catalog (source.legacyCell + source.footCell) can map back; others are skipped
## and listed in "unmapped" so nothing disappears silently.
static func to_home_grid_layout(kit: Dictionary) -> Dictionary:
	var positions := {}; var unmapped: Array = []
	for p in kit.room.placements:
		var src: Dictionary = kit.assets[p.asset].get("source", {}) if typeof(kit.assets[p.asset].get("source", {})) == TYPE_DICTIONARY else {}
		if src.has("legacyCell") and src.has("footCell"):
			positions[p.id] = [float(src.legacyCell[0]) + float(p.cell[0]) - float(src.footCell[0]), float(src.legacyCell[1]) + float(p.cell[1]) - float(src.footCell[1])]
		else:
			unmapped.append(p.id)
	return {"version": 1, "scene": kit.room.id, "positions": positions, "unmapped": unmapped}

## ---- Room shape (plan -> floor mask, walk area, walls). Used only when room.shape.drive == true. ----
const WALK_CHARS := [".", "D", "o"] ## o = outdoor walkable (path, garden): characters may walk, furniture may not be placed

## One axis-aligned rectangle per horizontal run of matching cells, as arrays of [x,y] points in px.
## `grow` expands each rectangle a little so neighbours overlap (needed for point-in-polygon tests on shared edges).
static func run_polygons(room: Dictionary, chars: Array, grow := 0.0) -> Array:
	var s := float(room.cell); var out: Array = []
	for y in room.plan.rows.size():
		var row: String = room.plan.rows[y]; var x := 0
		while x < row.length():
			if row[x] in chars:
				var x2 := x
				while x2 < row.length() and row[x2] in chars: x2 += 1
				var l: float = x * s - grow; var t: float = y * s - grow; var r: float = x2 * s + grow; var b: float = (y + 1) * s + grow
				out.append([[l, t], [r, t], [r, b], [l, b]]); x = x2
			else: x += 1
	return out

## Wall cells ("#") as full-cell rects, whatever their art thickness.
static func wall_rects(room: Dictionary) -> Array:
	var s := float(room.cell); var out: Array = []
	for y in room.plan.rows.size():
		for x in room.plan.rows[y].length():
			if room.plan.rows[y][x] == "#": out.append({"x": x * s, "y": y * s, "w": s, "h": s})
	return out

## Everything HomeGrid needs to let the plan drive the room. Empty dictionary = plan does not drive (default).
static func shape(kit: Dictionary) -> Dictionary:
	var room: Dictionary = kit.room
	if not room.get("shape", {}).get("drive", false): return {}
	var s := float(room.cell); var lo := Vector2(1e9, 1e9); var hi := Vector2(-1e9, -1e9)
	for y in room.plan.rows.size():
		for x in room.plan.rows[y].length():
			if room.plan.rows[y][x] in WALK_CHARS:
				lo = Vector2(min(lo.x, x * s), min(lo.y, y * s)); hi = Vector2(max(hi.x, (x + 1) * s), max(hi.y, (y + 1) * s))
	return {"floor": run_polygons(room, WALKABLE), "walk": run_polygons(room, WALK_CHARS, 0.5), "walls": wall_rects(room),
		"walk_rect": {"x": lo.x, "y": lo.y, "w": hi.x - lo.x, "h": hi.y - lo.y}, "cell": s,
		"door": door_px(room), "size": [room.cols * s, room.rows * s]}


## Centre of the first door cell ("D") in px, or {} when the plan has none. Only the first door is used.
static func door_px(room: Dictionary) -> Dictionary:
	var s := float(room.cell)
	for y in room.plan.rows.size():
		var x: int = room.plan.rows[y].find("D")
		if x >= 0: return {"x": x * s + s / 2.0, "y": y * s + s / 2.0}
	return {}
