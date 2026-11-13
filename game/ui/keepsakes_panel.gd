extends Window
## Local owner controls. These actions do not send QQ messages or call a model.
var actor:OptionButton
var room:OptionButton
var kind:OptionButton
var product:OptionButton
var message:LineEdit
var status:Label
var fish:OptionButton
var fish_name:LineEdit
var fish_action:Button
var books:OptionButton
var paintings:OptionButton
var progress:Label
var birthday:LineEdit
var ids:Array=[]
var rooms:Array=[]
var products:Array=[]
const Keepsakes=preload("res://core/keepsakes.gd")
func _ready()->void:
	title="小屋纪念册";size=Vector2i(660,700);min_size=Vector2i(560,520);transient=true;exclusive=true
	var palette:=Theme.new();var font:=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei","SimHei"]);palette.default_font=font;palette.default_font_size=16
	for type_of in ["Label","Button","OptionButton","LineEdit"]:
		for name_of in ["font_color","font_hover_color","font_pressed_color"]:palette.set_color(name_of,type_of,Hud.INK)
		palette.set_color("font_placeholder_color",type_of,Hud.INK2)
	for type_of in ["Button","OptionButton","LineEdit"]:
		for name_of in ["normal","hover","pressed","focus"]:
			var style:=StyleBoxFlat.new();style.bg_color=Hud.PAPER_H if name_of=="normal" else Hud.PAPER_D;style.border_color=Hud.WOOD;style.set_border_width_all(2);style.content_margin_left=8;style.content_margin_right=8;style.content_margin_top=5;style.content_margin_bottom=5;palette.set_stylebox(name_of,type_of,style)
	theme=palette
	var backdrop:=ColorRect.new();backdrop.color=Hud.PAPER;backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(backdrop)
	close_requested.connect(queue_free)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,18)
	add_child(margin)
	var scroll:=ScrollContainer.new();margin.add_child(scroll)
	var body:=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",10);scroll.add_child(body)
	status=label(body,"");status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	actor=OptionButton.new();body.add_child(actor)
	for resident in Residents.people():actor.add_item(resident.name);ids.append(resident.key)
	actor.item_selected.connect(func(_index):refresh())
	label(body,"留一份心意 · 她走进房间后才会发现")
	room=OptionButton.new();body.add_child(room)
	for id in WorldData.scenes:room.add_item(WorldData.scenes[id].name);rooms.append(id)
	kind=OptionButton.new();body.add_child(kind)
	for name_of in ["留言","礼物（等她自己决定是否收下）","小请求（不强制执行）"]:kind.add_item(name_of)
	message=LineEdit.new();message.placeholder_text="写给她的话（最多 120 字）";message.max_length=120;body.add_child(message)
	product=OptionButton.new();body.add_child(product)
	for id in Economy.catalog:product.add_item(str(Economy.catalog[id].name));products.append(id)
	product.visible=false;kind.item_selected.connect(func(index):product.visible=index==1)
	button(body,"放在这个房间",func():
		var args:Dictionary={"use":"owner_post","scene":rooms[room.selected],"kind":["note","gift","request"][kind.selected],"feeling":message.text,"item":products[product.selected] if not products.is_empty() else ""}
		if commit(args):message.clear())
	separator(body);label(body,"长期目标")
	progress=label(body,"")
	var row:=HBoxContainer.new();body.add_child(row)
	for id in Keepsakes.data().goals:
		var key:String=id
		button(row,str(Keepsakes.data().goals[id].name),func():commit({"use":"goal","item":key}))
	button(body,"攒够后买下相框 · 60 元",func():commit({"use":"claim_frame"}))
	separator(body);label(body,"家中的小纪念 · 回到自己家后可操作")
	fish=OptionButton.new();body.add_child(fish)
	var fish_names:Array=["小丑鱼","蓝吊鱼","孔雀鱼","金鱼","斗鱼","小鲸鱼玩偶"]
	for name_of in fish_names:fish.add_item(name_of)
	fish_name=LineEdit.new();fish_name.max_length=12;fish_name.placeholder_text="给这条鱼取个名字";body.add_child(fish_name)
	fish_action=button(body,"记住鱼的名字",func():commit({"use":"name_fish","item":Keepsakes.data().fish[fish.selected],"feeling":fish_name.text}))
	books=OptionButton.new();body.add_child(books)
	books.add_theme_constant_override("icon_max_width",24)
	for topic in Keepsakes.data().books:
		var cover:String="res://assets/books/cover-"+str(topic)+".png"
		if ResourceLoader.exists(cover):books.add_icon_item(load(cover),Keepsakes.data().books[topic])
		else:books.add_item(Keepsakes.data().books[topic])
	button(body,"挑选下次阅读主题",func():commit({"use":"read_topic","item":Keepsakes.data().books.keys()[books.selected]}))
	paintings=OptionButton.new();body.add_child(paintings)
	for slot in 2:
		var position_of:int=slot
		button(body,"挂到墙上 · 位置 "+str(slot+1),func():
			if paintings.item_count>0:commit({"use":"hang_painting","item":paintings.get_item_metadata(paintings.selected),"slot":position_of}))
	separator(body);label(body,"生日装饰 · 只使用你填写的日期")
	birthday=LineEdit.new();birthday.max_length=5;birthday.placeholder_text="MM-DD，例如 06-18；留空清除";body.add_child(birthday)
	button(body,"保存生日日期",func():commit({"use":"birthday","item":birthday.text}))
	refresh();popup_centered()
func label(parent:Node,text:String)->Label:
	var result:=Label.new();result.text=text;parent.add_child(result);return result
func button(parent:Node,text:String,callback:Callable)->Button:
	var result:=Button.new();result.text=text;result.pressed.connect(callback);parent.add_child(result);return result
func separator(parent:Node)->void:parent.add_child(HSeparator.new())
func commit(args:Dictionary)->bool:
	if ids.is_empty():return false
	var request:Dictionary=args.merged({"id":"owner-"+str(Time.get_unix_time_from_system())+"-"+str(Time.get_ticks_usec()),"actor":ids[actor.selected],"op":"keepsake"})
	var result:Dictionary=Economy.answer(request)
	status.text=str(result.get("note","已保存")) if result.ok else str(result.get("error","没有保存成功"))
	var scroll:ScrollContainer=status.get_parent().get_parent();scroll.scroll_vertical=0
	refresh();return result.ok
func refresh()->void:
	if ids.is_empty():return
	var key:String=ids[actor.selected];var s:Dictionary=Economy.people.get(key,{})
	birthday.text=str(s.get("keepsakes",{}).get("birthday",""))
	var has_fish:bool=Keepsakes.has_aquarium(key)
	fish_action.disabled=not has_fish;fish.disabled=not has_fish;fish_name.editable=has_fish
	fish_action.text="记住鱼的名字" if has_fish else "她的小屋还没有鱼缸"
	var goal:Dictionary=Keepsakes.progress(s,key)
	progress.text="还没有选长期目标" if goal.is_empty() else "%s：%s / %s%s"%[goal.name,goal.have,goal.need," · 已达成" if goal.done else ""]
	paintings.clear()
	for painting in Keepsakes.state(s).paintings:
		paintings.add_item(str({"sea":"海边","park":"公园","flowers":"花朵","cat":"小猫","stars":"星空","portrait":"小鲸鱼"}.get(painting.motif,painting.motif))+" · "+Time.get_date_string_from_unix_time(int(painting.at/1000)+28800))
		paintings.set_item_metadata(paintings.item_count-1,painting.id)
