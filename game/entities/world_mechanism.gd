class_name WorldMechanism
extends Node2D
## Original moving furniture, synchronized with WorldPresentation's seat transforms.
var scene := ""
var module := {}
var clock := 0.0
static var textures := {}

static func texture(file: String) -> Texture2D:
	if not textures.has(file): textures[file] = load("res://assets/world/"+file)
	return textures[file]

static func mount(room: Node2D, scene_id: String) -> void:
	var info: Dictionary = WorldPresentation.facts().scenes.get(scene_id,{})
	for m in info.get("modules",{}).values():
		if not m.id in ["swing","seesaw","rider","carousel"] and m.get("kind")!="world-curtain": continue
		var node := WorldMechanism.new()
		node.scene = scene_id
		node.module = m
		node.position.y = m.depth
		room.add_child(node)

func _process(delta: float) -> void:
	clock += delta
	if is_visible_in_tree(): queue_redraw()

func _draw() -> void:
	var active: Character
	for resident in get_tree().get_nodes_in_group("world_residents"):
		# All instances share the same running animation clock, even in rooms off screen.
		clock = resident._time
		if resident.scene_id!=scene or resident.is_walking() or resident._effect_active()=="": continue
		if module.get("kind")=="world-curtain":
			if resident.effect.get("kind")=="shower" and resident.effect.get("slot")==module.slot: active=resident
		elif resident.effect.get("module")==module.id: active=resident
	var t := clock if active!=null else 0.0
	var m := module
	var data := WorldPresentation.facts()
	draw_set_transform(Vector2(0,-position.y))
	if m.get("kind")=="world-curtain":
		if active==null: return
		var curtain: Dictionary = data.curtains
		var row := int(Residents.person(active.key).get("curtain_row",0))
		draw_texture_rect_region(texture(curtain.file),Rect2(m.x,m.y,m.w,m.h),Rect2((int(clock*1.5)%4)*curtain.w,row*curtain.h,curtain.w,curtain.h))
		return
	if m.id in ["rider","carousel"]:
		var row := 1 if m.id=="rider" else 0
		var b: Dictionary = data.bounds[row]
		var r: Array = data.mechanism.cellRects[row*4+int(t*4)%4]
		var sx: float = m.w/b.w
		var sy: float = m.h/b.h
		draw_texture_rect_region(texture(data.mechanism.file),Rect2(m.x-b.x*sx,m.y-b.y*sy,r[2]*sx,r[3]*sy),Rect2(r[0],r[1],r[2],r[3]))
		return
	draw_texture_rect(texture(data.modules[m.art].file),Rect2(m.x,m.y,m.w,m.h),false)
	if m.id=="seesaw":
		var art: Dictionary = data.modules["seesaw-plank"]
		var w := 180*.625
		var h: float = w*art.nativeSize[1]/art.nativeSize[0]
		draw_set_transform(Vector2(m.x+m.w/2,m.y+m.h-14*.625-position.y),WorldPresentation.phase(t)*.7)
		draw_texture_rect(texture(art.file),Rect2(-w/2,-20*.625,w,h),false)
	elif m.id=="swing":
		var seat := WorldPresentation.mechanism_seat(m,"swing",t)
		var art: Dictionary = data.modules["swing-seat"]
		var w := 58*.625
		for side in [-1,1]: draw_line(Vector2(m.x+m.w/2+side*16,m.y+9),seat+Vector2(side*w*.36,0),Color("777067"),1)
		draw_texture_rect(texture(art.file),Rect2(seat.x-w/2,seat.y-3,w,art.worldSize[1]*.625),false)
