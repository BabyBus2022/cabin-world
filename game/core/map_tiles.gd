extends RefCounted
## Walls and floors as assets: the actual content of a map. (Logic only; the editor UI is ui/map_editor.gd.)
##
## A room's look and shape are two tile layers, each cell holding one palette character:
##   tiles.floor[y][x]  -> tiles.floor_palette[char] = floor asset id          ("." = no floor)
##   tiles.wall[y][x]   -> tiles.wall_palette[char]  = {asset, dir}            ("." = no wall)
## A wall asset may be DRAWN thin (visual.thickness 0.1..1 of a cell, hugging the cell side `dir` N/E/S/W) but always BLOCKS one
## full cell. The special wall asset "door" marks the door. plan.rows (the collision plan every other tool reads) is DERIVED from the
## layers on every save: wall -> "#" (window asset -> "W", door -> "D"), else floor -> "." (outdoor floor -> "o"), else "_".

const MapPlan := preload("res://core/map_plan.gd")
const NONE := "."
const PALETTE_CHARS := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
const DOOR := "door"
const DIRS := ["N", "E", "S", "W"]

## Starter types, written to library/ when missing. No art yet (swatch colour only): GPT-image art is added per type later.
static func default_assets() -> Array:
	var out: Array = []
	for f in [["floor-basic", "素地板", "#e9c58a", false], ["floor-tatami", "榻榻米", "#d9cf6a", false], ["floor-wood", "木地板", "#d49a52", false], ["floor-stone", "石板", "#8f969c", false], ["floor-path", "室外小路", "#cdb98a", true]]:
		out.append({"format": "roomkit-asset/1", "id": f[0], "name": f[1], "kind": "floor", "layer": "floor", "footprint": {"w": 1, "h": 1}, "anchors": {}, "blockout": {}, "actions": {}, "swatch": f[2], "outdoor": f[3], "source": {"type": "starter"}})
	for w in [["wall-basic", "墙（半格）", "#8a4b2a", 0.5, false], ["wall-thin", "薄墙（0.3格）", "#a8683f", 0.3, false], ["wall-full", "厚墙（整格）", "#6d3a20", 1.0, false], ["wall-window", "带窗的墙", "#7fb7d8", 0.5, true]]:
		out.append({"format": "roomkit-asset/1", "id": w[0], "name": w[1], "kind": "wall", "layer": "solid", "footprint": {"w": 1, "h": 1}, "anchors": {}, "blockout": {}, "actions": {}, "swatch": w[2], "visual": {"thickness": w[3]}, "window": w[4], "source": {"type": "starter"}})
	return out

static func asset_file(dir: String, id: String) -> String:
	return dir.path_join("library").path_join(id + ".json")

## Writes starter floor/wall types that are missing. Returns how many were written.
static func ensure_defaults(dir: String) -> int:
	var n := 0
	DirAccess.make_dir_recursive_absolute(dir.path_join("library"))
	for a in default_assets():
		if not FileAccess.file_exists(asset_file(dir, a.id)) and write_asset(dir, a) == "": n += 1
	return n

static func write_asset(dir: String, a: Dictionary) -> String:
	if not MapPlan.valid_id(String(a.get("id", ""))): return "名字只能用小写字母、数字、- 和 _"
	DirAccess.make_dir_recursive_absolute(dir.path_join("library"))
	var file := asset_file(dir, a.id)
	var handle := FileAccess.open(file + ".tmp", FileAccess.WRITE)
	if handle == null: return "无法写入素材"
	handle.store_string(JSON.stringify(a, "  ") + "\n"); handle.close()
	if FileAccess.file_exists(file): DirAccess.remove_absolute(file)
	if DirAccess.rename_absolute(file + ".tmp", file) != OK: return "素材保存失败"
	return ""

## All assets of `kind` (floor or wall) in the library, sorted by id. Each entry is the asset's JSON dictionary.
static func list_assets(dir: String, kind: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir.path_join("library")):
		if not f.ends_with(".json"): continue
		var a = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("library").path_join(f)))
		if a is Dictionary and a.get("kind", "") == kind: out.append(a)
	out.sort_custom(func(x, y): return String(x.id) < String(y.id))
	return out

static func swatch(a: Dictionary) -> Color:
	return Color(String(a.get("swatch", "#ff00ff")))

static func thickness(a: Dictionary) -> float:
	return clampf(float(a.get("visual", {}).get("thickness", 1.0)), 0.1, 1.0)

