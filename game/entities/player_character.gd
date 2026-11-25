extends Character
## The local player shares the resident position, action, and save systems.
const ART := "res://assets/world/vads-player/"
const LOOKS := "圆脸团团，穿着绿色围裙"
const FACES := ["south", "west", "east", "north"]
const ART_DIRECTIONS := [0, 1, 2, 3]
const SPEED := 120.0
const RUN_SPEED := 184.0

var player_enabled := false
var direction_input := Vector2.ZERO
var sprint_pressed := false
var _walk_point := Vector2.INF
var _art_data: Dictionary = {}
var _art_textures: Dictionary = {}
var _presence_elapsed := 0.0
var _position_dirty := false
var _last_pose := ""
var _pose_clock := 0.0
var _crossed_door := false
var _manual_step := Vector2.ZERO
var swim_feet := Vector2.INF
var swim_flip := false

func setup(p_key: String, p_name: String, p_art: String) -> void:
	hide()
	WorldData.actors[p_art] = WorldData.actors["xiaojingyu"]
	super.setup(p_key, p_name, p_art)
	restore_skin()
	
func set_enabled(active: bool) -> void:
	if player_enabled == active:
		return
	player_enabled = active
	if active:
		if not placed: wake()
		if not placed:
			want_scene = "qianxia-park"
			want_zone = "meadow"
			_place_first()
		stop_navigation()
	else:
		stop_navigation()
		remember_if_moved()
		placed = false
	visible = active
	publish_player()

func apply_presence(_presence: Dictionary) -> void:
	pass

func report_position() -> void:
	publish_player()

func remember_if_moved() -> void:
	if placed and _position_dirty:
		_remember()
		_position_dirty = false

func stop_navigation() -> void:
	direction_input = Vector2.ZERO
	_walk_point = Vector2.INF
	order_id = ""
	next_scene = ""
	want_scene = scene_id
	want_zone = ""
	route.clear()
	target = feet
	state = State.IDLE
	velocity = 0.0

func go_local(destination: String, zone := "") -> bool:
	if not player_enabled or not placed or not WorldData.scenes.has(destination):
		return false
	var origin: String = str(WorldData.SPACE_SCENE.find_key(scene_id))
	var space: String = str(WorldData.SPACE_SCENE.find_key(destination))
	if Entry.route(origin, space, key).is_empty():
		return false
	stop_navigation()
	want_scene = destination
	want_zone = zone
	return true

func click_walk(point: Vector2) -> bool:
	if not player_enabled or not placed or not WorldData.nav(scene_id).walkable(point):
		return false
	stop_navigation()
	_walk_point = point
	return true

func _choose_destination() -> void:
	if scene_id=="qianxia-park" and scene_id==want_scene and effect.get("module","") in ["bench","swing","rider"] and action==effect.get("module"):
		return
	if _walk_point.is_finite():
		if feet.distance_to(_walk_point) <= 2.0:
			_walk_point = Vector2.INF
		else:
			go(_walk_point)
			if not is_walking():
				_walk_point = Vector2.INF
		return
	super._choose_destination()

func _stage_now() -> Dictionary:
	if swim_feet.is_finite() and action=="swim":
		return {"feet":swim_feet,"robe_row":4,"water":true,"flip":swim_flip,"snap":true}
	if action.is_empty() and restaurant_effect.is_empty() and not sleeping:
		return {}
	if scene_id == "world-arcade" and action == "sit" and want_zone in ["arcade_xiangqi", "arcade_xiangqi_far", "arcade_xiangqi_near"]:
		var seats = preload("res://entities/sit_presentation.gd")
		seats.ready()
		var binding: Dictionary = seats.bindings.scenes[scene_id][want_zone]
		var chair: Dictionary = WorldData.scenes[scene_id].modules.get(binding.module, {})
		if not chair.is_empty():
			var cushion := Vector2(chair.x + chair.w * binding.anchor_ratio[0], chair.y + chair.h * binding.anchor_ratio[1])
			return {"feet":cushion, "sort":float(chair.depth)+0.05, "seat":true, "snap":true, "chess_facing":binding.facing}
	var fixture := str(effect.get("module",""))
	if scene_id=="qianxia-park" and fixture in ["bench","swing","rider"] and action==fixture:
		var module:Dictionary=WorldPresentation.facts().scenes[scene_id].modules.get(fixture,{})
		if not module.is_empty():
			var seat:=WorldPresentation.point(module)+WorldPresentation.point(module.anchors.seat) if fixture=="bench" else WorldPresentation.mechanism_seat(module,fixture,_time)
			return {"feet":seat,"sort":float(module.depth)+.05,"seat":true,"snap":true,"park_pose":"park-"+fixture,"fixture":module}
	return super._stage_now()

