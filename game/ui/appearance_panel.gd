extends Window
const Packs=preload("res://core/appearance_packs.gd")
var resident:=OptionButton.new()
var appearance:=OptionButton.new()
var note:=Label.new()
var rows:Array=[]

func _ready()->void:
	title="角色外观与动作包";size=Vector2i(560,340);unresizable=true
	close_requested.connect(queue_free)
	var box:=VBoxContainer.new();add_child(box);box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left=24;box.offset_right=-24;box.offset_top=24;box.offset_bottom=-24
	var label:=Label.new();label.text="同一个机器人，可以切换不同的外观和动作。";box.add_child(label)
	box.add_child(resident)
	for r in Residents.people():resident.add_item(str(r.get("name",r.key)));resident.set_item_metadata(resident.item_count-1,str(r.key))
	box.add_child(appearance);rows=Packs.choices();appearance.add_item("原版外观")
	for p in rows:appearance.add_item(p.name)
	var apply:=Button.new();apply.text="应用外观";box.add_child(apply)
	box.add_child(note);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	note.text="外部 ZIP、GIF 和 PNG 请在角色工坊导入、审核，然后使用“小屋世界”发送。未提供的动作继续使用原版。"
	var open:=Button.new();open.text="打开外观文件夹";box.add_child(open)
	open.pressed.connect(func():OS.shell_open(ProjectSettings.globalize_path(Packs.directory())))
	apply.pressed.connect(func():
		if resident.selected<0:return
		var id:String="" if appearance.selected==0 else rows[appearance.selected-1].id
		var err:=Packs.select(str(resident.get_item_metadata(resident.selected)),id)
		note.text="已切换。机器人、人设、记忆和家保持不变。" if err==OK else "保存失败，请检查文件夹权限。")
	resident.item_selected.connect(func(_i):_selection())
	_selection()

func _selection()->void:
	Packs.refresh();appearance.select(0)
	if resident.selected<0:return
	var id:String=str(Packs._selected.get(str(resident.get_item_metadata(resident.selected)),""))
	for i in rows.size():
		if rows[i].id==id:appearance.select(i+1)
