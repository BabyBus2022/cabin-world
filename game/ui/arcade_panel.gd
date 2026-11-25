class_name ArcadePanel
extends PanelContainer
## The dock card for live arcade matches.
## 2026-11-20 Claude (arcade-mind): redesigned (owner: "ugly, bloated, rigid"). No dropdown any more: up to two live
## matches show by themselves as cards — game and players on one line, a status chip, the board, and what the
## residents are thinking or saying right now (their own AI plays; see src/core/sim/arcade-mind.mjs in VADS).
## Click a card to watch it big (ui/player_arcade.gd watch()). "战绩" opens rules and recent results.
## Static helpers kept for other files: _face, available, live_choices, recent, name_of, RULES, NAMES.
const NAMES := {"snake":"贪吃蛇", "blocks":"俄罗斯方块", "mines":"扫雷", "xiangqi":"象棋","gomoku":"五子棋"}
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
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel",style)
	var font_of := SystemFont.new()
	font_of.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","SimHei"])
	add_theme_font_override("font",font_of)
	add_theme_font_size_override("font_size",13)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",6)
	add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := Label.new()
	title.text = "电玩城 · 正在进行"
	title.add_theme_font_size_override("font_size",15)
	title.add_theme_color_override("font_color",Hud.WOOD_D)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var more := Button.new()
	more.text = "战绩"
	more.focus_mode = Control.FOCUS_NONE
	more.pressed.connect(_show_history)
	_style_button(more)
	head.add_child(more)
	_columns = HBoxContainer.new()
	_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_columns.add_theme_constant_override("separation", 8)
	box.add_child(_columns)
	for i in 2:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _face(Hud.PAPER_H))
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.tooltip_text = "点一下观战"
		card.gui_input.connect(_card_clicked.bind(i))
		_columns.add_child(card)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 3)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(column)
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(top)
		var who := _label("", 13, Hud.INK)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		top.add_child(who)
		var state := _chip("", Hud.PAPER_D)
		top.add_child(state)
		var board := ArcadeBoardView.new()
		board.size_flags_vertical = Control.SIZE_EXPAND_FILL
		board.custom_minimum_size = Vector2(0,80)
		column.add_child(board)
		var detail := _label("", 12, Hud.INK2)
		detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		column.add_child(detail)
		var mind := _label("", 12, Hud.WOOD)
		mind.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		column.add_child(mind)
		_cards.append({"card":card,"who":who,"state":state,"board":board,"detail":detail,"mind":mind,"key":""})
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
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func _chip(text: String, fill: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var face := StyleBoxFlat.new(); face.bg_color = fill; face.set_corner_radius_all(6)
	face.content_margin_left = 6; face.content_margin_right = 6; face.content_margin_top = 1; face.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", face)
	chip.add_child(_label(text, 12, Hud.INK))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return chip

## Rules and recent results in the game's own paper-and-wood style.
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
		if card.card.visible: _refresh_card(card, rows[i])

func _card_clicked(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT): return
	var key := str(_cards[index].key)
	var host = get_parent()
	if key != "" and host != null and "player_controls" in host and host.player_controls != null:
		host.player_controls.arcade.watch(key)

func _refresh_card(card: Dictionary, chosen: Dictionary) -> void:
	var game = chosen.get("game")
	card.key = str(chosen.get("cabinetKey",""))
	card.board.board = game if game is Dictionary else {}
	card.board.queue_redraw()
	var players: Array = chosen.get("players",[]).map(func(p): return str(p.get("name",name_of(str(p.get("id",""))))))
	if chosen.get("passerby"): players.append(name_of("computer"))
	var game_name: String = "方块2号机" if chosen.get("cabinetKey")=="blocks@second" else NAMES.get(chosen.kind,chosen.kind)
	card.who.text = game_name + "  " + " vs ".join(PackedStringArray(players))
	card.who.tooltip_text = card.who.text
	var status: String = chosen.get("status","")
	var state: String = {"playing":"进行中","waiting":"等入座","draw":"平局","lost":"输了","interrupted":"中断","won":"赢了"}.get(status,status)
	if status=="won" and game is Dictionary: state = name_of(str(game.get("winner",""))) + "赢"
	(card.state.get_child(0) as Label).text = state
	card.detail.text = ""
	if game is Dictionary:
		match game.kind:
			"mines": card.detail.text = "翻开 %d/%d · 旗 %d/%d" % [game.open.size(),int(game.w*game.h-game.total),game.flags.size(),int(game.total)]
			"blocks": card.detail.text = "消行 %d/%d · %d 分" % [game.lines,game.target,game.score]
			"snake": card.detail.text = " · ".join(PackedStringArray(game.snakes.map(func(s): return name_of(s.id)+" "+str(s.score)+" 个")))
			"xiangqi": card.detail.text = "第 %d 手 · 轮到%s" % [game.moves,"红方" if game.turn else "黑方"]
			"gomoku": card.detail.text = "第 %d 手 · 轮到%s" % [game.moves,"白棋" if game.turn else "黑棋"]
	## What they are thinking or saying right now (their own AI).
	var mind_line := ""
	for id in chosen.get("minds", {}):
		var m: Dictionary = chosen.minds[id]
		if m.get("thinking", false): mind_line = "%s 在想…" % name_of(str(id))
	if mind_line == "":
		for r in chosen.get("feed", []):
			if r.get("kind") in ["say", "thought"]: mind_line = ("%s：%s" if r.kind == "say" else "（%s 想）%s") % [r.get("name",""), r.get("text","")]
	card.mind.text = mind_line
	card.mind.tooltip_text = mind_line
