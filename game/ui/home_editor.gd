extends Control
const Grid=preload("res://core/world_grid.gd")
signal saved_layout(value:Dictionary)
signal exit_requested()
var embedded := false
var editor_scene:=""
## Fixed shell, independent furniture, optional groups. Saving never edits resident/economy data.
var layout:Dictionary={}
var saved:Dictionary={}
var selected:Array=[]
var history:Array=[]
var future:Array=[]
var room:Room
var stage:=Node2D.new()
var overlay:=Node2D.new()
var list:=ItemList.new()
var message:=Label.new()
var selection_label:=Label.new()
var dirty:=false
var drag:=false
var drag_start:=Vector2.ZERO
var drag_base:Dictionary={}
var drag_step:=Vector2i.ZERO
var candidate:Dictionary={}
var grid_on:=true
var file_label:=Label.new()
var ignore_list:=false
var close_dialog:=ConfirmationDialog.new()
var placement_issue := ""
var header:=PanelContainer.new()
var sidebar:=PanelContainer.new()
var status_panel:=PanelContainer.new()
var map_frame:=Panel.new()
var search:=LineEdit.new()
var category:=OptionButton.new()
var list_mode:=OptionButton.new()
var furniture_title:=Label.new()
var save_button:=Button.new()
var count_label:=Label.new()
var floor_polygons:Array[PackedVector2Array]=[]
var grid_segments:Array[PackedVector2Array]=[]
var grid_cells:Array[Rect2]=[]
var library_dialog := AcceptDialog.new()
var library_list := ItemList.new()
var library_search := LineEdit.new()
var library_source := OptionButton.new()
var library_scenes:Array=[""]
var pending_asset := ""
var pending_restore: Array = []
var collision_on := false
var maker_dialog:AcceptDialog
var function_filter:=OptionButton.new()


