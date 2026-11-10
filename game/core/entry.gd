class_name Entry
extends RefCounted
## Who may enter where, and which way to walk. Same rules as canEnter and spaceRoute in VADS.
## Whether a host agrees to a visit is still asked in VADS; once they agree, the pass lives here.
##
## INTERFACE: entry messages. Full reference: ../docs/INTERFACES.md section 8.
##   entry.route   host -> game  id (required, unique), owner (required), from (required), to (required)
##   entry.result  game -> host  id, ok, route: space ids from start to end. Empty when she can't get there; just [from] when she is already there.
##   entry.pass    host -> game  owner, space, until (ms since 1970). Lets her into someone else's home until then.
##   entry.revoke  host -> game  owner, space
##
## DATA MAPPING: space ids are the ones in WorldData.SPACE_SCENE. Passes are kept in memory, as in VADS; the host sends them again when the link opens.

## links: the doors, in the order they are tried. owner: only she may enter without a pass.
const SPACES := {
	"home": {"links": ["park"], "owner": "Final01"},
	"park": {"links": ["home", "shop", "xjhome", "arcade", "restaurant"], "owner": ""},
	"xjhome": {"links": ["park"], "owner": "xiaojingyu"},
	"shop": {"links": ["park", "onsen"], "owner": ""},
	"arcade": {"links": ["park"], "owner": ""},
	"onsen": {"links": ["shop"], "owner": ""},
	"restaurant": {"links": ["park"], "owner": ""},
}

static var _passes := {}

static func view(owner: String) -> Dictionary:
	var routes := {}
	var allowed := {}
	for origin in SPACES:
		routes[origin] = {}
		allowed[origin] = can_enter(origin,owner)
		for destination in SPACES: routes[origin][destination] = route(origin,destination,owner)
	return {"owner":owner,"routes":routes,"allowed":allowed}


static func has_pass(owner: String, space: String) -> bool:
	return float(_passes.get(owner + "|" + space, 0)) > SharedFeed.now_ms()


static func can_enter(space: String, owner: String) -> bool:
	if not SPACES.has(space) or not WorldData.scenes.has(WorldData.scene_of_space(space)):
		return false
	var who: String = SPACES[space]["owner"]
	return who == "" or who == owner or has_pass(owner, space)


## Spaces to walk through, start and end included. Empty when there is no way.
static func route(from: String, to: String, owner: String) -> Array:
	if not WorldData.scenes.has(WorldData.scene_of_space(to)): return []
	if from == to:
		return [from]
	if not can_enter(to, owner):
		return []
	var prev := {from: ""}
	var queue := [from]
	while not queue.is_empty():
		var s: String = queue.pop_front()
		var links: Array = SPACES[s]["links"] if SPACES.has(s) else []
		for n in links:
			if not prev.has(n) and can_enter(n, owner):
				prev[n] = s
				if n == to:
					var path := [n]
					var p := s
					while p != "":
						path.push_front(p)
						p = prev[p]
					return path
				queue.push_back(n)
	return []


static func handle(frame: Dictionary) -> void:
	var owner := str(frame.get("owner", ""))
	var space := str(frame.get("space", ""))
	match frame.get("type"):
		"entry.route":
			VadsLink.send({"type": "entry.result", "id": frame.get("id"), "ok": true, "view":view(owner), "route": route(str(frame.get("from", "")), str(frame.get("to", "")), owner)})
		"entry.pass":
			_passes[owner + "|" + space] = float(frame.get("until", 0))
		"entry.revoke":
			_passes.erase(owner + "|" + space)
	if frame.get("type") in ["entry.pass","entry.revoke"]:
		VadsLink.send({"type":"entry.result","ok":true,"view":view(owner)})
