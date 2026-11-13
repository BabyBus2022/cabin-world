extends AcceptDialog
const Grid=preload("res://core/world_grid.gd")
signal created(asset:String)
const Made=preload("res://core/furniture_maker.gd")
const NAMES={"S":"正面","W":"左侧","N":"背面","E":"右侧"}
var title_field:=LineEdit.new()
var id_field:=LineEdit.new()
var width_field:=SpinBox.new()
var depth_field:=SpinBox.new()
var ppu:=SpinBox.new()
var rotate_box:=CheckButton.new()
var operation_mode:=OptionButton.new()
var actor:=OptionButton.new()
var actors:Array=[]
var action_name:=LineEdit.new()
var description:=LineEdit.new()
var seconds:=SpinBox.new()
var frames:=SpinBox.new()
var fps:=SpinBox.new()
var pose_scale:=SpinBox.new()
var face_select:=OptionButton.new()
var rows:Dictionary={}
var images:Dictionary={}
var preview_textures:Dictionary={}
var preview:=Control.new()
var notice:=Label.new()
var action_box:=VBoxContainer.new()
var picker:=FileDialog.new()
var picking:=""
func label(parent:Node,text:String)->void:
	var l:=Label.new();l.text=text;parent.add_child(l)
func spin(parent:Node,s:SpinBox,lo:float,hi:float,value:float,step:float=1)->void:
	s.min_value=lo;s.max_value=hi;s.step=step;s.value=value;s.custom_minimum_size.x=82;parent.add_child(s);s.value_changed.connect(func(_v):preview.queue_redraw())
func button(parent:Node,text:String,fn:Callable)->Button:
	var b:=Button.new();b.text=text;b.pressed.connect(fn);parent.add_child(b);return b
var steps:Array=[]
var pages:Array=[]
var step_index:=0
var next_button:Button
var back_button:Button
var advance:=VBoxContainer.new()
var direction_buttons:Dictionary={}
var art_thumbs:Dictionary={}
var pose_thumbs:Dictionary={}
var count_hint:=Label.new()
var footprint_hint:=Label.new()
var no_action:=Label.new()
var advance_toggle:=CheckButton.new()
var preview_time:=0.0
const PAPER=Color("f7efde")
const CARD=Color("fffaf0")
const INK=Color("493c30")
const MUTED=Color("897762")
const BLUE=Color("426b87")
func style(fill:Color,border:Color,pad:int=10)->StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=fill;s.border_color=border;s.set_border_width_all(1);s.set_content_margin_all(pad);s.set_corner_radius_all(4);return s
func make_theme()->Theme:
	var t:=Theme.new();t.default_font_size=18
	var font:=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei"]);t.default_font=font
	for kind in ["Label","Button","OptionButton","CheckButton","LineEdit","SpinBox","PopupMenu"]:
		for state in ["font_color","font_hover_color","font_pressed_color","font_selected_color"]:t.set_color(state,kind,INK)
		t.set_color("font_placeholder_color",kind,MUTED)
	for kind in ["Button","OptionButton","LineEdit"]:
		t.set_stylebox("normal",kind,style(CARD,Color("d9cbb3")))
		t.set_stylebox("hover",kind,style(Color("f0e4ce"),Color("b5a07d")))
		t.set_stylebox("pressed",kind,style(Color("dde7e8"),BLUE))
		t.set_stylebox("focus",kind,style(Color(0,0,0,0),BLUE))
	var window:=style(PAPER,Color("95734e"),16);window.border_width_top=34
	t.set_stylebox("embedded_border","Window",window);t.set_stylebox("embedded_unfocused_border","Window",window)
	t.set_color("title_color","Window",Color("fff8e7"));t.set_color("title_outline_modulate","Window",Color(0,0,0,0))
	t.set_stylebox("panel","PopupMenu",style(CARD,Color("b5a07d")))
	t.set_stylebox("panel","AcceptDialog",style(PAPER,PAPER,10))
	return t
func heading(parent:Node,text:String,sub:String)->void:
	var h:=Label.new();h.text=text;h.add_theme_font_size_override("font_size",24);parent.add_child(h)
	var l:=Label.new();l.text=sub;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.add_theme_color_override("font_color",MUTED);parent.add_child(l)
