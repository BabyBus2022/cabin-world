class_name RoomObservation
extends RefCounted
## Read-only environmental facts for world_look and the existing lifeNote bridge.
## Never creates memories, completed actions, a mood bonus or a guessed indoor temperature.
static var definitions:Dictionary={}

static func reading(actor:String) -> Dictionary:
	if definitions.is_empty():definitions=JSON.parse_string(FileAccess.get_file_as_string("res://assets/room-observations.json"))
	var resident:Character=null
	var tree:=Engine.get_main_loop() as SceneTree
	if tree==null:return {}
	for candidate in tree.get_nodes_in_group("world_residents"):
		if candidate is Character and candidate.key==actor and candidate.placed:resident=candidate;break
	if resident==null or not definitions.has(resident.scene_id):return {}
	var id:String=resident.scene_id
	var definition:Dictionary=definitions[id]
	var scene:Dictionary=WorldData.scenes[id]
	var indoors:=not SeasideEnvironment.outside(resident.feet)
	var own:bool=Residents.person(actor).get("home",{}).get("scene","")==id
	var facts:Array=[]
	facts.append(("你自己的" if own else "你正在拜访的")+definition.name+"："+"、".join(definition.features)+"。")
	facts.append(definition.change)
	if indoors:facts.append(definition.shelter)
	else:facts.append("现在实际站在屋外的小路或海边，已离开房屋遮蔽；不能把屋内挡风避雨的条件套用到这里。")
	var weather:=SeasideEnvironment.classify(SharedFeed.local_weather,SharedFeed.now_ms())
	var weather_words:Dictionary={"clear":"晴天，光线明亮","cloudy":"多云或阴天，光线柔和","light_rain":"小雨，细雨落在窗外与小路上","heavy_rain":"大雨，室外雨势明显","snow":"下雪，屋外有积雪"}
	var condition:Dictionary={"source":"vads.weather.local","fresh":weather.fresh,"kind":weather.kind}
	if weather.fresh:
		facts.append("当前房屋对应的当地实时天气："+weather_words[weather.kind]+"；本屋的天气观察以这条实时数据为准。")
		if indoors and weather.kind in ["light_rain","heavy_rain","snow"]:facts.append("窗外有雨雪，室内地板仍是干燥的；没有屋内漏雨、漏雪的状态。")
	else:facts.append("当地实时天气尚未收到或已过期，当前晴雨和温度无法确认。")
	var phase:="unknown"
	if SharedFeed.clock_synced:
		phase=Daylight.reading(SharedFeed.now_ms()).phase
		facts.append("现在是夜间，窗外已暗，屋内照明由灯光设置决定。" if phase=="night" else "现在是白天，窗户光影会随天气与时间变化。")
	var zone:String=resident.want_zone
	if not resident.is_walking() and scene.zones.has(zone) and resident.feet.distance_to(WorldData.point(scene.zones[zone]))<=24 and definition.nearby.has(zone):facts.append(definition.nearby[zone])
	var furniture:Array=[]
	var arrangement:Array[String]=[]
	var grid_definition:Dictionary=HomeGrid.definitions.get(id,{})
	for item in grid_definition.get("catalog",[]):
		var module:Dictionary=scene.modules[item.id]
		var anchor:=Vector2(float(item.foot[0])+float(module.x)-float(item.box[0]),float(item.foot[1])+float(module.y)-float(item.box[1]))
		var area:="榻榻米卧室" if anchor.x<404 and anchor.y<247 else "书房" if anchor.x>430 and anchor.y<247 else "客厅或入口区域"
		furniture.append({"id":item.id,"name":item.name,"area":area,"x":module.x,"y":module.y})
		if item.id in ["xj-bed","xj-tank","xj-desk"]:arrangement.append(str(item.name)+"在"+area)
	facts.append("当前已保存的布置："+"，".join(arrangement)+"。")
	return {"scene":id,"homeOwner":own,"revision":definition.revision,"layoutRevision":scene.get("layoutRevision",""),"indoors":indoors,"weather":condition,"phase":phase,"facts":facts,"furniture":furniture,"note":"【当前房屋观察】"+" ".join(facts)}
