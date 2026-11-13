extends RefCounted
## Pure logic of the MAP editor (draw a roomkit plan). Deliberately separate from the furniture editor (HomeGrid/HomeEditor):
## it only reads and writes <roomkit>/rooms/<id>/room.json and never touches furniture layouts, saves or live scene data.
##
## plan.rows is an Array of Strings, one char per cell: . floor, # wall, W window, D door, o outdoor path, _ outside/void.
## (same legend as roomkit/README.md and core/roomkit.gd)

const RK := preload("res://core/roomkit.gd")
## [char, label, colour] for the palette; order = keys 1..6
const TOOLS := [
	[".", "地板", Color(0.35, 0.80, 0.45, 0.38)],
	["#", "墙", Color(0.55, 0.28, 0.12, 0.80)],
	["W", "窗", Color(0.55, 0.80, 0.95, 0.75)],
	["D", "门", Color(0.98, 0.82, 0.25, 0.80)],
	["o", "室外路", Color(0.30, 0.75, 0.80, 0.45)],
	["_", "清除", Color(0, 0, 0, 0)],
]

static func color_of(ch: String) -> Color:
	for t in TOOLS:
		if t[0] == ch: return t[2]
	return Color(1, 0, 1, 0.5)

static func in_bounds(rows: Array, c: Vector2i) -> bool:
	return c.y >= 0 and c.y < rows.size() and c.x >= 0 and c.x < String(rows[c.y]).length()

## Returns a NEW rows array with cell `c` set to `ch` (unchanged if outside the plan).
static func paint(rows: Array, c: Vector2i, ch: String) -> Array:
	var out: Array = rows.duplicate()
	if not in_bounds(rows, c) or String(rows[c.y])[c.x] == ch: return out
	var row: String = rows[c.y]
	out[c.y] = row.substr(0, c.x) + ch + row.substr(c.x + 1)
	return out

static func fill_rect(rows: Array, a: Vector2i, b: Vector2i, ch: String) -> Array:
	var out: Array = rows.duplicate()
	for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1): out = paint(out, Vector2i(x, y), ch)
	return out

## Cells on the straight line a->b (inclusive), so a fast drag leaves no gaps.
static func line_cells(a: Vector2i, b: Vector2i) -> Array:
	var out: Array = []; var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	if n == 0: return [a]
	for i in n + 1: out.append(Vector2i(roundi(lerpf(a.x, b.x, float(i) / n)), roundi(lerpf(a.y, b.y, float(i) / n))))
	return out

## Human-readable problems with `rows` for this room (placements and assets come from the loaded kit). Empty = fine.
static func check(kit: Dictionary, rows: Array) -> Array:
	var issues: Array = []
	var doors := 0
	for r in rows: for ch in String(r): if ch == "D": doors += 1
	if doors == 0: issues.append("没有门（D）：角色进不来")
	elif doors > 1: issues.append("有 %d 个门；游戏只会使用第一个" % doors)
	var probe: Dictionary = {"room": kit.room.duplicate(true), "assets": kit.assets}
	probe.room.plan.rows = rows
	for p in probe.room.placements:
		var a: Dictionary = kit.assets[p.asset]
		if a.layer == "surface" or a.kind == "wall": continue
		var on_floor := false
		for c in RK.footprint(p, a):
			if RK.plan_char(probe.room, c) in RK.WALKABLE: on_floor = true
		if not on_floor: issues.append("%s 不在地板上" % p.id)
	if doors > 0:
		for name in RK.unreachable_anchors(probe): issues.append("走不到 " + name)
	return issues

## Writes plan.rows (and shape.drive, cols/rows, and any top-level fields passed in "extra", e.g. backdrop) into room.json, keeping every other field. Atomic, with a .bak. Returns "" or an error.
static func save(dir: String, room_id: String, rows: Array, drive: bool, extra: Dictionary = {}) -> String:
	var file := dir.path_join("rooms").path_join(room_id).path_join("room.json")
	if not FileAccess.file_exists(file): return "找不到 room.json"
	var room = JSON.parse_string(FileAccess.get_file_as_string(file))
	if not room is Dictionary or not room.get("plan") is Dictionary: return "读不到 room.json"
	room.plan.rows = rows
	room["rows"] = rows.size(); room["cols"] = String(rows[0]).length() if not rows.is_empty() else 0
	for k in extra: room[k] = extra[k]
	var shape: Dictionary = room.get("shape", {}) if room.get("shape", {}) is Dictionary else {}
	shape["drive"] = drive; room["shape"] = shape
	var handle := FileAccess.open(file + ".tmp", FileAccess.WRITE)
	if handle == null: return "无法写入 room.json"
	handle.store_string(JSON.stringify(room, "  ") + "\n"); handle.close()
	if DirAccess.copy_absolute(file, file + ".bak") != OK: return "备份失败，未覆盖"
	if DirAccess.rename_absolute(file + ".tmp", file) != OK: return "保存失败"
	return ""

# ---- Any map: list, create, resize, import a game scene ----

