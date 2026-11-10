extends Node
## The world's static facts: rooms, doors, spots, obstacles and character art.

## DATA: res://assets/world.json holds scenes and actors, and baked/<room>.layers.json holds each room's art.
## Field lists: ../docs/INTERFACES.md section 13.
const ORDER := ["qianxia-home", "qianxia-park", "qianxia-shop", "xiaojingyu-home", "world-arcade", "world-onsen", "world-restaurant"]
const SPACE_SCENE := {"home": "qianxia-home", "park": "qianxia-park", "shop": "qianxia-shop", "arcade": "world-arcade", "onsen": "world-onsen", "xjhome": "xiaojingyu-home", "restaurant": "world-restaurant"}

var scenes := {}
var actors := {}
var objects: Array = []
var layers := {}
var _navs := {}


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world.json"))
	scenes = data["scenes"]
	actors = data["actors"]
	objects = data.get("objects", [])
	for id in available_order():
		layers[id] = JSON.parse_string(FileAccess.get_file_as_string("res://assets/baked/%s.layers.json" % id))
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
