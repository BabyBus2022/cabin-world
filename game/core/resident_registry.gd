extends RefCounted
const Grid=preload("res://core/world_grid.gd")
## Persistent identities and independent rooms. Never derive identity from display names.
const Store=preload("res://core/safe_store.gd")
const Personal=preload("res://core/resident_personal.gd")
const M=preload("res://core/map_model.gd")
static var rows:Dictionary={}
static func file()->String:return Economy.save_path.get_base_dir().path_join("resident-registry.json")
static func valid_key(key:String)->bool:
	var re:=RegEx.new();re.compile("^[a-zA-Z0-9][a-zA-Z0-9_-]{0,47}$")
	return re.search(key)!=null and key not in ["computer","__proto__","prototype","constructor"]
static func valid(doc:Dictionary)->bool:
	if not doc.get("residents",{}) is Dictionary:return false
	for key in doc.get("residents",{}):
		var r=doc.residents[key]
		if not valid_key(key) or not r is Dictionary or not Personal.valid_name(r.get("name")):return false
		if r.has("map") and not r.map is Dictionary:return false
		if r.has("homeName") and not Personal.valid_name(r.homeName):return false
		if r.has("deleted") and not r.deleted is bool:return false
	return true
static func restore()->void:
	var saved:=Store.read_document(file(),valid)
	if not saved.ok:return
	rows=saved.data.get("residents",{})
	for key in rows:
		if not rows[key].get("deleted",false):mount(key,rows[key])
static func removed(key:String)->bool:return rows.get(key,{}).get("deleted",false)
static func maps_dir()->String:
	var args:=OS.get_cmdline_user_args();var i:=args.find("--maps-dir")
	return ProjectSettings.globalize_path(args[i+1] if i>=0 and i+1<args.size() else Economy.save_path.get_base_dir().path_join("maps"))
static func maps()->Array:
	var out:=[]
	var directory:=DirAccess.open(maps_dir())
	if directory==null:return out
	for id in directory.get_directories():
		if not valid_key(id):continue
		var p:=maps_dir().path_join(id).path_join("map.json")
		var m=Store.raw(p)
		if m is Dictionary and m.get("kind")=="indoor":out.append({"id":id,"name":m.get("name",id)})
	return out
static func describe(key:String)->Dictionary:
	var p:=Residents.person(key)
	if p.is_empty():return {}
	var scene:String=p.home.scene
	return {"key":key,"name":Personal.label(key,p.name),"homeName":WorldData.scenes[scene].name,"scene":scene,"home":p.home,"arcade":p.get("arcade",{}),"zones":WorldData.scenes[scene].zones,"custom":rows.has(key)}
static func accept(f:Dictionary)->Dictionary:
	var action:String=f.get("action","list")
	if action=="list":return {"ok":true,"residents":Residents.people().map(func(p):return describe(p.key)),"maps":maps(),"deleted":rows.keys().filter(func(k):return removed(k))}
	var key:String=str(f.get("actor",""))
	if not valid_key(key):return {"ok":false,"error":"住户编号须为1–48位字母、数字、下划线或短横线"}
	if removed(key):return {"ok":false,"error":"这位住户已经删除，不能由旧连接自动恢复；请使用新的编号"}
	if action=="remove":return remove_resident(key)
	if action=="rename_home":return rename_home(key,f.get("name",""))
	if action=="register" and not Residents.person(key).is_empty():return {"ok":true,"resident":describe(key),"existing":true}
	if action not in ["register","room"]:return {"ok":false,"error":"未知住户操作"}
	if action=="room" and not rows.has(key):return {"ok":false,"error":"内置房间保留；请为新增住户分配自制房间"}
	var name:String=str(f.get("name",rows.get(key,{}).get("name",key)))
	if not Personal.valid_name(name):return {"ok":false,"error":"名字须为1–32字"}
	if rows.values().filter(func(r):return not r.get("deleted",false)).size()>=32 and not rows.has(key):return {"ok":false,"error":"当前最多可新增32位住户"}
	var row:Dictionary={"name":name.strip_edges()}
	if rows.get(key,{}).has("homeName"):row.homeName=rows[key].homeName
	var map_id:String=str(f.get("mapId",""))
	if map_id!="":
		if not valid_key(map_id):return {"ok":false,"error":"地图编号无效"}
		var m=Store.raw(maps_dir().path_join(map_id).path_join("map.json"))
		var issue:=map_issue(m)
		if issue!="":return {"ok":false,"error":issue}
		row.map=m;row.mapId=map_id
	# Switching a room while occupied would invalidate walking, seats and furniture.
	if action=="room":
		for c in Engine.get_main_loop().get_nodes_in_group("world_residents"):
			if c.scene_id==describe(key).scene or c.want_scene==describe(key).scene:return {"ok":false,"error":"请让房间内的住户先去公园，再更换房间"}
	var next:=rows.duplicate(true);next[key]=row
	if not Store.write_document(file(),{"version":1,"residents":next},valid):return {"ok":false,"error":"住户登记保存失败，未新增或更换"}
	rows=next;mount(key,row)
	WorldData.resident_registered.emit(key)
	return {"ok":true,"resident":describe(key)}
