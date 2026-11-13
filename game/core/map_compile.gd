extends RefCounted
## Cabin World map files (format "cabin-map/1", docs/MAP-FORMAT.md) -> the room definition HomeGrid and Room already use
## (the same shape as assets/<room>-grid.json). Map editor design: docs/MAP-EDITOR-DESIGN.md, phase 1.
##
## Phase 1 (step A, structure only): an imported room keeps its exact pixel geometry, art layers, zones and stages in
## map.legacy. compile() rebuilds the definition from legacy plus the parts the map itself owns:
##   id/name/kind      -> scene, sceneData.id, sceneData.name, sceneData.outdoor
##   size, cell        -> columns, rows, cell
##   furniture         -> catalog[].cell (default positions) and defaultGroups
##   exits             -> sceneData.exits[].to / .entry (which room a door leads to, where you arrive)
##   legacy.floorPolygons / legacy.gridOrigin -> floorPolygons / gridOrigin (HomeGrid.floor_mask / grid_origin)
## floor.rows (one char per cell, from the furniture grid's own floor rule) is not used to build the room yet: it is the
## editable shape for phase 3 and is checked against the legacy floor (handover/map-phase1-20261111/check-map-phase1.gd).
## Nothing here reads or writes saves.

const FORMAT := "cabin-map/1"

static func map_file(scene: String) -> String:
	return "res://assets/maps/%s/map.json" % scene

static func has_map(scene: String) -> bool:
	return FileAccess.file_exists(map_file(scene))

## Reads and compiles a room's map. {} when the file is missing or not a valid map (the caller falls back to the old file).
static func load_definition(scene: String) -> Dictionary:
	var map = JSON.parse_string(FileAccess.get_file_as_string(map_file(scene)))
	if not map is Dictionary: return {}
	var installed:Dictionary=load("res://core/room_maps.gd").installed(scene)
	if not installed.is_empty():map=installed
	elif not Features.use_map(scene):return {} # No published override: retain the selected classic room.
	var issue := problem(map)
	if issue != "":
		push_warning("map %s: %s; using the built-in room file" % [scene, issue]); return {}
	var source: String = map.legacy.get("source", "")
	if source != "" and FileAccess.file_exists(source) and FileAccess.get_sha256(source) != str(map.legacy.get("sourceSha256", "")):
		push_warning("map %s: %s changed after the map was imported; re-run the map import (handover/map-phase1-20261111)" % [scene, source])
	return compile(map)

## "" when the map has every field compile() needs.
static func problem(map: Dictionary) -> String:
	if map.get("format") != FORMAT: return "unknown format"
	for key in ["id", "name", "kind", "size", "cell", "floor", "exits", "furniture", "legacy"]:
		if not map.has(key): return "missing " + key
	if not map.kind in ["indoor", "outdoor"]: return "kind must be indoor or outdoor"
	if map.cell!=preload("res://core/world_grid.gd").CELL:return "map grid must match the world grid (32 pixels)"
	if not map.legacy is Dictionary or not map.legacy.get("definition") is Dictionary: return "phase 1 maps need legacy.definition"
	var rows = map.floor.get("rows")
	if not rows is Array or rows.size() != int(map.size[1]): return "floor.rows must have one row per map row"
	for row in rows:
		if not row is String or row.length() != int(map.size[0]): return "every floor row must be one char per column"
	return ""

static func compile(map: Dictionary) -> Dictionary:
	var def: Dictionary = map.legacy.definition.duplicate(true)
	def.scene = map.id
	def.cell = map.cell
	def.columns = map.size[0]; def.rows = map.size[1]
	def.sceneData.id = map.id
	def.sceneData.name = map.name
	def.sceneData.outdoor = map.kind == "outdoor"
	if map.has("revision"): def.revision = map.revision
	var positions: Dictionary = map.furniture.get("positions", {})
	for item in def.catalog:
		if positions.has(item.id): item.cell = positions[item.id].duplicate()
	def.defaultGroups = map.furniture.get("groups", []).duplicate(true)
	for exit in def.sceneData.exits:
		var link: Dictionary = map.exits.get(exit.id, {})
		if link.has("to"): exit.to = link.to
		if link.has("entry"): exit.entry = link.entry
	# Step B (re-skin, owner-approved per room): the room is drawn from map pieces, baked to one picture with exactly the
	# same size and geometry. map.art.ground names it in assets/baked/; everything else (walking, furniture) is unchanged.
	if map.get("art", {}) is Dictionary and str(map.get("art", {}).get("ground", "")) != "":
		def.manifest.ground.file = str(map.art.ground)
	# map.art.front: the front wall, front door and side walls as one picture drawn ABOVE furniture and people
	# (owner 2026-11-11: the entrance door was hidden behind the freezer when it was part of the ground picture).
	if map.get("art", {}) is Dictionary and str(map.get("art", {}).get("front", "")) != "":
		var g: Dictionary = def.manifest.ground
		def.manifest.layers.append({"id": "room-front", "owner": "room-front", "file": str(map.art.front), "x": g.get("x", 0), "y": g.get("y", 0), "w": g.w, "h": g.h, "depth": float(g.get("y", 0)) + float(g.h) + 1000.0})
	if map.legacy.has("floorPolygons"): def.floorPolygons = map.legacy.floorPolygons.duplicate(true)
	if map.legacy.has("gridOrigin"): def.gridOrigin = map.legacy.gridOrigin.duplicate()
	if map.get("structure","")=="modular":def=modular(map,def)
	return def