func _ready() -> void:
	editor_scene=HomeGrid.selected_scene
	if HomeGrid.current.get("scene","")!=editor_scene:HomeGrid.load_saved()
	layout=HomeGrid.current.duplicate(true);saved=layout.duplicate(true)
	HomeGrid.activate(layout)
	if not embedded:
		get_window().title="小屋世界 · "+str(HomeGrid.data().sceneData.name)+"家具布置"
		get_tree().auto_accept_quit=false
	theme=editor_theme()
	build_floor_grid()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg:=ColorRect.new();bg.color=Color("293d39");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(bg)
	map_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE;map_frame.add_theme_stylebox_override("panel",box(Hud.WOOD,Hud.WOOD_D,5,0));add_child(map_frame)
	add_child(stage)
	stage.add_child(overlay);overlay.z_index=200;overlay.draw.connect(draw_grid)
	header.add_theme_stylebox_override("panel",box(Hud.PAPER,Hud.WOOD,4,14));add_child(header)
	var top:=VBoxContainer.new();top.add_theme_constant_override("separation",10);header.add_child(top)
	var head:=HBoxContainer.new();head.add_theme_constant_override("separation",18);top.add_child(head)
	var title:=Label.new();title.text=str(HomeGrid.data().sceneData.name)+"  /  家具布置";title.add_theme_font_size_override("font_size",28);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;head.add_child(title)
	save_button.text="保存布置";save_button.custom_minimum_size=Vector2(148,44);save_button.pressed.connect(save_layout)
	for state in ["normal","hover","pressed"]:save_button.add_theme_stylebox_override(state,box(Color("365a80") if state=="normal" else Color("47749c"),Color("253e5a"),2,10))
	for state in ["font_color","font_hover_color","font_pressed_color"]:save_button.add_theme_color_override(state,Hud.CREAM)
	head.add_child(save_button)
	if embedded:button(head,"返回游戏 · F6",request_exit)
	var bar:=HFlowContainer.new();bar.add_theme_constant_override("h_separation",8);bar.add_theme_constant_override("v_separation",6);top.add_child(bar)
	button(bar,"组合",group_selection);button(bar,"拆开组合",ungroup_selection)
	button(bar,"撤销",undo);button(bar,"收起家具",store_selection)
	button(bar,"转向 · R",turn_selected) ## furniture facings: only pieces with approved four-view art; otherwise it says why
	button(bar,"重做",redo);button(bar,"摆回房间",restore_selection)
	button(bar,"恢复默认",func():commit(HomeGrid.defaults(),"默认布局已恢复；可撤销，保存后才写入"))
	var collision_button:=CheckButton.new();collision_button.text="碰撞范围";collision_button.toggled.connect(func(on):collision_on=on;overlay.queue_redraw());bar.add_child(collision_button)
	var grid_button:=CheckButton.new();grid_button.text="显示格子";grid_button.button_pressed=true;grid_button.toggled.connect(func(on):grid_on=on;overlay.queue_redraw());bar.add_child(grid_button)
	sidebar.add_theme_stylebox_override("panel",box(Hud.PAPER,Hud.WOOD,4,14));add_child(sidebar)
	var side:=VBoxContainer.new();side.add_theme_constant_override("separation",8);sidebar.add_child(side)
	var label_row:=HBoxContainer.new();side.add_child(label_row)
	furniture_title.text="全部家具";furniture_title.add_theme_font_size_override("font_size",26);furniture_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label_row.add_child(furniture_title)
	count_label.add_theme_color_override("font_color",Hud.INK2);label_row.add_child(count_label)
	for text in ["素材库","房间内","收纳箱"]:list_mode.add_item(text)
	list_mode.item_selected.connect(func(_i):populate_list());side.add_child(list_mode)
	search.placeholder_text="搜索家具…";search.clear_button_enabled=true;search.text_changed.connect(func(_text):populate_list());side.add_child(search)
	for text in ["全部家具","桌椅与收纳","装饰与小物","地毯与坐垫"]:category.add_item(text)
	var filters:=HBoxContainer.new();side.add_child(filters)
	category.size_flags_horizontal=Control.SIZE_EXPAND_FILL;category.add_theme_font_size_override("font_size",16)
	category.item_selected.connect(func(_index):populate_list());filters.add_child(category)
	for text in ["全部类型","有互动功能","仅装饰"]:function_filter.add_item(text)
	function_filter.add_theme_font_size_override("font_size",16)
	function_filter.item_selected.connect(func(_i):populate_list());filters.add_child(function_filter)
	if Features.on("furniture-workshop"):button(side,"家具制作 · 图片与动作",open_maker) ## module switch, core/features.gd
	list.select_mode=ItemList.SELECT_MULTI;list.fixed_icon_size=Vector2i(96,80);list.icon_mode=ItemList.ICON_MODE_TOP
	list.max_columns=2;list.fixed_column_width=142;list.same_column_width=true;list.max_text_lines=2
	list.add_theme_font_size_override("font_size",16)
	list.size_flags_vertical=Control.SIZE_EXPAND_FILL;list.custom_minimum_size=Vector2(280,120);side.add_child(list)
	list.multi_selected.connect(list_selection)
	var selection_card:=PanelContainer.new();selection_card.add_theme_stylebox_override("panel",box(Hud.PAPER_H,Hud.WOOD_L,1,10));side.add_child(selection_card)
	selection_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;selection_label.custom_minimum_size=Vector2(250,64);selection_label.max_lines_visible=4;selection_label.add_theme_font_size_override("font_size",16);selection_card.add_child(selection_label)
	file_label.text="Shift 多选 · 方向键移动一格 · R 转向\n保存立即生效 · F6 返回游戏" if embedded else "Shift 多选 · 方向键移动一格 · R 转向\n保存布置后从游戏内查看。";file_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;file_label.add_theme_font_size_override("font_size",17);file_label.add_theme_color_override("font_color",Hud.INK2);side.add_child(file_label)
	status_panel.add_theme_stylebox_override("panel",box(Hud.PAPER,Hud.WOOD,3,10));add_child(status_panel)
	file_label.tooltip_text=file_label.text;file_label.text="Shift 多选 · R 旋转 · 方向键移动";file_label.add_theme_font_size_override("font_size",15)
	message.text="点选家具开始布置  ·  绿色可以放置，红色需要换个位置";message.add_theme_font_size_override("font_size",20);status_panel.add_child(message)
	add_child(close_dialog);close_dialog.title="尚未保存布局";close_dialog.dialog_text="返回游戏会丢弃尚未保存的布置。";close_dialog.ok_button_text="返回，不保存";close_dialog.cancel_button_text="继续布置";close_dialog.confirmed.connect(finish_exit)
	build_library_dialog()
	populate_list()
	refresh(layout);resized.connect(fit)
	select_items([])
	if HomeGrid.load_warning!="":message.text=HomeGrid.load_warning
	var args:=OS.get_cmdline_user_args()
	var seconds:=args.find("--seconds")
	if not embedded and seconds>=0 and seconds+1<args.size():
		await get_tree().create_timer(float(args[seconds+1])).timeout
		var screenshot:=args.find("--shot")
		if screenshot>=0 and DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(args[screenshot+1])
		get_tree().quit()

