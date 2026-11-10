class_name Character
extends Node2D
## One resident of the world. Walks on a fixed tick through a small state machine, door to door, never jumping.

signal room_changed(character: Character)

enum State { IDLE, WALK, RUN, ASLEEP, DOING }

const WALK_CYCLE := [1, 2, 3, 2]
const RUN_FROM := 230.0
const Crowd = preload("res://core/crowd.gd")
var replan_in := 0.0
var blocked_for := 0.0
const ORDER_LOCK := 3.0
## With no save, how long to wait for a last known place before standing at her starting spot.
const START_WAIT := 2.0
const MOOD_SECONDS := 3.0
const MOOD_CELLS := {"😄": 0, "🙂": 1, "😌": 2, "🍃": 3, "🌧️": 4, "🥺": 5, "😑": 6, "😔": 7, "😣": 8, "🥱": 9, "💤": 10, "😊": 11, "😎": 12, "🥰": 13, "🎁": 14}
## Phases of an action that have a pose: which row of her actions sheet.
const PHASE_POSES := {"pick": 2, "pay_wait": 3, "pay": 3, "settle": 3}
## How fast she shifts from a spot to a seat, in room units a second.
const SEAT_SPEED := 110.0
## The bed, as the room is laid out.

var resident_actor := true
var key := ""
## Her poses at home and the art drawn with them, from residents.json.
var _home := {}
var _pieces := {}
var display_name := ""
var art := ""
var neighbours: Array = []
var state := State.IDLE
var placed := false
var scene_id := ""
var feet := Vector2.ZERO
var target := Vector2.ZERO
var route: Array[Vector2] = []
var velocity := 0.0
var row := 0

# What the world says about her right now.
var want_scene := ""
var want_zone := ""
var next_scene := ""
var sleeping := false
var robe := false
var place := ""
var label := ""
var action_phase := ""
var action_label := ""
var action_pose := -1
var effect := {}
var restaurant_owner := ""
var restaurant_effect := {}
var _meal_sprite := Sprite2D.new()
func _notification(what:int):
	if what==NOTIFICATION_PREDELETE and is_instance_valid(_meal_sprite) and _meal_sprite.get_parent()==null:_meal_sprite.free()
var gift_visual := {}
var gift_at := 0.0
var _gift_draw := false
var action := ""
var body := {}
## What she looks like when she isn't walking: see _stage_now.
var stage := {}
var _display := Vector2.ZERO
var _upper := Sprite2D.new()
var _front := Sprite2D.new()
var _phones := Sprite2D.new()
var _phone := Sprite2D.new()
var coins = null
var mood_word := ""
var mood_icon := ""
var _mood_until := 0.0
var _overlay := Node2D.new()
var _mood_tex: Texture2D

# A walk the host is waiting on. While one is active, or just after, late presence rows don't redirect her.
var order_id := ""
var _restored := false
var _unplaced_for := 0.0
var _order_lock := 0.0

var _sprite := Sprite2D.new()
var _time := 0.0
var _visual_head := Rect2(-17,-60,34,29)
var _was_moving := false
var _hop_start := -1.0
var _dust_at := -1.0
var _dust: Array = []
var _paint_start := -1.0
var _walk_tex: Texture2D
var _robe_tex: Texture2D
var _walk: Dictionary
var _robe: Dictionary
var _actions: Dictionary
var _actions_tex: Texture2D


func setup(p_key: String, p_name: String, p_art: String) -> void:
	key = p_key
	Economy.gift_changed.connect(func(record):
		if key in [record.from, record.to]: gift_event(record))
	add_to_group("world_residents" if resident_actor else "world_npcs")
	display_name = p_name
	art = p_art
	_home = Residents.person(key).get("home", {})
	_pieces = Residents.person(key).get("pieces", {})
	if art == "":
		# Own the same presentation nodes even without textures; removing a test
		# body must free every node, just as removing a skinned resident does.
		for visual in [_sprite,_upper,_front,_phones,_phone,_overlay]:
			visual.visible = false
			add_child(visual)
		return
	_walk = WorldData.actors[art]["walk"]
	_robe = WorldData.actors[art]["yukata"]
	_walk_tex = load("res://assets/actors/" + _walk["file"])
	_robe_tex = load("res://assets/actors/" + _robe["file"])
	_actions = WorldData.actors[art]["actions"]
	_actions_tex = load("res://assets/actors/" + _actions["file"])
	_sprite.region_enabled = true
	_sprite.centered = false
	add_child(_sprite)
	add_child(_meal_sprite);_meal_sprite.visible=false
	for extra in [_upper, _front, _phones, _phone]:
		extra.region_enabled = true
		extra.centered = false
		extra.visible = false
		add_child(extra)
	_mood_tex = load("res://assets/actors/mood-icons.png")
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


## She exists from the moment the game starts, where she was last.
func wake() -> void:
	var row := Residents.saved(key)
	if row.is_empty():
		return
	_restored = true
	scene_id = str(row["scene"])
	want_scene = str(row["want_scene"])
	want_zone = str(row.get("want_zone", ""))
	next_scene = str(row.get("next", ""))
	feet = Vector2(float(row.get("x", 0)), float(row.get("y", 0)))
	var layout_revision:String=WorldData.scenes[scene_id].get("layoutRevision","")
	if layout_revision!="" and row.get("layout_revision","")!=layout_revision:
		# On a changed house layout, preserve the named destination, not obsolete pixels inside a wall.
		var zones:Dictionary=WorldData.scenes[scene_id].zones
		feet=WorldData.point(zones[want_zone]) if zones.has(want_zone) else WorldData.point(WorldData.scenes[scene_id].entries.door)
	target = feet
	position = feet
	_display = feet
	placed = true
	room_changed.emit(self)


func _remember() -> void:
	Residents.remember(key, {"scene": scene_id, "x": feet.x, "y": feet.y, "want_scene": want_scene, "want_zone": want_zone, "next": next_scene,"layout_revision":WorldData.scenes.get(scene_id,{}).get("layoutRevision","")})


## INTERFACE: walk.position to the host. Full reference: ../docs/INTERFACES.md section 8.
##   actor, scene (both required), zone, x, y. Where she really is; VADS keeps this as its copy.
func rebase_layout(previous:Dictionary) -> void:
	if not placed:return
	var scene:Dictionary=WorldData.scenes[scene_id]
	var old_zone:Dictionary=previous.zones.get(want_zone,{})
	if not old_zone.is_empty() and scene.zones.has(want_zone) and feet.distance_to(WorldData.point(old_zone))<16:
		feet=WorldData.point(scene.zones[want_zone])
	elif not WorldData.nav(scene_id).walkable(feet):
		feet=WorldData.point(scene.entries.door)
	route.clear();target=feet;state=State.IDLE;velocity=0
	stage={};_display=feet;position=feet
	_choose_destination()
	_remember();report_position()

