class_name WorldSettings
extends Control
## UI only. Audio is an optional host service; only display preferences live here.
const SIZES := [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]
var display: FixedWindow
var _status: Label
var _endpoint: LineEdit
var _model: LineEdit
var _key: LineEdit
var _enabled: CheckBox
var _save: Button
var _test: Button
var _reload: Button
var _resolution: OptionButton
var _fullscreen: CheckBox
var _display_status: Label
var _request := ""
var _seq := 0
var _remaining := 0.0
var _loaded := false
var _audio_description: Label
var _audio_notice: Label
var _sheet: PanelContainer
signal refresh_requested()
signal observe_requested()
signal furniture_requested()
signal map_requested() ## separate map editor (ui/map_editor.gd); does not touch the furniture editor
var _resident_options := {}
const NpcAppearance=preload("res://core/npc_appearance.gd")
var _npc_status:Label
var _npc_cards:Array=[]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.05,0.08,0.15,0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_sheet = PanelContainer.new()
	_sheet.set_anchors_preset(Control.PRESET_CENTER)
	_sheet.offset_left = -340
	_sheet.offset_right = 340
	_sheet.offset_top = -365
	_sheet.offset_bottom = 365
	_sheet.add_theme_stylebox_override("panel",_box(Hud.PAPER,Hud.WOOD,4,20))
	add_child(_sheet)
	var theme_of := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei","SimHei"])
	theme_of.default_font = font
	theme_of.default_font_size = 16
	for type_of in ["Label","Button","CheckBox","OptionButton","LineEdit"]:
		for color_of in ["font_color","font_hover_color","font_pressed_color"]: theme_of.set_color(color_of,type_of,Hud.INK)
	for type_of in ["Button","CheckBox","OptionButton","LineEdit"]:
		theme_of.set_color("font_disabled_color",type_of,Hud.INK2)
		theme_of.set_color("font_uneditable_color",type_of,Hud.INK2)
		theme_of.set_color("font_placeholder_color",type_of,Hud.INK2)
		theme_of.set_stylebox("disabled",type_of,_box(Hud.PAPER_D,Hud.WOOD_L,1,7))
		theme_of.set_stylebox("read_only",type_of,_box(Hud.PAPER_D,Hud.WOOD_L,1,7))
	for type_of in ["Button","OptionButton","LineEdit"]:
		theme_of.set_stylebox("normal",type_of,_box(Hud.PAPER_H,Hud.WOOD_L,2,7))
		theme_of.set_stylebox("hover",type_of,_box(Hud.PAPER_D,Hud.WOOD_L,2,7))
		theme_of.set_stylebox("pressed",type_of,_box(Hud.PAPER_D,Hud.WOOD,2,7))
	theme = theme_of
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	_sheet.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	var title := _label("小屋设置",head)
	title.add_theme_font_size_override("font_size",24)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	_button("关闭",close,head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",10)
	scroll.add_child(body)
	_label("画面",body).add_theme_font_size_override("font_size",20)
	_label("固定 16:9（1920 × 1080），整幅画面一起缩放。",body)
	_resolution = OptionButton.new()
	for value in SIZES: _resolution.add_item("%d × %d" % [value.x,value.y])
	body.add_child(_resolution)
	_fullscreen = CheckBox.new()
	_fullscreen.text = "全屏显示（保持比例）"
	body.add_child(_fullscreen)
	_button("应用画面设置",_apply_display,body)
	_display_status = _label("",body)
	_resolution.item_selected.connect(func(_index):
		_fullscreen.set_pressed_no_signal(false)
		_apply_display())
	_fullscreen.toggled.connect(func(_on): _apply_display())
	_build_npc_settings(body)
	body.add_child(HSeparator.new())
	_label("世界",body).add_theme_font_size_override("font_size",20)
	var controls := HBoxContainer.new()
	body.add_child(controls)
	_button("刷新近况",func():refresh_requested.emit(),controls)
	_button("专注观察 / 恢复面板",func():observe_requested.emit();close(),controls)
	_button("布置当前场景家具 · F6",func():close();furniture_requested.emit(),body)
	# Roomkit's map editor is temporarily hidden from Settings.
	_label("暂停只影响自主探索，聊天和手动工具继续可用。",body)
	for resident in Residents.people():
		var row := HBoxContainer.new()
		body.add_child(row)
		_label(resident.name,row).size_flags_horizontal=SIZE_EXPAND_FILL
		var pause := CheckBox.new()
		pause.text="暂停自主探索"
		row.add_child(pause)
		var lamps := OptionButton.new()
		for label in ["灯光 · 自动","灯光 · 开","灯光 · 关"]:lamps.add_item(label)
		row.add_child(lamps)
		_resident_options[resident.key]={"pause":pause,"lamps":lamps}
		pause.toggled.connect(func(on):_world_option(resident.key,{"paused":on}))
		lamps.item_selected.connect(func(i):_world_option(resident.key,{"lamps":["auto","on","off"][i]}))
	body.add_child(HSeparator.new())
	_label("音频与接口",body).add_theme_font_size_override("font_size",20)
	_audio_description = _label("音频由连接的机器人软件提供。",body)
	_endpoint = _field("接口地址 · 由机器人软件提供",body)
	_endpoint.editable = false
	_endpoint.placeholder_text = "连接机器人软件后读取"
	_model = _field("音频模型",body)
	_key = _field("音频服务密钥",body)
	_key.secret = true
	_key.placeholder_text = "留空保留已保存的密钥"
	_key.max_length = 4096
	_enabled = CheckBox.new()
	_enabled.text = "启用音频理解"
	body.add_child(_enabled)
	var buttons := HBoxContainer.new()
	body.add_child(buttons)
	_save = _button("保存到机器人软件",_save_audio,buttons)
	_test = _button("测试已保存的连接",_test_audio,buttons)
	_reload = _button("重新读取",_load_audio,buttons)
	_status = _label("",body)
	_audio_notice = _label("",body)
	_audio_notice.add_theme_font_size_override("font_size",13)
	VadsLink.panel_arrived.connect(_on_data)
	VadsLink.panel_done.connect(_on_done)
	VadsLink.connection_changed.connect(_connection)
	hide()

func _build_npc_settings(body:VBoxContainer) -> void:
	body.add_child(HSeparator.new())
	_label("NPC 设置",body).add_theme_font_size_override("font_size",20)
	var npc_row:=HBoxContainer.new()
	npc_row.add_theme_constant_override("separation",12)
	body.add_child(npc_row)
	for i in NpcAppearance.IDS.size():
		var skin:Dictionary=NpcAppearance.data().skins[NpcAppearance.IDS[i]]
		var frame:Dictionary=skin.frames[skin.animations.idle.frames[0]]
		var atlas:=AtlasTexture.new()
		atlas.atlas=load(frame.get("texture",skin.texture))
		atlas.region=Rect2(frame.rect[0],frame.rect[1],frame.rect[2],frame.rect[3])
		var card:=Button.new()
		card.name="NpcSkin_"+NpcAppearance.IDS[i]
		card.custom_minimum_size=Vector2(0,116)
		card.size_flags_horizontal=SIZE_EXPAND_FILL
		card.icon=atlas;card.expand_icon=true
		card.add_theme_constant_override("icon_max_width",76)
		card.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		card.toggle_mode=true
		card.pressed.connect(_choose_npc_skin.bind(i))
		npc_row.add_child(card);_npc_cards.append(card)
	_npc_status=_label("统一更换小卖部、餐厅和游戏对手的外观。",body)
	_load_npc_skin()

func _load_npc_skin() -> void:
	for i in _npc_cards.size():
		var active:bool=NpcAppearance.IDS[i]==NpcAppearance.current()
		_npc_cards[i].set_pressed_no_signal(active)
		_npc_cards[i].text=("团团" if i==0 else "Naiwa")+"\n"+("✓ 使用中" if active else "点击换上")

func _choose_npc_skin(index:int) -> void:
	var error:=NpcAppearance.choose(NpcAppearance.IDS[index],get_tree())
	_load_npc_skin()
	_npc_status.text="已换成"+NpcAppearance.label()+"，下次打开仍会使用。" if error==OK else "皮肤保存失败，请重试。"

func _world_option(actor: String,fields: Dictionary) -> void:
	if not Economy.people.has(actor):
		_status.text="住户还没有连上世界，设置未保存"
		_load_world_options()
		return
	_seq+=1
	var result := Economy.answer({"actor":actor,"op":"options","id":"settings-%s-%d"%[Time.get_ticks_usec(),_seq]}.merged(fields))
	_status.text="世界设置已保存" if result.ok else str(result.get("error","保存失败"))
	if result.ok:VadsLink.send({"type":"economy.social","actor":actor,"state":result.state,"view":result.view})
	_load_world_options()

func _load_world_options() -> void:
	for actor in _resident_options:
		var fields: Dictionary=Economy.people.get(actor,{}).get("options",{})
		_resident_options[actor].pause.set_pressed_no_signal(fields.get("paused",false))
		_resident_options[actor].lamps.select(maxi(0,["auto","on","off"].find(fields.get("lamps","auto"))))

func _box(color: Color, border: Color, width: int, pad: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_content_margin_all(pad)
	return box

func _label(value: String, parent: Node) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(value: String, action: Callable, parent: Node) -> Button:
	var button := Button.new()
	button.text = value
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _field(value: String, parent: Node) -> LineEdit:
	_label(value,parent)
	var field := LineEdit.new()
	field.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(field)
	return field

func open() -> void:
	show()
	_load_npc_skin()
	_load_world_options()
	var nearest := 0
	for i in SIZES.size():
		if Vector2(SIZES[i]).distance_to(Vector2(display.requested)) < Vector2(SIZES[nearest]).distance_to(Vector2(display.requested)): nearest = i
	_resolution.select(nearest)
	_fullscreen.button_pressed = get_window().mode == Window.MODE_FULLSCREEN
	_display_status.text = "当前窗口：%d × %d" % [get_window().size.x,get_window().size.y]
	_load_audio()

func close() -> void:
	_key.clear()
	_request = ""
	hide()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _apply_display() -> void:
	var error := display.apply_display(SIZES[_resolution.selected],_fullscreen.button_pressed)
	await get_tree().process_frame
	await get_tree().process_frame
	var actual := get_window().size
	var matched := get_window().mode == Window.MODE_FULLSCREEN if _fullscreen.button_pressed else actual == display.previous and (DisplayServer.get_name()=="headless" or get_window().mode == Window.MODE_WINDOWED)
	_display_status.text = "当前窗口：%d × %d · " % [actual.x,actual.y]
	if not matched:
		_display_status.text += "窗口未完成调整，请重试。"
		return
	_display_status.text += "已保存" if error == OK else "保存失败，下次启动不会保留"
	if not _fullscreen.button_pressed and actual != SIZES[_resolution.selected]:
		_display_status.text += "（已适配屏幕可用大小）"

func _controls() -> void:
	var ready_to_edit := VadsLink.connected and VadsLink.supports_audio_settings and _request == "" and _loaded
	_save.disabled = not ready_to_edit
	_test.disabled = not ready_to_edit
	_reload.disabled = not VadsLink.connected or not VadsLink.supports_audio_settings or _request != ""
	_model.editable = ready_to_edit
	_key.editable = ready_to_edit
	_enabled.disabled = not ready_to_edit

func _ask(frame: Dictionary, seconds: float) -> void:
	_seq += 1
	_request = "settings:" + str(_seq)
	_remaining = seconds
	frame.id = _request
	VadsLink.send(frame)
	_controls()

func _load_audio() -> void:
	_loaded = false
	_key.clear()
	_request = ""
	_save.text = "保存到 " + VadsLink.host_name
	_audio_description.text = "与 %s 共用音频配置，游戏不单独保存密钥。" % VadsLink.host_name
	_audio_notice.text = "测试连接使用宿主提供的音频服务，可能产生接口费用。"
	if VadsLink.connected and not VadsLink.supports_audio_settings:
		_endpoint.clear()
		_model.clear()
		_enabled.set_pressed_no_signal(false)
		_audio_description.text = "%s 的音频由它自己管理。" % VadsLink.host_name
		_audio_notice.text = "此宿主未提供游戏内音频设置接口，请在机器人软件中配置。"
		_status.text = "已连接 · 无需在游戏内配置音频"
		_controls()
		return
	_status.text = "正在读取 %s 音频配置…" % VadsLink.host_name if VadsLink.connected else "机器人软件未连接，音频设置暂不可用。"
	if VadsLink.connected: _ask({"type":"panel.get","panel":"audio"},12)
	else: _controls()

func _save_audio() -> void:
	if _save.disabled: return
	if _model.text.strip_edges()=="":
		_status.text = "请填写音频模型。"
		return
	_ask({"type":"panel.do","action":"audio.save","enabled":_enabled.button_pressed,"model":_model.text.strip_edges(),"key":_key.text},12)
	_key.clear()
	_status.text = "正在保存到 %s…" % VadsLink.host_name

func _test_audio() -> void:
	if _test.disabled: return
	_ask({"type":"panel.do","action":"audio.test"},135)
	_status.text = "正在测试 %s 中已保存的连接…" % VadsLink.host_name

func _fill(data: Dictionary) -> void:
	_loaded = true
	_model.text = str(data.get("model",""))
	_endpoint.text = str(data.get("endpoint",""))
	_enabled.button_pressed = data.get("enabled",false)
	_status.text = ("密钥已保存 · " if data.get("configured",false) else "尚未配置密钥 · ") + str(data.get("message",""))

func _on_data(frame: Dictionary) -> void:
	if str(frame.get("id", "")) != _request or _request == "": return
	_request = ""
	if frame.get("ok") == true and frame.get("data") is Dictionary: _fill(frame.data)
	else: _status.text = str(frame.get("error","读不到配置，请确认机器人软件支持该接口。"))
	_controls()

func _on_done(frame: Dictionary) -> void:
	if str(frame.get("id", "")) != _request or _request == "": return
	_request = ""
	if frame.get("ok") != true: _status.text = str(frame.get("error","操作失败"))
	elif frame.get("action") == "audio.save":
		_fill(frame.get("data",{}))
		_status.text = "已保存到 %s · " % VadsLink.host_name + _status.text
	else: _status.text = str(frame.get("data",{}).get("message","测试没有返回结果"))
	_controls()

func _connection(on: bool) -> void:
	_key.clear()
	_request = ""
	_loaded = false
	if visible:
		if on: _load_audio()
		else:
			_status.text = "%s 已断开，请重新连接后读取。" % VadsLink.host_name
			_controls()

func _process(delta: float) -> void:
	if _request == "": return
	_remaining -= delta
	if _remaining <= 0:
		_request = ""
		_status.text = "请求超时。保存结果尚未确认，请重新读取后再操作。"
		_loaded = false
		_controls()