func button(parent:Node,text:String,fn:Callable) -> void:
	var b:=Button.new();b.text=text;b.custom_minimum_size=Vector2(90,40);b.pressed.connect(fn);parent.add_child(b)

static func box(fill:Color,border:Color,width:int,pad:int) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=fill;style.border_color=border;style.set_border_width_all(width);style.set_content_margin_all(pad)
	return style

static func editor_theme() -> Theme:
	var out:=Theme.new();out.default_font_size=18
	var font:=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","SimHei"]);out.default_font=font
	for type in ["Label","Button","CheckButton","OptionButton","LineEdit","ItemList","PopupMenu"]:
		for state in ["font_color","font_hover_color","font_pressed_color","font_selected_color"]:out.set_color(state,type,Hud.INK)
		out.set_color("font_placeholder_color",type,Hud.INK2)
	for type in ["Button","OptionButton","LineEdit"]:
		out.set_stylebox("normal",type,box(Hud.PAPER_H,Hud.WOOD_L,2,8))
		out.set_stylebox("hover",type,box(Hud.PAPER_D,Hud.WOOD,2,8))
		out.set_stylebox("pressed",type,box(Color("d8c19c"),Hud.WOOD,2,8))
		out.set_stylebox("focus",type,box(Color(0,0,0,0),Color("547d9a"),2,0))
	out.set_stylebox("panel","ItemList",box(Hud.PAPER_H,Hud.WOOD_L,1,4))
	out.set_stylebox("selected","ItemList",box(Color("c4d9de"),Color("61859b"),2,5))
	out.set_stylebox("selected_focus","ItemList",box(Color("c4d9de"),Color("61859b"),2,5))
	out.set_stylebox("hovered","ItemList",box(Hud.PAPER_D,Hud.WOOD_L,1,5))
	out.set_constant("v_separation","ItemList",12);out.set_constant("icon_margin","ItemList",12)
	out.set_stylebox("panel","PopupMenu",box(Hud.PAPER_H,Hud.WOOD,2,8))
	for orientation in ["VScrollBar","HScrollBar"]:
		out.set_stylebox("scroll",orientation,box(Hud.PAPER_D,Hud.PAPER_D,0,3))
		for state in ["grabber","grabber_highlight","grabber_pressed"]:out.set_stylebox(state,orientation,box(Hud.WOOD_L,Hud.WOOD,1,5))
	return out

func populate_list() -> void:
	HomeGrid.activate(layout)
	ignore_list=true;list.clear()
	if list_mode.selected==0:
		furniture_title.text="全部家具"
		for a in HomeGrid.Library.all().values():
			if not function_matches(a):continue
			if search.text!="" and not (str(a.name)+str(a.scene_name)).contains(search.text):continue
			var kind:int=3 if a.layer=="floor" else 2 if a.layer=="surface" or "plant" in a.id or "lamp" in a.id else 1
			if category.selected>0 and category.selected!=kind:continue
			var icon:Texture2D=null
			var path:=("res://assets/baked/"+str(a.layers[0].file)).simplify_path()
			icon=HomeGrid.Library.icon(path)
			if icon!=null and a.layers[0].has("region"):
				var atlas:=AtlasTexture.new();atlas.atlas=icon
				var r:Array=a.layers[0].region;atlas.region=Rect2(r[0],r[1],r[2],r[3]);icon=atlas
			var index:=list.add_item(a.name,icon);list.set_item_metadata(index,"library:"+a.id)
			list.set_item_tooltip(index,"%s · %s\n%d×%d 格 · %s\n点击后在地图放置" % [a.name,a.scene_name,a.footprint.w,a.footprint.h,HomeGrid.Library.label(a)])
	else:
		furniture_title.text="已收起家具" if list_mode.selected==2 else "本房间家具"
		for item in HomeGrid.data().catalog:
			if not function_matches(item):continue
			if list_mode.selected==2 and not HomeGrid.hidden(layout,item.id):continue
			if search.text!="" and not str(item.name).contains(search.text):continue
			var kind:int=3 if item.layer=="floor" else 2 if item.layer=="surface" or "plant" in item.id or "lamp" in item.id else 1
			if category.selected>0 and category.selected!=kind:continue
			var icon:Texture2D=null
			var path:String=item.get("icon","res://assets/seaside/"+str(item.id)+".png")
			path=path.simplify_path()
			icon=HomeGrid.Library.icon(path)
			if icon!=null and item.has("iconRegion"):
				var atlas:=AtlasTexture.new();atlas.atlas=icon
				var r:Array=item.iconRegion;atlas.region=Rect2(r[0],r[1],r[2],r[3]);icon=atlas
			var stored := HomeGrid.hidden(layout,item.id)
			var index:=list.add_item(item.name,icon);list.set_item_metadata(index,item.id)
			list.set_item_tooltip(index,item.name+(" · 选中后点击摆回房间" if stored else " · 点击选中，Shift 多选"))
			if stored:list.set_item_custom_fg_color(index,Color("7d7770"))
	count_label.text=str(list.item_count)+" 件"
	ignore_list=false;select_items(selected)
	fit.call_deferred()