## The thin strip a wall is DRAWN as inside its cell (collision is always the whole cell).
static func wall_strip(cell: Rect2, dir: String, t: float) -> Rect2:
	match dir:
		"S": return Rect2(cell.position.x, cell.end.y - cell.size.y * t, cell.size.x, cell.size.y * t)
		"E": return Rect2(cell.end.x - cell.size.x * t, cell.position.y, cell.size.x * t, cell.size.y)
		"W": return Rect2(cell.position.x, cell.position.y, cell.size.x * t, cell.size.y)
	return Rect2(cell.position.x, cell.position.y, cell.size.x, cell.size.y * t)

## ---- the editable model: {fl: rows, wl: rows, fpal: {char: asset id}, wpal: {char: {asset, dir}}} ----
static func make_model(cols: int, count: int) -> Dictionary:
	return {"fl": blank_tiles(cols, count), "wl": blank_tiles(cols, count), "fpal": {}, "wpal": {}}

static func blank_tiles(cols: int, count: int) -> Array:
	var out: Array = []
	for i in count: out.append(NONE.repeat(cols))
	return out

static func model_size(m: Dictionary) -> Vector2i:
	return Vector2i(String(m.fl[0]).length() if not m.fl.is_empty() else 0, m.fl.size())

## Old rooms only have plan.rows: map the characters onto starter assets so they open in the asset editor unchanged.
static func model_from_plan(rows: Array) -> Dictionary:
	var m := make_model(String(rows[0]).length() if not rows.is_empty() else 0, rows.size())
	for y in rows.size():
		for x in String(rows[y]).length():
			var c := Vector2i(x, y)
			match String(rows[y])[x]:
				".": m = paint_tile(m, c, "floor", "floor-basic", "N")
				"o": m = paint_tile(m, c, "floor", "floor-path", "N")
				"#": m = paint_tile(m, c, "wall", "wall-basic", "N")
				"W": m = paint_tile(m, c, "wall", "wall-window", "N")
				"D": m = paint_tile(m, c, "door", DOOR, "N")
	return m

static func model_from_tiles(tiles: Dictionary) -> Dictionary:
	return {"fl": tiles.floor.duplicate(), "wl": tiles.wall.duplicate(), "fpal": tiles.get("floor_palette", {}).duplicate(true), "wpal": tiles.get("wall_palette", {}).duplicate(true)}

## The room.json form: unused palette entries are dropped.
static func model_to_tiles(m: Dictionary) -> Dictionary:
	var fused := {}; var wused := {}
	for line in m.fl:
		for ch in String(line): fused[ch] = true
	for line in m.wl:
		for ch in String(line): wused[ch] = true
	var fp := {}; var wp := {}
	for k in m.fpal:
		if fused.has(k): fp[k] = m.fpal[k]
	for k in m.wpal:
		if wused.has(k): wp[k] = m.wpal[k]
	return {"floor": m.fl.duplicate(), "wall": m.wl.duplicate(), "floor_palette": fp, "wall_palette": wp}

static func palette_char(pal: Dictionary, entry) -> String:
	for k in pal:
		if pal[k] == entry: return k
	for ch in PALETTE_CHARS:
		if not pal.has(ch): return ch
	return ""

static func set_char(rows: Array, c: Vector2i, ch: String) -> Array:
	var out: Array = rows.duplicate(); var row: String = rows[c.y]
	out[c.y] = row.substr(0, c.x) + ch + row.substr(c.x + 1)
	return out

## kind: floor | wall | door | erase | erase_floor | erase_wall. Returns a NEW model (the old one is untouched).
static func paint_tile(m: Dictionary, c: Vector2i, kind: String, asset: String, dir: String) -> Dictionary:
	var s := model_size(m)
	if c.x < 0 or c.y < 0 or c.x >= s.x or c.y >= s.y: return m
	var out := m.duplicate(true)
	match kind:
		"floor":
			var ch := palette_char(out.fpal, asset)
			if ch == "": return m
			out.fpal[ch] = asset; out.fl = set_char(out.fl, c, ch)
		"wall", "door":
			var side := auto_dir(m, c) if dir == "auto" else dir
			var entry := {"asset": asset, "dir": side if kind == "wall" else "N"}
			var ch := palette_char(out.wpal, entry)
			if ch == "": return m
			out.wpal[ch] = entry; out.wl = set_char(out.wl, c, ch)
		"erase": out.fl = set_char(out.fl, c, NONE); out.wl = set_char(out.wl, c, NONE)
		"erase_floor": out.fl = set_char(out.fl, c, NONE)
		"erase_wall": out.wl = set_char(out.wl, c, NONE)
	return out

