extends RefCounted
## Pure visual adapter: avatar keys, scene names and robot identities are not hard-coded.
## Physics/occupancy remains owned by the game. The caller has to claim and reach the chair first.
const DIRECTIONS := ["south","west","east","north"]
var manifest:Dictionary={}
var base_dir:=""

func configure(file:String) -> String:
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(file))
	if not parsed is Dictionary:return "Invalid sit manifest"
	var issue:=validate_manifest(parsed)
	if issue!="":return issue
	manifest=parsed.duplicate(true);base_dir=file.get_base_dir()
	return ""

static func pair(value:Variant) -> bool:
	return value is Array and value.size()==2 and value.all(func(n):return (n is float or n is int) and is_finite(float(n)))

static func validate_manifest(value:Dictionary) -> String:
	if value.get("format")!="cabinworld-avatar-action/1" or value.get("action")!="sit_idle":return "Unsupported action format"
	if not value.get("avatars") is Dictionary or value.avatars.is_empty():return "Missing avatars"
	for id in value.avatars:
		var avatar=value.avatars[id]
		if not avatar is Dictionary or not avatar.get("sheet") is String or avatar.sheet=="":return "Missing sheet: "+str(id)
		var scale_of=avatar.get("pixel_scale",0)
		if not (scale_of is int or scale_of is float) or not is_finite(float(scale_of)) or scale_of<=0:return "Invalid scale: "+str(id)
		if not avatar.get("frames") is Dictionary:return "Missing frames: "+str(id)
		for dir in DIRECTIONS:
			var frame=avatar.frames.get(dir)
			if not frame is Dictionary:return "Missing direction: "+str(id)+"/"+dir
			var rect=frame.get("rect")
			if not rect is Array or rect.size()!=4 or not rect.all(func(n):return (n is int or n is float) and is_finite(float(n))) or rect[0]<0 or rect[1]<0 or rect[2]<=0 or rect[3]<=0:return "Invalid frame rectangle"
			if not pair(frame.get("seat_anchor")):return "Invalid seat anchor"
			var anchor:Array=frame.seat_anchor
			if anchor[0]<0 or anchor[0]>rect[2] or anchor[1]<0 or anchor[1]>rect[3]:return "Seat anchor outside frame"
	return ""

## seat = {anchor:[world_x,world_y], facing:"south", depth:world_sort_y}
## Return offsets relative to the anatomical pelvis anchor, never the PNG bounding box.
func sample(avatar_key:String,seat:Dictionary) -> Dictionary:
	if not manifest.get("avatars",{}).has(avatar_key):return {"error":"Avatar has no sit_idle: "+avatar_key}
	var facing:String=str(seat.get("facing",""))
	if not facing in DIRECTIONS:return {"error":"Unsupported seat facing"}
	if not pair(seat.get("anchor")):return {"error":"Invalid world seat anchor"}
	var depth=seat.get("depth",seat.anchor[1])
	if not (depth is float or depth is int) or not is_finite(float(depth)):return {"error":"Invalid seat depth"}
	var avatar:Dictionary=manifest.avatars[avatar_key];var frame:Dictionary=avatar.frames[facing]
	var anchor:=Vector2(seat.anchor[0],seat.anchor[1]);var pelvis:=Vector2(frame.seat_anchor[0],frame.seat_anchor[1])
	var r:Array=frame.rect
	return {"error":"","action":"sit_idle","direction":facing,"sheet":base_dir.path_join(avatar.sheet),"region":Rect2(r[0],r[1],r[2],r[3]),"scale":float(avatar.pixel_scale),"anchor":anchor,"offset":-pelvis,"sort":float(depth)+0.05,"flip":false}

static func seat_from_module(module:Dictionary,slot:String) -> Dictionary:
	var row=module.get("sitting",{}).get("slots",{}).get(slot)
	if not row is Dictionary or not pair(row.get("anchor")):return {"error":"Missing registered seat slot"}
	var position=[module.get("x"),module.get("y")]
	if not pair(position):return {"error":"Invalid furniture position"}
	return {"anchor":[position[0]+row.anchor[0],position[1]+row.anchor[1]],"facing":row.get("facing",""),"depth":module.get("depth",position[1])}

static func apply_to(sprite:Sprite2D,value:Dictionary) -> void:
	# assert() is stripped in release exports; an error result must never reach load().
	if value.get("error","")!="" or not value.get("sheet") is String:return
	sprite.texture=load(value.sheet)
	sprite.centered=false;sprite.region_enabled=true;sprite.region_rect=value.region
	sprite.scale=Vector2.ONE*value.scale
	sprite.position=Vector2(value.anchor.x,value.sort)
	sprite.offset=value.offset+Vector2(0,(value.anchor.y-value.sort)/value.scale)
	sprite.flip_h=false;sprite.flip_v=false
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
