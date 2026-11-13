extends RefCounted
const Grid=preload("res://core/world_grid.gd")
## A turn moves ground-space approach points, but seats are measured on the
## artwork: perspective is not a rotation of the PNG or its bounding box.
const Sit=preload("res://entities/sit_presentation.gd")
const NAMES={"S":"south","W":"west","N":"north","E":"east"}
const ORDER=["S","W","N","E"]
static func turn(p:Vector2,size:Vector2,face:String)->Vector2:
	match face:
		"W":return Vector2(size.y-p.y,p.x)
		"N":return size-p
		"E":return Vector2(p.y,size.x-p.x)
	return p
static func resize_axis(p:float,old:float,size:float)->float:
	if p<0:return p
	if p>old:return size+p-old
	return p/old*size
static func ground(p:Vector2,old:Rect2,size:Vector2,face:String)->Vector2:
	p-=old.position
	p=Vector2(resize_axis(p.x,old.size.x,size.x),resize_axis(p.y,old.size.y,size.y))
	return old.position+turn(p,size,face)
static func bind(def:Dictionary,item:Dictionary,m:Dictionary,old:Rect2,views:Dictionary,face:String)->void:
	var v:Dictionary=views[face]
	var size:=Vector2(views.S.footprint.w,views.S.footprint.h)*Grid.CELL
	var relocated:=Vector2(item.foot[0],item.foot[1])-old.position
	m.facing=face;m.facingArt=v.file
	if v.has("visibleBounds"):m.visibleBounds=v.visibleBounds.duplicate()
	var zone_ids:Array=item.get("zoneIds",[]).duplicate()
	for z in def.get("zoneOwners",{}):
		if def.zoneOwners[z]==item.id and not z in zone_ids:zone_ids.append(z)
	for z in zone_ids:
		if not def.sceneData.zones.has(z):continue
		var zone:Dictionary=def.sceneData.zones[z]
		var p:=ground(Vector2(zone.x,zone.y),old,size,face)+relocated
		zone.x=p.x;zone.y=p.y
		# Action effects may have been queued before the furniture was turned.
		zone.furnitureFacing=face
	# SharedSit owns all ordinary seated poses, including computer/writing chairs.
	Sit.ready()
	var rules:Dictionary=Sit.bindings.scenes.get(def.scene,{})
	var slots:Dictionary={}
	for z in rules:
		if rules[z].get("module","")!=item.id:continue
		var rule:Dictionary=rules[z].duplicate(true)
		var seats:Array=v.get("seats",[])
		if seats.is_empty():continue
		var index:=0
		if item.id=="long-bench":index=["bench_a","bench_b","bench_c"].find(z)
		var seat:Dictionary=seats[clampi(index,0,seats.size()-1)]
		rule.erase("anchor_ratio");rule.erase("use_zone_anchor");rule.erase("front")
		rule.zone=z;rule.anchor=[float(seat.x)-float(v.art.x),float(seat.y)-float(v.art.y)]
		rule.facing=NAMES.get(str(seat.get("face",face)),"south")
		slots[z]=rule
	if not slots.is_empty():m.sitting={"slots":slots}
	if v.has("seats"):m.facingSeats=v.seats.duplicate(true)
	if def.profile.has("home"):
		for stage in def.profile.home.stages:
			if not stage.get("zone","") in zone_ids:continue
			if stage.has("feet"):
				var p:=ground(Vector2(stage.feet[0],stage.feet[1]),old,size,face)+relocated
				stage.feet=[p.x,p.y];stage.sort=p.y
			if stage.has("dir"):
				# Character rows: south, west, east, north.
				var dirs:=[0,1,3,2]
				stage.dir=dirs[(dirs.find(int(stage.dir))+ORDER.find(face))%4]
			if stage.get("registered","")=="computer":
				stage.erase("registered")
				# The old composite is gone, but computer use remains seated.
				stage.seat=true
		if item.id=="xj-bed":
			var p:=ground(Vector2(def.profile.home.bed.lying[0],def.profile.home.bed.lying[1]),old,size,face)+relocated
			def.profile.home.bed.lying=[p.x,p.y]
			def.profile.home.bed.facing=face