static func fill_tiles(m: Dictionary, a: Vector2i, b: Vector2i, kind: String, asset: String, dir: String) -> Dictionary:
	var out := m
	for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1): out = paint_tile(out, Vector2i(x, y), kind, asset, dir)
	return out

static func resize_model(m: Dictionary, cols: int, count: int) -> Dictionary:
	var out := m.duplicate(true)
	out.fl = resize_tiles(m.fl, cols, count); out.wl = resize_tiles(m.wl, cols, count)
	return out

static func resize_tiles(rows: Array, cols: int, count: int) -> Array:
	var out: Array = []
	for y in count:
		var line: String = rows[y] if y < rows.size() else ""
		out.append(line.substr(0, cols) + NONE.repeat(maxi(0, cols - line.length())))
	return out

## The collision plan the rest of the toolchain reads, derived from the layers. `assets` maps id -> asset dictionary.
static func derive_rows(m: Dictionary, assets: Dictionary) -> Array:
	var s := model_size(m); var out: Array = []
	for y in s.y:
		var line := ""
		for x in s.x:
			var wc := String(m.wl[y])[x]; var fc := String(m.fl[y])[x]
			if wc != NONE and m.wpal.has(wc):
				var id: String = m.wpal[wc].asset
				line += "D" if id == DOOR else ("W" if assets.get(id, {}).get("window", false) else "#")
			elif fc != NONE and m.fpal.has(fc):
				line += "o" if assets.get(String(m.fpal[fc]), {}).get("outdoor", false) else "."
			else: line += "_"
		out.append(line)
	return out

## ---- ideas borrowed from other editors ----
## Auto side (LDtk-style rule from neighbours): a wall is drawn on the side that faces the floor next to it, so a thin wall hugs the
## room's edge with no gap. Order of preference S, N, E, W when floor is on several sides; "N" when there is none.
static func auto_dir(m: Dictionary, c: Vector2i) -> String:
	var s := model_size(m)
	for e in [["S", Vector2i(0, 1)], ["N", Vector2i(0, -1)], ["E", Vector2i(1, 0)], ["W", Vector2i(-1, 0)]]:
		var n: Vector2i = c + e[1]
		if n.x < 0 or n.y < 0 or n.x >= s.x or n.y >= s.y: continue
		if String(m.fl[n.y])[n.x] != NONE and String(m.wl[n.y])[n.x] == NONE: return e[0]
	return "N"

## Paint bucket (Tiled-style): fills the connected region (4 neighbours) of cells that hold the same floor (kind floor) or the same
## wall/empty value (other kinds) as the clicked cell. `dir` may be "auto".
static func flood_fill(m: Dictionary, start: Vector2i, kind: String, asset: String, dir: String) -> Dictionary:
	var s := model_size(m)
	if start.x < 0 or start.y < 0 or start.x >= s.x or start.y >= s.y: return m
	var layer: Array = m.fl if kind == "floor" or kind == "erase_floor" else m.wl
	var target := String(layer[start.y])[start.x]
	var seen := {start: true}; var queue: Array = [start]; var out := m
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		out = paint_tile(out, c, kind, asset, auto_dir(out, c) if dir == "auto" else dir)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= s.x or n.y >= s.y or seen.has(n): continue
			if String(layer[n.y])[n.x] == target: seen[n] = true; queue.append(n)
	return out

## "Room first, then walls" (Sweet Home 3D workflow): puts `asset` on every empty cell touching a floor cell (8 neighbours),
## each drawn on the side facing the floor. Existing walls, doors and floors are left alone.
static func wall_ring(m: Dictionary, asset: String) -> Dictionary:
	var s := model_size(m); var spots: Array = []
	for y in s.y:
		for x in s.x:
			if String(m.fl[y])[x] != NONE or String(m.wl[y])[x] != NONE: continue
			var touches := false
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = x + dx; var ny: int = y + dy
					if (dx != 0 or dy != 0) and nx >= 0 and ny >= 0 and nx < s.x and ny < s.y and String(m.fl[ny])[nx] != NONE: touches = true
			if touches: spots.append(Vector2i(x, y))
	var out := m
	for c in spots: out = paint_tile(out, c, "wall", asset, auto_dir(out, c))
	return out

## Asset ids used by the model that are not in the library, so the editor can say so instead of drawing nothing.
static func missing_assets(m: Dictionary, assets: Dictionary) -> Array:
	var out: Array = []
	for k in m.fpal:
		var id := String(m.fpal[k])
		if not assets.has(id) and not id in out: out.append(id)
	for k in m.wpal:
		var id := String(m.wpal[k].asset)
		if id != DOOR and not assets.has(id) and not id in out: out.append(id)
	return out
