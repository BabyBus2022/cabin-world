extends Control
## Builds the game: background, rooms, residents and interface. Everything else lives in its own entity.
## Test mode (no clicks needed): -- --seconds N --trace file --shot file --scene id --data folder

const NAVY := Color("1f2a4d")
const NAVY_L := Color("232f55")
const WAVE := Color("2b3a64")

var rooms := {}
var characters: Array[Character] = []
var follow := 0
var view_scene := "qianxia-home"

var _hud: Hud
var _settings: WorldSettings
var _display: FixedWindow
var _landscape: Landscape
var _petals: CPUParticles2D
var _view: Control
var _dock: Dock
var _arcade: ArcadePanel
var _arcade_show := false
var observing := false
var _stage: Node2D
var _room_camera:Node
var _restaurant:Node
var _home_editor:Control
var _home_editor_notice:AcceptDialog

var _test_seconds := -1.0
var _trace_file: FileAccess
var _shot := ""
var _test_scene := ""
var _test_poke := ""
var _test_pick := -1
var _test_clock := 0.0
var _next_log := 0.0


func _ready() -> void:
	if "--home-editor" in OS.get_cmdline_user_args():
		get_tree().call_deferred("change_scene_to_file", "res://ui/home_editor.tscn")
		return
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
	_dock = Dock.new()
	add_child(_dock)
	_arcade = ArcadePanel.new()
	add_child(_arcade)
	for id in WorldData.available_order():
		var room := Room.new()
		room.setup(id)
		_stage.add_child(room)
		rooms[id] = room
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
	_settings = WorldSettings.new()
	_settings.display = _display
	add_child(_settings)
	_hud.settings_picked.connect(_settings.open)
	_settings.furniture_requested.connect(_open_home_editor)
	_settings.refresh_requested.connect(func():SharedFeed.poll();_dock.refresh())
	_settings.observe_requested.connect(func():observing=not observing;_layout())
	SharedFeed.presence_changed.connect(_on_presence)
	Actions.phase_started.connect(_on_action_phase)
	Actions.action_ended.connect(_on_action_ended)
	VadsLink.walk_ordered.connect(_on_walk_ordered)
	VadsLink.connection_changed.connect(func(on: bool):
		if on:
			for c in characters:
				c.report_position())
	SharedFeed.poll()
	resized.connect(_layout)
	_show_room(view_scene)
	_layout()
	_warm_room_art.call_deferred()
	if "--open-layout" in OS.get_cmdline_user_args():
		follow=-1;_show_room(HomeGrid.requested_scene());_open_home_editor()


func _open_home_editor() -> void:
	if is_instance_valid(_home_editor):
		_home_editor.request_exit()
		return
	if view_scene not in ["xiaojingyu-home","world-arcade","world-restaurant","qianxia-park","qianxia-shop"]:
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
		if c.key == str(frame.get("actor", "")):
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
	if follow >= 0 and characters[follow] == c:
		_show_room(c.scene_id)


## Poking: clicking a character in the room shows her mood. Same hit area as the old panel.
func _on_room_clicked(at: Vector2) -> void:
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
		best.poke()
		return
	var object := ""
	for row in WorldData.objects:
		if WorldData.scene_of_space(str(row.get("space","")))!=view_scene:continue
		for id in WorldPresentation.facts().get("objectModules",{}).get(row.id,[]):
			var definition: Dictionary=WorldPresentation.facts().scenes[view_scene].modules.get(id,{})
			if not definition.is_empty() and Rect2(definition.x,definition.y,definition.w,definition.h).has_point(p):object=str(row.id)
	if object!="":_dock.show_object(view_scene,object)


func _on_scene_picked(id: String) -> void:
	follow = -1
	_show_room(id)


func _on_character_picked(index: int) -> void:
	follow = -1
	if characters[index].placed:
		_show_room(characters[index].scene_id)
	_hud.follow = follow
	_hud.queue_redraw()


