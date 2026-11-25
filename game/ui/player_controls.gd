extends CanvasLayer

const Player = preload("res://entities/player_character.gd")
const Personal = preload("res://core/resident_personal.gd")
const Play = {
	"bench":["bench","坐在长椅上"], "long_bench":["bench","坐在长椅上"],
	"swing":["swing","荡秋千"], "slide":["slide","滑滑梯"], "carousel":["carousel","坐转马"],
	"seesaw":["seesaw","玩跷跷板"], "rider":["rider","骑鲸鱼摇摇乐"], "pier":["fish","钓鱼"],
	"onsen_pool":["swim","游泳"], "onsen_soak":["soak","泡汤"], "onsen_shower":["shower","冲澡"],
	"onsen_bench":["sit","坐下休息"], "onsen_locker":["yukata","换回衣服／穿浴衣"],
	"beanbag":["sit","坐懒人沙发"], "whale_bed":["rest","休息"], "xj_beach":["watch_sea","看海"],
	"xj_phone":["phone","看手机"], "xj_computer":["computer","坐在电脑前"],
	"xj_bookshelf":["read","看书"], "round_window":["watch","看窗外"], "river":["watch","看小河"],
	"big_tree":["rest","在树下歇一会"], "meadow":["rest","在草坪歇一会"],
	"xj_plant":["water_plant","浇花"], "fish_tank":["feed_fish","喂鱼"],
}
const SHOPS := ["counter","snack_shelf","drink_fridge","freezer","daily_shelf","food_shelf","bread_shelf","produce_shelf","hot_cabinet","magazine_shelf"]
const SIDES := {"left":"seesaw_left","right":"seesaw_right"}
const RANGE := 46.0
const OVERLAP := 8.0

var _targets_in := 0.0

var game
var player: Player
var panel: PopupPanel
var title: Label
var rows: VBoxContainer
var note: Label
var prompt: Label
var action_button: Button
var bag_button: Button
var activity: Dictionary = {}
var arcade
var _last_prompt := ""
var _input_was_moving := false
var visit_request := ""
var visit_scene := ""

func setup(host, body: Player) -> void:
	game = host
	player = body
	layer = 10
	panel = PopupPanel.new()
	panel.size = Vector2i(520, 370)
	var theme_ := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
	theme_.default_font = font
	theme_.default_font_size = 17
	panel.theme = theme_
	var surface := PanelContainer.new()
	surface.add_theme_stylebox_override("panel", ArcadePanel._face(Hud.PAPER))
	panel.add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	surface.add_child(column)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Hud.INK)
	column.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	note = Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Hud.INK)
	column.add_child(note)
	var close := make_button("关闭", panel.hide)
	column.add_child(close)
	add_child(panel)
	action_button = hud_button("互动  E", open_nearby)
	bag_button = hud_button("背包  B", open_bag)
	add_child(action_button)
	add_child(bag_button)
	prompt = Label.new()
	prompt.theme = theme_
	prompt.add_theme_color_override("font_color", Hud.CREAM)
	prompt.add_theme_color_override("font_outline_color", Hud.WOOD_D)
	prompt.add_theme_constant_override("outline_size", 4)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt)
	arcade = load("res://ui/player_arcade.gd").new()
	add_child(arcade)
	arcade.setup(self)
	Economy.gift_changed.connect(_gift_changed)
	VadsLink.foreground_reply.connect(_visit_reply)

func hud_button(caption: String, used: Callable) -> Button:
	var button := make_button(caption, used)
	button.theme = panel.theme
	for status in ["normal","hover","pressed"]:
		var face := ArcadePanel._face(Hud.WOOD if status=="normal" else Hud.WOOD_L)
		face.border_color = Hud.WOOD_D
		face.content_margin_left = 10
		face.content_margin_right = 10
		button.add_theme_stylebox_override(status, face)
		button.add_theme_color_override("font_color" if status=="normal" else "font_%s_color"%status, Hud.CREAM)
	return button

