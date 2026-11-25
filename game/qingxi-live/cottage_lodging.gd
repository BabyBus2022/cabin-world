extends RefCounted

const FILE = "cottage-lodging.json"
const UPPER = "room_private_up"
const DORM = "room_private_dorm"
static var profiles := {}

static func data(path: String) -> Dictionary:
	if not profiles.has(path):
		var state = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		profiles[path] = state if state is Dictionary else {}
	return profiles[path]

static func commit(path: String, state: Dictionary) -> bool:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(state))
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	if not ok or DirAccess.rename_absolute(temp,path) != OK: return false
	profiles[path] = state
	return true

static func beds(state: Dictionary) -> Array:
	var result := []
	for floor_id in [DORM, UPPER, "room_private"]:
		if floor_id == DORM and not state.get("expanded", false): continue
		var defaults := ["room_0","room_1","room_2"] if floor_id == DORM else (["room_0"] if floor_id == UPPER else [])
		for key in state.get("floors", {}).get(floor_id, defaults): result.append(floor_id + "/" + str(key))
	return result

static func sync_floor(path: String, floor_id: String, keys: Array) -> void:
	var current := data(path)
	if current.get("floors", {}).get(floor_id) == keys: return
	var state := current.duplicate(true)
	if not state.has("floors"): state.floors = {}
	state.floors[floor_id] = keys
	commit(path, state)

static func expand(path: String) -> bool:
	if data(path).get("expanded", false): return true
	var state := data(path).duplicate(true)
	state.expanded = true
	return commit(path, state)

static func claim(path: String, who: String, preferred := "") -> Dictionary:
	var state := data(path).duplicate(true)
	if not state.has("guests"): state.guests = {}
	var available := beds(state)
	if preferred != "" and not available.has(preferred): return {"error":"这张床已经移动或收起了。"}
	if state.guests.has(who): return {"bed":state.guests[who]} if preferred in ["",state.guests[who]] else {"error":"请先从原来的床起身。"}
	for key in available:
		if preferred != "" and preferred != key: continue
		if key in state.guests.values(): continue
		state.guests[who] = key
		return {"bed":key} if commit(path,state) else {"error":"床位未能保存，请重试。"}
	return {"error":"这张床有人了。"} if preferred != "" else {"error":"小屋里的床已满，可以在二楼扩建宿舍或添床。"}

static func wake(path: String, who: String) -> bool:
	if not data(path).get("guests", {}).has(who): return true
	var state := data(path).duplicate(true)
	state.guests.erase(who)
	return commit(path,state)

static func path_for(world) -> String:
	return world.qingxi_save_path("user://" + FILE)