func refresh(value:Dictionary) -> void:
	if value.get("scene","")!=editor_scene:
		message.text="房间与布局不一致，已阻止加载；请重新打开家具布置";return
	HomeGrid.activate(value)
	# Build an inert preview without moving live furniture, residents or navigation.
	var id:String=HomeGrid.data().scene
	var resolved:=HomeGrid.resolve(value)
	var original_scene:Dictionary=WorldData.scenes[id]
	var original_layers:Dictionary=WorldData.layers[id]
	WorldData.scenes[id]=resolved.scene;WorldData.layers[id]=resolved.manifest
	if is_instance_valid(room):room.free()
	room=Room.new();room.preview_only=true;room.setup(id);stage.add_child(room);room.build();room.visible=true
	WorldData.scenes[id]=original_scene;WorldData.layers[id]=original_layers
	# Editing has neutral illumination; the live game's clock/weather remain authoritative.
	room._floor.visible=false;room._top.visible=false;room._glow.visible=false
	if is_instance_valid(room._weather_ground):room._weather_ground.visible=false
	tint_selection()
	fit();overlay.queue_redraw()

func fit() -> void:
	header.position=Vector2(18,14);header.size=Vector2(size.x-36,maxf(116,header.get_combined_minimum_size().y))
	var top:=header.position.y+header.size.y+12
	sidebar.position=Vector2(18,top);sidebar.size=Vector2(344,size.y-top-18)
	status_panel.position=Vector2(378,size.y-66);status_panel.size=Vector2(size.x-396,48)
	var dimensions:=Vector2(HomeGrid.data().sceneData.width,HomeGrid.data().sceneData.height)
	var factor:=maxf(.1,minf((size.x-412)/dimensions.x,(size.y-top-100)/dimensions.y))
	stage.scale=Vector2(factor,factor)
	stage.position=Vector2(394+(size.x-412-dimensions.x*factor)/2,top+12+(size.y-top-100-dimensions.y*factor)/2)
	map_frame.position=stage.position-Vector2(7,7);map_frame.size=dimensions*factor+Vector2(14,14)
	overlay.queue_redraw()

func world(p:Vector2) -> Vector2:return (p-stage.position)/stage.scale

func hit(p:Vector2) -> String:
	var found:="";var best:=-INF
	var resolved:Dictionary=HomeGrid.resolve(layout)
	for item in HomeGrid.data().catalog:
		if HomeGrid.hidden(layout,item.id):continue
		var r:=HomeGrid.moved_rect(item.box,HomeGrid.delta(layout,item.id))
		var depth:float=HomeGrid.data().sceneData.modules[item.id].depth+HomeGrid.delta(layout,item.id).y
		if item.layer=="surface":
			var m:Dictionary=resolved.scene.modules[item.id]
			r=Rect2(m.x,m.y,m.w,m.h);depth=m.depth
		if item.layer=="floor":depth=-100
		if r.has_point(p) and depth>=best:best=depth;found=item.id
	return found