func make_button(label: String, used: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	for status in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(status, ArcadePanel._face(Hud.PAPER_H if status == "normal" else Hud.PAPER_D))
		button.add_theme_color_override("font_color" if status == "normal" else "font_%s_color" % status, Hud.INK)
	button.pressed.connect(used)
	return button

func viewing_player() -> bool:
	if game.qingxi_host != null and game.qingxi_host.busy(): return false ## 2026-11-19 Claude: in 清溪村 or on the bus
	return player.player_enabled and player.placed and game.view_scene == player.scene_id and game.follow < 0

func allows_input() -> bool:
	return viewing_player() and not panel.visible and not arcade.visible and not game._settings.visible and not is_instance_valid(game._home_editor) and not is_instance_valid(game._map_editor)

func tell(text: String) -> void:
	_last_prompt = text
	var old := text
	get_tree().create_timer(4.0).timeout.connect(func():if _last_prompt == old: _last_prompt = "")

func _process(dt: float) -> void:
	var usable := viewing_player()
	if not usable:
		action_button.hide()
		_targets_in = 0
	bag_button.visible = usable
	prompt.visible = usable
	if not usable:
		player.direction_input = Vector2.ZERO
		player.sprint_pressed = false
	else:
		var bounds: Rect2 = game._hud.frame_rect
		_targets_in -= dt
		if _targets_in <= 0:
			_targets_in = 0.1
			var nearby := nearby_choices()
			action_button.visible = not activity.is_empty() or not nearby.is_empty()
			action_button.text = ("结束" if not activity.is_empty() else str(nearby[0].label) if nearby.size()==1 else "选择互动") + "  E"
			action_button.reset_size()
		bag_button.position = bounds.end - bag_button.size - Vector2(10, 9)
		action_button.position = Vector2(bag_button.position.x-action_button.size.x-6,bag_button.position.y)
		prompt.position = bounds.position + Vector2(12, bounds.size.y - 39)
		prompt.text = _last_prompt
		var input := Vector2.ZERO
		if allows_input():
			input.x = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
			input.y = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
		if input != Vector2.ZERO and not _input_was_moving:
			stop_activity()
			if is_instance_valid(game._restaurant):
				game._restaurant.cancel(player.key)
		player.direction_input = input
		player.sprint_pressed = input != Vector2.ZERO and Input.is_physical_key_pressed(KEY_SHIFT)
		_input_was_moving = input != Vector2.ZERO
	if not activity.is_empty() and not player.is_walking():
		if player.effect.is_empty():
			if not WorldData.scenes[player.scene_id].zones.has(player.want_zone):
				stop_activity()
				return
			var zone_at := WorldData.point(WorldData.scenes[player.scene_id].zones[player.want_zone])
			if player.feet.distance_to(zone_at)>RANGE:
				return
			begin_effect()
		activity.left -= dt
		if activity.left <= 0.0:
			var completed := activity.duplicate()
			stop_activity()
			var uses := transact("use_record", {"objectId":completed.id, "use":completed.use, "label":completed.label})
			if uses.ok and completed.use == "fish":
				var caught := transact("play", {"use":"fish"})
				tell("　".join(PackedStringArray(caught.get("lines", []))) if caught.ok else str(caught.get("error", "这次没有钓到鱼")))
			elif uses.ok:
				transact("experience", {"args":{"objectId":completed.id, "use":completed.use, "label":completed.label}})
				tell(completed.label)
			else:
				tell(uses.get("error", "活动未保存"))

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or not allows_input():
		return
	match event.physical_keycode:
		KEY_E: open_nearby()
		KEY_B: open_bag()
		KEY_ESCAPE:
			stop_activity()
			player.stop_navigation()
		_: return
	get_viewport().set_input_as_handled()

func transact(op: String, args := {}) -> Dictionary:
	var weather: Dictionary = SharedFeed.weather if SharedFeed.weather is Dictionary else {}
	var frame := {"actor":player.key, "op":op, "id":"player-" + str(Time.get_ticks_usec()), "at":SharedFeed.now_ms(), "now":SharedFeed.now_ms(), "who":"owner", "space":str(WorldData.SPACE_SCENE.find_key(player.scene_id)), "weather":weather}
	frame.merge(args, true)
	return Economy._answer(frame)

func show_panel(caption: String, dimensions := Vector2i(520, 370)) -> void:
	title.text = caption
	note.text = ""
	for previous in rows.get_children():
		rows.remove_child(previous)
		previous.queue_free()
	panel.popup_centered(dimensions)

func option(label: String, fun: Callable) -> void:
	rows.add_child(make_button(label, fun))

func nearby_choices() -> Array:
	var scene: Dictionary = WorldData.scenes[player.scene_id]
	var space: String = str(WorldData.SPACE_SCENE.find_key(player.scene_id))
	var options := []
	for obj in WorldData.objects:
		if obj.space != space or not scene.zones.has(obj.zone):
			continue
		if not (Play.has(obj.id) or obj.id in SHOPS or obj.id=="xj_notes" or str(obj.id).begins_with("arcade_") or str(obj.id).begins_with("home_chess_")):
			continue
		var target: Dictionary = obj
		if obj.id in ["onsen_soak","onsen_shower","onsen_bench"]:
			target = obj.duplicate()
			for slot in Seats.SLOTS[obj.id]:
				var alt := str(obj.zone).left(-1)+str(slot)
				if scene.zones.has(alt) and player.feet.distance_squared_to(WorldData.point(scene.zones[alt]))<player.feet.distance_squared_to(WorldData.point(scene.zones[target.zone])):
					target.zone = alt
		add_choice(options, object_interaction_point(target), str(Play[obj.id][1]) if Play.has(obj.id) else str(obj.name), use_object.bind(target))
	for peer in game.characters:
		if peer!=player and peer.placed and peer.scene_id==player.scene_id:
			add_choice(options,peer.feet,"与%s互动"%peer.display_name,open_peer.bind(peer.key))
	for door in scene.exits:
		if WorldData.scenes.has(door.to):
			add_choice(options,WorldData.point(door),"前往"+str(WorldData.scenes[door.to].name),travel.bind(str(door.to)))
	if game.qingxi_host != null: game.qingxi_host.add_choices(self, options) ## 2026-11-19 Claude: the 清溪村 bus stop in the park
	if space == "restaurant" and is_instance_valid(game._restaurant):
		for zone in ["order_a","order_b","cook_a","cook_b","hall"]:
			if scene.zones.has(zone):
				add_choice(options,WorldData.point(scene.zones[zone]),"餐厅菜单",open_restaurant)
	options.sort_custom(func(a,b):return a.distance < b.distance)
	var choices := []
	for candidate in options:
		if not choices.is_empty() and candidate.point.distance_to(choices[0].point)>OVERLAP:
			continue
		if choices.all(func(other):return other.label != candidate.label):
			choices.append(candidate)
	return choices

func add_choice(options: Array, point: Vector2, label: String, callback: Callable) -> void:
	var distance := player.feet.distance_to(point)
	if distance <= RANGE:
		options.append({"point":point,"distance":distance,"label":label,"callback":callback})

func open_nearby() -> void:
	if not viewing_player():
		return
	if not activity.is_empty():
		stop_activity()
		return
	var choices := nearby_choices()
	if choices.size()==1:
		choices[0].callback.call()
	elif choices.size()>1:
		show_panel("选择互动",Vector2i(300,100+choices.size()*40))
		for choice in choices:
			option(choice.label,choice.callback)

func travel(destination: String) -> void:
	panel.hide()
	stop_activity()
	visit_request = ""
	if player.go_local(destination):
		return
	var space := str(WorldData.SPACE_SCENE.find_key(destination))
	if space in ["home", "xjhome"] and VadsLink.owns_bodies:
		show_panel("拜访" + str(WorldData.scenes[destination].name))
		option("请住户开门", _ask_visit.bind(destination, space))
	else:
		tell("这扇门现在不能通行。")

func _ask_visit(destination: String, space: String) -> void:
	visit_request = "visit-" + str(Time.get_ticks_usec())
	visit_scene = destination
	note.text = "等住户回应"
	VadsLink.send({"type":"entry.playerVisit","id":visit_request,"space":space})

func _visit_reply(frame: Dictionary) -> void:
	if frame.get("type") != "entry.playerVisitResult" or visit_request.is_empty() or frame.get("id") != visit_request:
		return
	visit_request = ""
	if viewing_player() and frame.get("ok", false) and player.go_local(visit_scene):
		panel.hide()
		tell("住户同意了，正前往拜访。")
	else:
		note.text = str(frame.get("error", "暂时无法前往"))

func open_bag() -> void:
	if not viewing_player():
		return
	var bag := Economy.inventory(player.key)
	var height := clampi(130+ceili(bag.items.size()/3.0)*68,230,520)
	show_panel("背包    %d 币" % bag.coins,Vector2i(540,height))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",6)
	grid.add_theme_constant_override("v_separation",6)
	rows.add_child(grid)
	for item in bag.items:
		var item_name := str(ItemIcons.FARM_NAMES.get(item.id,item.get("name",item.id)))
		var card := make_button("%s\n× %d" % [item_name,item.count], use_item.bind(str(item.id)))
		card.custom_minimum_size = Vector2(152,62)
		card.icon = ItemIcons.texture(item.id,item_name)
		card.add_theme_constant_override("icon_max_width",40)
		card.disabled = not Economy.catalog.has(item.id)
		card.add_theme_stylebox_override("disabled",ArcadePanel._face(Hud.PAPER))
		card.add_theme_color_override("font_disabled_color",Hud.INK)
		card.add_theme_color_override("icon_disabled_color",Color.WHITE)
		card.tooltip_text = item_name if card.disabled else "使用"+item_name
		grid.add_child(card)
	var total := 0
	for item in bag.items:
		total += int(item.count)
	note.text = "%d 种物品，共 %d 件" % [bag.items.size(),total]
	if bag.used>0:
		note.text += "    小屋用品 %d／%d 件" % [bag.used,bag.capacity]
	if bag.items.is_empty():
		note.text = "背包是空的"

func use_item(id: String) -> void:
	var item: Dictionary = Economy.catalog.get(id, {})
	var result := transact("consume", {"product":id, "kind":"used" if item.get("kind","") == "use" else "eaten"})
	open_bag()
	note.text = "已使用 " + str(item.get("name", id)) if result.ok else str(result.error)

func open_shop(object: Dictionary) -> void:
	var day := Economy.today()
	show_panel("%s  ·  %d 币" % [object.name, Economy.inventory(player.key).coins])
	for item in Economy.catalog.values():
		if item.get("shelf","")=="restaurant" or str(item.id).begins_with("restaurant-") or not Economy.available_today(item, day):
			continue
		option("%s  ·  %d 币" % [item.name, Economy.price_today(item, day)], buy.bind(object, str(item.id)))

func buy(shop: Dictionary, id: String) -> void:
	if not near_object(shop):
		note.text = "请走回货架旁"
		return
	var result := transact("buy", {"product":id})
	title.text = "%s  ·  %d 币" % [shop.name, Economy.inventory(player.key).coins]
	note.text = "已放入背包" if result.ok else str(result.error)

func object_interaction_point(object: Dictionary) -> Vector2:
	var zones: Dictionary = WorldData.scenes[player.scene_id].zones
	var point := WorldData.point(zones[object.zone])
	var seat_zones: Array = []
	match str(object.id):
		"arcade_xiangqi": seat_zones = ["arcade_xiangqi_far", "arcade_xiangqi_near"]
		"arcade_snake": seat_zones = ["arcade_snake_left", "arcade_snake_right"]
		"home_chess_home": seat_zones = ["chess_home_a", "chess_home_b"]
		"home_chess_xjhome": seat_zones = ["chess_xj_a", "chess_xj_b"]
	if seat_zones.size() == 2 and zones.has(seat_zones[0]) and zones.has(seat_zones[1]):
		var across := Geometry2D.get_closest_point_to_segment(player.feet, WorldData.point(zones[seat_zones[0]]), WorldData.point(zones[seat_zones[1]]))
		if player.feet.distance_squared_to(across) < player.feet.distance_squared_to(point):
			return across
	return point

func near_object(object: Dictionary) -> bool:
	if not viewing_player() or WorldData.scene_of_space(object.space) != player.scene_id:
		return false
	var zones: Dictionary = WorldData.scenes[player.scene_id].zones
	return zones.has(object.zone) and player.feet.distance_to(object_interaction_point(object)) <= RANGE

func use_object(object: Dictionary) -> void:
	if not near_object(object):
		return
	if object.id in SHOPS:
		open_shop(object)
	elif str(object.id).begins_with("arcade_") or str(object.id).begins_with("home_chess_"):
		open_arcade(object)
	elif object.id == "xj_notes":
		open_journal()
	elif Play.has(object.id):
		start_activity(object)

func start_activity(object: Dictionary) -> void:
	var use: Array = Play[object.id]
	var preferred := str(object.zone).right(1) if object.id in ["onsen_soak","onsen_shower","onsen_bench"] else ""
	var claim := Seats.claim(player.key, object.id, 15.0, preferred)
	if claim.error != "":
		tell(claim.error)
		return
	panel.hide()
	player.stop_navigation()
	if object.id == "onsen_locker":
		player.robe = not player.robe
		tell("已经换好衣服")
		return
	var zone: String = str(object.zone)
	if claim.slot != null and claim.slot != "only":
		zone = str(SIDES.get(claim.slot,"")) if object.id=="seesaw" else zone.get_slice("_",0) + "_" + str(claim.slot) if object.id=="long_bench" else zone.left(zone.length()-1)+str(claim.slot)
	var zones: Dictionary = WorldData.scenes[player.scene_id].zones
	player.want_zone = zone if zones.has(zone) else str(object.zone)
	var modules: Array = WorldPresentation.facts().objectModules.get(object.id,[])
	activity = {"id":object.id,"slot":claim.slot,"module":modules.front() if not modules.is_empty() else "", "use":use[0], "label":use[1], "left":10.0 if use[0] in ["fish","swim"] else 5.5}
	if player.scene_id=="qianxia-park" and object.id in ["swing","bench","rider"]:
		begin_effect()

func begin_effect() -> void:
	player.effect = {"kind":"fishing" if activity.use=="fish" else activity.use,"module":activity.module,"slot":activity.slot,"at":SharedFeed.now_ms(),"seconds":activity.left+0.5}
	player.action = activity.use
	player.action_label = activity.label

func stop_activity() -> void:
	if activity.is_empty():
		return
	activity.clear()
	player.effect = {}
	Seats.release(player.key)
	player.action = ""
	player.action_label = ""
	player.stage = {}
	player.stop_navigation()

func open_restaurant() -> void:
	show_panel("餐厅菜单")
	var choice := OptionButton.new()
	for dish in game._restaurant.dishes.values():
		choice.add_item("%s  ·  %d 币" % [dish.name, dish.price])
		choice.set_item_metadata(choice.item_count - 1, dish.id)
	rows.add_child(choice)
	for action_ in [["点餐","order"],["做菜","cook"],["用餐","eat"],["坐下","sit"],["取消安排","cancel"]]:
		option(action_[0], restaurant_order.bind(action_[1], choice))

func restaurant_order(mode: String, choice: OptionButton) -> void:
	if not viewing_player() or player.scene_id != "world-restaurant":
		return
	if mode=="cancel":
		game._restaurant.cancel(player.key)
		note.text = "已取消"
		return
	var result: Dictionary = game._restaurant.start(player.key, mode, str(choice.get_selected_metadata()))
	if result.ok:
		panel.hide()
	else:
		note.text = result.get("error","未开始")

func open_arcade(object: Dictionary) -> void:
	var key: String = str(object.id).trim_prefix("arcade_")
	if key == "blocks_2":
		key = "blocks@second"
	if str(object.id).begins_with("home_chess_"):
		key = "xiangqi"
	if object.space=="arcade" and key not in ["xiangqi","snake"]:
		start_arcade(key,object)
		return
	## 2026-11-20 Claude (arcade-mind): two-player machines and home boards open the arcade hub (solo game,
	## or invite a resident directly; her own AI answers). The old option list below stays for an offline world.
	if VadsLink.owns_bodies and near_object(object):
		panel.hide()
		var suffix_of: String = "@xjhome" if object.space == "xjhome" else "@home" if object.space == "home" else ""
		arcade.open_hub(key + suffix_of if key in ["xiangqi"] else key, object)
		return
	show_panel(str(object.name))
	var suffix: String = "@xjhome" if object.space == "xjhome" else "@home" if object.space == "home" else ""
	if suffix.is_empty():
		option("开始" + str(arcade.Hall.NAMES.get(key.get_slice("@",0), "游戏")), start_arcade.bind(key, object))
		if key=="xiangqi" and Features.on("gomoku"):
			option("开始五子棋", start_arcade.bind("gomoku", object))
	if VadsLink.owns_bodies and key in ["snake", "xiangqi"]:
		option("和住户一起玩", start_shared_arcade.bind(key + suffix, object))
		if key == "xiangqi" and Features.on("gomoku"):
			option("和住户下五子棋", start_shared_arcade.bind("gomoku" + suffix, object))

func start_shared_arcade(key: String, object: Dictionary) -> void:
	if near_object(object) and VadsLink.owns_bodies:
		panel.hide()
		arcade.start_shared(key)

func start_arcade(key: String, object: Dictionary) -> void:
	if not near_object(object):
		return
	if arcade.start(key, str(object.id)):
		panel.hide()
	else:
		note.text = "这个机位正在使用"

func open_peer(peer: String) -> void:
	if not Economy.Social.near(player.key, peer):
		tell("请在对方身边停下")
		return
	show_panel(Personal.label(peer, Residents.person(peer).name))
	## 2026-11-20 Claude (arcade-mind): invite her to a game right here (she answers with her own AI).
	var space := str(WorldData.SPACE_SCENE.find_key(player.scene_id))
	if VadsLink.owns_bodies and space in ["arcade", "home", "xjhome"]:
		var suffix: String = "" if space == "arcade" else "@" + space
		option("邀请她下象棋", _invite_peer.bind("xiangqi" + suffix, peer))
		if Features.on("gomoku"): option("邀请她下五子棋", _invite_peer.bind("gomoku" + suffix, peer))
		if space == "arcade": option("邀请她玩贪吃蛇", _invite_peer.bind("snake", peer))
	for gift in Economy.Social.view(player.key):
		if gift.to==player.key and gift.from==peer and gift.status=="offered":
			option("接受 · %s" % gift.get("item","邀请"), answer_offer.bind(peer,str(gift.id),"accept"))
			option("婉拒", answer_offer.bind(peer,str(gift.id),"decline"))
	for item in Economy.inventory(player.key).items:
		if item.giftable:
			option("送出 %s" % item.name, offer_gift.bind(peer,str(item.id)))

## 2026-11-20 Claude (arcade-mind)
func _invite_peer(key: String, peer: String) -> void:
	panel.hide()
	arcade.invite(key, peer)

func offer_gift(peer: String, product: String) -> void:
	var id := "player-gift-" + str(Time.get_ticks_usec())
	var result := Economy.social_request(player.key, {"id":id,"ticket":id,"action":"gift","peer":peer,"product":product})
	note.text = "已送出邀请，等待对方收下" if result.ok else str(result.error)

func answer_offer(peer: String, ticket: String, response: String) -> void:
	var result := Economy.social_request(player.key, {"id":"player-reply-" + str(Time.get_ticks_usec()),"ticket":ticket,"action":response})
	open_peer(peer)
	note.text = "已答复" if result.ok else str(result.error)

func _gift_changed(record: Dictionary) -> void:
	if record.get("to") == player.key and record.get("status") == "offered":
		tell("%s送来一份礼物 · 靠近按 E" % record.get("fromName","住户"))
	elif record.get("from") == player.key and record.get("status") == "received":
		tell("%s收下了%s" % [record.get("toName","住户"),record.get("item","礼物")])

func open_journal() -> void:
	show_panel("日记")
	for entry in Personal.accept({"actor":player.key,"action":"read"}).get("entries",[]).slice(-4):
		var text := Label.new()
		text.text = entry.text
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_theme_color_override("font_color", Hud.INK)
		rows.add_child(text)
	var input := TextEdit.new()
	input.custom_minimum_size.y = 110.0
	rows.add_child(input)
	option("保存", func():
		var result := Personal.accept({"actor":player.key,"action":"write","id":"player-journal-"+str(Time.get_ticks_usec()),"text":input.text})
		note.text = "日记已保存" if result.ok else str(result.error))

func set_player_mode(active: bool) -> void:
	if not active:
		visit_request = ""
		panel.hide()
		arcade.stop()
		stop_activity()
		if is_instance_valid(game._restaurant):
			game._restaurant.cancel(player.key)
	player.set_enabled(active)
