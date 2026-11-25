extends Control
## Builds the game: background, rooms, residents and interface. Everything else lives in its own entity.
## Test mode (no clicks needed): -- --seconds N --trace file --shot file --scene id --data folder

const NAVY := Color("1f2a4d")
const NAVY_L := Color("232f55")
const WAVE := Color("2b3a64")

var rooms := {}
var characters: Array[Character] = []
var follow := 0
var _walk_follow := -1
var _follow_clock := 0.0
var _follow_door := ""
var view_scene := "qianxia-home"

var _hud: Hud
var _settings: Control ## WorldSettings, or the 1.0 panel when the settings-ui module is off (core/features.gd)
var _display: FixedWindow
var _landscape: Landscape
var _petals: CPUParticles2D
var _view: Control
var _dock: Dock
var _arcade: ArcadePanel
var _arcade_show := false
var _music: Node ## 2026-11-21 Claude: scene music (core/cabin_music.gd, assets/music-rules.json)
var observing := false
var _stage: Node2D
var _room_camera:Node
var _observer:Node   ## 2026-11-21 Claude (observer-view): 观察者模式的镜头（玩家模式下完全不做事）
var _observer_return_scene := ""   ## 2026-11-21 Claude (observer2): 观察者去清溪村之前看的那个房间
var _observer_leaving := false     ## 正在收村子（淡出），期间不重复触发
var _observer_pending := ""        ## 收村子期间又来了一个"去某处"，收完再去那里
var _restaurant:Node
var _home_editor:Control
var _home_editor_notice:AcceptDialog
var _map_editor:Control ## separate map editor, opened from Settings (see ui/map_editor.gd)
var _map_notice:AcceptDialog
const Player = preload("res://entities/player_character.gd")
var local_player: Player
var player_controls
var qingxi_host ## 2026-11-19 Claude: 清溪村 as a map (core/qingxi_host.gd); null when 清溪村 is not in the pack

var _test_seconds := -1.0
var _trace_file: FileAccess
var _shot := ""
var _test_scene := ""
var _test_poke := ""
var _test_pick := -1
var _test_clock := 0.0
var _next_log := 0.0


# Public installation choices are read once, before mounting rooms.
var selected_shaders: Array = []
func release_on(id:String)->bool:
	return Features.on(id)

func read_release_options()->void:
	Features.load_flags()
	var base="res://qingxi-live/village-center/"
	for row in [["water12","flat-build/pond_glints"],["water12","village_river"],["wind12","garden_crop"],["wind12","rice"],["flame12","village_embers"],["flame12","lantern_glass"],["window12","../cottage_glass"],["window12","../seedshop-study/window_glass"]]:
		if not release_on(row[0]):
			var shader=load(base+row[1]+".gdshader")
			if shader:
				shader.code=shader.code.replace("TIME","0.0")
				if row[1]=="rice":shader.code=shader.code.replace("age*","0.0*")
				selected_shaders.append(shader)
