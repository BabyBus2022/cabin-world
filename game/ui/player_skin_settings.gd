extends RefCounted

static func portrait(path:String)->Texture2D:
	var im:=Image.new()
	if not FileAccess.file_exists(path) or im.load_png_from_buffer(FileAccess.get_file_as_bytes(path))!=OK:return null
	var bounds:=im.get_used_rect()
	if not bounds.has_area():return null
	return ImageTexture.create_from_image(im.get_region(bounds))

static func label(text:String,size:int,ink:Color)->Label:
	var l:=Label.new()
	l.text=text
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",ink)
	return l

static func frame(fill:Color,line:Color)->StyleBoxFlat:
	var box:=StyleBoxFlat.new()
	box.bg_color=fill
	box.border_color=line
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.content_margin_top=5
	box.content_margin_bottom=5
	box.content_margin_left=7
	box.content_margin_right=7
	return box

static func mount(game,panel):
	var tabs=panel.find_child("SettingsTabs",true,false)
	var scroll:=ScrollContainer.new()
	scroll.name="玩家外观"
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	if tabs:tabs.add_child(scroll)
	else:
		var pages=panel.find_children("*","ScrollContainer",true,false)
		if pages.is_empty():return
		pages[0].get_child(0).add_child(scroll)
	var body:=VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",9)
	scroll.add_child(body)
	var player=game.local_player
	var spec:Dictionary=player.skin_catalog()
	var ink:=Color("#493325")
	body.add_child(label("选择玩家形象",20,ink))
	var cards:=GridContainer.new()
	cards.columns=2
	cards.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("h_separation",8)
	cards.add_theme_constant_override("v_separation",6)
	body.add_child(cards)
	scroll.resized.connect(func():cards.columns=2 if scroll.size.x>=268 else 1)
	var buttons:Array[Button]=[]
	for i in spec.builtins.size():
		var entry:Dictionary=spec.builtins[i]
		var b:=Button.new()
		b.name="Skin"+str(i)
		b.text=str(entry.name)
		b.toggle_mode=true
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.custom_minimum_size=Vector2(122,138)
		b.icon=portrait(str(entry.root)+"idle.png")
		b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP
		b.expand_icon=true
		b.add_theme_constant_override("icon_max_width",86)
		b.add_theme_color_override("font_color",ink)
		b.add_theme_color_override("font_hover_color",ink)
		b.add_theme_color_override("font_pressed_color",ink)
		b.add_theme_color_override("font_hover_pressed_color",ink)
		b.add_theme_stylebox_override("normal",frame(Color("#f7ead1"),Color("#bf9c72")))
		b.add_theme_stylebox_override("hover",frame(Color("#fff1cf"),Color("#9f7247")))
		b.add_theme_stylebox_override("pressed",frame(Color("#f5dc9a"),Color("#91622e")))
		b.add_theme_stylebox_override("hover_pressed",b.get_theme_stylebox("pressed"))
		cards.add_child(b)
		buttons.append(b)
	var status:=label("",13,ink)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.add_child(status)
	body.add_child(HSeparator.new())
	body.add_child(label("自定义形象",16,ink))
	var row:=HFlowContainer.new()
	body.add_child(row)
	var layout:=OptionButton.new()
	layout.add_item("单张角色图")
	layout.add_item("四向行走图")
	row.add_child(layout)
	var browse:=Button.new()
	browse.text="导入 PNG…"
	row.add_child(browse)
	var custom:=Button.new()
	custom.text="使用已导入形象"
	row.add_child(custom)
	var info:=label("四向图每行一个方向，依次为正面、左、右、背面。每格为正方形。",13,ink)
	info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.add_child(info)
	var sync=func():
		for i in buttons.size():
			buttons[i].set_pressed_no_signal(i==player.skin_index)
			buttons[i].text=str(spec.builtins[i].name)+("  ✓" if i==player.skin_index else "")
		custom.visible=player.has_custom_skin()
		custom.disabled=player.skin_index==buttons.size()
		status.text="当前形象  "+(str(spec.builtins[player.skin_index].name) if player.skin_index<buttons.size() else "自定义")
	var apply=func(i:int):
		if player.select_skin(i)!=OK:
			sync.call()
			status.text="形象未能载入，请检查文件。"
			return
		var host=game.qingxi_host
		if host!=null and is_instance_valid(host.scene) and host.scene.has_method("load_character_assets"):
			host.scene.clip_cache.clear()
			host.scene.load_character_assets()
			if is_instance_valid(host.scene.portrait):host.scene.show_idle()
		sync.call()
	for i in buttons.size():buttons[i].pressed.connect(apply.bind(i))
	custom.pressed.connect(apply.bind(buttons.size()))
	var dialog:=FileDialog.new()
	dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
	dialog.access=FileDialog.ACCESS_FILESYSTEM
	dialog.filters=PackedStringArray(["*.png ; PNG"])
	body.add_child(dialog)
	browse.pressed.connect(func():dialog.popup_centered_ratio(.76))
	dialog.file_selected.connect(func(path):
		if player.import_skin(path,layout.selected==1)==OK:apply.call(buttons.size())
		else:status.text="导入失败，请检查图片尺寸和透明区域。")
	sync.call()

