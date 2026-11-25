extends "res://qingxi-live/farm_animals.gd"
## Ranch animals on the player's grid layout (region.gd). Each kind walks the cells of
## the enclosure holding its feeder (A* on a 12px grid), eats at that feeder, drinks at
## the creek bank, and at night walks through the barn passage into the barn, coming
## back out in the morning. Kinds without a placed feeder stay inside the barn.
##
## 2026-11-21 pets: 猫和狗也住在这张农场上，但它们不进圈舍、不走 A*：
##   * 场景里最多同时画 display.max_actors 只（其余仍在读数和存档里，数量上限本身没有）；
##   * 猫会自己出门（节点隐藏）再回来；狗会跟着你、夜里回门口看家；
##   * 名牌写「名字」+ 现在的状态；它们的位置/状态都由 pets.gd 的判据决定，表现层只照着画。
const BreedSprite=preload("res://qingxi-live/village-center/breed_sprite.gd")
const PetSprite=preload("res://qingxi-live/village-center/pet_sprite.gd")
const PetRules=preload("res://qingxi-live/village-center/pets_rules.gd")
const GRID=12
var grids={}
var points={}
var drinking_spots={}
var shore_points:Array[Vector2]=[]
var shore_dirty:=true
var pet_actors={}
var pet_tick_clock=0.0

func reset():
	super.reset()
	grids.clear()
	points.clear()
	drinking_spots.clear();shore_dirty=true
	_pet_clear()
func _pet_clear():
	for id in pet_actors.keys():
		var node=pet_actors[id].get("node")
		if is_instance_valid(node):node.queue_free()
	pet_actors.clear()
func garden_model(_node:Node2D,a:Dictionary):return BreedSprite.new(a)
func yard(kind:String)->String:return kind
func on_ranch()->bool:return world.region!=null and world.region.id=="ranch"
func herd_blocked(p:Vector2)->bool:
	return world.livestock_blocked(p) if world.has_method("livestock_blocked") else world.blocked(p)

func deep_water(p:Vector2)->bool:
	return on_ranch() and world.has_method("deep_for_herd") and world.deep_for_herd(p)

func nearest_wading_spot(p:Vector2,a:Dictionary)->Vector2:
	var center=Vector2i((p/64.).floor())
	var bounds=world.region.zone()
	for radius in range(1,ceili(maxf(bounds.size.x,bounds.size.y)/64.)+1):
		var best=Vector2.INF
		var distance=INF
		for y in range(-radius,radius+1):
			for x in range(-radius,radius+1):
				if maxi(absi(x),absi(y))!=radius:continue
				var point=(Vector2(center+Vector2i(x,y))+Vector2(.5,.5))*64.
				if bounds.has_point(point) and point.distance_squared_to(p)<distance and not herd_blocked(point):
					best=point;distance=point.distance_squared_to(p)
		if best!=Vector2.INF:return best
	return outdoor_spot(a)
func on_barn()->bool:return world.region!=null and world.region.id=="barn"
## Half body length / depth used to keep animals from walking into each other.
const BODY={"cow":26.0,"sheep":23.0,"pig":21.0,"chicken":10.0}
func body(a:Dictionary)->float:return BODY[a.kind]*(1.0 if world.sim.livestock.adult(a) else .65)
func movement_rect(kind:String)->Rect2:
	if not on_ranch():return Herd.pen("pig" if kind=="chicken" else kind)
	return world.region.pens().get(kind,Rect2(world.region.barn_door()+Vector2(-60,-40),Vector2(120,30)))
func cell(p:Vector2)->Vector2i:return Vector2i((p/GRID).round())
func homeless(kind:String)->bool:return on_ranch() and not world.region.home.has(kind)
func night()->bool:
	var h=world.sky_value()*24.0
	return h>=19.5 or h<6.0
func passage_point()->Vector2:return Vector2(world.region.passage())*64+Vector2(32,36)
## Called by region.refresh_ranch() after fences or feeders change.
func layout_changed():
	for actor in actors.values():actor.erase("loose_goal")
	grids.clear();points.clear();drinking_spots.clear();shore_dirty=true
	for actor in actors.values():actor.erase("shore_route");actor.erase("shore_retry");actor.erase("shore_return_path")
	for actor in actors.values():actor.erase("barn_path");actor.erase("retry_at")
	for a in world.sim.livestock.data.herd:
		if not actors.has(a.id):continue
		var actor:Dictionary=actors[a.id]
		actor.path=PackedVector2Array();actor.erase("dest")
		if actor.get("barn","out")=="out" and not homeless(a.kind) and not a.get("barn_transit",false):
			actor.node.position=clamp_point(Vector2(a.pos[0],a.pos[1]),a.kind);actor.goal=actor.node.position
