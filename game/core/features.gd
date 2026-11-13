class_name Features
extends RefCounted
## Optional 1.1 modules (docs/UPDATE-1.1-DESIGN.md). Each module can be switched off to keep the 1.0 version.
##
## DATA: <data folder>/features.json, written by the updater or the bot's cabin_update_apply, e.g.
##   {"version":1, "modules":{"arcade-renovated":false, "furniture-rotation":false}}
## A module missing from the file, or no file at all, is ON: the owner's edition and VADS keep today's game unchanged.
## The data folder is the same one the bridge discovery uses (--data, CABINWORLD_DATA or cabinworld.ini, see InstallPaths).
## Switching a module only changes which copy of its data files is read at start: the 1.0 copies live in
## res://assets/classic/ and are never written. Program files are not replaced.
##
## Modules and what turning them OFF keeps from 1.0:
##   arcade-renovated     the 1.0 railway arcade: its scene, layered art and furniture grid (no wall partitions, one Tetris machine)
##   furniture-rotation   the 1.0 furniture art and fixed facings in the restaurant, shop, home and park; R in F6 does not turn
##   gomoku               Gomoku is not offered at the chess table
##   furniture-workshop   the "家具制作" button and custom furniture are hidden
##   map-editor           the "编辑地图" entry in Settings is hidden
##   character-motion     the 1.0 walking and idle animation set
##   seasons              no seasonal decorations or seasonal shop goods
##   seaside-path         the beach path from the home's south door is closed
##   pocket-money-50      the 1.0 allowance: +20 a day, savings up to 80
##   add-bots             the 机器人与房间 entry in Settings is hidden (bots added earlier stay)
##   settings-ui          the 1.0 Settings layout
const MODULES := ["arcade-renovated","furniture-rotation","gomoku","furniture-workshop","map-editor","character-motion",
	"seasons","seaside-path","pocket-money-50","add-bots","settings-ui"]
## Which module owns a data file whose 1.0 copy is in res://assets/classic/ (path relative to res://assets/).
const CLASSIC_FILES := {
	"arcade-grid.json":"arcade-renovated", "baked/world-arcade.layers.json":"arcade-renovated",
	"restaurant-grid.json":"furniture-rotation", "shop-grid.json":"furniture-rotation", "home-grid.json":"furniture-rotation",
	"park-grid.json":"furniture-rotation", "restaurant/furniture.json":"furniture-rotation",
}
## Rooms whose map file (assets/maps/<scene>/map.json) belongs to a module: with it off, the room is built from the
## classic grid above instead, as in 1.0.
const MAP_OWNER := {"world-arcade":"arcade-renovated", "world-restaurant":"furniture-rotation", "qianxia-shop":"furniture-rotation",
	"xiaojingyu-home":"furniture-rotation", "qianxia-park":"furniture-rotation"}
## world.json scene entries replaced by their 1.0 version (res://assets/classic/scenes/<scene>.json).
const CLASSIC_SCENES := {"world-arcade":"arcade-renovated"}

static var _flags := {}
static var _loaded := false
static var path := ""

static func load_flags(force := false) -> void:
	if _loaded and not force: return
	_loaded = true; _flags = {}
	var dir := ""
	var exe_dir := OS.get_executable_path().get_base_dir()
	var ini := exe_dir.path_join("cabinworld.ini")
	var text := FileAccess.get_file_as_string(ini) if FileAccess.file_exists(ini) else ""
	dir = InstallPaths.resolve_data(OS.get_cmdline_user_args(), OS.get_environment("CABINWORLD_DATA"), exe_dir, text)
	path = dir.path_join("features.json")
	if not FileAccess.file_exists(path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary and data.get("modules") is Dictionary:
		for id in data.modules:
			if id in MODULES and data.modules[id] is bool: _flags[id] = data.modules[id]

static func on(id: String) -> bool:
	load_flags()
	return bool(_flags.get(id, true))

## res:// path of a data file, taking the 1.0 copy when its module is off. relative = path under res://assets/.
static func asset(relative: String) -> String:
	var owner: String = CLASSIC_FILES.get(relative, "")
	if owner != "" and not on(owner):
		var classic := "res://assets/classic/" + relative
		if FileAccess.file_exists(classic): return classic
	return "res://assets/" + relative

static func use_map(scene: String) -> bool:
	var owner: String = MAP_OWNER.get(scene, "")
	return owner == "" or on(owner)

## world.json scenes with the 1.0 version of each scene whose module is off.
static func scenes(scenes: Dictionary) -> Dictionary:
	for id in CLASSIC_SCENES:
		if scenes.has(id) and not on(CLASSIC_SCENES[id]):
			var file := "res://assets/classic/scenes/%s.json" % id
			if FileAccess.file_exists(file):
				var old = JSON.parse_string(FileAccess.get_file_as_string(file))
				if old is Dictionary: scenes[id] = old
	return scenes

## Writes the player's choice. The previous file is kept as features.json.bak; the write is atomic (temp file, rename).
## Takes effect on the next start (rooms and art are read once). Returns "" or an error text.
static func save(choice: Dictionary) -> String:
	load_flags()
	if path == "": return "找不到数据文件夹"
	var modules := {}
	for id in MODULES: modules[id] = bool(choice.get(id, on(id)))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if FileAccess.file_exists(path): DirAccess.copy_absolute(path, path + ".bak")
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null: return "写不进 " + tmp
	f.store_string(JSON.stringify({"version": 1, "modules": modules, "savedAt": Time.get_datetime_string_from_system(true)}, "  ") + "\n"); f.close()
	if DirAccess.rename_absolute(tmp, path) != OK: return "保存失败：" + path
	return ""

## The shared descriptions (assets/update/modules.json), also used by the bridge's cabin_update_plan.
static func descriptions() -> Array:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/update/modules.json"))
	return data.get("modules", []) if data is Dictionary else []

## For the bridge and Settings: every module and whether it is on.
static func status() -> Dictionary:
	load_flags()
	var out := {}
	for id in MODULES: out[id] = on(id)
	return {"file": path, "modules": out}
