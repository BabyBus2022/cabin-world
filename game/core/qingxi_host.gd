extends CanvasLayer
## 2026-11-19 Claude: 清溪村 (Qingxi Village) as a map of Cabin World.
##
## How you get there: a bus stop stands on the lawn in the middle of the park (north-west of
## the crossroads). Press E at the stop, the bus pulls up, you get on, and you arrive at the
## bus stop in 清溪村's village centre. In 清溪村 the 车站 has "乘公交回小屋世界" (and the pause
## menu offers the same), which brings the bus back to the park.
##
## How it is shown (the owner's rules):
## * Only inside Cabin World's world frame (game._hud.frame_rect). Tabs, resident cards and
##   the log stay as they are; nothing of 清溪村 is drawn outside the frame.
## * 清溪村's camera scale is unchanged and the picture is crisp: the village renders into a
##   SubViewport at the frame's real screen pixels (this layer cancels Cabin World's
##   canvas_items stretch), with 2D content at an integer factor k (k = frame height / 432,
##   the same rule 清溪村 uses standalone with its 768x432 base and integer scaling) and
##   nearest-neighbour textures. No smooth scaling of the finished picture.
## * The live minimap is 清溪村's own HUD inside its view, so it only exists while you are in
##   清溪村; Cabin World does not show one.
##
## Interface used by the 清溪村 code (it looks for the tree meta "qingxi_world_host"):
##   controls(scene)            true while that 清溪村 scene has the keyboard
##   mount_scene(packed)        replaces the 清溪村 scene inside the view (its map changes)
##   loading_parent()           where its loading card goes (inside the view)
##   owner_bus_home()           take the bus back to the park
##   profile_path(file)         where 清溪村 saves live (Cabin World data/world/qingxi-saves)
##   local_hour()               Cabin World's clock (清溪村's time keys are off inside Cabin World)
##   rural_weather()            Cabin World's weather (real local weather or the Settings preview)
##   season_index() / season_progress() / date_label()   the real date, as Cabin World counts it
##   owner_art_root()           the player's look in 清溪村 = your Cabin World player (not 小鲸鱼)
##   owner_uses_travel_outfit() false
## Nothing here changes Cabin World saves; the Cabin World player only stands at the stop.
const VILLAGE := "res://qingxi-live/village-center/main.tscn"
const ObserverView := preload("res://entities/observer_view.gd")   ## 2026-11-21 Claude (observer-view): 与镜头共用的同一份 clamp 数学
const ART := "res://assets/world/qingxi/"
const PARK := "qianxia-park"
const BASE_HEIGHT := 432.0               ## 清溪村's own base height (its project: 768x432)
const SHELTER := Vector2(330, 350)       ## bottom centre of the shelter art, world px of the park
const SHELTER_WIDTH := 128.0
const SHELTER_BLOCK := Rect2(272, 328, 116, 22) ## walkers go around the shelter
const CURB := Vector2(330, 376)          ## where you stand to take the bus (on the path)
const BUS_Y := 398.0                     ## bus wheels on the path
const BUS_WIDTH := 170.0
const SAVE_DIR := "world/qingxi-saves"
## Standalone 清溪村 save folder, relative to the Cabin World root, copied once (read only).
const DEMO_SAVES := "../../CabinWorld-rural-playtest-demo/.test-appdata/Godot/app_userdata/小屋世界 · 农村初版测试"

var game
var farm_wallet=preload("res://core/farm_wallet.gd").new()
var active := false     ## 清溪村 is open in the frame
var transit := false    ## the bus is moving (no input either side)
var holder: Control
var backdrop: ColorRect
var container: SubViewportContainer
var view: SubViewport
var curtain: ColorRect
var scene: Node
var stop_node: Node2D
var bus: Sprite2D
var bus_frames: Array[Texture2D] = []
var scale_k := 1
var bus_busy := false   ## 2026-11-20 Claude (qingxi-residents): the one bus is at work (you or a resident)
## 2026-11-21 Claude (observer-view): 观察者模式真的能看到清溪村。
## 观察者没有身体，所以这不是"他走进来了"，而是"镜头过来了"：村子是真村子、居民是真居民，
## 只是村子里的"你"（清溪村自己的 player/portrait/hud）藏起来，村子的输入也关掉——观察者只看看。
var spectator := false              ## true = 现在是一个观察者在看（没有身体）
var spectator_pan := Vector2.ZERO   ## 观察者自己拖出来的偏移（世界像素）
var _spectator_leaving := false

func setup(main) -> void:
	game = main
	name = "QingxiHost"
	layer = 15   ## above the room and player buttons (10), under the settings window (20)
	get_tree().set_meta("qingxi_world_host", self)
	farm_wallet.recover(SharedFeed.data_dir.path_join(SAVE_DIR),SIM_FILES)
	Economy.transaction_committed.connect(_wallet_transaction)
	holder = Control.new(); holder.name = "Frame"; holder.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.clip_contents = true   ## nothing of 清溪村 can draw outside Cabin World's frame
	add_child(holder)
	backdrop = ColorRect.new(); backdrop.color = Color("1d1a24"); backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE; holder.add_child(backdrop)
	container = SubViewportContainer.new(); container.stretch = false; container.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.add_child(container)
	view = SubViewport.new(); view.name = "Qingxi"
	view.disable_3d = true
	view.handle_input_locally = true
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	view.size_2d_override_stretch = true
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	container.add_child(view)
	curtain = ColorRect.new(); curtain.color = Color("1d1a24"); curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE; curtain.modulate.a = 0.0
	holder.add_child(curtain)
	holder.hide()
	for i in 2: bus_frames.append(_texture(ART + "bus-%d.png" % i))
	_mount_stop()
	get_tree().root.size_changed.connect(layout)
	_setup_residents()   ## 2026-11-20 Claude (qingxi-residents): residents ride the same bus

static func _texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path): return load(path)
	return ImageTexture.create_from_image(Image.load_from_file(path))

# ---------------- the park bus stop ----------------
func _mount_stop() -> void:
	if not game.rooms.has(PARK): return
	var park: Dictionary = WorldData.scenes[PARK]
	park.obstacles.append({"x":SHELTER_BLOCK.position.x, "y":SHELTER_BLOCK.position.y, "w":SHELTER_BLOCK.size.x, "h":SHELTER_BLOCK.size.y})
	WorldData._navs.erase(PARK)   ## rebuilt with the shelter on the next walk
	stop_node = Node2D.new(); stop_node.name = "QingxiBusStop"; stop_node.position = SHELTER
	game.rooms[PARK].add_child(stop_node)
	var art := Sprite2D.new(); art.texture = _texture(ART + "bus-shelter.png"); art.centered = false
	var k := SHELTER_WIDTH / art.texture.get_width()
	art.scale = Vector2.ONE * k
	art.position = Vector2(-SHELTER_WIDTH / 2.0, -art.texture.get_height() * k)
	stop_node.add_child(art)
	bus = Sprite2D.new(); bus.name = "QingxiBus"; bus.centered = false; bus.visible = false; bus.z_index = 1   ## low: the player is drawn on top of it (owner)
	game.rooms[PARK].add_child(bus)

## Adds "乘公交去清溪村" to the E choices when the player stands at the stop (player_controls.gd).
func add_choices(controls, options: Array) -> void:
	if active or transit:return
	travel_pets.add_choices(self,controls,options)
	if controls.player.scene_id==PARK:controls.add_choice(options, CURB, "乘公交去清溪村", board)

func _place_bus(x: float, open: bool) -> void:
	bus.texture = bus_frames[1 if open else 0]
	var k := BUS_WIDTH / bus.texture.get_width()
	bus.scale = Vector2.ONE * k
	bus.position = Vector2(x - BUS_WIDTH / 2.0, BUS_Y - bus.texture.get_height() * k)

func _drive(from_x: float, to_x: float, seconds: float, arriving: bool) -> void:
	bus.visible = true
	bus.flip_h = to_x < from_x   ## the art faces right: mirror it when driving left (never reversing)
	var t := 0.0
	while t < seconds:
		t += get_process_delta_time()
		var f := clampf(t / seconds, 0, 1)
		f = 1.0 - pow(1.0 - f, 3.0) if arriving else f * f * f
		_place_bus(lerpf(from_x, to_x, f), false)
		await get_tree().process_frame

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

# ---------------- going there and back ----------------
func busy() -> bool: return active or transit

func board() -> void:
	if busy(): return
	transit = true
	while bus_busy: await get_tree().process_frame   ## 2026-11-20 Claude (qingxi-residents): one bus; a resident may be getting on or off
	bus_busy = true
	var player = game.local_player
	game.player_controls.stop_activity()
	player.stop_navigation()
	await _drive(-260.0, CURB.x, 1.3, true)
	player.z_index = 2   ## stepping in: in front of the bus, never behind it
	_place_bus(CURB.x, true); await _wait(0.45)
	player.visible = false
	player.z_index = 0
	_place_bus(CURB.x, false); await _wait(0.25)
	await _drive(CURB.x, -260.0, 1.1, false)   ## back the way it came (west): the east side is the river
	bus.visible = false
	bus_busy = false
	await _open_village()
	transit = false

func owner_bus_home() -> void:
	if not active or transit: return
	transit = true
	await _fade(1.0, 0.25)
	if is_instance_valid(scene) and scene.has_method("save_progress"): scene.save_progress()
	_close_village()
	var player = game.local_player
	game.follow = -1
	game._show_room(PARK)
	player.feet = CURB; player.position = CURB
	if "_display" in player: player._display = CURB
	while bus_busy: await get_tree().process_frame   ## 2026-11-20 Claude (qingxi-residents): one bus
	bus_busy = true
	await _drive(-260.0, CURB.x, 1.3, true)   ## from the west along the path, never across the river
	player.z_index = 2   ## stepping out: in front of the bus
	_place_bus(CURB.x, true); await _wait(0.35)
	player.visible = true
	_place_bus(CURB.x, false); await _wait(0.25)
	await _drive(CURB.x, -260.0, 1.1, false)
	bus.visible = false
	bus_busy = false
	player.z_index = 0
	transit = false

## Leaving by clicking a Cabin World tab or card while in 清溪村: take the bus first.
## 2026-11-21 Claude (observer-view): 观察者没有身体可载，所以只是镜头回去。
func request_leave() -> void:
	if spectator:
		spectator_leave()
		return
	owner_bus_home()

# ---------------- the top bar while you are in 清溪村 ----------------
## The owner's rule: in player mode the top bar shows the places of where you are. In 清溪村
## those are its places (the one you are in is highlighted), plus the bus back; the title plaque
## reads 清溪村. Clicking one travels there the same way 清溪村's own M map does.
const PLACES := [
	{"id":"qx:village", "label":"清溪村", "icon":"qianxia-park"},
	{"id":"qx:meadow", "label":"自家农场", "icon":"qianxia-home"},
	{"id":"qx:barn", "label":"牧场屋", "icon":"rabbit"},
	{"id":"qx:room_private", "label":"自家小屋", "icon":"qianxia-home"},
	{"id":"qx:village_bath", "label":"暖汤屋", "icon":"world-onsen"},
	{"id":"qx:village_store", "label":"小铃杂货", "icon":"qianxia-shop"},
	{"id":"qx:seedshop", "label":"青芽种子店", "icon":"qianxia-shop"},
	{"id":"qx:livestockshop", "label":"牧铃畜牧铺", "icon":"rabbit"},
	{"id":"qx:@home", "label":"乘公交回小屋世界", "icon":"xiaojingyu-home"}]
func _set_bar(on: bool) -> void:
	var hud = game._hud
	if hud == null or not "places" in hud: return
	hud.places = PLACES.duplicate(true) if on else []
	hud.world_title = "清溪村" if on else "小屋世界"
	hud.place_on = tab_place() if on else ""
	game._layout(); hud.queue_redraw()
## Which place you are in now ("qx:village", "qx:meadow", the shops); inside the farm's cottage
## or barn you are still on the farm. (From a shop, a click on the farm first walks you out to the
## village centre: shops only have a door to the village, the same as in 清溪村 alone.)
func place_now() -> String:
	if not is_instance_valid(scene): return ""
	var path := str(scene.get_script().resource_path)
	if path.ends_with("livestock_shop.gd"): return "qx:livestockshop"
	if path.ends_with("connected_shop.gd") or path.ends_with("shop.gd"): return "qx:seedshop"
	if scene.get("open_meadow") == true: return "qx:meadow"   ## the farm scene (flat-build/trial.gd)
	## Otherwise the village-centre scene: map_id "village", or a room/region it opened.
	var map := str(scene.get("map_id"))
	return "qx:village" if map in ["village","village_bath","village_store"] or map.begins_with("resident_") else "qx:meadow"
## A click on the top bar while you are in 清溪村 (main.gd routes every tab click here then).
const ROOM_TABS={"village_bath":"village","village_store":"village","room_private":"meadow","barn":"meadow"}
var next_room:=""

func tab_place()->String:
	if is_instance_valid(scene):
		var room=str(scene.get("map_id"))
		if room in ROOM_TABS:return "qx:"+room
		if room.begins_with("room_private_"):return "qx:room_private"
		if scene.has_method("barn_level") and scene.barn_level(room)>0:return "qx:barn"
	return place_now()

func pick(id: String) -> void:
	if transit or not active or next_room!="" or JourneyCard.loading(get_tree()): return
	if id == "qx:@home" or not id.begins_with("qx:"):
		if spectator:
			spectator_leave()   ## 2026-11-21 Claude (observer-view): 观察者只是镜头回去，不坐公交
		else:
			owner_bus_home()
		return
	if id == tab_place() or not is_instance_valid(scene): return
	var place := id.trim_prefix("qx:")
	if spectator:observe_release()
	if place in ROOM_TABS:
		var base:String=ROOM_TABS[place]
		if place_now()=="qx:"+base:
			await JourneyCard.rebuild(get_tree(),_tab_label(place),_enter_tab_room.bind(place))
		else:
			next_room=place
			_pick_outdoor(base)
			# Some doors start loading on the following deferred call.
			await get_tree().process_frame
			await get_tree().process_frame
			while JourneyCard.loading(get_tree()):await get_tree().process_frame
			next_room=""
		return
	if place=="meadow" and scene.get("open_meadow")==true:
		await JourneyCard.rebuild(get_tree(),"自家农场",_enter_tab_room.bind("ranch"))
		return
	_pick_outdoor(place)

func _tab_label(place:String)->String:
	for item in PLACES:
		if item.id=="qx:"+place:return item.label
	return place

func _enter_tab_room(room:String):
	scene.close_menu()
	var layout:Dictionary=scene.sim.data.get("layout",{})
	var item={"barn":"meadow_barn","room_private":"meadow_house"}.get(room,"")
	if item!="" and not layout.has(item):
		scene.notify("请先在自家农场放置"+_tab_label(room));return
	var entry=Vector2.ZERO
	if room=="room_private":entry=scene.Rooms.ENTRY-Vector2(0,55)
	if room=="ranch" and str(scene.map_id).begins_with("room_private") and layout.has("meadow_house"):
		entry=Vector2(layout.meadow_house[0],layout.meadow_house[1])+Vector2(0,54)
	scene.build_map(room,entry)
	scene.save_progress()
	if spectator:_spectator_camera()

func _pick_outdoor(place:String):
	if spectator:
		if place not in ["village","meadow","seedshop","livestockshop"] or JourneyCard.loading(get_tree()):return
		if scene.has_method("observer_tab_destination"):
			scene.observer_tab_destination(place)
			return
	if scene.has_method("open_map_destination"):
		scene.open_map_destination(place)          ## village and farm: same as the M map
	elif scene.has_method("return_to_center"):
		_shop_destination(scene, place)

func _shop_destination(shop, place: String) -> void:
	if shop.leaving or place not in ["village","meadow","seedshop","livestockshop"]: return
	shop.leaving = true
	shop.save_study()
	var tree := get_tree()
	tree.set_meta("center_hour",shop.hour)
	tree.set_meta("center_cycle",shop.cycle_running)
	var path := "res://qingxi-live/village-center/" + place + ".tscn"
	var label := ""
	for item in PLACES:
		if item.id == "qx:" + place: label = item.label
	match place:
		"village":
			tree.set_meta("center_from_livestock" if place_now() == "qx:livestockshop" else "center_from_shop",true)
			path = "res://qingxi-live/village-center/main.tscn"
		"meadow":
			tree.set_meta("enter_meadow_from_village",true)
			tree.set_meta("meadow_via_gate",true)
			path = "res://qingxi-live/village-center/flat-build/meadow.tscn"
		_:
			if shop.from_meadow: tree.set_meta("return_shop_to_meadow",shop.meadow_via_village)
	preload("res://qingxi-live/village3d/session.gd").publish(tree,shop.sim,"ranch" if place=="meadow" else "village")
	if await preload("res://qingxi-live/village-center/map_loading.gd").change(tree,path,label) != OK and is_instance_valid(shop):
		shop.leaving = false
func _wallet_transaction(record:Dictionary):
	if record.get("actor")=="owner":_refresh_owner_wallet()

func _refresh_owner_wallet():
	if active and is_instance_valid(scene) and scene.get("sim")!=null and scene.sim.cabin_wallet==farm_wallet:
		farm_wallet.refresh(scene.sim)

func _process(_dt: float) -> void:
	_refresh_owner_wallet()
	_residents_tick()   ## 2026-11-20 Claude (qingxi-residents): their bus trips, their bodies in the view, the observer card
	if active:
		_spectator_camera()   ## 2026-11-21 Claude (observer-view): 观察者的镜头跟住她在村子里的位置
	if not active or transit: return
	var now := tab_place()
	if game._hud != null and "place_on" in game._hud and game._hud.place_on != now:
		game._hud.place_on = now; game._hud.queue_redraw()
	## 2026-11-21 Claude (observer-view): 切到观察者模式时不再"坐公交回家"——留下看，只是没有身体。
	if is_instance_valid(game.local_player) and not game.local_player.player_enabled and not spectator:
		set_spectator(true)

const JourneyCard := preload("res://qingxi-live/village-center/map_loading.gd")
func journey_card(title: String):
	var card = JourneyCard.new()
	card.name = "RuralMapLoading"
	get_tree().root.add_child(card)
	card.title_.text = title
	return card

func _open_village(spectating := false) -> void:
	active = true
	game._stage.visible = false   ## the park is behind the village: no need to draw it twice
	holder.show(); curtain.modulate.a = 1.0
	layout()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	spectator = spectating
	var card
	var packed: PackedScene
	if spectating or transit:
		transit = true
		card = journey_card("前往清溪村")
		await card.show_progress(.12,.12)
		if ResourceLoader.load_threaded_request(VILLAGE,"PackedScene")==OK:
			var fraction := []
			while ResourceLoader.load_threaded_get_status(VILLAGE,fraction)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				if not fraction.is_empty():card.set_progress(.12+.62*float(fraction[0]))
				await get_tree().process_frame
			if ResourceLoader.load_threaded_get_status(VILLAGE)==ResourceLoader.THREAD_LOAD_LOADED:
				packed = ResourceLoader.load_threaded_get(VILLAGE)
	else: packed = load(VILLAGE)
	if not packed:
		_close_village()
		transit = false
		if is_instance_valid(card):card.queue_free()
		return
	mount_scene(packed)
	if scene.has_method("bus_spawn"): scene.call_deferred("bus_spawn")
	_set_bar(true)
	spectator = spectating
	spectator_pan = Vector2.ZERO
	_apply_spectator()
	await get_tree().process_frame
	if is_instance_valid(card):
		curtain.modulate.a = 0
		await card.finish()
		transit = false
	else:await _fade(0.0, 0.35)

