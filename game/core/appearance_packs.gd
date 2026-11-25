extends RefCounted
## Presentation only. Resident identity, world state and bot APIs are untouched.
const FORMAT := "cabin-appearance-v1"
static var _selected:Dictionary={}
static var _checked:int=-1000
static var _cache:Dictionary={}
static var _bindings:Array=[]
static var _old_bounds:Dictionary={}
static var _contact_bounds:Dictionary={}

static func visible_bounds(im:Image)->Rect2:
	# Nearly transparent matte residue must not count as feet or a chair contact.
	var mask:=BitMap.new();mask.create_from_image_alpha(im,0.125)
	var low:=Vector2(im.get_size());var high:=Vector2.ZERO;var found:bool=false
	for polygon in mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,im.get_size()),0.1):
		for p in polygon:low=low.min(p);high=high.max(p);found=true
	return Rect2(low,high-low) if found else Rect2(im.get_used_rect())

static func directory()->String:
	return Economy.save_path.get_base_dir().path_join("appearance")

static func read_json(path:String)->Dictionary:
	if not FileAccess.file_exists(path):return {}
	var data=JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

static func refresh()->void:
	var now:int=Time.get_ticks_msec()
	if now-_checked<500:return
	_checked=now
	_selected=read_json(directory().path_join("active.json"))

static func announce()->void:
	DirAccess.make_dir_recursive_absolute(directory().path_join("packs"))
	if OS.has_feature("editor"):return
	var people:Array=[]
	for r in Residents.people():people.append({"key":r.key,"name":str(r.get("name",r.key))})
	var marker:Dictionary={"format":FORMAT,"directory":ProjectSettings.globalize_path(directory()),"residents":people}
	var file:=FileAccess.open(OS.get_executable_path().get_base_dir().path_join("appearance-support.json"),FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(marker))

static func valid_id(value:String)->bool:
	if value.length()!=32:return false
	for c in value:
		if not c in "0123456789abcdef":return false
	return true

static func pack(resident:String)->Dictionary:
	refresh()
	var id:String=str(_selected.get(resident,""))
	if not valid_id(id):return {}
	if _cache.has(id):return _cache[id]
	var root:String=directory().path_join("packs").path_join(id)
	var data:Dictionary=read_json(root.path_join("appearance.json"))
	if data.get("format")!=FORMAT or not data.get("actions") is Dictionary:return {}
	data["root"]=root;data["textures"]={}
	_cache[id]=data
	return data

static func safe_frame(path:String)->bool:
	return path.begins_with("actions/") and path.ends_with(".png") and not ".." in path and not "\\" in path and not ":" in path

static func sample(resident:String,action:String,seconds:float)->Dictionary:
	var data:Dictionary=pack(resident)
	if data.is_empty():return {}
	var spec=data.actions.get(action)
	if not spec is Dictionary:return {}
	var frames=spec.get("frames");var durations=spec.get("durationsMs")
	if not frames is Array or not durations is Array or frames.is_empty() or frames.size()>120 or frames.size()!=durations.size():return {}
	var total:float=0
	for ms in durations:
		if not (ms is float or ms is int) or not is_finite(ms) or ms<20 or ms>10000:return {}
		total+=float(ms)
	var t:float=maxf(0,seconds)*1000
	t=fmod(t,total) if spec.get("loop",true) else minf(t,total-0.001)
	var index:int=0
	while index<frames.size()-1 and t>=float(durations[index]):
		t-=float(durations[index]);index+=1
	if not frames[index] is String or not safe_frame(frames[index]):return {}
	var path:String=data.root.path_join(frames[index])
	if not data.textures.has(path):
		if not FileAccess.file_exists(path):return {}
		var im:=Image.load_from_file(path)
		if im==null or im.is_empty() or im.get_width()>2048 or im.get_height()>2048:return {}
		data.textures[path]=ImageTexture.create_from_image(im)
	var bounds=spec.get("bounds")
	if not bounds is Array or bounds.size()!=4:return {}
	for n in bounds:
		if not (n is float or n is int) or not is_finite(n):return {}
	if bounds[2]<=0 or bounds[3]<=0:return {}
	if not spec.has("_visible_bounds"):
		var combined:=Rect2()
		for frame_path in frames:
			if not frame_path is String or not safe_frame(frame_path):return {}
			var frame:=Image.load_from_file(data.root.path_join(frame_path))
			if frame==null or frame.is_empty() or frame.get_width()>2048 or frame.get_height()>2048:return {}
			var visible:=visible_bounds(frame)
			combined=visible if combined.size==Vector2.ZERO else combined.merge(visible)
		spec["_visible_bounds"]=combined
	var result:Dictionary={"texture":data.textures[path],"bounds":spec._visible_bounds,"index":index,"action":action}
	var calibration=spec.get("sizeCalibration",{})
	if calibration is Dictionary and calibration.get("anchor") is Array and calibration.anchor.size()==2:
		var valid:bool=true
		for n in calibration.anchor:
			if not (n is float or n is int) or not is_finite(n):valid=false
		if valid:
			var at:=Vector2(float(calibration.anchor[0]),float(calibration.anchor[1]))
			if at.x>=0 and at.y>=0 and at.x<=data.textures[path].get_width() and at.y<=data.textures[path].get_height():
				result["calibrated"]=true;result["calibration_anchor"]=at;result["anchor_kind"]=calibration.get("anchorKind","ground")
	return result

