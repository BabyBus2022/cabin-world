extends RefCounted
const Grid=preload("res://core/world_grid.gd")
## Shared artwork and whole-cell footprints. New instances deliberately have no AI/plugin bindings.
static var assets: Dictionary = {}
const Made=preload("res://core/furniture_maker.gd")

static func all() -> Dictionary:
	if assets.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://assets/furniture-library.json"))
		for a in parsed.assets: assets[a.id] = a
	return assets.merged(Made.all())

static func label(item:Dictionary)->String:
	if item.has("custom"):return "可互动" if not item.custom.actions.is_empty() else "装饰"
	return "已绑定互动" if not item.get("zoneIds",[]).is_empty() else "装饰"

static func icon(path:String)->Texture2D:
	if "made:" in path:return Made.texture("made:"+path.split("made:")[1])
	return load(path) if ResourceLoader.exists(path) else null

static func augment(base: Dictionary, instances: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for id in instances:
		var a: Dictionary = all().get(instances[id], {})
		if a.is_empty(): continue
		var w: float = a.footprint.w * Grid.CELL
		var h: float = a.footprint.h * Grid.CELL
		var first: Dictionary = a.layers[0]
		var module := {"id":id,"kind":"decoration","x":first.x,"y":first.y,"w":first.w,"h":first.h,"depth":first.depth}
		if a.has("custom"):module.customAsset=a.id;module.facing="S"
		if a.layer == "solid": module.collision = {"x":-first.x,"y":-first.y,"w":w,"h":h}
		out.sceneData.modules[id] = module
		for source in a.layers:
			var layer: Dictionary = source.duplicate(true)
			layer.id = id if source.part == "main" else id + "__" + source.part
			layer.owner = id
			out.manifest.layers.append(layer)
		out.catalog.append({"id":id,"name":a.name,"cell":[0,0],"layer":a.layer,"box":[first.x,first.y,first.w,first.h],"foot":[0,0,w,h],"zoneIds":[],"icon":"res://assets/baked/"+str(first.file),"asset":a.id})
		if a.has("custom"):
			out.catalog[-1].custom=a.custom
			if not a.custom.actions.is_empty():
				var zone:="use_"+str(id)
				out.catalog[-1].zoneIds=[zone];out.zoneOwners[zone]=id
				out.sceneData.zones[zone]={"x":w/2,"y":h+20}
		if first.has("region"):out.catalog[-1]["iconRegion"]=first.region
	return out