func select_items(ids:Array) -> void:
	HomeGrid.activate(layout)
	selected=HomeGrid.selection(layout,ids)
	ignore_list=true;list.deselect_all()
	for i in list.item_count:
		if list.get_item_metadata(i) in selected:list.select(i,false)
	ignore_list=false
	tint_selection()
	var grouped:bool=layout.groups.any(func(group):return group.size()==selected.size() and group.all(func(id):return id in selected))
	selection_label.text="还没有选中家具\n点选房间里的家具，或从列表选择。" if selected.is_empty() else ("已组合 · %d 件\n%s" if grouped else "已选 %d 件\n%s") % [selected.size(),"、".join(HomeGrid.data().catalog.filter(func(item):return item.id in selected).map(func(item):return item.name))]
	if selected.size()==1: ## say whether this piece can turn, so R is never a mystery
		selection_label.text+="\n类型："+HomeGrid.Library.label(HomeGrid.catalog_item(selected[0]))
		var why:=HomeGrid.rotation_issue(layout,selected[0])
		selection_label.text+=("\n可以按 R 转向（现在：%s）" % HomeGrid.FACING_NAMES[HomeGrid.facing_of(layout,selected[0])]) if why=="" else ("\n不能转向："+why)
	overlay.queue_redraw()

func tint_selection() -> void:
	if not is_instance_valid(room):return
	var valid:=HomeGrid.validate(candidate if drag else layout)==""
	for id in room.furniture:
		room.furniture[id].modulate=(Color("b3ffcb") if valid else Color("ff868d")) if id in selected else Color.WHITE

func list_selection(_index:int,_value:bool) -> void:
	if ignore_list:return
	if list_mode.selected==0:return
	var ids:Array=[]
	for index in list.get_selected_items():ids.append(list.get_item_metadata(index))
	select_items(ids)

func _input(event:InputEvent) -> void:
	if not layout.is_empty():HomeGrid.activate(layout)
	if close_dialog.visible or library_dialog.visible or is_instance_valid(maker_dialog):return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and (pending_asset != "" or not pending_restore.is_empty()):
		pending_asset="";pending_restore=[];message.text="已取消放置";get_viewport().set_input_as_handled();return
	if embedded and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_F6,KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		if drag:drag=false;refresh(layout)
		else:request_exit()
		return
	if event is InputEventKey and get_viewport().gui_get_focus_owner() is LineEdit:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		# ItemList's built-in multi-selection resets previous groups while emitting
		# per-item callbacks. Use the same explicit toggle as the map before GUI input.
		var scrollbar:=list.get_v_scroll_bar()
		if list.get_global_rect().has_point(event.position) and not (scrollbar.visible and scrollbar.get_global_rect().has_point(event.position)):
			var index:=list.get_item_at_position(event.position-list.global_position,true)
			if index>=0:
				if event.pressed:
					var id:String=list.get_item_metadata(index)
					if id.begins_with("library:"):
						pending_asset=id.trim_prefix("library:");pending_restore=[];list.deselect_all();list.select(index)
						selection_label.text="%s\n点击地图格子放置；Esc 取消" % HomeGrid.Library.all()[pending_asset].name
						message.text="已选择家具，点击地图放置"
					elif event.shift_pressed or event.ctrl_pressed:toggle_selection(id)
					else:select_items([id])
					list.grab_focus()
				get_viewport().set_input_as_handled()
				return
		if event.pressed and Rect2(stage.position,Vector2(HomeGrid.data().sceneData.width,HomeGrid.data().sceneData.height)*stage.scale).has_point(event.position):
			if pending_asset != "" or not pending_restore.is_empty():
				place_pending(Vector2i(((world(event.position)-HomeGrid.grid_origin())/Grid.CELL).floor()));get_viewport().set_input_as_handled();return
			var id:=hit(world(event.position))
			if id=="":select_items([]);return
			if event.shift_pressed:
				toggle_selection(id);return
			if not id in selected:select_items([id])
			drag=true;drag_start=world(event.position);drag_base=layout.duplicate(true);drag_step=Vector2i.ZERO;candidate=layout
		elif not event.pressed and drag:
			drag=false
			if drag_step!=Vector2i.ZERO:commit(candidate,"家具已移动；保存后生效")
			else:refresh(layout)
	elif event is InputEventMouseMotion and drag:
		var step:=Vector2i(((world(event.position)-drag_start)/Grid.CELL).round())
		if step==drag_step:return
		drag_step=step;candidate=HomeGrid.snap_layout(HomeGrid.translate(drag_base,selected,step),selected)
		placement_issue=HomeGrid.validate(candidate)
		message.text="无法放置："+placement_issue if placement_issue!="" else "可以放置 · 松开鼠标确认"
		refresh(candidate)
	elif event is InputEventKey and event.pressed:
		if event.keycode==KEY_ESCAPE and drag:drag=false;refresh(layout);return
		if event.ctrl_pressed and event.keycode==KEY_Z:undo();return
		if event.ctrl_pressed and event.keycode==KEY_S:save_layout();return
		var steps:Dictionary={KEY_LEFT:Vector2i.LEFT,KEY_RIGHT:Vector2i.RIGHT,KEY_UP:Vector2i.UP,KEY_DOWN:Vector2i.DOWN}
		if event.keycode==KEY_R and not event.echo and not event.ctrl_pressed:turn_selected();return
		if steps.has(event.keycode) and not selected.is_empty():commit(HomeGrid.snap_layout(HomeGrid.translate(layout,selected,steps[event.keycode]),selected),"已移动一格")

