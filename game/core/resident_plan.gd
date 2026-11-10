extends RefCounted
## Non-AI idle fallback, ported from the original outing logic. The language
## model remains in VADS; choices based on game facts live here for any skin.
static func pick(rows: Array,random: Callable) -> Dictionary:
	var total := 0.0
	for row in rows:total+=float(row[2])
	var value := float(random.call())*total
	for row in rows:
		value-=float(row[2])
		if value<=0:return {"action":"use","objectId":row[0],"use":row[1]}
	return {"action":"stay"}

static func resolve(args: Dictionary) -> Dictionary:
	var actor := str(args.actor)
	var profile := Residents.person(actor)
	var data: Dictionary=profile.get("idle",{})
	if data.is_empty():return {"action":"stay"}
	var view := Economy.reading(actor)
	if view.options.get("paused",false):return {"action":"stay"}
	var queue: Array=args.get("rands",[]).duplicate()
	var random := func():return float(queue.pop_front()) if not queue.is_empty() else randf()
	var home := str(data.home)
	var space := str(args.space)
	var phase := str(args.phase)
	var r: Dictionary=args.weather if args.get("weather") is Dictionary else {}
	var energy := float(view.feeling.energy)
	if energy<30:return {"action":"use","objectId":data.rest,"use":data.rest_use} if space==home else {"action":"go","space":home}
	var hint=want(view,args)
	if hint!=null and float(random.call())<.6:return hint
	var awake := phase in ["forenoon","afternoon","evening"]
	var rain := float(r.get("rain",0))
	var night: bool=r.get("phase")=="night"
	if space==home:
		if awake and rain<=.5 and not night and float(random.call())<.35:return {"action":"go","space":"park"}
		return pick(data.activities,random)
	if space=="arcade":
		if not awake or float(random.call())<.5:return {"action":"go","space":"park"}
		var games: Array=WorldData.objects.filter(func(o):return o.get("space")=="arcade")
		return {"action":"use","objectId":games[int(floorf(float(random.call())*games.size()))%games.size()].id,"use":"play"}
	if space=="onsen":
		if not awake or float(random.call())<.35:return {"action":"go","space":home}
		return pick([["onsen_pool","swim",3],["onsen_soak","soak",3],["onsen_shower","shower",1],["onsen_bench","rest",2]],random)
	if awake and space=="shop" and (float(r.get("temp",20))<=16 or rain>0) and float(random.call())<.25:return {"action":"go","space":"onsen"}
	if awake and space=="park" and float(random.call())<.12:return {"action":"go","space":"arcade"}
	if not awake or night or rain>.5 or float(random.call())<.4:return {"action":"go","space":home}
	return pick([["swing","swing",3],["slide","slide",2],["carousel","spin",2],["bench","sit_bench",2],["pier","fish",3],["river","skip_stones",2],["river","feed_ducks",2],["flower_bed","watch_butterfly",0 if rain>0 else 2],["meadow","fly_kite",3 if float(r.get("windLevel",0))>=1 and rain==0 else 0],["big_tree","shade",2 if float(r.get("sun",0))>.5 else 0]],random)

static func want(view: Dictionary,args: Dictionary) -> Variant:
	var weather: Dictionary=args.get("weather",{})
	var peer: Dictionary=args.peer if args.get("peer") is Dictionary else {}
	if float(view.life.needs.social)<35 and peer.get("space") in ["park","shop"] and peer.space!=args.space and weather.get("phase")!="night":return {"action":"go","space":peer.space}
	var hint=view.care if view.care!=null else view.want
	if not hint is Dictionary:return null
	for object in WorldData.objects:
		if object.id!=hint.objectId:continue
		if object.space=="park" and (float(weather.get("rain",0))>.5 or weather.get("phase")=="night" or not args.phase in ["forenoon","afternoon","evening"]):return null
		return {"action":"use","objectId":hint.objectId,"use":hint.use} if object.space==args.space or object.space=="any" else {"action":"go","space":object.space}
	return null