func report_position() -> void:
	if placed:
		var actual_zone:=""
		var nearest:=INF
		for id in WorldData.scenes[scene_id].zones:
			var distance:=feet.distance_to(WorldData.point(WorldData.scenes[scene_id].zones[id]))
			# A machine and its seat can share a point. Keep the confirmed seat
			# on an equal-distance tie; otherwise a position heartbeat fabricates a departure.
			var confirmed_tie:bool=not is_walking() and scene_id==want_scene and id==want_zone and absf(distance-nearest)<0.01
			if distance<nearest or confirmed_tie:nearest=distance;actual_zone=id
		VadsLink.send({"type": "walk.position", "actor": key, "scene": scene_id, "zone": actual_zone, "x": feet.x, "y": feet.y, "walking":is_walking(), "targetScene":want_scene, "targetZone":want_zone})


func portrait_frame() -> Dictionary:
	return {"texture": _walk_tex, "rect": _walk["rects"][0], "anchor": _walk["anchors"][0]}


func set_action(phase: String, text: String, pose := -1) -> void:
	action_phase = phase
	action_label = text
	action_pose = pose


func has_pose() -> bool:
	return action_pose >= 0 or PHASE_POSES.has(action_phase) or is_fishing()


## Poked: shows how she feels for a moment.
func poke() -> void:
	_mood_until = _time + MOOD_SECONDS


func _effect_seconds() -> float:
	return (SharedFeed.now_ms() - float(effect.get("at", 0))) / 1000.0


func is_fishing() -> bool:
	if effect.get("kind") != "fishing" or is_walking():
		return false
	return _effect_seconds() < float(effect.get("seconds", 0))


## Where she sits at the end of the pier, easing there from her spot.
func _fishing_seat() -> Vector2:
	var m: Dictionary = WorldData.scenes[scene_id]["modules"].get(str(effect.get("module", "")), {})
	if m.is_empty():
		return Vector2.ZERO
	var seat := Vector2(float(m["x"]) + float(m["w"]) - 18.0, float(m["y"]) + float(m["h"]) * 0.62) - feet
	var p := clampf(_effect_seconds() / 1.2, 0.0, 1.0)
	return feet + seat * (p * p * (3.0 - 2.0 * p)) - _display


## INTERFACE: walk.go from the host. Full reference: ../docs/INTERFACES.md section 8.
##   id, actor (both required), scene (required), zone (optional), next (optional: walk to the door towards this room)
## Answers walk.arrived: id, scene, x, y, plus replaced when a newer order took over.
func walk_order(frame: Dictionary) -> void:
	if frame.get("type","")=="walk.cancel":
		if str(frame.get("id",""))==order_id:
			order_id="";route.clear();state=State.IDLE;want_scene=scene_id;want_zone="";next_scene="";target=feet;_remember();report_position()
		return
	if str(frame.get("restaurantOwner",""))!=restaurant_owner:
		restaurant_owner="";restaurant_effect={}
	if order_id != "":
		VadsLink.send({"type": "walk.arrived", "id": order_id, "replaced": true})
	order_id = str(frame.get("id", ""))
	want_scene = str(frame.get("scene", ""))
	want_zone = str(frame.get("zone", ""))
	next_scene = str(nz(frame.get("next"), ""))
	_order_lock = ORDER_LOCK
	_remember()


static func nz(v, d):
	return d if v == null else v


## INTERFACE: one presence row from the host. Full reference: ../docs/INTERFACES.md section 4.
##   sceneId or space -> want_scene    zone -> want_zone    place, label -> card text
##   sleeping -> State.ASLEEP          outfit "yukata" -> robe sprites
##   travel: next, or route with to -> next_scene
##   action -> what she does at her spot    items (Xiaojingyu) or view { items, computer, bed } (Qianxia) -> body
func apply_presence(p: Dictionary) -> void:
	action = str(p.get("action", ""))
	var seen = p.get("view")
	body = seen if seen is Dictionary else {}
	if p.get("items") is Dictionary:
		body["items"] = p["items"]
	var fx = p.get("effect")
	effect = fx if fx is Dictionary else {}
	coins = p.get("coins")
	var feeling = p.get("mood")
	mood_word = str(feeling.get("word", "")) if feeling is Dictionary else ""
	mood_icon = str(feeling.get("icon", "")) if feeling is Dictionary else ""
	# Where she is belongs to the game once VADS has agreed, and to the save until VADS has spoken.
	var ordered := order_id != "" or _order_lock > 0.0 or VadsLink.owns_bodies or (_restored and not VadsLink.connected)
	if not ordered:
		want_scene = str(p.get("sceneId", WorldData.scene_of_space(str(p.get("space", "")))))
		want_zone = str(p.get("zone", ""))
	place = str(p.get("place", ""))
	label = str(p.get("label", "")) if p.get("label") != null else ""
	sleeping = p.get("sleeping") == true
	robe = p.get("outfit") == "yukata"
	if ordered:
		return
	next_scene = ""
	var travel = p.get("travel")
	if travel is Dictionary:
		next_scene = WorldData.scene_of_space(str(travel.get("next", "")))
		var r = travel.get("route")
		if next_scene == "" and r is Array:
			var at: int = r.find(travel.get("to"))
			if at >= 0 and at + 1 < r.size():
				next_scene = WorldData.scene_of_space(str(r[at + 1]))


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if not placed:
		_unplaced_for += delta
		_place_first()
		return
	_order_lock = maxf(0.0, _order_lock - delta)
	var previous_scene := scene_id
	_choose_destination()
	# Entering a room resets the movement state. It is not yet arrival at the
	# requested spot (or the onward exit for a multi-room trip).
	if scene_id != previous_scene and scene_id == want_scene:
		_choose_destination()
	_move(delta)
	if order_id != "" and scene_id == want_scene and not is_walking() and feet.distance_to(target)<=Crowd.GAP+1:
		VadsLink.send({"type": "walk.arrived", "id": order_id, "actor":key, "scene": scene_id, "zone":want_zone, "x": feet.x, "y": feet.y})
		order_id = ""
		_order_lock = ORDER_LOCK
		_remember()
		report_position()
	if VadsLink.body_persistence:
		var saved: Dictionary = VadsLink.BodySave.people.get(key,{})
		if saved.has("outfit"):
			robe = scene_id=="world-onsen" and saved.outfit=="yukata"
	if VadsLink.body_persistence and Body.known(key) and not Body.of(key).simple_rest.is_empty():
		sleeping = Body.of(key).bed_snapshot(SharedFeed.now_ms()).asleep and scene_id == Residents.person(key).get("home", {}).get("scene", "")
	if is_walking():
		pass
	elif sleeping:
		state = State.ASLEEP
	elif has_pose() and not robe:
		state = State.DOING
	else:
		state = State.IDLE
	if Body.known(key):
		body.merge(Body.of(key).view(SharedFeed.now_ms()), true)
	stage = _stage_now() if not is_walking() and scene_id == want_scene and scene_id != "" else {}
	if not is_walking():
		_display = stage.get("feet",feet) if stage.get("snap",false) else _display.move_toward(stage.get("feet", feet), SEAT_SPEED * clampf(delta, 0.0, 0.05))
	position = Vector2(_display.x, float(stage.get("sort", _display.y)))