static func rename_home(key:String,value:Variant)->Dictionary:
	if not rows.has(key):return {"ok":false,"error":"请为自建住户修改私人房屋名称"}
	if not Personal.valid_name(value):return {"ok":false,"error":"房屋名称须为1–32字，不能包含控制字符"}
	var next:=rows.duplicate(true);next[key].homeName=value.strip_edges()
	if not Store.write_document(file(),{"version":1,"residents":next},valid):return {"ok":false,"error":"房屋名称保存失败"}
	rows=next;refresh_name(key)
	return {"ok":true,"resident":describe(key)}
static func refresh_name(key:String)->void:
	if not rows.has(key) or removed(key):return
	var scene:="resident-"+key+"-home"
	var name:String=rows[key].get("homeName",Personal.label(key,rows[key].name)+"的家")
	if WorldData.scenes.has(scene):WorldData.scenes[scene].name=name
	if HomeGrid.definitions.has(scene):
		HomeGrid.definitions[scene].sceneData.name=name;HomeGrid.definitions[scene].visual.name=name
	if WorldPresentation.facts().scenes.has(scene):WorldPresentation.facts().scenes[scene].name=name
	WorldData.resident_named.emit(key)
static func remove_resident(key:String)->Dictionary:
	if not rows.has(key):return {"ok":false,"error":"内置机器人不能删除"}
	var scene:="resident-"+key+"-home";var space:="home_"+key
	if Actions.current(key).get("id","")!="":return {"ok":false,"error":"请先结束住户当前活动再删除"}
	for c in Engine.get_main_loop().get_nodes_in_group("world_residents"):
		if c.key!=key and (c.scene_id==scene or c.want_scene==scene):return {"ok":false,"error":"还有访客在家中或正在前往，请先让访客离开"}
		if c.key==key and (c.is_walking() or c.restaurant_owner!=""):return {"ok":false,"error":"请先停止走路或餐厅操作再删除"}
	# A durable tombstone is the commit point. Keep the old row and per-resident
	# saves as recovery data; a stale host cannot re-register this identity.
	var next:=rows.duplicate(true);next[key].deleted=true;next[key].deletedAt=SharedFeed.now_ms()
	if not Store.write_document(file(),{"version":1,"residents":next},valid):return {"ok":false,"error":"删除记录保存失败，住户未删除"}
	rows=next
	WorldData.resident_removed.emit(key,scene)
	Seats.release(key);Body._people.erase(key)
	Residents.people().assign(Residents.people().filter(func(p):return p.key!=key))
	for s in WorldData.scenes.values():s.exits=s.exits.filter(func(e):return e.get("to")!=scene)
	for s in Entry.SPACES.values():s.links=s.links.filter(func(link):return link!=space)
	Entry.SPACES.erase(space);WorldData.SPACE_SCENE.erase(space)
	WorldData.scenes.erase(scene);WorldData.layers.erase(scene);WorldData._navs.erase(scene)
	HomeGrid.definitions.erase(scene);WorldPresentation.facts().scenes.erase(scene)
	for tex in WorldData.runtime_textures.keys():
		if str(tex).begins_with(scene+"-"):WorldData.runtime_textures.erase(tex)
	SharedFeed.presence_now.erase(key)
	if HomeGrid.selected_scene==scene:HomeGrid.choose("xiaojingyu-home");HomeGrid.current=HomeGrid.load_saved()
	return {"ok":true,"removed":key,"scene":scene,"archived":true,"note":"住户与私人房间已移出世界；恢复资料保留，原地图模板和其他住户未删除"}
static func map_issue(m:Variant)->String:
	if not m is Dictionary or m.get("format")!="cabin-map/1" or m.get("kind")!="indoor":return "请选择室内地图"
	if not m.get("size") is Array or m.size.size()!=2 or m.size[0]!=30 or m.size[1]!=20 or m.get("cell")!=Grid.CELL:return "目前入住地图须为30×20格，每格32像素"
	if not m.get("floor") is Dictionary or not m.floor.get("rows") is Array or m.floor.rows.size()!=20:return "地图地面格式错误"
	for line in m.floor.rows:
		if not line is String or line.length()!=30:return "地图地面行宽错误"
	if not m.floor.get("palette") is Dictionary or not m.get("walls") is Dictionary or not m.walls.get("style") is Dictionary or not m.walls.get("inner") is Array or not m.walls.get("doorways") is Array or not m.get("openings") is Array or not m.get("exits") is Dictionary:return "地图结构缺少门窗或墙壁数据"
	var renderer=load("res://core/map_render.gd")
	for part in ["back","side","front"]:
		if not renderer.WALLS.has(m.walls.style.get(part,"")):return "请选择有效墙壁样式"
	for cells in [m.walls.inner,m.walls.doorways]:
		for c in cells:
			if not c is Array or c.size()!=2:return "内墙坐标错误"
			for n in c:
				if not (n is float or n is int) or not is_finite(float(n)) or n!=floorf(n):return "内墙须落在整数格"
			if c[0]<0 or c[0]>=30 or c[1]<0 or c[1]>=20:return "内墙超出地图"
	for o in m.openings:
		if not o is Dictionary or not M.OPENINGS.has(o.get("type","")) or not o.has("x") or not o.has("y") or not o.has("id"):return "地图门窗格式错误"
		for axis in ["x","y"]:
			var n=o[axis]
			if not (n is float or n is int) or not is_finite(float(n)) or n!=floorf(n):return "门窗须落在整数格"
	for rule in M.checks(m):
		if not rule[1] and rule[-1]!="linked":return str(rule[0])+"："+str(rule[2])
	return ""
