extends RefCounted
const Grid=preload("res://core/world_grid.gd")
## User assets are data and PNGs only. No scripts, remote URLs or executable hooks.
const Store=preload("res://core/safe_store.gd")
const FACES=["S","W","N","E"]
static var cached:Dictionary={}
static var loaded_path:=""
static var textures:Dictionary={}
static func root()->String:return Economy.save_path.get_base_dir().path_join("furniture-made")
static func file()->String:return root().path_join("library.json")
static func valid_id(s:Variant)->bool:
	if not s is String:return false
	var re:=RegEx.new();re.compile("^[a-zA-Z0-9][a-zA-Z0-9_-]{0,47}$")
	return re.search(s)!=null and s not in ["__proto__","constructor","prototype"]
static func number(n:Variant,lo:float,hi:float)->bool:return (n is int or n is float) and is_finite(float(n)) and n>=lo and n<=hi
static func text_ok(s:Variant,limit:int)->bool:
	if not s is String or s.strip_edges().is_empty() or s.length()>limit:return false
	for i in s.length():
		if s.unicode_at(i)<32:return false
	return true
static func valid(doc:Dictionary)->bool:
	if not doc.get("assets",{}) is Dictionary:return false
	for id in doc.get("assets",{}):
		var a=doc.assets[id]
		if not a is Dictionary or a.get("id")!=id or not str(id).begins_with("user-") or not a.get("custom") is Dictionary or not a.get("layers") is Array or not a.get("facings") is Dictionary:return false
	return true
static func all()->Dictionary:
	if loaded_path!=file():
		var saved:=Store.read_document(file(),valid);cached=saved.data.get("assets",{}) if saved.ok else {};loaded_path=file();textures.clear()
	return cached
static func image_path(ref:String)->String:
	var name:=ref.trim_prefix("made:")
	if name!=name.get_file() or not name.ends_with(".png"):return ""
	return root().path_join(name)
static func texture(ref:String)->Texture2D:
	if textures.has(ref):return textures[ref]
	var path:=image_path(ref)
	if path=="" or not FileAccess.file_exists(path):return null
	var img:=Image.new()
	if img.load(path)!=OK:return null
	var t:=ImageTexture.create_from_image(img);textures[ref]=t;return t
static func png(bytes:PackedByteArray)->Dictionary:
	if bytes.size()<24 or bytes.size()>4*1024*1024 or bytes.slice(0,8)!=PackedByteArray([137,80,78,71,13,10,26,10]):return {"error":"请选择不超过4MB的PNG图片"}
	var w:=0;var h:=0
	for i in range(16,20):w=w*256+bytes[i];h=h*256+bytes[i+4]
	if w<1 or h<1 or w>2048 or h>2048:return {"error":"图片尺寸须在1–2048像素内"}
	var img:=Image.new()
	if img.load_png_from_buffer(bytes)!=OK:return {"error":"PNG图片无法读取"}
	return {"w":w,"h":h}