func _close_village() -> void:
	if is_instance_valid(scene) and scene.get("rooms")!=null and scene.rooms.owner_bed!="":
		scene.rooms.leave_bed()
	spectator = false
	if game != null and is_instance_valid(game.local_player) and game.local_player.player_enabled:
		game.local_player.visible = true   # 只在玩家模式下还原；观察者模式出村也不该看见自己
	spectator_pan = Vector2.ZERO
	_show_body(false)                    ## 把村子里的"你"还回去（场景随后就销毁，纯属收尾）
	view.gui_disable_input = false
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(scene):
		view.remove_child(scene); scene.queue_free()
	scene = null
	for child in view.get_children(): child.queue_free()   ## loading cards and other leftovers
	for meta in ["rural_handoff", "enter_meadow_from_village", "meadow_via_gate", "meadow_return", "return_shop_to_meadow", "center_from_shop", "center_from_livestock", "cottage_return", "ranch_return"]:
		if get_tree().has_meta(meta): get_tree().remove_meta(meta)
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	active = false
	_set_bar(false)
	game._stage.visible = true
	holder.hide()
	curtain.modulate.a = 0.0

func _fade(to: float, seconds: float) -> void:
	var tw := create_tween(); tw.tween_property(curtain, "modulate:a", to, seconds)
	await tw.finished

# ---------------- layout: inside the frame, real pixels, integer scale ----------------
func layout() -> void:
	if not active or game._hud == null: return
	var stretch: Transform2D = get_tree().root.get_final_transform()
	transform = stretch.affine_inverse()   ## children of this layer are in real screen pixels
	var frame: Rect2 = game._hud.frame_rect
	var canvas: Transform2D = game.get_global_transform_with_canvas()
	var a: Vector2 = (stretch * (canvas * frame.position)).round()
	var b: Vector2 = (stretch * (canvas * frame.end)).round()
	var real := Vector2i(b - a)
	scale_k = maxi(1, floori(real.y / BASE_HEIGHT))
	var logical := Vector2i(real.x / scale_k, real.y / scale_k)
	var drawn := logical * scale_k              ## a whole number of pixels per 清溪村 pixel
	## The viewport first: a container without stretch cannot be smaller than its viewport.
	view.size = drawn
	view.size_2d_override = logical
	holder.position = a; holder.size = Vector2(real)
	backdrop.size = Vector2(real); curtain.size = Vector2(real)
	container.position = Vector2((real - drawn) / 2); container.size = Vector2(drawn)

# ---------------- the interface the 清溪村 code calls ----------------
func audible_scene(rural) -> bool:
	return active and not transit and is_instance_valid(scene) and rural == scene

func controls(rural) -> bool:
	return not spectator and audible_scene(rural)

func can_observer_edit() -> bool:
	if not active or transit or not spectator or not is_instance_valid(scene):return false
	if not scene.has_method("can_build") or not scene.can_build() or scene.transition_pending or scene.overlay.visible:return false
	var chat=get_tree().get_meta("qingxi_chat",false)
	return not chat or not chat.opened()

func mount_scene(packed: PackedScene) -> int:
	if packed == null: return ERR_CANT_OPEN
	if is_instance_valid(scene):
		view.remove_child(scene); scene.queue_free()
	scene = packed.instantiate()
	view.add_child(scene)
	if scene.get("sim")!=null:
		farm_wallet.attach(scene.sim)
		if scene.has_method("sync_purse"):scene.sync_purse()
	if next_room!="" and place_now()=="qx:"+str(ROOM_TABS[next_room]):
		var room=next_room
		next_room=""
		_enter_tab_room(room)
	if spectator: _show_body(false)
	return OK

func loading_parent() -> Node: return view

var shared_farm_slot:=""
func profile_path(file:String)->String:
	if file in SIM_FILES:
		if shared_farm_slot=="":
			var candidates=[]
			for name_ in SIM_FILES:
				var p=_raw_profile_path(name_)
				if not FileAccess.file_exists(p):continue
				var data=JSON.parse_string(FileAccess.get_file_as_string(p))
				if data is Dictionary:candidates.append({"name":name_,"path":p,"wall":float(data.get("last_wall",0))})
			candidates.sort_custom(func(a,b):return a.wall>b.wall)
			shared_farm_slot=SIM_FILES[0]
			for slot in candidates:
				if load(PASTURE).new().load_from(slot.path):
					shared_farm_slot=slot.name;break
			var note=FileAccess.open(_raw_profile_path("农场存档说明.txt"),FileAccess.WRITE)
			if note:
				note.store_line("当前农场存档："+shared_farm_slot+"。村中心、自家农场和机器人使用同一份。")
				note.store_line("另一个旧槽若存在，是升级前的历史副本。迁移和备份请保留整个 qingxi-saves 目录。")
				note.close()
		file=shared_farm_slot
	return _raw_profile_path(file)

func _raw_profile_path(file: String) -> String:
	var folder: String = SharedFeed.data_dir.path_join(SAVE_DIR)
	DirAccess.make_dir_recursive_absolute(folder)
	var destination := folder.path_join(file)
	if not FileAccess.file_exists(destination) and not "--verify-center" in OS.get_cmdline_user_args():
		## First visit: continue the farm from standalone 清溪村 (copied, the original is not touched).
		var demo := ""
		for arg in OS.get_cmdline_user_args():   ## checks point this at a copy
			if arg.begins_with("--qingxi-demo-saves="): demo = arg.trim_prefix("--qingxi-demo-saves=")
		if not demo.is_empty() and FileAccess.file_exists(demo.path_join(file)):
			DirAccess.copy_absolute(demo.path_join(file), destination)
	return destination

## Time, weather and season are Cabin World's (the owner's rule): the same clock the park uses
## (VADS-synced, Shanghai time), the same weather as the window/park (real local weather or the
## preview set in Settings), and the season of the real date (as keepsakes.gd counts it).
func local_hour() -> float: return Daylight.local_hour(SharedFeed.now_ms())
func rural_weather() -> Dictionary: return SeasideEnvironment.state()
func _date() -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(int((SharedFeed.now_ms() + Daylight.SHANGHAI_MS) / 1000.0))
const SEASON_START := [3, 6, 9, 12]   ## spring, summer, autumn, winter start months
func season_index() -> int:
	var month: int = _date().month
	return 0 if month in [3,4,5] else 1 if month in [6,7,8] else 2 if month in [9,10,11] else 3
## 0..1 through the current season by days since its first day.
func season_progress() -> float:
	var d := _date(); var start_month: int = SEASON_START[season_index()]
	var year: int = d.year if d.month >= start_month else d.year - 1
	var start := Time.get_unix_time_from_datetime_dict({"year":year, "month":start_month, "day":1, "hour":0, "minute":0, "second":0})
	var now := Time.get_unix_time_from_datetime_dict({"year":d.year, "month":d.month, "day":d.day, "hour":d.hour, "minute":d.minute, "second":0})
	return clampf(float(now - start) / (91.0 * 86400.0), 0.0, 1.0)
func date_label() -> String:
	var d := _date()
	return "%s · %d月%d日" % [["春","夏","秋","冬"][season_index()], d.month, d.day]
## In 清溪村 you are your own Cabin World player (the black-haired maid), never 小鲸鱼: the same
## character pack the park uses (same layout as 清溪村's own packs; swimming uses its frames).
func owner_art_root() -> String: return game.local_player.skin_root if is_instance_valid(game.local_player) else load("res://entities/player_character.gd").ART
func owner_uses_travel_outfit() -> bool: return false

# ---------------- residents in 清溪村 (2026-11-20 Claude, qingxi-residents) ----------------
## The owner's rule: the residents (小鲸鱼 and any resident added later: same code, their
## own data) may go to 清溪村 too, by the same bus, when they choose to (VADS: space "qingxi",
## world_go / house_go qingxi). Whether to go and what to do there stays their own choice.
##
## In Cabin World's world model 清溪村 is one more scene, PLACE: it has spots (zones) but no room
## picture, no Cabin World tab (hud.gd skips scenes marked "noRoom") and NO door in the park (so
## you, the player, still go only by pressing E at the stop). The bus links the two:
##   going:  VADS sends walk.go scene=PLACE (or walk.go park with next=PLACE). This host keeps that
##           order, sends her to the park bus stop (park zone STOP_ZONE = CURB) and, when she stands
##           there, the bus comes, she gets in and it drives off. Then she is in PLACE, walks to
##           the spot VADS asked for, and the game answers walk.arrived as usual (scene PLACE).
##   back:   PLACE has an exit to the park whose entry is the bus stop. When she steps out there,
##           she waits (hidden, standing still) until the bus has pulled in with its door open.
##   One bus: you and the residents take turns (bus_busy).
## Where she is shown: in player mode, inside the 清溪村 view, when you are at the same place
## (village centre, farm, seed shop, livestock shop): her real Cabin World body (the same frame,
## pose and action as her body this moment) drawn into 清溪村 with her name. In observer mode,
## following her to 清溪村 (or clicking her card) shows a card in the frame: who is there, where,
## doing what (main.gd routes _show_room(PLACE) to watch_place).
## Time, weather and lighting there are Cabin World's (see the clock/weather functions above);
## none of a resident's 清溪村 uses touches lamps, time or weather.
##
## DATA MAPPING (must match VADS public/house-world.mjs QINGXI_ZONES / SPACES.qingxi):
##   space "qingxi" <-> scene PLACE; park zone STOP_ZONE "qx_curb" (VADS PARK_ZONES.qx_curb);
##   spots qx_busstop (车站), qx_plaza (村中心广场), qx_farm (自家农场), qx_seedshop (青芽种子店),
##   qx_livestockshop (牧铃畜牧铺). SPOT_PLACE maps a spot to the 清溪村 place (top bar ids above).
const Stay=preload("res://qingxi-live/cottage_lodging.gd")
const PLACE := "qingxi-village"
const PLACE_SPACE := "qingxi"
const STOP_ZONE := "qx_curb"
const PLACE_ENTRY := "bus"
const SPOT_PLACE := {"qx_busstop":"qx:village", "qx_plaza":"qx:village", "qx_farm":"qx:meadow", "qx_seedshop":"qx:seedshop", "qx_livestockshop":"qx:livestockshop"}
const SPOT_NAMES := {"qx_busstop":"车站", "qx_plaza":"村中心广场", "qx_farm":"自家农场", "qx_seedshop":"青芽种子店", "qx_livestockshop":"牧铃畜牧铺"}
const STOP_REACH := 48.0     ## close enough to the stop for the bus to pick her up
const HOLD_LIMIT := 20.0     ## never hold a resident still longer than this (watchdog)
## Her body's walk frame height in Cabin World units when the art pack does not say.
const BODY_HEIGHT := 69.0
## Your 清溪村 frames carry more empty margin above the head than Cabin World's walk frames; measured on the
## 2026-11-20 screenshots (her body came out ~1.6x yours), this brings both to the same height.
const FRAME_FILL := 0.62
var trips := {}      ## key -> {id, zone}: a walk.go to 清溪村 this host is carrying out (stop, then bus)
var riding := {}     ## key -> true while the bus picks her up or drops her off
var held := {}       ## key -> seconds held still by the bus (watchdog)
var last_scene := {} ## key -> the scene she was in (to notice her stepping off the bus at the park)
var visitors := {}   ## key -> {node, sprite, tag, k}: her body drawn inside the 清溪村 view
var arrivals := {}   ## 清溪村 scene instance id -> where you arrived in it (anchor for the farm)
var watch: PanelContainer
var watch_text: Label
var watching := false
var _watch_clock := 0.0

## Called by main.gd right after the rooms are made and BEFORE the residents wake, so one who was
## in 清溪村 when the game closed wakes there. Adds PLACE (spots, the exit back to the park), the
## park's bus-stop spot and entry, the space for Entry routes, and a hidden Room for her body.
static func register_place(main) -> void:
	if WorldData.scenes.has(PLACE) or not WorldData.scenes.has(PARK): return
	WorldData.scenes[PLACE] = {"id":PLACE, "name":"清溪村", "noRoom":true, "outdoor":true,
		"width":960, "height":640, "walk":{"x":12, "y":12, "w":936, "h":616}, "speed":82, "run":120, "clearance":9,
		"entries":{PLACE_ENTRY:{"x":480, "y":590}},
		"exits":[{"id":PLACE_ENTRY, "x":480, "y":624, "to":PARK, "entry":"qingxi"}],
		"zones":{"qx_busstop":{"x":480, "y":548}, "qx_plaza":{"x":480, "y":380}, "qx_farm":{"x":800, "y":160},
			"qx_seedshop":{"x":200, "y":250}, "qx_livestockshop":{"x":330, "y":150}},
		"obstacles":[], "modules":{}}
	var park: Dictionary = WorldData.scenes[PARK]
	park.entries["qingxi"] = {"x":CURB.x, "y":CURB.y}
	park.zones[STOP_ZONE] = {"x":CURB.x, "y":CURB.y}
	WorldData.SPACE_SCENE[PLACE_SPACE] = PLACE
	Entry.SPACES[PLACE_SPACE] = {"links":["park"], "owner":""}
	if not PLACE_SPACE in Entry.SPACES.park.links: Entry.SPACES.park.links.append(PLACE_SPACE)
	var room := Room.new(); room.name = "QingxiPlace"; room.scene_id = PLACE
	room.width = 960; room.height = 640; room.visible = false   ## never built, never shown
	main._stage.add_child(room)
	main.rooms[PLACE] = room

func _setup_residents() -> void:
	VadsLink.walk_ordered.connect(_on_walk_ordered)   ## after main.gd's handler: main hands her the order first
	watch = PanelContainer.new(); watch.name = "QingxiWatch"; watch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := StyleBoxFlat.new(); paper.bg_color = Color("f3e7cf"); paper.border_color = Color("5a3d28")
	paper.set_border_width_all(3); paper.set_corner_radius_all(6); paper.set_content_margin_all(18)
	watch.add_theme_stylebox_override("panel", paper)
	watch_text = Label.new(); watch_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	watch_text.add_theme_color_override("font_color", Color("3b2a1e"))
	watch.add_child(watch_text)
	add_child(watch); watch.hide()

func _residents() -> Array:
	var out := []
	for c in game.characters:
		if is_instance_valid(c) and c != game.local_player and c.key != Residents.PLAYER: out.append(c)
	return out

func _resident(key: String):
	for c in _residents():
		if c.key == key: return c
	return null

## walk.go / walk.cancel from VADS (main.gd has already given it to her body).
func _on_walk_ordered(frame: Dictionary) -> void:
	var c = _resident(str(frame.get("actor", "")))
	if c == null: return
	var key: String = c.key
	var id := str(frame.get("id", ""))
	var trip = trips.get(key)
	if frame.get("type", "") == "walk.cancel":
		if trip != null and id == trip.id:
			trips.erase(key)
			if not riding.has(key): _stand_still(c)
		return
	if trip != null and trip.id != id:   ## a newer order replaces the bus trip
		trips.erase(key)
		VadsLink.send({"type":"walk.arrived", "id":trip.id, "actor":key, "replaced":true})
	resident_rooms.leisure.erase(key)
	var to := str(frame.get("scene", ""))
	if to!=PLACE or str(frame.get("zone",""))!=c.want_zone:resident_rooms.inside.erase(key)
	if to == PLACE and c.scene_id != PLACE:
		var zone := str(Character.nz(frame.get("zone"), ""))
		trips[key] = {"id":id, "zone":zone if zone != "" else "qx_busstop"}
		c.order_id = ""   ## the host answers this order once she is really in 清溪村
		c.want_scene = PARK; c.want_zone = STOP_ZONE; c.next_scene = ""; c._remember()
	elif to == PARK and str(Character.nz(frame.get("next"), "")) == PLACE:
		## "walk through the park towards 清溪村": there is no door, the stop is the way on.
		c.want_zone = STOP_ZONE; c.next_scene = ""; c._remember()

func _stand_still(c) -> void:
	c.order_id = ""; c.route.clear(); c.state = Character.State.IDLE
	c.want_scene = c.scene_id; c.want_zone = ""; c.next_scene = ""; c.target = c.feet
	c._remember(); c.report_position()

func _hold(c) -> void:
	c.set_physics_process(false); held[c.key] = 0.0

func _release(c) -> void:
	if not is_instance_valid(c): return
	c.set_physics_process(true); c.visible = true; c.z_index = 0; held.erase(c.key)

func _on_resident_room(c) -> void:
	var before: String = last_scene.get(c.key, "")
	last_scene[c.key] = c.scene_id
	if before==PLACE and c.scene_id!=PLACE:Stay.wake(profile_path_cached(),c.key)
	if before == PLACE and c.scene_id == PARK and not riding.has(c.key): _drop_off(c)

## She stands at the stop; the bus comes, she gets in, and it drives off with her.
func _pick_up(c) -> void:
	var key: String = c.key
	riding[key] = true
	_hold(c)
	while bus_busy: await get_tree().process_frame
	bus_busy = true
	await _drive(-260.0, CURB.x, 1.3, true)
	_place_bus(CURB.x, true)
	if is_instance_valid(c): c.z_index = 2   ## stepping in: in front of the bus
	await _wait(0.45)
	var trip = trips.get(key)
	if is_instance_valid(c) and trip != null and c.scene_id == PARK:
		c.visible = false
		_place_bus(CURB.x, false); await _wait(0.25)
		trip = trips.get(key)
		if is_instance_valid(c) and trip != null:
			trips.erase(key)
			c._enter(PLACE, PLACE_ENTRY)     ## same as stepping through a door: she is now in 清溪村
			c.want_scene = PLACE; c.want_zone = trip.zone; c.next_scene = ""
			c.order_id = trip.id; c._order_lock = Character.ORDER_LOCK; c._remember()
	else:
		_place_bus(CURB.x, false); await _wait(0.25)
	_release(c)
	riding.erase(key)
	await _drive(CURB.x, -260.0, 1.1, false)
	bus.visible = false
	bus_busy = false

## She has stepped out of 清溪村 at the park stop: she stays hidden until the bus is there.
func _drop_off(c) -> void:
	var key: String = c.key
	riding[key] = true
	_hold(c); c.visible = false
	while bus_busy: await get_tree().process_frame
	bus_busy = true
	await _drive(-260.0, CURB.x, 1.3, true)
	_place_bus(CURB.x, true)
	if is_instance_valid(c):
		c.z_index = 2; c.visible = true   ## stepping out: in front of the bus
	await _wait(0.35)
	_place_bus(CURB.x, false); await _wait(0.25)
	_release(c)
	riding.erase(key)
	await _drive(CURB.x, -260.0, 1.1, false)
	bus.visible = false
	bus_busy = false

var resident_rooms=preload("res://core/resident_rooms.gd").new()
var pet_beds=preload("res://core/resident_pet_beds.gd").new()
var travel_pets=preload("res://core/travel_pets.gd").new()

func _residents_tick() -> void:
	var dt := get_process_delta_time()
	for c in _residents():
		var key: String = c.key
		if not c.room_changed.is_connected(_on_resident_room):   ## residents added later too
			c.room_changed.connect(_on_resident_room); last_scene[key] = c.scene_id
		if c.scene_id!=PLACE or c.want_zone!="qx_farm":
			held_by.erase(key)
			if resident_rooms.leisure.get(key,{}).get("verb","") in ["farm_bench","swim"]:resident_rooms.leisure.erase(key)
		if held.has(key):
			held[key] += dt
			if held[key] > HOLD_LIMIT: _release(c)
		if trips.has(key) and not riding.has(key) and c.placed and c.scene_id == PARK and not c.is_walking() and c.feet.distance_to(CURB) <= STOP_REACH:
			_pick_up(c)
	_draw_visitors()
	travel_pets.tick(self,dt)
	_watch_tick(dt)

# ---- her body inside the 清溪村 view (player mode) ----
var _lodging_path := ""
func profile_path_cached() -> String:
	if _lodging_path=="":_lodging_path=profile_path(Stay.FILE)
	return _lodging_path
