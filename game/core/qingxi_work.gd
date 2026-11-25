extends RefCounted
const ExternalAppearance=preload("res://core/appearance_packs.gd")
# Find the same world-space interaction points the player's E key uses.
static func target(host, scene, action:String, arg:String, spot:String, start:Vector2)->Vector2:
	if spot in ["qx_seedshop","qx_livestockshop"]:
		for point in scene.points:
			if point.type==("grow" if action=="water_seedlings" else "shop"):return point.p
		return Vector2.INF
	if host.resident_rooms.SPOTS.has(action):
		var dest=host.resident_rooms.nearby(scene,action,arg,start)
		return dest if dest!=null else Vector2.INF
	if action in ["enter_room","visit_home"]:
		var door=host.resident_rooms.door(scene,arg)
		if door!=null:return door
	if action in ["build_at","remove_at"] and arg.get_slice("|",0)==scene.get("map_id"):
		var at=preload("res://core/resident_editor.gd").point(arg)
		if at!=null:return at
	var parts=arg.replace("，",":").replace(",",":").split(":")
	if action in ["till","dig","fence","unfence","gate","build_pen","place_feeder"]:
		if not parts.is_empty() and not str(parts[0]).is_valid_int():parts.remove_at(0)
		if parts.size()>=2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			return (Vector2(int(parts[0]),int(parts[1]))+Vector2(.5,.5))*64
	if action in ["plant","water","water_plot","harvest"] and not scene.fields.is_empty():
		var ids=host._plot_indices(scene.sim,{"plots":scene.fields},arg)
		for i in ids:
			if i>=scene.sim.data.crops.size():continue
			var crop=scene.sim.data.crops[i]
			var ripe:bool=crop.planted and float(crop.progress)>=scene.sim.CROP_SECONDS
			if (action=="plant" and not crop.planted) or (action=="water" and crop.planted and not ripe and float(crop.water)<scene.sim.CROP_SECONDS-float(crop.progress)) or (action=="harvest" and ripe):
				return scene.fields[i].rect.get_center()
		if not ids.is_empty():return scene.fields[ids[0]].rect.get_center()
	if action in ["follow_pet","stay_pet","play_pet","feed_pet","walk_pet","name_pet"] and scene.get("herd_ai")!=null:
		var id=arg.get_slice(":",0)
		var pet=host._pet_target(scene.sim.pet_roster(),id)
		var actor=scene.herd_ai.pet_actors.get(str(pet.get("id","")),{})
		if is_instance_valid(actor.get("node")) and actor.node.is_visible_in_tree():return actor.node.position
		if action in ["follow_pet","stay_pet"]:return Vector2.INF
	if action=="river_fish":
		var banks=scene.targets.filter(func(i):return i.kind=="river_fishing")
		banks.sort_custom(func(a,b):return start.distance_squared_to(a.pos)<start.distance_squared_to(b.pos))
		for bank in banks:
			var route=walking_path(scene,start,bank.pos)
			if not route.is_empty() and route[-1].distance_to(bank.pos)<58:return bank.pos
		return Vector2.INF
	if action=="walk_to":
		var point=preload("res://core/resident_editor.gd").point("ranch||"+arg)
		if point==null or not scene.world_bounds().has_point(point):return Vector2.INF
		return point
	if action=="swim":
		var water=scene.get("ground_tiles")
		if water==null:return Vector2.INF
		var nearest=Vector2.INF
		for cell in water.swim_cells:
			var p=(Vector2(cell)+Vector2(.5,.5))*water.SIDE
			if start.distance_squared_to(p)<start.distance_squared_to(nearest):nearest=p
		return nearest
	if action in ["hold_food","stand_up"]:return start
	var types:Array
	match action:
		"farm_bench":types=["meadow_seat"]
		"sell":types=["ship"]
		"take_honey":types=["hive"]
		"dry_fish":types=["dry_fish"]
		"fill_water":types=["well"]
		"cook","cook_fish","store","take","mill":types=["home","mill"]
		"adopt_pet","name_pet","feed_pet","play_pet","walk_pet":types=["pet","pet_adopt"]
		_:types=["pen","portal"]
	var kind=host._arg_kind(arg.split("×")[0])
	if action in ["collect","treat","pair","sell_animal","pair_free","pair_pause","process_stock"] and scene.get("herd_ai")!=null:
		var id=arg.replace("，",",").get_slice(",",0).strip_edges()
		var animal:Dictionary=scene.sim.livestock.animal(id) if id!="" else {}
		if id!="" and animal.is_empty():return Vector2.INF
		var near=Vector2.INF
		for a in scene.sim.livestock.data.herd:
			if (not animal.is_empty() and a.id!=animal.id) or (kind!="" and a.kind!=kind):continue
			var actor:Dictionary=scene.herd_ai.actors.get(a.id,{})
			if actor.has("node") and actor.node.is_visible_in_tree() and start.distance_squared_to(actor.node.position)<start.distance_squared_to(near):
				near=actor.node.position
		if near!=Vector2.INF:return near
		if id!="":return Vector2.INF
	var best=Vector2.INF
	var rank=99
	for item in scene.targets:
		var priority=types.find(str(item.kind))
		if priority<0 or priority>rank:continue
		var extra=str(item.get("extra",""))
		if action in ["dry_fish","take_honey"] and arg!="" and arg!=extra and not extra.ends_with(":"+arg):continue
		if item.kind=="portal" and extra!="barn":continue
		var p:Vector2=item.pos
		if priority<rank or start.distance_squared_to(p)<start.distance_squared_to(best):
			best=p;rank=priority
	if best!=Vector2.INF:return best
	if action in ["sell","farm_bench","fill_water"]:return Vector2.INF
	# A free-range release needs no fixture. Use open ground beside the resident.
	return start+Vector2(48,24)