func make_grid(kind:String):
	var bounds=movement_rect(kind)
	var grid=AStarGrid2D.new()
	grid.region=Rect2i(cell(bounds.position)-Vector2i.ONE,Vector2i((bounds.size/GRID).ceil())+Vector2i(3,3))
	grid.cell_size=Vector2(GRID,GRID)
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var allowed={}
	for c in world.region.pen_cells()[kind]:allowed[Vector2i(c[0],c[1])]=true
	var open=[]
	for y in range(grid.region.position.y,grid.region.end.y):
		for x in range(grid.region.position.x,grid.region.end.x):
			var c=Vector2i(x,y)
			var p=Vector2(c)*GRID
			var inside=allowed.has(Vector2i((p/64).floor()*64))
			if inside and not herd_blocked(p):open.append(p)
			else:grid.set_point_solid(c)
	# Only the part reachable from the feeder counts (a feeder may cut a cell in two).
	if world.region.troughs.has(kind) and not open.is_empty():
		var anchor:Vector2=world.region.troughs[kind].food+Vector2(0,12)
		var start=open[0];var best=INF
		for point in open:
			if point.distance_squared_to(anchor)<best:
				start=point;best=point.distance_squared_to(anchor)
		var queue=[cell(start)];var seen={cell(start):true};var head=0
		while head<queue.size():
			var at:Vector2i=queue[head];head+=1
			for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
				var to:Vector2i=at+d
				if seen.has(to) or not grid.region.has_point(to) or grid.is_point_solid(to):continue
				seen[to]=true;queue.append(to)
		for i in range(open.size()-1,-1,-1):
			var id=cell(open[i])
			if not seen.has(id):grid.set_point_solid(id);open.remove_at(i)
	grids[kind]=grid
	points[kind]=open
	if not world.region.troughs.has(kind):return
	var trough:Dictionary=world.region.troughs[kind]
	var banks:Array=world.region.river_banks(kind)
	var spots:Array[Vector2]=[]
	for bank in banks:
		var spot:Vector2=(bank/GRID).round()*GRID
		var id=cell(spot)
		if grid.region.has_point(id) and not grid.is_point_solid(id) and not spots.has(spot):spots.append(spot)
	spots.sort_custom(func(a,b):return a.distance_squared_to(trough.food)<b.distance_squared_to(trough.food))
	drinking_spots[kind]=spots
	world.sim.livestock.data.pens[kind].creek=not spots.is_empty()
func clamp_point(p:Vector2,kind:String)->Vector2:
	if not on_ranch() or homeless(kind):return movement_rect(kind).get_center()
	if not grids.has(kind):make_grid(kind)
	var grid:AStarGrid2D=grids[kind]
	var id=cell(p)
	if grid.region.has_point(id) and not grid.is_point_solid(id) and not herd_blocked(p):return p
	if points[kind].is_empty():return movement_rect(kind).get_center()
	var best=Vector2.INF
	for point in points[kind]:
		if p.distance_squared_to(point)<p.distance_squared_to(best):best=point
	return best
func random_goal(kind:String)->Vector2:
	if not on_ranch() or homeless(kind):return movement_rect(kind).get_center()
	if not grids.has(kind):make_grid(kind)
	if points[kind].is_empty():return movement_rect(kind).get_center()
	return points[kind][rng.randi_range(0,points[kind].size()-1)]
## Feeding places go round the feeder (front pair, back pair, both ends); drinking
## places spread along the bank. One animal per place, so nobody stands in another.
func station_goal(a:Dictionary,need:String)->Vector2:
	var flock=world.sim.livestock.members(a.kind)
	var slot=maxi(0,flock.find(a))
	if not grids.has(a.kind):make_grid(a.kind)
	var banks:Array=drinking_spots.get(a.kind,[])
	if need=="drink" and not banks.is_empty():
		return banks[slot%banks.size()]
	var center:Vector2=world.region.troughs[a.kind][need]
	var w=float(world.region.FEEDER_SIZE[a.kind])
	var spot:Vector2
	if need=="food":
		var places=[Vector2(-w*.3,26),Vector2(w*.3,26),Vector2(-w*.3,-44),Vector2(w*.3,-44),Vector2(-w*.5-22,-8),Vector2(w*.5+22,-8)]
		spot=center+places[slot%places.size()]+Vector2(0,10*(slot/places.size()))
	else:
		var along=[0,1,-1,2,-2,3]
		spot=center+Vector2(along[slot%along.size()]*body(a)*1.6,(slot/along.size())*14)
	return clamp_point(spot,a.kind)
## Straight walk (barn doorway and passage, which are off the pasture grid).
func walk_to(actor:Dictionary,a:Dictionary,target:Vector2,dt:float)->bool:
	var node:Node2D=actor.node
	var speed=float({"cow":28,"sheep":33,"pig":30,"chicken":40}[a.kind])
	actor.moving=node.position.distance_to(target)>1.0
	if actor.moving:actor.heading=node.position.direction_to(target)
	var next=node.position.move_toward(target,dt*speed)
	if on_ranch():
		var steps=maxi(1,ceili(node.position.distance_to(next)/8.))
		for i in range(1,steps+1):
			if deep_water(node.position.lerp(next,float(i)/steps)):
				actor.moving=false
				actor.erase("loose_goal")
				return false
	node.position=next
	return node.position.distance_to(target)<2.0
## During the commute animals can use the same wooden gates as a walker.
## Ordinary grazing still uses the enclosure-only grid.
func clear_walk(a:Vector2,b:Vector2)->bool:
	var samples=maxi(1,ceili(a.distance_to(b)/7.0))
	for i in range(1,samples+1):
		if herd_blocked(a.lerp(b,float(i)/samples)):return false
	return true

func barn_route(start:Vector2,goal:Vector2)->PackedVector2Array:
	return route_to_points(start,[goal])

## Locate real dry approaches. An isolated pond without a species feeder still has banks.
func natural_banks()->Array[Vector2]:
	if not shore_dirty:return shore_points
	shore_dirty=false;shore_points.clear()
	var ground=world.get("ground_tiles")
	var wet={}
	if is_instance_valid(ground):
		for c in ground.cells:
			if ground.cells[c]=="channel":wet[c]=true
	else:
		for y in range(world.region.rows().x,world.region.rows().y):
			for x in range(world.region.cols().x,world.region.cols().y):
				var c=Vector2i(x,y)
				if world.region.cell_water(c):wet[c]=true
	for c in wet:
		for d in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			if wet.has(c+d):continue
			if world.region.ranch().edges.get(world.region.edge_key_between(c,c+d),"")=="fence":continue
			var p=(Vector2(c)+Vector2(.5,.5))*64+Vector2(d)*44
			if not herd_blocked(p):shore_points.append(p)
	var ponds=world.get("waters")
	if ponds is Dictionary:
		for pond in ponds.values():
			for i in pond.shore.size():
				var edge:Vector2=pond.shore[i].lerp(pond.shore[(i+1)%pond.shore.size()],.5)
				var bank:Vector2=edge+pond.bank_center.direction_to(edge)*12
				if not herd_blocked(bank):shore_points.append(bank)
	return shore_points

