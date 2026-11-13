extends AcceptDialog
const Registry=preload("res://core/resident_registry.gd")
var people:OptionButton
var maps:OptionButton
var notice:Label
var key_field:LineEdit
var name_field:LineEdit
var home_field:LineEdit
var delete_dialog:=ConfirmationDialog.new()
var delete_key:=""
var keys:Array=[]
var map_ids:Array=[]
func _ready()->void:
	title="机器人与房间";min_size=Vector2i(600,600)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",12);add_child(box)
	var help:=Label.new();help.text="每位机器人有独立编号、房间与生活存档。\n新增后，在机器人软件的工具调用中传入相同编号即可接入。";box.add_child(help)
	key_field=LineEdit.new();key_field.placeholder_text="机器人编号，例如 bot_2（保存后不变）";box.add_child(key_field)
	name_field=LineEdit.new();name_field.placeholder_text="显示名字（可以随时修改）";name_field.max_length=32;box.add_child(name_field)
	var add:=Button.new();add.text="新增机器人 · 分配小鲸鱼同款独立房间";add.pressed.connect(_add);box.add_child(add)
	box.add_child(HSeparator.new())
	people=OptionButton.new();box.add_child(people)
	var rename:=Button.new();rename.text="将选中住户改为上方填写的名字";rename.pressed.connect(func():
		if keys.is_empty():return
		var r:Dictionary=Registry.Personal.accept({"actor":keys[people.selected],"action":"rename","name":name_field.text})
		notice.text="名字已保存" if r.ok else str(r.error)
		if r.ok:VadsLink.send({"type":"resident.changed","actor":keys[people.selected]})
		_refresh())
	box.add_child(rename)
	home_field=LineEdit.new();home_field.placeholder_text="房屋名称，例如 听潮小筑（不改变机器人名字）";home_field.max_length=32;box.add_child(home_field)
	var rename_home:=Button.new();rename_home.text="修改选中住户的房屋名称";rename_home.pressed.connect(func():
		if keys.is_empty():return
		_result(Registry.accept({"action":"rename_home","actor":keys[people.selected],"name":home_field.text})))
	box.add_child(rename_home)
	maps=OptionButton.new();box.add_child(maps)
	var assign:=Button.new();assign.text="使用选中的房间";assign.pressed.connect(_assign);box.add_child(assign)
	var remove:=Button.new();remove.text="删除选中的机器人及私人房间…";remove.pressed.connect(func():
		if keys.is_empty():return
		delete_key=keys[people.selected]
		delete_dialog.dialog_text="删除「"+Registry.describe(delete_key).name+"」及其私人房间？\n恢复资料会保留，其他机器人与原地图模板不受影响。\n请先结束活动，并让访客离开。"
		delete_dialog.popup_centered())
	box.add_child(remove);add_child(delete_dialog);delete_dialog.title="删除机器人与房屋"
	delete_dialog.confirmed.connect(func():
		var r:Dictionary=Registry.accept({"action":"remove","actor":delete_key})
		notice.text=r.get("note","") if r.ok else r.error
		if r.ok:VadsLink.send({"type":"resident.changed","actor":delete_key,"removed":true})
		_refresh())
	notice=Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.text="先在地图编辑器保存室内地图，再到这里选择。入住后入口接到公园；换房前请让所有人离开该房间。";box.add_child(notice)
	_refresh();popup_centered();confirmed.connect(queue_free);canceled.connect(queue_free)
func _refresh()->void:
	people.clear();keys=[]
	for p in Residents.people():
		if Registry.rows.has(p.key):people.add_item(p.name+" · "+Registry.describe(p.key).homeName+" · "+p.key);keys.append(p.key)
	maps.clear();maps.add_item("默认房间 · 小鲸鱼同款");map_ids=[""]
	for m in Registry.maps():maps.add_item(m.name+" · "+m.id);map_ids.append(m.id)
func _result(r:Dictionary)->void:
	notice.text="已保存并更新房间" if r.ok else str(r.error)
	if r.ok:
		VadsLink.send({"type":"resident.changed","actor":r.resident.key})
		_refresh()
func _add()->void:
	_result(Registry.accept({"action":"register","actor":key_field.text.strip_edges(),"name":name_field.text.strip_edges()}))
func _assign()->void:
	if keys.is_empty():notice.text="请先新增一位机器人";return
	_result(Registry.accept({"action":"room","actor":keys[people.selected],"mapId":map_ids[maps.selected]}))