func _ready() -> void:
	read_release_options()
	install_default_whale()
	if "--home-editor" in OS.get_cmdline_user_args():
		get_tree().call_deferred("change_scene_to_file", "res://ui/home_editor.tscn")
		return
	if "--map-cli" in OS.get_cmdline_user_args(): ## AI / script map commands, no window needed (core/map_commands.gd, docs/MAP-AI-COMMANDS.md)
		get_tree().quit(load("res://core/map_commands.gd").cli(OS.get_cmdline_user_args()))
		return
	if "--map-editor" in OS.get_cmdline_user_args(): ## standalone map editor (also used by tests)
		get_tree().call_deferred("change_scene_to_file", "res://ui/map_editor.tscn")
		return
	load("res://core/resident_registry.gd").restore()
	WorldData.resident_registered.connect(_resident_registered)
	WorldData.resident_removed.connect(_resident_removed)
	WorldData.resident_named.connect(func(_key):_hud.queue_redraw();_layout())
	_display = FixedWindow.new()
	add_child(_display)
	get_window().title = "小屋世界"
	if not WorldData.scenes.has(view_scene): view_scene = str(Residents.people()[0]["start"][0])
	_read_arguments()
	if _test_scene!="" and WorldData.scenes.has(_test_scene):
		view_scene=_test_scene;follow=-1
	_build_background()
	_landscape = Landscape.new()
	add_child(_landscape)
	_build_petals()
	_hud = Hud.new()
	add_child(_hud)
	_hud.scene_picked.connect(_on_scene_picked)
	_hud.character_picked.connect(_on_character_picked)
	_hud.follow_picked.connect(_on_follow_picked)
	_hud.room_clicked.connect(_on_room_clicked)
	_view = Control.new()
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	_stage = Node2D.new()
	_view.add_child(_stage)
	_room_camera=load("res://entities/room_camera.gd").new()
	add_child(_room_camera)
	_room_camera.setup(self)
	_observer=load("res://entities/observer_view.gd").new()
	add_child(_observer)
	_observer.setup(self)
	if release_on("map12"):
		var minimap=preload("res://ui/observer_room_map.gd").new()
		minimap.name="ObserverRoomMap"
		minimap.setup(self)
		add_child(minimap)
	_dock = Dock.new()
	add_child(_dock)
	_arcade = ArcadePanel.new()
	add_child(_arcade)
	## 2026-11-21 Claude: scene music for Cabin World. Its rules live in assets/music-rules.json;
	## it polls view_scene and the 清溪村 host, so it needs no hook in _show_room.
	if release_on("music12"):
		_music = load("res://core/cabin_music.gd").new()
		add_child(_music)
		_music.setup(self)
	for id in WorldData.available_order():
		var room := Room.new()
		room.setup(id)
		_stage.add_child(room)
		rooms[id] = room
	## 2026-11-20 Claude (qingxi-residents): 清溪村 as a place residents reach by bus (no room picture). Before they wake, so one who was there wakes there.
	if release_on("village12") and ResourceLoader.exists("res://qingxi-live/village-center/main.tscn"): load("res://core/qingxi_host.gd").register_place(self)
	for person in Residents.people():
		_make_character(person["key"], person["name"], person["art"])
	for c in characters:
		c.wake()
	for resident in characters:
		resident.neighbours = characters
	_hud.characters = characters
	if WorldData.scenes.has("world-restaurant"):
		_restaurant=load("res://entities/restaurant_service.gd").new()
		add_child(_restaurant);_restaurant.setup(self)
	_settings = WorldSettings.new() if Features.on("settings-ui") else load("res://ui/classic/settings_panel_1_0.gd").new()
	_settings.display = _display
	var settings_layer:=CanvasLayer.new();settings_layer.name="SettingsLayer";settings_layer.layer=20;add_child(settings_layer)
	settings_layer.add_child(_settings)
	_hud.settings_picked.connect(_settings.open)
	_settings.furniture_requested.connect(_open_home_editor)
	if _settings.has_signal("map_requested"):_settings.connect("map_requested",_open_map_editor)
	_settings.refresh_requested.connect(func():SharedFeed.poll();_dock.refresh())
	_settings.player_mode_requested.connect(set_player_mode)
	_settings.player_mode_active = not observing
	SharedFeed.presence_changed.connect(_on_presence)
	Actions.phase_started.connect(_on_action_phase)
	Actions.action_ended.connect(_on_action_ended)
	VadsLink.walk_ordered.connect(_on_walk_ordered)
	VadsLink.connection_changed.connect(func(on: bool):
		if on:
			for c in characters:
				if c != local_player:c.report_position()
			if is_instance_valid(local_player):local_player.publish_player())
	SharedFeed.poll()
	resized.connect(_layout)
	_show_room(view_scene)
	local_player = Player.new()
	local_player.setup(Residents.PLAYER, "你", "tuantuan-player")
	load("res://ui/player_skin_settings.gd").mount(self,_settings)
	local_player.room_changed.connect(_on_room_changed)
	rooms[view_scene].add_child(local_player)
	player_controls = load("res://ui/player_controls_public.gd").new()
	add_child(player_controls)
	player_controls.setup(self, local_player)
	var game_modal:=CanvasLayer.new();game_modal.name="ArcadeOverlay";game_modal.layer=18
	add_child(game_modal)
	player_controls.arcade.reparent(game_modal,false)
	var mode := ConfigFile.new()
	mode.load(player_mode_file())
	set_player_mode(bool(mode.get_value("player", "enabled", true)), false)
	## 2026-11-19 Claude: 清溪村, reached by bus from the park, shown inside the world frame.
	if release_on("village12") and ResourceLoader.exists("res://qingxi-live/village-center/main.tscn"):
		qingxi_host = load("res://core/qingxi_host.gd").new()
		add_child(qingxi_host)
		qingxi_host.setup(self)
	_layout()
	_warm_room_art.call_deferred()
	if "--open-layout" in OS.get_cmdline_user_args():
		follow=-1;_show_room(HomeGrid.requested_scene());_open_home_editor()

func player_mode_file() -> String:
	return Economy.save_path.get_base_dir().path_join("player-mode.cfg")