func seek_shore(a:Dictionary,actor:Dictionary,dt:float)->bool:
	if a.drink>=90 or (not actor.has("shore_route") and a.drink>world.sim.livestock.SEEK_AT):
		if actor.has("shore_route"):
			actor.erase("shore_route")
			actor.return_from_bank=true
		return false
	if actor.get("shore_retry",0.0)>0:
		actor.shore_retry-=dt;return false
	if not actor.has("shore_route"):
		var pos:Vector2=actor.node.position
		var choices=natural_banks().duplicate()
		choices.sort_custom(func(left,right):return pos.distance_squared_to(left)<pos.distance_squared_to(right))
		var route=route_to_points(pos,choices)
		if route.is_empty():actor.shore_retry=6.0;return false
		actor.shore_route=route
	var path:PackedVector2Array=actor.shore_route
	actor.moving=false
	if path.size()==1 and actor.node.position.distance_to(path[0])<=5:
		actor.mode="喝水"
		world.sim.livestock.data.pens[a.kind].creek=true
		world.sim.livestock.consume_at_trough(a,"drink",dt*13.0)
	else:
		actor.mode="找水"
		if not clear_walk(actor.node.position,path[0]):actor.erase("shore_route");return false
		if walk_to(actor,a,path[0],dt) and path.size()>1:path.remove_at(0);actor.shore_route=path
	a.pos=[actor.node.position.x,actor.node.position.y]
	animate(actor,a,dt)
	return true

