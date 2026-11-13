extends PopupPanel
## 1.1 模块: one switch per optional 1.1 module, with what it changes, whether it looks different and what it touches.
## Reads assets/update/modules.json (shared with the bridge's cabin_update_plan); saves with Features.save().
## Choices take effect after restarting the game. Opened from both the new and the 1.0 Settings panels.
var _checks := {}
var _note: Label

static func _label(text: String, size: int, color: Color, wrap := false) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", color)
	if wrap: l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _ready() -> void:
	var frame := StyleBoxFlat.new(); frame.bg_color = Hud.PAPER; frame.border_color = Hud.WOOD_D
	frame.set_border_width_all(3); frame.set_corner_radius_all(8); frame.set_content_margin_all(16)
	add_theme_stylebox_override("panel", frame)
	var font_of := SystemFont.new(); font_of.font_names = PackedStringArray(["Microsoft YaHei", "SimHei"])
	var t := Theme.new(); t.default_font = font_of; t.default_font_size = 14; theme = t
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 10); box.custom_minimum_size = Vector2(640, 0)
	add_child(box)
	var head := HBoxContainer.new(); box.add_child(head)
	var title := _label("1.1 模块", 20, Hud.WOOD); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(title)
	var close := Button.new(); close.text = "关闭"; close.pressed.connect(queue_free); head.add_child(close)
	box.add_child(_label("每一项都可以单独打开或关闭；关闭就保留 1.0 的样子。保存后重新启动游戏生效。", 13, Hud.INK2, true))
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(640, 380); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; box.add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", 8); scroll.add_child(list)
	for m in Features.descriptions():
		var card := PanelContainer.new()
		var face := StyleBoxFlat.new(); face.bg_color = Hud.PAPER_H; face.border_color = Hud.WOOD_L; face.set_border_width_all(1); face.set_corner_radius_all(6); face.set_content_margin_all(10)
		card.add_theme_stylebox_override("panel", face); list.add_child(card)
		var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 3); card.add_child(v)
		var row := HBoxContainer.new(); v.add_child(row)
		var check := CheckButton.new(); check.text = str(m.name); check.button_pressed = Features.on(str(m.id))
		check.add_theme_color_override("font_color", Hud.INK); check.add_theme_color_override("font_pressed_color", Hud.INK)
		check.add_theme_color_override("font_hover_color", Hud.INK); check.add_theme_color_override("font_focus_color", Hud.INK)
		row.add_child(check); _checks[str(m.id)] = check
		v.add_child(_label(str(m.summary), 13, Hud.INK, true))
		v.add_child(_label("看起来：" + str(m.looksDifferent) + "　·　存档：" + str(m.touches), 12, Hud.INK2, true))
	var foot := HBoxContainer.new(); box.add_child(foot)
	_note = _label("", 13, Hud.INK2, true); _note.size_flags_horizontal = Control.SIZE_EXPAND_FILL; foot.add_child(_note)
	var save := Button.new(); save.text = "保存"; save.pressed.connect(_save); foot.add_child(save)

func _save() -> void:
	var choice := {}
	for id in _checks: choice[id] = _checks[id].button_pressed
	var error := Features.save(choice)
	_note.text = error if error != "" else "已保存。重新启动游戏后生效；原来的选择保存在 features.json.bak。"