func set_player_mode(active: bool, persist := true) -> void:
	if active and not release_on("body12"):
		active=false
		persist=false
	if not is_instance_valid(local_player):
		return
	if persist:
		var config := ConfigFile.new()
		config.set_value("player","enabled",active)
		if config.save(player_mode_file()+".tmp") != OK or DirAccess.rename_absolute(player_mode_file()+".tmp",player_mode_file()) != OK:
			player_controls.tell("模式设置保存失败")
			return
	_walk_follow = -1
	var resuming := active and observing
	var watched_room := view_scene
	var in_village:bool = qingxi_host != null and qingxi_host.active
	if resuming and in_village:
		qingxi_host.resume_observed_position()
	if resuming and not in_village and WorldData.scenes.has(watched_room):
		# Disabling the player keeps their feet but clears placed. Restore placement
		# before enabling them, so the first-time park spawn cannot replace the view.
		if local_player.scene_id == watched_room:
			local_player.placed = true
		else:
			local_player.want_scene = watched_room
			local_player.want_zone = ""
			local_player._place_first()
	follow = -1
	observing = not active
	_settings.player_mode_active = active
	if active and not characters.has(local_player):
		characters.append(local_player)
	elif not active:
		characters.erase(local_player)
	for c in characters:
		c.neighbours = characters
	_hud.characters = characters
	player_controls.set_player_mode(active)
	## 2026-11-21 Claude (observer-view): 观察者的镜头跟着开关一起同步；清溪村那边决定是留下看还是回公园。
	if is_instance_valid(_observer): _observer.sync()
	if qingxi_host != null: qingxi_host.on_mode_changed(active)
	if active:
		Economy._answer({"actor":Residents.PLAYER,"op":"top_up","id":"player-start-"+str(Time.get_ticks_usec())})
		# 2026-11-21（业主）：从观察者切回玩家模式要停在刚才看的那个房间，不要把人拽回自己原来的房间。
		if qingxi_host != null and qingxi_host.active:
			_layout()
			return
		var want := view_scene
		if is_instance_valid(local_player) and want != "" and want != local_player.scene_id and WorldData.scenes.has(want):
			local_player.want_scene = want
			local_player.want_zone = ""
			local_player._place_first()
		_show_room(local_player.scene_id)
	_layout()

func _exit_tree() -> void:
	if is_instance_valid(local_player):local_player.remember_if_moved()


func _open_home_editor() -> void:
	if is_instance_valid(_home_editor):
		_home_editor.request_exit()
		return
	if view_scene not in ["xiaojingyu-home","world-arcade","world-restaurant","qianxia-park","qianxia-shop"] and not HomeGrid.definitions.has(view_scene):
		_home_editor_message("请先切换到公园、小卖部、小鲸鱼家、电玩城或餐厅，再按 F6 布置家具。")
		return
	_settings.close()
	HomeGrid.choose(view_scene);HomeGrid.load_saved()
	_home_editor=load("res://ui/home_editor.tscn").instantiate()
	_home_editor.embedded=true
	_home_editor.saved_layout.connect(_apply_home_layout)
	_home_editor.exit_requested.connect(_close_home_editor)
	_view.hide()
	add_child(_home_editor)

## Map editor: independent of the furniture editor. Finds the roomkit folder from --roomkit, or next to the project / executable.
func _roomkit_dir() -> String:
	var args:=OS.get_cmdline_user_args();var i:=args.find("--roomkit")
	if i>=0 and i+1<args.size():return args[i+1]
	for base in [ProjectSettings.globalize_path("res://").path_join("../roomkit"),OS.get_executable_path().get_base_dir().path_join("roomkit"),OS.get_executable_path().get_base_dir().get_base_dir().path_join("roomkit"),OS.get_executable_path().get_base_dir().get_base_dir().get_base_dir().path_join("roomkit")]:
		if DirAccess.dir_exists_absolute(str(base).path_join("rooms")):return str(base).simplify_path()
	return ""

func _open_map_editor() -> void:
	if is_instance_valid(_map_editor):
		_map_editor.request_exit()
		return
	## The new map editor (phase 3, docs/MAP-EDITOR-DESIGN.md) needs no roomkit folder: it saves maps in its own folder.
	_settings.close()
	_map_editor=load("res://ui/map_editor.tscn").instantiate()
	_map_editor.embedded=true;_map_editor.scene_hint=view_scene
	_map_editor.exit_requested.connect(_close_map_editor)
	_view.hide()
	add_child(_map_editor)

func _close_map_editor() -> void:
	if not is_instance_valid(_map_editor):return
	_map_editor.hide();_map_editor.set_process_input(false);_map_editor.queue_free()
	_map_editor=null
	_view.show()
	_layout()

func _close_home_editor() -> void:
	if not is_instance_valid(_home_editor):return
	_home_editor.hide();_home_editor.set_process_input(false);_home_editor.queue_free()
	_home_editor=null
	_view.show()
	_layout()