## One flood fill for all banks, including ponds on the far side of a traversable gate.
func route_to_points(start:Vector2,banks:Array)->PackedVector2Array:
	if banks.is_empty():return PackedVector2Array()
	if clear_walk(start,banks[0]):return PackedVector2Array([banks[0]])
	var ends={}
	var scale_=32.0
	for bank in banks:
		var base=Vector2i((bank/scale_).round())
		for d in [Vector2i.ZERO,Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var k:Vector2i=base+d
			if not ends.has(k) and clear_walk(Vector2(k)*scale_,bank):ends[k]=bank
	var origin=Vector2i((start/scale_).round())
	var queue:Array[Vector2i]=[];var parents={}
	for d in [Vector2i.ZERO,Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
		var k:Vector2i=origin+d
		if clear_walk(start,Vector2(k)*scale_):queue.append(k);parents[k]=k
	var head=0
	while head<queue.size():
		var at:Vector2i=queue[head];head+=1
		if ends.has(at):
			var path=PackedVector2Array([ends[at]])
			while true:
				path.append(Vector2(at)*scale_)
				if parents[at]==at:break
				at=parents[at]
			path.reverse();return path
		for d in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var k:Vector2i=at+d
			if parents.has(k) or not world.world_bounds().has_point(Vector2(k)*scale_):continue
			if on_ranch() and not world.region.in_zone_cell(world.region.cell_of(Vector2(k)*scale_)):continue
			if clear_walk(Vector2(at)*scale_,Vector2(k)*scale_):parents[k]=at;queue.append(k)
	return PackedVector2Array()

func outdoor_spot(a:Dictionary)->Vector2:
	if not homeless(a.kind):return clamp_point(world.region.troughs[a.kind].food+Vector2(0,32),a.kind)
	var door:Vector2=world.region.barn_door()
	var slot=absi(hash(str(a.id)))%5
	for r in [88,62,38]:
		for offset in [0,1,2,3,4]:
			var p=door+Vector2((((slot+offset)%5)-2)*22,r)
			if not herd_blocked(p):return p
	return door+Vector2(0,16)

## Free-range animals pick a fresh leg from their current position. Try a
## shorter stride near obstacles so narrow passages still have viable steps.
func roaming_goal(start:Vector2)->Vector2:
	var area:Rect2=world.region.zone()
	var angle=rng.randf_range(0.,TAU)
	for reach in [256.,112.,42.,16.]:
		for turn in 8:
			var heading=angle+turn*TAU/8.
			var point=start+Vector2.from_angle(heading)*rng.randf_range(reach*.6,reach)
			if area.has_point(point) and clear_walk(start,point):return point
	return start

func roam(actor:Dictionary,a:Dictionary,dt:float):
	if actor.wait>0:
		actor.wait=maxf(0.,actor.wait-dt)
		actor.mode="歇一会儿"
		return
	var start:Vector2=actor.node.position
	if not actor.has("loose_goal"):actor.loose_goal=roaming_goal(start)
	var dest:Vector2=actor.loose_goal
	# Another activity or a layout edit may have displaced the animal mid-leg.
	if not clear_walk(start,start.move_toward(dest,dt*42.+2.)):
		actor.erase("loose_goal");actor.wait=rng.randf_range(.15,.55)
	elif walk_to(actor,a,dest,dt):
		actor.erase("loose_goal");actor.wait=rng.randf_range(1.5,5.)

func commute(actor:Dictionary,a:Dictionary,dark:bool,door:Vector2,dt:float)->bool:
	if world.region.layout.barn.is_empty():
		a["inside_barn"]=false
		return false
	var inside=bool(a.get("inside_barn",false))
	if inside and dark:
		actor.node.hide();actor.barn="in";actor.mode="在畜舍里"
		if a.food<60:world.sim.livestock.consume_at_trough(a,"food",dt*13.0)
		if a.drink<60 and not world.sim.livestock.river_only(a):world.sim.livestock.consume_at_trough(a,"drink",dt*13.0)
		return true
	if not dark and not inside and not a.get("barn_transit",false):return false
	var mode="entering" if dark else "leaving"
	var goal=door if dark else outdoor_spot(a)
	if actor.get("barn","")!=mode:
		actor.erase("barn_path");actor.erase("retry_at")
		if inside:actor.node.position=door
		actor.barn=mode
	a["inside_barn"]=false;a["barn_transit"]=true
	actor.node.show()
	actor.mode="回舍" if dark else "出舍"
	if not actor.has("barn_path"):
		if float(actor.get("retry_at",0))>Time.get_ticks_msec():return true
		var route=barn_route(actor.node.position,goal)
		if route.is_empty():
			actor.retry_at=Time.get_ticks_msec()+5000
			actor.mode="通道受阻";return true
		actor.barn_path=route
	var path:PackedVector2Array=actor.barn_path
	if walk_to(actor,a,path[0],dt):
		path.remove_at(0);actor.barn_path=path
	if path.is_empty():
		actor.erase("barn_path");a.barn_transit=false
		a.inside_barn=dark;actor.barn="in" if dark else "out"
		actor.node.visible=not dark
		actor.path=PackedVector2Array();actor.erase("dest");actor.goal=actor.node.position
	a.pos=[actor.node.position.x,actor.node.position.y]
	if a.barn_transit:a["barn_position"]=a.pos.duplicate()
	else:a.erase("barn_position")
	animate(actor,a,dt)
	return true

func lure_point(a,position:Vector2)->Vector2:
	var treat="carrot" if a.kind=="pig" else "wheat"
	if int(world.sim.data.bag.get(treat,0))<=0:return Vector2.INF
	var best=Vector2.INF
	if world.held_food==treat and world.player.visible and position.distance_to(world.player.position)<165:best=world.player.position
	var host=world.get_tree().get_meta("qingxi_world_host") if world.get_tree().has_meta("qingxi_world_host") else null
	if host!=null and host.scene==world:
		for who in host.visitors:
			var pet_owner=host.visitors[who].node
			if host.held_by.get(who,"")!=treat or not is_instance_valid(pet_owner):continue
			var dist=position.distance_to(pet_owner.position)
			if dist<165 and dist<position.distance_to(best):best=pet_owner.position
	return best

func tick(dt:float):
	pets_tick(dt)
	if on_barn():
		barn_tick(dt);return
	if not on_ranch():return
	var herd=world.sim.livestock
	var dark=night()
	var door:Vector2=world.region.barn_door()+Vector2(0,10)
	for a in herd.data.herd:
		if not actors.has(a.id):continue
		var actor:Dictionary=actors[a.id]
		var node:Node2D=actor.node
		actor.moving=false
		if not a.get("inside_barn",false) and deep_water(node.position):
			node.position=nearest_wading_spot(node.position,a)
			a.pos=[node.position.x,node.position.y]
			actor.goal=node.position;actor.path=PackedVector2Array()
			for key in ["loose_goal","shore_route","shore_return_path","barn_path","dest"]:actor.erase(key)
		if commute(actor,a,dark,door,dt):continue
		if not dark and (homeless(a.kind) or drinking_spots.get(a.kind,[]).is_empty()) and seek_shore(a,actor,dt):
			node.visible=true
			continue
		if actor.get("return_from_bank",false):
			var rest=outdoor_spot(a)
			if not actor.has("shore_return_path"):actor.shore_return_path=barn_route(node.position,rest)
			var return_path:PackedVector2Array=actor.shore_return_path
			if not return_path.is_empty() and clear_walk(node.position,return_path[0]):
				actor.mode="回牧场"
				if walk_to(actor,a,return_path[0],dt):return_path.remove_at(0);actor.shore_return_path=return_path
				a.pos=[node.position.x,node.position.y];animate(actor,a,dt)
				continue
			actor.erase("return_from_bank");actor.erase("shore_return_path")
			actor.goal=node.position
		if homeless(a.kind):
			node.visible=true;actor.barn="out";actor.mode="睡觉" if dark else "散步"
			if not dark and a.food<90 and herd.available(a,"food")>0 and (a.food<=herd.SEEK_AT or actor.get("loose_eating",false)):
				actor.loose_eating=true;actor.mode="进食"
				var trough=world.region.troughs.get(a.kind,{})
				if not trough.is_empty() and node.position.distance_to(trough.food)>34:
					var step=companion_step(actor,trough.food+Vector2(0,14),dt)
					actor.mode="找食";walk_to(actor,a,step,dt)
				else:herd.consume_at_trough(a,"food",dt*13.)
				a.pos=[node.position.x,node.position.y];animate(actor,a,dt);continue
			actor.loose_eating=false
			var lure=lure_point(a,node.position)
			if not dark and lure!=Vector2.INF and clear_walk(node.position,lure):
				actor.mode="跟随点心"
				if node.position.distance_to(lure)>28:walk_to(actor,a,lure,dt)
				a.pos=[node.position.x,node.position.y];animate(actor,a,dt);continue
			if not dark:roam(actor,a,dt)
			a.pos=[node.position.x,node.position.y];animate(actor,a,dt);continue
		var goal:Vector2=actor.goal
		var distance=6.0
		var walking=true
		var need:String=actor.get("need","")
		if dark:
			actor.mode="睡觉";walking=false;need=""
		else:
			if need=="" or a.get(need,100)>=90 or herd.available(a,need)<=0:
				need=herd.priority(a)
			if need=="drink" and herd.river_only(a) and drinking_spots.get(a.kind,[]).is_empty():need=""
			if need!="" and world.region.troughs.has(a.kind):
				goal=station_goal(a,need)
				actor.mode="找水" if need=="drink" else "找食"
				if node.position.distance_to(goal)<=13:
					actor.mode="喝水" if need=="drink" else "进食"
					herd.consume_at_trough(a,need,dt*13.0)
					walking=false
			else:
				var mate=herd.partner(a)
				var lure=lure_point(a,node.position)
				if not mate.is_empty():
					goal=clamp_point(Vector2(mate.pos[0],mate.pos[1]),a.kind)
					actor.mode="靠近伴侣";distance=25.0
				elif lure!=Vector2.INF:
					goal=clamp_point(lure,a.kind)
					actor.mode="跟随点心";distance=30.0
				elif actor.wait>0:
					actor.wait-=dt;actor.mode="歇一会儿";walking=false
				else:
					actor.mode="散步"
					if node.position.distance_to(goal)<10 or actor.get("stalled",false):
						goal=random_goal(a.kind);actor.wait=rng.randf_range(1,4)
		actor.need=need
		actor.goal=goal
		node.visible=true
		if walking and node.position.distance_to(goal)>distance:
			move_along_path(a,actor,dt)
		a.pos=[node.position.x,node.position.y]
		animate(actor,a,dt)
	separate(dt)
	finish_frame()
func finish_frame():
	update_sprites()
	for a in world.sim.livestock.data.herd:
		if not actors.has(a.id):continue
		var actor:Dictionary=actors[a.id]
		var status:String=world.sim.livestock.care_status(a)
		var title="%s #%s"%[Herd.NAMES.get(a.kind,"鸡"),a.id]
		var nm:=str(a.get("name","")).strip_edges()
		if nm!="":title="「%s」%s" % [nm,title]   # 2026-11-21 pets: 牲畜也能取名，名牌立刻带出来
		if status!="":
			actor.tag.text=title+" · "+status
			actor.tag.add_theme_color_override("font_color",Color("ffd6a0"))
		else:
			actor.tag.remove_theme_color_override("font_color")
		for target in world.targets:
			if target.kind=="animal" and target.extra==a.id:target.name=title if status=="" else title+" · "+status
	for id in actors:
		var actor=actors[id]
		actor.sprite.flip_h=actor.model.mirrored
		if actor.moving and actor.model.step==1:actor.sprite.position.y-=1.5
		if not actor.node.visible:
			actor.tag.visible=false
			for target in world.targets:
				if target.kind=="animal" and target.extra==id:target.pos=Vector2(-99999,-99999)
## Soft bodies: overlapping animals ease apart (an ellipse, long side to side), never
## onto a fence, feeder or out of their enclosure.
func separate(dt:float):
	var herd=world.sim.livestock.data.herd
	var nearby={}
	for a in herd:
		if not actors.has(a.id) or not actors[a.id].node.visible:continue
		var na:Node2D=actors[a.id].node
		var block=Vector2i((na.position/64.).floor())
		var neighbors=[]
		for x in range(-1,2):
			for y in range(-1,2):
				neighbors.append_array(nearby.get(block+Vector2i(x,y),[]))
		if not nearby.has(block):nearby[block]=[]
		nearby[block].append(a)
		for b in neighbors:
			var nb:Node2D=actors[b.id].node
			var reach=body(a)+body(b)
			var d=nb.position-na.position
			var e=Vector2(d.x/reach,d.y/(reach*.75))
			var l=e.length()
			if l>=1.0:continue
			var dir=Vector2(e.x,e.y*.75).normalized() if l>.001 else Vector2.RIGHT.rotated(randf()*TAU)
			var push=minf((1.0-l)*reach*.5,60.0*dt)
			for pair in [[na,a,-dir],[nb,b,dir]]:
				if str(actors[pair[1].id].mode) in ["进食","喝水","找食","找水","睡觉","回舍","出舍"]:continue
				var to:Vector2=pair[0].position+pair[2]*push
				var k:String=pair[1].kind
				if grids.has(k):
					var c=cell(to);var g:AStarGrid2D=grids[k]
					if not g.region.has_point(c) or g.is_point_solid(c):continue
				if herd_blocked(to):continue
				pair[0].position=to
				pair[1].pos=[to.x,to.y]
## Inside the barn map: who sleeps here lies in its own bay; the rest are out at pasture.
func barn_tick(dt:float):
	var info=world.region.ranch_info
	var herd=world.sim.livestock
	var dark=night()
	var counts={}
	var occupied=[]
	for a in herd.data.herd:
		if not actors.has(a.id):continue
		var actor:Dictionary=actors[a.id]
		# Advance an offscreen trip while the player is inside; share membership with the exterior.
		var inside=bool(a.get("inside_barn",false))
		if dark!=inside:
			a["door_elapsed"]=float(a.get("door_elapsed",0.0))+dt
			if a.door_elapsed>=3.0:
				inside=dark;a["inside_barn"]=dark;a["barn_transit"]=not dark;a.erase("door_elapsed")
		else:a.erase("door_elapsed")
		actor.node.visible=inside;actor.moving=false
		if not inside:continue
		var n=int(counts.get(a.kind,0));counts[a.kind]=n+1
		var fallback:Vector2=world.region.bay_spot(a.kind,n)
		if is_instance_valid(world.barn_editor):
			var stamp=Vector3i(n,world.barn_editor.bed_revision,herd.data.herd.size())
			if actor.get("bed_key")!=stamp:
				actor.bed_key=stamp;actor.bed_pos=world.barn_editor.bed_spot(fallback,occupied)
			actor.node.position=actor.bed_pos
		else:actor.node.position=fallback
		occupied.append(actor.node.position)
		actor.mode="睡觉" if dark else "歇一会儿"
		if a.food<60:herd.consume_at_trough(a,"food",dt*13.0)
		if not herd.river_only(a) and a.drink<60:herd.consume_at_trough(a,"drink",dt*13.0)
		animate(actor,a,dt)
	finish_frame()
func animate(actor:Dictionary,a:Dictionary,dt:float):
	actor.model.animate(dt,actor.moving,actor.mode,a.shorn,actor.get("heading",Vector2.LEFT))
func move_along_path(a:Dictionary,actor:Dictionary,dt:float):
	if not grids.has(a.kind):make_grid(a.kind)
	var grid:AStarGrid2D=grids[a.kind]
	var node:Node2D=actor.node
	var dest=cell(actor.goal)
	var path:PackedVector2Array=actor.get("path",PackedVector2Array())
	if actor.get("dest",Vector2i(-1,-1))!=dest or path.is_empty():
		path=PackedVector2Array()
		if grid.region.has_point(cell(node.position)) and grid.region.has_point(dest):
			path=grid.get_point_path(cell(node.position),dest)
		if not path.is_empty() and node.position.distance_to(path[0])<GRID:path.remove_at(0)
		actor.dest=dest
	actor.stalled=path.is_empty()
	if path.is_empty():return
	var prior_distance=node.position.distance_to(path[0])
	var toward=node.position.direction_to(path[0])
	var speed=float({"cow":28,"sheep":33,"pig":30,"chicken":40}[a.kind])
	var next=node.position.move_toward(path[0],dt*speed)
	# Give the next footstep a side offset when another body is directly ahead.
	for id in actors:
		if id==a.id or not actors[id].node.visible or actor.mode in ["回舍","找水","找食"]:continue
		var other:Vector2=actors[id].node.position
		var gap=next.distance_to(other)
		if gap>=14 or gap>=node.position.distance_to(other):continue
		var away=next.direction_to(other)
		var tangent=Vector2(-away.y,away.x)
		if tangent.dot(toward)<0:tangent=-tangent
		var diverted=node.position+(tangent-away*.25).normalized()*speed*dt
		var c=cell(diverted)
		if grid.region.has_point(c) and not grid.is_point_solid(c) and not herd_blocked(diverted):
			next=diverted
		break
	# Slide along a feeder or fence corner instead of stopping against it.
	if herd_blocked(next) and not herd_blocked(node.position):
		for slide in [Vector2(next.x,node.position.y),Vector2(node.position.x,next.y)]:
			if not herd_blocked(slide):next=slide;break
	if not deep_water(next) and (not herd_blocked(next) or herd_blocked(node.position)):
		actor.moving=node.position.distance_to(next)>.01
		node.position=next
		if actor.moving:actor.heading=toward
	var progress=prior_distance-node.position.distance_to(path[0])
	if progress>dt*speed*.18:actor.pinned=0.0
	else:
		actor.pinned=float(actor.get("pinned",0.0))+dt
		if actor.pinned>.85 and clear_walk(node.position,path[0]):
			node.position=path[0];actor.pinned=0.0
	if node.position.distance_to(path[0])<1.0:path.remove_at(0)
	actor.path=path

# ---------------- 2026-11-21 pets: 农场上的猫和狗 ----------------
## 它们不进圈舍、不走 A*：在农场范围内闲逛/跟着你/回门口看家；位置和状态都由 pets.gd 的判据决定。
## 场景里最多同时画 display.max_actors 只；其余仍在存档和读数里（数量上限本身没有）。
func pet_roster():
	if world==null or world.sim==null:return null
	return world.sim.pet_roster() if world.sim.has_method("pet_roster") else null
func pet_now()->float:return Time.get_unix_time_from_system()
func pet_hour()->float:return world.sky_value()*24.0 if world.has_method("sky_value") else 12.0

## 家：畜舍门口（没有畜舍就站在你附近）。狗看家就回这里。
func pet_home()->Vector2:
	var r=world.region
	if r!=null and r.has_method("barn_door"):
		return r.barn_door()+Vector2(0,30)
	return world.player.position

func refresh():
	var before=actors.keys()
	super.refresh()
	if on_ranch():
		for a in world.sim.livestock.data.herd:
			if a.id in before or not actors.has(a.id):continue
			var actor:Dictionary=actors[a.id]
			if a.get("inside_barn",false):
				actor.node.position=world.region.barn_door()+Vector2(0,10)
				actor.node.visible=false;actor.barn="in"
			elif a.get("barn_transit",false) or homeless(a.kind):
				var saved=a.get("barn_position",a.pos) if a.get("barn_transit",false) else a.pos
				var last=Vector2(saved[0],saved[1])
				if deep_water(last):
					actor.node.position=nearest_wading_spot(last,a)
					a.pos=[actor.node.position.x,actor.node.position.y]
				else:
					actor.node.position=last if world.region.in_zone_cell(world.region.cell_of(last)) and not herd_blocked(last) else outdoor_spot(a)
				actor.goal=actor.node.position
	pets_refresh()

func _pet_pos(pet:Dictionary)->Vector2:
	var p=pet.get("pos",null)
	if p is Array and p.size()>=2:return Vector2(float(p[0]),float(p[1]))
	return pet_home()

## 挑出场上的那几只：在家的、离玩家近的优先。出门的猫不建节点。
func _pet_pick()->Array:
	var roster=pet_roster()
	if roster==null:return []
	var now=pet_now()
	var cap=maxi(0,int(PetRules.display().get("max_actors",12)))
	var scored=[]
	for p in roster.list():
		if not p is Dictionary:continue
		var manual=bool(p.get("follow",false))
		var host=world.get_tree().get_meta("qingxi_world_host") if world.get_tree().has_meta("qingxi_world_host") else null
		if host!=null and host.travel_pets.sleep_spot(host,p,host._resident(str(p.get("owner_id",""))))!=Vector2.INF:continue
		if manual:
			if host!=null:
				var companion=host.travel_pets.leader(host,str(p.get("owner_id","")))
				if not is_instance_valid(companion) or not world.is_ancestor_of(companion):continue
		if not on_ranch() and not manual:continue
		var arrival=float(p.get("adopted_here_until",0))>now
		var away=PetRules.is_away(p,now) and not arrival
		scored.append({"arrival":arrival,"pet":p,"away":away,"manual":manual,"d":_pet_pos(p).distance_to(world.player.position)})
	scored.sort_custom(func(a,b):return a.arrival if a.arrival!=b.arrival else (a.manual if a.manual!=b.manual else a.d<b.d))
	var out=[]
	for row in scored:
		if out.size()>=cap:break
		if bool(row.away):continue
		out.append(row.pet)
	return out

func pets_refresh():
	if world==null or not is_instance_valid(world.scenery) or not is_instance_valid(world.player):
		_pet_clear();return
	var roster=pet_roster()
	if roster==null:
		_pet_clear();return
	var keep={}
	for pet in _pet_pick():
		var id=str(pet.get("id",""))
		keep[id]=true
		if pet_actors.has(id):
			# v2：品种/成长阶段会变（幼崽长大），刷新时把身份推给已有的精灵，不重建节点。
			var had=pet_actors[id]
			var had_sprite=had.get("sprite")
			if had_sprite!=null and is_instance_valid(had_sprite):
				had_sprite.set_identity(str(pet.get("kind","cat")),PetRules.breed_of(pet),PetRules.body_scale(pet),PetRules.is_baby(pet))
			continue
		var node=Node2D.new();node.name="Pet_"+id
		var sprite=PetSprite.new(str(pet.get("kind","cat")),PetRules.breed_of(pet),PetRules.body_scale(pet),PetRules.is_baby(pet))
		node.add_child(sprite)
		var tag=world.world_label("",Vector2.ZERO);tag.reparent(node)
		var pos=_pet_pos(pet) if on_ranch() else world.player.position
		if on_ranch() and world.blocked(pos):pos=clamp_pet(pos)
		if pet.get("follow",false):
			var leader=world.player
			if str(pet.get("owner_id",""))!="owner":
				var host=world.get_tree().get_meta("qingxi_world_host") if world.get_tree().has_meta("qingxi_world_host") else null
				if host:leader=host.travel_pets.leader(host,str(pet.owner_id))
			if is_instance_valid(leader) and (not on_ranch() or pet.get("companion_map","ranch")!=world.map_id or world.blocked(pos)):
				pos=leader.position
		pet["companion_map"]=world.map_id
		node.position=pos
		world.scenery.add_child(node)
		pet_actors[id]={"node":node,"sprite":sprite,"tag":tag,"goal":pos,"wait":rng.randf_range(0,2),"mode":"在家"}
		world.targets.append({"kind":"pet","pos":pos,"name":PetRules.name_text(pet),"extra":id})
	for id in pet_actors.keys():
		if keep.has(id):continue
		var actor=pet_actors[id]
		if is_instance_valid(actor.get("node")):actor.node.queue_free()
		pet_actors.erase(id)
		world.targets=world.targets.filter(func(t):return not (t.kind=="pet" and t.extra==id))

## 别走出农场边界：有围栏就用围栏的矩形，没有就用家门口 ±140 的院子。
func pet_rect()->Rect2:
	var r=world.region
	if r!=null and r.has_method("pens"):
		var pens:Dictionary=r.pens()
		if pens.has("cow"):return pens["cow"].grow(220.0)
	var h=pet_home()
	return Rect2(h-Vector2(140,110),Vector2(280,220))
func clamp_pet(p:Vector2)->Vector2:
	var r=pet_rect()
	return p.clamp(r.position,r.end)

func companion_step(actor:Dictionary,goal:Vector2,dt:float)->Vector2:
	var pos:Vector2=actor.node.position
	if clear_walk(pos,goal):
		actor.erase("trail");actor.erase("repath");return goal
	actor.repath=float(actor.get("repath",0))-dt
	var path:PackedVector2Array=actor.get("trail",PackedVector2Array())
	if actor.repath<=0 and (path.is_empty() or goal.distance_to(actor.get("trail_goal",goal))>26):
		path=barn_route(pos,goal);actor.trail_goal=goal;actor.repath=.65
	while not path.is_empty() and pos.distance_to(path[0])<4:path.remove_at(0)
	actor.trail=path
	return pos if path.is_empty() else path[0]

func pets_tick(dt:float):
	if world==null:return
	if not is_instance_valid(world.player):return
	pet_tick_clock+=dt
	if pet_tick_clock>=1.0:
		pet_tick_clock=0.0
		pets_refresh()
	var roster=pet_roster()
	if roster==null:return
	var now=pet_now()
	var hour=pet_hour()
	var claimed={}
	var beds={}
	if world.get("placement")!=null:
		for slot in world.placement.nodes:
			if world.placement.plan.furniture[slot][0]=="pet_bed":
				beds[slot]=world.placement.nodes[slot].draw.get_center()+Vector2(0,5)
	for id in pet_actors.keys():
		var actor:Dictionary=pet_actors[id]
		if not is_instance_valid(actor.get("node")):pet_actors.erase(id);continue
		var pet:Dictionary=roster.pet(str(id))
		if pet.is_empty():continue
		var node:Node2D=actor.node
		# 猫自己出门了：不画，但它在存档里照常活着（读数会写"出门了，约 N 分钟后回来"）
		if float(pet.get("adopted_here_until",0))>now and not pet.get("follow",false):
			node.visible=true;actor.mode="刚到家";_pet_tag(actor,pet);continue
		if PetRules.is_away(pet,now):
			node.visible=false
			actor.mode="出门了"
			_pet_tag(actor,pet)
			continue
		node.visible=true
		var target:Vector2=actor.goal
		if not on_ranch() and not pet.get("follow",false):continue
		var speed:=42.0
		var mode:="闲逛"
		var companion=world.player
		if str(pet.get("owner_id",""))!="owner":
			var host=world.get_tree().get_meta("qingxi_world_host") if world.get_tree().has_meta("qingxi_world_host") else null
			companion=host.travel_pets.leader(host,str(pet.get("owner_id",""))) if host!=null else null
		if is_instance_valid(companion) and world.is_ancestor_of(companion) and companion.is_visible_in_tree() and PetRules.wants_follow(pet,now,hour):
			mode="跟着"+preload("res://core/pet_owner.gd").caption(pet)
			var owner:Vector2=companion.position
			var comfort=preload("res://core/pet_comfort.gd")
			var destination=comfort.follow_target(actor,owner,pet,dt)
			var sleeping_owner=companion!=world.player and not str(companion.name).begins_with("Visitor_") or (companion==world.player and world.rooms!=null and world.rooms.owner_bed!="")
			var bed=comfort.choose_bed(beds,claimed,actor,owner,node.position,INF if sleeping_owner else 210.)
			if bed!=Vector2.INF:destination=bed
			if world.blocked(destination):destination=owner
			target=companion_step(actor,destination,dt)
			speed=clampf(node.position.distance_to(destination)*3,46,400)
			if bed!=Vector2.INF and node.position.distance_to(bed)<5:mode="睡觉"
		elif PetRules.is_dog(pet) and PetRules.guarding(pet,now,hour):
			mode="看家";speed=30.0
			target=clamp_pet(pet_home()+Vector2(sin(now*0.13+float(id))*34.0,0))
			roster.observe(str(id),now,hour,dt)
		elif PetRules.is_cat(pet) and PetRules.rub_ready(pet,now) and node.position.distance_to(world.player.position)<PetRules.rub_range():
			mode="蹭蹭";speed=30.0
			target=world.player.position+Vector2(20,6)
			if node.position.distance_to(target)<12.0:
				var said = roster.rub(str(id),now)
				if said!="" and world.has_method("perform"):world.perform(said)
		elif PetRules.is_cat(pet) and not PetRules.cat_awake(hour):
			# 白天打盹：不动
			mode="打盹";speed=0.0
			target=node.position
		else:
			if float(actor.wait)>0.0:
				actor.wait-=dt;speed=0.0;target=node.position
				mode="歇一会儿"
			elif node.position.distance_to(target)<12.0:
				var home:=pet_home()
				if PetRules.is_dog(pet) and PetRules.anxious(pet,now):
					home=world.player.position   # 着急的狗在门口打转
				var reach:=80.0 if not PetRules.is_cat(pet) else 60.0
				actor.goal=clamp_pet(home+Vector2(rng.randf_range(-reach,reach),rng.randf_range(-reach*0.6,reach*0.6)))
				actor.wait=rng.randf_range(1.5,5.0)
				target=node.position
			else:
				mode="散步"
		# 走动（撞到东西就沿轴滑一下，不寻路）
		# v2：品种/成长阶段的速度系数（柴犬 1.25 跑得最快、幼崽 0.85 慢一点）。
		if speed>0.0:
			speed*=PetRules.speed_mult(pet)
			var d:Vector2=target-node.position
			if d.length()>3.0:
				var step:Vector2=d.normalized()*minf(d.length(),speed*dt)
				var next:Vector2=node.position+step
				if world.blocked(next):
					var alt:Vector2=node.position+Vector2(step.x,0.0)
					if world.blocked(alt):alt=node.position+Vector2(0.0,step.y)
					next=alt if not world.blocked(alt) else node.position
				actor.moving=next.distance_to(node.position)>0.05
				node.position=next
				if actor.moving:actor.heading=d.normalized()
			else:
				actor.moving=false
		else:
			actor.moving=false
		actor.mode=mode
		if on_ranch():pet["pos"]=[node.position.x,node.position.y]
		actor.sprite.animate(dt,bool(actor.moving),mode,actor.get("heading",Vector2.DOWN))
		_pet_tag(actor,pet)
	_pet_separate(dt)

## 名牌：「名字」·（幼崽）· 状态（名字取自存档，没名字就是 猫 #7）。
## v2：名牌高度用 pets_rules 的品种 plate_lift × 体型（柯基矮、幼崽更低）。
func _pet_tag(actor:Dictionary,pet:Dictionary):
	var tag:Label=actor.tag
	var sprite=actor.sprite
	var h:=PetRules.plate_lift(pet)*PetRules.body_scale(pet)
	if sprite!=null and h<=0.0:h=sprite.height()
	tag.position=Vector2(-64,-h-16)
	var baby:="（幼崽）" if PetRules.is_baby(pet) else ""
	tag.text="%s%s · %s" % [PetRules.name_text(pet),baby,str(actor.mode)]
	tag.visible=is_instance_valid(world.player) and actor.node.position.distance_to(world.player.position)<160
	for target in world.targets:
		if target.kind=="pet" and str(target.extra)==str(pet.get("id","")):
			target.pos=actor.node.position
			target.name=PetRules.name_text(pet)
			if actor.node.visible and tag.visible:pass

## 别叠在一起：互相轻轻推开一点。
func _pet_separate(dt:float):
	var ids=pet_actors.keys()
	for i in ids.size():
		var a:Dictionary=pet_actors[ids[i]]
		if not is_instance_valid(a.node) or not a.node.visible:continue
		for j in range(i+1,ids.size()):
			var b:Dictionary=pet_actors[ids[j]]
			if not is_instance_valid(b.node) or not b.node.visible:continue
			var d:Vector2=b.node.position-a.node.position
			var l:=d.length()
			if l>=24.0:continue
			var dir:Vector2=d.normalized() if l>0.01 else Vector2.RIGHT
			var push:=minf((24.0-l)*0.5,40.0*dt)
			var na:Vector2=a.node.position-dir*push
			var nb:Vector2=b.node.position+dir*push
			if a.mode!="睡觉" and not world.blocked(na):a.node.position=na
			if b.mode!="睡觉" and not world.blocked(nb):b.node.position=nb
