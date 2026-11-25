extends "res://ui/player_arcade_original.gd"

func start(key: String, object: String) -> bool:
	if not super.start(key, object):
		return false
	var player = controls.player
	if player.player_enabled and player.scene_id == "world-arcade" and key.get_slice("@", 0) in ["xiangqi", "gomoku"]:
		var room: Dictionary = WorldData.scenes[player.scene_id]
		var nearest := INF
		for zone in ["arcade_xiangqi_far", "arcade_xiangqi_near"]:
			if room.zones.has(zone):
				var distance: float = player.feet.distance_squared_to(WorldData.point(room.zones[zone]))
				if distance < nearest:
					nearest = distance
					player.want_zone = zone
	return true

func stop(notify := true) -> void:
	if not hosted and not spectating and board.get("kind", "") in ["xiangqi", "gomoku"] and is_instance_valid(controls):
		var player = controls.player
		if player.scene_id == "world-arcade" and player.want_zone in ["arcade_xiangqi_far", "arcade_xiangqi_near"]:
			player.stop_navigation()
	super.stop(notify)

func _rematch() -> void:
	if spectating or board.is_empty() or board.get("status") == "playing":
		return
	if match_id.is_empty() or not hosted:
		super._rematch()
		return
	var partner := ""
	var players: Array = snapshot.get("players", [])
	for member in players:
		if member.get("id", "") not in ["", Residents.PLAYER, "computer"]:
			partner = str(member.id)
	if partner.is_empty():
		super._rematch()
		return
	var previous := match_id
	var key := cabinet
	# The completed table has already released its seats on the host.
	stop(false)
	cabinet = key
	hosted = true
	invitee = partner
	invite_state = "asking"
	request = "rematch-" + str(Time.get_ticks_usec())
	active_invite_id = request
	local_feed = [{"kind":"system", "text":"你邀请%s再来一局" % _name(partner)}]
	_title.text = Hall.NAMES.get(key.get_slice("@", 0), "对局")
	_show("wait")
	VadsLink.send({"type":"arcade.playerInvite", "id":request, "key":key, "resident":partner, "previousMatchId":previous})

func _walk_to_invited_machine() -> void:
	if active_invite_id.begins_with("rematch-") and not controls.player.player_enabled:
		invite_state = "coming"
		remote_play = true
		start_shared(cabinet, active_invite_id)
		return
	super._walk_to_invited_machine()

func _owner_invited(frame: Dictionary) -> void:
	# The base controller owns invitation identity, expiry and the response buttons.
	var old_body := _invite_card.get_child(-1) if _invite_card.get_child_count() else null
	super._owner_invited(frame)
	if not _invite_card.visible or _invite_card.get_child_count() == 0:
		return
	var body := _invite_card.get_child(-1)
	if body == old_body:
		return
	var buttons := body.find_children("*", "Button", true, false)
	var bar := body.find_child("Bar", true, false) as ProgressBar
	var paper := art_box(Hud.PAPER, Hud.WOOD, 2, 8)
	paper.content_margin_left = 16
	paper.content_margin_right = 16
	paper.content_margin_top = 12
	paper.content_margin_bottom = 12
	paper.shadow_color = Color(0.12, 0.08, 0.04, 0.28)
	paper.shadow_size = 5
	paper.shadow_offset = Vector2(0, 3)
	_invite_card.add_theme_stylebox_override("panel", paper)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	_invite_card.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	var portrait := Face.new()
	portrait.owner_ui = self
	portrait.who = str(frame.get("from", ""))
	portrait.custom_minimum_size = Vector2(66, 66)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(portrait)
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 3)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	copy.add_child(_invite_text(str(frame.get("place", "电玩城")), 12, Hud.WOOD))
	var game_name := str(frame.get("game", "游戏"))
	var invitation := "下一盘" if game_name in ["象棋", "五子棋"] else "玩"
	var title := "%s邀你%s%s" % [frame.get("name", "她"), invitation, game_name]
	copy.add_child(_invite_text(title, 20, Hud.WOOD_D))
	var words := str(frame.get("words", "")).strip_edges()
	if not words.is_empty():
		var quote := _invite_text("“%s”" % words, 15, Hud.INK)
		quote.add_theme_constant_override("line_spacing", 2)
		copy.add_child(quote)
	var line := ColorRect.new()
	line.custom_minimum_size.y = 1
	line.color = Hud.PAPER_D
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(line)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	column.add_child(footer)
	var clock := VBoxContainer.new()
	clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clock.custom_minimum_size.x = 68
	clock.add_theme_constant_override("separation", 3)
	footer.add_child(clock)
	_invite_left.reparent(clock, false)
	_invite_left.add_theme_font_size_override("font_size", 12)
	_invite_left.add_theme_color_override("font_color", Hud.INK2)
	bar.reparent(clock, false)
	bar.custom_minimum_size = Vector2(0, 3)
	for style in ["background", "fill"]:
		var track := StyleBoxFlat.new()
		track.bg_color = Hud.PAPER_D if style == "background" else Hud.WOOD_L
		track.set_corner_radius_all(1)
		bar.add_theme_stylebox_override(style, track)
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(space)
	# Secondary action first, affirmative wood key at the outside edge.
	for i in range(buttons.size() - 1, -1, -1):
		buttons[i].reparent(footer, false)
	_invite_card.remove_child(body)
	body.queue_free()
	_place_invite_card()
	if not _invite_card.minimum_size_changed.is_connected(_place_invite_card):
		_invite_card.minimum_size_changed.connect(_place_invite_card, CONNECT_DEFERRED)
	if not get_viewport().size_changed.is_connected(_place_invite_card):
		get_viewport().size_changed.connect(_place_invite_card)