func _apply_home_layout(value:Dictionary) -> void:
	var id:String=value.scene
	if id=="world-restaurant" and _restaurant!=null:
		for actor in _restaurant.jobs.keys():_restaurant.cancel(actor,"餐厅布置已更新，请重新安排；已拿到的菜保留在背包")
	var previous:Dictionary=WorldData.scenes[id]
	HomeGrid.apply(value)
	var old:Room=rooms[id]
	var replacement:=Room.new();replacement.setup(id);_stage.add_child(replacement)
	rooms[id]=replacement
	for c in characters:
		c._home=Residents.person(c.key).get("home",{})
		c._pieces=Residents.person(c.key).get("pieces",{})
		if c.scene_id==id:
			c.reparent(replacement,false)
			c.rebase_layout(previous)
	old.free()
	if view_scene==id:replacement.build();replacement.visible=true
	_layout()

func _home_editor_message(text:String) -> void:
	if not is_instance_valid(_home_editor_notice):
		_home_editor_notice=AcceptDialog.new();_home_editor_notice.title="布置家具";add_child(_home_editor_notice)
	_home_editor_notice.dialog_text=text;_home_editor_notice.popup_centered()

func _unhandled_key_input(event:InputEvent) -> void:
	if qingxi_busy(): return ## 2026-11-19 Claude: keys belong to 清溪村 (its F6 is a test key there)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F6:
		if not WorldData.scenes.has("xiaojingyu-home"):return
		_open_home_editor();get_viewport().set_input_as_handled()

func _read_arguments() -> void:
	var args := OS.get_cmdline_user_args()
	for i in range(0, args.size() - 1):
		match args[i]:
			"--seconds":
				_test_seconds = float(args[i + 1])
			"--trace":
				_trace_file = FileAccess.open(args[i + 1], FileAccess.WRITE)
			"--shot":
				_shot = args[i + 1]
			"--scene":
				_test_scene = args[i + 1]
			"--now":
				RoomLight.test_now = float(args[i + 1])
			"--weather":
				SharedFeed.weather = JSON.parse_string(args[i + 1])
			"--light-table":
				_write_light_table(args[i + 1])
			"--poke":
				_test_poke = args[i + 1]
			"--pick":
				_test_pick = int(args[i + 1])


## Test support: the daylight reading at every time listed in a file, to compare with VADS.
func _write_light_table(file: String) -> void:
	var times = JSON.parse_string(FileAccess.get_file_as_string(file))
	var rows: Array = []
	for t in times:
		rows.append(Daylight.reading(float(t)))
	var f := FileAccess.open(file + ".out", FileAccess.WRITE)
	f.store_string(JSON.stringify(rows, "", false, true))
	f.close()


func _build_background() -> void:
	var image := Image.create(32, 16, false, Image.FORMAT_RGB8)
	image.fill(NAVY)
	for r in range(-2, 6):
		var cy := r * 4.0 + 2.0
		var off := 8.0 if (r & 1) != 0 else 0.0
		var cx := off - 16.0
		while cx <= 32.0:
			for y in range(-8, 16):
				for x in range(-8, 24):
					var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
					if d > 8.0 or y + 0.5 > cy:
						continue
					var ring := int(d) % 3
					var c := WAVE if ring == 2 else (NAVY_L if ring == 1 else NAVY)
					var px := posmod(x, 16) * 2
					var py := posmod(y, 8) * 2
					image.fill_rect(Rect2i(px, py, 2, 2), c)
			cx += 16.0
	var back := TextureRect.new()
	back.texture = ImageTexture.create_from_image(image)
	back.stretch_mode = TextureRect.STRETCH_TILE
	back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)


func _build_petals() -> void:
	var p := CPUParticles2D.new()
	p.amount = 40
	p.lifetime = 26.0
	p.preprocess = 26.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2(0.35, 1.0)
	p.spread = 12.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 40.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	p.color = Hud.PINK
	p.position = Vector2.ZERO
	add_child(p)
	_petals = p


func _resident_registered(key:String)->void:
	var person:=Residents.person(key)
	var id:String=person.home.scene
	if rooms.has(id):
		rooms[id].queue_free()
	var room:=Room.new();room.setup(id);_stage.add_child(room);rooms[id]=room
	if not characters.any(func(c):return c.key==key):
		var c:=_make_character(key,person.name,person.art)
		c.wake()
	else:
		for c in characters:
			if c.key==key:c._home=person.home
	for c in characters:c.neighbours=characters
	_hud.characters=characters;_hud.queue_redraw()
	if view_scene==id:_show_room(id)
	_layout()

func _resident_removed(key:String,scene:String)->void:
	if is_instance_valid(_home_editor):_close_home_editor()
	follow=-1
	if view_scene==scene:_show_room("qianxia-park")
	for c in characters.duplicate():
		if c.key==key:characters.erase(c);c.queue_free()
	for c in characters:c.neighbours=characters
	if rooms.has(scene):rooms[scene].queue_free();rooms.erase(scene)
	_hud.characters=characters;_hud.queue_redraw();_layout()