func _draw_visitors() -> void:
	var here := place_now() if active and not transit and is_instance_valid(scene) else ""
	if here != "" and not arrivals.has(scene.get_instance_id()) and scene.get("player") is Node2D:
		arrivals[scene.get_instance_id()] = scene.player.position
	var seen := {}
	var index := 0
	for c in _residents():
		if here == "" or not c.placed or c.scene_id != PLACE or c.is_walking(): continue
		if Stay.data(profile_path_cached()).get("guests",{}).has(c.key):continue
		var interior=str(resident_rooms.inside.get(c.key,""))
		var displayed=str(scene.get("map_id"))
		if interior!="" and displayed!=interior:continue
		if interior=="" and (displayed.begins_with("room_private") or displayed.begins_with("resident_") or displayed.begins_with("barn")):continue
		var spot: String = c.want_zone
		if SPOT_PLACE.get(spot, "") != here: continue
		if here == "qx:village" and interior=="" and displayed != "village": continue   ## inside a village house
		seen[c.key] = true
		_draw_visitor(c, spot, index)
		index += 1
	for key in visitors.keys():
		if not seen.has(key):
			if is_instance_valid(visitors[key].node): visitors[key].node.queue_free()
			visitors.erase(key)

func _draw_visitor(c, spot: String, index: int) -> void:
	var parent = scene.get("scenery")
	if not parent is Node2D: return
	var v = visitors.get(c.key)
	if v == null or not is_instance_valid(v.node) or v.node.get_parent() != parent:
		if v != null and is_instance_valid(v.node): v.node.queue_free()
		var node := Node2D.new(); node.name = "Visitor_" + c.key
		var sprite := Sprite2D.new()
		if scene.has_method("light_material"): sprite.material = scene.light_material()   ## the same sun and lamps as the village
		node.add_child(sprite)
		var tag := Label.new(); tag.text = c.display_name; tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.size = Vector2(80, 14); tag.add_theme_font_size_override("font_size", 10)
		tag.add_theme_color_override("font_color", Color("fff6e0")); tag.add_theme_color_override("font_outline_color", Color("2a2230"))
		tag.add_theme_constant_override("outline_size", 3)
		node.add_child(tag)
		parent.add_child(node)
		v = {"node":node, "sprite":sprite, "tag":tag, "k":_visitor_scale(c)}
		visitors[c.key] = v
	var arrival:=_visit_point(spot,index)
	if not v.has("at_farm"):
		v.node.position=arrival;v.at_farm=true
	var movement:=Vector2.ZERO
	var job:Dictionary=visitor_jobs.get(c.key,{})
	var now:=Time.get_ticks_msec()
	var location=str(scene.get("map_id")) if spot not in ["qx_seedshop","qx_livestockshop"] else spot
	if job.get("room","")==location and not v.get("restored",false):
		v.node.position=job.pos;v.restored=true
	if job.get("room","")==location and now<int(job.expires):
		if job.node!=v.node.get_instance_id():v.node.position=job.pos;job.node=v.node.get_instance_id()
		job.last=now
		var route:PackedVector2Array=job.route
		if not route.is_empty():
			var at:Vector2=v.node.position
			var next:=at.move_toward(route[0],get_process_delta_time()*126.0)
			var farm=scene.get("player_moving")!=null
			var previous=scene.get("player_moving")
			if farm:scene.player_moving=true
			var blocked=scene.blocked(next)
			if farm:scene.player_moving=previous
			if blocked:job.blocked=true;route.clear()
			else:
				v.node.position=next;movement=next-at
				if movement.length_squared()>.001:job.facing=movement
				if next.distance_to(route[0])<.6:route.remove_at(0)
			job.route=route;job.pos=v.node.position
		if route.is_empty() and job.at==0:job.at=now
		if job.at>0 and now-int(job.at)<900 and not job.get("blocked",false):
			v.tag.text=c.display_name+" · "+str({"buy_young":"买幼崽","buy":"买东西","release":"放养","plant":"播种","water":"浇水","harvest":"收获","fish":"抛竿","feed":"添料"}.get(job.action,"操作中"))
			if job.has("bank"):v.tag.text=c.display_name+" · E 鱼塘 · "+str(Pond.LABELS.get(job.action,"水边"))
		else:v.tag.text=c.display_name
	else:v.tag.text=c.display_name
	var src: Sprite2D = c._sprite
	var sprite: Sprite2D = v.sprite
	var k: float = v.k
	sprite.texture = src.texture; sprite.region_enabled = src.region_enabled; sprite.region_rect = src.region_rect
	sprite.centered = src.centered; sprite.offset = src.offset; sprite.flip_h = src.flip_h; sprite.flip_v = src.flip_v
	sprite.position = src.position * k; sprite.scale = src.scale * k; sprite.rotation = src.rotation
	sprite.visible = src.visible and src.texture != null
	if movement.length_squared()>.001:Work.animate(c,sprite,movement,k)
	elif job.get("node",0)==v.node.get_instance_id() and job.get("at",0)>0 and now-int(job.at)<900:
		Work.animate(c,sprite,Vector2.UP if spot in ["qx_livestockshop","qx_seedshop"] else job.get("facing",Vector2.DOWN),k,false)
		sprite.position.y+=sin(clampf(float(now-int(job.at))/650.,0.,1.)*PI)*2.0*k
	if spot=="qx_farm" and scene.get("map_id")=="ranch":
		var wet=scene.water_at(v.node.position)
		if wet and not v.has("surface"):
			v.surface=preload("res://qingxi-live/village-center/swim_surface.gd").new()
			v.node.add_child(v.surface);v.node.move_child(v.surface,0)
		if v.has("surface"):
			v.surface.visible=wet
			if wet:
				v.surface.moving=movement.length_squared()>.001
				v.surface.phase+=get_process_delta_time()*(8.5 if v.surface.moving else 2.5)
				if v.surface.moving:v.surface.axis=movement.normalized()
				v.surface.queue_redraw()
			if sprite.material is ShaderMaterial:sprite.material.set_shader_parameter("swim_waterline",v.node.global_position.y+2. if wet else 100000.)
		if held_by.has(c.key):v.tag.text+=" · "+("小麦" if held_by[c.key]=="wheat" else "胡萝卜")
	resident_rooms.pose(self,c.key,v,get_process_delta_time())
	v.tag.position = Vector2(-40, -BODY_HEIGHT * k - 16)

## Her size in 清溪村: the same height as your own character there (both are grown-up girls).
func _visitor_scale(c) -> float:
	var mine := 0.0
	var portrait = scene.get("portrait")
	if portrait is Sprite2D and portrait.texture != null:
		mine = portrait.texture.get_height() * absf(portrait.scale.y)
	var hers := BODY_HEIGHT
	var walk = WorldData.actors.get(c.art, {}).get("walk", {})
	if walk is Dictionary and walk.has("rects") and walk.has("scale"):
		hers = float(walk.rects[0][3]) * float(walk.scale)
	return clampf(mine / hers * FRAME_FILL, 0.3, 3.0) if mine > 0.0 else 1.0

## Where she stands at each spot, a little to the side so she is not on top of you.
func _visit_point(spot: String, index: int) -> Vector2:
	var base: Vector2 = scene.player.position
	if str(scene.get("map_id")).begins_with("resident_") or str(scene.get("map_id")).begins_with("room_private"):base=Vector2(640,625)
	elif spot == "qx_busstop" and scene.has_method("bus_point"): base = scene.bus_point() + Vector2(-46, 6)
	elif spot == "qx_plaza" and scene.get("qingxi") != null: base = scene.qingxi.plaza + Vector2(70, 96)
	elif SPOT_PLACE.get(spot, "") in ["qx:seedshop", "qx:livestockshop"]: base = Vector2(482, 521)   ## on the shop floor, a few steps in from the door
	else: base = arrivals.get(scene.get_instance_id(), base) + Vector2(56, -30)   ## the farm: near where you came in
	var p := base + Vector2(index * 40, 0)
	if scene.has_method("blocked"):
		for d in [Vector2.ZERO, Vector2(-80, 0), Vector2(0, 40), Vector2(0, -40), Vector2(80, 0), Vector2(-40, 60)]:
			if not scene.blocked(p + d): return p + d
	return p

# ---- observer mode: following her to 清溪村 shows who is there ----
## main.gd calls this from _show_room(id) for every room shown; only PLACE shows the card.
func watch_place(id: String) -> void:
	watching = id == PLACE
	_watch_clock = 1.0
	_watch_tick(0.0)

func _watch_tick(dt: float) -> void:
	if not watching or active or transit or game._hud == null:
		if watch.visible: watch.hide()
		return
	_watch_clock += dt
	if watch.visible and _watch_clock < 0.5: return
	_watch_clock = 0.0
	var lines := []
	for c in _residents():
		if c.placed and c.scene_id == PLACE:
			var doing: String = c.label if c.label != "" else ("在走路" if c.is_walking() else "待着")
			lines.append("%s · %s · %s" % [c.display_name, SPOT_NAMES.get(c.want_zone, "清溪村"), doing])
	if lines.is_empty(): lines.append("现在没有住户在清溪村。")
	watch_text.text = "清溪村\n\n" + "\n".join(lines) + "\n\n她们在公园的公交站坐车来这里。你也可以在公交站按 E 坐车过来。"
	var stretch: Transform2D = get_tree().root.get_final_transform()
	transform = stretch.affine_inverse()   ## real screen pixels, as in layout()
	var frame: Rect2 = game._hud.frame_rect
	var canvas: Transform2D = game.get_global_transform_with_canvas()
	var a: Vector2 = (stretch * (canvas * frame.position)).round()
	var b: Vector2 = (stretch * (canvas * frame.end)).round()
	watch_text.add_theme_font_size_override("font_size", maxi(14, roundi(20 * stretch.get_scale().y)))
	watch.reset_size()
	watch.position = ((a + b) / 2.0 - watch.size / 2.0).round()
	watch.show()

# ---------------- 观察者看真的清溪村 (2026-11-21 Claude, observer-view) ----------------
## 业主："如果是观察者模式的话，我会去不了清溪村。" 改动前为什么去不了，两道闸：
##   ① 观察者没有身体 ⇒ player_controls.allows_input() 为假 ⇒ 没有 E 菜单 ⇒ 公交站的
##      "乘公交去清溪村"（add_choices）根本长不出来，所以坐不了车。
##   ② 跟随一个在清溪村的居民时，main.gd 的 _show_room(PLACE) 遇到 noRoom 直接 return，
##      只剩一张文字卡（watch_place），画面还停在原来的房间。
## 正解不是给他一个隐形身体，而是镜头过来：真村子、真居民，只是"你"不在场。
func can_watch_in_person() -> bool:
	return game != null and bool(game.get("observing")) and ResourceLoader.exists(VILLAGE)

## main.gd 在观察者模式里 _show_room(PLACE) 时调用；返回 true = 已经用真村子接手了。
func watch_in_person() -> bool:
	if not can_watch_in_person(): return false
	if active:
		if not spectator: set_spectator(true)
		return true
	if transit: return false
	_open_village(true)
	return true

## 观察者的镜头：跟住被跟随的那个居民（她真的在清溪村时），否则停在村口；都能拖动。
func _spectator_camera() -> void:
	if not spectator or not is_instance_valid(scene): return
	_show_body(false)
	var cam = scene.get("camera")
	var allow_editor=can_observer_edit()
	view.gui_disable_input=not allow_editor
	container.mouse_filter=Control.MOUSE_FILTER_STOP if allow_editor else Control.MOUSE_FILTER_IGNORE
	if not (cam is Camera2D): return
	var bounds: Rect2 = scene.world_bounds() if scene.has_method("world_bounds") else Rect2(Vector2.ZERO, Vector2(1280, 900))
	var extent := Vector2(view.size_2d_override)
	if extent.x <= 0.0 or extent.y <= 0.0: extent = Vector2(view.size)
	var half: Vector2 = extent / cam.zoom * 0.5
	var target: Vector2 = _spectator_point() + spectator_pan
	var next_position := ObserverView.village_center(target, bounds, half).round()
	if cam.position != next_position and allow_editor and scene.get("build_mode"):
		scene.queue_redraw()
	cam.position = next_position
	cam.force_update_scroll()
	if not transit and scene.has_method("update_environment_audio"):
		scene.update_environment_audio(cam.get_screen_center_position())

## 值得看的地方：跟着她时就是她的 spot；没跟随时是村口。
func _spectator_point() -> Vector2:
	var base := Vector2.ZERO
	if is_instance_valid(scene) and scene.get("player") is Node2D: base = scene.player.position
	if game == null: return base
	var index: int = int(game.follow)
	if index < 0 or index >= game.characters.size(): return base
	var c = game.characters[index]
	if not (is_instance_valid(c) and c.placed and c.scene_id == PLACE): return base
	var spot := str(c.want_zone)
	if SPOT_PLACE.get(spot, "") != place_now(): return base
	if visitors.has(c.key) and is_instance_valid(visitors[c.key].node):return visitors[c.key].node.position
	return _visit_point(spot, 0)

## 拖动/贴边/方向键：屏幕像素位移 → 清溪村世界像素。
func observe_pan(delta_screen: Vector2) -> void:
	if not spectator or not is_instance_valid(scene): return
	_show_body(false)
	var cam = scene.get("camera")
	var zoom := 1.0
	if cam is Camera2D: zoom = maxf(0.01, cam.zoom.x)
	spectator_pan -= delta_screen / maxf(0.01, float(scale_k) * zoom)

## 退出跟随，回到自由镜头（村子停在原地，可以继续拖）。
func observe_release() -> void:
	spectator_pan = Vector2.ZERO
	if game == null: return
	game.follow = -1
	if game._hud != null:
		game._hud.follow = -1
		game._hud.queue_redraw()

## 观察者离开清溪村：只收镜头，不碰玩家身体（他一直待在公园，没动过）。
func spectator_leave() -> void:
	if not active or _spectator_leaving or transit: return
	_spectator_leaving = true
	transit = true
	var card = journey_card("返回小屋世界")
	await card.show_progress(.34,.14)
	_close_village()
	if not game._observer_leaving:game._show_room(game._observer_return_scene if game.rooms.has(game._observer_return_scene) else PARK)
	if not game._observer_leaving and game.follow >= 0:
		game.follow = -1
		if game._hud != null: game._hud.follow = -1; game._hud.queue_redraw()
	await card.finish()
	transit = false
	_spectator_leaving = false

## 玩家/观察者模式切换时由 main.gd 调用。
func resume_observed_position() -> void:
	if not spectator or not is_instance_valid(scene) or not (scene.get("player") is Node2D):return
	if spectator_pan.is_zero_approx() and game.follow<0:return
	var focus:=_spectator_point()+spectator_pan
	var bounds:Rect2=scene.world_bounds() if scene.has_method("world_bounds") else Rect2(0,0,1280,900)
	focus=focus.clamp(bounds.position+Vector2.ONE*8,bounds.end-Vector2.ONE*8)
	for radius in range(0,161,8):
		for i in (1 if radius==0 else 16):
			var at:=focus+Vector2.RIGHT.rotated(i*TAU/16.)*radius
			if bounds.has_point(at) and (not scene.has_method("blocked") or not scene.blocked(at)):
				scene.player.position=at
				if scene.has_method("update_camera"):scene.update_camera(true)
				return

func on_mode_changed(player_mode: bool) -> void:
	if not active: return
	if player_mode:
		if spectator: set_spectator(false)
	elif not spectator:
		set_spectator(true)

## 观察者：把"你"藏起来、关掉村子的输入；回到玩家模式则原样还回去。
## 观察者：把"你"藏起来、关掉村子的输入；回到玩家模式则原样还回去。
## 用 gui_disable_input + 容器的 mouse_filter 来关（不从 handle_input_locally 上打主意：
## 那个属性在场景子树被换掉时会被引擎重新武装，实测关得住但不稳）。
func _apply_spectator() -> void:
	_show_body(not spectator)
	# 2026-11-21（业主）：观察者在清溪村还能看见「自己」的玩家建模。_show_body 只管村里场景里那个 player 节点，
	# 小屋世界里还挂着 game.local_player 这一个 —— 这里一起藏掉，出村时按模式还原（见 _close_village）。
	if game != null and is_instance_valid(game.local_player):
		game.local_player.visible = not spectator
	var local := not spectator
	view.gui_disable_input = not local
	container.mouse_filter = Control.MOUSE_FILTER_STOP if local else Control.MOUSE_FILTER_IGNORE

## 村子里的"你"：观察者在看的时候没有身体。
func _show_body(on: bool) -> void:
	if not is_instance_valid(scene): return
	if scene.has_meta("player_cast") and is_instance_valid(scene.get_meta("player_cast")): scene.get_meta("player_cast").visible = on
	if scene.get("player") is CanvasItem: scene.player.visible = on and not (scene.get("rooms")!=null and scene.rooms.owner_bed!="")
	if scene.get("portrait") is CanvasItem: scene.portrait.visible = on
	if scene.get("hud") is CanvasLayer or scene.get("hud") is CanvasItem: scene.hud.visible = on
	if is_instance_valid(scene.get("shop_hud")):
		scene.shop_hud.visible=on
		var shop_map=scene.get_node_or_null("ShopObserverMap")
		if not on and not shop_map:
			shop_map=CanvasLayer.new();shop_map.name="ShopObserverMap";shop_map.layer=11;scene.add_child(shop_map)
			var panel:=Control.new();panel.position=Vector2(6,6);panel.size=Vector2(148,90)
			panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;shop_map.add_child(panel)
			panel.draw.connect(_draw_shop_map.bind(panel,scene))
		if shop_map:
			shop_map.visible=not on
			if not on:shop_map.get_child(0).queue_redraw()
	# Keep the live map and its plaque in the village viewport when the player HUD is hidden.
	var ui = scene.get("ui")
	if is_instance_valid(ui) and "mini" in ui and is_instance_valid(ui.mini):
		var frame:Control = ui.mini.get_parent().get_parent()
		if not on and frame.get_parent()==ui:
			var layer:=CanvasLayer.new()
			layer.name="ObserverMap"
			layer.layer=11
			scene.add_child(layer)
			frame.reparent(layer,false)
			for tool in [scene.get("edit_button"),scene.get("hotbar")]:
				if is_instance_valid(tool):tool.reparent(layer,false)
		elif on and frame.get_parent()!=ui and frame.get_parent().name=="ObserverMap":
			var layer=frame.get_parent()
			frame.reparent(ui,false)
			ui.move_child(frame,0)
			for tool in [scene.get("edit_button"),scene.get("hotbar")]:
				if is_instance_valid(tool) and tool.get_parent()==layer:tool.reparent(scene.hud,false)
			layer.queue_free()

func _draw_shop_map(panel:Control, shop) -> void:
	var footprint:Rect2=shop.ROOMS[0]
	for rect in shop.ROOMS:footprint=footprint.merge(rect)
	var k:=minf((panel.size.x-12)/footprint.size.x,(panel.size.y-12)/footprint.size.y)
	var offset:Vector2=(panel.size-footprint.size*k)/2-footprint.position*k
	panel.draw_rect(Rect2(Vector2.ZERO,panel.size),Color("765133"))
	panel.draw_rect(Rect2(Vector2(3,3),panel.size-Vector2(6,6)),Color("39372e"))
	for rect in shop.ROOMS:panel.draw_rect(Rect2(offset+rect.position*k,rect.size*k),Color("c8aa78"))
	panel.draw_circle(offset+shop.COUNTER*k,2,Color("694e39"))
	for visitor in visitors.values():
		if is_instance_valid(visitor.node):panel.draw_circle(offset+visitor.node.position*k,2,Color("85d7df"))
	if shop.get("camera") is Camera2D:
		var cam:Camera2D=shop.camera
		var seen_size:Vector2=Vector2(view.size_2d_override)/cam.zoom
		var seen:=footprint.intersection(Rect2(cam.get_screen_center_position()-seen_size/2,seen_size))
		panel.draw_rect(Rect2(offset+seen.position*k,seen.size*k),Color("fbefd4"),false,1)