func is_walking() -> bool:
	return state == State.WALK or state == State.RUN


func _process(delta: float) -> void:
	_time += delta
	_update_sprite()
	var restaurant_scale:float=WorldData.scenes.get(scene_id,{}).get("actorScale",1.0)
	if restaurant_scale!=1.0:
		var shift:=Vector2(0,_display.y-position.y)
		for part in [_sprite,_upper,_front,_phones,_phone,_meal_sprite]:
			if part.visible:
				part.scale*=restaurant_scale;part.position=shift+(part.position-shift)*restaurant_scale
		_visual_head=Rect2(_visual_head.position*restaurant_scale,_visual_head.size*restaurant_scale)
	if not resident_actor: return
	if _was_moving and not is_walking() and state!=State.ASLEEP: _hop_start=_time
	_was_moving=is_walking()
	var hop := (_time-_hop_start)/.38
	if _hop_start>=0 and hop>=0 and hop<1 and state!=State.ASLEEP and not stage.get("seat",false) and not stage.get("snap",false) and not stage.has("crop"):
		var bob := -floorf(sin(hop*PI)*3+.5)
		for part in [_sprite,_upper,_phone,_phones]: part.position.y+=bob
		_visual_head.position.y+=bob
	if state==State.RUN and _time-_dust_at>.11:
		_dust_at=_time
		_dust.append({"x":feet.x-(-1 if row==1 else 1)*6,"y":feet.y-1,"at":_time*1000,"scene":scene_id})
	_dust=_dust.filter(func(d):return _time*1000-d.at<520 and d.scene==scene_id)


func _items() -> Dictionary:
	var it = body.get("items")
	if not it is Dictionary:return {}
	if _home.get("audioOutput","")=="speakers":
		var view:Dictionary=it.duplicate(true)
		view.headphones="dock"
		if view.get("transfer") is Dictionary and view.transfer.get("item")=="headphones":view.transfer=null
		return view
	return it


func _effect_active() -> String:
	return str(effect.get("kind", "")) if _effect_seconds() < float(effect.get("seconds", 0)) else ""


## Where she is and how she looks once she has arrived. Same rules as the VADS page.
##   feet    where she really is
##   sort    depth line in the room, so furniture covers what it should
##   pose    a Poses name (Qianxia at home), or
##   row     a row of her actions sheet, with seat true when she sits; dir is a walk sheet row otherwise
##   front   what is drawn over her: "chair" or "quilt"
func _stage_now() -> Dictionary:
	var legacy:=_legacy_stage()
	if robe:return legacy
	var fx:Dictionary=restaurant_effect if restaurant_owner!="" else effect
	var seconds:float=(SharedFeed.now_ms()-float(fx.get("at",0)))/1000.0
	var sitting:Dictionary=load("res://entities/sit_presentation.gd").resolve(art,scene_id,want_zone,fx,seconds,action,body,legacy)
	return load("res://entities/restaurant_pose.gd").resolve(art,scene_id,want_zone,fx,seconds,sitting)

func _legacy_stage() -> Dictionary:
	var outdoor := WorldPresentation.moment(scene_id,want_zone,effect,_effect_seconds(),_time)
	if not outdoor.is_empty(): return outdoor
	if robe or scene_id != str(_home.get("scene", "")):
		return {}
	var bed := _stage_bed()
	return bed if not bed.is_empty() else _stage_activity()


func _height() -> float:
	return float(WorldData.scenes[scene_id]["height"])


func _bed_rect() -> Rect2:
	for m in WorldPresentation.facts().scenes.get(scene_id,{}).get("modules",{}).values():
		if m.get("kind")=="bed":return Rect2(m.x,m.y,m.w,m.h)
	return Rect2()

func _stage_bed() -> Dictionary:
	var bed: Dictionary = _home["bed"]
	if bed["mode"] == "staged":
		var state_of = body.get("bed")
		if not state_of is Dictionary or state_of.get("occupied") != true or want_zone != bed["zone"]:
			return {}
		var phase := str(state_of.get("phase", ""))
		var out := WorldPresentation.bed(scene_id,state_of)
		out.merge({"sort":_height()+1.0,"asleep":state_of.get("asleep")==true})
		if not phase in bed["no_quilt"]:
			out["front"] = "quilt"
			out["quilt_top"] = _bed_rect().position.y + float(bed["covered_top"] if state_of.get("covered") == true else bed["open_top"])
		return out
	var active := _effect_active()
	if not sleeping and not active in bed["effects"]:
		return {}
	return {"feet": _point(bed["lying"]), "sort": _height() + 1.0, "dir": 0, "front": "quilt", "quilt_top": _bed_rect().position.y + float(bed["quilt_top"]), "clip": _bed_rect().position.y + float(bed["clip"]), "asleep": sleeping or active in bed["asleep_effects"]}


func _point(p: Array) -> Vector2:
	return Vector2(float(p[0]), float(p[1]))


func _stage_activity() -> Dictionary:
	var active := _effect_active()
	for row in _home["stages"]:
		if row.has("zone") and row["zone"] != want_zone:
			continue
		if row.has("actions") and not action in row["actions"]:
			continue
		if row.has("effect") and row["effect"] != active:
			continue
		if row.has("effect_kind") and row["effect_kind"] != effect.get("kind"):
			continue
		if row.has("needs") and not _body_says(str(row["needs"])):
			continue
		return _stage_from(row)
	var idle: Dictionary = _home["idle"].duplicate()
	var items := _items()
	if idle.has("phone_pose") and items.get("phone") == "hand" and not _transferring("phone"):
		idle["pose"] = idle["phone_pose"]
	elif idle.has("listen_pose") and items.get("headphones") == "worn" and not _transferring("headphones") and items.get("audio") == "playing":
		idle["pose"] = idle["listen_pose"]
	return _stage_from(idle)


## "computer.chairOccupied" is true in her body data.
func _body_says(path: String) -> bool:
	var parts := path.split(".")
	var part = body.get(parts[0])
	return part is Dictionary and part.get(parts[1]) == true


func _stage_from(row: Dictionary) -> Dictionary:
	var out := row.duplicate()
	out["feet"] = _point(row["feet"]) if row.has("feet") else _spot_here()
	if not row.has("sort"):
		out["sort"] = out["feet"].y
	return out


func _spot_here() -> Vector2:
	var zones: Dictionary = WorldData.scenes[scene_id]["zones"]
	return _spot_for(WorldData.point(zones[want_zone])) if zones.has(want_zone) else feet


