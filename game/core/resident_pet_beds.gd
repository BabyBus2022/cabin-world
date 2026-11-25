extends RefCounted
const Comfort=preload("res://core/pet_comfort.gd")
const Store=preload("res://qingxi-live/cottage_lodging.gd")
const FILE="house-pet-beds.json"
var mounted={}
var state:Dictionary
var loaded=false
func load_state(host):
	if not loaded:
		state=Store.data(host.profile_path(FILE));loaded=true
func spots(scene:String)->Dictionary:
	var result={}
	for id in state.get(scene,{}):
		var xy=state[scene][id]
		if xy is Array and xy.size()==2:result[id]=Vector2(xy[0],xy[1])
	for layer in WorldData.layers.get(scene,{}).get("layers",[]):
		if str(layer.get("file",""))=="pet-sleep-basket.png":
			result["furniture:"+str(layer.id)]=Vector2(layer.x+layer.w*0.5,layer.y+layer.h*0.6)
	return result
func draw_rooms(host):
	load_state(host)
	for scene in state:
		var parent=host.game.rooms.get(scene)
		if not is_instance_valid(parent) or not parent._built:continue
		var old=mounted.get(scene,{})
		if is_instance_valid(old.get("container")) and old.container.get_parent()==parent._floor:continue
		var container=Node2D.new()
		container.name="PetBaskets";parent._floor.add_child(container)
		mounted[scene]={"container":container}
		for raw in state[scene].values():
			var pos=Vector2(raw[0],raw[1])
			var bed=Sprite2D.new()
			bed.texture=Comfort.texture();bed.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			bed.scale=Vector2.ONE*60./bed.texture.get_width()
			bed.position=pos+Vector2(0,-5);container.add_child(bed)

func arrange(host,who:String,action:String,arg:String,out:Dictionary)->String:
	var resident=host._resident(who)
	var home=str(Residents.person(who).get("home",{}).get("scene",""))
	if not is_instance_valid(resident) or home=="" or resident.scene_id!=home or resident.is_walking():return "请先走到自己的小屋。"
	load_state(host)
	var slots=spots(home)
	var id=arg.strip_edges()
	var next=state.duplicate(true)
	if not next.has(home):next[home]={}
	if action=="list_beds":
		out.text="自家宠物床："+str(slots)+"。放置可留空或写世界像素 横:纵；收起请写床号。";return ""
	if action=="remove_bed":
		if id.begins_with("furniture:"):return "请在家具布置里收起这只睡篮。"
		if not slots.has(id):return "请选择已有床号："+str(slots.keys())
		next[home].erase(id)
	else:
		var nav=WorldData.nav(home)
		var center:Vector2=resident.feet
		if arg!="":
			var parts=arg.split(":")
			if parts.size()!=2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():return "位置写横:纵，或留空选择身边空地。"
			center=Vector2(int(parts[0]),int(parts[1]))
		var found=Vector2.INF
		for offset in ([Vector2.ZERO] if arg!="" else [Vector2(-45,18),Vector2(45,18),Vector2(0,40),Vector2(-60,-20),Vector2(60,-20),Vector2.ZERO]):
			var p=center+offset
			if slots.values().any(func(other):return p.distance_to(other)<54):continue
			if [Vector2.ZERO,Vector2(-22,-9),Vector2(22,-9),Vector2(-22,9),Vector2(22,9)].all(func(d):return nav.walkable(p+d)) and not nav.route(resident.feet,p).is_empty():
				found=p;break
		if found==Vector2.INF:return "床需要整块能走到的空地，请换个位置。"
		var i=1
		while slots.has(str(i)):i+=1
		id=str(i);next[home][id]=[found.x,found.y]
	if not Store.commit(host.profile_path(FILE),next):return "床位未能保存。"
	state=next
	if mounted.has(home):
		if is_instance_valid(mounted[home].container):mounted[home].container.free()
		mounted.erase(home)
	draw_rooms(host)
	out.text=("已收起" if action=="remove_bed" else "已放好")+"宠物床 #"+id+"。";return ""