func set_spectator(on: bool) -> void:
	spectator = on
	spectator_pan = Vector2.ZERO
	_apply_spectator()
	if on and is_instance_valid(scene) and scene.has_method("update_camera"):
		scene.update_camera(true)   ## 先让村子自己摆好镜头，本帧的 _spectator_camera() 再改成看住户

# ---------------- residents farm in 清溪村 (2026-11-20 Claude, qingxi-residents round 2) ----------------
## 业主的规则（2026-11-20）："她们和我一样是正常玩家" — 居民在清溪村拥有全部正常玩家功能，自己决定用不用；
## 只有作弊（quick_grow / quick_produce / supplies，F6 测试键）不是她们的。农场是三个人共用的（田、动物、
## 鱼塘、农场背包、小屋存的东西）；钱不是：各花各的零花钱。搭建、改造、挪建筑不在这一轮。
##
## 2026-11-20 round 3（qingxi-farm）：业主的三条原则
##   1) 世界自由化：每个前提都必须能自己达成、缺什么一眼看见、一步能补。已有大围栏就直接算数。
##   2) 插件工具化：till/dig/fence/place_feeder/fill_water/survey 都是她手里的工具，名字是人话。
##   3) 不许撒谎：工具只在真的改动了存档时返回成功（changed 检查）；拒绝时说清缺哪一条和下一步；
##      规则和阈值全在 qingxi-live/village-center/farm_rules.json，两边都查得到（out.farm.rules）。
##
## INTERFACE: VADS economy.do {actor, op:"qingxi", act, arg} -> core/economy.gd _apply -> resident_act(s, frame, out).
##   s = 她的 Cabin World economy 状态（s.wallet.coins 是她的零花钱）；economy 事后保存。
##   out.text = 发生了什么；out.farm = 一份共享农场的读数（act "look"/"survey" 或任何动作之后）。
##   返回 "" 表示做成了；返回字符串表示为什么没做成（此时存档没有被改）。
const PASTURE := "res://qingxi-live/village-center/pasture_state.gd"
const FARM := preload("res://qingxi-live/village-center/farm_rules.gd")
const PET_RULES := preload("res://qingxi-live/village-center/pets_rules.gd")
const SIM_FILES := ["village-center-test.json", "open-meadow.json"]
var fishing_lines := {}
const Pond=preload("res://core/pond_interaction.gd")
const Work=preload("res://core/qingxi_work.gd")
var held_by := {}
var visitor_jobs := {}
var route_viewport:SubViewport
var route_model
var route_cache:Dictionary={}
var route_map=""
var route_layout:Dictionary={}
var route_pen:Dictionary={}

func background_map(room:String,spot:String,action:String):
	var farm=_farm_sim()
	var layout:Dictionary=farm.sim.data.get("layout",{}) if spot not in ["qx_seedshop","qx_livestockshop"] else {}
	var herd_action=action in ["collect","treat","pair","sell_animal","pair_free","pair_pause","process_stock","follow_pet","stay_pet","play_pet","feed_pet","walk_pet","name_pet"]
	var fixed_village=room=="village" and action in ["tea_break","foot_bath","village_well","river_fish"]
	var cache_key=room+"/fixed" if fixed_village else room
	if fixed_village:layout={}
	elif room=="ranch" and layout.has("meadow_ground"):
		layout=layout.duplicate()
		layout.meadow_ground={"cells":layout.meadow_ground.get("cells",{})}
	var cached:Dictionary=route_cache.get(cache_key,{})
	var same=not cached.is_empty() and cached.layout==layout
	if same:
		route_model=cached.model;route_viewport=cached.viewport;route_pen=cached.pen
		route_map=room
	if same:
		preload("res://core/farm_edit_view.gd").Herd.pen_override.assign(route_pen)
		if route_model.get("sim")!=null and spot not in ["qx_seedshop","qx_livestockshop"]:
			route_model.sim.bind_snapshot(farm.sim.data.duplicate(true))
			if herd_action and route_model.get("herd_ai")!=null:
				var herd=route_model.herd_ai
				for actor in herd.actors.values():
					route_model.surfaces.erase(actor.sprite.material)
					actor.node.queue_free()
				route_model.targets=route_model.targets.filter(func(t):return t.kind not in ["animal","pet"])
				herd.reset()
				herd.refresh()
		return route_model
	if not cached.is_empty():
		cached.viewport.free()
		route_cache.erase(cache_key)
	elif route_cache.size()>=3:
		var evict=route_cache.keys()[0]
		route_cache[evict].viewport.free()
		route_cache.erase(evict)
	route_viewport=SubViewport.new()
	route_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	route_viewport.gui_disable_input=true
	add_child(route_viewport)
	if spot=="qx_seedshop":route_model=preload("res://core/offscreen_seed_shop.gd").new()
	elif spot=="qx_livestockshop":route_model=preload("res://core/offscreen_stock_shop.gd").new()
	else:
		route_model=preload("res://core/farm_edit_view.gd").new()
		route_model.edit_map=room
		route_model.use_fixed_village=fixed_village
		route_model.sim=load(PASTURE).new()
		route_model.sim.bind_snapshot(farm.sim.data.duplicate(true))
	route_viewport.add_child(route_model)
	if room=="ranch" or room.begins_with("barn"):route_model.herd_ai.refresh()
	route_map=room;route_layout=layout.duplicate(true)
	route_pen=preload("res://core/farm_edit_view.gd").Herd.pen_override.duplicate(true)
	route_cache[cache_key]={"model":route_model,"viewport":route_viewport,"layout":route_layout,"pen":route_pen}
	return route_model

func _work_arrival(who:String,frame:Dictionary,out:Dictionary)->String:
	var c=_resident(who)
	var spot=str(frame.get("spot",""))
	var task=str(frame.get("workId",""))
	var action=str(frame.get("workAct",frame.get("act","")))
	if task=="" or c==null or not SPOT_PLACE.has(spot) or c.scene_id!=PLACE or c.want_zone!=spot:return "还没到要操作的地点。"
	if c.is_walking():
		out.waitMs=450;return ""
	var indoors=str(resident_rooms.inside.get(who,""))
	var requested=frame.get("arg","").get_slice("|",0) if action in ["edit_catalog","build_at","remove_at"] else ""
	if action in ["chest_store","chest_take"]:
		var placed=_farm_sim().sim.shared_chest_rooms()
		if placed.is_empty():return "还没摆共用物资箱。"
		requested=indoors if indoors in placed else ("ranch" if "ranch" in placed else str(placed[0]))
	if indoors.begins_with("barn") and action in ["collect","treat","pair","sell_animal","pair_free","pair_pause","process_stock"]:requested=indoors
	if action not in ["visit_home","enter_room","leave_room"] and indoors!="" and requested!=indoors:
		resident_rooms.inside.erase(who);indoors=""
	var room=requested if action in ["chest_store","chest_take"] else indoors if indoors!="" else str({"qx_farm":"ranch","qx_plaza":"village"}.get(spot,spot))
	var watching=active and is_instance_valid(scene) and place_now()==SPOT_PLACE[spot] and (scene.get("map_id")==room or spot in ["qx_seedshop","qx_livestockshop"])
	var now=Time.get_ticks_msec()
	var job:Dictionary=visitor_jobs.get(who,{})
	if watching and not visitors.has(who):_draw_visitors()
	var body=visitors.get(who,{}).get("node") if watching else null
	if watching and not is_instance_valid(body):return "还没到操作位置。"
	if job.get("id","")!=task or job.get("room","")!=room:
		var model=scene if watching else null
		var previous=preload("res://core/farm_edit_view.gd").Herd.pen_override.duplicate(true)
		if not watching:model=background_map(room,spot,action)
		var start:Vector2=body.position if watching else (model.player.position if model.get("player")!=null else Vector2(432,691))
		if job.get("room","")==room and not watching and not model.blocked(job.pos):start=job.pos
		var selector=str(frame.get("arg",""))
		var crop_cell=null
		if action in ["plant","harvest","water_plot"]:
			var plots=FARM.context(model.sim,"meadow").plots
			var selected=_plot_indices(model.sim,{"plots":plots},selector)
			if selected.size()==1:
				var xy=plots[selected[0]]
				crop_cell=Vector2i((Vector2(xy[0],xy[1])/FARM.cell_size()).floor())
				selector=str(selected[0]+1)
		var plan=plan_job(model,start,action,selector,spot)
		if crop_cell!=null:plan.cropCell=crop_cell
		if not watching:
			preload("res://core/farm_edit_view.gd").Herd.pen_override.assign(previous)
		if plan.has("waterSource"):
			out.waterSource=plan.waterSource;out.text=plan.error;return ""
		if plan.has("error"):return plan.error
		job=plan
		job.merge({"id":task,"room":room,"pos":start,"last":now,"node":body.get_instance_id() if watching else 0,"at":0,"expires":now+95000,"action":action})
		visitor_jobs[who]=job
		if action!="stand_up":resident_rooms.leisure.erase(who)
	if job.get("blocked",false):return "到操作点的路被挡住了。"
	if not watching:
		var budget=maxf(0.,(now-int(job.last))*.126)
		while budget>0 and not job.route.is_empty():
			var next:Vector2=job.route[0]
			var distance=job.pos.distance_to(next)
			job.pos=job.pos.move_toward(next,budget)
			budget-=distance
			if job.pos==next:job.route.remove_at(0)
		if job.route.is_empty() and job.at==0:job.at=now
		job.last=now;job.node=0
	if job.at>0 and now-int(job.at)>=650:
		if job.has("chest"):
			var furniture=_farm_sim().sim.data.get("layout",{}).get("placement_by_map",{}).get(room,{}).get("furniture",{})
			var exists=false
			for row in furniture.values():
				if row[0]=="shared_chest" and (Vector2(row[1],row[2])+Vector2(0,18)).distance_to(job.chest)<1:
					exists=true;break
			if not exists:return "箱子被移动了，请重新走到箱边。"
		if job.has("bank"):
			if watching:
				var close=Pond.banks(scene,body.position,str(job.bank.id))
				if close.is_empty() or body.position.distance_to(close[0].pos)>=58:return "岸边已改变，请重新走到鱼塘。"
			out.pondId=job.bank.id
		if job.has("gateEdge"):out.gateEdge=job.gateEdge
		if job.get("station","")!="":out.station=job.station
		out.arrived=true
	else:out.waitMs=450
	return ""

func plan_job(model,start:Vector2,action:String,arg:String,spot:String)->Dictionary:
	var route=PackedVector2Array()
	var plan={}
	if action in ["chest_store","chest_take"]:
		var boxes=model.targets.filter(func(t):return t.kind=="furniture" and t.extra=="shared_chest")
		boxes.sort_custom(func(a,b):return start.distance_squared_to(a.pos)<start.distance_squared_to(b.pos))
		for box in boxes:
			route=Work.walking_path(model,start,box.pos)
			if not route.is_empty() and route[-1].distance_to(box.pos)<58:
				plan.chest=box.pos
				break
			route.clear()
		if route.is_empty():return {"error":"共用物资箱尚未摆放或被挡住了。"}
	elif action in Pond.ACTIONS:
		for bank in Pond.banks(model,start,"" if action=="restock" else arg):
			route=Work.walking_path(model,start,bank.pos)
			if not route.is_empty() and route[-1].distance_to(bank.pos)<58:
				plan.bank=bank;break
			route.clear()
		if not plan.has("bank") and Pond.saved_keys(model.sim,"meadow").is_empty():return {"error":"自家农场还没有鱼塘。先挖塘，再到岸边放鱼苗。"}
		if not plan.has("bank"):return {"error":"没有可以走到的鱼塘岸边。"}
	else:
		if action=="feed_pet" and not _pet_all(arg):
			var pet=_pet_target(model.sim.pet_roster(),arg)
			if not pet.is_empty() and PET_RULES.is_away(pet,Time.get_unix_time_from_system()):return {"error":"这只宠物出门了，回来后再喂。"}
		var target=Work.target(self,model,action,arg,spot,start)
		if action in ["tea_break","foot_bath"]:
			var place="village_store" if action=="tea_break" else "village_bath"
			for fixture in model.targets:
				if fixture.kind=="portal" and fixture.extra==place:target=fixture.pos;break
		if action=="fill_water" and target==Vector2.INF:
			return {"error":"农场还没有水井或水泵。去村中心的村井打水，或在农场摆一口井。","waterSource":"village"}
		if action=="gate":
			var enclosure=FARM.context(model.sim,"meadow")
			var cell=_arg_cell(arg)
			for pen in FARM.enclosures(enclosure):
				if not pen.cells.has(cell):continue
				var edges=[]
				for inside in pen.cells:
					for d in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
						var outside=inside+d
						if pen.cells.has(outside) or not gate_approach_clear(enclosure,inside,outside):continue
						var edge=FARM._edge_between(inside,outside)
						if enclosure.edges.get(edge,"") not in ["fence","gate"]:continue
						var at=Vector2(outside)*64+Vector2(32,32)
						edges.append({"pos":at,"edge":edge,"distance":start.distance_squared_to(at)})
				edges.sort_custom(func(a,b):return a.distance<b.distance)
				for edge in edges:
					var path=Work.walking_path(model,start,edge.pos)
					if not path.is_empty():return {"route":path,"point":path[-1],"gateEdge":edge.edge}
				return {"error":"围栏外侧没有可抵达的门位，请留出一格通道。"}
		if target==Vector2.INF:return {"error":"这里没有对应的操作点。"}
		route=Work.walking_path(model,start,target)
		if action in ["dry_fish","take_honey"]:
			for interaction in model.targets:
				if interaction.kind==("hive" if action=="take_honey" else "dry_fish") and interaction.pos==target:
					plan.station=str(interaction.extra);break
	if route.is_empty():return {"error":"到操作点的路被挡住了。"}
	if action=="swim" and not model.can_swim_at(route[-1]):return {"error":"没有可以游进去的水域。"}
	plan.route=route;plan.point=route[-1]
	return plan
const ACTS := ["chest_store","chest_take","river_fish","restock","water_plot","walk_to","hold_food","farm_bench","stand_up","swim","water_seedlings","cottage_sleep","cottage_wake","look", "survey", "plant", "water", "harvest", "buy", "sell", "buy_young", "release", "feed",
	"water_pen", "add_water", "give_water", "collect", "treat", "pair", "sell_animal", "pond", "cook", "store", "take", "mill",
	"build_pen", "gate", "watch_pond","feed_fish","fish", "reel", "harvest_fish", "stock_fry", "cook_fish", "till", "dig", "fence", "unfence", "place_feeder", "fill_water", "guide",
	"adopt_pet", "name_pet", "feed_pet", "play_pet", "walk_pet", "follow_pet", "stay_pet", "pair_free", "pair_pause", "process_stock", "take_honey", "dry_fish","eat_harvest","edit_catalog","build_at","remove_at","expand_dorm","visit_home","enter_room","leave_room","tea_break","foot_bath","plaza_lamp","talk_worker","plaza_bench","festival_dance","village_mill","village_well","eat_meal","rest"]
const KINDS := {"牛":"cow", "羊":"sheep", "猪":"pig", "鸡":"chicken", "cow":"cow", "sheep":"sheep", "pig":"pig", "chicken":"chicken"}
## 食槽的中文名 / 背包键 -> 种类（业主：她买得到食槽）
const FEEDER_ALIAS := {"牧场食槽":"cow","通用食槽":"cow","牛草槽":"cow", "羊草架":"sheep", "猪食槽":"pig", "鸡食盘":"chicken",
	"feeder_cow":"cow", "feeder_sheep":"sheep", "feeder_pig":"pig", "feeder_chicken":"chicken",
	"食槽":"cow", "牛":"cow", "羊":"sheep", "猪":"pig", "鸡":"chicken"}

