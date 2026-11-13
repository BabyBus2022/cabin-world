class_name ArcadePanel
extends PanelContainer
const NAMES := {"snake":"贪吃蛇", "blocks":"俄罗斯方块", "mines":"扫雷", "xiangqi":"象棋","gomoku":"五子棋"}
var _select: OptionButton
var _who: Label
var _state: Label
var _detail: Label
var _board: ArcadeBoardView
var _cards: Array = []
var _columns: HBoxContainer
var selected := ""
var elapsed := 0.0

static func recent(row: Dictionary) -> bool:
	var game=row.get("game")
	return row.get("status")=="playing" and game is Dictionary and game.get("status","playing")=="playing"

static func available(scene := "") -> bool:
	return not live_choices(VadsLink.arcade_view.get("sessions",{})).is_empty()

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
	_select.add_item("自动：同时显示正在玩的机台")
	for name_of in NAMES.values(): _select.add_item(name_of)
	_select.item_selected.connect(func(index): selected = "" if index==0 else NAMES.keys()[index-1]; refresh())
	_style_button(_select)
	_style_popup(_select.get_popup())
	box.add_child(_select)
	_columns = HBoxContainer.new()
	_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_columns.add_theme_constant_override("separation", 8)
	box.add_child(_columns)
	for i in 2:
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_constant_override("separation", 4)
		_columns.add_child(card)
		var who := Label.new()
		var state := Label.new()
		for label_of in [who,state]:
			label_of.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			label_of.add_theme_color_override("font_color",Hud.INK)
			card.add_child(label_of)
		var board := ArcadeBoardView.new()
		board.size_flags_vertical = Control.SIZE_EXPAND_FILL
		board.custom_minimum_size = Vector2(0,80)
		card.add_child(board)
		var detail := Label.new()
		detail.add_theme_color_override("font_color",Hud.INK2)
		detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		card.add_child(detail)
		_cards.append({"card":card,"who":who,"state":state,"board":board,"detail":detail})
	var more := Button.new()
	more.text = "玩法与战绩"
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

## One short line per game. The full rule text from VADS stays available to the residents; people only need the gist.
const RULES := {"snake":"先吃到 12 个果子（两人对战 15 个）", "blocks":"消除 30 行就过关", "mines":"翻开所有安全格就赢", "xiangqi":"将死对方，或让对方无棋可走", "gomoku":"先连成五子就赢 · 15×15"}
const RESULT := {"won":["赢",Hud.GREEN], "lost":["输",Hud.PINK], "draw":["平",Hud.PAPER_D]}
var _history_popup: PopupPanel

static func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", color)
	return l

