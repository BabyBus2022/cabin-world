class_name Room
extends Node2D
## One room as a game scene: a floor, then furniture and people sorted by depth by the engine.

var scene_id := ""
var preview_only := false
var width := 0.0
var height := 0.0
var _built := false
var _clock := 0.0
var _light := {}
var _lamps: Array = []
var _lamp_at := -100.0
var _floor := _layer(0)
var _top := _layer(100)
const ScreenBlend = preload("res://entities/screen_light.gd")
var _glow := ScreenBlend.new()
var _light_copy := BackBufferCopy.new()
var _window_view: Node2D = null
var furniture := {}
const WindowScenery=preload("res://entities/window_scenery.gd")
var _scenery:Array=[]
var _weather_ground:Node2D

func _exit_tree() -> void:
	for layer in [_floor,_top,_glow,_light_copy]:
		if is_instance_valid(layer) and layer.get_parent()==null:layer.free()


static func _layer(z: int) -> Node2D:
	var n := Node2D.new()
	n.z_index = z
	n.y_sort_enabled = false
	return n


func setup(id: String) -> void:
	scene_id = id
	width = WorldData.scenes[id]["width"]
	height = WorldData.scenes[id]["height"]
	y_sort_enabled = true
	visible = false
	if not preview_only:load("res://entities/service_npc.gd").mount(self,id)


## Art loads the first time the room is looked at.
func build() -> void:
	if _built:
		return
	_built = true
	_light = Daylight.reading(RoomLight.now_ms())
	if scene_id=="xiaojingyu-home":_light=SeasideEnvironment.lighting(_light)
	if WorldData.scenes[scene_id].get("enclosed",false):_light.darkness=0.03;_light.beamAlpha=0.0;_light.tintAlpha=0.0
	var manifest: Dictionary = WorldData.layers[scene_id]
	var ground:Node2D
	if manifest.ground.has("registration"):
		ground=load("res://entities/registered_ground.gd").new()
		ground.texture=load("res://assets/baked/"+str(manifest.ground.file))
		ground.xs=manifest.ground.registration.x
		ground.ys=manifest.ground.registration.y
	else:
		ground = _sprite(manifest["ground"]["file"])
	ground.position = Vector2(manifest["ground"]["x"], manifest["ground"]["y"])
	add_child(ground)
	# Local architectural patches preserve the original ground and unrelated scenery.
	for patch in manifest.ground.get("patches",[]):
		var overlay:Node2D=load("res://entities/registered_ground.gd").new()
		overlay.texture=load("res://assets/baked/"+str(patch.file))
		overlay.xs=patch.registration.x
		overlay.ys=patch.registration.y
		add_child(overlay)
	if scene_id=="xiaojingyu-home":
		_weather_ground=Node2D.new();_weather_ground.draw.connect(func():SeasideEnvironment.draw_ground(_weather_ground));add_child(_weather_ground)
	_light_copy.z_index = 101
	_light_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_glow.z_index = 102
	_floor.draw.connect(func():
		if scene_id=="xiaojingyu-home":SeasideEnvironment.draw_floor(_floor,_light)
		else:RoomLight.draw_floor(_floor, scene_id, _light, Vector2(width, height)))
	_top.draw.connect(_draw_top)
	add_child(_floor)
	add_child(_top)
	add_child(_light_copy)
	add_child(_glow)
	for layer in manifest["layers"]:
		var module_id := str(layer.get("id",str(layer.file).trim_prefix(scene_id+".").trim_suffix(".png")))
		if layer.get("procedural","")=="speaker":
			var speaker:Node2D=load("res://entities/room_speaker.gd").new()
			speaker.setup(scene_id,layer)
			add_child(speaker)
			furniture[module_id]=speaker
			continue
		# Live scenes mount animated mechanisms below; the inert editor needs their baked previews.
		if not preview_only and scene_id=="qianxia-park" and module_id in ["swing","seesaw","rider","carousel"]: continue
		var s := _sprite(layer["file"])
		# Sorted on its depth line, drawn where the art really is.
		var depth: float = layer["depth"]
		s.position = Vector2(layer["x"], depth)
		s.offset = Vector2(0, (float(layer["y"]) - depth) * 2.0)
		if str(layer["file"]).begins_with("roomkit:"): # own pixel scale instead of the baked 0.5
			s.scale = Vector2.ONE * float(layer.get("scale", 1.0))
			s.offset = Vector2(0, (float(layer["y"]) - depth) / s.scale.y)
		elif layer.get("fit_art",false):
			if layer.has("region"):
				var region:Array=layer.region
				s.region_enabled=true
				s.region_rect=Rect2(region[0],region[1],region[2],region[3])
			var pixels:Vector2=s.region_rect.size if s.region_enabled else s.texture.get_size()
			s.scale=Vector2(layer.w,layer.h)/pixels
			s.offset=Vector2(0,(float(layer.y)-depth)/s.scale.y)
		add_child(s)
		furniture[module_id]=s
		if WorldData.scenes[scene_id].modules.get(module_id,{}).get("kind")=="seaside-tank":
			var fish:Node2D=load("res://entities/aquarium_life.gd").new()
			fish.scene=scene_id;fish.scale=Vector2(2,2)
			fish.position=Vector2(0,(float(layer.y)-depth)*2)
			s.add_child(fish)
		_add_window_view(layer, depth)
	if preview_only:
		process_mode=Node.PROCESS_MODE_DISABLED
		return
	ArcadeScreen.mount(self, scene_id)
	WorldMechanism.mount(self, scene_id)
	AmbientArt.mount(self, scene_id)
	FurnitureState.mount(self,scene_id,WorldPresentation.facts().scenes[scene_id].modules,furniture)


