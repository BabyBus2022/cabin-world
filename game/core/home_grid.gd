class_name HomeGrid
extends RefCounted
## Layout is data: each independent item stores a grid cell; groups only store member IDs.
## The same resolved manifest, collision and interaction points drive the editor and game.
static var definition: Dictionary = {}
static var current: Dictionary = {}
static var load_warning := ""
static var validation_cache:Dictionary={}
static var selected_scene:="xiaojingyu-home"
static var definitions:Dictionary={}
static var instance_key := ""
static var packing: Dictionary = {}
static func grid_file(scene:String) -> String:
	return "park" if scene=="qianxia-park" else "shop" if scene=="qianxia-shop" else "restaurant" if scene=="world-restaurant" else "arcade" if scene=="world-arcade" else "home"
const Library = preload("res://core/furniture_library.gd")

static func grid_origin() -> Vector2:
	if not data().get("_shape",{}).is_empty():return Vector2.ZERO
	var file := grid_file(selected_scene)
	if not packing.has(file):packing[file]=JSON.parse_string(FileAccess.get_file_as_string("res://assets/"+file+"-grid-packing.json"))
	var p:Array=packing[file].origin
	return Vector2(p[0],p[1])

static func snap_layout(value: Dictionary, ids: Array) -> Dictionary:
	if ids.is_empty():return value
	activate(value)
	var item:Dictionary=data().catalog.filter(func(i):return i.id==ids[0])[0]
	var foot:=moved_rect(item.foot,delta(value,item.id))
	var origin:=grid_origin()
	var shift:Vector2=((foot.position-origin)/32).round()*32+origin-foot.position
	var out:=value.duplicate(true)
	if not out.has("offsets"):out.offsets={}
	for id in ids:
		var before:Array=out.offsets.get(id,[0,0])
		out.offsets[id]=[float(before[0])+shift.x,float(before[1])+shift.y]
	return out

static func activate(layout: Dictionary) -> void:
	if layout.get("scene", selected_scene) != selected_scene: choose(layout.scene)
	var instances = layout.get("instances", {})
	if not instances is Dictionary: return
	var key := selected_scene + JSON.stringify(instances, "", true)
	if key == instance_key: return
	definition = Library.augment(definitions[selected_scene], instances)
	instance_key = key
	validation_cache.clear()

static func hidden(layout: Dictionary, id: String) -> bool:
	return id in layout.get("stored", [])

static func store_items(layout: Dictionary, ids: Array) -> Dictionary:
	var out := layout.duplicate(true)
	if not out.has("stored"): out.stored = []
	for id in ids:
		if not id in out.stored: out.stored.append(id)
	out.groups = out.groups.map(func(g): return g.filter(func(id): return not id in out.stored)).filter(func(g): return g.size() > 1)
	return out


static func choose(scene:String) -> void:
	selected_scene=scene
	if not definitions.has(scene):
		var file:=grid_file(scene)+"-grid.json"
		definitions[scene]=JSON.parse_string(FileAccess.get_file_as_string("res://assets/"+file))
	definition=definitions[scene]
	instance_key=""
	var rk_args:=OS.get_cmdline_user_args();var rk_index:=rk_args.find("--roomkit") ## opt-in, see RoomKitItems
	if rk_index>=0 and rk_index+1<rk_args.size():load("res://core/roomkit_items.gd").augment(definition,rk_args[rk_index+1],scene)
	var plan_size:Array=definition.get("_shape",{}).get("size",[960,640])
	if plan_size!=[960.0,640.0] and plan_size!=[960,640]: ## baked ground art, lighting and weather assume 960x640
		load_warning="roomkit: 房间尺寸 %dx%d 与烘焙美术 960x640 不一致，背景与光照不会随之缩放"%[plan_size[0],plan_size[1]]
	validation_cache.clear()

static func requested_scene() -> String:
	var args:=OS.get_cmdline_user_args();var index:=args.find("--edit-scene")
	return args[index+1] if index>=0 and index+1<args.size() and args[index+1] in ["world-arcade","world-restaurant","qianxia-park","qianxia-shop"] else "xiaojingyu-home"

static func data() -> Dictionary:
	if definition.is_empty():choose(selected_scene)
	return definition

