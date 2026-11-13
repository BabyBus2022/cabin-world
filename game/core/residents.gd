class_name Residents
extends RefCounted
## The people who live in the world. The game creates them when it starts and keeps where they are; VADS only asks them to go places.
##
## INTERFACE: residents save file. Full reference: ../docs/INTERFACES.md section 8.
##   Written to residents.json beside the economy save. One entry per character key:
##   scene (room she is in), x, y (feet), want_scene, want_zone (where she is heading or standing), next (door she is heading for).
##   seats holds the facility table, see Seats.
##
## DATA: res://assets/residents.json. The two residents are like two accounts: one implementation, different data.
## Add a value here rather than a branch on who she is. Full field list: ../docs/INTERFACES.md section 13.
##   key         the VADS instance id
##   flavor      her name in the life rules
##   name, art   how she looks
##   start       where she stands if there is no save and VADS has no record of her
##   peer_name, favorite_foods, preferred_objects, care, wish_hints, own_wishes    what the life rules read
##   home        her poses at home; pieces: chair back, quilt, phone and headphones art

const DATA_FILE := "res://assets/residents.json"

static var _data := {}
static var _people := {}
static var _seats := {}
static var _loaded := false


static func _table() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_FILE))
	return _data


static func people() -> Array:
	return _table()["residents"]


## Her row, by VADS key.
static func person(key: String) -> Dictionary:
	for p in people():
		if p["key"] == key:
			return p
	return {}


## Her row, by the name the life rules use. Anyone else gets the "unknown" row.
static func flavor(who: String) -> Dictionary:
	for p in people():
		if p["flavor"] == who:
			return p
	return _table()["unknown"]


static func _file() -> String:
	return Economy.save_path.get_base_dir().path_join("residents.json")


static func saved(key: String) -> Dictionary:
	if not _loaded:
		_loaded = true
		var stored:Dictionary=load("res://core/safe_store.gd").read_document(_file(),valid_save,true)
		if stored.ok:
			_people=stored.data.get("people",{})
			_seats=stored.data.get("seats",{})
	var row = _people.get(key)
	if row is Dictionary and WorldData.scenes.has(str(row.get("scene", ""))) and WorldData.scenes.has(str(row.get("want_scene", ""))):
		return row
	return {}


static func seats() -> Dictionary:
	saved("")
	return _seats


static func remember(key: String, row: Dictionary) -> void:
	_people[key] = row
	save_now()


static func valid_save(data:Dictionary)->bool:
	if not data.get("people") is Dictionary or not data.get("seats",{}) is Dictionary:return false
	for row in data.people.values():
		if not row is Dictionary or not row.get("scene") is String or not row.get("want_scene") is String:return false
		for axis in ["x","y"]:
			if not (row.get(axis) is int or row.get(axis) is float) or not is_finite(float(row[axis])):return false
	return true

static func save_now() -> void:
	load("res://core/safe_store.gd").write_document(_file(),{"version":1,"people":_people,"seats":_seats},valid_save,true)