func resident_act(s: Dictionary, frame: Dictionary, out: Dictionary) -> String:
	var seed_choice=""
	if frame.get("workAct",frame.get("act",""))=="plant" and str(frame.get("arg","")).contains("|"):
		frame=frame.duplicate()
		seed_choice=str(frame.arg).get_slice("|",1).strip_edges()
		frame.arg=str(frame.arg).get_slice("|",0).strip_edges()
	var act := str(frame.get("act", ""))
	var arg := str(frame.get("arg", "")).strip_edges()
	var who := str(frame.get("actor", ""))          ## 2026-11-21 pets: 谁在动手（取名记 named_by）
	if act in ["place_bed","remove_bed","list_beds"]:return pet_beds.arrange(self,who,act,arg,out)
	if act=="companion_near" or frame.get("withCompanion",false):
		var operation=str(frame.get("workAct",act))
		if operation not in ["follow_pet","stay_pet","name_pet","play_pet","walk_pet","feed_pet"]:return "没有对应的随行动作。"
		var parts=_pet_parts(arg) if operation=="name_pet" else {}
		if str(parts.get("kind","")) in ["cow","sheep","pig","chicken"]:
			if act=="companion_near":out.near=false;return ""
			return "请到牧场给牲畜改名。"
		var candidate=str(parts.get("id",arg))
		var roster=_farm_sim().sim.pet_roster()
		var pet=_pet_target(roster,candidate)
		var body=_resident(who)
		var near=false
		if not pet.is_empty() and body!=null and body.placed and body.scene_id!=PLACE and pet.get("follow",false):
			var follower=travel_pets.actors.get(str(pet.id),{}).get("sprite")
			if is_instance_valid(follower) and follower.is_visible_in_tree():
				near=follower.get_parent()==body.get_parent() and follower.position.distance_to(body.feet)<=65
			else:near=str(pet.get("owner_id",""))==who
		if act=="companion_near":out.near=near;return ""
		if not near:return "宠物现在不在你身旁。"
		if operation!="name_pet":arg=str(pet.id)
	if act=="crop_targets":
		var farm=_farm_sim()
		var sim=farm.sim
		var ids=[]
		for i in _plot_indices(sim,FARM.context(sim,_farm_map(farm)),arg):
			if i>=sim.data.crops.size():continue
			var crop=sim.data.crops[i]
			if (frame.get("workAct")=="water_plot" and crop.planted and crop.progress<sim.CROP_SECONDS) or (frame.get("workAct")=="plant" and not crop.planted) or (frame.get("workAct")=="harvest" and crop.planted and crop.progress>=sim.CROP_SECONDS):ids.append(i+1)
		out.plotIds=ids
		if ids.is_empty():out.text="所选地块无需此操作或地号不存在，请看 plotList。"
		return ""
	if act=="approach":return _work_arrival(who,frame,out)
	if act in ["plant","harvest","water_plot"] and frame.has("workId"):
		var address=_farm_sim()
		var plots=FARM.context(address.sim,_farm_map(address)).plots
		var targets=_plot_indices(address.sim,{"plots":plots},arg)
		if targets.size()!=1:return "请逐块走到已开垦的田边操作。"
		var index=int(targets[0])
		if index>=address.sim.data.crops.size():return "田块已改变，请重新查看地号。"
		var last=address.sim.data.crops[index].get("workReceipt",{})
		if last.get("actor")==who and last.get("work")==frame.workId and last.get("act")==act:
			out.text=last.text;out.plotId=index+1;out.replayed=true;return ""
		var planned=visitor_jobs.get(who,{})
		var xy=plots[index]
		var cell=Vector2i((Vector2(xy[0],xy[1])/FARM.cell_size()).floor())
		if planned.get("id")!=frame.workId or planned.get("action")!=act or planned.get("cropCell")!=cell:
			return "田块或操作已改变，请重新走到这块田。"
		arg=str(index+1)
	if act in ["chest_store","chest_take"] and not Features.on("sharedChest12"):return "共用物资箱模块已关闭"
	if act in ["chest_store","chest_take"] and not frame.has("workId"):return "请先走到共用物资箱旁边。"
	if frame.has("workId"):
		var reached:Dictionary={}
		var reason:=_work_arrival(who,frame,reached)
		if reason!="":return reason
		if not reached.get("arrived",false):return "还在前往操作位置，本次操作没有执行。"
		if reached.has("pondId"):arg=str(reached.pondId)
		if reached.has("station"):arg=str(reached.station)
		if reached.has("gateEdge"):arg=arg+"|"+str(reached.gateEdge)
	if act=="guide":
		out.text=FARM.tutorial_text(arg)
		return ""
	if act=="water_seedlings":
		if active and is_instance_valid(scene) and place_now()=="qx:seedshop":
			scene.water_nursery();scene.save_study()
		else:
			var current=_farm_sim()
			current.sim.data.nursery_watered=true
			_farm_commit(current)
		out.text="已给青芽种子店窗边的幼苗浇水。";return ""
	if act in ["farm_bench","stand_up","swim","hold_food","walk_to"]:
		var resident=_resident(who)
		if resident==null or resident.scene_id!=PLACE or resident.want_zone!="qx_farm":return "请先到自家农场。"
		if act=="walk_to":
			if not frame.has("workId"):return "请指定农场的位置并走到那里。"
			out.text="已走到农场 "+arg+" 附近。";return ""
		if act=="hold_food":
			var food=_key_of(_farm_sim().sim,arg)
			if arg in ["","收起","none"]:held_by.erase(who);out.text="已收起点心。";return ""
			if food not in ["wheat","carrot"] or int(_farm_sim().sim.data.bag.get(food,0))<=0:return "请先备好小麦或胡萝卜。"
			held_by[who]=food;out.text="已拿出"+arg+"，附近喜欢这种点心的牲畜会跟上。";return ""
		if act=="stand_up":
			if resident_rooms.leisure.get(who,{}).get("verb","")!="farm_bench":return "目前没有坐在农场长凳上。"
			resident_rooms.leisure.erase(who);out.text="已起身。";return ""
		resident_rooms.leisure[who]={"verb":act,"until":0 if act=="farm_bench" else Time.get_ticks_msec()+30000}
		out.text="已坐到农场长凳上。" if act=="farm_bench" else "已游入农场水塘。";return ""
	if act in ["plaza_bench","festival_dance","plaza_lamp","talk_worker"]:return resident_rooms.village_act(self,who,act,arg,out)
	if act in ["visit_home","enter_room","leave_room"]:return resident_rooms.act(self,who,act,arg,out)
	if act in ["edit_catalog","build_at","remove_at"]:
		return preload("res://core/resident_editor.gd").run(self,_farm_sim(),act,arg,out)
	if act in ["cottage_sleep","cottage_wake","expand_dorm"]:
		var path:=profile_path(Stay.FILE)
		if _resident(who)==null:return "住户不存在。"
		if act=="cottage_wake":
			if not Stay.wake(path,who):return "床位没有保存成功。"
			out.text="已从私人小屋起床。";return ""
		var person=_resident(who)
		if person.scene_id!=PLACE or person.want_zone!="qx_farm" or person.is_walking():return "请先走到清溪村农场小屋。"
		var farm=_farm_sim()
		var cottage_exists:bool=farm.sim.data.get("layout",{}).has("meadow_house")
		if not cottage_exists and not (active and is_instance_valid(scene) and scene.get("open_meadow")==true):
			var file:=profile_path("open-meadow.json")
			if FileAccess.file_exists(file):
				var saved=JSON.parse_string(FileAccess.get_file_as_string(file))
				cottage_exists=saved is Dictionary and saved.get("layout",{}).has("meadow_house")
		if not cottage_exists and not (active and is_instance_valid(scene) and str(scene.get("map_id")).begins_with("room_private")):return "农场还没有建私人小屋。"
		if act=="expand_dorm":
			if not Stay.expand(path):return "宿舍扩建未能保存。"
			out.text="私人小屋的多人宿舍已经开放。";return ""
		var result:=Stay.claim(path,who,arg)
		if result.has("error"):return result.error
		out.bed=result.bed;out.text="已在私人小屋的床上躺下。";return ""
	if not act in ACTS: return "清溪村里没有这个操作：" + act + "（能做的看 out.farm.actions，或者先用 look 看一眼）"
	if get_tree().has_meta("rural_handoff"): return "清溪村这会儿正在换地图，过一会儿再试"
	var farm := _farm_sim()
	var sim = farm.sim
	var map := _farm_map(farm)
	## 2026-11-21（业主 ④）：survey 也可以带一块候选范围（左下:右上），先把"这块范围里有什么不能围的"列给她。
	if act == "survey" and arg.split(":").size() >= 4:
		var c := arg.split(":")
		var report := FARM.area_report(sim, map, Vector2i(int(c[0]), int(c[1])), Vector2i(int(c[2]), int(c[3])))
		out["farm"] = _farm_reading(sim, map)
		out["area"] = report
		if report.issue_count > 0 or report.out_of_zone_count > 0:
			return "这块范围（%s，%d 格）里不能围/要注意的有 %d 处：%s%s。" % [str(report.rect), int(report.cells), int(report.issue_count), "；".join((report.issues as Array).map(func(x): return str(x.text))), ("" if int(report.out_of_zone_count) == 0 else "；另有 %d 格在农场边界外" % int(report.out_of_zone_count))]
		return ""
	if act == "look" or act == "survey":
		out["farm"] = _farm_reading(sim, map, arg)
		out.farm.sight=farm_sight(who,sim,out.farm)   ## arg 可以是宠物编号/名字：看单只
		return ""
	if act in Pond.ACTIONS:
		if map!="meadow" or (farm.live and scene.get("map_id")=="ranch" and scene.get("open_meadow")!=true):return "只能在自家农场建好的鱼塘边操作。"
		var ids=Pond.saved_keys(sim,map)
		var current=sim.pond_list()
		if frame.has("workId") and active and place_now()=="qx:meadow" and scene.get("map_id")=="ranch":
			ids=[]
			for bank in Pond.banks(scene,Vector2.ZERO,""):
				if not ids.has(bank.id):ids.append(bank.id)
		var selected=Pond.wanted("" if act=="restock" and not frame.has("workId") else arg,ids)
		if selected=="" and not ids.is_empty():selected=ids[0]
		if not ids.has(selected) or not current.has(selected):return "请到自家农场实际建好的鱼塘边操作。还没有塘时，先在自家农场挖塘。"
		arg=selected
		var menu=Pond.menu(sim,current[arg])
		if act=="restock":
			var options=sim.live_catches()
			var choice=str(frame.get("arg","")).strip_edges()
			if choice!="" and not options.has(choice):
				var matching=options.filter(func(k):return sim.Fish.kinds()[k.get_slice(":",1)].name==choice or sim.Fish.label(k)==choice)
				if matching.size()!=1:return "请选择背包中的鱼："+str(options)
				choice=matching[0]
			if not "restock" in menu.buttons:return "鱼塘已满或背包中没有可放养的鱼。"
			out.text=sim.restock(current[arg],choice)
			_farm_commit(farm);out.farm=_farm_reading(sim,map);return ""
		if act=="watch_pond":
			out.text="E · 鱼塘 · 水边　"+menu.summary+"。可选："+"、".join(menu.buttons.map(func(key):return Pond.LABELS[key]))
			out.pondButtons=menu.buttons
			out.farm=_farm_reading(sim,map)
			return ""
		if act in Pond.LABELS and act not in menu.buttons:return "塘边目前只能"+"、".join(menu.buttons.map(func(key):return Pond.LABELS[key]))+"。"
	if act=="river_fish":
		if not frame.has("workId") or frame.get("spot")!="qx_plaza":return "请先走到清溪村的小河边。"
		var delay=sim.Fish.bite_delay()
		fishing_lines[who]={"river":true,"start":Time.get_ticks_msec(),"delay":delay}
		out.text="已在村中小河抛竿。";out.biteMs=ceili(delay*1000);return ""
	if act in ["fish","reel"]:
		var ponds:Dictionary=sim.pond_list()
		if act=="fish":
			if arg=="":
				for id in ponds:
					if int(ponds[id].count)>0:arg=id;break
			if not ponds.has(arg) or int(ponds[arg].count)<=0:return "这里没有可钓的鱼。先向鱼塘放苗，或选有鱼的塘。"
			var delay:float=sim.Fish.bite_delay()
			fishing_lines[who]={"pond":arg,"start":Time.get_ticks_msec(),"delay":delay}
			out["text"]="已在%s抛竿，等待浮漂下沉。"%arg
			out["biteMs"]=ceili(delay*1000)
			return ""
		var line:Dictionary=fishing_lines.get(who,{})
		if line.is_empty():return "请先到塘边抛竿。"
		var t=(Time.get_ticks_msec()-line.start)/1000.0
		fishing_lines.erase(who)
		if not sim.Fish.hooked(t,line.delay):return "过早收竿，鱼没咬钩。" if t<line.delay else "错过鱼讯，鱼游走了。"
		if line.get("river",false):
			var resident=_resident(who)
			if resident==null or resident.scene_id!=PLACE or resident.want_zone!="qx_plaza" or resident.is_walking():return "已经离开河边。"
			var catch_key=sim.wild_catch()
			_farm_commit(farm)
			out.text="钓到"+sim.goods_name(catch_key)+"，已收进农场背包，可带到自家鱼塘放养。";out.item=catch_key;return ""
		if not ponds.has(line.pond):return "这口塘已经移除了。"
		var key:String=sim.catch_fish(ponds[line.pond])
		if key=="":return "塘里的鱼已被钓走。"
		out["text"]="钓到%s，已放进农场背包；可出售或留作鱼肉料理。"%sim.goods_name(key)
		_farm_commit(farm)
		out["farm"]=_farm_reading(sim,map)
		return ""
	if act in ["follow_pet","stay_pet","name_pet"]:
		var selection=_pet_parts(arg) if act=="name_pet" else {}
		if not str(selection.get("kind","")) in ["cow","sheep","pig","chicken"]:
			var pet=_pet_target(sim.pet_roster(),str(selection.get("id",arg)))
			if pet.is_empty():return "请指定一只现有宠物。"
			var why=sim.Ownership.denied(pet,who)
			if why!="":return why
	var refused := _farm_precheck(sim, map, act, arg)
	if refused != "":
		out["refused"] = refused
		out["farm"] = _farm_reading(sim, map)
		return refused
	if act in ["eat_meal","rest","foot_bath","eat_harvest","tea_break"]:
		var current=Life.feeling_now(s.get("feeling"),Time.get_unix_time_from_system()*1000.)
		var shared_energy=sim.data.energy
		sim.data.energy=current.energy
		var original=sim.data.duplicate(true)
		var wallet=sim.data.coins
		sim.data.coins=int(s.wallet.coins)
		original.coins=sim.data.coins
		farm_wallet.resident_action=true
		var message=_farm_do(sim,map,act,arg,who)
		var success=sim.data!=original
		current.energy=sim.data.energy
		var coins=int(sim.data.coins)
		sim.data.coins=wallet;sim.data.energy=shared_energy
		farm_wallet.resident_action=false
		if not success and act=="foot_bath" and current.energy>=100:
			out.text="已经泡过脚，精力已满。";return ""
		if not success:return message
		if act in ["eat_meal","eat_harvest"]:
			current.satiety=clampf(float(current.satiety)+(40 if act=="eat_meal" else 12),0.,100.)
		current.last=message
		s.feeling=current;s.wallet.coins=coins
		_farm_commit(farm)
		out.text=message+"，目前个人精力 %d、饱腹 %d。"%[current.energy,current.satiety]
		out.farm=_farm_reading(sim,map)
		return ""
	var owner_coins = sim.data.coins
	var mine := int(s["wallet"]["coins"])
	sim.data.coins = mine                       ## 她付钱（也收钱）用她自己的零花钱
	var before := JSON.stringify(sim.data)
	farm_wallet.resident_action=true
	var text := _farm_do(sim, map, act, arg, who, seed_choice)
	if farm.live and act in ["release","sell_animal"] and scene.has_method("refresh_life"):scene.refresh_life()
	var after_coins := int(sim.data.coins)
	var changed := JSON.stringify(sim.data) != before
	sim.data.coins = owner_coins                ## 业主清溪村的零钱不动
	farm_wallet.resident_action=false
	if not changed:
		var water_ok=act in ["give_water","water_pen","add_water"] and text.contains("满")
		if water_ok or (act in ["fill_water","village_well"] and int(sim.data.bag.get("well_water",0))>=3) or (act=="gate" and text.begins_with("这圈已有")) or (act=="build_pen" and text.ends_with("都已齐全。")):
			out["text"]=text;out["farm"]=_farm_reading(sim,map);return ""
		return text if text != "" else "什么也没变"
	var delta := after_coins - mine
	s["wallet"]["coins"] = maxi(mine, mini(Economy.reward_cap, mine + delta)) if delta > 0 else mine + delta
	if delta > 0 and int(s["wallet"]["coins"]) < mine + delta: text += "（零花钱最多攒 %d，多出的没有收进来）" % Economy.reward_cap
	if act in ["plant","harvest","water_plot"] and frame.has("workId"):
		var plot=int(arg)-1
		sim.data.crops[plot]["workReceipt"]={"actor":who,"work":frame.workId,"act":act,"text":text}
		out.plotId=plot+1
	if not _farm_commit(farm):return "农场存档写入失败，请检查磁盘后重试。"
	if act in Pond.ACTIONS:text="自家农场 · "+arg+"："+text
	out["text"] = text
	out["coins"] = int(s["wallet"]["coins"])
	out["farm"] = _farm_reading(sim, map)
	return ""

## 哪张农场：开荒农场（业主真正在玩的 open meadow）或村中心牧场。
func _farm_map(farm: Dictionary) -> String:
	if bool(farm.get("live", false)) and is_instance_valid(scene):
		if scene.get("open_meadow") == true:return "meadow"
		if scene.get("map_id")=="ranch":return "ranch"
	var L:Dictionary = farm.sim.data.get("layout", {})
	if L.has("meadow_pen") or L.has("meadow_ground"): return "meadow"
	if L.has("ranch_v3"): return "ranch"
	return "meadow"   ## 新存档：业主的农场是开荒农场，围栏/田都是空的

func _farm_sim() -> Dictionary:
	if active and is_instance_valid(scene) and scene.get("sim") != null and scene.sim.has_method("crop_action"):
		return {"sim":scene.sim, "live":true}
	var sim = load(PASTURE).new()
	var path:=profile_path(SIM_FILES[0])
	if FileAccess.file_exists(path):sim.load_from(path)
	if Economy.people.get("owner",{}).has("wallet"):sim.data.coins=farm_wallet.balance()
	return {"sim":sim, "live":false}

func _farm_commit(farm: Dictionary) -> bool:
	travel_pets.remember(farm.sim)
	if farm.live:
		if scene.get("ground_tiles") != null and scene.ground_tiles.has_method("sync_fish_counts"): scene.ground_tiles.sync_fish_counts()
		if scene.has_method("save_progress"):scene.save_progress()
		elif scene.has_method("save_study"):scene.save_study()
		if scene.has_method("update_hud"): scene.update_hud()
		scene.queue_redraw()
		return true   ## 场景自己照常保存（离开、关闭时）
	return farm.sim.save_to(profile_path(SIM_FILES[0]))

## 农场正开着时拿它的 region（真实的开垦/围栏/食槽/地面编辑器都在那里），否则 null。
func _region():
	if not active or not is_instance_valid(scene): return null
	var r = scene.get("region")
	return r if r != null and r.has_method("add_plot") and r.id in ["ranch","field"] else null

# ---------------- 前置校验：缺什么就说缺什么，绝不假装 ----------------
func _farm_precheck(sim, map: String, act: String, arg: String) -> String:
	var ctx := FARM.context(sim, map)
	match act:
		"plant":
			var idxs := _plot_indices(sim, ctx, arg)
			if idxs.is_empty(): return "这块地还没开垦：先用 till 开垦（现在的田地 %d 块）" % int(FARM.plot_summary(sim, ctx).total)
			var missing := []
			for i in idxs:
				var st := FARM.plot_status(sim, ctx, i)
				for m in st.missing:
					if not m in missing: missing.append(m)
			if not missing.is_empty():
				return FARM.missing_text(missing) + "。" + _plant_hint(missing)
		"water":
			if int(sim.data.bag.get("well_water",0))<=0:return "水壶空了，请先到井边打水。"
		"feed":
			var kind := _arg_kind(arg)
			if kind == "": return "要照顾哪种动物：牛、羊、猪、鸡"
			## 几种"喂不了"要分得开：食槽没料 / 背包没料 / 水不够 / 这只已经吃饱了。
			var feed_key := str(FARM.livestock_rules().get("feed_item", {}).get(kind, "hay"))
			if int(sim.data.get("bag", {}).get(feed_key, 0)) <= 0 and float(sim.livestock.data.pens.get(kind,{}).get("feed",0))<=0:
				return "缺：饲料（背包里没有%s，%s也添不进新料）" % [str(FARM.livestock_rules().get("feed_name", {}).get(kind, "饲料")), FARM.feeder_cn(kind)]
			var one := _animal_of(sim, kind, arg)
			if not one.is_empty():
				var nd := FARM.animal_needs(one)
				if float(nd.satiety) > float(FARM.needs_rules().get("hungry_below", 48.0)):
					return "%s#%s 已经吃饱了（%s %.0f，低于 %.0f 才会吃）：不用喂它，可以让它继续产东西" % [FARM.kind_cn(kind), str(one.id), FARM.needs_name("satiety"), float(nd.satiety), float(FARM.needs_rules().get("hungry_below", 48.0))]

		"water_pen", "add_water":
			var kind := _arg_kind(arg)
			if kind == "" and arg == "":
				return ""
			if kind=="":return "要给哪种动物补水：牛、羊、猪、鸡"
	var pet_problem := _pet_precheck(sim, act, arg)
	if pet_problem != "":
		return pet_problem
	return ""