## Ids of every roomkit room (folders under rooms/ that hold a room.json), sorted.
static func list_rooms(dir: String) -> Array:
	var out: Array = []
	for d in DirAccess.get_directories_at(dir.path_join("rooms")):
		if FileAccess.file_exists(dir.path_join("rooms").path_join(d).path_join("room.json")): out.append(d)
	out.sort()
	return out

static func valid_id(id: String) -> bool:
	var re := RegEx.new(); re.compile("^[a-z0-9][a-z0-9_-]*$")
	return re.search(id) != null

## Like RoomKit.load_room but never fails because an asset file is missing: placements whose asset is absent are left out
## of the returned copy (and listed in "missing"), so any room can be opened and its plan edited.
static func open_room(dir: String, room_id: String) -> Dictionary:
	var file := dir.path_join("rooms").path_join(room_id).path_join("room.json")
	if not FileAccess.file_exists(file): return {"room": {}, "assets": {}, "error": "没有这个房间：" + room_id, "missing": []}
	var room = JSON.parse_string(FileAccess.get_file_as_string(file))
	if not room is Dictionary or not room.get("plan") is Dictionary or not room.plan.get("rows") is Array:
		return {"room": {}, "assets": {}, "error": "room.json 格式不对：" + room_id, "missing": []}
	var assets := {}; var missing: Array = []; var kept: Array = []
	for p in room.get("placements", []):
		var a = null
		var af := dir.path_join("library").path_join(String(p.asset) + ".json")
		if assets.has(p.asset): a = assets[p.asset]
		elif FileAccess.file_exists(af): a = JSON.parse_string(FileAccess.get_file_as_string(af))
		if a is Dictionary: assets[p.asset] = a; kept.append(p)
		elif not String(p.asset) in missing: missing.append(String(p.asset))
	room.placements = kept
	return {"room": room, "assets": assets, "error": "", "missing": missing}

static func blank_rows(cols: int, rows: int) -> Array:
	var out: Array = []
	for i in rows: out.append("_".repeat(cols))
	return out

## Crops or pads (with "_") to cols x rows, keeping the top-left corner fixed.
static func resize_rows(rows: Array, cols: int, count: int) -> Array:
	var out: Array = []
	for y in count:
		var line: String = rows[y] if y < rows.size() else ""
		out.append(line.substr(0, cols) + "_".repeat(maxi(0, cols - line.length())))
	return out

## A new in-memory room dictionary (same fields as roomkit.mjs init).
static func new_room(id: String, rows: Array, source: Dictionary = {}) -> Dictionary:
	var legend := {".": "floor", "_": "void (outside the room, never gridded)", "#": "wall cell (blocks, drawn as wall)", "D": "door (entry/exit, walkable)", "W": "window (on a wall cell)", "o": "outdoor walkable (path/garden): walking yes, furniture no"}
	var room := {"format": "roomkit-room/1", "id": id, "name": id, "cell": 32, "cols": String(rows[0]).length() if not rows.is_empty() else 0, "rows": rows.size(),
		"plan": {"legend": legend, "rows": rows}, "shell": {}, "placements": [], "test": {}}
	if not source.is_empty(): room["source"] = source
	return room

## Writes a brand-new room.json. Refuses to overwrite an existing room. Returns "" or an error.
static func write_new(dir: String, room: Dictionary) -> String:
	if not valid_id(String(room.get("id", ""))): return "房间名只能用小写字母、数字、- 和 _"
	var file := dir.path_join("rooms").path_join(String(room.id)).path_join("room.json")
	if FileAccess.file_exists(file): return "已经有这个房间：" + String(room.id)
	if DirAccess.make_dir_recursive_absolute(file.get_base_dir()) != OK: return "无法创建文件夹"
	var handle := FileAccess.open(file, FileAccess.WRITE)
	if handle == null: return "无法写入 room.json"
	handle.store_string(JSON.stringify(room, "  ") + "\n"); handle.close()
	return ""

## Starting plan for ANY game scene (WorldData.scenes[id]): a cell is floor (or outdoor path for outdoor scenes) when the game's own
## walking rules let a character stand at its centre; the door/first exit cell becomes D. Sizes round up to whole cells.
static func rows_from_scene(scene: Dictionary) -> Array:
	var nav := RoomNav.new(scene)
	var cols := ceili(float(scene.width) / 32.0); var count := ceili(float(scene.height) / 32.0)
	var walk_char := "o" if scene.get("outdoor", false) else "."
	var rows: Array = []
	for y in count:
		var line := ""
		for x in cols: line += walk_char if nav.walkable(Vector2(x * 32 + 16, y * 32 + 16)) else "_"
		rows.append(line)
	var door = scene.get("entries", {}).get("door", null)
	if door == null:
		for e in scene.get("exits", []): door = {"x": e.get("x", e.get("point", {}).get("x", 0)), "y": e.get("y", e.get("point", {}).get("y", 0))}; break
	if door != null: rows = paint(rows, Vector2i(floori(float(door.x) / 32.0), floori(float(door.y) / 32.0)), "D")
	return rows