## The view through the glass sits right over the window itself, behind everything in front of it.
func _add_window_view(layer: Dictionary, depth: float) -> void:
	if not scene_id in RoomLight.HOMES:
		return
	var id := str(layer.get("id",str(layer["file"]).trim_prefix(scene_id + ".").trim_suffix(".png")))
	var m = WorldData.scenes[scene_id]["modules"].get(id)
	if not m is Dictionary or m.get("kind") != "window":
		return
	_window_view = Node2D.new()
	_window_view.position = Vector2(0, depth + 0.01)
	_window_view.draw.connect(func():
		_window_view.draw_set_transform(Vector2(0, -(depth + 0.01)))
		RoomLight.draw_window(_window_view, m, _light, SharedFeed.weather, _clock))
	add_child(_window_view)


func _process(delta: float) -> void:
	if not visible or not _built:
		return
	_clock += delta
	_light = Daylight.reading(RoomLight.now_ms())
	if WorldData.scenes[scene_id].get("enclosed",false):_light.darkness=0.03;_light.beamAlpha=0.0;_light.tintAlpha=0.0
	if scene_id=="xiaojingyu-home":
		_light=SeasideEnvironment.lighting(_light)
		_weather_ground.queue_redraw()
	for entry in _scenery:WindowScenery.update(entry.sprite,entry.kind,RoomLight.now_ms(),SeasideEnvironment.state())
	_floor.queue_redraw()
	_top.queue_redraw()
	_draw_glow()
	if _window_view:
		_window_view.queue_redraw()


func _draw_top() -> void:
	if WorldData.scenes[scene_id].get("enclosed",false):
		_draw_routes();return
	if scene_id=="xiaojingyu-home":
		SeasideEnvironment.draw_top(_top,_light,_clock)
		_draw_routes()
		return
	var size := Vector2(width, height)
	var weather = SharedFeed.weather
	if WorldData.scenes[scene_id]["outdoor"] == true and weather is Dictionary:
		RoomLight.draw_weather(_top, weather, size, _clock)
	RoomLight.draw_air(_top, scene_id, _light, _clock)
	RoomLight.draw_tint(_top, scene_id, _light, size)
	_draw_routes()

func _draw_routes() -> void:
	Wayfinding.draw(_top,scene_id,Vector2(width,height))


func _draw_glow() -> void:
	var size:=Vector2(width,height)
	var modules: Dictionary=WorldData.scenes[scene_id].modules
	var identified: Array=modules.keys().map(func(id):return modules[id].merged({"id":id}))
	var sources:=ScreenBlend.lamps(identified,RoomLight.lamp_settings(scene_id),float(_light.darkness),size,RoomLight.now_ms())
	for person in get_tree().get_nodes_in_group("world_residents"):
		if person._home.get("scene")!=scene_id:continue
		var computer: Dictionary=person.body.get("computer",{})
		var mode:=str(computer.get("screen","off"))
		for m in WorldData.scenes[scene_id].modules.values():
			if m.get("kind")!="computer" or mode=="off":continue
			var flick:=0.85+0.15*sin(_clock*7.3)*sin(_clock*2.1) if mode=="video" else 1.0
			var seated: bool=person.scene_id==scene_id and person.want_zone=="video" and person.stage.get("front")=="chair"
			sources.append(ScreenBlend.prop(Vector2(m.x+m.w*.53,m.y+m.h*.2),78 if seated else 56,Color(176.0/255,206.0/255,1),(.03+float(_light.darkness)*.34)*flick))
		if person.scene_id==scene_id and str(person.stage.get("pose","")).begins_with("phone") and not person.is_walking():
			var head: Rect2=person._visual_head
			sources.append(ScreenBlend.prop(person._display+Vector2(head.position.x+head.size.x*.5,head.position.y+head.size.y*1.35),16,Color(190.0/255,220.0/255,1),float(_light.darkness)*.45))
	var asleep:=RoomLight.sleeping_in(scene_id)
	if asleep:sources.clear()
	for id in furniture:
		if modules.get(id,{}).get("light") is Dictionary:
			var settings:=RoomLight.lamp_settings(scene_id)
			var on:=Daylight.light_enabled(str(settings.get(id,settings.lamps)),float(_light.darkness))
			furniture[id].self_modulate=Color.WHITE if on else Color(.32,.37,.46,1)
	_glow.update_lights(size,sources)


func _sprite(file: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	if file.begins_with("roomkit:"): # roomkit art lives outside res:// (see core/roomkit_items.gd); the caller sets scale/offset
		s.texture = load("res://core/roomkit_items.gd").texture_for(file.trim_prefix("roomkit:"))
		return s
	s.texture = load("res://assets/baked/" + file)
	if scene_id=="xiaojingyu-home" and file in ["../seaside/ground-dynamic.png","../seaside/xj-window.png"]:
		var kind:="ground" if "ground-dynamic" in file else "curtain"
		_scenery.append({"sprite":s,"kind":kind})
		WindowScenery.update(s,kind,RoomLight.now_ms(),SeasideEnvironment.state())
	s.scale = Vector2(0.5, 0.5) # baked at twice the room's size
	return s