## Editor-authored architecture. All art, navigation and furniture share WorldGrid.
static func modular(map:Dictionary,base:Dictionary)->Dictionary:
	const Grid=preload("res://core/world_grid.gd")
	const Model=preload("res://core/map_model.gd")
	var d:=base.duplicate(true)
	var w:int=int(map.size[0])*Grid.CELL;var h:int=int(map.size[1])*Grid.CELL
	var polygons:=[]
	for c in Model.walkable(map):
		var x:int=c.x*Grid.CELL;var y:int=c.y*Grid.CELL
		polygons.append([[x,y],[x+Grid.CELL,y],[x+Grid.CELL,y+Grid.CELL],[x,y+Grid.CELL]])
	var origin:Array=map.get("gridOrigin",map.legacy.get("gridOrigin",[0,0]))
	var ox:float=origin[0];var oy:float=origin[1]
	for polygon in polygons:
		for point in polygon:point[0]+=ox;point[1]+=oy
	d.bounds=[ox,oy,w,h];d.floorPolygons=polygons;d.gridOrigin=origin.duplicate();d.fixedObstacles=[]
	for c in map.walls.inner:
		if Model.is_doorway(map,Vector2i(c[0],c[1])):continue
		d.fixedObstacles.append({"x":ox+int(c[0])*Grid.CELL,"y":oy+int(c[1])*Grid.CELL,"w":Grid.CELL,"h":Grid.CELL})
	d.sceneData.width=w;d.sceneData.height=h;d.sceneData.walk={"x":0,"y":0,"w":w,"h":h};d.sceneData.walkRegions=polygons;d.sceneData.obstacles=[]
	# The editable indoor floor does not own attached outdoor paths (e.g. beach).
	if map.id=="xiaojingyu-home" and base.sceneData.get("walkRegions",[]).size()>1:
		d.sceneData.walkRegions=polygons.duplicate(true)
		d.sceneData.walkRegions.append_array(base.sceneData.walkRegions.slice(1).duplicate(true))
	d.sceneData.enclosed=not Model.outdoor(map);d.sceneData.outdoor=Model.outdoor(map)
	if map.has("editScene"):
		d.sceneData.exits=[]
		for opening in Model.doors(map):
			var exit_id:String=str(opening.get("exit",opening.id))
			var link:Dictionary=map.exits.get(exit_id,{})
			var cells:Array=Model.opening_cells(opening)
			if cells.is_empty():continue
			var point:={"x":ox+(float(cells[0].x+cells[-1].x)+1.0)*Grid.CELL/2.0,"y":oy+(float(cells[0].y+cells[-1].y)+1.0)*Grid.CELL/2.0}
			d.sceneData.exits.append({"id":exit_id,"x":point.x,"y":point.y,"to":link.get("to",""),"entry":link.get("entry","")})
			d.sceneData.entries[exit_id]=point.duplicate()
			var previous:Dictionary=base.sceneData.entries.get(exit_id,{})
			if not previous.is_empty():
				var anchor:=Vector2(previous.x,previous.y)
				for key in base.sceneData.entries:
					var entry:Dictionary=base.sceneData.entries[key]
					if Vector2(entry.x,entry.y).distance_to(anchor)<1:d.sceneData.entries[key]=point.duplicate()
				for key in base.sceneData.zones:
					if base.get("zoneOwners",{}).has(key):continue
					var zone:Dictionary=base.sceneData.zones[key]
					if Vector2(zone.x,zone.y).distance_to(anchor)<=32:d.sceneData.zones[key]=point.duplicate()
	var images:Dictionary=load("res://core/map_render.gd").render(map)
	for part in images:WorldData.runtime_textures[map.id+"-"+part]=ImageTexture.create_from_image(images[part])
	d.manifest.ground={"file":"runtime:"+map.id+"-ground","x":ox,"y":oy,"w":w,"h":h}
	d.manifest.layers=d.manifest.layers.filter(func(l):return not str(l.id).begins_with("map-inner") and l.id!="map-front")
	d.manifest.layers.append({"id":"map-front","file":"runtime:"+map.id+"-overlay","x":ox,"y":oy,"w":w,"h":h,"depth":h+1000})
	for stripe in load("res://core/map_render.gd").inner_stripes(map):
		var key:String=map.id+"-inner-"+str(stripe.row)
		WorldData.runtime_textures[key]=ImageTexture.create_from_image(stripe.image)
		d.manifest.layers.append({"id":"map-inner-"+str(stripe.row),"file":"runtime:"+key,"x":ox+float(stripe.at.x)/Grid.ART_SCALE,"y":oy+float(stripe.at.y)/Grid.ART_SCALE,"w":float(stripe.image.get_width())/Grid.ART_SCALE,"h":float(stripe.image.get_height())/Grid.ART_SCALE,"depth":oy+stripe.depth})
	d.visual.width=w;d.visual.height=h;d.visual.enclosed=not Model.outdoor(map);d.visual.outdoor=Model.outdoor(map)
	if map.has("editScene"):
		d.visual.exits=d.sceneData.exits.map(func(e):return {"id":e.id,"name":WorldData.scenes.get(e.to,{}).get("name",e.to),"point":{"x":e.x,"y":e.y},"to":{"sceneId":e.to,"entry":e.entry}})
		d.visual.zones=d.sceneData.zones.duplicate(true)
	return d