func _make_character(key: String, display_name: String, art: String) -> Character:
	var c := Character.new()
	c.setup(key, display_name, art)
	c.room_changed.connect(_on_room_changed)
	characters.append(c)
	rooms[view_scene].add_child(c) # moves to her real room as soon as she is placed
	return c


func _on_presence(presence: Dictionary) -> void:
	for c in characters:
		if presence.has(c.key):
			c.apply_presence(presence[c.key])


func _on_action_phase(actor: String, phase: String, text: String, pose: int) -> void:
	for c in characters:
		if c.key == actor:
			c.set_action(phase, text, pose)
	_hud.queue_redraw()


func _on_walk_ordered(frame: Dictionary) -> void:
	for c in characters:
		if c != local_player and c.key == str(frame.get("actor", "")):
			c.walk_order(frame)


func _on_action_ended(actor: String) -> void:
	for c in characters:
		if c.key == actor:
			c.set_action("", "")
	_hud.queue_redraw()


func _on_room_changed(c: Character) -> void:
	var room: Room = rooms[c.scene_id]
	if c.get_parent():
		c.reparent(room, false)
	else:
		room.add_child(c)
	c.position = c.feet
	if c == local_player and qingxi_busy(): return
	if (c == local_player and not observing and follow < 0) or (follow >= 0 and characters[follow] == c):
		_show_room(c.scene_id)


## Poking: clicking a character in the room shows her mood. Same hit area as the old panel.
func _on_room_clicked(at: Vector2) -> void:
	if qingxi_busy(): return ## 2026-11-19 Claude: the frame shows 清溪村 (or the bus is moving)
	var p := (at-_stage.position) / _stage.scale.x
	var best: Character = null
	var best_d := 30.0
	for c in characters:
		if not c.placed or c.scene_id != view_scene:
			continue
		var d := absf(p.x - c.feet.x)
		if d < best_d and p.y > c.feet.y - 78.0 and p.y < c.feet.y + 8.0:
			best_d = d
			best = c
	if best != null:
		if player_controls and player_controls.allows_input() and best != local_player and Economy.Social.near(local_player.key, best.key):
			player_controls.open_peer(best.key)
			return
		best.poke()
		return
	# 2026-11-20 业主：玩家模式取消左键点地行走，移动只用 WASD/方向键。点 NPC、点家具、点地块等真实交互保留。
	var object := ""
	for row in WorldData.objects:
		if WorldData.scene_of_space(str(row.get("space","")))!=view_scene:continue
		for id in WorldPresentation.facts().get("objectModules",{}).get(row.id,[]):
			var definition: Dictionary=WorldPresentation.facts().scenes[view_scene].modules.get(id,{})
			if not definition.is_empty() and Rect2(definition.x,definition.y,definition.w,definition.h).has_point(p):object=str(row.id)
	if object!="":_dock.show_object(view_scene,object)


## 2026-11-19 Claude: while in 清溪村, Cabin World tabs and cards first take the bus back to the park.
func qingxi_busy() -> bool:
	return qingxi_host != null and qingxi_host.busy()

func _on_scene_picked(id: String) -> void:
	_cancel_walk_follow()
	if qingxi_busy():
		## 2026-11-21 Claude (observer2): 观察者正在清溪村里看时，点小屋世界的标签 = 真的去那个房间
		## （不是被顺手扔回公园）；点清溪村自己的地方（qx:...）仍然交给 qingxi_host 在村里换地方。
		## _spectating() 只在 spectator 时成立，玩家模式永远不会进这一支。
		if _spectating() and not id.begins_with("qx:"):
			follow = -1
			_show_room(id)
			return
		qingxi_host.pick(id);return ## a 清溪村 place, the bus home, or a Cabin World tab (bus first)
	if is_instance_valid(local_player) and local_player.player_enabled:
		follow = -1
		_show_room(local_player.scene_id)
		player_controls.travel(id)
		return
	follow = -1
	_show_room(id)


func _on_character_picked(index: int) -> void:
	_cancel_walk_follow()
	follow = -1
	# 2026-11-21（业主）：人在清溪村时点人物卡片，绝不该把人扔回公园。
	# 以前这里 qingxi_busy() 且非观察者就 request_leave() —— 玩家模式下点她一下 = 坐公交回公园。
	# 现在：人在村里只更新面板，不切房间、不坐车。
	if qingxi_busy():
		_hud.follow = follow
		_hud.queue_redraw()
		return
	if index >= 0 and index < characters.size() and characters[index].placed:
		_show_room(characters[index].scene_id)
	_hud.follow = follow
	_hud.queue_redraw()