static func import_asset(spec:Dictionary,images:Dictionary)->Dictionary:
	var id=spec.get("id","");var name=spec.get("name","")
	if not valid_id(id) or not text_ok(name,40):return {"ok":false,"error":"请填写有效家具编号和1–40字名称"}
	all()
	var asset_id:String="user-"+id
	if cached.has(asset_id):return {"ok":false,"error":"这个家具编号已存在，请换一个编号；原家具不会被覆盖"}
	if cached.size()>=128:return {"ok":false,"error":"自制家具库已达到128件"}
	for k in ["width","depth"]:
		if not number(spec.get(k),1,8) or int(spec[k])!=spec[k]:return {"ok":false,"error":"占地长宽须为1–8整数格"}
	var ppu=spec.get("pixelsPerUnit",2)
	if not number(ppu,.25,8):return {"ok":false,"error":"图片比例须为每游戏像素0.25–8个素材像素"}
	var rotation:bool=spec.get("rotatable",false)==true
	var faces:Array=FACES if rotation else ["S"]
	var views=spec.get("views",{});var actions=spec.get("actions",[])
	if not views is Dictionary or not actions is Array or actions.size()>8:return {"ok":false,"error":"方向或动作配置无效（最多8个动作）"}
	var files:Dictionary={};var dims:Dictionary={}
	if images.size()>132:return {"ok":false,"error":"图片数量过多"}
	var total:=0
	for key in images:
		if not valid_id(key) or not images[key] is PackedByteArray:return {"ok":false,"error":"图片编号或数据无效"}
		total+=images[key].size()
		if total>24*1024*1024:return {"ok":false,"error":"每件家具图片合计不得超过24MB"}
		var d:=png(images[key])
		if d.has("error"):return {"ok":false,"error":str(key)+"："+str(d.error)}
		dims[key]=d
		var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(images[key])
		files[key]="made:"+hash.finish().hex_encode()+".png"
	var cooked_views:Dictionary={}
	for face in faces:
		var v=views.get(face,{})
		if not v is Dictionary or not dims.has(v.get("image","")):return {"ok":false,"error":"缺少"+face+"方向家具图"}
		var size:Dictionary=dims[v.image]
		var footprint:=Grid.footprint(int(spec.width),int(spec.depth),face)
		var w:float=footprint.x*Grid.CELL
		var h:float=footprint.y*Grid.CELL
		var aw:float=float(size.w)/ppu;var ah:float=float(size.h)/ppu
		if absf(aw-w)>Grid.CELL:return {"ok":false,"error":face+"方向图宽度与占格相差超过一格，请调整素材比例或图片，不能拉伸"}
		cooked_views[face]={"file":files[v.image],"footprint":{"w":w/Grid.CELL,"h":h/Grid.CELL},"art":{"x":(w-aw)/2,"y":h-ah,"w":aw,"h":ah},"depth":h,"scale":1.0/ppu}
	var ids:=[];var cooked_actions:=[]
	for a in actions:
		if not a is Dictionary or not valid_id(a.get("id")) or a.id in ids or not text_ok(a.get("name"),40) or not text_ok(a.get("description"),300):return {"ok":false,"error":"动作须有不重复编号、名称与功能说明"}
		ids.append(a.id)
		if a.get("mode") not in ["activity","external"] or not number(a.get("seconds",5),1,60):return {"ok":false,"error":"动作类型或时长无效"}
		var poses=a.get("poses",{})
		if not poses is Dictionary or poses.is_empty() or poses.size()>16:return {"ok":false,"error":"每个动作须绑定1–16位机器人的动作图片"}
		var cooked_poses:Dictionary={}
		for actor in poses:
			if not valid_id(actor) or not poses[actor] is Dictionary:return {"ok":false,"error":"机器人编号或动作方向无效"}
			cooked_poses[actor]={}
			for face in faces:
				var p=poses[actor].get(face,{})
				if not p is Dictionary or not dims.has(p.get("image","")):return {"ok":false,"error":actor+"缺少"+face+"方向动作图"}
				var frames=p.get("frames",1);var fps=p.get("fps",4);var scale=p.get("scale",.5)
				var sz:Dictionary=dims[p.image]
				if not number(frames,1,16) or int(frames)!=frames or int(sz.w)%int(frames)!=0 or not number(fps,1,16) or not number(scale,.05,4):return {"ok":false,"error":"动作图需为等宽横排帧，帧数/速度/比例无效"}
				var fw:float=float(sz.w)/frames
				var anchor=p.get("anchor",[fw/2,float(sz.h)])
				var foot=p.get("feet",[float(cooked_views[face].footprint.w)*Grid.CELL/2,float(cooked_views[face].footprint.h)*Grid.CELL+20])
				for point in [anchor,foot]:
					if not point is Array or point.size()!=2 or not number(point[0],-1024,2048) or not number(point[1],-1024,2048):return {"ok":false,"error":"动作脚底锚点或站位坐标无效"}
				cooked_poses[actor][face]={"file":files[p.image],"frames":frames,"fps":fps,"scale":scale,"anchor":anchor,"feet":foot,"cell":[fw,sz.h]}
		cooked_actions.append({"id":a.id,"name":a.name,"description":a.description,"mode":a.mode,"seconds":float(a.get("seconds",5)),"poses":cooked_poses})
	var front:Dictionary=cooked_views.S;var art:Dictionary=front.art
	var asset:Dictionary={"id":asset_id,"name":name,"scene":"custom","scene_name":"自制家具","layer":"solid","footprint":{"w":spec.width,"h":spec.depth},"rotationLocked":not rotation,"facingsApproved":"user-grid-validated" if rotation else "","facings":cooked_views,"custom":{"actions":cooked_actions},"layers":[{"part":"main","file":front.file,"x":art.x,"y":art.y,"w":art.w,"h":art.h,"depth":front.depth,"scale":front.scale}]}
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root()))!=OK:return {"ok":false,"error":"无法建立家具素材目录"}
	for key in files:
		var dest:=image_path(files[key])
		if FileAccess.file_exists(dest):continue
		var f:=FileAccess.open(dest,FileAccess.WRITE)
		if f==null:return {"ok":false,"error":"图片保存失败"}
		f.store_buffer(images[key]);f.flush();var ok:=f.get_error()==OK;f.close()
		if not ok:return {"ok":false,"error":"图片保存失败"}
	var next:=cached.duplicate(true);next[asset_id]=asset
	if not Store.write_document(file(),{"version":1,"assets":next},valid):return {"ok":false,"error":"家具配置保存失败，未加入家具库"}
	cached=next
	return {"ok":true,"asset":asset_id,"name":name,"rotatable":rotation,"functional":not actions.is_empty()}