static func path(scene:="") -> String:
	if scene=="":scene=selected_scene
	var args:=OS.get_cmdline_user_args();var index:=args.find("--layout")
	if index>=0 and index+1<args.size():
		if scene==requested_scene():return args[index+1]
		return args[index+1].get_base_dir().path_join(grid_file(scene)+"-grid-layout.json")
	return OS.get_executable_path().get_base_dir().get_base_dir().path_join(grid_file(scene)+"-grid-layout.json")

## Opt-in: with `--roomkit <dir>` the default positions come from the roomkit room of this scene (roomkit/README.md).
## Without the flag, or if the room/assets cannot be read, nothing changes (catalog cells are used; failure is reported in load_warning).
## Only ids already in the catalog are taken, so the saved-layout format and the editor stay as they were.
static func roomkit_positions() -> Dictionary:
	var args:=OS.get_cmdline_user_args();var index:=args.find("--roomkit")
	if index<0 or index+1>=args.size():return {}
	var dir:String=args[index+1]
	if not DirAccess.dir_exists_absolute(dir.path_join("rooms")):
		load_warning="roomkit: 找不到 "+dir+"，已使用内置布局";return {}
	if not FileAccess.file_exists(dir.path_join("rooms").path_join(selected_scene).path_join("room.json")):return {} ## this scene has no roomkit room yet (e.g. the arcade): use the catalog
	var kit_class=load("res://core/roomkit.gd")
	var kit:Dictionary=kit_class.load_room(dir,selected_scene)
	if kit.error!="":
		load_warning="roomkit: "+kit.error+"，已使用内置布局";return {}
	var out:Dictionary={}
	var mapped:Dictionary=kit_class.to_home_grid_layout(kit).positions
	for item in data().catalog:
		if mapped.has(item.id):out[item.id]=mapped[item.id]
	return out

static func defaults() -> Dictionary:
	data()
	var positions:Dictionary={}
	for item in definitions[selected_scene].catalog:positions[item.id]=item.cell.duplicate()
	positions.merge(roomkit_positions(),true)
	return {"version":1,"scene":data().scene,"positions":positions,"groups":data().defaultGroups.duplicate(true),"instances":{},"stored":[],"map_revision":data().get("revision","")}

static func delta(layout: Dictionary,id: String) -> Vector2:
	for item in data().catalog:
		if item.id==id:
			var cell:Array=layout.positions[id]
			var offset:Array=layout.get("offsets",{}).get(id,[0,0])
			return Vector2(float(cell[0])-item.cell[0],float(cell[1])-item.cell[1])*float(data().cell)+Vector2(offset[0],offset[1])
	return Vector2.ZERO

## Fixed walls: the built-in list, or full-cell "#" rects when a roomkit plan drives the room shape.
static func wall_list() -> Array:
	var shape:Dictionary=data().get("_shape",{})
	return shape.walls if not shape.is_empty() else data().fixedObstacles

## Floor polygons for the editor grid: the plan's floor cells when it drives the shape, else the mask file.
static func floor_mask() -> Array:
	var shape:Dictionary=data().get("_shape",{})
	if not shape.is_empty():return shape.floor
	return JSON.parse_string(FileAccess.get_file_as_string(data().get("floorFile","res://assets/home-grid-floor.json"))).polygons

## Fraction of `foot` (Rect2) covered by the floor rectangles (axis-aligned runs from the plan).
static func floor_share(foot:Rect2,runs:Array) -> float:
	var area:=0.0
	for r in runs:area+=foot.intersection(Rect2(r[0][0],r[0][1],r[1][0]-r[0][0],r[2][1]-r[0][1])).get_area()
	return area/maxf(foot.get_area(),0.001)

static func moved_rect(values: Array,d: Vector2) -> Rect2:
	return Rect2(Vector2(values[0],values[1])+d,Vector2(values[2],values[3]))