func _place_first() -> void:
	if not WorldData.scenes.has(want_scene):
		if not VadsLink.owns_bodies and _unplaced_for < START_WAIT:
			return
		var start: Array = Residents.person(key)["start"]
		want_scene = start[0]
		want_zone = start[1]
	scene_id = want_scene
	var zones: Dictionary = WorldData.scenes[scene_id]["zones"]
	var s: Dictionary = WorldData.scenes[scene_id]
	feet = WorldData.point(zones[want_zone]) if zones.has(want_zone) else Vector2(s["width"], s["height"]) / 2.0
	target = feet
	position = feet
	stage = _stage_now()
	_display = stage.get("feet", feet)
	placed = true
	room_changed.emit(self)
	_remember()
	report_position()


func _choose_destination() -> void:
	if not WorldData.scenes.has(want_scene):
		return
	if scene_id != want_scene:
		var path := WorldData.scene_path(scene_id, want_scene)
		var door = WorldData.exit_to(scene_id, path[1]) if path.size() > 1 else null
		if door == null:
			if order_id!="":VadsLink.send({"type":"walk.arrived","id":order_id,"actor":key,"failed":true,"error":"没有连通的地图出口","scene":scene_id,"x":feet.x,"y":feet.y})
			order_id="";want_scene=scene_id;want_zone="";next_scene="";route.clear();state=State.IDLE;target=feet
			return
		var threshold := WorldData.point(door)
		# A doorway has room to pass within one body clearance. Requiring both
		# feet to touch its centre makes each person's clearance block the other.
		if feet.distance_to(threshold) <= Crowd.GAP and WorldData.nav(scene_id).clear_line(feet, threshold):
			_enter(path[1], door["entry"])
			return
		go(threshold)
		if not is_walking():
			_enter(path[1], door["entry"])
		return
	if next_scene != "":
		var door = WorldData.exit_to(scene_id, next_scene)
		if door != null:
			var threshold := WorldData.point(door)
			# Staging is arrival in the doorway, not ownership of its exact centre.
			# The host then issues the crossing order. Use the same body clearance.
			if feet.distance_to(threshold) <= Crowd.GAP and WorldData.nav(scene_id).clear_line(feet,threshold):
				target=threshold
				route.clear()
				state = State.IDLE
				velocity = 0
			else:
				go(threshold)
			return
	var zones: Dictionary = WorldData.scenes[scene_id]["zones"]
	if zones.has(want_zone):
		go(_spot_for(WorldData.point(zones[want_zone])))


func _nearby() -> Array:
	return neighbours.filter(func(c): return c != self and c.placed and c.scene_id == scene_id)


var _spot_memo := ""
var _spot_memo_value := Vector2.ZERO
func _spot_for(spot: Vector2) -> Vector2:
	var others := []
	for c in _nearby():
		if c.want_zone == want_zone and c.want_scene == want_scene:
			if not c.is_walking():
				# Already standing (arrived beside the shared spot): solid for everyone, whatever the name order.
				# Ignoring her made the next arrival choose the exact place she stands and edge there forever.
				others.append(c.feet)
			elif c.feet.distance_to(spot)<Crowd.GAP and (feet.distance_to(spot)>=Crowd.GAP or key>c.key):
				others.append(c.feet)
			elif feet.distance_to(spot)>=Crowd.GAP and c.feet.distance_to(spot)>=Crowd.GAP and key>c.key:
				others.append(spot) # reserve the centre when both are still approaching
		else:
			others.append(c.feet)
	# A clear centre can still be unreachable behind a standing resident.
	if is_walking() and target.distance_to(spot)<=88 and Crowd.clear(target,others,Crowd.GAP+Crowd.SPOT_MARGIN):return target
	if feet.distance_to(spot)<=88 and Crowd.clear(feet,others):
		if target.distance_to(feet)<1:return feet
	if others.is_empty():return spot
	# Building a crowd navigation grid costs ~10-50 ms. This runs every tick while someone stands near her spot, so
	# reuse the answer while the spot, her rough position and everyone's rough positions are unchanged.
	var memo := str(scene_id, spot.round(), feet.snapped(Vector2(8,8)), others.map(func(o): return o.snapped(Vector2(4,4))))
	if memo == _spot_memo:return _spot_memo_value
	var p = Crowd.standing(Crowd.navigation(WorldData.scenes[scene_id],others,feet), spot, others, feet)
	_spot_memo = memo;_spot_memo_value = p if p != null else spot
	return _spot_memo_value


func go(to: Vector2) -> void:
	if target.distance_to(to) < 0.01 and (is_walking() or feet.distance_to(to) < 1.0):
		return
	target = to
	route = WorldData.nav(scene_id).route(feet, to)
	if route.is_empty():
		route = [to] as Array[Vector2] # at worst she walks straight there; she never jumps
	var length := 0.0
	var at := feet
	for q in route:
		length += at.distance_to(q)
		at = q
	state = State.RUN if length >= RUN_FROM else State.WALK


func _move(delta: float) -> void:
	if not is_walking():
		velocity = 0.0
		return
	# Up off the seat first; she doesn't walk through the furniture she was sitting at.
	if _display.distance_to(feet) > 0.5:
		_display = _display.move_toward(feet, SEAT_SPEED * clampf(delta, 0.0, 0.05))
		velocity = 0.0
		return
	var s: Dictionary = WorldData.scenes[scene_id]
	var want: float = s["run"] if state == State.RUN else s["speed"]
	delta = clampf(delta, 0.0, 0.05)
	velocity = minf(want, velocity + want * delta * 4.0) if velocity < want else maxf(want, velocity - float(s["run"]) * delta * 3.0)
	var nearby := _nearby()
	var people := nearby.map(func(c): return c.feet)
	replan_in = maxf(0.0, replan_in-delta)
	if replan_in<=0 and nearby.any(func(c): return (key>c.key or not c.is_walking()) and feet.distance_to(c.feet)<85):
		var crowd_nav := Crowd.navigation(s,people,feet) # one grid for both the standing spot and the detour
		var alternative = Crowd.standing(crowd_nav,target,people,feet)
		if alternative!=null:
			var detour := crowd_nav.route(feet,alternative)
			if not detour.is_empty():
				target=alternative
				route=detour
		replan_in=.6
	var original := route.duplicate() if not people.is_empty() else []
	var budget := velocity * delta
	var before := feet
	while not route.is_empty() and budget > 0.0:
		var q: Vector2 = route[0]
		var d := feet.distance_to(q)
		if d <= budget:
			feet = q
			budget -= d
			route.remove_at(0)
		else:
			feet = feet.move_toward(q, budget)
			budget = 0.0
	for p in people:
		# Block only a step that walks INTO someone. When the two already overlap (restored or arrived on the same
		# spot) any step is allowed, so they can separate instead of freezing and giving up the walk after 2.5 s.
		if before.distance_to(p)<Crowd.GAP*0.5: continue
		if feet.distance_to(p)<Crowd.GAP and feet.distance_to(p)<=before.distance_to(p):
			feet=before
			route.assign(original)
			velocity=0
			blocked_for+=delta
			if blocked_for>2.5:
				blocked_for=0
				if order_id=="" and want_scene==scene_id and next_scene=="": route.clear()
				elif want_scene==scene_id and feet.distance_to(target)<=72.0:
					# Someone is standing on her spot: stop beside them and count the walk as arrived,
					# instead of "walking" in place forever with the order never finishing.
					target=feet;route.clear()
				else:
					_spot_memo="" # re-pick a free spot on the next tick
			break
	if feet!=before: blocked_for=0
	var moved := feet - before
	if absf(moved.x) + absf(moved.y) > 0.001:
		row = (3 if moved.y < 0 else 0) if absf(moved.y) > absf(moved.x) else (1 if moved.x < 0 else 2)
	_display = feet
	if route.is_empty():
		state = State.IDLE
		velocity = 0.0


