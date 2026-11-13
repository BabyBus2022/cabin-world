class_name ServiceNpc
extends Character
## A stationary service role attached to the common Character body. Appearance,
## station, trigger mapping and frame timing are data, never resident identities.
var profile := {}
var pose_name := "idle"
var pose_time := 0.0
var jobs: Array = []
var waiting := {}
var greeted := {}
var receipts := {}
var service_texture: Texture2D
var textures := {}
var idle_elapsed := 0.0
var pose_flip := false
const Appearance=preload("res://core/npc_appearance.gd")
var role_profile:Dictionary={}

func _ready() -> void:
	# The engine enables inherited callbacks when entering the tree; station
	# placement belongs to this role, not the walking controller's idle target.
	set_physics_process(false)

static func mount(room: Node2D, scene: String) -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/npcs.json"))
	for entry in data.characters:
		if entry.scene != scene: continue
		var npc := ServiceNpc.new()
		npc.configure(data.skins.get(entry.get("skin",""),{}).merged(entry,true))
		room.add_child(npc)

func configure(entry: Dictionary) -> void:
	role_profile=entry.duplicate(true)
	profile = entry.merged(Appearance.skin(),true)
	resident_actor = false
	setup(str(entry.id), Appearance.label(), "")
	service_texture = load(str(profile.texture))
	textures[str(profile.texture)] = service_texture
	scene_id = str(entry.scene)
	want_scene = scene_id
	feet = Vector2(entry.feet[0],entry.feet[1])
	position = feet
	_display = feet
	placed = true
	# The counter is a fixed station inside furniture; it takes no aisle/seat.
	set_physics_process(false)
	if entry.role=="cashier":
		Actions.phase_started.connect(_phase)
		Actions.action_ended.connect(_ended)
		Economy.transaction_committed.connect(_committed)
	else:
		visible = false
	_update_sprite()

func refresh_appearance() -> void:
	profile=role_profile.merged(Appearance.skin(),true)
	display_name=Appearance.label()
	service_texture=load(str(profile.texture))
	textures[str(profile.texture)]=service_texture
	_update_sprite()

func _near(actor: String) -> bool:
	if not is_inside_tree(): return false
	var counter := Vector2(profile.counter[0],profile.counter[1])
	for person in get_tree().get_nodes_in_group("world_residents"):
		if person.key==actor:
			return person.placed and person.scene_id==scene_id and person.feet.distance_to(counter)<=float(profile.radius)
	return false

func _phase(actor: String, phase: String, _label: String, _pose: int) -> void:
	var current: Dictionary = Actions.current(actor)
	if current.get("kind")!=profile.service.action or not phase in profile.service.phases or not _near(actor): return
	waiting[actor] = current.id
	greeted[actor] = true

func _ended(actor: String) -> void:
	waiting.erase(actor)
	# Successful receipts already queued remain visible after the action ends.

func _committed(record: Dictionary) -> void:
	if record.op!=profile.service.operation or not _near(record.actor) or receipts.has(record.id): return
	receipts[record.id] = true
	if receipts.size()>128: receipts.erase(receipts.keys()[0])
	waiting.erase(record.actor)
	greeted[record.actor] = true
	jobs.append({"pose":"give","actor":record.actor,"receipt":record.id})
	jobs.append({"pose":"thanks","actor":record.actor,"receipt":record.id})

func _set_pose(value: String) -> void:
	if pose_name==value: return
	pose_name = value
	pose_time = 0.0

func _duration(value: String) -> float:
	var animation: Dictionary = profile.animations[value]
	return animation.frames.size()/float(animation.fps)

func advance(delta: float) -> void:
	pose_time += delta
	idle_elapsed = idle_elapsed+delta if pose_name=="idle" else 0.0
	for actor in waiting.keys():
		if not _near(actor): waiting.erase(actor)
	for actor in greeted.keys():
		if not _near(actor): greeted.erase(actor)
	# Finish each committed handover before beginning the next customer's clip.
	if (pose_name in ["give","thanks"] or (pose_name in ["greet","laugh"] and jobs.is_empty() and waiting.is_empty())) and pose_time<_duration(pose_name): return
	if not jobs.is_empty():
		var job: Dictionary = jobs.pop_front()
		_set_pose(str(job.pose))
		pose_time = 0.0
	elif not waiting.is_empty():
		_set_pose("scan")
	else:
		_set_pose("idle")
		if is_inside_tree():
			for person in get_tree().get_nodes_in_group("world_residents"):
				if _near(person.key) and not greeted.has(person.key):
					greeted[person.key] = true
					_set_pose("greet")
					break
		if pose_name=="idle" and profile.has("idle_cycle") and idle_elapsed>=float(profile.idle_cycle.seconds):
			_set_pose(str(profile.idle_cycle.pose))

