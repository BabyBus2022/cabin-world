class_name ArcadePanel
extends PanelContainer
const NAMES := {"snake":"贪吃蛇", "blocks":"俄罗斯方块", "mines":"扫雷", "xiangqi":"象棋"}
var _select: OptionButton
var _who: Label
var _state: Label
var _detail: Label
var _board: ArcadeBoardView
var selected := ""
var elapsed := 0.0

static func recent(row: Dictionary) -> bool:
	return row.get("status") in ["playing","waiting"] or (float(row.get("endedAt",0))>0 and SharedFeed.now_ms()-float(row.endedAt)<25000)

static func available(scene := "") -> bool:
	# The arcade keeps its scoreboard after a match. Other rooms retain the
	# temporary live-match view (including chess played at home).
	return scene=="world-arcade" or VadsLink.arcade_view.get("sessions",{}).values().any(func(s): return recent(s))

func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Hud.PAPER
	style.border_color = Hud.WOOD_D
	style.set_border_width_all(3)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel",style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",4)
	add_child(box)
	var font_of := SystemFont.new()
	font_of.font_names = PackedStringArray(["Microsoft YaHei","SimHei"])
	add_theme_font_override("font",font_of)
	add_theme_font_size_override("font_size",13)
	var title := Label.new()
	title.text = "星光电玩城 · 实时对局"
	title.add_theme_font_size_override("font_size",14)
	title.add_theme_color_override("font_color",Hud.WOOD)
	box.add_child(title)
	_select = OptionButton.new()
	_select.add_item("自动：正在玩的那台")
	for name_of in NAMES.values(): _select.add_item(name_of)
	_select.item_selected.connect(func(index): selected = "" if index==0 else NAMES.keys()[index-1]; refresh())
	_style_button(_select)
	_style_popup(_select.get_popup())
	box.add_child(_select)
	_who = Label.new()
	_state = Label.new()
	for label_of in [_who,_state]:
		label_of.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label_of.add_theme_color_override("font_color",Hud.INK)
		box.add_child(label_of)
	_board = ArcadeBoardView.new()
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.custom_minimum_size = Vector2(0,80)
	box.add_child(_board)
	_detail = Label.new()
	_detail.add_theme_color_override("font_color",Hud.INK2)
	_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(_detail)
	var more := Button.new()
	more.text = "规则与最近战绩"
	more.pressed.connect(_show_history)
	_style_button(more)
	box.add_child(more)
	refresh()

static func _face(bg: Color) -> StyleBoxFlat:
	var face := StyleBoxFlat.new()
	face.bg_color = bg
	face.border_color = Hud.WOOD_L
	face.set_border_width_all(2)
	face.set_content_margin_all(5)
	return face

func _style_button(button: Button) -> void:
	for state in ["normal","hover","pressed","focus"]:
		button.add_theme_stylebox_override(state,_face(Hud.PAPER_H if state in ["hover","focus"] else Hud.PAPER_D if state=="pressed" else Hud.PAPER))
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		button.add_theme_color_override(state,Hud.INK)
	button.add_theme_font_size_override("font_size",13)

func _style_popup(popup: PopupMenu) -> void:
	popup.add_theme_stylebox_override("panel",_face(Hud.PAPER_H))
	popup.add_theme_stylebox_override("hover",_face(Hud.PAPER_D))
	popup.add_theme_color_override("font_color",Hud.INK)
	popup.add_theme_color_override("font_hover_color",Hud.INK)

func _show_history() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "电玩城 · 规则与战绩"
	var lines := PackedStringArray()
	for kind in NAMES:
		if selected=="" or selected==kind: lines.append(NAMES[kind]+"："+str(VadsLink.arcade_view.get("rules",{}).get(kind,"")))
	var history: Array = VadsLink.arcade_view.get("history",[]).slice(-5)
	history.reverse()
	for record in history:
		var players: Array = record.get("players",[]).map(func(p): return str(p.get("name",name_of(str(p.get("id","")))))+str({"won":"赢","lost":"输","draw":"平"}.get(p.get("result"),"")))
		lines.append(NAMES.get(record.kind,record.kind)+"："+"，".join(PackedStringArray(players)))
	dialog.dialog_text = "\n\n".join(lines)
	dialog.min_size = Vector2i(400,180)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func _process(dt: float) -> void:
	elapsed += dt
	if elapsed >= .15:
		elapsed = 0
		if visible: refresh()

static func name_of(id: String) -> String:
	return load("res://core/npc_appearance.gd").label() if id=="computer" else str(Residents.person(id).get("name",id))

func refresh() -> void:
	var rows: Array = VadsLink.arcade_view.get("sessions",{}).values()
	var chosen := {}
	if selected != "":
		for row in rows:
			if row.get("kind")==selected: chosen=row; break
	else:
		for phase in ["playing","waiting"]:
			for row in rows:
				if row.get("status")==phase: chosen=row; break
			if not chosen.is_empty(): break
		if chosen.is_empty():
			rows.sort_custom(func(a,b): return float(a.get("endedAt",0))>float(b.get("endedAt",0)))
			if not rows.is_empty(): chosen=rows[0]
	var game = chosen.get("game")
	_board.board = game if game is Dictionary else {}
	_board.queue_redraw()
	if chosen.is_empty():
		_who.text = "这台机子暂时没有对局"
		_state.text = ""
		_detail.text = ""
		return
	var players: Array = chosen.get("players",[]).map(func(p): return str(p.get("name",name_of(str(p.get("id",""))))))
	if chosen.get("passerby"): players.append(name_of("computer"))
	_who.text = NAMES.get(chosen.kind,chosen.kind) + " · " + " × ".join(PackedStringArray(players))
	var status: String = chosen.get("status","")
	_state.text = {"playing":"进行中","waiting":"等待入座","draw":"平局","lost":"这局输了","interrupted":"已中断，不算输赢","won":"赢了"}.get(status,status)
	if status=="won" and game is Dictionary: _state.text = name_of(str(game.get("winner",""))) + "赢了"
	if status!="playing" and str(chosen.get("reason",""))!="": _state.text += " · " + chosen.reason
	_state.tooltip_text = _state.text
	_detail.text = ""
	if not game is Dictionary: return
	match game.kind:
		"mines": _detail.text = "翻开 %d/%d · 旗 %d/%d" % [game.open.size(),int(game.w*game.h-game.total),game.flags.size(),int(game.total)]
		"blocks": _detail.text = "消行 %d/%d · %d 分" % [game.lines,game.target,game.score]
		"snake": _detail.text = " · ".join(PackedStringArray(game.snakes.map(func(s): return name_of(s.id)+" "+str(s.score)+" 个")))
		"xiangqi": _detail.text = "第 %d 手 · %s%s" % [game.moves,"红方" if game.turn else "黑方","走棋" if status=="playing" else " · 已结束"]