static func resolve(layout: Dictionary) -> Dictionary:
	activate(layout)
	var d:=data();var scene:Dictionary=d.sceneData.duplicate(true)
	var manifest:Dictionary=d.manifest.duplicate(true);var profile:Dictionary=d.profile.duplicate(true)
	scene.layoutRevision="grid-v2:"+str(JSON.stringify(layout,"",true).hash())
	scene.obstacles=wall_list().duplicate(true)
	var shape:Dictionary=d.get("_shape",{})
	if not shape.is_empty(): ## the roomkit plan drives walking: only plan cells are walkable, "#" cells are walls
		scene.walkRegions=shape.walk.duplicate(true);scene.walk=shape.walk_rect.duplicate(true)
		scene.width=int(shape.size[0]);scene.height=int(shape.size[1])
		if not shape.door.is_empty(): ## the first "D" cell is the door; exit and use point keep the built-in offsets from the entry (+6 / -19 px)
			var dx:float=shape.door.x;var dy:float=shape.door.y
			scene.entries.door={"x":dx,"y":dy}
			for exit in scene.exits:
				if exit.id=="door":exit.x=dx;exit.y=dy+6
			if scene.zones.has("xj_door"):scene.zones.xj_door={"x":dx,"y":dy-19}
	for item in d.catalog:
		if hidden(layout, item.id):
			scene.modules.erase(item.id)
			if item.id == "xj-bed": scene.modules.erase("quilt")
			for z in item.zoneIds: scene.zones.erase(z)
			continue
		var shift:=delta(layout,item.id)
		var m:Dictionary=scene.modules[item.id];m.x+=shift.x;m.y+=shift.y;m.depth+=shift.y
		if item.layer=="solid":
			var foot:=moved_rect(item.foot,shift)
			scene.obstacles.append({"x":foot.position.x,"y":foot.position.y,"w":foot.size.x,"h":foot.size.y})
		for z in item.zoneIds:scene.zones[z].x+=shift.x;scene.zones[z].y+=shift.y
	manifest.layers = manifest.layers.filter(func(layer): return not hidden(layout, layer.get("owner", "xj-bed" if layer.id == "quilt" else layer.id)))
	for layer in manifest.layers:
		var owner:String=layer.get("owner", "xj-bed" if layer.id=="quilt" else layer.id)
		var shift:=delta(layout,owner);layer.x+=shift.x;layer.y+=shift.y
		if owner not in ["xj-ocean-rug","chess-seat-left","chess-seat-right"]:layer.depth+=shift.y
	if profile.has("home"):
		var bed_shift:=delta(layout,"xj-bed")
		profile.home.bed.lying[0]+=bed_shift.x;profile.home.bed.lying[1]+=bed_shift.y
		for stage in profile.home.stages:
			var owner:String=d.zoneOwners.get(stage.get("zone",""),"")
			var shift:=delta(layout,"xj-computer-chair" if stage.get("registered","")=="computer" else owner)
			if stage.has("feet"):stage.feet[0]+=shift.x;stage.feet[1]+=shift.y
			if stage.has("sort"):stage.sort+=shift.y
			if stage.get("registered","")=="computer" and delta(layout,"xj-desk")!=delta(layout,"xj-computer-chair"):
				stage.erase("registered");stage.erase("feet");stage.erase("sort")
		profile.home.layoutOffsets={"computer":delta(layout,"xj-computer-chair"),"desk":delta(layout,"xj-desk")}
	var visual:Dictionary=d.visual.duplicate(true);visual.modules=scene.modules;visual.zones=scene.zones
	if not shape.is_empty():
		visual.width=scene.width;visual.height=scene.height
		for exit in visual.exits:
			if exit.id=="door" and not shape.door.is_empty():exit.point={"x":shape.door.x,"y":shape.door.y+6}
	return {"scene":scene,"manifest":manifest,"profile":profile,"visual":visual}