## ---------------- 2026-11-21 pets：宠物动作的前置（缺什么就说缺什么） ----------------
## 规则/阈值全在 pets_rules.json；这里只做"这一步现在能不能做"的判断，绝不假装。
func _pet_precheck(sim, act: String, arg: String) -> String:
	if not (act in ["adopt_pet", "name_pet", "feed_pet", "play_pet", "walk_pet"]):
		return ""
	if not PET_RULES.ok():
		return "宠物规则文件没装好（qingxi-live/village-center/pets_rules.json）：先别动宠物，把这件事告诉主人"
	var roster = sim.pet_roster()
	match act:
		"adopt_pet":
			## v2：arg 可以写 猫 / 狗，也可以写 猫:橘猫 这种"种类:品种"。品种认不出就列出来给她选。
			var pick := PET_RULES.parse_breed(arg)
			if str(pick.get("kind", "")) == "":
				return _pet_breed_help(arg)
			## 钱在 _farm_do 里按"她自己的零花钱"扣（resident_act 会先换手），这里不查业主的钱包。
		"name_pet":
			var parts := _pet_parts(arg)
			if str(parts.get("id", "")) == "":
				return "要给谁取名字？arg 写 编号:名字，例如 7:咪咪（宠物编号看 farm.petsDetailed，牲畜编号看 farm.animals；牲畜也可以写 牛:3:大黄）"
			var nm := str(parts.get("name", ""))
			var checked := PET_RULES.name_ok(nm)
			if not bool(checked.get("ok", false)):
				return str(checked.get("why", "这个名字不能用"))
			var name_kind := str(parts.get("kind", ""))
			if name_kind in ["cow", "sheep", "pig", "chicken"]:
				var found_animal := false
				for a in sim.livestock.data.get("herd", []):
					if str(a.get("kind", "")) == name_kind and str(a.get("id", "")) == str(parts.id):
						found_animal = true
						var wait_a := PET_RULES.rename_wait(a, Time.get_unix_time_from_system())
						if wait_a > 0.5:
							return "%s #%s 刚改过名字，再等 %.0f 秒" % [Book_name(name_kind), str(parts.id), wait_a]
						break
				if not found_animal:
					return "没有 %s #%s 这只动物（编号看 farm.animals）" % [Book_name(name_kind), str(parts.id)]
			else:
				var pet: Dictionary = roster.find(str(parts.id))
				if pet.is_empty():
					return "没有编号 #%s 的宠物（现在有 %d 只，编号看 farm.petsDetailed）" % [str(parts.id), roster.count()]
				var wait := PET_RULES.rename_wait(pet, Time.get_unix_time_from_system())
				if wait > 0.5:
					return "%s 刚改过名字，再等 %.0f 秒" % [PET_RULES.name_text(pet), wait]
		"feed_pet":
			var pet2 := _pet_target(roster, arg)
			if pet2.is_empty() and not _pet_all(arg):
				return "" if _pet_all(arg) else "要喂哪只？arg 写编号（例如 7）或 猫/狗，空 = 全部"
			if not pet2.is_empty() and PET_RULES.is_away(pet2,Time.get_unix_time_from_system()):return "这只宠物出门了，回来后再喂。"
			var kinds2 := ["cat", "dog"] if _pet_all(arg) else [str(pet2.get("kind", ""))]
			if _pet_has_food(roster, sim.data.get("bag", {}), kinds2) == "":
				return "缺：饲料（背包里没有猫/狗能吃的东西：牧铃畜牧铺 qx_livestock_counter 用 buy 买猫粮或狗粮，每份 3 币，再回来 feed_pet）"
		"play_pet":
			var pet3 := _pet_target(roster, arg)
			if pet3.is_empty():
				return "要陪哪只玩？arg 写编号（例如 7）或 猫/狗"
			if PET_RULES.is_dog(pet3) and PET_RULES.anxious(pet3, Time.get_unix_time_from_system()):
				return "%s 现在有点着急，不肯叼球：先带它出去走走（walk_pet %s）" % [PET_RULES.name_text(pet3), str(pet3.get("id", ""))]
		"walk_pet":
			var pet4 := _pet_target(roster, arg)
			if pet4.is_empty() and _pet_all(arg):
				return ""
			if pet4.is_empty():
				return "要遛哪只？arg 写编号（例如 7）或 狗"
			if not PET_RULES.is_dog(pet4):
				return "%s 不用遛：猫自己会出门转，回来就好" % PET_RULES.name_text(pet4)
	return ""

## "7:咪咪" / "猫:7:咪咪" / "cow:3:大黄" -> {kind, id, name}
## kind 是 cat/dog/cow/sheep/pig/chicken 之一（没写就是 ""，靠编号去宠物名册里找）。
func _pet_parts(arg: String) -> Dictionary:
	var t := arg.strip_edges().replace("，", ":").replace(",", ":")
	var parts := t.split(":", false)
	if parts.is_empty():
		return {}
	var head := str(parts[0]).strip_edges()
	var kind := PET_RULES.kind_of(head)
	if kind == "":
		kind = str(KINDS.get(head, ""))   # 牛/羊/猪/鸡 -> cow/sheep/pig/chicken
	var id := ""
	var nm := ""
	if kind != "" and parts.size() >= 2:
		id = str(parts[1]).strip_edges()
		nm = ":".join(parts.slice(2)) if parts.size() > 2 else ""
	elif parts.size() >= 2:
		id = head
		nm = ":".join(parts.slice(1))
	else:
		id = head
	return {"kind": kind, "id": id, "name": nm}

## 牲畜记录也共用命名机制（同一套字段 name/named_by/named_at）。返回 {ok, text}。
func _name_livestock(sim, kind: String, id: String, raw: String, who: String) -> Dictionary:
	if kind == "" or id == "":
		return {"ok": false, "text": ""}
	for a in sim.livestock.data.get("herd", []):
		if str(a.get("kind", "")) != kind or str(a.get("id", "")) != id:
			continue
		var now := Time.get_unix_time_from_system()
		var wait := PET_RULES.rename_wait(a, now)
		if wait > 0.5:
			return {"ok": false, "text": "%s #%s 刚改过名字，再等 %.0f 秒" % [Book_name(kind), id, wait]}
		var checked := PET_RULES.name_ok(raw)
		if not bool(checked.get("ok", false)):
			return {"ok": false, "text": str(checked.get("why", "这个名字不能用"))}
		var cleaned := str(checked.get("text", ""))
		a["name"] = cleaned
		a["named_by"] = who
		a["named_at"] = now
		if cleaned == "":
			return {"ok": true, "text": "把 %s #%s 的名字清掉了" % [Book_name(kind), id]}
		return {"ok": true, "text": "把 %s #%s 叫作「%s」了（%s 取的，所有人都看得见）" % [Book_name(kind), id, cleaned, PET_RULES.named_by_cn(who) if PET_RULES.named_by_cn(who) != "" else who]}
	return {"ok": false, "text": "没有 %s #%s 这只动物（编号看 farm.animals）" % [Book_name(kind), id]}

## 牲畜记录带名字时的显示："「大黄」荷斯坦牛 #3"。
func _animal_display(a: Dictionary) -> String:
	var Book = load("res://qingxi-live/village-center/breed_catalog.gd")
	var base := "%s #%s" % [Book.breed_name(a), str(a.get("id", ""))]
	var nm := str(a.get("name", "")).strip_edges()
	return "「%s」%s" % [nm, base] if nm != "" else base

## "要领养猫还是狗？" + 每个品种的真实价格（价格全部来自 pets_rules.json，不在代码里写数字）。
func _pet_breed_help(arg: String) -> String:
	var lines := []
	for k in PET_RULES.kinds():
		var rows := PET_RULES.breed_menu(str(k))
		if rows.is_empty():
			continue
		var bits := []
		for r in rows:
			bits.append("%s %d 币" % [str(r.get("name", "")), int(r.get("price", 0))])
		lines.append("%s：%s" % [PET_RULES.kind_cn(str(k)), "、".join(bits)])
	var head := "要领养猫还是狗？" if arg.strip_edges() == "" else "没有这个品种：%s。" % arg.strip_edges()
	return "%sarg 写 猫 或 狗，想挑品种就写 猫:橘猫 / 狗:金毛。现在能领养的：%s" % [head, "；".join(lines)]

## 点名的那一只（编号或名字）；认不出来返回 {}。
func _pet_target(roster, arg: String) -> Dictionary:
	var t := arg.strip_edges()
	if t == "" or _pet_all(t):
		return {}
	var pet: Dictionary = roster.find(t)
	if not pet.is_empty():
		return pet
	# "猫:7" 这种写法
	var parts := t.replace("，", ":").replace(",", ":").split(":", false)
	for p in parts:
		var found: Dictionary = roster.find(str(p).strip_edges())
		if not found.is_empty():
			return found
	return {}

func _pet_all(arg: String) -> bool:
	return arg.strip_edges() in ["", "all", "全部", "所有", "都"]

## 背包里有没有这类宠物能吃的东西（返回找到的键，没有返回 ""）。
func _pet_has_food(roster, bag: Dictionary, kinds: Array) -> String:
	for kind in kinds:
		for item in PET_RULES.feed_items(str(kind)):
			var want := str(item)
			for k in bag:
				if int(bag[k]) <= 0:
					continue
				if str(k) == want or str(k).begins_with(want + ":"):
					return str(k)
	return ""

## 挑出要动手的那几只：点名优先，否则这一类全部（空 = 猫狗全部）。
## v2：arg 写 猫:橘猫 就是"这个品种全部"；只写 猫 才是"这一类全部"。
func _pet_choose(roster, arg: String) -> Array:
	var one := _pet_target(roster, arg)
	if not one.is_empty():
		return [one]
	var t := arg.strip_edges()
	var pick := PET_RULES.parse_breed(t)
	if str(pick.get("kind", "")) != "":
		if t.contains(":") or t.contains("："):
			return roster.pets_of_breed(str(pick.kind), str(pick.get("breed", "")))
		return roster.pets_of(str(pick.kind))
	if _pet_all(t):
		return roster.list()
	return []

func _plant_hint(missing: Array) -> String:
	for m in missing:
		match str(m.code):
			"water": return "hint：用 dig 在田边挖一格水渠（半径 %d 格内算有水）" % int(FARM.water_rules().get("plot_reach_cells", 3))
			"seed": return "hint：去青芽种子店 buy 种子、小麦或胡萝卜"
			"tilled": return "hint：用 till 开垦"
			"planted": return "hint：这块地已经种着，等熟了 harvest"
	return ""

func _pen_hint(kind: String, missing: Array) -> String:
	for m in missing:
		match str(m.code):
			"pen": return "hint：先 fence 闭合，dig 确认圈内水源，gate 安装木门，再把%s place_feeder 摆进去（围栏已有就直接算数）" % FARM.feeder_cn(kind)
			"water": return "hint：dig 挖一格水渠进圈里，或者 give_water 加水槽"
			"feed_in_trough": return "hint：feed 给%s添一份%s" % [FARM.feeder_cn(kind), str(FARM.livestock_rules().get("feed_name", {}).get(kind, "饲料"))]
	return ""

# ---------------- 地号 / 格子 ----------------
## 田格编号（她写 "1-6,9"，1 起）；空或 all = 全部。只返回**真的开垦过**的地。
func _plot_indices(sim, ctx: Dictionary, arg: String) -> Array:
	var n: int = int(ctx.get("plots", []).size())
	if n <= 0: return []
	if arg == "" or arg in ["all", "全部", "所有"]: return range(n)
	var out := []
	var selector=arg.strip_edges().replace("，",",").replace("：",":")
	var pair=selector.replace(",",":").split(":")
	if pair.size()==2 and pair[0].is_valid_int() and pair[1].is_valid_int():
		var wanted=Vector2i(int(pair[0]),int(pair[1]))
		for i in n:
			var row=ctx.plots[i]
			var xy=row.rect.get_center() if row is Dictionary and row.has("rect") else Vector2(row[0],row[1])
			if Vector2i((xy/64.).floor())==wanted:return [i]
		if ":" in selector:return []
	for part in selector.split(",",false):
		var bounds=part.strip_edges().split("-")
		if bounds.size()>2 or not bounds[0].is_valid_int() or not bounds[-1].is_valid_int():return []
		var first=int(bounds[0])
		var last=int(bounds[-1])
		if first<1 or last<first:return []
		for i in range(first-1,mini(last,n)):
			if not i in out:out.append(i)
	return out

## 格子写法 "c:r"（c、r 都是世界坐标 /64 向下取整）。
func _arg_cell(arg: String) -> Vector2i:
	var t := arg.strip_edges().replace(",", ":").replace("，", ":")
	var parts := t.split(":", false)
	if parts.size() < 2: return Vector2i(-1, -1)
	return Vector2i(int(parts[0]), int(parts[1]))

func _key_of(sim, name: String) -> String:
	if name=="混合鱼苗":return "fry"
	if sim.ITEM_NAMES.has(name) or sim.data.bag.has(name): return name
	for k in sim.ITEM_NAMES:
		if sim.ITEM_NAMES[k] == name: return k
	for k in sim.data.bag:
		if sim.goods_name(k) == name: return k
	return name

## 存档里的 layout（田格/围栏/食槽/水渠都在这里）；没有就建一个并真的挂到 sim.data 上。
## 否则改动落在一个临时字典里，changed 检查会说「什么也没变」—— 这正是以前「种了但世界没变」的坑。
func _layout(sim) -> Dictionary:
	if not sim.data.has("layout"): sim.data["layout"] = {}
	return sim.data.layout

func _pens_store(sim, map: String) -> Dictionary:
	var L:Dictionary = _layout(sim)
	var key := "meadow_pen" if map == "meadow" else "ranch_v3"
	if not L.has(key): L[key] = {"edges": {}, "feeders": []}
	if map == "ranch" and not L[key].has("feeders"):
		# 村中心牧场：第一次用时用烘焙的 default_ranch 播种（跟 region.ranch() 一致）
		var d:Dictionary = FARM._json("res://qingxi-live/village-center/art/regions/ranch/layout.json").get("default_ranch", {})
		if not d.is_empty():
			L[key]["edges"] = FARM._default_edges(sim, d)
			L[key]["feeders"] = d.get("feeders", [])
	return L[key]

# ---------------- 动作 ----------------
func _farm_do(sim, map: String, act: String, arg: String, who: String = "", seed_choice: String = "") -> String:
	var lines := []
	var ctx := FARM.context(sim, map)
	match act:
		"adopt_pet":
			var pick := PET_RULES.parse_breed(arg)
			lines.append(sim.adopt_pet(str(pick.get("kind", "")), str(pick.get("breed", "")),who))
		"name_pet":
			var parts := _pet_parts(arg)
			var kind := str(parts.get("kind", ""))
			var named := {}
			if kind in ["cow", "sheep", "pig", "chicken"]:
				named = _name_livestock(sim, kind, str(parts.get("id", "")), str(parts.get("name", "")), who)
			else:
				named = sim.name_owned_pet(str(parts.get("id", "")), str(parts.get("name", "")), who)
			lines.append(str(named.get("text", "")))
		"feed_pet":
			var roster = sim.pet_roster()
			for pet in _pet_choose(roster, arg):
				var said: String = roster.feed(str(pet.get("id", "")), sim.data.bag)
				if said != "": lines.append(said)
			if lines.is_empty(): lines.append("没有可以喂的宠物")
		"play_pet":
			var roster2 = sim.pet_roster()
			for pet2 in _pet_choose(roster2, arg):
				var said2: String = roster2.play(str(pet2.get("id", "")))
				if said2 != "": lines.append(said2)
			if lines.is_empty(): lines.append("没有可以陪玩的宠物")
		"walk_pet":
			var roster3 = sim.pet_roster()
			for pet3 in _pet_choose(roster3, arg):
				var said3: String = roster3.walk(str(pet3.get("id", "")))
				if said3 != "": lines.append(said3)
			if lines.is_empty(): lines.append("没有可以遛的狗（猫不用遛）")
		"till":
			lines.append(_till(sim, map, arg))
		"dig":
			lines.append(_dig(sim, map, arg))
		"guide":
			## 教程只在她主动查时整篇返回；look 里只给一句摘要（业主：别每轮把整篇灌进上下文）。
			return FARM.tutorial_text(arg)
		"unfence":
			lines.append(_unfence(sim, map, arg))
		"fence":
			lines.append(_fence(sim, map, arg))
		"place_feeder":
			lines.append(_place_feeder(sim, map, arg))
		"fill_water":
			lines.append(_fill_water(sim, map))
		"plant", "harvest":
			for i in _plot_indices(sim, ctx, arg):
				var c: Dictionary = sim.data.crops[i]
				var ripe: bool = c.planted and float(c.progress) >= sim.CROP_SECONDS
				if (act == "plant" and not c.planted) or (act == "harvest" and ripe):
					var t:String
					if act=="plant" and seed_choice!="":
						var sow_key=_key_of(sim,seed_choice)
						if not sim.Garden.book().produce.has(sow_key):sow_key=sim.Garden.book().produce.find_key(sow_key)
						t=sim.sow(i,str(sow_key))
					else:t=sim.crop_action(i)
					lines.append("第%d块：%s" % [i + 1, t.get_slice("；", 0)])
			if lines.is_empty(): return {"plant": "选的地都种着东西了", "harvest": "还没有成熟的作物"}[act]
		"water_plot":
			if arg.strip_edges()=="":return "请填写一块田的地号。"
			var ids=_plot_indices(sim,ctx,arg)
			if ids.size()!=1:return "这里没有这块田。"
			var crop=sim.data.crops[ids[0]]
			if not crop.planted or float(crop.progress)>=sim.CROP_SECONDS:return "请选择已播种且尚未成熟的田。"
			return sim.crop_action(ids[0])
		"water":
			var targets=_plot_indices(sim,ctx,arg)
			if targets.is_empty():return "没有对应的田块。"
			var anchor=targets[0]
			for i in targets:
				var crop=sim.data.crops[i]
				if crop.planted and crop.water<sim.CROP_SECONDS-float(crop.progress):
					anchor=i;break
			var row=ctx.plots[anchor]
			var cells=[]
			for i in ctx.plots.size():
				var other=ctx.plots[i]
				if absf(other[0]-row[0])<=64 and absf(other[1]-row[1])<=64:cells.append(i)
			return sim.water_area(cells)
		"buy":   ## "白菜种子" 或 "牛草槽"，可选 ×N / *N
			var parts := arg.replace("×", "*").replace("x", "*").replace("X", "*").split("*", false)
			var want := parts[0].strip_edges() if parts.size() > 0 else ""
			var n := clampi(int(parts[1]) if parts.size() > 1 else 1, 1, 20)
			var product_key:=_key_of(sim,want)
			var unit_cost:=int(sim.PRICES.get(product_key,0))
			if FEEDER_ALIAS.has(want):unit_cost=int(sim.FEEDER_PRICE.get(FEEDER_ALIAS[want],unit_cost))
			if unit_cost*n>int(sim.data.coins):
				return "%s ×%d 需要 %d 元，现有 %d 元。"%[want,n,unit_cost*n,int(sim.data.coins)]
			if FEEDER_ALIAS.has(want) and str(want).begins_with("牛") or FEEDER_ALIAS.has(want) and str(want).ends_with("槽") or FEEDER_ALIAS.has(want) and str(want).ends_with("架") or FEEDER_ALIAS.has(want) and str(want).ends_with("盘"):
				var kind := str(FEEDER_ALIAS[want])
				for i in n: lines.append(sim.buy_feeder(kind))
			elif FEEDER_ALIAS.has(want) and str(want).begins_with("feeder_"):
				var kind := str(FEEDER_ALIAS[want])
				for i in n: lines.append(sim.buy_feeder(kind))
			else:
				var key := _key_of(sim, want)
				for i in n: lines.append(sim.buy(key))
		"sell":
			if arg in ["all","全部"]:
				for key in sim.data.bag.keys():
					if sim.shipping_price(key)>0 and int(sim.data.bag[key])>0:
						lines.append(sim.ship_goods(key,int(sim.data.bag[key])))
				if lines.is_empty():return "背包里没有能卖的东西。"
			else:
				var order=arg.replace("×","*").split("*")
				if order.size()>2 or str(order[0]).strip_edges()=="":return "请填品名，或品名×数量；整批写品名×全部。"
				var key=_key_of(sim,str(order[0]).strip_edges())
				var quantity=1
				if order.size()==2:
					var amount=str(order[1]).strip_edges()
					if amount in ["全部","all"]:quantity=int(sim.data.bag.get(key,0))
					elif amount.is_valid_int() and int(amount)>0:quantity=int(amount)
					else:return "出售数量必须是正整数。"
				return sim.ship_goods(key,quantity)
		"buy_young","release":
			return _young_stock(sim,act,arg)
		"feed", "water_pen", "add_water", "give_water":
			var kinds: Array = [_arg_kind(arg)] if arg != "" and arg != "all" else ["cow", "sheep", "pig", "chicken"]
			var need := "food" if act == "feed" else "drink"
			for k in kinds:
				if k == "": return "要照顾哪种动物：牛、羊、猪、鸡"
				if sim.livestock.members(k).is_empty(): continue
				lines.append(Book_name(k) + "：" + (sim.livestock.feed_pen(k, sim.data.bag) if act == "feed" else sim.livestock.water_pen(k)))
				## 2026-11-20 round 2（业主）：喂/给水要真的把**这只动物**的值抬上去，而不是只改槽里的数字。
				## 用的是牧场自己的进食逻辑（没人看着时它就是这么吃的），所以不会凭空造出一条平行规则。
				lines.append(_feed_animals_now(sim, k, need, arg))
			if lines.is_empty(): return "牧场还没有这种动物"
		"collect":
			for a in sim.livestock.data.herd.duplicate():
				if arg == "" or str(a.id) == arg:
					var t: String = sim.livestock.collect(str(a.id), sim.data.bag)
					if t.begins_with("收获"): lines.append(t)
			if lines.is_empty(): return "目前没有可以收取的产物"
		"treat":
			lines.append(sim.livestock.treat(arg, sim.data.bag))
		"pair":   ## "id,mate"
			var ids := arg.replace("，", ",").split(",", false)
			if ids.size() < 2: return "配对要写两只动物的编号，例如 3,5"
			lines.append("配好了，它们会自己生小崽" if sim.pair_stock(ids[0].strip_edges(), ids[1].strip_edges(), true) else "这两只配不了（要同种、一公一母、都成年）")
		"sell_animal","process_stock":
			lines.append(sim.sell_stock(arg, act=="process_stock"))
		"pair_free","pair_pause":
			if not sim.pair_stock(arg,"",act=="pair_free"):return "找不到要调整配对的牲畜。"
			lines.append("已恢复自由配对" if act=="pair_free" else "已暂停配对")
		"follow_pet","stay_pet":
			var pet=_pet_target(sim.pet_roster(),arg)
			if pet.is_empty():return "请写宠物编号或名字。"
			var denied=sim.Ownership.denied(pet,who)
			if denied!="":return denied
			lines.append(sim.Ownership.follow(pet,who,act=="follow_pet"))
		"chest_store","chest_take":
			var parts=arg.split("×")
			if parts.size()>2 or (parts.size()==2 and not parts[1].strip_edges().is_valid_int()):return "请填写物品名×数量。"
			var amount=int(parts[1]) if parts.size()==2 else 1
			var source:Dictionary=sim.data.get("shared_chest",{}) if act=="chest_take" else sim.data.bag
			var item=str(parts[0]).strip_edges()
			if not source.has(item):
				item=str(FARM.rules().get("item_aliases",{}).get(item,item))
			if not source.has(item):
				for key in source:
					if sim.goods_name(key)==item:item=key;break
			lines.append(sim.transfer_chest(act=="chest_take",item,amount))
		"eat_meal":lines.append(sim.eat())
		"rest","foot_bath":lines.append(sim.rest())
		"tea_break":lines.append(sim.tea_break())
		"village_mill":lines.append(sim.mill_feed(_key_of(sim,arg)))
		"village_well":lines.append(sim.fill_can())
		"eat_harvest":
			var item=_key_of(sim,arg)
			if item not in ["honey","dried_fish"] and not sim.Garden.edible(item):return "请选择背包里的水果、熟食、蜂蜜或鱼干。"
			lines.append(sim.eat_harvest(item))
		"take_honey","dry_fish":
			var prefix="hive:" if act=="take_honey" else "rack:"
			var prop="beehive" if act=="take_honey" else "drying_rack"
			var selected=""
			for row in sim.data.get("layout",{}).get("props_ranch",[]):
				if row.size()>=4 and str(row[0])==prop and (arg=="" or arg in [str(row[3]),prefix+str(row[3])]):selected=prefix+str(row[3]);break
			if selected=="":
				var plans=sim.data.get("layout",{}).get("placement_by_map",{})
				for room in plans:
					var furniture=plans[room].get("furniture",{})
					for id in furniture:
						var key=prefix+str(room)+":"+str(id)
						if furniture[id][0]=="prop:"+prop and (arg==key or (arg=="" and str(room)==str(resident_rooms.inside.get(who,"ranch")))):
							selected=key;break
					if selected!="":break
			if selected=="":return "没有对应的蜂箱或晾晒架。"
			lines.append(sim.take_honey(selected) if act=="take_honey" else sim.dry_fish(selected))
		"build_pen":
			return _build_pen(sim,map,arg)
		"gate":
			return _wooden_gate(sim,map,arg)
		"pond","feed_fish","stock_fry","harvest_fish":
			var ponds:Dictionary=sim.pond_list()
			var id=arg if arg!="" else ponds.keys()[0]
			if not ponds.has(id):return "可选鱼塘："+ "、".join(ponds.keys())
			if act=="harvest_fish":lines.append(sim.harvest_pond(ponds[id]))
			elif act=="stock_fry":lines.append(sim.stock_fry(ponds[id]))
			else:lines.append(sim.tend_pond(ponds[id]))
		"cook_fish":
			lines.append(sim.cook_catch(_key_of(sim,arg) if arg!="" else ""))

		"cook":
			lines.append(sim.cook() if arg=="" or arg=="家常菜" else sim.Garden.cook(sim,sim.Garden.recipe_id(arg)))
		"store", "take":
			lines.append(sim.store_items(act == "take"))
		"mill":
			lines.append(sim.mill_feed(_key_of(sim, arg) if arg != "" else "pig_feed"))
	return "；".join(lines)