static func _chip(text: String, fill: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var face := StyleBoxFlat.new(); face.bg_color = fill; face.set_corner_radius_all(6)
	face.content_margin_left = 6; face.content_margin_right = 6; face.content_margin_top = 1; face.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", face)
	chip.add_child(_label(text, 12, Hud.INK))
	return chip

## Rules and recent results in the game's own paper-and-wood style (it used to be a plain system dialog).
func _show_history() -> void:
	if is_instance_valid(_history_popup): _history_popup.queue_free()
	var popup := PopupPanel.new(); _history_popup = popup
	var frame := StyleBoxFlat.new(); frame.bg_color = Hud.PAPER; frame.border_color = Hud.WOOD_D
	frame.set_border_width_all(3); frame.set_corner_radius_all(8); frame.set_content_margin_all(16)
	popup.add_theme_stylebox_override("panel", frame)
	var font_of := SystemFont.new(); font_of.font_names = PackedStringArray(["Microsoft YaHei","SimHei"])
	var theme_of := Theme.new(); theme_of.default_font = font_of; theme_of.default_font_size = 14; popup.theme = theme_of
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 10); box.custom_minimum_size = Vector2(440, 0)
	popup.add_child(box)
	var head := HBoxContainer.new(); box.add_child(head)
	var title := _label("电玩城 · 玩法与战绩", 18, Hud.WOOD); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(title)
	var close := Button.new(); close.text = "关闭"; _style_button(close); close.pressed.connect(popup.queue_free); head.add_child(close)
	var kinds: Array = NAMES.keys().filter(func(k): return selected=="" or selected==k)
	box.add_child(_label("玩法", 13, Hud.WOOD_L))
	var rules := GridContainer.new(); rules.columns = 2
	rules.add_theme_constant_override("h_separation", 14); rules.add_theme_constant_override("v_separation", 4); box.add_child(rules)
	for kind in kinds:
		rules.add_child(_label(NAMES[kind], 14, Hud.INK))
		rules.add_child(_label(RULES.get(kind, ""), 14, Hud.INK2))
	var pay := _chip("赢 +5 钱 · 输 −2 钱 · 平局和中途离开不算", Hud.PAPER_D); pay.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; box.add_child(pay)
	box.add_child(HSeparator.new())
	box.add_child(_label("最近战绩", 13, Hud.WOOD_L))
	var history: Array = VadsLink.arcade_view.get("history",[]).filter(func(r): return r is Dictionary and (selected=="" or r.get("kind")==selected)).slice(-6)
	history.reverse()
	if history.is_empty(): box.add_child(_label("还没有下完的对局", 14, Hud.INK2))
	for record in history:
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); box.add_child(row)
		var at := float(record.get("at", 0))
		var when := Time.get_datetime_string_from_unix_time(int(at/1000.0) + 28800).substr(5, 11).replace("T", " ") if at > 0 else ""
		var time_label := _label(when, 12, Hud.INK2); time_label.custom_minimum_size = Vector2(88, 0); row.add_child(time_label)
		var game_label := _label(NAMES.get(record.get("kind",""), str(record.get("kind",""))), 14, Hud.INK); game_label.custom_minimum_size = Vector2(76, 0); row.add_child(game_label)
		var players: Array = record.get("players", [])
		for p in players:
			row.add_child(_label(str(p.get("name", name_of(str(p.get("id",""))))), 14, Hud.INK))
			var res = RESULT.get(p.get("result"))
			if res: row.add_child(_chip(res[0], res[1]))
		if record.get("passerby") and players.size() < 2: row.add_child(_label("vs " + name_of("computer"), 14, Hud.INK2))
		if players.all(func(p): return not RESULT.has(p.get("result"))): row.add_child(_chip("中断", Hud.PAPER_D))
	add_child(popup)
	popup.popup_centered()

func _process(dt: float) -> void:
	elapsed += dt
	if elapsed >= .15:
		elapsed = 0
		if visible: refresh()

static func name_of(id: String) -> String:
	return load("res://core/npc_appearance.gd").label() if id=="computer" else str(Residents.person(id).get("name",id))

static func live_choices(sessions: Dictionary, selection: String = "") -> Array:
	var rows: Array = []
	for key in sessions:
		var row: Dictionary = sessions[key].duplicate()
		row["cabinetKey"] = key
		if recent(row) and (selection=="" or row.get("kind")==selection): rows.append(row)
	rows.sort_custom(func(a,b):
		var rank := {"playing":0,"waiting":1}
		var ra: int = rank.get(a.get("status"),2)
		var rb: int = rank.get(b.get("status"),2)
		if ra!=rb:return ra<rb
		if ra<2:return str(a.cabinetKey)<str(b.cabinetKey)
		return float(a.get("endedAt",0))>float(b.get("endedAt",0)))
	return rows.slice(0,2)

func refresh() -> void:
	var rows := live_choices(VadsLink.arcade_view.get("sessions",{}), selected)
	for i in _cards.size():
		var card: Dictionary = _cards[i]
		card.card.visible = i<rows.size()
		if not card.card.visible:continue
		_who=card.who;_state=card.state;_board=card.board;_detail=card.detail
		_refresh_card(rows[i] if i<rows.size() else {})

func _refresh_card(chosen: Dictionary) -> void:
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
	_who.text = ("方块2号机" if chosen.get("cabinetKey")=="blocks@second" else "方块1号机" if chosen.kind=="blocks" else NAMES.get(chosen.kind,chosen.kind)) + " · " + " × ".join(PackedStringArray(players))
	_who.tooltip_text = _who.text
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
		"gomoku": _detail.text = "第 %d 手 · %s%s" % [game.moves,"白方" if game.turn else "黑方","落子" if status=="playing" else " · 已结束"]
