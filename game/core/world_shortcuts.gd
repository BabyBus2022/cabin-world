extends RefCounted
## Outdoor routes sharing an existing front door. Rebind after every layout change
## so old saves and remodeled doors receive the same connection as a new game.
static func refresh()->void:
	for pair in [["xiaojingyu-home","world-restaurant","restaurant-direct","餐厅直达"],["world-restaurant","xiaojingyu-home","home-direct","小鲸鱼家直达"]]:
		var from:String=pair[0];var to:String=pair[1];var id:String=pair[2]
		if not WorldData.scenes.has(from) or not WorldData.scenes.has(to):continue
		var scene:Dictionary=WorldData.scenes[from]
		var target:Dictionary=WorldData.scenes[to]
		var source_doors:Array=scene.exits.filter(func(e):return e.get("to")=="qianxia-park")
		var target_doors:Array=target.exits.filter(func(e):return e.get("to")=="qianxia-park")
		if source_doors.is_empty() or target_doors.is_empty():continue
		var door:Dictionary=source_doors[0];var destination:Dictionary=target_doors[0]
		if not target.entries.has(destination.id):continue
		scene.exits=scene.exits.filter(func(e):return e.get("id")!=id)
		scene.exits.append({"id":id,"x":door.x,"y":door.y,"to":to,"entry":destination.id,"shortcut":true})
		scene.entries[id]=scene.entries.get(door.id,{"x":door.x,"y":door.y}).duplicate(true)
		var visual:Dictionary=WorldPresentation.facts().scenes.get(from,{})
		if not visual.is_empty():
			visual.exits=visual.exits.filter(func(e):return e.get("id")!=id)
			visual.exits.append({"id":id,"name":pair[3],"point":{"x":door.x,"y":door.y},"to":{"sceneId":to,"entry":destination.id}})