static func mount(key:String,row:Dictionary)->void:
	var scene:="resident-"+key+"-home"
	var space:="home_"+key
	var template:=Residents.person("xiaojingyu").duplicate(true)
	if template.is_empty():return
	var def:Dictionary=HomeGrid.definitions["xiaojingyu-home"].duplicate(true)
	if row.has("map"):
		if map_issue(row.map)!="":push_warning("住户地图无效，保留默认房间："+key)
		else:def=custom_definition(scene,row.map,def)
	var display_name:String=Personal.label(key,row.name)
	def.scene=scene;def.sceneData.id=scene;def.sceneData.name=row.get("homeName",display_name+"的家");def.sceneData.owner=key
	def.visual.id=scene;def.visual.name=def.sceneData.name
	for e in def.sceneData.exits:e.to="qianxia-park";e.entry="xjhome"
	for e in def.visual.exits:e.to={"sceneId":"qianxia-park","entry":"xjhome"};e.name="公园"
	if def.profile.has("home"):def.profile.home.scene=scene
	HomeGrid.definitions[scene]=def
	WorldData.scenes[scene]=def.sceneData
	if Residents.person(key).is_empty():
		template.key=key;template.flavor=key;template.name=display_name;template.start=[scene,"xj_door"]
		template.home=def.profile.get("home",{}).duplicate(true)
		template.home.scene=scene
		template.arcade.board="xiangqi@"+space
		Residents.people().append(template)
	else:Residents.person(key).home=def.profile.get("home",{}).duplicate(true)
	HomeGrid.choose(scene);HomeGrid.apply(HomeGrid.load_saved())
	WorldData.SPACE_SCENE[space]=scene
	Entry.SPACES[space]={"owner":key,"links":["park"]}
	if not space in Entry.SPACES.park.links:Entry.SPACES.park.links.append(space)
	var park:Dictionary=WorldData.scenes["qianxia-park"]
	if not park.exits.any(func(e):return e.to==scene):
		var e:Dictionary=park.exits.filter(func(x):return x.to=="xiaojingyu-home")[0].duplicate(true)
		e.id=space;e.to=scene;e.entry="door";park.exits.append(e)
	WorldData._navs.erase(scene)
static func custom_definition(scene:String,m:Dictionary,base:Dictionary)->Dictionary:
	var d:=base.duplicate(true)
	d.revision="custom:"+str(JSON.stringify(m).hash())
	d.catalog=[];d.zoneOwners={};d.defaultGroups=[];d.fixedObstacles=[];d.gridOrigin=[0,0]
	var walk:=M.walkable(m);var polygons:=[]
	for c in walk:polygons.append([[c.x*Grid.CELL,c.y*Grid.CELL],[(c.x+1)*Grid.CELL,c.y*Grid.CELL],[(c.x+1)*Grid.CELL,(c.y+1)*Grid.CELL],[c.x*Grid.CELL,(c.y+1)*Grid.CELL]])
	var door:Dictionary=M.doors(m)[0]
	var p:={"x":float(door.x)*Grid.CELL+Grid.CELL/2,"y":float(door.y)*Grid.CELL+Grid.CELL/2}
	d.floorPolygons=polygons
	d.sceneData={"id":scene,"name":m.name,"width":960,"height":640,"speed":base.sceneData.speed,"run":base.sceneData.run,"outdoor":false,"enclosed":true,"description":m.name,"walk":{"x":0,"y":0,"w":960,"h":640},"clearance":4,"walkRegions":polygons,"obstacles":[],"modules":{},"zones":{"xj_door":p},"entries":{"door":p},"exits":[{"id":"door","x":p.x,"y":p.y,"to":"qianxia-park","entry":"xjhome"}]}
	var images:Dictionary=load("res://core/map_render.gd").render(m)
	for part in images:WorldData.runtime_textures[scene+"-"+part]=ImageTexture.create_from_image(images[part])
	d.manifest={"ground":{"file":"runtime:"+scene+"-ground","x":0,"y":0,"w":960,"h":640},"layers":[]}
	for part in ["inner","overlay"]:d.manifest.layers.append({"id":part,"file":"runtime:"+scene+"-"+part,"x":0,"y":0,"w":960,"h":640,"depth":1000})
	d.profile={"home":{"scene":scene,"defaultZone":"xj_door","placeNames":[],"stages":[],"idle":{}}}
	d.visual={"id":scene,"name":m.name,"width":960,"height":640,"modules":{},"zones":d.sceneData.zones,"exits":[{"id":"door","name":"公园","point":p,"to":{"sceneId":"qianxia-park","entry":"xjhome"}}]}
	return d