func _enter(to: String, entry: String) -> void:
	if not Economy.Social.entry_allowed(key, to):
		var denied := order_id
		order_id = ""
		want_scene = scene_id
		var zones: Dictionary = WorldData.scenes[scene_id].zones
		var closest := INF
		for zone in zones:
			var distance := feet.distance_to(WorldData.point(zones[zone]))
			if distance < closest:
				closest = distance
				want_zone = zone
		next_scene = ""
		route.clear()
		_remember()
		VadsLink.send({"type":"walk.arrived","id":denied,"denied":true,"scene":scene_id,"zone":want_zone})
		report_position()
		return
	Economy.Social.departed(key, scene_id)
	scene_id = to
	var entries: Dictionary = WorldData.scenes[to]["entries"]
	if entries.has(entry):
		feet = WorldData.point(entries[entry])
		# Two residents coming through the same door used to land on the identical point and then walk stacked.
		# Step in beside whoever is already standing in the doorway (same rule as choosing a standing spot).
		var here := _nearby().map(func(c): return c.feet)
		if not Crowd.clear(feet, here):
			var beside = Crowd.standing(WorldData.nav(to), feet, here)
			if beside != null: feet = beside
	target = feet
	position = feet
	_display = feet
	stage = {}
	route.clear()
	state = State.IDLE
	room_changed.emit(self)
	_remember()
	report_position()


func _arrive_directly() -> void:
	scene_id = want_scene
	var zones: Dictionary = WorldData.scenes[scene_id]["zones"]
	if zones.has(want_zone):
		feet = WorldData.point(zones[want_zone])
	target = feet
	position = feet
	_display = feet
	stage = {}
	route.clear()
	state = State.IDLE
	room_changed.emit(self)
	_remember()


func _update_sprite() -> void:
	_meal_sprite.visible=false
	_visual_head=Rect2(-17,-52 if stage.get("seat",false) else -60,34,29)
	if art == "":
		queue_redraw()
		return
	var shift := Vector2(0, _display.y - position.y)
	_overlay.position = shift
	_sprite.visible = placed and (state != State.ASLEEP or not stage.is_empty())
	if stage.get("hidden",false) and not is_walking(): _sprite.visible = false
	_upper.visible = false
	_front.visible = false
	_phones.visible = false
	_phone.visible = false
	queue_redraw()
	_overlay.queue_redraw()
	if not _sprite.visible:
		return
	_gift_draw = false
	if _show_gift(shift): return
	if state == State.DOING and has_pose() and stage.is_empty(): # the action can end between the tick and this draw
		_show_pose()
		_sprite.position += shift
		return
	_sprite.position = shift
	var still := not is_walking()
	var kind:String=restaurant_effect.get("kind","") if restaurant_owner!="" else ""
	if kind in ["restaurant_carry","restaurant_place"]:
		var rig=load("res://entities/restaurant_pose.gd")
		var facing:String=["south","west","east","north"][row] if kind=="restaurant_carry" else restaurant_effect.get("facing","north")
		var pose:Dictionary=rig.sample(art,"carry" if kind=="restaurant_carry" else "place",facing,_time)
		if not pose.is_empty():
			_body_sprite(rig.texture(pose.sheet),pose.region,pose.anchor,pose.scale,shift,0)
			_show_carried_meal(facing,shift)
			return
	if still and stage.has("restaurant_pose"):
		var sample:Dictionary=stage.restaurant_pose
		var rig=load("res://entities/restaurant_pose.gd")
		_upper.z_index=0;_front.z_index=0
		_body_sprite(rig.texture(sample.sheet),sample.region,sample.anchor,sample.scale,shift,0.0)
		_visual_head=Rect2(-17,-48 if stage.get("seat",false) else -60,34,29)
		_accessories(shift,_visual_head,"restaurant_"+sample.action)
		return
	if still and stage.get("asleep",false) and not _home.get("bed",{}).get("sleep_visual",{}).is_empty():
		_show_sleep_pose()
		return
	if still and stage.has("sit_idle"):
		_show_shared_sit(shift)
		return
	if still and stage.get("registered","")=="computer":
		_show_registered_computer()
		return
	_upper.z_index=0;_front.z_index=0
	if still and robe and stage.has("robe_row"):
		var index := int(stage.robe_row)*4+int(floorf(_time*2))%4
		var cell: float = _robe.cell
		_body_sprite(_robe_tex,Rect2((index%4)*cell,int(index/4)*cell,cell,cell),_point(_robe.anchors[index]),float(_robe.scale)*(-1 if stage.get("flip",false) else 1),shift,0)
		return
	if still and stage.has("pose"):
		_show_stage_pose(shift)
		return
	if still and stage.has("row") and not robe:
		_show_stage_row(shift)
		return
	if still and not robe:
		_show_standing(shift)
		return
	var walking := is_walking()
	var frame := 0
	if walking:
		var step := int(floor(_time * 7.0)) % 4
		frame = step if robe else WALK_CYCLE[step]
	var index := (row if walking else 0) * 4 + frame
	var source: Dictionary = _robe if robe else _walk
	_sprite.texture = _robe_tex if robe else _walk_tex
	var scale_of: float = source["scale"]
	if robe:
		var cell: float = source["cell"]
		_sprite.region_rect = Rect2((index % 4) * cell, (index / 4) * cell, cell, cell)
	else:
		var r: Array = source["rects"][index]
		_sprite.region_rect = Rect2(r[0], r[1], r[2], r[3])
	var anchor: Array = source["anchors"][index]
	_sprite.scale = Vector2(scale_of, scale_of)
	_sprite.offset = Vector2(-float(anchor[0]), -float(anchor[1]))


func _show_carried_meal(facing:String,shift:Vector2):
	if facing=="north":return # Tray is correctly occluded by the body from behind.
	if _meal_sprite.get_parent()==null:add_child(_meal_sprite)
	var rig=load("res://entities/restaurant_pose.gd")
	var menu:Dictionary=rig.menu_data()
	var found:Array=menu.dishes.filter(func(d):return d.id==restaurant_effect.get("dish",""))
	if found.is_empty():return
	var r:Array=found[0].region
	_meal_sprite.texture=rig.texture(menu.sheet);_meal_sprite.region_enabled=true;_meal_sprite.region_rect=Rect2(r[0],r[1],r[2],r[3])
	_meal_sprite.scale=Vector2(18/r[2],10/r[3]);_meal_sprite.position=shift+Vector2(-17 if facing=="west" else 17 if facing=="east" else 0,-23)
	_meal_sprite.z_index=1;_meal_sprite.visible=true