static func objects(actor:String)->Array:
	var out:=[]
	for scene_id in WorldData.scenes:
		var scene:Dictionary=WorldData.scenes[scene_id]
		var owner:String=str(scene.get("owner",""))
		if owner!="" and owner!=actor:continue
		for id in scene.modules:
			var m:Dictionary=scene.modules[id]
			if not m.has("customAsset"):continue
			var asset:Dictionary=all().get(m.customAsset,{})
			var uses:=[]
			for a in asset.get("custom",{}).get("actions",[]):
				if a.poses.has(actor):uses.append({"id":a.id,"label":a.name,"description":a.description,"mode":a.mode,"seconds":a.seconds})
			out.append({"id":"made/"+scene_id+"/"+id,"module":id,"asset":m.customAsset,"name":asset.get("name",id),"scene":scene_id,"zone":"use_"+id,"facing":m.get("facing","S"),"revision":scene.get("layoutRevision",""),"functional":not uses.is_empty(),"uses":uses})
	return out
static func pose(scene:String,module:String,actor:String,action:String)->Dictionary:
	var m:Dictionary=WorldData.scenes.get(scene,{}).get("modules",{}).get(module,{})
	var a:Dictionary=all().get(m.get("customAsset",""),{})
	for use in a.get("custom",{}).get("actions",[]):
		if use.id==action:return use.poses.get(actor,{}).get(m.get("facing","S"),{})
	return {}
static func accept(f:Dictionary)->Dictionary:
	if f.get("action")=="list":return {"ok":true,"objects":objects(str(f.get("actor","")))}
	if f.get("action")=="import":
		if not f.get("images") is Dictionary or not f.get("spec") is Dictionary:return {"ok":false,"error":"缺少家具配置与图片"}
		var images:Dictionary={}
		for key in f.images:
			if not f.images[key] is String or f.images[key].length()>5600000:return {"ok":false,"error":"图片数据过大或无效"}
			images[key]=Marshalls.base64_to_raw(f.images[key])
		return import_asset(f.spec,images)
	return {"ok":false,"error":"未知家具操作"}