func upload_card(parent:Node,face:String,kind:String)->Dictionary:
	var card:=PanelContainer.new();card.add_theme_stylebox_override("panel",style(CARD,Color("dfd1ba"),12));parent.add_child(card)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",8);card.add_child(box)
	label(box,NAMES[face]+("家具图" if kind=="art" else "动作图"))
	var thumb:=TextureRect.new();thumb.custom_minimum_size=Vector2(156,100);thumb.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;thumb.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;thumb.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;box.add_child(thumb)
	var b:=button(box,"＋ 选择PNG",func():pick(face+"_"+kind));b.clip_text=true;b.custom_minimum_size=Vector2(156,40)
	return {"card":card,"button":b,"thumb":thumb}
func _ready()->void:
	theme=make_theme();title="小屋世界 · 家具工坊";size=Vector2i(1080,650);min_size=Vector2i(920,560);ok_button_text="完成 · 放入家具库";dialog_hide_on_ok=false
	var root:=VBoxContainer.new();root.add_theme_constant_override("separation",10);add_child(root)
	heading(root,"制作一件新家具","放进自己的小屋，也让机器人知道怎么使用它。")
	var nav:=HFlowContainer.new();nav.add_theme_constant_override("h_separation",8);root.add_child(nav)
	var names:=["01  基本设置","02  家具图片","03  机器人动作"]
	for i in 3:
		var b:=button(nav,names[i],func():show_step(i));b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.custom_minimum_size.y=42;steps.append(b)
	button(nav,"检查现有家具",func():var inspector=load("res://ui/furniture_inspector.gd").new();inspector.theme=theme;add_child(inspector))
	var body:=HBoxContainer.new();body.add_theme_constant_override("separation",24);body.size_flags_vertical=Control.SIZE_EXPAND_FILL;root.add_child(body)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(410,220);scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(scroll)
	var form:=VBoxContainer.new();form.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(form)
	for i in 3:
		var page:=VBoxContainer.new();page.add_theme_constant_override("separation",12);form.add_child(page);pages.append(page)
	heading(pages[0],"先认识这件家具","名字、占地和使用方式，先定下来。")
	label(pages[0],"家具名称")
	title_field.placeholder_text="例如：海蓝色的小沙发";title_field.max_length=40;pages[0].add_child(title_field)
	label(pages[0],"正面占地（格）")
	var dimensions:=HBoxContainer.new();dimensions.add_theme_constant_override("separation",12);pages[0].add_child(dimensions)
	spin(dimensions,width_field,1,8,2);label(dimensions,"×");spin(dimensions,depth_field,1,8,2)
	footprint_hint.add_theme_color_override("font_color",MUTED);pages[0].add_child(footprint_hint)
	rotate_box.text="支持旋转 · 前、后、左、右四个方向";pages[0].add_child(rotate_box)
	label(pages[0],"家具用途")
	for text in ["装饰 · 只摆放，不使用","互动 · 播放机器人动作","互动 · 由机器人软件执行功能"]:operation_mode.add_item(text)
	pages[0].add_child(operation_mode)
	var explain:=Label.new();explain.text="互动家具需要配好人物动作图。涉及真实读写或设备操作时，选择由机器人软件执行。";explain.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;explain.add_theme_color_override("font_color",MUTED);pages[0].add_child(explain)
	id_field.text="furniture_"+str(Time.get_unix_time_from_system()).replace(".","_");id_field.max_length=48
	heading(pages[1],"为家具配上图片","不旋转只需正面；支持旋转就配齐四张。")
	var art_grid:=GridContainer.new();art_grid.columns=2;art_grid.add_theme_constant_override("h_separation",12);art_grid.add_theme_constant_override("v_separation",12);pages[1].add_child(art_grid)
	for face in Made.FACES:
		var art:=upload_card(art_grid,face,"art");art_thumbs[face]=art.thumb
		rows[face]={"box":art.card,"art":art.button}
	count_hint.add_theme_color_override("font_color",MUTED);pages[1].add_child(count_hint)
	var density:=HBoxContainer.new();pages[1].add_child(density);label(density,"图片比例");spin(density,ppu,.25,8,2,.25);label(density,"默认 2 即可")
	var hint:=Label.new();hint.text="每格32游戏像素；默认素材每格64像素。四个方向统一缩放，不压扁、不拉长。";hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hint.add_theme_color_override("font_color",MUTED);pages[1].add_child(hint)
	heading(pages[2],"让机器人用起来","按当前预览方向上传动作，检查人物与家具贴合。")
	no_action.text="这是一件装饰家具，无需机器人动作。