func _physics_process(dt: float) -> void:
	if not player_enabled:
		return
	var before := feet
	_manual_step = Vector2.ZERO
	if direction_input != Vector2.ZERO:
		var direction := direction_input
		stop_navigation()
		direction_input = direction
		var nav := WorldData.nav(scene_id)
		var speed := RUN_SPEED if sprint_pressed and not robe else SPEED
		var move := direction.normalized() * speed * minf(dt, 0.05)
		var at_exit := false
		for door in WorldData.scenes[scene_id].exits:
			if scene_id=="xiaojingyu-home" and WorldData.point(door).distance_to(WorldData.point(WorldData.scenes[scene_id].zones.xj_door))<48:
				continue # The beach shares this doorstep. E explicitly takes the park exit.
			var towards := WorldData.point(door) - feet
			if towards.length() > 24.0:
				continue
			at_exit = true
			if not _crossed_door and towards.dot(direction) > 0 and go_local(str(door.to)):
				_crossed_door = true
				_enter(str(door.to), str(door.entry))
				_position_dirty = true
				publish_player()
				return
		if not at_exit:
			_crossed_door = false
		var offsets:Array[Vector2]=[move, Vector2(move.x,0), Vector2(0,move.y)]
		# Ease around the diagonal bends while respecting the same walk mask as residents.
		if scene_id=="xiaojingyu-home" and (feet.x>858 or feet.y>572) and Features.on("seaside-path") and not nav.clear_line(feet,feet+move):
			for angle in [22.5,-22.5,45.0,-45.0,65.0,-65.0]:
				offsets.append(move.rotated(deg_to_rad(angle)))
		for offset in offsets:
			if offset != Vector2.ZERO and nav.clear_line(feet, feet + offset):
				feet += offset
				break
		var step := feet - before
		_manual_step = step
		if step != Vector2.ZERO:
			row = (3 if step.y < 0 else 0) if absf(step.y) > absf(step.x) else (1 if step.x < 0 else 2)
			state = State.RUN if speed == RUN_SPEED else State.WALK
			velocity = speed
		stage = {}
		_display = feet
		position = feet
	else:
		_crossed_door = false
		tick(dt)
	if feet != before:
		_position_dirty = true
	_presence_elapsed += dt
	if _presence_elapsed >= 0.65:
		_presence_elapsed = 0.0
		publish_player()
		if not is_walking():
			remember_if_moved()

func publish_player() -> void:
	if not VadsLink.connected:
		return
	var here := player_enabled and placed
	var area: String = str(WorldData.SPACE_SCENE.find_key(scene_id)) if here else ""
	var place := ""
	var nearest := 60.0
	var seen := {}
	if here:
		for obj in WorldData.objects:
			if obj.space != area or not WorldData.scenes[scene_id].zones.has(obj.zone):
				continue
			var distance := feet.distance_to(WorldData.point(WorldData.scenes[scene_id].zones[obj.zone]))
			if distance < nearest:
				nearest = distance
				place = str(obj.name)+"旁"
		for other in _nearby():
			var delta: Vector2 = feet-other.feet
			seen[other.key] = "身旁" if delta.length()<22 else ("左侧" if delta.x<0 else "右侧") if absf(delta.x)>absf(delta.y) else ("画面上方" if delta.y<0 else "画面下方")
	VadsLink.send({"type":"body.playerPresence", "actor":key, "present":here,
		"name":display_name, "looks":str(_art_data.get("name",display_name)), "appearance":str(skin_catalog().builtins[skin_index].appearance) if skin_index<skin_catalog().builtins.size() else "custom-player",
		"space":area, "sceneId":scene_id if here else "", "zone":want_zone,"place":place,"seen":seen,
		"x":feet.x, "y":feet.y, "action":action, "sleeping":sleeping,
		"label":action_label if action_label != "" else ("小跑中" if state == State.RUN else "走路中" if is_walking() else "")})