static func binding(tex:Texture2D,region:Rect2,art:String)->String:
	if tex==null:return ""
	if _bindings.is_empty():
		var value=JSON.parse_string(FileAccess.get_file_as_string("res://assets/appearance-bindings.json"))
		if value is Array:_bindings=value
	var path:String=tex.resource_path.trim_prefix("res://assets/")
	if art!="xiaojingyu":path=path.replace(art,"xiaojingyu")
	for item in _bindings:
		var r:Array=item.rect
		if item.file==path and absf(region.position.x-r[0])<1.1 and absf(region.position.y-r[1])<1.1 and absf(region.size.x-r[2])<1.1 and region.size.y<=float(r[3])+1.1:return item.action
	return ""

static func fit(sample_data:Dictionary,tex:Texture2D,region:Rect2,anchor:Vector2,k:float)->Dictionary:
	var cache_key:String=tex.resource_path+":"+sample_data.action
	if not _old_bounds.has(cache_key):
		var im:=tex.get_image()
		if im==null:return {}
		if im.is_compressed():im.decompress()
		_old_bounds[cache_key]=Rect2(im.get_region(Rect2i(region)).get_used_rect())
	var old:Rect2=_old_bounds[cache_key];var box:Rect2=sample_data.bounds
	if old.size.x<=0 or old.size.y<=0:return {}
	var scale:float=absf(k)*minf(old.size.x/box.size.x,old.size.y/box.size.y)
	if scale<=0:return {}
	var offset:=Vector2(box.get_center().x,box.end.y)-Vector2(old.get_center().x-anchor.x,old.end.y-anchor.y)*absf(k)/scale
	return {"texture":sample_data.texture,"region":Rect2(Vector2.ZERO,sample_data.texture.get_size()),"anchor":offset,"scale":scale*signf(k)}


static func body_fit(sample_data:Dictionary,tex:Texture2D,region:Rect2,anchor:Vector2,k:float,standing_scale:float,seated:bool=false)->Dictionary:
	# An action silhouette is NOT a character-size ruler. Phone, arm extension,
	# crouching and different old atlas resolutions must not resize the body.
	var box:Rect2=sample_data.bounds
	var pixels:float=sample_data.texture.get_width()
	if pixels<=0 or standing_scale<=0:return {}
	var calibrated:bool=sample_data.get("calibrated",false)
	var scale:float=standing_scale*(1.0 if calibrated else 320.0/pixels)
	var cache_key:String=str(tex.get_instance_id())+":"+str(region)
	if seated and not _contact_bounds.has(cache_key):
		var im:=tex.get_image()
		if im==null:return {}
		if im.is_compressed():im.decompress()
		_contact_bounds[cache_key]=visible_bounds(im.get_region(Rect2i(region)))
	var offset:Vector2=sample_data.get("calibration_anchor",Vector2(box.get_center().x,box.end.y))
	# A ground anchor is absolute: never add offsets from a different old drawing.
	# Seats locate the pelvis, not the soles. Transfer the contact within the
	# visible pose, without changing the already fixed character scale.
	if seated and not (calibrated and sample_data.get("anchor_kind")=="seat"):
		var old:Rect2=_contact_bounds[cache_key]
		if old.size.x>0 and old.size.y>0:offset=box.position+(anchor-old.position)/old.size*box.size
	return {"texture":sample_data.texture,"region":Rect2(Vector2.ZERO,sample_data.texture.get_size()),"anchor":offset,"scale":scale*signf(k)}

static func layer_fit(sample_data:Dictionary,tex:Texture2D,region:Rect2,at:Rect2,standing_scale:float)->Dictionary:
	if not sample_data.get("calibrated",false) or region.size.x<=0 or region.size.y<=0 or standing_scale<=0:return {}
	var im:=tex.get_image()
	if im==null:return {}
	if im.is_compressed():im.decompress()
	var old:=Rect2(im.get_region(Rect2i(region)).get_used_rect())
	# Bed/desk rectangles determine contact location, never character pixel size.
	return {"texture":sample_data.texture,"region":Rect2(Vector2.ZERO,sample_data.texture.get_size()),
		"anchor":sample_data.calibration_anchor,"scale":Vector2.ONE*standing_scale,
		"position":at.position+Vector2(old.get_center().x,old.end.y)*at.size/region.size}

static func choices()->Array:
	var result:Array=[];var folder:String=directory().path_join("packs")
	for id in DirAccess.get_directories_at(folder):
		if not valid_id(id):continue
		var m:Dictionary=read_json(folder.path_join(id).path_join("appearance.json"))
		if m.get("format")==FORMAT:result.append({"id":id,"name":str(m.get("name",id))})
	return result

static func select(resident:String,id:String)->Error:
	if id!="" and not valid_id(id):return ERR_INVALID_DATA
	var active:Dictionary=read_json(directory().path_join("active.json"));active[resident]=id
	var path:String=directory().path_join("active.json")
	var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return ERR_CANT_CREATE
	file.store_string(JSON.stringify(active));file.close()
	var err:=DirAccess.rename_absolute(path+".tmp",path)
	_checked=-1000;refresh();return err