检查右侧预览后，即可放入家具库。";no_action.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;pages[2].add_child(no_action)
	pages[2].add_child(action_box);action_box.add_theme_constant_override("separation",10)
	label(action_box,"谁来使用")
	for person in Residents.people():actor.add_item(person.name);actors.append(person.key)
	action_box.add_child(actor)
	action_name.placeholder_text="动作名称，例如：坐着休息";action_box.add_child(action_name)
	description.placeholder_text="简单描述这个动作或功能";action_box.add_child(description)
	for face in Made.FACES:
		var pose:=upload_card(action_box,face,"pose");pose_thumbs[face]=pose.thumb;rows[face].pose=pose.button;rows[face].pose_card=pose.card
	advance_toggle.text="精细调整 · 动画、大小与脚底位置";action_box.add_child(advance_toggle);action_box.add_child(advance);advance.visible=false
	advance_toggle.toggled.connect(func(on):advance.visible=on)
	var timing:=HBoxContainer.new();advance.add_child(timing);label(timing,"秒数");spin(timing,seconds,1,60,5);label(timing,"横排帧数");spin(timing,frames,1,16,1)
	var scaling:=HBoxContainer.new();advance.add_child(scaling);label(scaling,"每秒帧");spin(scaling,fps,1,16,4);label(scaling,"人物比例");spin(scaling,pose_scale,.05,4,.5,.05)
	for face in Made.FACES:
		var align:=VBoxContainer.new();advance.add_child(align)
		var fline:=HBoxContainer.new();align.add_child(fline);label(fline,"人物脚底 X / Y")
		var fx:=SpinBox.new();var fy:=SpinBox.new();spin(fline,fx,-256,512,Grid.CELL);spin(fline,fy,-256,512,84)
		var aline:=HBoxContainer.new();align.add_child(aline);label(aline,"图内脚底 X / Y")
		var ax:=SpinBox.new();var ay:=SpinBox.new();spin(aline,ax,0,2048,0);spin(aline,ay,0,2048,0)
		rows[face].merge({"align":align,"fx":fx,"fy":fy,"ax":ax,"ay":ay})
	button(advance,"重置站位到家具外侧",reset_feet)
	label(advance,"家具编号（自动生成，可修改）");advance.add_child(id_field)
	var right:=VBoxContainer.new();right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;right.add_theme_constant_override("separation",12);body.add_child(right)
	var top:=HBoxContainer.new();right.add_child(top);label(top,"实时预览")
	var gap:=Control.new();gap.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(gap)
	var note:=Label.new();note.text="绿框：占地";note.add_theme_color_override("font_color",MUTED);top.add_child(note)
	var dirs:=HBoxContainer.new();dirs.add_theme_constant_override("separation",6);right.add_child(dirs)
	for face in Made.FACES:
		face_select.add_item(NAMES[face]);var b:=button(dirs,NAMES[face],func():face_select.select(Made.FACES.find(face));update_form());b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;direction_buttons[face]=b
	face_select.visible=false;right.add_child(face_select)
	preview.custom_minimum_size=Vector2(380,180);preview.clip_contents=true;preview.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;preview.size_flags_vertical=Control.SIZE_EXPAND_FILL;right.add_child(preview);preview.draw.connect(draw_preview);preview.resized.connect(func():preview.queue_redraw())
	var preview_hint:=Label.new();preview_hint.text="选好图片后可切换方向检查。图片保持原比例，