# ---- 开垦 / 挖渠 / 围栏 / 食槽 / 打水：都是她手里的工具 ----
func _till(sim, map: String, arg: String) -> String:
	var c := _arg_cell(arg)
	if c.x < 0: return "开垦哪一格？写格子编号，例如 14:11（c:r，看 out.farm.zone）"
	var region = _region()
	if region != null:
		return str(region.add_plot(Vector2(c) * float(FARM.cell_size())))
	var ctx := FARM.context(sim, map)
	var L:Dictionary = _layout(sim)
	if not L.has("plots"): L["plots"] = []
	for row in L.plots:
		if Vector2i(int(floor(float(row[0]) / FARM.cell_size())), int(floor(float(row[1]) / FARM.cell_size()))) == c:
			return "第 %d:%d 格已经是田了" % [c.x, c.y]
	var z: Rect2i = ctx.zone
	if not (c.x >= z.position.x and c.x < z.end.x and c.y >= z.position.y and c.y < z.end.y):
		return "第 %d:%d 格不在农场范围内（农场格子 %d..%d, %d..%d）" % [c.x, c.y, z.position.x, z.end.x - 1, z.position.y, z.end.y - 1]
	if ctx.water.has(c): return "第 %d:%d 格是水渠，不能开垦" % [c.x, c.y]
	L.plots.append([c.x * FARM.cell_size(), c.y * FARM.cell_size()])
	while sim.data.crops.size() < L.plots.size(): sim.data.crops.append({"planted": false, "progress": 0.0, "water": 0.0})
	return "开垦好了第 %d:%d 格 · 现在共 %d 块地" % [c.x, c.y, L.plots.size()]

func _dig(sim, map: String, arg: String) -> String:
	var c := _arg_cell(arg)
	if c.x < 0: return "挖哪一格？写格子编号，例如 14:12"
	if active and is_instance_valid(scene) and scene.get("sim")==sim and scene.get("ground_tiles") != null and scene.ground_tiles.has_method("edit"):
		var r := str(scene.ground_tiles.edit("channel", {c: true}, false))
		if r != "" and r != "ok": return r
		return "挖好了：第 %d:%d 格是水渠了" % [c.x, c.y]
	var ctx := FARM.context(sim, map)
	if map != "meadow": return "只有自家农场能挖水渠和鱼塘"
	if ctx.water.has(c): return "第 %d:%d 格已经是水了" % [c.x, c.y]
	var z: Rect2i = ctx.zone
	if not (c.x >= z.position.x and c.x < z.end.x and c.y >= z.position.y and c.y < z.end.y):
		return "第 %d:%d 格不在农场范围内" % [c.x, c.y]
	var L:Dictionary = _layout(sim)
	for row in L.get("plots", []):
		if Vector2i(int(floor(float(row[0]) / FARM.cell_size())), int(floor(float(row[1]) / FARM.cell_size()))) == c:
			return "第 %d:%d 格是田，不能挖成水渠" % [c.x, c.y]
	if not L.has("meadow_ground"): L["meadow_ground"] = {"cells": {}, "stocks": {}}
	L.meadow_ground.cells[FARM.cell_key(c)] = "channel"
	sim.recover_ponds()
	return "挖好了：第 %d:%d 格是水渠了" % [c.x, c.y]

## 拆自己围的围栏边（unfence）：扩圈时"先建新边、再拆旧边"的第二步。只拆边，不碰别人的东西。
func _unfence(sim, map: String, arg: String) -> String:
	var t := arg.strip_edges().replace(",", ":").replace("，", ":")
	var p := t.split(":", false)
	if p.size() < 4: return "拆围栏要写两块格子：左下角:右上角，例如 14:11:20:17"
	var c0 := Vector2i(mini(int(p[0]), int(p[2])), mini(int(p[1]), int(p[3])))
	var c1 := Vector2i(maxi(int(p[0]), int(p[2])), maxi(int(p[1]), int(p[3])))
	var store := _pens_store(sim, map)
	var removed := 0
	for x in range(c0.x, c1.x + 1):
		for key in ["h:%d:%d" % [x, c0.y], "h:%d:%d" % [x, c1.y + 1]]:
			if store.edges.has(key): store.edges.erase(key); removed += 1
	for y in range(c0.y, c1.y + 1):
		for key in ["v:%d:%d" % [c0.x, y], "v:%d:%d" % [c1.x + 1, y]]:
			if store.edges.has(key): store.edges.erase(key); removed += 1
	if removed == 0: return "这块范围边上本来就没有你围的围栏（没东西可拆）"
	return "拆掉了 %d 条围栏边（只拆了你自己围的那些）" % removed

func _fence(sim, map: String, arg: String) -> String:
	var t := arg.strip_edges().replace(",", ":").replace("，", ":")
	var p := t.split(":", false)
	if p.size() < 4: return "圈围栏要写两块格子：左下角:右上角，例如 14:11:20:17"
	var a := Vector2i(int(p[0]), int(p[1]))
	var b := Vector2i(int(p[2]), int(p[3]))
	var c0 := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var c1 := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	if p.size()!=4 or not Array(p).all(func(v):return str(v).is_valid_int()):return "围栏需要四个整数坐标"
	var ctx:=FARM.context(sim,map)
	var zone:Rect2i=ctx.zone
	if not zone.has_point(c0) or not zone.has_point(c1):return "围栏超出农场边界"
	if (c1.x-c0.x+1)*(c1.y-c0.y+1)<int(FARM.livestock_rules().get("min_pen_cells",4)):return "围栏太小"
	var edges := []
	for x in range(c0.x, c1.x + 1):
		edges.append("h:%d:%d" % [x, c0.y])
		edges.append("h:%d:%d" % [x, c1.y + 1])
	for y in range(c0.y, c1.y + 1):
		edges.append("v:%d:%d" % [c0.x, y])
		edges.append("v:%d:%d" % [c1.x + 1, y])
	if edges.size() > int(FARM.rules().get("fence", {}).get("max_edges", 96)):
		return "这块地太大了（%d 条边），一次最多 %d 条" % [edges.size(), int(FARM.rules().get("fence", {}).get("max_edges", 96))]
	var store := _pens_store(sim, map)
	var region = _region()
	if region!=null and region.id!="ranch":region=null
	var ok := 0
	for key in edges:
		if store.edges.has(key):continue
		if region!=null:
			var reason:String=region.edge_ok(key)
			if reason!="":return reason
		else:
			var seg=key.split(":")
			var mid=Vector2(int(seg[1]),int(seg[2]))*64+(Vector2(32,0) if seg[0]=="h" else Vector2(0,32))
			var barn:Dictionary=sim.data.get("layout",{}).get("meadow_barn",{})
			var box:Array=barn.get("rect",[])
			if box.size()==4 and Rect2(box[0],box[1],box[2],box[3]).grow(8).has_point(mid):return "围栏不能穿过牧场屋。"
	for key in edges:
		if not store.edges.has(key):
			store.edges[key]="fence";ok+=1
	if ok==0:return "这一圈本来就有围栏，不用再圈"
	if region!=null:region.refresh_ranch()
	return "圈好了：%d 条围栏，围出 %d 格" % [ok, (c1.x - c0.x + 1) * (c1.y - c0.y + 1)]

## A repeatable job. Every stage is derived from the persisted enclosure, including after shopping.
func _build_pen(sim,map:String,arg:String)->String:
	var parts:=arg.replace(",",":").replace("，",":").split(":",false)
	if parts.is_empty():return "指定种类与围栏范围，例如 牛:14:11:19:16。"
	var kind:=_arg_kind(parts[0])
	if kind=="":return "选择牛、羊、猪或鸡。"
	var ctx:=FARM.context(sim,map)
	var origin:=Vector2i(-1,-1)
	if parts.size()==5:
		var rect=":".join(parts.slice(1))
		var result:=_fence(sim,map,rect)
		origin=Vector2i(mini(int(parts[1]),int(parts[3])),mini(int(parts[2]),int(parts[4])))
		if not (result.begins_with("圈好了") or result.begins_with("这一圈本来")):return result
	elif parts.size()==1:
		var options:=FARM.enclosures(ctx)
		for pen in options:
			for f in ctx.feeders:
				var pos:=Vector2i(int(f[1]),int(f[2]))
				if pen.cells.has(pos):origin=pos;break
			if origin.x>=0:break
		if origin.x<0 and not options.is_empty():origin=options[0].cells.keys()[0]
		if origin.x<0:return "还没有闭合围栏。先 survey 选一块空地，然后 build_pen，item 写 %s:左:上:右:下。"%parts[0]
	else:return "格式：牛:14:11:19:16；已有围栏也可只写种类。"
	ctx=FARM.context(sim,map)
	for pen in FARM.enclosures(ctx):
		if not pen.cells.has(origin):continue
		var cells:Array=pen.cells.keys()
		if cells.size()<int(FARM.livestock_rules().get("min_pen_cells",4)):return "圈太小，请扩圈。"
		var used={}
		for f in ctx.feeders:used[Vector2i(int(f[1]),int(f[2]))]=str(f[0])
		if not pen.water:
			var water_ok=false
			for c in cells:
				if used.has(c):continue
				var dug:=_dig(sim,map,FARM.cell_key(c))
				if dug.begins_with("挖好了"):water_ok=true;break
			if not water_ok:return "围栏已闭合，但没有可用的圈内水源。请调整范围。"
		var gate:=_wooden_gate(sim,map,FARM.cell_key(origin))
		if not (gate.begins_with("木门已装好") or gate.begins_with("这圈已有通行木门")):return gate
		for c in cells:
			if used.has(c):return "围栏、水源、木门、%s都已齐全。"%FARM.feeder_cn(kind)
		var item:=FARM.feeder_cn(kind)
		if int(sim.data.bag.get("feeder_cow",0))<=0:
			return "围栏、水源和木门已就绪；还缺%s。去村中心牧铃畜牧铺 qx_livestock_counter，use=buy，item=%s。买好回农场，重复同一条 build_pen 即可。"%[item,item]
		var center:=Vector2.ZERO
		for c in cells:center+=Vector2(c)
		center/=cells.size()
		cells.sort_custom(func(a,b):return Vector2(a).distance_squared_to(center)<Vector2(b).distance_squared_to(center))
		for c in cells:
			if used.has(c):continue
			var placed:=_place_feeder(sim,map,"%s:%s"%[kind,FARM.cell_key(c)])
			if placed.begins_with("摆好了"):return "已建好可通行的围栏，有水源、木门和%s。"%item
		return "水和木门已就绪，但圈内没有能摆食槽的空地。"
	return "尚未形成闭合围栏，请 survey 查边界。"

func gate_approach_clear(ctx:Dictionary,inside:Vector2i,outside:Vector2i)->bool:
	if not ctx.zone.has_point(outside) or ctx.water.has(inside) or ctx.water.has(outside):return false
	var start:=Vector2(inside)*64+Vector2(32,32)
	var end:=Vector2(outside)*64+Vector2(32,32)
	var corridor:=Rect2(start,end-start).abs().grow(8)
	for f in ctx.feeders:
		if feeder_footprint(str(f[0]),Vector2i(int(f[1]),int(f[2]))).intersects(corridor):return false
	var r=_region()
	if r!=null and r.id=="ranch":
		if r.world.blocked(start) or r.world.blocked(end):return false
		if ctx.edges.get(FARM._edge_between(inside,outside),"")=="gate":
			return r.world.herd_ai.clear_walk(start,end)
	return true

func feeder_footprint(kind:String,c:Vector2i)->Rect2:
	var w:float=load("res://qingxi-live/village-center/region.gd").FEEDER_SIZE[kind]
	return Rect2(Vector2(c)*64+Vector2(32-w*.42,32),Vector2(w*.84,14))

func _wooden_gate(sim,map:String,arg:String)->String:
	var chosen=arg.get_slice("|",1) if "|" in arg else ""
	var c:=_arg_cell(arg.get_slice("|",0))
	var ctx:=FARM.context(sim,map)
	var region=_region()
	for pen in FARM.enclosures(ctx):
		if not pen.cells.has(c):continue
		if not pen.water:return "先在圈内确认水源；可用 qx_fields 的 dig 挖水渠。"
		for inside in pen.cells:
			for side in [Vector2i.DOWN,Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT]:
				var outside:Vector2i=inside+side
				var edge:=FARM._edge_between(inside,outside)
				if not pen.cells.has(outside) and ctx.edges.get(edge,"")=="gate" and gate_approach_clear(ctx,inside,outside):
					return "这圈已有通行木门 "+edge
		for cell in pen.cells:
			if ctx.water.has(cell):continue
			for d in [Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP]:
				var other:Vector2i=cell+d
				if pen.cells.has(other) or ctx.water.has(other) or not ctx.zone.has_point(other):continue
				var key:=FARM._edge_between(cell,other)
				if chosen!="" and key!=chosen:continue
				if ctx.edges.get(key,"")!="fence" or not gate_approach_clear(ctx,cell,other):continue
				if region!=null and region.id=="ranch" and region.has_method("set_edge"):
					if region.world.blocked(region.cell_rect(cell).get_center()) or region.world.blocked(region.cell_rect(other).get_center()):continue
					if region.set_edge(key,"gate")!="ok":continue
				else:_pens_store(sim,map).edges[key]="gate"
				return "木门已装好（%s）；进出走这扇门，下一步在圈内摆对应食槽。"%key
		return "围栏两侧没有可通行的干地，请调整圈边。"
	return "请指定闭合围栏里的一格，例如 17:14。"

func _place_feeder(sim, map: String, arg: String) -> String:
	var t := arg.strip_edges().replace("，", ":").replace(",", ":")
	var p := t.split(":", false)
	var kind := str(KINDS.get(str(KINDS.get(p[0] if p.size() > 0 else "", "")), ""))
	if p.size()==2:p.insert(0,"cow")
	if kind=="":kind="cow"
	if p.size() < 3: return "还要写格子：例如 %s:17:14" % kind
	var c := Vector2i(int(p[1]), int(p[2]))
	var bag: Dictionary = sim.data.get("bag", {})
	var ctx:=FARM.context(sim,map)
	for enclosure in FARM.enclosures(ctx):
		if not enclosure.cells.has(c):continue
		for cell in enclosure.cells:
			for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
				var adjacent:Vector2i=cell+direction
				if enclosure.cells.has(adjacent) or ctx.edges.get(FARM._edge_between(cell,adjacent),"")!="gate":continue
				var near:=Vector2(cell)*64+Vector2(32,32)
				var far:=Vector2(adjacent)*64+Vector2(32,32)
				var footprint:=feeder_footprint(kind,c).grow(8)
				if footprint.has_point(near) or footprint.has_point(far) or footprint.intersects(Rect2(near,far-near).abs().grow(1.0)):return "这里会挡住木门，请把食槽往圈内移一格。"
		break
	if not ctx.zone.has_point(c) or ctx.water.has(c):return "食槽需要一格牧场干地。"
	var key := "feeder_cow"
	if int(bag.get(key, 0)) <= 0: return "背包里没有%s：先去牧铃畜牧铺 buy %s" % [FARM.feeder_cn(kind), FARM.feeder_cn(kind)]
	var region = _region()
	if region != null and region.id=="ranch" and region.has_method("place_feeder"):
		var r := str(region.place_feeder(kind, c))
		if r != "ok": return r
		return "摆好了：%s在 %d:%d" % [FARM.feeder_cn(kind), c.x, c.y]
	var store := _pens_store(sim, map)
	for f in store.feeders:
		if Vector2i(int(f[1]), int(f[2])) == c: return "这一格已经有食槽了"
	store.feeders.append([kind, c.x, c.y])
	bag[key] = int(bag[key]) - 1
	return "摆好了：%s在 %d:%d" % [FARM.feeder_cn(kind), c.x, c.y]

