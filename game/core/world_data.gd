extends Node
## The world's static facts: rooms, doors, spots, obstacles and character art.

## DATA: res://assets/world.json holds scenes and actors, and baked/<room>.layers.json holds each room's art.
## Field lists: ../docs/INTERFACES.md section 13.
const ORDER := ["qianxia-home", "qianxia-park", "qianxia-shop", "xiaojingyu-home", "world-arcade", "world-onsen", "world-restaurant"]
var SPACE_SCENE := {"home": "qianxia-home", "park": "qianxia-park", "shop": "qianxia-shop", "arcade": "world-arcade", "onsen": "world-onsen", "xjhome": "xiaojingyu-home", "restaurant": "world-restaurant"}

signal resident_registered(key: String)
signal resident_removed(key: String, scene: String)
signal resident_named(key: String)
var runtime_textures:Dictionary={}
var scenes := {}
var actors := {}
var objects: Array = []
var layers := {}
var _navs := {}


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world.json"))
	scenes = Features.scenes(data["scenes"]) ## a module switched off keeps its 1.0 scene (core/features.gd)
	actors = data["actors"]
	objects = data.get("objects", [])
	## Module switches (core/features.gd): the beach path and the second Tetris machine exist only with their module on.
	if not Features.on("seaside-path"):
		objects = objects.filter(func(o): return o.get("id") != "xj_beach")
		for s in scenes.values(): if s.get("zones") is Dictionary: s.zones.erase("xj_beach")
	if not Features.on("arcade-renovated"):
		objects = objects.filter(func(o): return o.get("id") != "arcade_blocks_2")
	for id in available_order():
		layers[id] = JSON.parse_string(FileAccess.get_file_as_string(Features.asset("baked/%s.layers.json" % id)))
	HomeGrid.initialize()


## Edition data selects rooms; controllers and body rules stay shared.
func available_order() -> Array:
	var ids: Array = ORDER.filter(func(id): return scenes.has(id))
	for id in scenes:
		if not ids.has(id): ids.append(id)
	return ids


func point(p) -> Vector2:
	return Vector2(p["x"], p["y"])


func scene_of_space(space: String) -> String:
	return SPACE_SCENE.get(space, "")


func nav(id: String) -> RoomNav:
	if not _navs.has(id):
		_navs[id] = RoomNav.new(scenes[id])
	return _navs[id]


func exit_to(id: String, to: String):
	for e in scenes[id]["exits"]:
		if e["to"] == to:
			return e
	return null


## The rooms to walk through, start and end included. Empty when there is no way.
func scene_path(from: String, to: String) -> Array:
	if from == to:
		return [from]
	var prev := {from: ""}
	var queue := [from]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		for e in scenes[current]["exits"]:
			var next: String = e["to"]
			if scenes.has(next) and not prev.has(next):
				prev[next] = current
				if next == to:
					var out := [to]
					var at := current
					while at != "":
						out.push_front(at)
						at = prev[at]
					return out
				queue.push_back(next)
	return []