人物大小与脚底位置可在「精细调整」中修改。";preview_hint.add_theme_color_override("font_color",MUTED);preview_hint.add_theme_font_size_override("font_size",20);right.add_child(preview_hint)
	preview_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;preview_hint.add_theme_font_size_override("font_size",16)
	notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.custom_minimum_size=Vector2(380,42);notice.add_theme_color_override("font_color",Color("9a5639"));right.add_child(notice)
	back_button=add_button("上一步",false,"back");next_button=add_button("下一步  →",true,"next")
	custom_action.connect(func(a):show_step(step_index+(-1 if a=="back" else 1)))
	for b in [get_ok_button(),next_button]:
		b.custom_minimum_size=Vector2(180,42)
		for state in ["normal","hover","pressed"]:b.add_theme_stylebox_override(state,style(BLUE if state=="normal" else Color("537f9a"),BLUE))
		for state in ["font_color","font_hover_color","font_pressed_color"]:b.add_theme_color_override(state,Color("fff9ed"))
	add_child(picker);picker.access=FileDialog.ACCESS_FILESYSTEM;picker.file_mode=FileDialog.FILE_MODE_OPEN_FILE;picker.filters=PackedStringArray(["*.png ; PNG图片"]);picker.file_selected.connect(selected_file)
	rotate_box.toggled.connect(func(_v):update_form());operation_mode.item_selected.connect(func(_v):update_form())
	width_field.value_changed.connect(func(_v):reset_feet();update_form());depth_field.value_changed.connect(func(_v):reset_feet();update_form())
	confirmed.connect(save_asset);canceled.connect(queue_free);close_requested.connect(queue_free)
	reset_feet();show_step(0)
	await get_tree().process_frame
	var available:Vector2=get_parent().get_viewport().get_visible_rect().size
	var desired:=Vector2i(minf(1160,available.x*.92),minf(700,available.y*.88))
	popup_centered(desired)
	# Autowrapped labels briefly measure at width 1 before container layout.
	# Refit after layout so that transient height never becomes the window size.
	await get_tree().process_frame
	await get_tree().process_frame
	size=desired;position=Vector2i((available-Vector2(size))/2)
func show_step(index:int)->void:
	step_index=clampi(index,0,2)
	for i in 3:
		pages[i].visible=i==step_index
		steps[i].add_theme_stylebox_override("normal",style(Color("dde7e8") if i==step_index else CARD,BLUE if i==step_index else Color("dfd1ba")))
	back_button.disabled=step_index==0;next_button.visible=step_index<2;get_ok_button().visible=step_index==2
	update_form()
func _process(delta:float)->void:
	preview_time+=delta
	if frames.value>1 and operation_mode.selected>0:preview.queue_redraw()
func reset_feet()->void:
	var w:=width_field.value*Grid.CELL;var h:=depth_field.value*Grid.CELL
	var points:={"S":Vector2(w/2,h+20),"W":Vector2(-20,w/2),"N":Vector2(w/2,-20),"E":Vector2(h+20,w/2)}
	for face in rows:rows[face].fx.value=points[face].x;rows[face].fy.value=points[face].y
func update_form()->void:
	action_box.visible=operation_mode.selected>0;no_action.visible=operation_mode.selected==0
	if not rotate_box.button_pressed:face_select.select(0)
	var current:String=Made.FACES[face_select.selected]
	var count:=0
	for face in rows:
		var enabled:bool=face=="S" or rotate_box.button_pressed
		rows[face].box.visible=enabled
		rows[face].pose_card.visible=enabled and face==current
		rows[face].align.visible=enabled and face==current
		direction_buttons[face].disabled=not enabled
		direction_buttons[face].add_theme_stylebox_override("normal",style(Color("dde7e8") if face==current else CARD,BLUE if face==current else Color("dfd1ba")))
		art_thumbs[face].texture=preview_textures.get(face+"_art");pose_thumbs[face].texture=preview_textures.get(face+"_pose")
		if enabled and images.has(face+"_art"):count+=1
	count_hint.text="家具图片 %d / %d 已就绪" % [count,4 if rotate_box.button_pressed else 1]
	footprint_hint.text="正面 %d×%d 格%s" % [width_field.value,depth_field.value,"  ·  转向后 %d×%d 格" % [depth_field.value,width_field.value] if rotate_box.button_pressed else "  ·  固定朝向"]
	preview.queue_redraw()
func pick(key:String)->void:
	picking=key;picker.popup_centered_ratio(.75)
