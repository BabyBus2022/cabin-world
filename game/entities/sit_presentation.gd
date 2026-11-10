extends RefCounted
## Shared ordinary-chair presentation. No robot identity or room coordinates in the renderer.
const Rig=preload("res://entities/shared_sit.gd")
static var rig:RefCounted
static var bindings:Dictionary={}
static var textures:Dictionary={}

static func ready() -> void:
	if rig==null:
		rig=Rig.new()
		# Not inside assert(): release exports strip assert() and its argument, which left the rig unconfigured in every export.
		var issue:String=rig.configure("res://assets/shared-sit/sit-idle.json")
		if issue!="":push_error("shared sit manifest: "+issue)
		bindings=JSON.parse_string(FileAccess.get_file_as_string("res://assets/shared-sit/bindings.json"))

static func texture(path:String) -> Texture2D:
	if not textures.has(path):textures[path]=load(path)
	return textures[path]

static func resolve(avatar:String,scene:String,zone:String,effect:Dictionary,seconds:float,action:String,body:Dictionary,legacy:Dictionary) -> Dictionary:
	ready()
	if not rig.manifest.avatars.has(avatar):return legacy
	var room:Dictionary=WorldData.scenes.get(scene,{})
	var rule:Dictionary=bindings.scenes.get(scene,{}).get(zone,{})
	# Future furniture may carry its own seat metadata; no code branch needed.
	for module in room.get("modules",{}).values():
		for slot in module.get("sitting",{}).get("slots",{}).values():
			if slot.get("zone","")==zone:rule=slot.merged({"module":module.id},true)
	if rule.is_empty():return legacy
	var module:Dictionary=room.get("modules",{}).get(rule.get("module",""),{})
	# Stored furniture cannot leave a floating sitting pose behind.
	if module.is_empty():return {}
	var active:String=str(effect.get("kind","")) if seconds<float(effect.get("seconds",0)) else ""
	var requested:bool=active in rule.get("effects",[]) or action in rule.get("actions",[])
	var need:String=rule.get("needs","")
	if need!="":
		var keys:=need.split(".")
		requested=requested or (keys.size()==2 and body.get(keys[0],{}) is Dictionary and body.get(keys[0],{}).get(keys[1])==true)
	# Existing registered chair states (including the computer) remain authoritative.
	requested=requested or legacy.get("registered","")=="computer" or legacy.get("seat",false)
	if not requested:return legacy
	var p:Vector2
	if rule.get("use_zone_anchor",false):
		if not room.get("zones",{}).has(zone):return {}
		p=WorldData.point(room.zones[zone])
	elif rule.has("anchor"):
		p=Vector2(module.x+rule.anchor[0],module.y+rule.anchor[1])
	else:
		var a:Array=rule.anchor_ratio
		p=Vector2(module.x+module.w*a[0],module.y+module.h*a[1])
	var depth:float=p.y if rule.get("sort_at_anchor",false) else float(module.get("depth",p.y))
	var sample:Dictionary=rig.sample(avatar,{"anchor":[p.x,p.y],"facing":rule.facing,"depth":depth})
	if sample.error!="":return legacy
	var out:Dictionary={"sit_idle":sample,"feet":p,"sort":sample.sort,"seat":true,"still":true,"snap":true}
	if rule.has("front"):out.front=rule.front
	return out