func pose_key() -> String:
	var facing: String = FACES[row]
	var art_dir: int = ART_DIRECTIONS[row]
	if not restaurant_effect.is_empty():
		var act: String = str(restaurant_effect.get("kind", restaurant_effect.get("phase", "order"))).trim_prefix("restaurant_")
		if act in ["order", "cook", "eat", "carry", "place"]:
			return "meal-" + act + "-" + str(restaurant_effect.get("facing",facing))
	if is_walking():
		if state == State.RUN and not robe:
			var heading := _manual_step if direction_input != Vector2.ZERO else target - feet
			var sector := posmod(roundi(heading.angle_to(Vector2.DOWN) / (PI / 4.0)), 8)
			return "run-" + str(posmod(-sector, 8))
		if not robe and direction_input.x!=0 and direction_input.y!=0:
			var diagonal := (1 if direction_input.x<0 else 7) if direction_input.y>0 else (3 if direction_input.x<0 else 5)
			return "walk8-"+str(diagonal)
		return ("yukata-" if robe else "walk-") + str(art_dir)
	if sleeping or action in ["sleep", "nap"]:
		return "sleeping"
	if stage.get("water", false):
		return "yukata-4" if action=="swim" else "yukata-5"
	if stage.has("chess_facing"):
		return "sit-" + str(stage.chess_facing)
	if stage.has("park_pose"):
		return stage.park_pose
	if stage.get("seat", false) or stage.has("sit_idle") or action in ["bench", "sit", "fish", "swing", "seesaw", "rider", "carousel", "slide"]:
		return "sit-" + facing
	if action in ["computer", "write", "read"]:
		return "computer-typing"
	if action in ["phone", "music"]:
		return "idle_phone-" + str(art_dir)
	if not gift_visual.is_empty():
		return "gift-" + str(art_dir)
	if robe:
		return "yukata-"+str(art_dir)
	return "idle" if row == 0 else "idle-" + facing

func art_texture(file: String) -> Texture2D:
	if not _art_textures.has(file):
		var im := Image.new()
		if im.load_png_from_buffer(FileAccess.get_file_as_bytes(skin_root + file)) == OK:
			if _art_textures.size() >= 16:
				_art_textures.erase(_art_textures.keys()[0])
			_art_textures[file] = ImageTexture.create_from_image(im)
	return _art_textures.get(file)

const WHALE_ART="res://qingxi-live/assets/studio-whale/"
var skin_root=ART
var skin_index=0
var custom_root=""
var _portrait:Texture2D

static var _catalog:Dictionary={}
static func skin_catalog()->Dictionary:
	if _catalog.is_empty():
		_catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/player-skins.json"))
	return _catalog

func skin_slot(id:String)->int:
	var entries:Array=skin_catalog().builtins
	if id=="custom":return entries.size()
	for i in entries.size():
		if str(entries[i].id)==id:return i
	return -1

func skin_config()->String:
	return Economy.save_path.get_base_dir().path_join("player-skin.cfg")

func has_custom_skin()->bool:
	return custom_root!="" and FileAccess.file_exists(custom_root+"character.json")

func restore_skin():
	var cfg=ConfigFile.new()
	if cfg.load(skin_config())==OK:
		custom_root=str(cfg.get_value("skin","custom",""))
		var legacy=int(cfg.get_value("skin","index",0))
		var old_ids=["tuantuan","xiaojingyu","custom"]
		var id=str(cfg.get_value("skin","id",old_ids[legacy] if legacy>=0 and legacy<old_ids.size() else ""))
		if select_skin(skin_slot(id),false)==OK:return
	select_skin(maxi(0,skin_slot(str(skin_catalog().default))),false)