func _show_sleep_pose() -> void:
	var spec:Dictionary=_home.bed.sleep_visual
	var tex:Texture2D=Poses.texture(spec.sheet)
	var bed:=_bed_rect()
	var r:Array=spec.at_ratio
	var breathe:=sin(_time*1.1)*0.25
	var at:=Rect2(bed.position+Vector2(bed.size.x*r[0],bed.size.y*r[1]+breathe)-position,Vector2(bed.size.x*r[2],bed.size.y*r[3]))
	_upper.z_index=0;_front.z_index=1
	_place(_sprite,tex,Rect2(Vector2.ZERO,tex.get_size()),at)
	_visual_head=Rect2(at.position,Vector2(at.size.x,at.size.y*.8))
	stage.quilt_top=bed.position.y+bed.size.y*float(spec.quilt_top_ratio)
	_front_piece(Vector2.ZERO)

func _show_shared_sit(shift:Vector2) -> void:
	var sample:Dictionary=stage.sit_idle
	var presentation=load("res://entities/sit_presentation.gd")
	_upper.z_index=0;_front.z_index=0
	_body_sprite(presentation.texture(sample.sheet),sample.region,-sample.offset,sample.scale,shift,0.0)
	_visual_head=Rect2(-17,-48,34,29)
	_accessories(shift,_visual_head,"sit_idle")
	_front_piece(shift)

## Qianxia's calibrated poses at home.
func _show_registered_computer() -> void:
	var offsets:Dictionary=_home.get("layoutOffsets",{})
	var chair:Vector2=offsets.get("computer",Vector2.ZERO)
	var desk:Vector2=offsets.get("desk",Vector2.ZERO)
	var blink:=fmod(_time,5)>4.8
	var file:="blink" if blink else "typing"
	var tex:Texture2D=load("res://assets/seaside/actors/computer/"+file+".png")
	_place(_sprite,tex,Rect2(Vector2.ZERO,tex.get_size()),Rect2(Vector2(137,344)+chair-position,Vector2(110,88.5)))
	var front:Texture2D=load("res://assets/seaside/actors/computer/desk-front.png")
	_place(_front,front,Rect2(Vector2.ZERO,front.get_size()),Rect2(Vector2(110,383.5)+desk-position,front.get_size()*.5))
	var hands:Texture2D=load("res://assets/seaside/actors/computer/"+file+"-hands.png")
	_place(_upper,hands,Rect2(Vector2.ZERO,hands.get_size()),Rect2(Vector2(137,344)+chair-position,Vector2(110,88.5)))
	_front.z_index=1;_upper.z_index=2
	_visual_head=Rect2(-16,-60,32,28)

func _show_stage_pose(shift: Vector2) -> void:
	var computer = body.get("computer")
	var m := Poses.moment(str(stage["pose"]), want_zone, str(computer.get("screen", "")) if computer is Dictionary else "", str(_items().get("audio", "")), _time)
	var pose: String = m["pose"]
	var region := Poses.region(pose)
	var k := Poses.scale_of(pose)
	var f := Poses.foot(pose)
	region.size.y *= float(stage.get("crop", 1.0))
	_body_sprite(Poses.sheet(pose), region, f, -k if m.get("flip", false) else k, shift, float(m.get("breathe", 0.0)))
	_visual_head=Poses.head(pose)
	_accessories(shift, _visual_head, pose)
	_front_piece(shift)


## Rows of the actions sheet, used for sitting and painting in her own home.
func _show_stage_row(shift: Vector2) -> void:
	var row_of: int = stage["row"]
	var index := row_of * 4 + (0 if stage.get("still",false) else int(floorf(_time * 3.0)) % 4)
	var r: Array = _actions["rects"][index]
	var anchor: Array = _actions["anchors"][index]
	var ay: float = float(_actions["seatY"][row_of]) if stage.get("seat") == true else float(anchor[1])
	_body_sprite(_actions_tex, Rect2(r[0], r[1], r[2], r[3]), Vector2(anchor[0], ay), float(_actions["scale"])*(-1 if stage.get("flip",false) else 1), shift, 0.0)
	_accessories(shift, Rect2(-17, -60, 34, 29), "")


## Standing on the walk sheet: facing the way the stage says, and breathing.
func _show_standing(shift: Vector2) -> void:
	var facing: int = stage.get("dir", 0)
	if stage.get("spin") == true:
		facing = [0, 2, 3, 1][int(floorf(_time * 4.0)) % 4]
	var index := facing * 4 + (int(floorf(_time*3))%4 if stage.get("animated",false) else 0)
	var r: Array = _walk["rects"][index]
	var anchor: Array = _walk["anchors"][index]
	var scale_of: float = _walk["scale"]
	var region := Rect2(r[0], r[1], r[2], r[3])
	if stage.has("clip"):
		# Only head and shoulders show above the quilt.
		var top: float = _display.y - float(anchor[1]) * scale_of
		region.size.y = clampf((float(stage["clip"]) - top) / scale_of, 1.0, region.size.y)
	_body_sprite(_walk_tex, region, Vector2(anchor[0], anchor[1]), scale_of, shift, 0.5 if sin(_time * 1.6) > 0.6 and not stage.has("clip") else 0.0)
	_accessories(shift, Rect2(-17, -60, 34, 29), "")
	_front_piece(shift)


func _body_sprite(tex: Texture2D, region: Rect2, anchor: Vector2, k: float, shift: Vector2, breathe: float) -> void:
	_sprite.texture = tex
	_sprite.region_rect = region
	_sprite.scale = Vector2(k, absf(k))
	_sprite.position = shift
	_sprite.offset = -anchor
	if breathe > 0.0:
		# The upper body shifts up a little over the same picture; nothing rescales and no gap opens.
		_upper.texture = tex
		_upper.region_rect = Rect2(region.position, Vector2(region.size.x, region.size.y * 0.62))
		_upper.scale = _sprite.scale
		_upper.position = shift + Vector2(0, -breathe)
		_upper.offset = -anchor
		_upper.visible = true


func _place(s: Sprite2D, tex: Texture2D, region: Rect2, at: Rect2) -> void:
	s.offset = Vector2.ZERO
	s.texture = tex
	s.region_rect = region
	s.scale = at.size / region.size
	s.position = at.position
	s.visible = true