## R: turn the one selected piece to its next view (HomeGrid facings). Placement is re-checked like a move.
func turn_selected() -> void:
	if not Features.on("furniture-rotation"):message.text="家具转向模块未开启（可让安装 AI 单独启用，或通过 update.cmd 选择）";return
	if selected.size()!=1:message.text="先只选中一件家具再按 R 转向";return
	var id:String=selected[0]
	var issue:=HomeGrid.rotation_issue(layout,id)
	if issue!="":message.text=issue;return
	var turned:=HomeGrid.rotate(layout,id)
	var place:=HomeGrid.validate(turned)
	if place!="":message.text="转不过去："+place+"；先挪到空一点的地方再转";refresh(layout);return
	commit(turned,"已转向："+HomeGrid.FACING_NAMES[HomeGrid.facing_of(turned,id)])

func toggle_selection(id:String) -> void:
	var ids:=selected.duplicate()
	if id in ids:
		for member in HomeGrid.selection(layout,[id]):ids.erase(member)
	else:ids.append(id)
	select_items(ids)

func commit(value:Dictionary,text:String) -> bool:
	var issue:=HomeGrid.validate(value)
	if issue!="":message.text=issue+"；已退回原位置";refresh(layout);return false
	history.append(layout.duplicate(true));if history.size()>60:history.pop_front()
	future.clear();layout=value.duplicate(true);dirty=layout!=saved
	refresh(layout);populate_list();select_items(selected.filter(func(id):return layout.positions.has(id)));message.text=text
	return true

func group_selection() -> void:
	if selected.size()<2:message.text="先按 Shift 选中两件或更多家具";return
	commit(HomeGrid.group_items(layout,selected),"已建立组合，可以整体拖动")

func ungroup_selection() -> void:
	commit(HomeGrid.ungroup(layout,selected),"组合已拆开，现在可以单独选择家具")
	select_items([])

func undo() -> void:
	if history.is_empty():return
	drag=false;future.append(layout.duplicate(true));layout=history.pop_back();dirty=layout!=saved
	refresh(layout);select_items([]);populate_list();message.text="已撤销"

func redo() -> void:
	if future.is_empty():return
	history.append(layout.duplicate(true));layout=future.pop_back();dirty=layout!=saved
	refresh(layout);select_items([]);populate_list();message.text="已重做"

func save_layout() -> void:
	if drag:return
	if layout.get("scene","")!=editor_scene:message.text="房间与布局不一致，未保存";return
	HomeGrid.activate(layout)
	var issue:=HomeGrid.save(layout)
	message.text=issue if issue!="" else "布局已保存，游戏中已生效" if embedded else "布局已保存"
	if issue=="":
		saved=layout.duplicate(true);dirty=false
		saved_layout.emit(layout.duplicate(true))

func request_exit() -> void:
	if dirty:close_dialog.popup_centered()
	else:finish_exit()

func finish_exit() -> void:
	if embedded:exit_requested.emit()
	else:get_tree().quit()

func build_floor_grid() -> void:
	# Uniform 32px grid. Only whole cells count; wall-edge fragments are not placement cells.
	floor_polygons.clear();grid_segments.clear();grid_cells.clear()
	for points in HomeGrid.floor_mask():
		var polygon:=PackedVector2Array()
		for p in points:polygon.append(Vector2(p[0],p[1]))
		floor_polygons.append(polygon)
	var w:int=HomeGrid.data().sceneData.width;var h:int=HomeGrid.data().sceneData.height
	var edges := {}
	var origin := Vector2i(HomeGrid.grid_origin())
	for y in range(origin.y,h,Grid.CELL):
		for x in range(origin.x,w,Grid.CELL):
			var rect := Rect2(x,y,Grid.CELL,Grid.CELL)
			if not HomeGrid.on_floor(rect):continue
			var blocked:=false
			for wall in HomeGrid.wall_list():
				if rect.intersects(Rect2(wall.x,wall.y,wall.w,wall.h)):blocked=true;break
			if blocked:continue
			grid_cells.append(rect)
			# Deduplicate shared edges so all grid lines have the same weight.
			for pair in [[Vector2(x,y),Vector2(x+Grid.CELL,y)],[Vector2(x,y+Grid.CELL),Vector2(x+Grid.CELL,y+Grid.CELL)],[Vector2(x,y),Vector2(x,y+Grid.CELL)],[Vector2(x+Grid.CELL,y),Vector2(x+Grid.CELL,y+Grid.CELL)]]:
				edges[str(pair)] = PackedVector2Array(pair)
	for line in edges.values():grid_segments.append(line)

