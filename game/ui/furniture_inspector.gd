extends AcceptDialog
const Geometry=preload("res://core/furniture_geometry.gd")
const Grid=Geometry.Grid
var choose:=OptionButton.new()
var face_select:=OptionButton.new()
var canvas:=Control.new()
var result:=Label.new()
var assets:Dictionary={}
var asset_ids:Array=[]
func _ready()->void:
	title="家具检查 · 共用游戏格子";ok_button_text="关闭"
	if theme==null:theme=load("res://ui/home_editor.gd").editor_theme()
	get_ok_button().add_theme_color_override("font_color",Color("493c30"))
	var root:=VBoxContainer.new();root.add_theme_constant_override("separation",14);add_child(root)
	var bar:=HBoxContainer.new();root.add_child(bar)
	assets=Geometry.Library.all();asset_ids=assets.keys()
	for id in asset_ids:choose.add_item(str(assets[id].name)+" · "+str(assets[id].scene_name))
	choose.size_flags_horizontal=Control.SIZE_EXPAND_FILL;bar.add_child(choose)
	for name in ["正面","左侧","背面","右侧"]:face_select.add_item(name)
	bar.add_child(face_select)
	canvas.custom_minimum_size=Vector2(880,490);canvas.size_flags_vertical=Control.SIZE_EXPAND_FILL;canvas.clip_contents=true;canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;root.add_child(canvas)
	result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;result.custom_minimum_size=Vector2(880,100);root.add_child(result)
	choose.item_selected.connect(func(_i):refresh());face_select.item_selected.connect(func(_i):refresh());canvas.draw.connect(draw_preview);canvas.resized.connect(func():canvas.queue_redraw())
	confirmed.connect(queue_free);canceled.connect(queue_free);close_requested.connect(queue_free)
	refresh();popup_centered_clamped(Vector2i(1000,760),.9)
func refresh()->void:
	if asset_ids.is_empty():return
	var asset:Dictionary=assets[asset_ids[choose.selected]];var face:String=Geometry.FACES[face_select.selected]
	var check:=Geometry.inspect(asset,face)
	var size:Vector2i=check.footprint
	var release:="固定朝向" if asset.get("rotationLocked",false) else ("四向素材已标记审核" if asset.get("facingsApproved","")!="" else "四向素材尚未审核")
	result.text="%d×%d 格 = %d×%d 游戏像素  ·  默认每格 %d 素材像素\n%s · %s\n这里检查原始素材和占格，不改变游戏放置，也不自动批准尚未上线的方向。" % [size.x,size.y,size.x*Grid.CELL,size.y*Grid.CELL,Grid.ART_CELL,"尺寸校验通过" if check.ok else "；".join(check.issues),release]
	canvas.queue_redraw()
func draw_preview()->void:
	canvas.draw_rect(Rect2(Vector2.ZERO,canvas.size),Color("eee4d0"))
	if asset_ids.is_empty():return
	var check:=Geometry.inspect(assets[asset_ids[choose.selected]],Geometry.FACES[face_select.selected])
	var foot:=Vector2(check.footprint)*Grid.CELL
	var v:Dictionary=check.view
	var extent:=Rect2(Vector2.ZERO,foot)
	if not v.is_empty():extent=extent.merge(Rect2(v.art.x,v.art.y,v.art.w,v.art.h))
	var scale:=minf(3,minf((canvas.size.x-100)/extent.size.x,(canvas.size.y-70)/extent.size.y))
	var origin:=canvas.size/2-extent.get_center()*scale
	for x in range(-20,40):canvas.draw_line(origin+Vector2(x*Grid.CELL,-1280)*scale,origin+Vector2(x*Grid.CELL,1280)*scale,Color("d9cbb3"))
	for y in range(-40,40):canvas.draw_line(origin+Vector2(-1280,y*Grid.CELL)*scale,origin+Vector2(1280,y*Grid.CELL)*scale,Color("d9cbb3"))
	if not v.is_empty():
		var tex:=Geometry.texture(v.file)
		if tex!=null:
			var rect:=Rect2(origin+Vector2(v.art.x,v.art.y)*scale,Vector2(v.art.w,v.art.h)*scale)
			var region=v.get("region",[])
			if region is Array and region.size()==4:canvas.draw_texture_rect_region(tex,rect,Rect2(region[0],region[1],region[2],region[3]))
			else:canvas.draw_texture_rect(tex,rect,false)
	canvas.draw_rect(Rect2(origin,foot*scale),Color("51845b") if check.ok else Color("b95f43"),false,3)