func select_skin(i:int,persist=true)->int:
	var entries:Array=skin_catalog().builtins
	if i<0 or i>entries.size() or (i==entries.size() and not has_custom_skin()):return ERR_INVALID_PARAMETER
	var source:String=custom_root if i==entries.size() else entries[i].root
	var meta=JSON.parse_string(FileAccess.get_file_as_string(source+"character.json"))
	if not meta is Dictionary or not meta.has("idle") or not meta.has("actions"):return ERR_INVALID_DATA
	if persist:
		var cfg=ConfigFile.new()
		cfg.set_value("skin","index",i)
		cfg.set_value("skin","id","custom" if i==entries.size() else entries[i].id)
		cfg.set_value("skin","custom",custom_root)
		var err=cfg.save(skin_config())
		if err!=OK:return err
	skin_root=source
	skin_index=i
	_art_data=meta
	_art_textures.clear()
	_portrait=null
	_last_pose=""
	if is_node_ready():publish_player()
	return OK

func import_skin(path:String,sheet:bool)->int:
	var im=Image.new()
	var input=FileAccess.open(path,FileAccess.READ)
	if input==null or input.get_length()>32*1024*1024:return ERR_INVALID_DATA
	input.close()
	if im.load(path)!=OK:return ERR_INVALID_DATA
	im.convert(Image.FORMAT_RGBA8)
	var rows=4 if sheet else 1
	if sheet and im.get_height()%4!=0:return ERR_INVALID_DATA
	var h=int(im.get_height()/rows)
	var cols=int(im.get_width()/maxi(1,h)) if sheet else 1
	if cols<1 or cols>16 or (sheet and im.get_width()!=cols*h):return ERR_INVALID_DATA
	var w=int(im.get_width()/cols)
	var area=Rect2i()
	for y in rows:
		for x in cols:
			var box=im.get_region(Rect2i(x*w,y*h,w,h)).get_used_rect()
			if not box.has_area():return ERR_INVALID_DATA
			if area.has_area():area=area.merge(box)
			else:area=box
	var scale_factor=minf(186.0/area.size.y,268.0/area.size.x)
	var size=Vector2i(maxi(1,roundi(area.size.x*scale_factor)),maxi(1,roundi(area.size.y*scale_factor)))
	var dest=skin_config().get_base_dir().path_join("player-skins/"+FileAccess.get_sha256(path)+("-walk/" if sheet else "-still/"))
	var meta={"name":"自定义皮肤","idle":{"file":"idle.png","anchor":[160,296],"unitPixels":100},"actions":{}}
	for direction in 4:
		var key="walk-%d"%direction
		var folder=dest.path_join(key)
		var err=DirAccess.make_dir_recursive_absolute(folder)
		if err!=OK:return err
		var times=[]
		for x in cols:
			var cell=im.get_region(Rect2i(x*w+area.position.x,(direction*h if sheet else 0)+area.position.y,area.size.x,area.size.y))
			cell.resize(size.x,size.y,Image.INTERPOLATE_LANCZOS)
			var canvas=Image.create_empty(320,320,false,Image.FORMAT_RGBA8)
			canvas.blit_rect(cell,Rect2i(Vector2i.ZERO,size),Vector2i(160-size.x/2,296-size.y))
			if canvas.save_png(folder.path_join("%03d.png"%x))!=OK:return ERR_CANT_CREATE
			if direction==0 and x==0 and canvas.save_png(dest+"idle.png")!=OK:return ERR_CANT_CREATE
			times.append(120)
		meta.actions[key]={"count":cols,"durationsMs":times,"loop":true,"sizeCalibration":{"anchor":[160,296],"unitPixels":100}}
	var file=FileAccess.open(dest+"character.json",FileAccess.WRITE)
	if file==null:return ERR_CANT_CREATE
	file.store_string(JSON.stringify(meta))
	file.close()
	custom_root=dest
	return OK