func floor_lines(a:Vector2,b:Vector2) -> Array[PackedVector2Array]:
	var segments:Array[PackedVector2Array]=[]
	for polygon in floor_polygons:segments.append_array(Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a,b]),polygon))
	return segments

func draw_floor_line(a:Vector2,b:Vector2,color:Color,width:float) -> void:
	for segment in floor_lines(a,b):overlay.draw_polyline(segment,color,width)

func draw_floor_box(rect:Rect2,color:Color) -> void:
	for cell in grid_cells:
		if rect.encloses(cell):
			overlay.draw_rect(cell,Color(color,.25))
			overlay.draw_rect(cell,color,false,2)

func draw_grid() -> void:
	var shown:Dictionary=candidate if drag else layout
	if shown.is_empty():return
	HomeGrid.activate(shown)
	if grid_on:
		for segment in grid_segments:
			overlay.draw_polyline(segment,Color("182c3f99"),2.3)
			overlay.draw_polyline(segment,Color("fff2c6b3"),1)
	var valid:=HomeGrid.validate(shown)==""
	if collision_on:
		for wall in HomeGrid.wall_list():overlay.draw_rect(Rect2(wall.x,wall.y,wall.w,wall.h),Color(1,0.25,0.2,0.30))
		for entry in HomeGrid.data().catalog:
			if entry.layer == "solid" and not HomeGrid.hidden(shown,entry.id):overlay.draw_rect(HomeGrid.moved_rect(entry.foot,HomeGrid.delta(shown,entry.id)),Color(1,0.65,0.1,0.30))
	for item in HomeGrid.data().catalog:
		if not item.id in selected or HomeGrid.hidden(shown,item.id):continue
		var shift:=HomeGrid.delta(shown,item.id)
		var foot:=HomeGrid.moved_rect(item.foot,shift)
		var color:=Color("42f596") if valid else Color("ff525b")
		var origin:=HomeGrid.grid_origin()
		var begin:Vector2=((foot.position-origin)/Grid.CELL).floor()*Grid.CELL+origin
		var end:Vector2=((foot.end-origin)/Grid.CELL).ceil()*Grid.CELL+origin
		var cells:=Rect2(begin,end-begin)
		draw_floor_box(cells,color)
		var caption:="可以放置" if valid else "无法放置"
		var at:=Vector2(cells.position.x,cells.position.y-8)
		overlay.draw_rect(Rect2(at+Vector2(-3,-17),Vector2(88,23)),Color("172638ed"))
		overlay.draw_string(ThemeDB.fallback_font,at,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,18,color)
		var resolved:Dictionary=HomeGrid.resolve(shown)
		for z in item.zoneIds:
			var point:=Vector2(resolved.scene.zones[z].x,resolved.scene.zones[z].y)
			overlay.draw_circle(point,4,Color("7bd8ff"));overlay.draw_line(foot.get_center(),point,Color("7bd8ff"),1)