func _invite_text(value: String, px: int, ink: Color) -> Label:
	var label := _label(value, px, ink)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _place_invite_card() -> void:
	if not is_instance_valid(_invite_card) or not _invite_card.visible:
		return
	var width := get_viewport_rect().size.x
	_invite_card.custom_minimum_size.x = minf(470, maxf(1, width - 24))
	_invite_card.reset_size()
	_invite_card.position = Vector2(roundf((width - _invite_card.size.x) / 2), 16)

func _redraw_all() -> void:
	super._redraw_all()
	if is_instance_valid(_plate_top):
		_plate_top.visible = not board.get("kind", "") in ["mines", "blocks"]

func _refresh_report() -> void:
	super._refresh_report()
	if board.get("kind")=="xiangqi":
		var move:=last_chess_move(board)
		if move!="":report.text+=" · 上一步 "+move

static func last_chess_move(position:Dictionary)->String:
	var last=position.get("last")
	var pieces:Array=position.get("board",[])
	if not last is Dictionary or pieces.size()!=90:return ""
	var a:=int(last.get("from",-1))
	var b:=int(last.get("to",-1))
	if a<0 or a>=90 or b<0 or b>=90 or not pieces[b] is Dictionary:return ""
	var piece:Dictionary=pieces[b]
	var side:=int(piece.side)
	var names:Dictionary=ArcadeBoardView.PIECES[side]
	var file:="九八七六五四三二一" if side==1 else "123456789"
	var dy:=b/9-a/9
	var mark:="平" if dy==0 else ("进" if (dy<0)==(side==1) else "退")
	var suffix:=file[b%9] if dy==0 or piece.type in ["h","a","e"] else ("一二三四五六七八九"[absi(dy)-1] if side==1 else str(absi(dy)))
	var label:=str(names.get(piece.type,""))
	var ranks:Array[int]=[a/9]
	for i in range(a%9,90,9):
		if i!=b and pieces[i] is Dictionary and pieces[i].side==piece.side and pieces[i].type==piece.type:ranks.append(i/9)
	ranks.sort()
	if side==0:ranks.reverse()
	if ranks.size()==1:return label+file[a%9]+mark+suffix
	var rank:=ranks.find(a/9)
	var prefix:="前" if rank==0 else ("后" if rank==ranks.size()-1 else ("中" if ranks.size()==3 else "一二三四五"[rank]))
	return prefix+label+mark+suffix