func _on_follow_picked(index: int) -> void:
	if not observing:
		var old:=_walk_follow
		_cancel_walk_follow()
		if index!=old and index>=0 and index<characters.size() and characters[index]!=local_player:
			_walk_follow=index
			player_controls.stop_activity()
			if not qingxi_busy():_show_room(local_player.scene_id)
			_player_follow_tick()
		_hud.follow=_walk_follow
		_hud.queue_redraw()
		return
	follow = -1 if follow == index else index

	if follow >= 0 and follow < characters.size() and characters[follow].placed:
		_show_room(characters[follow].scene_id)
	_hud.follow = follow
	_hud.queue_redraw()


func _cancel_walk_follow() -> void:
	if _walk_follow>=0 and is_instance_valid(local_player):
		local_player.stop_navigation()
	_walk_follow=-1
	_follow_door=""

func _player_follow_tick() -> void:
	if _walk_follow<0 or _walk_follow>=characters.size() or observing:return
	var c:=characters[_walk_follow]
	if not is_instance_valid(c) or not c.placed or qingxi_host.transit:return
	if local_player.direction_input!=Vector2.ZERO:
		_cancel_walk_follow()
		_hud.follow=-1
		_hud.queue_redraw()
		return
	if qingxi_host.active:
		if c.scene_id!=qingxi_host.PLACE:qingxi_host.owner_bus_home()
		return
	var village:bool=c.scene_id==qingxi_host.PLACE
	var dest:String=qingxi_host.PARK if village else c.scene_id
	if local_player.scene_id!=dest:
		if local_player.want_scene!=dest and _follow_door!=dest:
			_follow_door=dest
			player_controls.travel(dest)
		return
	_follow_door=""
	var at:Vector2=qingxi_host.CURB if village else c.feet
	if local_player.feet.distance_to(at)<(24 if village else 29):
		if village:qingxi_host.board()
		return
	var nav:=WorldData.nav(dest)
	var heading:Vector2=at.direction_to(local_player.feet)
	for i in 8:
		var goal:=at if village else at+heading.rotated(i*TAU/8)*19
		if not nav.walkable(goal):continue
		if local_player._walk_point.is_finite() and local_player._walk_point.distance_to(goal)<14:return
		if not nav.route(local_player.feet,goal).is_empty() and local_player.click_walk(goal):return

## 观察者的镜头可以自由跟随住户。
func _spectating() -> bool:
	return qingxi_host != null and qingxi_host.spectator


## 2026-11-21 Claude (observer2): 观察者自己走去清溪村。**跟任何居民在哪完全无关** ——
## 两个都在家、两个都在清溪村，这条路都通。用的还是原来那套真村子（spectator，没有身体）。
func observer_enter_village() -> bool:
	if not observing or qingxi_host == null:
		return false
	if qingxi_host.active or qingxi_host.transit:
		return false
	if not WorldData.scenes.has(qingxi_host.PLACE):
		return false
	_observer_return_scene = view_scene
	if view_scene=="qianxia-park":
		qingxi_host.observer_bus_from_park()
		return true
	_show_room(qingxi_host.PLACE)
	return bool(qingxi_host.active)


## 观察者回小屋世界：回到进清溪村之前看的那个房间（不是一律扔回公园）。
func observer_leave_village() -> void:
	if qingxi_host == null or not qingxi_host.active:
		return
	var back := _observer_return_scene
	if back == "" or back == qingxi_host.PLACE or not WorldData.scenes.has(back):
		back = local_player.scene_id if is_instance_valid(local_player) and WorldData.scenes.has(local_player.scene_id) else "qianxia-park"
	follow = -1   ## 业主自己按"回小屋世界" = 不跟了
	if is_instance_valid(_hud):
		_hud.follow = -1
		_hud.queue_redraw()
	await _observer_leave_to(back)


## 收起清溪村（异步淡出）之后再去 id。keep_follow=true 用于"跟着她换世界"：
## 她离开村子时 follow 不能被 spectator_leave 顺手清掉。
func _observer_leave_to(id: String) -> void:
	if _observer_leaving:
		_observer_pending = id
		return
	_observer_leaving = true
	while qingxi_host.transit and qingxi_host.active:await get_tree().process_frame
	if qingxi_host.spectator and qingxi_host.active:
		qingxi_host.spectator_leave()   ## 它自己跑完会 _show_room(PARK)；下面等它真的收完
	var started := Time.get_ticks_msec()
	while qingxi_host.active and Time.get_ticks_msec() - started < 5000:
		await get_tree().process_frame
	_observer_leaving = false
	if is_instance_valid(_hud):
		_hud.follow = follow
		_hud.queue_redraw()
	var want := _observer_pending if _observer_pending != "" else id
	_observer_pending = ""
	if not observing and is_instance_valid(local_player) and WorldData.scenes.has(local_player.scene_id):
		want = local_player.scene_id   ## 切回玩家模式：回玩家自己的房间
	_show_room(want)


