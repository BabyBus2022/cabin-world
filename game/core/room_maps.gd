extends RefCounted
## Existing-room drafts and installed overrides are separate. Publishing never
## mutates an occupied world: the validated override is picked up next launch.
const Model=preload("res://core/map_model.gd")
const Store=preload("res://core/safe_store.gd")
const ROOMS=["xiaojingyu-home","world-arcade","world-restaurant","qianxia-shop","qianxia-park"]
static func directory()->String:
	# WorldData loads architecture before Economy._ready resolves its save path.
	# Resolve identically here so startup reads the same folder Publish writes.
	var args:=OS.get_cmdline_user_args();var exe:=OS.get_executable_path().get_base_dir()
	var ini:=exe.path_join("cabinworld.ini")
	var text:=FileAccess.get_file_as_string(ini) if FileAccess.file_exists(ini) else ""
	var save:=InstallPaths.resolve_save(args,OS.get_environment("CABINWORLD_SAVE"),exe,text)
	if save.is_empty():save="user://" if args.has("--unit") else "user://dev"
	return save.path_join("room-maps")
static func file(scene:String)->String:return directory().path_join(scene+".json")
static func valid(doc:Dictionary)->bool:
	if doc.get("disabled",false):return true
	var m=doc.get("map")
	if not m is Dictionary or m.get("id") not in ROOMS:return false
	return schema(m)==""
## A published map keeps its original furniture variant even if install choices change.
static func base_map(scene:String,variant:String="modern")->Dictionary:
	if variant not in ["modern","classic"]:return {}
	var prefix:="res://assets/classic/maps/" if variant=="classic" else "res://assets/maps/"
	var value=Store.raw(prefix+scene+"/map.json")
	return value if value is Dictionary else {}
static func schema(m:Dictionary)->String:
	var material_issue:String=preload("res://core/map_design.gd").materials_issue(m)
	if material_issue!="":return material_issue
	if m.get("format")!="cabin-map/1" or m.get("cell")!=Model.Grid.CELL:return "地图必须使用游戏的32像素格子"
	if m.get("id") not in ROOMS or m.get("editScene")!=m.id:return "请选择有效的现有房间"
	var base=base_map(str(m.id),str(m.get("baseVariant","modern")))
	if base.is_empty():return "原房间不可用"
	if m.get("kind")!=base.kind or m.get("size")!=base.size:return "改建现有房间时保留原地图尺寸和室内外类型"
	# Room remodeling owns architecture only. Furniture, actor profiles and file
	# references come from the shipped room, not from an AI-edited document.
	for key in ["legacy","furniture"]:
		if JSON.stringify(m.get(key),"",true)!=JSON.stringify(base.get(key),"",true):return "家具和交互数据请通过家具布置编辑器修改"
	if m.get("structure")!="modular":return "房间尚未转换为可编辑结构"
	if not m.get("size") is Array or m.size.size()!=2:return "地图大小错误"
	for n in m.size:
		if not (n is int or n is float) or n!=floorf(n) or n<4 or n>64:return "地图大小须为4至64个整数格"
	if not m.get("floor") is Dictionary or not m.floor.get("palette") is Dictionary or not m.floor.get("rows") is Array or m.floor.rows.size()!=int(m.size[1]):return "地板数据错误"
	for row in m.floor.rows:
		if not row is String or row.length()!=int(m.size[0]):return "地板行宽错误"
	if not m.get("walls") is Dictionary or not m.walls.get("style") is Dictionary:return "墙壁数据错误"
	if not m.walls.get("adaptive",false) is bool:return "墙壁高度模式错误"
	if m.has("gridOrigin"):
		var origin=m.gridOrigin
		var original:Array=base.legacy.get("gridOrigin",[0,0])
		if not origin is Array or origin.size()!=2:return "格子原点错误"
		for i in 2:
			if not (origin[i] is float or origin[i] is int) or not is_finite(origin[i]):return "格子原点错误"
		if origin[0]!=original[0] or origin[1]>original[1] or original[1]-origin[1]>Model.WALL_H*Model.Grid.CELL or fmod(original[1]-origin[1],Model.Grid.CELL)!=0:return "改建仅允许向上对齐少量整格，家具位置保持不变"
	for key in ["inner","doorways"]:
		if not m.walls.get(key) is Array:return "墙壁坐标错误"
		for c in m.walls[key]:
			if not c is Array or c.size()!=2:return "墙壁坐标错误"
			for n in c:
				if not (n is int or n is float) or not is_finite(n) or n!=floorf(n):return "墙壁须对齐整数格"
			if not Model.inb(m,Vector2i(c[0],c[1])):return "墙壁超出地图"
	if not m.get("openings") is Array or not m.get("exits") is Dictionary:return "门与连接数据错误"
	var ids:={}
	for o in m.openings:
		if not o is Dictionary or o.get("type") not in Model.openings_for(m):return "未知门窗类型"
		if not o.get("id") is String or ids.has(o.id):return "门窗编号重复或缺失"
		ids[o.id]=true
		for key in ["x","y"]:
			var n=o.get(key)
			if not (n is int or n is float) or not is_finite(n) or n!=floorf(n):return "门窗须对齐整数格"
	if not m.get("furniture") is Dictionary or not m.get("legacy") is Dictionary or not m.legacy.get("definition") is Dictionary:return "缺少原房间的家具与交互数据"
	return ""
static func installed(scene:String)->Dictionary:
	if scene not in ROOMS:return {}
	var doc:=Store.read_document(file(scene),valid)
	return doc.data.get("map",{}).duplicate(true) if doc.ok and not doc.data.get("disabled",false) else {}