static func validate(layout: Dictionary,paths:=true) -> String:
	if not layout.get("instances", {}) is Dictionary or not layout.get("stored", []) is Array: return "家具收纳格式不正确"
	if not layout.get("offsets",{}) is Dictionary:return "家具对齐数据不正确"
	for id in layout.get("offsets",{}):
		var offset=layout.offsets[id]
		if not layout.get("positions",{}).has(id) or not offset is Array or offset.size()!=2:return "家具对齐数据不正确"
		for n in offset:
			if not (n is int or n is float) or not is_finite(float(n)):return "家具对齐数据不正确"
	activate(layout)
	for id in layout.get("instances", {}):
		if not str(id).begins_with("placed_") or not Library.all().has(layout.instances[id]): return "家具库条目不存在"
	for id in layout.get("stored", []):
		if not layout.get("positions", {}).has(id): return "收纳家具不存在"
	if layout.get("version")!=1 or layout.get("scene")!=data().scene or not layout.get("positions") is Dictionary or not layout.get("groups") is Array:return "布局格式不正确"
	var known:Array=data().catalog.map(func(item):return item.id)
	if layout.positions.size()!=known.size():return "家具列表不完整"
	for id in known:
		var pos=layout.positions.get(id)
		if not pos is Array or pos.size()!=2:return "家具坐标不完整"
		for n in pos:
			if not (n is int or n is float) or not is_finite(float(n)) or float(n)!=floorf(float(n)):return "家具必须落在整数格子"
	var grouped:Array=[]
	for group in layout.groups:
		if not group is Array or group.size()<2:return "组合至少需要两件家具"
		for id in group:
			if not id in known or id in grouped:return "组合成员重复或不存在"
			grouped.append(id)
	var occupied:Array=[]
	for item in data().catalog:
		if hidden(layout,item.id):continue
		var foot:=moved_rect(item.foot,delta(layout,item.id))
		var shape:Dictionary=data().get("_shape",{})
		if shape.is_empty():
			if not moved_rect(data().get("bounds",[84,40,774,552]),Vector2.ZERO).encloses(foot):return item.name+"超出房屋范围"
			if item.has("asset") and item.layer != "surface" and not on_floor(foot):return item.name+"必须完整放在地面格子内"
		else: ## plan-driven room: at least half of the footprint must stand on floor cells (furniture may lean into the wall margin)
			if item.layer!="surface" and floor_share(foot,shape.floor)<0.5:return item.name+"超出房屋范围"
		if item.layer!="solid":continue
		for wall in wall_list():
			if foot.intersects(Rect2(wall.x,wall.y,wall.w,wall.h)):return item.name+"与墙体重叠"
		for row in occupied:
			if foot.intersects(row.rect):return item.name+"与"+str(row.name)+"重叠"
		occupied.append({"rect":foot,"name":item.name})
	if paths:
		var cache_key:=JSON.stringify(layout,"",true)
		if validation_cache.has(cache_key):return validation_cache[cache_key]
		var scene:Dictionary=resolve(layout).scene
		var nav:=RoomNav.new(scene);var door:=Vector2(scene.entries.door.x,scene.entries.door.y)
		if not nav.walkable(door):return "门口被挡住了"
		var from:=near_cell(nav,door)
		for z in scene.zones:
			var p:=Vector2(scene.zones[z].x,scene.zones[z].y)
			var to:=near_cell(nav,p)
			if not nav.walkable(p) or from.x<0 or to.x<0 or nav.grid.get_id_path(from,to).is_empty():
				var error:="无法走到使用位置："+str(z)
				validation_cache[cache_key]=error;return error
		if validation_cache.size()>128:validation_cache.clear()
		validation_cache[cache_key]=""
	return ""

static func on_floor(foot: Rect2) -> bool:
	var remaining: Array[PackedVector2Array] = [PackedVector2Array([foot.position,Vector2(foot.end.x,foot.position.y),foot.end,Vector2(foot.position.x,foot.end.y)])]
	for points in floor_mask():
		var polygon := PackedVector2Array()
		for p in points:polygon.append(Vector2(p[0],p[1]))
		var next: Array[PackedVector2Array] = []
		for part in remaining:next.append_array(Geometry2D.clip_polygons(part,polygon))
		remaining=next
	return remaining.is_empty()

static func near_cell(nav:RoomNav,p:Vector2) -> Vector2i:
	var center:=Vector2i(((p-nav.walk.position)/nav.step).round())
	for radius in 3:
		for y in range(-radius,radius+1):
			for x in range(-radius,radius+1):
				var cell:=center+Vector2i(x,y)
				if nav.grid.region.has_point(cell) and not nav.grid.is_point_solid(cell) and nav.clear_line(nav.walk.position+Vector2(cell)*nav.step,p):return cell
	return nav._nearest_cell(p)

