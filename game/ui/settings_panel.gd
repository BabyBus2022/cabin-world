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
	_sheet.offset_left = -380
	_sheet.offset_right = 380
	_sheet.offset_top = -300
	_sheet.offset_bottom = 300
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
	var emblem:=Control.new();emblem.custom_minimum_size=Vector2(36,36);emblem.mouse_filter=MOUSE_FILTER_IGNORE;head.add_child(emblem)
	emblem.draw.connect(func():
		for r in [Rect2(4,12,28,16),Rect2(8,8,20,4),Rect2(12,4,12,4)]:emblem.draw_rect(r,Color("365a80"))
		emblem.draw_rect(Rect2(14,17,8,11),Hud.PAPER_H)
		emblem.draw_rect(Rect2(8,13,4,4),Color("e3b665"))
		emblem.draw_rect(Rect2(24,13,4,4),Color("e3b665")))
	var title := _label("小屋设置",head)
	title.add_theme_font_size_override("font_size",24)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	_button("关闭",close,head)
	var trim:=Control.new();trim.custom_minimum_size.y=8;trim.mouse_filter=MOUSE_FILTER_IGNORE;column.add_child(trim)
	trim.draw.connect(func():
		trim.draw_rect(Rect2(0,3,trim.size.x,2),Hud.WOOD_L)
		for x in [4,12,20]:trim.draw_rect(Rect2(x,1,4,6),Color("365a80")))
	var tabs:=TabContainer.new()
	tabs.add_theme_stylebox_override("panel",_box(Hud.PAPER,Hud.PAPER,0,0))
	tabs.add_theme_stylebox_override("tab_selected",_box(Hud.PAPER_H,Hud.WOOD_L,1,12))
	tabs.add_theme_stylebox_override("tab_unselected",_box(Hud.PAPER_D,Hud.PAPER,0,12))
	tabs.add_theme_stylebox_override("tab_hovered",_box(Hud.PAPER_H,Hud.WOOD_L,1,12))
	tabs.add_theme_color_override("font_selected_color",Hud.INK)
	tabs.add_theme_color_override("font_unselected_color",Hud.INK2)
	tabs.add_theme_color_override("font_hovered_color",Hud.INK)
	tabs.name="SettingsTabs";tabs.size_flags_vertical=SIZE_EXPAND_FILL;column.add_child(tabs)
	var body:=_page(tabs,"常用")
	_label("画面",body).add_theme_font_size_override("font_size",20)
	_resolution = OptionButton.new()
	for value in SIZES: _resolution.add_item("%d × %d" % [value.x,value.y])
	body.add_child(_resolution)
	_fullscreen = CheckBox.new()
	_fullscreen.text = "全屏"
	_fullscreen.size_flags_horizontal=SIZE_SHRINK_BEGIN
	body.add_child(_fullscreen)
	_display_status = _label("",body)
	_resolution.item_selected.connect(func(_index):
		_fullscreen.set_pressed_no_signal(false)
		_apply_display())
	_fullscreen.toggled.connect(func(_on): _apply_display())
	body.add_child(HSeparator.new())
	_label("工具",body).add_theme_font_size_override("font_size",20)
	var controls := GridContainer.new();controls.columns=2;controls.add_theme_constant_override("h_separation",12);controls.add_theme_constant_override("v_separation",12)
	body.add_child(controls)
	_button("刷新近况",func():refresh_requested.emit(),controls)
	_button("专注观察",func():observe_requested.emit();close(),controls)
	_button("家具布置 · F6",func():close();furniture_requested.emit(),controls)
	if Features.on("map-editor"):_button("地图编辑",func():close();map_requested.emit(),controls) # the new map editor (ui/map_editor.gd), owner D4; module switch, core/features.gd
	body=_page(tabs,"住户")
	if Features.on("add-bots"):_button("新增住户 / 分配房间",func():add_child(load("res://ui/resident_manager.gd").new()),body) ## module switch; bots added earlier stay
	for resident in Residents.people():
		var card:=PanelContainer.new();card.add_theme_stylebox_override("panel",_box(Hud.PAPER_H,Hud.WOOD_L,1,14));body.add_child(card)
		var content:=VBoxContainer.new();content.add_theme_constant_override("separation",12);card.add_child(content)
		var heading:=HBoxContainer.new();content.add_child(heading)
		for character in get_tree().get_nodes_in_group("world_residents"):
			if character.key!=resident.key:continue
			var f:Dictionary=character.portrait_frame();var r:Array=f.rect;var anchor:Array=f.anchor
			var portrait:=TextureRect.new();var atlas:=AtlasTexture.new();atlas.atlas=f.texture
			atlas.region=Rect2(float(r[0])+float(anchor[0])-92.5,float(r[1])+float(anchor[1])-278.0,185,185)
			portrait.texture=atlas;portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.texture_filter=TEXTURE_FILTER_NEAREST;portrait.custom_minimum_size=Vector2(48,48);heading.add_child(portrait)
		var name_label:=_label(load("res://core/resident_personal.gd").label(resident.key,resident.name),heading)
		name_label.add_theme_font_size_override("font_size",22);name_label.size_flags_horizontal=SIZE_EXPAND_FILL
		_button("改名",func():_rename(resident,name_label),heading)
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",18);content.add_child(row)
		var pause := CheckButton.new()
		pause.text="暂停探索"
		pause.tooltip_text="只暂停自主活动，聊天与手动操作仍可使用。"
		pause.size_flags_horizontal=SIZE_SHRINK_BEGIN
		row.add_child(pause)
		var spacer:=Control.new();spacer.size_flags_horizontal=SIZE_EXPAND_FILL;row.add_child(spacer)
		var lamps := OptionButton.new()
		for label in ["灯光 · 自动","灯光 · 开","灯光 · 关"]:lamps.add_item(label)
		row.add_child(lamps)
		_resident_options[resident.key]={"pause":pause,"lamps":lamps}
		pause.toggled.connect(func(on):_world_option(resident.key,{"paused":on}))
		lamps.item_selected.connect(func(i):_world_option(resident.key,{"lamps":["auto","on","off"][i]}))
	body.add_child(HSeparator.new())
	body=_page(tabs,"外观")
	_build_npc_settings(body)
	body=_page(tabs,"音频")
	tabs.tab_changed.connect(func(index):
		if index==3:_load_audio())
	_label("音频理解",body).add_theme_font_size_override("font_size",20)
	_audio_description = _label("音频由连接的机器人软件提供。",body)
	_endpoint = _field("接口地址",body)
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
	_save = _button("保存",_save_audio,buttons)
	_test = _button("测试连接",_test_audio,buttons)
	_reload = _button("重新读取",_load_audio,buttons)
	_status = _label("",column)
	_audio_notice = _label("",body)
	_audio_notice.add_theme_font_size_override("font_size",13)
	VadsLink.panel_arrived.connect(_on_data)
	VadsLink.panel_done.connect(_on_done)
	VadsLink.connection_changed.connect(_connection)
	hide()