## A piece of art from her data: sheet, rect, and measured_width when the rect was measured on a different size of sheet.
func _piece(id: String) -> Array:
	var p: Dictionary = _pieces[id]
	var tex := Poses.texture(p["sheet"])
	var f: float = tex.get_width() / float(p["measured_width"]) if p.has("measured_width") else 1.0
	var r: Array = p["rect"]
	return [tex, Rect2(float(r[0]) * f, float(r[1]) * f, float(r[2]) * f, float(r[3]) * f)]


## Chair back or quilt over her. Positions are in the room, so they are taken back to her own place.
func _front_piece(_shift: Vector2) -> void:
	var here := position
	match stage.get("front"):
		"chair":
			var art_of := _piece("chair_back")
			var at: Array = _pieces["chair_back"]["at"]
			_place(_front, art_of[0], art_of[1], Rect2(Vector2(float(at[0]), float(at[1])) - here, Vector2(float(at[2]), float(at[3]))))
		"quilt":
			var art_of := _piece("quilt")
			var inset: float = _pieces["quilt"]["inset"]
			var rise := roundf(sin(_time * (1.1 if stage.get("asleep") == true else 1.6)) * 1.2) / 2.0
			var top: float = float(stage["quilt_top"]) + rise
			var bottom := _bed_rect().position.y + _bed_rect().size.y - 7.0
			var size := Vector2(_bed_rect().size.x - inset * 2.0, maxf(15.0, bottom - top))
			_place(_front, art_of[0], art_of[1], Rect2(Vector2(_bed_rect().position.x + inset, top) - here, size))


## Headphones and phone, when she has them on her and the pose doesn't already show them.
func _transferring(item: String) -> bool:
	var transfer = _items().get("transfer")
	return transfer is Dictionary and transfer.get("item")==item

func _draw_transfer() -> void:
	var transfer = _items().get("transfer")
	if not transfer is Dictionary:return
	var module := {}
	for m in WorldData.scenes.get(scene_id,{}).get("modules",{}).values():
		if m.get("kind")=="prop" and m.get("art")==("phoneOff" if transfer.item=="phone" else "phonesDock"):module=m;break
	if module.is_empty():return
	var head_width := _visual_head.size.x+4
	var head := Rect2(_visual_head.position+Vector2(_visual_head.size.x/2-head_width/2,-2),Vector2(head_width,floorf(head_width*.875+.5)))
	var hand := Vector2(5,-30) if transfer.item=="phone" else head.position
	var dock := Vector2(module.x,module.y)-_display
	var start := dock if transfer.from=="dock" else hand
	var end := dock if transfer.to=="dock" else hand
	var p := WorldPresentation.eased(float(transfer.progress))
	var at := start.lerp(end,p)
	var file := "phone_in_hand" if transfer.item=="phone" else "phones_on_head"
	var size := Vector2(6,10)
	if transfer.item=="headphones":
		var dock_size := Vector2(module.w,module.h)
		size=(dock_size if transfer.from=="dock" else head.size).lerp(dock_size if transfer.to=="dock" else head.size,p)
		if (transfer.to=="dock" and p>.5) or (transfer.from=="dock" and p<.5):
			var baked := load("res://assets/baked/"+scene_id+"."+str(module.id)+".png")
			_overlay.draw_texture_rect(baked,Rect2(at,size),false)
			return
	var piece := _piece(file)
	_overlay.draw_texture_rect_region(piece[0],Rect2(at,size),piece[1])

func _accessories(shift: Vector2, head: Rect2, pose: String) -> void:
	var items := _items()
	if items.get("headphones") == "worn" and not _transferring("headphones") and pose != "listen" and stage.get("front") != "quilt":
		var w := head.size.x + 4.0
		var art_of := _piece("phones_on_head")
		_place(_phones, art_of[0], art_of[1], Rect2(shift + head.position + Vector2(head.size.x / 2.0 - w / 2.0, -2.0), Vector2(w, roundf(w * 0.875))))
	if items.get("phone") == "hand" and not _transferring("phone") and not pose.begins_with("phone") and stage.get("front") != "quilt":
		var art_of := _piece("phone_in_hand")
		_place(_phone, art_of[0], art_of[1], Rect2(shift + Vector2(10, -25), Vector2(6, 10)))


func _show_pose() -> void:
	var fishing := is_fishing()
	var pose_row: int = 1 if fishing else (action_pose if action_pose >= 0 else PHASE_POSES[action_phase])
	var index: int = pose_row * 4 + int(floor(_time * 3.0)) % 4
	var r: Array = _actions["rects"][index]
	var anchor: Array = _actions["anchors"][index]
	var k: float = _actions["scale"]
	_sprite.texture = _actions_tex
	_sprite.region_rect = Rect2(r[0], r[1], r[2], r[3])
	_sprite.scale = Vector2(-k if fishing else k, k)
	_sprite.position = _fishing_seat() if fishing else Vector2.ZERO
	_sprite.offset = Vector2(-float(anchor[0]), -float(_actions["seatY"][pose_row]) if fishing else -float(anchor[1]))


## Rod, line, bobber and catch while fishing; the mood bubble when poked.
func gift_event(record: Dictionary) -> void:
	if gift_visual.get("id") == record.id and gift_visual.get("status") == record.status: return
	gift_visual = record.duplicate(true)
	gift_at = _time

func _show_gift(shift: Vector2) -> bool:
	if gift_visual.is_empty() or is_walking() or sleeping or robe or state == State.DOING: return false
	var giver: bool = gift_visual.from == key
	var i := GiftPose.frame(gift_visual.status, giver, _time - gift_at)
	if i < 0: return false
	var data := GiftPose.sheet(key)
	if data.is_empty(): return false
	var peer: Character
	for other in neighbours:
		if other.key == (gift_visual.to if giver else gift_visual.from): peer = other
	if peer == null or peer.scene_id != scene_id: return false
	var facing := 1.0 if peer.feet.x >= feet.x else -1.0
	_body_sprite(data.texture, Rect2(Vector2(i % 4, i / 4) * data.cell, data.cell), data.anchors[i], data.scale * facing, shift, 0.0)
	_gift_draw = true
	return true