static func walking_path(scene,start:Vector2,end:Vector2)->PackedVector2Array:
	var farm=scene.get("player_moving")!=null
	var previous=scene.get("player_moving")
	if farm:scene.player_moving=true
	var route=path(scene,start,end)
	if farm:scene.player_moving=previous
	return route

static func direct(scene,a:Vector2,b:Vector2)->bool:
	var n=maxi(1,ceili(a.distance_to(b)/5.))
	for i in range(1,n+1):
		if scene.blocked(a.lerp(b,float(i)/n)):return false
	return true

static func path(scene,start:Vector2,target_:Vector2)->PackedVector2Array:
	var goals=[]
	for offset in [Vector2.ZERO,Vector2(0,22),Vector2(0,42),Vector2(-32,16),Vector2(32,16),Vector2(0,-30),Vector2(48,32),Vector2(-48,32)]:
		var p=target_+offset
		if not scene.blocked(p):
			if direct(scene,start,p):return PackedVector2Array([p])
			goals.append(p)
	if goals.is_empty():return PackedVector2Array()
	if scene.get("herd_ai")!=null and scene.herd_ai.has_method("route_to_points"):
		return scene.herd_ai.route_to_points(start,goals)
	# Shop shelves can separate a visitor from the till. Search walkable aisle centres.
	var first:=Vector2i((start/16.).round())
	var todo:Array[Vector2i]=[]
	var prev={}
	for d in [Vector2i.ZERO,Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
		var cell:Vector2i=first+d
		if direct(scene,start,Vector2(cell)*16):todo.append(cell);prev[cell]=cell
	var i=0
	while i<todo.size():
		var at:Vector2i=todo[i];i+=1
		var p:=Vector2(at)*16
		for goal in goals:
			if p.distance_to(goal)<=28 and direct(scene,p,goal):
				var result:=PackedVector2Array([goal,p])
				while prev[at]!=at:
					at=prev[at];result.append(Vector2(at)*16)
				result.reverse();return result
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var cell:Vector2i=at+d
			if prev.has(cell) or not direct(scene,p,Vector2(cell)*16):continue
			prev[cell]=at;todo.append(cell)
	return PackedVector2Array()

static func animate(c,sprite:Sprite2D,velocity:Vector2,k:float,walking:=true):
	var row:int=(1 if velocity.x<0 else 2) if absf(velocity.x)>absf(velocity.y) else (3 if velocity.y<0 else 0)
	var index=row*4+(int(Time.get_ticks_msec()/135)%4 if walking else 0)
	var r:Array=c._walk.rects[index]
	var anchor:Array=c._walk.anchors[index]
	var region:=Rect2(r[0],r[1],r[2],r[3])
	var offset:=Vector2(anchor[0],anchor[1])
	# The village visitor follows its own route while the cabin body can be standing.
	var elapsed:float=c._time if walking else 0.0
	var direction:int=preload("res://entities/body_language.gd").octant(velocity)
	var sample:Dictionary=ExternalAppearance.sample(c.key,"walk8-"+str(direction),elapsed)
	if sample.is_empty():sample=ExternalAppearance.sample(c.key,"walk-"+str(row),elapsed)
	var tex=c._walk_tex
	var scale_:float=c._walk.scale
	if not sample.is_empty():
		var fit=ExternalAppearance.body_fit(sample,tex,region,offset,scale_,scale_,false)
		if not fit.is_empty():
			tex=fit.texture;region=fit.region;offset=fit.anchor;scale_=fit.scale
	sprite.texture=tex;sprite.region_enabled=true;sprite.region_rect=region
	sprite.centered=false;sprite.offset=-offset;sprite.flip_h=false;sprite.flip_v=false
	sprite.scale=Vector2.ONE*k*scale_;sprite.position=Vector2.ZERO;sprite.show()