func _show_room(id: String) -> void:
	if qingxi_host != null:
		if qingxi_host.spectator and qingxi_host.active and id != qingxi_host.PLACE:
			## 2026-11-21 Claude (observer2): 收村子是异步的（0.25s 淡出），收完再进目标房间。
			## 这样"跟着她走"不会在半路把房间切两次，也不会因为 spectator_leave 而丢掉 follow。
			_observer_leave_to(id)
			return
		qingxi_host.watch_place(id) ## 2026-11-20 Claude (qingxi-residents): the 清溪村 card (observer), hidden for other rooms
		## 2026-11-21 Claude (observer-view): 观察者跟随到清溪村时，真的把村子打开给他看；
		## 玩家模式这条返回 false，行为与改动前一样（只有那张卡片）。
		if id == qingxi_host.PLACE and qingxi_host.watch_in_person():
			return
	if WorldData.scenes.get(id, {}).get("noRoom", false): return ## 2026-11-20 Claude (qingxi-residents): 清溪村 has no room picture
	view_scene = id
	for k in rooms:
		rooms[k].visible = k == id
	rooms[id].build()
	if _hud:
		_hud.view_scene = id
		_hud.follow = follow if observing else _walk_follow
		_hud.queue_redraw()
	if is_inside_tree():
		_layout()


func _layout() -> void:
	if _hud == null or _view == null:
		return
	# Wider than tall: room on the left, cards and records on the right.
	# Otherwise: room on top at full width, cards and records underneath. Nothing is left empty.
	var W := size.x
	var H := size.y
	var frame := 8.0
	var margin := 10.0
	_hud.navigation_layout(W)
	var top := _hud.tabs_bottom + 4.0
	var low := H - _hud.grass_height - 6.0
	var room: Room = rooms[view_scene]
	var side := W * 0.20
	var right := W - side - margin * 2.0
	var k := minf((right - margin - 2.0 * frame) / room.width, (low - top - 2.0 * frame) / room.height)
	var sw := room.width * k
	var sh := room.height * k
	var sx := floorf(margin + (right - margin - sw) / 2.0)
	var sy := floorf(top + (low - top - sh) / 2.0)
	var cx := W - side - margin
	_hud.layout_cards(Rect2(cx, top, side, 254.0))
	var dock_rect := Rect2(cx, top + 260.0, side, low - top - 260.0)
	_view.position = Vector2(sx, sy)
	_view.size = Vector2(sw, sh)
	_stage.scale = Vector2(k, k)
	_room_camera.configure(view_scene,Vector2(room.width,room.height),k,WorldData.scenes[view_scene])
	if is_instance_valid(_observer): _observer.sync()   ## 2026-11-21 Claude (observer-view): 只在观察者模式里接管 stage.position
	_hud.size = size
	_hud.frame_rect = Rect2(sx, sy, sw, sh)
	_hud.queue_redraw()
	_arcade_show = ArcadePanel.available(view_scene)
	_arcade.visible = _arcade_show
	if _arcade_show:
		var half := floorf((dock_rect.size.y - 6.0) / 2.0)
		_arcade.position = dock_rect.position
		_arcade.size = Vector2(dock_rect.size.x, half)
		dock_rect.position.y += half + 6.0
		dock_rect.size.y -= half + 6.0
	_dock.visible = dock_rect.size.y >= 120.0
	if _dock.visible:
		_dock.position = dock_rect.position
		_dock.size = dock_rect.size
	_landscape.size = size
	_landscape.queue_redraw()
	_petals.emission_rect_extents = Vector2(W / 2.0, 2.0)
	_petals.position = Vector2(W / 2.0, -4.0)
	if qingxi_host != null: qingxi_host.layout() ## 2026-11-19 Claude: keep 清溪村 inside the frame


## Rooms are built the first time they are shown, and their baked art used to load on the main thread then
## (a 50-220 ms hitch on the first visit to each scene). Load every scene's art on background threads right after
## start-up and keep a reference so Room's own load() finds it cached. Purely a cache: nothing is shown or changed.
var _warm_paths: Array = []
var _warm_held: Array = []
var _room_warm_complete:bool=false
var _keepsake_poll:float=0.0
var _keepsake_sent:Dictionary={}
func _warm_room_art() -> void:
	var seen := {}
	for id in WorldData.layers:
		var manifest = WorldData.layers[id]
		if not manifest is Dictionary: continue
		var files: Array = []
		if manifest.get("ground") is Dictionary: files.append(str(manifest.ground.get("file", "")))
		for layer in manifest.get("layers", []): files.append(str(layer.get("file", "")))
		for f in files:
			if f == "" or f.begins_with("roomkit:"): continue
			var p: String = "res://assets/baked/" + f
			if seen.has(p) or not ResourceLoader.exists(p): continue
			seen[p] = true
			if ResourceLoader.load_threaded_request(p) == OK: _warm_paths.append(p)
	await load("res://entities/scene_warmup.gd").run(self)
	_room_warm_complete=true