func portrait_frame() -> Dictionary:
	if _portrait==null:
		var image=art_texture("idle.png").get_image()
		var bounds=image.get_used_rect()
		var canvas=Image.create_empty(320,320,false,Image.FORMAT_RGBA8)
		if bounds.has_area():
			var body=image.get_region(bounds)
			var factor=168.0/maxi(bounds.size.x,bounds.size.y)
			body.resize(maxi(1,roundi(body.get_width()*factor)),maxi(1,roundi(body.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
			canvas.blit_rect(body,Rect2i(Vector2i.ZERO,body.get_size()),Vector2i(67+(185-body.get_width())/2,18+(185-body.get_height())/2))
		_portrait=ImageTexture.create_from_image(canvas)
	return {"texture":_portrait,"rect":[0,0,320,320],"anchor":[159.5,296]}



func _update_sprite() -> void:
	_overlay.position = _display-position
	_overlay.queue_redraw()
	_sprite.visible = player_enabled and placed and not stage.get("hidden", false)
	if not _sprite.visible:
		return
	var pose := pose_key()
	if pose != _last_pose:
		_pose_clock = _time
		_last_pose = pose
	if is_walking() and not _art_data.actions.has(pose):pose="walk-%d"%ART_DIRECTIONS[row]
	var spec: Dictionary = _art_data.actions.get(pose, {})
	var index := 0
	var times: Array = spec.get("durationsMs", [])
	var active := pose.begins_with("idle") or is_walking() or sleeping or not action.is_empty() or not restaurant_effect.is_empty() or not gift_visual.is_empty()
	if active and not times.is_empty():
		var total := 0.0
		for duration in times:
			total += float(duration)
		var elapsed := (_time - _pose_clock) * 1000.0
		var t := fposmod(elapsed,total) if spec.get("loop",true) else minf(elapsed,total-0.01)
		for duration in times:
			if t < float(duration):
				break
			t -= float(duration)
			index += 1
	if pose=="park-swing" and not spec.is_empty():
		# The leg extension follows the same pendulum phase as the two ropes.
		index = floori(fposmod(_time*2.4+PI*.25,TAU)/TAU*int(spec.count))
	elif pose=="park-rider" and not spec.is_empty():
		index = floori(fposmod(_time*3.5+PI*.25,TAU)/TAU*int(spec.count))
	var strip: String = spec.get("strip","")
	var texture := art_texture(strip if not strip.is_empty() else "idle.png" if spec.is_empty() else "%s/%03d.png" % [pose, index])
	if texture == null:
		texture = art_texture("idle.png")
		spec = {}
		strip = ""
	var anchor: Array = spec.get("sizeCalibration", {}).get("anchor", _art_data.idle.anchor)
	if stage.has("chess_facing"):
		var seat_anchor: Array = _art_data.get("chessSeatAnchors",{}).get(stage.chess_facing,[])
		if seat_anchor.size()==2:anchor=seat_anchor
	var k := 0.29
	_sprite.texture = texture
	_sprite.region_enabled = not strip.is_empty()
	if _sprite.region_enabled:
		var columns := int(spec.get("columns",spec.count))
		var width := texture.get_width()/columns
		var height := texture.get_height()/ceili(float(spec.count)/columns)
		_sprite.region_rect=Rect2((index%columns)*width,(index/columns)*height,width,height)
	_sprite.scale = Vector2.ONE * k
	_sprite.offset = Vector2.ZERO
	var contact := _display
	if pose in ["park-swing","park-rider"]:
		contact=WorldPresentation.mechanism_seat(stage.fixture,action,_time)
	elif is_walking() and _manual_step!=Vector2.ZERO:
		contact-=_manual_step*(1.0-Engine.get_physics_interpolation_fraction())
	_sprite.rotation = WorldPresentation.rider_angle(_time) if pose=="park-rider" else 0.0
	_sprite.position = contact-position-(Vector2(anchor[0], anchor[1])*k).rotated(_sprite.rotation)
	_sprite.flip_h = stage.get("flip", false) and stage.get("water", false)
	if stage.get("water", false):
		# The bath artwork is a head-and-shoulders overlay anchored at the waterline.
		_sprite.position.y += sin(_time*2.0) * 0.8