func _build_npc_settings(body:VBoxContainer) -> void:
	body.add_child(HSeparator.new())
	_label("NPC 形象",body).add_theme_font_size_override("font_size",20)
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
	_npc_status=_label("",body)
	_load_npc_skin()

func _load_npc_skin() -> void:
	for i in _npc_cards.size():
		var active:bool=NpcAppearance.IDS[i]==NpcAppearance.current()
		_npc_cards[i].set_pressed_no_signal(active)
		_npc_cards[i].text=("团团" if i==0 else "Naiwa")+"\n"+("✓ 使用中" if active else "选择")

func _choose_npc_skin(index:int) -> void:
	var error:=NpcAppearance.choose(NpcAppearance.IDS[index],get_tree())
	_load_npc_skin()
	_npc_status.text="已换成"+NpcAppearance.label()+"" if error==OK else "皮肤保存失败，请重试。"

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
	box.set_corner_radius_all(6)
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
	button.custom_minimum_size.y=40
	button.size_flags_horizontal=SIZE_EXPAND_FILL if parent is GridContainer else SIZE_FILL
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
	_status.text=""

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
	if visible and _sheet.get_child(0).get_node("SettingsTabs").current_tab==3:
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

func _page(tabs:TabContainer,title:String)->VBoxContainer:
	var scroll:=ScrollContainer.new();scroll.name=title;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;tabs.add_child(scroll)
	var margin:=MarginContainer.new();margin.size_flags_horizontal=SIZE_EXPAND_FILL;scroll.add_child(margin)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,16)
	var body:=VBoxContainer.new();body.size_flags_horizontal=SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",12);margin.add_child(body)
	return body

func _rename(resident:Dictionary,target:Label)->void:
	var dialog:=ConfirmationDialog.new();dialog.title="修改名字";dialog.ok_button_text="保存";dialog.cancel_button_text="取消";dialog.size=Vector2i(360,140)
	var field:=LineEdit.new();field.text=target.text;field.max_length=32;dialog.add_child(field)
	dialog.confirmed.connect(func():
		var result:Dictionary=load("res://core/resident_personal.gd").accept({"actor":resident.key,"action":"rename","name":field.text})
		if result.ok:target.text=field.text.strip_edges()
		_status.text="名字已保存" if result.ok else str(result.error)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free);add_child(dialog);dialog.popup_centered();field.grab_focus()
