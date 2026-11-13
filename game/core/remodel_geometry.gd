extends RefCounted
## Convert the old furniture-placement mask into an editable architectural grid.
## Only draft geometry changes; legacy furniture anchors remain immutable.
const M=preload("res://core/map_model.gd")
const CELL=32
static func origin(m:Dictionary)->Vector2:
	var p:Array=m.get("gridOrigin",m.legacy.get("gridOrigin",[0,0]));return Vector2(p[0],p[1])
static func prepare(m:Dictionary,support:Array=[])->void:
	var base:Dictionary=m.legacy.definition
	var floor_polys:Array=m.legacy.get("floorPolygons",[])
	# The importer synthesizes one polygon per complete placement cell for rooms
	# without architectural polygons. Those cells are not the walking boundary.
	if base.sceneData.get("walkRegions",[]).is_empty():floor_polys=[]
	var old_origin:=origin(m);var at:=old_origin
	if not M.outdoor(m) and not floor_polys.is_empty():
		var top:=INF
		for points in floor_polys:
			for p in points:top=minf(top,float(p[1]))
		for item in base.catalog:
			if item.layer!="surface":top=minf(top,float(item.foot[1]))
		at.y-=maxf(0,ceilf((at.y+M.WALL_H*CELL-top)/CELL))*CELL
		m.gridOrigin=[at.x,at.y]
		m.walls.adaptive=true
	var terrain:Dictionary=base.sceneData.duplicate(true);terrain.obstacles=base.fixedObstacles
	var nav:=RoomNav.new(terrain)
	var polygons:Array[PackedVector2Array]=[]
	for points in floor_polys:
		var poly:=PackedVector2Array()
		for p in points:poly.append(Vector2(p[0],p[1]))
		polygons.append(poly)
	# Grid centres retain boundary cells that the old "whole cell fits" mask lost.
	for y in int(m.size[1]):
		var row:=""
		for x in int(m.size[0]):
			var p:=at+(Vector2(x,y)+Vector2(.5,.5))*CELL
			var inside:bool=nav.walkable(p) if M.outdoor(m) or polygons.is_empty() else polygons.any(func(poly):return Geometry2D.is_point_in_polygon(p,poly))
			# Classic rooms may have walking strips at the canvas edge. Reserve
			# one cell for the new side/front walls; furniture support is checked below.
			if not M.outdoor(m) and (x==0 or x==int(m.size[0])-1 or y==int(m.size[1])-1):inside=false
			row+="a" if inside else "."
		m.floor.rows[y]=row
	# Imported furniture may lean against a pixel wall; retain its support cells.
	for values in support:
		var r:=Rect2(values[0],values[1],values[2],values[3])
		var lo:=Vector2i(((r.position-at)/CELL).floor());var hi:=Vector2i(((r.end-at-Vector2(.001,.001))/CELL).floor())
		for y in range(lo.y,hi.y+1):
			for x in range(lo.x,hi.x+1):put(m,Vector2i(x,y))
	# Keep physical use points; an indoor outdoor annex is preserved separately.
	for zone in base.sceneData.zones.values():
		var p:=Vector2(zone.x,zone.y)
		if not M.outdoor(m) and not polygons.is_empty() and not polygons.any(func(poly):return Geometry2D.is_point_in_polygon(p,poly)):continue
		put(m,Vector2i(((p-at)/CELL).floor()))
	m.openings=[]
	for old in base.sceneData.exits:
		var best:Dictionary={};var score:=INF
		for kind in (["entrance"] if M.outdoor(m) else ["front_door","back_door"]):
			for c in M.floor_cells(m):
				if M.opening_issue(m,kind,c.x,c.y)!="":continue
				var center:=at+Vector2(c.x+float(M.OPENINGS[kind].w)/2,c.y+.5)*CELL
				var distance:=center.distance_squared_to(Vector2(old.x,old.y))
				if distance<score:score=distance;best={"id":old.id,"exit":old.id,"type":kind,"x":c.x,"y":c.y}
		if not best.is_empty():m.openings.append(best)
	# Widen only one-cell bottlenecks, choosing the least additional ground.
	for iteration in 64:
		var narrow:Array=M.analysis(m).narrow
		if narrow.is_empty():break
		var c:Vector2i=narrow[0];var best:Array=[];var cost:=INF
		for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.UP,Vector2i(-1,-1)]:
			var cells:Array=[];var score:=0.0
			for delta in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i(1,1)]:
				var p:Vector2i=c+offset+delta
				if not M.inb(m,p) or (not M.outdoor(m) and (p.x==0 or p.x==int(m.size[0])-1 or p.y==int(m.size[1])-1)):score=INF;break
				cells.append(p)
				if not M.is_floor(m,p):score+=10.0+(0 if nav.walkable(at+(Vector2(p)+Vector2(.5,.5))*CELL) else 1)
			if score<cost:cost=score;best=cells
		if best.is_empty():break
		for p in best:put(m,p)
static func put(m:Dictionary,c:Vector2i)->void:
	if not M.inb(m,c):return
	var row:String=m.floor.rows[c.y];m.floor.rows[c.y]=row.substr(0,c.x)+"a"+row.substr(c.x+1)