static func selection(layout: Dictionary,ids: Array) -> Array:
	var out:=ids.duplicate()
	for group in layout.groups:
		if group.any(func(id):return id in ids):
			for id in group:
				if not id in out:out.append(id)
	return out

static func translate(layout: Dictionary,ids: Array,step: Vector2i) -> Dictionary:
	var out:=layout.duplicate(true)
	for id in ids:
		out.positions[id][0]+=step.x;out.positions[id][1]+=step.y
	return out

static func group_items(layout: Dictionary,ids: Array) -> Dictionary:
	var members:=selection(layout,ids);var out:=layout.duplicate(true)
	out.groups=out.groups.filter(func(group):return not group.any(func(id):return id in members))
	if members.size()>=2:out.groups.append(members)
	return out

static func ungroup(layout: Dictionary,ids: Array) -> Dictionary:
	var out:=layout.duplicate(true)
	out.groups=out.groups.filter(func(group):return not group.any(func(id):return id in ids))
	return out

static func save(layout: Dictionary) -> String:
	var issue:=validate(layout)
	if issue!="":return issue
	var file:=path();DirAccess.make_dir_recursive_absolute(file.get_base_dir())
	var handle:=FileAccess.open(file+".tmp",FileAccess.WRITE)
	if handle==null:return "无法写入布局文件"
	handle.store_string(JSON.stringify(layout,"  "));handle.close()
	if FileAccess.file_exists(file):
		if DirAccess.copy_absolute(file,file+".bak")!=OK:return "布局备份失败，未覆盖"
	if DirAccess.rename_absolute(file+".tmp",file)!=OK:return "布局保存失败"
	current=layout.duplicate(true)
	return ""

static func load_saved() -> Dictionary:
	var layout:=defaults()
	if FileAccess.file_exists(path()):
		var saved=JSON.parse_string(FileAccess.get_file_as_string(path()))
		if saved is Dictionary and saved.get("positions") is Dictionary:
			if selected_scene=="world-arcade" and data().get("revision","")=="arcade-wide-20261109" and saved.get("map_revision","")=="arcade-station-20261108":
				# Three full columns were inserted before the right-hand rooms.
				# Translate existing placements together with the architecture; keep storage/groups/instances.
				for cell in saved.positions.values():
					if cell[0]>=19:cell[0]+=3
				saved.map_revision=data().revision
			if data().has("revision") and saved.get("map_revision","")!=data().revision:
				# New room geometry needs new base positions. Keep stored items and custom additions.
				saved.positions.merge(layout.positions,true)
				for id in layout.positions:saved.get("offsets",{}).erase(id)
				saved.map_revision=data().revision
				if not saved.has("stored"):saved.stored=[]
				# Preserve custom additions in storage rather than place them into a new wall.
				for id in saved.get("instances",{}):
					if not id in saved.stored:saved.stored.append(id)
				load_warning="房型已更新：原家具已重新布置，自添家具保留在收纳中"
			for id in layout.positions:
				if not saved.positions.has(id):saved.positions[id]=layout.positions[id]
		var issue:=validate(saved) if saved is Dictionary else "无法读取布局"
		if issue=="":layout=saved
		else:load_warning=issue+"，已使用默认布局，原文件保留"
	activate(layout)
	current=layout.duplicate(true)
	return layout

static func apply(layout: Dictionary) -> void:
	var r:=resolve(layout);var id:String=data().scene
	WorldData.scenes[id]=r.scene;WorldData.layers[id]=r.manifest;WorldData._navs.erase(id)
	WorldPresentation.facts().scenes[id]=r.visual
	if not r.profile.is_empty():
		for person in Residents.people():
			# Layouts own furniture/pose geometry, never a resident's identity,
			# peer, preferences or AI configuration (including public shells).
			if person.home.scene==id and r.profile.has("home"):
				person.home=r.profile.home.duplicate(true)

static func initialize() -> void:
	for scene in ["xiaojingyu-home","world-arcade","world-restaurant","qianxia-park","qianxia-shop"]:
		if WorldData.scenes.has(scene) and FileAccess.file_exists("res://assets/"+grid_file(scene)+"-grid.json"):
			choose(scene);apply(load_saved())
	choose(requested_scene());current=load_saved()
