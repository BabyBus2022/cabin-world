extends RefCounted
## Shared artwork and whole-cell footprints. New instances deliberately have no AI/plugin bindings.
static var assets: Dictionary = {}

static func all() -> Dictionary:
	if assets.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://assets/furniture-library.json"))
		for a in parsed.assets: assets[a.id] = a
	return assets

static func augment(base: Dictionary, instances: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for id in instances:
		var a: Dictionary = all().get(instances[id], {})
		if a.is_empty(): continue
		var w: float = a.footprint.w * 32.0
		var h: float = a.footprint.h * 32.0
		var first: Dictionary = a.layers[0]
		var module := {"id":id,"kind":"decoration","x":first.x,"y":first.y,"w":first.w,"h":first.h,"depth":first.depth}
		if a.layer == "solid": module.collision = {"x":-first.x,"y":-first.y,"w":w,"h":h}
		out.sceneData.modules[id] = module
		for source in a.layers:
			var layer: Dictionary = source.duplicate(true)
			layer.id = id if source.part == "main" else id + "__" + source.part
			layer.owner = id
			out.manifest.layers.append(layer)
		out.catalog.append({"id":id,"name":a.name,"cell":[0,0],"layer":a.layer,"box":[first.x,first.y,first.w,first.h],"foot":[0,0,w,h],"zoneIds":[],"icon":"res://assets/baked/"+str(first.file),"asset":a.id})
		if first.has("region"):out.catalog[-1]["iconRegion"]=first.region
	return out