static func draft(scene:String)->Dictionary:
	if scene not in ROOMS:return {}
	var m:=installed(scene)
	if m.is_empty():m=base_map(scene,"modern" if Features.use_map(scene) else "classic")
	if m.is_empty():return {}
	m=m.duplicate(true);m.editScene=scene
	if m.get("structure")=="modular":return m
	# Imported rooms retain exact furniture anchors and grid origin. Architecture
	# becomes a remodel draft; no installed room changes until Publish passes.
	m.structure="modular"
	for key in m.floor.palette:
		if m.floor.palette[key]=="legacy-floor":m.floor.palette[key]="original-ground" if Model.outdoor(m) else "arcade-coast-wood"
	m.walls.style={"edge":"hedge"} if Model.outdoor(m) else {"back":"whale-blue","side":"whale-blue","front":"whale-blue"}
	m=_old_openings(m)
	var layout:=layout_result(m)
	if Model.checks(m).any(func(c):return not c[1]) or layout.issue!="":
		load("res://core/remodel_geometry.gd").prepare(m,layout.support)
	return m

static func _old_openings(m:Dictionary)->Dictionary:
	var openings:=[]
	var old_openings:Array=m.openings.duplicate(true);m.openings=[]
	for old in old_openings:
		if old.type!="legacy-door":openings.append(old);continue
		var cell:=Vector2i(old.cell[0],old.cell[1])
		var best:Dictionary={};var score:=INF
		for kind in (["entrance"] if Model.outdoor(m) else ["front_door","back_door"]):
			for c in Model.floor_cells(m):
				if Model.opening_issue(m,kind,c.x,c.y)!="":continue
				var dist:=Vector2(c).distance_squared_to(Vector2(cell))
				if dist<score:score=dist;best={"id":old.id,"exit":old.get("exit",old.id),"type":kind,"x":c.x,"y":c.y}
		if not best.is_empty():openings.append(best)
	m.openings=openings
	return m
static func check(m:Dictionary)->String:
	var issue:=schema(m)
	if issue!="":return issue
	var Render=load("res://core/map_render.gd")
	for value in m.floor.palette.values():
		if value not in Render.floor_ids(m):return "地面材质不可用"
	for value in m.walls.style.values():
		if not (Render.EDGES if Model.outdoor(m) else Render.walls(m)).has(value):return "墙壁样式不可用"
	for value in m.walls.get("segments",{}).values():
		if not Render.walls(m).has(value):return "局部墙面材质不可用"
	for c in Model.checks(m):
		if not c[1]:return str(c[0])+"："+str(c[2])
	for o in Model.doors(m):
		var link=m.exits.get(o.get("exit",o.id),{})
		if not link is Dictionary or not WorldData.scenes.has(link.get("to","")):return "门的目标房间不存在"
		if not WorldData.scenes[link.to].get("entries",{}).has(link.get("entry","")):return "门的目标入口不存在"
	return layout_result(m).get("issue","")
## Save and restore editor globals: inspecting a draft never swaps the live room.
static func layout_result(m:Dictionary)->Dictionary:
	var HG=load("res://core/home_grid.gd")
	var previous:={"selected_scene":HG.selected_scene,"definition":HG.definition,"definitions":HG.definitions.duplicate(),"instance_key":HG.instance_key,"current":HG.current,"validation_cache":HG.validation_cache.duplicate(),"load_warning":HG.load_warning}
	var textures:=WorldData.runtime_textures.duplicate()
	var compiled:Dictionary=load("res://core/map_compile.gd").compile(m)
	HG.definitions[m.id]=compiled;HG.choose(m.id)
	var layout:Dictionary=HG.defaults()
	var saved=Store.raw(HG.path(m.id))
	if saved is Dictionary and saved.get("positions") is Dictionary:
		layout=saved.duplicate(true)
		for item in compiled.catalog:
			if not layout.positions.has(item.id):layout.positions[item.id]=item.cell.duplicate()
	var issue:String=HG.validate(layout)
	if issue=="":
		for item in HG.data().catalog:
			if item.layer=="surface" or HG.hidden(layout,item.id):continue
			if not HG.on_floor(HG.moved_rect(item.foot,HG.delta(layout,item.id))):issue=str(item.name)+"下方不能挖空地板或铺不能走的地面";break
	var result:={"issue":issue,"resolved":HG.resolve(layout),"layout":layout,"support":[]}
	for item in HG.data().catalog:
		if item.layer=="surface" or HG.hidden(layout,item.id):continue
		var foot:Rect2=HG.moved_rect(item.foot,HG.delta(layout,item.id))
		result.support.append([foot.position.x,foot.position.y,foot.size.x,foot.size.y])
	HG.selected_scene=previous.selected_scene;HG.definition=previous.definition;HG.definitions=previous.definitions
	HG.instance_key=previous.instance_key;HG.current=previous.current;HG.validation_cache=previous.validation_cache;HG.load_warning=previous.load_warning
	WorldData.runtime_textures=textures
	return result
static func publish(m:Dictionary)->String:
	var issue:=check(m)
	if issue!="":return issue
	# Restore architecture revision, otherwise HomeGrid would reset saved furniture.
	var copy:=m.duplicate(true)
	var original=base_map(str(m.id),str(m.get("baseVariant","modern")))
	copy.revision=original.get("revision","")
	return "" if Store.write_document(file(m.id),{"version":1,"map":copy},valid) else "保存房间失败；原房间未改动"
static func restore_original(scene:String)->String:
	if scene not in ROOMS:return "未知房间"
	return "" if Store.write_document(file(scene),{"version":1,"disabled":true},valid) else "恢复失败，原记录保留"