func _fill_water(sim, map: String) -> String:
	var ctx := FARM.context(sim, map)
	if ctx.get("wells", []).is_empty():
		return "这块农场没有水井/手压水泵：先在自己的农场上摆一个（玩家 build 模式），或者用 dig 挖水渠"
	sim.data.bag["well_water"] = 3
	return "水壶打满了：3 份水"

## 参数里的种类："牛" / "cow" / "牛:3" / "3"（后者靠别的函数解析 id）都认。
func _young_stock(sim,act:String,arg:String)->String:
	var parts:=arg.strip_edges().replace("＊","×").replace("*","×").replace("x","×").replace("X","×").split("×")
	var spec:=parts[0].strip_edges().trim_prefix("young_").replace("：",":").split(":")
	var kind:=str(KINDS.get(spec[0],""))
	if kind=="":return "要操作哪种幼崽：牛、羊、猪、鸡；例如 鸡×2。"
	var qty:=1
	if parts.size()>1:
		if parts.size()!=2 or not parts[1].strip_edges().is_valid_int():return "只数要写正整数，例如 鸡×2。"
		qty=int(parts[1])
		if qty<1 or qty>20:return "一次可选 1 到 20 只。"
	if spec.size()>3 or (spec.size()>1 and not spec[1].is_valid_int()):return "幼崽品种编号无效。"
	var coat:=int(spec[1]) if spec.size()>1 else 0
	var sex:=str(spec[2]) if spec.size()>2 else "f"
	if coat<0 or coat>=sim.Book.BREEDS[kind].size() or sex not in ["f","m"]:return "没有这个幼崽品种或性别。"
	var label:=str(sim.Book.KIND[kind])
	if act=="buy_young":
		var cost:int=sim.Book.stock_cost(kind,coat)*qty
		if sim.data.coins<cost:return "买 %d 只需要 %d 零钱，余额不足。"%[qty,cost]
		for i in qty:sim.buy_stock(kind,coat,sex)
		return "买入%s %d 只，共 %d 零钱，幼崽在农场背包，回牧场放养后才进场。"%[label,qty,cost]
	var available:=0
	var keys=[]
	for k in sim.data.bag:
		if k!="young_"+kind and not str(k).begins_with("young_"+kind+":"):continue
		var bits:=str(k).split(":")
		if (spec.size()>1 and (bits.size()<2 or int(bits[1])!=coat)) or (spec.size()>2 and (bits.size()<3 or bits[2]!=sex)):continue
		keys.append(k);available+=int(sim.data.bag[k])
	if available==0:return "背包里没有待放养的"+label+"。"
	if parts.size()==1:qty=available
	if qty>available:return "背包里只有 %d 只，无法放养 %d 只。"%[available,qty]
	var released:=0
	for k in keys:
		for i in mini(qty-released,int(sim.data.bag[k])):
			var before:int=sim.data.bag[k]
			var message:String=sim.release_young(str(k).trim_prefix("young_"))
			if before==sim.data.bag[k]:
				if released==0:return message
				return "实际放养%s %d 只，其余仍在背包：%s"%[label,released,message]
			released+=1
	return "已放养%s %d 只；牧场现在共有这种动物 %d 只。"%[label,released,sim.livestock.members(kind).size()]

func _arg_kind(arg: String) -> String:
	var head := arg.strip_edges().replace("，", ":").replace(",", ":").split(":", false)
	var first := str(head[0]).strip_edges() if head.size() > 0 else ""
	if first.is_valid_int(): return ""
	return str(KINDS.get(str(KINDS.get(first, first)), ""))

## 她点名的那一只（"牛:3" 或 "3"），没点名就返回空字典（操作整类）。
func _animal_of(sim, kind: String, arg: String) -> Dictionary:
	var t := arg.strip_edges().replace("，", ":").replace(",", ":")
	var parts := t.split(":", false)
	var id := ""
	if parts.size() >= 2: id = str(parts[1]).strip_edges()
	elif parts.size() == 1 and str(parts[0]).strip_edges().is_valid_int(): id = str(parts[0]).strip_edges()
	if id == "": return {}
	for a in sim.livestock.data.get("herd", []):
		if str(a.get("kind", "")) == kind and str(a.get("id", "")) == id: return a
	return {}

## 添料/加水之后，让饿着/渴着的动物**当场**吃/喝，并如实报出每只从多少到多少。
## 判据跟牧场自己的进食逻辑一致：只有 need <= hungry_below 的动物才会吃（pasture_herd.advance_step）。
func _feed_animals_now(sim, kind: String, need: String, arg: String = "") -> String:
	var nr := FARM.needs_rules()
	var seek := float(nr.get("hungry_below", 48.0))
	var raise_to := float(nr.get("feed_raise_to", 90.0))
	var only := _animal_of(sim, kind, arg)
	var raised := []
	var already := 0
	var no_supply := 0
	for a in sim.livestock.data.get("herd", []):
		if str(a.get("kind", "")) != kind: continue
		if not only.is_empty() and str(a.get("id", "")) != str(only.get("id", "")): continue
		var before := float(a.get(need, 100.0))
		if before > seek:
			already += 1
			continue
		if need=="drink" and sim.livestock.available(a,need)<=0 and sim.livestock.river_only(a):
			# Hand-water loose animals from the water just carried to their pen.
			var reservoir:Dictionary=sim.livestock.pool(a,need)
			var cost:float=sim.livestock.COST[need]
			var given=minf(raise_to-before,float(reservoir.get("water",0))/cost)
			if given>0:
				reservoir.water-=given*cost;a.drink=before+given
				raised.append("%s#%s %.0f→%.0f"%[FARM.kind_cn(kind),str(a.id),before,a.drink])
				continue
		if sim.livestock.available(a, need) <= 0.0:
			no_supply += 1
			continue
		sim.livestock.consume_at_trough(a, need, raise_to - before)
		var after := float(a.get(need, 0.0))
		if after > before + 0.5:
			raised.append("#%s %.0f→%.0f" % [str(a.get("id", "")), before, after])
	if raised.is_empty():
		if no_supply > 0 and already == 0: return "槽里没有可以吃的东西，谁都没吃上"
		return "动物现在不饿/不渴（%s都高于 %.0f），谁都没吃" % [FARM.needs_name("satiety") if need == "food" else FARM.needs_name("thirst"), seek]
	var text := ("吃了：" if need == "food" else "喝了：") + "、".join(raised)
	if already > 0: text += "（另有 %d 只不饿，没吃）" % already
	if no_supply > 0: text += "（%d 只吃不到：槽里/渠里没有料或水）" % no_supply
	return text

func Book_name(kind: String) -> String:
	return {"cow":"牛", "sheep":"羊", "pig":"猪", "chicken":"鸡"}.get(kind, kind)

## What she perceives of the shared farm: plots she can actually see (tilled ones only), the farm bag, the
## cottage store, every animal with its id (treat / pair / sell_animal), pens with what is missing, the pond,
## the rules/thresholds and human-word actions — so "can I plant / what is missing / what next" is answerable.
## 2026-11-21 pets: arg 是宠物编号/名字时，额外给单只详情（look 7 / look 咪咪）。
func farm_sight(who:String,sim,reading:Dictionary)->Dictionary:
	var result={"nearbyKnown":false,"animals":[],"plots":[],"herd":{},"inside":0,"outside":0,"fields":reading.get("plots",{})}
	var person=_resident(who)
	var room=str(resident_rooms.inside.get(who,""))
	if room=="":room="ranch"
	var at=Vector2.INF
	var visible_herd=null
	if person!=null and person.placed and person.scene_id==PLACE and person.want_zone=="qx_farm" and not person.is_walking():
		var visitor=visitors.get(who,{}).get("node")
		if active and is_instance_valid(scene) and str(scene.get("map_id"))==room and is_instance_valid(visitor) and scene.is_ancestor_of(visitor) and visitor.is_visible_in_tree():
			at=visitor.position;visible_herd=scene.get("herd_ai")
		else:
			var job=visitor_jobs.get(who,{})
			if job.get("room","")==room:at=job.get("pos",Vector2.INF)
	result.nearbyKnown=at!=Vector2.INF
	for a in sim.livestock.data.herd:
		var kind=str(a.kind)
		result.herd[kind]=int(result.herd.get(kind,0))+1
		var inside=bool(a.get("inside_barn",false))
		result["inside" if inside else "outside"]+=1
		if at==Vector2.INF:continue
		var pos=Vector2.INF
		var mode=""
		if visible_herd!=null:
			var live=visible_herd.actors.get(a.id,{})
			if is_instance_valid(live.get("node")) and live.node.is_visible_in_tree():pos=live.node.position;mode=live.get("mode","")
		elif room=="ranch" and not inside:pos=Vector2(a.pos[0],a.pos[1])
		var dist=at.distance_to(pos)
		if dist<=310:result.animals.append({"kind":kind,"id":a.id,"name":a.get("name",""),"metersPx":roundi(dist),"mode":mode})
	var plots=sim.data.layout.get("plots",[])
	if room=="ranch" and at!=Vector2.INF:
		for row in reading.get("plotList",[]):
			var i=int(row.index)
			if i<0 or i>=plots.size():continue
			var xy=plots[i]
			if not xy is Array or xy.size()<2:continue
			var dist=at.distance_to(Vector2(xy[0]+32,xy[1]+32))
			if dist<=310:result.plots.append({"number":i+1,"state":row.get("stateText",row.state),"metersPx":roundi(dist),"planted":row.planted})
	for group in [result.animals,result.plots]:group.sort_custom(func(a,b):return a.metersPx<b.metersPx)
	return result

func _farm_reading(sim, map: String, arg: String = "") -> Dictionary:
	var reading := FARM.reading(sim, map)
	## 2026-11-21（业主 ④⑤）：每个圈算不算数、漏在哪，逐类算出来；顺带判断"是不是第一次来"。
	var first_time: bool = int(reading.plots.total) == 0
	for kind in FARM.livestock_rules().get("kinds", {}):
		var diag := FARM.pen_diagnosis(sim, str(kind), FARM.context(sim, map))
		if reading.pens.has(kind): reading.pens[kind]["diagnosis"] = diag
		if bool(diag.get("ok", false)): first_time = false
	var book=preload("res://qingxi-live/village-center/breed_catalog.gd")
	var by_id={}
	for animal in sim.livestock.data.herd:by_id[str(animal.id)]=animal
	for row in reading.animalsDetailed:
		var a=by_id[str(row.id)]
		row.sex="母" if a.sex=="f" else "公"
		row.parents=a.parents.duplicate()
		row.lineage=[book.BREEDS[a.kind][a.genes[0]],book.BREEDS[a.kind][a.genes[1]]]
		row.grade=book.GRADE[int(a.quality)-1]
		row.trait=book.TRAIT_NAMES[book.breed_trait(a)]
		row.pregnancyMinutes=ceili(float(a.pregnancy.get("left",0))/sim.livestock.RATE/60)
		row.cooldownMinutes=ceili(float(a.cooldown)/sim.livestock.RATE/60)
	var plots := []
	for row in reading.plots.rows:
		var index=int(row.index)
		row.plotId=index+1
		if index>=0 and index<sim.data.crops.size():
			var crop=sim.data.crops[index]
			row.growthSeconds=float(crop.get("progress",0))
			row.waterSeconds=float(crop.get("water",0))
			row.remainingGrowthSeconds=maxf(0.0,sim.CROP_SECONDS-row.growthSeconds) if crop.planted else 0.0
		## 2026-11-21（业主："不种田菜就会枯萎"）：用 farm_rules 按真实 ripe_seconds 算出的档位文字
		## （熟了/快枯了/在枯萎/枯了），并且把"快枯了先收"和"枯了铲掉重种"直接写在她看得见的那一行里。
		var line := "%d:%s" % [int(row.index) + 1, str(row.get("stateText", row.state))]
		var wither: Dictionary = row.get("wither", {})
		if bool(row.can_clear):
			line += "(已枯：harvest 铲掉重种)"
		elif bool(wither.get("urgent", false)):
			line += "(成熟后已 %.0f 小时，先收)" % float(wither.get("hours", 0.0))
		elif bool(row.can_plant): line += "(能种)"
		elif not row.missing.is_empty(): line += "(缺%s)" % str(row.missing[0].text).get_slice("（", 0)
		plots.append(line)
	var bag := {}
	for k in sim.data.bag:
		if int(sim.data.bag[k]) > 0: bag[sim.goods_name(k)] = int(sim.data.bag[k])
	var store := {}
	for k in sim.data.storage:
		if int(sim.data.storage[k]) > 0: store[sim.goods_name(k)] = int(sim.data.storage[k])
	var animals := []
	var Book = load("res://qingxi-live/village-center/breed_catalog.gd")
	for a in sim.livestock.data.herd:
		var line := "%s%s" % [_animal_display(a), "（成年）" if sim.livestock.adult(a) else "（幼崽）"]
		## 2026-11-20 round 2（业主）：每只动物自己的饱食度 / 饥渴度，直接读 a.food / a.drink。
		var nd := FARM.animal_needs(a)
		line += " %s %.0f / %s %.0f" % [FARM.needs_name("satiety"), float(nd.satiety), "水分", float(nd.thirst)]
		var care: String = FARM.animal_status(a)
		if care != "": line += " " + care
		if sim.livestock.adult(a) and int(a.get("ready", 0)) > 0: line += " 有产物可收"
		animals.append(line)
	var ctx := FARM.context(sim, map)
	var z: Rect2i = ctx.zone
	## 2026-11-21 pets：宠物读数（全量在 petsDetailed；文本只列前 max_pets 行，其余给计数）。
	var now := Time.get_unix_time_from_system()
	var hour := local_hour()   ## 小屋世界的时钟（白天打盹 / 夜里活跃 / 狗看家都按它）
	var pet_reading := PET_RULES.reading(sim.data, now, hour)
	var pet_one := {}
	if arg != "":
		var found := PET_RULES.find_pet(sim.data, arg)
		if not found.is_empty():
			pet_one = PET_RULES.pet_view(found, now, hour)
			pet_reading["pet"] = pet_one
			pet_reading["pets"] = [PET_RULES.pet_line(found, now, hour)]
	## 2026-11-21 v2（业主："喂猫狗是手动还是自动" -> 手动，但要让她知道）：
	## 把"谁饿了"并进 next[]/urgent[]/todo，和「牛饿了」同级；数字与文案全部来自 pets_rules.json。
	## 这里只产生文字，绝不自动喂：feed_pet 永远是别人手动调用的。
	var merged := PET_RULES.merge_farm_todo(reading.get("next", []), reading.get("urgent", []), str(reading.get("todo", "")), sim.data, sim.data.get("bag", {}), now)
	## 宠物角的价目也从数据文件读（品种差价改 json 就行，不用改代码）。
	var pet_prices := []
	for k in PET_RULES.kinds():
		for row in PET_RULES.breed_menu(str(k)):
			pet_prices.append("%s %d" % [str(row.get("name", "")), int(row.get("price", 0))])
	var ponds:Dictionary=sim.pond_list()
	var pond_tasks=[]
	var pond_ids=Pond.saved_keys(sim,map)
	for pond_id in pond_ids:
		if not ponds.has(pond_id):continue
		var stock:Dictionary=ponds[pond_id]
		if int(stock.count)>0 and float(stock.feed)<14400:
			pond_tasks.append("%s 有 %d 条鱼，鱼食将尽。%s"%[pond_id,stock.count,"走到塘边选投喂鱼饲料（feed_fish），塘名可留空。" if int(sim.data.bag.get("fish_feed",0))>0 else "去牧铃畜牧铺买鱼饲料，再到塘边投喂。"])
		elif int(stock.count)==0 and int(sim.data.bag.get("fry",0))>0:
			pond_tasks.append("%s 有空位，背包有鱼苗，可到牧场 stock_fry 放苗。"%pond_id)
	var price_line := "；宠物角：" + "、".join(pet_prices) if not pet_prices.is_empty() else ""
	return {
		"map": map, "mapTitle": str(reading.mapTitle),"beds":Stay.beds(Stay.data(profile_path_cached())),"occupiedBeds":Stay.data(profile_path_cached()).get("guests",{}).values(),
		"zone": "%d:%d..%d:%d（格子）" % [z.position.x, z.position.y, z.end.x - 1, z.end.y - 1],
		"plots": " ".join(plots) if not plots.is_empty() else "一块地都还没开垦",
		"plotList": reading.plots.rows,
		"plotTotal": int(reading.plots.total),
		"farmBag": bag, "cottageStore": store,"sharedChestRooms":sim.shared_chest_rooms(),"sharedChest":sim.data.get("shared_chest",{}).duplicate(),
		"animals": animals,
		"animalsDetailed": reading.animalsDetailed,
		"pens": reading.pens, "pondTasks": pond_tasks,
		"pond": "、".join(pond_ids.filter(func(id):return ponds.has(id)).map(func(id):return "%s（%d条）"%[id,ponds[id].count]))+"。走到塘边 watch_pond 查看 E 菜单，放苗、投喂、抛竿和收获都可留空塘名。鱼苗和鱼饲料可在牧铃畜牧铺购买。",
		"prices": "种子店：" + "、".join(sim.PRICES.keys().map(func(k): return "%s %d" % [sim.ITEM_NAMES[k], sim.PRICES[k]])) + "；牧铃畜牧铺也卖猫粮、狗粮（各 3 币）、鱼苗 %d、鱼饲料 %d；幼崽："%[sim.PRICES.fry,sim.PRICES.fish_feed]+"牛 60、羊 50、猪 40、鸡 18 起；牧场食槽 20（四种牲畜共用）" + price_line,
		"rules": reading.rules, "actions": reading.actions,
		"next": unique_steps(merged.get("next", reading.get("next", []))),
		## 2026-11-21（业主：她看到缺口却推给"明儿"）：一句人话待办 + 会造损失的条目，排在最前面。
		## 宠物饿了的条目和牲畜同级（插在牲畜那几条后面、田前面），见 pets_rules.merge_farm_todo。
		"urgent": merged.get("urgent", reading.get("urgent", [])), "todo": str(merged.get("todo", reading.get("todo", ""))),
		"petTodo": merged.get("petRows", []),
		"firstTime": first_time, "tutorialHint": (FARM.rules().get("tutorial", {}).get("first_time", "") if first_time else ""),
		"pets": pet_reading.get("pets", []),
		"petsDetailed": pet_reading.get("petsDetailed", []),
		"cookbook": sim.Garden.recipe_list(), "sowing":"空田可播种七种作物。plant 地号默认轮种背包里有的品种，也可填写 地号|作物名。", "petsTotal": int(pet_reading.get("petsTotal", 0)),
		"petsHidden": int(pet_reading.get("petsHidden", 0)),
		"petRules": pet_reading.get("petRules", {}),
		"petActions": pet_reading.get("petActions", []),
		"pet": pet_one,
		"petsNow": now,
		"hour": snappedf(hour, 0.01)
	}

func observer_bus_from_park() -> void:
	if busy(): return
	transit = true
	while bus_busy: await get_tree().process_frame
	bus_busy = true
	await _drive(-260.0, CURB.x, 1.25, true)
	_place_bus(CURB.x, true)
	await _wait(.5)
	await _drive(CURB.x, -260.0, 1.0, false)
	bus.visible = false
	bus_busy = false
	transit = false
	if game.observing and game.view_scene=="qianxia-park":
		game._show_room(PLACE)

func unique_steps(rows:Array)->Array:
	var result=[]
	for row in rows:
		if not result.has(row):result.append(row)
	return result