func _draw_overlay() -> void:
	if stage.get("hidden",false) and not is_walking(): return
	if stage.get("water",false) and robe and not is_walking():
		var w := 26+sin(_time*2)*2
		for k in 2:
			var points := PackedVector2Array()
			for i in 33:
				var a := TAU*i/32
				points.append(Vector2(cos(a)*(w+k*6),sin(a)*(4+k*2)+k*3))
			_overlay.draw_polyline(points,Color("ffffffb0"),1)
	if _gift_draw and not gift_visual.is_empty():
		var giver: bool = gift_visual.from == key
		var received: bool = gift_visual.status == "received"
		if (giver and not received and gift_visual.status == "offered") or (not giver and received):
			var icon := ItemIcons.texture(gift_visual.product, gift_visual.item)
			var facing := signf(_sprite.scale.x)
			_overlay.draw_texture_rect(icon, Rect2(Vector2(facing * 18.0 - 9.0, -39.0), Vector2(18, 18)), false)

	if not placed:
		return
	if not is_walking():
		AmbientArt.paint(_overlay,AmbientArt.food(effect,SharedFeed.now_ms()))
		_draw_transfer()
	var particles := ActorEffects.dust(_dust,_time*1000)
	for row in particles:
		row.rect[0]-=_display.x
		row.rect[1]-=_display.y
	AmbientArt.paint(_overlay,particles)
	if not is_walking() and state!=State.ASLEEP:
		var modules := {}
		for id in WorldPresentation.facts().scenes[scene_id].modules:
			var m: Dictionary=WorldPresentation.facts().scenes[scene_id].modules[id].duplicate()
			m.x-=_display.x
			m.y-=_display.y
			modules[id]=m
		var rain := float(SharedFeed.weather.get("rain",0)) if SharedFeed.weather is Dictionary else 0.0
		load("res://entities/play_extras.gd").draw(_overlay,effect,_effect_seconds(),_visual_head,Vector2.ZERO,modules,_time,scene_id=="qianxia-park" and rain>0 and Economy.people.get(key,{}).get("bag",{}).get("umbrella",0)>0)
		if action=="chat": AmbientArt.paint(_overlay,ActorEffects.chat(_visual_head,_time))
		var kind := _effect_active()
		if kind!="":
			var sec := _effect_seconds()
			var duration := maxf(2,float(effect.get("seconds",6)))
			var m: Dictionary=WorldData.scenes[scene_id].modules.get(str(effect.get("module","")),{})
			var box := Rect2(Vector2(m.x,m.y)-_display,Vector2(m.w,m.h)) if not m.is_empty() else Rect2(_visual_head.position-Vector2(6,4),Vector2(_visual_head.size.x+12,30))
			if sec<duration: AmbientArt.paint(_overlay,ActorEffects.effect(kind,box,_visual_head,sec/duration,sec))
	var painting: bool=str(stage.get("pose","")).begins_with("draw") or (want_zone==str(_home.get("visual",{}).get("paint_zone","")) and not is_walking() and _effect_active()!="")
	if painting:
		if _paint_start<0: _paint_start=_time
		for m in WorldPresentation.facts().scenes[scene_id].modules.values():
			if "easel" in str(m.id): AmbientArt.paint(_overlay,ActorEffects.paint(Rect2(Vector2(m.x,m.y)-_display,Vector2(m.w,m.h)),_time-_paint_start))
	else: _paint_start=-1
	if stage.get("asleep") == true:
		_draw_sleep()
	if str(_items().get("audio", "")) == "playing" and not is_walking() and _home.get("audioOutput","")!="speakers":
		_draw_notes()
	if is_fishing():
		var sec := _effect_seconds()
		var dur := float(effect.get("seconds", 16))
		var seat := _fishing_seat()
		var hand := seat + Vector2(19, -13)
		var tip := hand + Vector2(26, -22)
		var m: Dictionary = WorldData.scenes[scene_id]["modules"].get(str(effect.get("module", "")), {})
		if not m.is_empty():
			var bob := Vector2(float(m["x"]) + float(m["w"]) + 34.0, float(m["y"]) + 42.0 + sin(_time * 3.0) * 1.2) - _display
			var outcome = effect.get("outcome")
			var caught: bool = outcome is Dictionary and float(outcome.get("sizeCm", 0) if outcome.get("sizeCm") != null else 0) > 0
			var reeling := sec > dur * 0.66 and caught
			var hook := bob
			if reeling:
				var p := minf(1.0, (sec - dur * 0.66) / (dur * 0.12))
				hook = bob.lerp(hand + Vector2(6, 0), p) + Vector2(0, -sin(p * PI) * 28.0)
			_overlay.draw_line(hand, tip, Color("6d4a32"), 2.0)
			var line := PackedVector2Array()
			for i in 13:
				var t := i / 12.0
				var ctrl := Vector2(tip.x + 10.0, hook.y - 10.0)
				line.append(tip.lerp(ctrl, t).lerp(ctrl.lerp(hook, t), t))
			_overlay.draw_polyline(line, Color("e8eef5"), 1.0)
			var bite := sec > dur * 0.6 and sec < dur * 0.66
			if reeling:
				AmbientArt.paint(_overlay,AmbientArt.caught(outcome,hook.x,hook.y,_time))
			else:
				var dip := 3.0 if bite else 0.0
				_overlay.draw_rect(Rect2(bob + Vector2(-1, -3 + dip), Vector2(3, 3)), Color("ff6f6c"))
				_overlay.draw_rect(Rect2(bob + Vector2(-1, -1 + dip), Vector2(3, 2)), Color.WHITE)
			if sec > dur * 0.6 and sec < dur * 0.8:
				var ripple := (sec - dur * 0.6) / (dur * 0.2)
				_overlay.draw_set_transform(bob + Vector2(0, 2), 0.0, Vector2(1.0, 0.4))
				_overlay.draw_arc(Vector2.ZERO, 3.0 + ripple * 10.0, 0.0, TAU, 20, Color(0.88, 0.94, 1.0, 0.8 * (1.0 - ripple)), 1.0)
				_overlay.draw_set_transform(Vector2.ZERO)
	if _time < _mood_until and MOOD_CELLS.has(mood_icon) and state != State.ASLEEP and not is_walking():
		var size := _mood_tex.get_size() / 4.0
		var cell: int = MOOD_CELLS[mood_icon]
		var base := (_fishing_seat() if is_fishing() else Vector2.ZERO) + Vector2(0, -64.0 + round(sin(_time * 1.6)))
		_overlay.draw_texture_rect_region(_mood_tex, Rect2(base + Vector2(-11, -21), Vector2(22, 22)), Rect2(size * 3.0, size))
		_overlay.draw_texture_rect_region(_mood_tex, Rect2(base + Vector2(-8, -19), Vector2(16, 16)), Rect2(Vector2(cell % 4, cell / 4) * size, size))


## The same head-relative sleep and audio glyphs for every resident.
func _draw_sleep() -> void:
	AmbientArt.paint(_overlay,ActorEffects.sleep(_visual_head,_time))

func _draw_notes() -> void:
	AmbientArt.paint(_overlay,ActorEffects.notes(_visual_head,_time))


func _draw() -> void:
	if art == "" and placed:
		draw_circle(Vector2(0,-26),10,Color("f5f1e8"))
		draw_style_box(_white_body(),Rect2(-9,-18,18,18))
		return
	if not placed or state == State.ASLEEP or stage.has("quilt_top"):
		return
	draw_set_transform(Vector2(0, _display.y - position.y - 1.0), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 12.0 if state == State.RUN else 14.0, Color(0.08, 0.125, 0.2, 0.19))
	draw_set_transform(Vector2.ZERO)

func _white_body() -> StyleBoxFlat:
	var body_style := StyleBoxFlat.new()
	body_style.bg_color = Color("dedbd4")
	body_style.set_corner_radius_all(6)
	return body_style