func _notification(what:int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and not embedded:request_exit()

func store_selection() -> void:
	var ids := selected.filter(func(id):return not HomeGrid.hidden(layout,id))
	if ids.is_empty():message.text="先选中房间里要收起的家具";return
	if commit(HomeGrid.store_items(layout,ids),"已收起选中家具；可从列表选中后摆回，也可撤销"):
		list_mode.select(2);populate_list();select_items(ids)

func restore_selection() -> void:
	pending_restore = selected.filter(func(id):return HomeGrid.hidden(layout,id))
	if pending_restore.is_empty():message.text="先在列表选择带 [已收起] 标记的家具";return
	pending_asset="";message.text="点击格子摆回选中家具 · Esc 取消"

func build_library_dialog() -> void:
	add_child(library_dialog);library_dialog.title="全部家具库";library_dialog.size=Vector2i(720,600)
	library_dialog.ok_button_text="选择后在地图上放置"
	var confirm := library_dialog.get_ok_button()
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color","font_disabled_color"]:confirm.add_theme_color_override(state,Hud.INK)
	for state in ["normal","hover","pressed"]:confirm.add_theme_stylebox_override(state,box(Hud.PAPER_H,Hud.WOOD,2,8))
	var column := VBoxContainer.new();library_dialog.add_child(column)
	library_search.placeholder_text="搜索家具名称…";library_search.text_changed.connect(func(_v):fill_library());column.add_child(library_search)
	library_source.add_item("全部来源")
	for asset in HomeGrid.Library.all().values():
		if asset.scene not in library_scenes:
			library_scenes.append(asset.scene);library_source.add_item(asset.scene_name)
	library_source.item_selected.connect(func(_v):fill_library());column.add_child(library_source)
	library_list.custom_minimum_size=Vector2(660,420);library_list.size_flags_vertical=Control.SIZE_EXPAND_FILL
	library_list.fixed_icon_size=Vector2i(56,56);column.add_child(library_list)
	library_dialog.confirmed.connect(choose_library)
	library_list.item_activated.connect(func(_i):choose_library();library_dialog.hide())

func open_library() -> void:
	pending_asset="";pending_restore=[];fill_library();library_dialog.title="全部家具库 · %d 件" % HomeGrid.Library.all().size();library_dialog.popup_centered()

func fill_library() -> void:
	library_list.clear()
	var sources := library_scenes
	for a in HomeGrid.Library.all().values():
		if library_source.selected>0 and a.scene!=sources[library_source.selected]:continue
		if library_search.text!="" and not (str(a.name)+str(a.scene_name)).contains(library_search.text):continue
		var icon:Texture2D=null
		var path := ("res://assets/baked/"+str(a.layers[0].file)).simplify_path()
		icon=HomeGrid.Library.icon(path)
		if icon!=null and a.layers[0].has("region"):
			var atlas:=AtlasTexture.new();atlas.atlas=icon
			var r:Array=a.layers[0].region;atlas.region=Rect2(r[0],r[1],r[2],r[3]);icon=atlas
		var index:=library_list.add_item("[%s] %s · %s · %d×%d 格" % [HomeGrid.Library.label(a),a.name,a.scene_name,a.footprint.w,a.footprint.h],icon)
		library_list.set_item_metadata(index,a.id)
		library_list.set_item_tooltip(index,"家具库复制品只有明确配置的功能；装饰不会自动继承原件的工具。占地与图片高度分离。")

func function_matches(item:Dictionary)->bool:
	var functional:bool=HomeGrid.Library.label(item)!="装饰"
	return function_filter.selected==0 or (function_filter.selected==1 and functional) or (function_filter.selected==2 and not functional)

func open_maker()->void:
	maker_dialog=load("res://ui/furniture_maker.gd").new();maker_dialog.theme=theme
	maker_dialog.created.connect(func(asset:String):
		populate_list();pending_asset=asset;pending_restore=[]
		message.text="家具已制作好，点击格子放置；保存布置后生效")
	add_child(maker_dialog)

func choose_library() -> void:
	var chosen := library_list.get_selected_items()
	if chosen.is_empty():return
	pending_asset=library_list.get_item_metadata(chosen[0]);pending_restore=[]
	message.text="点击格子放置「%s」· Esc 取消" % HomeGrid.Library.all()[pending_asset].name

func place_pending(cell:Vector2i) -> void:
	var value:=layout.duplicate(true)
	var ids:Array=[]
	if pending_asset!="":
		if not value.has("instances"):value.instances={}
		var n:=1
		while value.positions.has("placed_%d" % n):n+=1
		var id:="placed_%d" % n
		value.instances[id]=pending_asset;value.positions[id]=[cell.x,cell.y];ids=[id]
		if not value.has("offsets"):value.offsets={}
		var origin:=HomeGrid.grid_origin();value.offsets[id]=[origin.x,origin.y]
	else:
		ids=pending_restore.duplicate()
		var first:Array=value.positions[ids[0]]
		var step:=cell-Vector2i(first[0],first[1])
		value=HomeGrid.translate(value,ids,step)
		value.stored=value.stored.filter(func(id):return not id in ids)
		value=HomeGrid.snap_layout(value,ids)
	if commit(value,"家具已放入；保存布置后生效"):
		pending_asset="";pending_restore=[];select_items(ids)