func _process(delta: float) -> void:
	if profile.has("station_module"):
		var module:Dictionary=WorldData.scenes.get(scene_id,{}).get("modules",{}).get(profile.station_module,{})
		visible=not module.is_empty()
		if not visible:return
		var anchor:Array=profile.station_anchor
		feet=Vector2(module.x+anchor[0],module.y+anchor[1])
		_display=feet;position=feet
		profile.counter=[feet.x,feet.y+80]
	if profile.role=="arcade": advance_arcade(delta)
	else: advance(delta)
	super._process(delta)

func _update_sprite() -> void:
	if profile.is_empty() or service_texture==null: return
	var animation: Dictionary = profile.animations[pose_name]
	var index: int = int(pose_time*float(animation.fps))%animation.frames.size()
	var frame: Dictionary = profile.frames[animation.frames[index]]
	_sprite.visible = true
	var file := str(frame.get("texture",profile.texture))
	if not textures.has(file): textures[file] = load(file)
	_sprite.texture = textures[file]
	_sprite.region_enabled = true
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.region_rect = Rect2(frame.rect[0],frame.rect[1],frame.rect[2],frame.rect[3])
	var art_scale := float(frame.get("scale",profile.scale))
	_sprite.scale = Vector2(-art_scale if pose_flip else art_scale,art_scale)
	if Appearance.current()=="mochi":
		# Small anchored breath/bow keeps the simple skin alive without changing its station.
		_sprite.scale.y*=1.0+sin(pose_time*3.0)*(.012 if pose_name in ["idle","chess","arcade"] else .025)
	_sprite.position = -Vector2(frame.anchor[0],frame.anchor[1])*_sprite.scale + (_display-position)

func _draw() -> void:
	pass # The fixed station's foreground counter supplies the occlusion/shadow.

## Arcade role reads the real board. Draws no extra opponent in resident-vs-resident matches.
func advance_arcade(delta: float) -> void:
	var row: Dictionary = VadsLink.arcade_view.get("sessions",{}).get(profile.match_key,{})
	if profile.match_key=="xiangqi":
		var alternate:Dictionary=VadsLink.arcade_view.get("sessions",{}).get("gomoku",{})
		if alternate.get("status") in ["waiting","playing"]:row=alternate
	var board = row.get("game")
	visible = false
	if not board is Dictionary or row.get("status") in ["waiting","interrupted"]: return
	var opponent := str(profile.opponent_id)
	if not opponent in board.get("players",[]) and not opponent in board.get("sides",[]): return
	var people: Array = row.get("players",[]).filter(func(p):return p.get("id")!=opponent)
	if people.size()!=1: return
	var active: bool = row.get("status")=="playing"
	var age := (SharedFeed.now_ms()-float(row.get("endedAt",0)))/1000.0
	if not active and (age<0 or age>15): return
	visible = true
	var seat_index := 1-clampi(int(people[0].get("seat",0)),0,1)
	var seat: Dictionary = arcade_seat(scene_id,str(profile.match_key),seat_index,profile.seats[seat_index])
	feet = Vector2(seat.feet[0],seat.feet[1])
	_display = feet
	position = Vector2(feet.x,seat.depth)
	var celebrating: bool = not active and board.get("status")=="won" and board.get("winner")==opponent and age<5
	_set_pose("laugh" if celebrating else str(profile.play_pose))
	pose_flip = seat.flip and not celebrating
	pose_time = age if celebrating else pose_time+delta
	if not active and not celebrating: pose_time=0
	if active and board.kind in ["xiangqi","gomoku"] and board.sides[int(board.turn)]!=opponent: pose_time=0

static func arcade_seat(scene:String,match_key:String,index:int,fallback:Dictionary) -> Dictionary:
	var room:Dictionary=WorldData.scenes.get(scene,{})
	if scene!="world-arcade" or not room.has("layoutRevision"):return fallback
	if match_key=="xiangqi":
		var chair:Dictionary=room.modules["chess-far-seat" if index==0 else "chess-near-seat"]
		return {"feet":[chair.x+chair.w/2,chair.y+chair.h*.22],"depth":chair.depth+.05,"flip":index==1}
	if match_key=="snake":
		var spot:Dictionary=room.zones["arcade_snake_left" if index==0 else "arcade_snake_right"]
		return {"feet":[spot.x,spot.y],"depth":spot.y,"flip":false}
	return fallback