func selected_file(path:String)->void:
	var f:=FileAccess.open(path,FileAccess.READ)
	if f==null or f.get_length()>4*1024*1024:notice.text="图片无法读取或超过4MB";return
	var bytes:=f.get_buffer(f.get_length());f.close()
	var d:=Made.png(bytes)
	if d.has("error"):notice.text=d.error;return
	images[picking]=bytes
	var img:=Image.new();img.load_png_from_buffer(bytes);preview_textures[picking]=ImageTexture.create_from_image(img)
	var face:=picking.substr(0,1);var kind:=picking.substr(2)
	rows[face]["art" if kind=="art" else "pose"].text=path.get_file().left(21)
	rows[face]["art" if kind=="art" else "pose"].tooltip_text=path
	if kind=="pose":rows[face].ax.value=float(d.w)/frames.value/2;rows[face].ay.value=d.h
	notice.text="图片已选好，保存后会复制进家具素材目录。";update_form()
func specification()->Dictionary:
	var views:Dictionary={};var poses:Dictionary={}
	for face in (Made.FACES if rotate_box.button_pressed else ["S"]):
		views[face]={"image":face+"_art"}
		var r:Dictionary=rows[face]
		poses[face]={"image":face+"_pose","frames":int(frames.value),"fps":fps.value,"scale":pose_scale.value,"anchor":[r.ax.value,r.ay.value],"feet":[r.fx.value,r.fy.value]}
	var actions:=[]
	if operation_mode.selected>0 and not actors.is_empty():actions.append({"id":"use","name":action_name.text.strip_edges(),"description":description.text.strip_edges(),"mode":"activity" if operation_mode.selected==1 else "external","seconds":seconds.value,"poses":{actors[actor.selected]:poses}})
	return {"id":id_field.text.strip_edges(),"name":title_field.text.strip_edges(),"width":int(width_field.value),"depth":int(depth_field.value),"pixelsPerUnit":ppu.value,"rotatable":rotate_box.button_pressed,"views":views,"actions":actions}
func save_asset()->void:
	var result:=Made.import_asset(specification(),images)
	if not result.ok:notice.text=result.error;return
	created.emit(result.asset);queue_free()
func draw_preview()->void:
	preview.draw_rect(Rect2(Vector2.ZERO,preview.size),Color("eee4d0"))
	var face:String=Made.FACES[face_select.selected]
	var foot:=Vector2(Grid.footprint(int(width_field.value),int(depth_field.value),face))*Grid.CELL
	var k:=minf(2.6,minf(preview.size.x/(foot.x+150),preview.size.y/(foot.y+200)))
	var origin:=Vector2(preview.size.x/2-foot.x*k/2,preview.size.y/2-foot.y*k/2+40)
	for x in range(-8,17):preview.draw_line(origin+Vector2(x*Grid.CELL,-512)*k,origin+Vector2(x*Grid.CELL,512)*k,Color("ddcfb5"))
	for y in range(-16,17):preview.draw_line(origin+Vector2(-256,y*Grid.CELL)*k,origin+Vector2(512,y*Grid.CELL)*k,Color("ddcfb5"))
	var tex:Texture2D=preview_textures.get(face+"_art")
	if tex!=null:
		var sz:=tex.get_size()/ppu.value;preview.draw_texture_rect(tex,Rect2(origin+Vector2((foot.x-sz.x)/2,foot.y-sz.y)*k,sz*k),false)
	preview.draw_rect(Rect2(origin,foot*k),Color("688b6b"),false,2)
	if operation_mode.selected>0:
		var r:Dictionary=rows[face];var feet:=Vector2(r.fx.value,r.fy.value);var point:=origin+feet*k
		var p:Texture2D=preview_textures.get(face+"_pose")
		if p!=null:
			var sz:=Vector2(p.get_width()/frames.value,p.get_height())
			preview.draw_texture_rect_region(p,Rect2(point-Vector2(r.ax.value,r.ay.value)*pose_scale.value*k,sz*pose_scale.value*k),Rect2(Vector2(int(preview_time*fps.value)%int(frames.value)*sz.x,0),sz))
		preview.draw_line(point-Vector2(8,0),point+Vector2(8,0),Color("426b87"),2);preview.draw_line(point-Vector2(0,8),point+Vector2(0,8),Color("426b87"),2)