func _collect_warm_art() -> void:
	for i in range(_warm_paths.size() - 1, -1, -1):
		var status := ResourceLoader.load_threaded_get_status(_warm_paths[i])
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: continue
		if status == ResourceLoader.THREAD_LOAD_LOADED: _warm_held.append(ResourceLoader.load_threaded_get(_warm_paths[i]))
		_warm_paths.remove_at(i)

func _discover_keepsakes()->void:
	if not VadsLink.connected:_keepsake_sent.clear()
	for c in get_tree().get_nodes_in_group("world_residents"):
		if not c.placed or c.is_walking() or c.sleeping:continue
		var notes:Array=Economy.people.get(c.key,{}).get("keepsakes",{}).get("notes",[])
		if notes.any(func(n):return n.get("status")=="placed" and n.get("scene")==c.scene_id):
			Economy.answer({"id":"discovery-"+c.key+"-"+str(Time.get_ticks_usec()),"actor":c.key,"op":"keepsake","use":"discover","scene":c.scene_id})
		if not VadsLink.connected:continue
		# Replay durable discovery receipts after reconnect. The shared journal
		# deduplicates these IDs, even if a previous connection lost its reply.
		for note in notes:
			if not note.has("foundAt") or _keepsake_sent.has(note.id):continue
			VadsLink.send({"type":"economy.activity","actor":c.key,"id":"found-"+str(note.id),"at":note.foundAt,"action":"discover","name":"发现主人留下的心意","detail":note.text,"space":note.scene,"status":"complete"})
			_keepsake_sent[note.id]=true

func _process(delta: float) -> void:
	if _walk_follow>=0:
		_follow_clock-=delta
		if _follow_clock<=0:
			_follow_clock=.3
			_player_follow_tick()
	_keepsake_poll+=delta
	if _keepsake_poll>=1:
		_keepsake_poll=0
		pass # Retired keepsake discovery; preserve historical save records.
	if not _warm_paths.is_empty(): _collect_warm_art()
	if _arcade != null and _arcade_show != ArcadePanel.available(view_scene): _layout()
	if _test_seconds < 0.0:
		return
	_test_clock += delta
	if _trace_file and _test_clock >= _next_log:
		_next_log = _test_clock + 0.25
		var line := "%.2f" % _test_clock
		for c in characters:
			line += " | %s %s %.0f %.0f %s" % [c.key, c.scene_id, c.feet.x, c.feet.y, "walk" if c.is_walking() else "still"]
		_trace_file.store_line(line)
		_trace_file.flush()
	if _test_clock >= _test_seconds:
		_test_seconds = -1.0
		_finish_test()


func _finish_test() -> void:
	if _trace_file:
		_trace_file.store_line("# reads %d" % SharedFeed.reads)
		_trace_file.close()
	if _shot != "":
		if _test_scene != "":
			follow = -1
			_show_room(_test_scene)
		if _test_pick >= 0:
			_on_character_picked(_test_pick)
		for c in characters:
			if c.key == _test_poke:
				c.poke()
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shot)
	get_tree().quit()

func install_default_whale() -> void:
	if not Features.on("character-motion"):return
	var library=preload("res://core/appearance_packs.gd")
	var directory:String=library.directory()
	var active:=directory.path_join("active.json")
	var selections:Dictionary={}
	if FileAccess.file_exists(active):
		var saved=JSON.parse_string(FileAccess.get_file_as_string(active))
		if not saved is Dictionary or saved.has("xiaojingyu"):return
		selections=saved
	var id:="d975af110b464bdaa867d3ffa59655a8"
	var source:="res://starter-whale/"
	var manifest:=library.read_json(source+"appearance.json")
	if not manifest.has("actions"):return
	var dest:=directory.path_join("packs").path_join(id)
	var files:Dictionary={"appearance.json":true}
	for action in manifest.actions.values():
		for frame in action.frames:
			if not library.safe_frame(frame):return
			files[frame]=true
	for relative:String in files:
		var path:=dest.path_join(relative)
		if FileAccess.file_exists(path):continue
		if DirAccess.make_dir_recursive_absolute(path.get_base_dir())!=OK:return
		var bytes:=FileAccess.get_file_as_bytes(source+relative)
		if bytes.is_empty():return
		var target:=FileAccess.open(path+".tmp",FileAccess.WRITE)
		if target==null:return
		target.store_buffer(bytes)
		target.close()
		if DirAccess.rename_absolute(path+".tmp",path)!=OK:return
	var selected:=FileAccess.open(active+".tmp",FileAccess.WRITE)
	if selected!=null:
		selections["xiaojingyu"]=id
		selected.store_string(JSON.stringify(selections))
		selected.close()
		DirAccess.rename_absolute(active+".tmp",active)