func _on_follow_picked(index: int) -> void:
	follow = -1 if follow == index else index
	if follow >= 0 and characters[follow].placed:
		_show_room(characters[follow].scene_id)
	_hud.follow = follow
	_hud.queue_redraw()


func _show_room(id: String) -> void:
	view_scene = id
	for k in rooms:
		rooms[k].visible = k == id
	rooms[id].build()
	if _hud:
		_hud.view_scene = id
		_hud.follow = follow
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
	var wide := true # fixed logical canvas; resizing never rearranges the interface
	var cards: Array[Rect2] = []
	var k := 1.0
	var sw := 0.0
	var sh := 0.0
	var sx := margin + frame
	var sy := top + frame
	var dock_rect := Rect2()
	if wide:
		var side := 0.0 if observing else W * 0.20
		var right := W - side - margin * 2.0
		k = minf((right - margin - 2.0 * frame) / room.width, (low - top - 2.0 * frame) / room.height)
		sw = room.width * k
		sh = room.height * k
		sx = floorf(margin + (right - margin - sw) / 2.0)
		sy = floorf(top + (low - top - sh) / 2.0)
		var cx := W - side - margin
		cards = [Rect2(cx, top, side, 124.0), Rect2(cx, top + 130.0, side, 124.0)]
		dock_rect = Rect2(cx, top + 260.0, side, low - top - 260.0)
	else:
		var cards_h := 116.0
		var room_limit := maxf(180.0, (low - top) * (0.58 if H >= 620.0 else 0.5))
		k = minf((W - margin * 2.0 - 2.0 * frame) / room.width, (room_limit - 2.0 * frame) / room.height)
		sw = room.width * k
		sh = room.height * k
		sx = floorf((W - sw) / 2.0)
		var y := top + sh + 2.0 * frame + 6.0
		var cw := (W - margin * 3.0) / 2.0
		cards = [Rect2(margin, y, cw, cards_h), Rect2(margin * 2.0 + cw, y, cw, cards_h)]
		dock_rect = Rect2(margin, y + cards_h + 6.0, W - margin * 2.0, low - y - cards_h - 6.0)
	_view.position = Vector2(sx, sy)
	_view.size = Vector2(sw, sh)
	_stage.scale = Vector2(k, k)
	_room_camera.configure(view_scene,Vector2(room.width,room.height),k,WorldData.scenes[view_scene])
	_hud.size = size
	if observing:cards.clear()
	_hud.card_rects = cards
	_hud.frame_rect = Rect2(sx, sy, sw, sh)
	_hud.queue_redraw()
	_arcade_show = ArcadePanel.available(view_scene)
	_arcade.visible = _arcade_show and not observing
	if _arcade_show:
		var half := floorf((dock_rect.size.y - 6.0) / 2.0)
		_arcade.position = dock_rect.position
		_arcade.size = Vector2(dock_rect.size.x, half)
		dock_rect.position.y += half + 6.0
		dock_rect.size.y -= half + 6.0
	_dock.visible = dock_rect.size.y >= 120.0 and not observing
	if _dock.visible:
		_dock.position = dock_rect.position
		_dock.size = dock_rect.size
	_landscape.size = size
	_landscape.queue_redraw()
	_petals.emission_rect_extents = Vector2(W / 2.0, 2.0)
	_petals.position = Vector2(W / 2.0, -4.0)


## Rooms are built the first time they are shown, and their baked art used to load on the main thread then
## (a 50-220 ms hitch on the first visit to each scene). Load every scene's art on background threads right after
## start-up and keep a reference so Room's own load() finds it cached. Purely a cache: nothing is shown or changed.
var _warm_paths: Array = []
var _warm_held: Array = []
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

func _collect_warm_art() -> void:
	for i in range(_warm_paths.size() - 1, -1, -1):
		var status := ResourceLoader.load_threaded_get_status(_warm_paths[i])
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: continue
		if status == ResourceLoader.THREAD_LOAD_LOADED: _warm_held.append(ResourceLoader.load_threaded_get(_warm_paths[i]))
		_warm_paths.remove_at(i)

func _process(delta: float) -> void:
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
