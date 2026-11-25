extends RefCounted

const ACTIONS = ["restock","watch_pond","pond","stock_fry","feed_fish","fish","harvest_fish"]
const LABELS = {"restock":"放养背包里的鱼","stock_fry":"放入混合鱼苗","feed_fish":"投喂鱼饲料","fish":"抛竿钓鱼","harvest_fish":"收获养成的鱼"}

static func menu(sim, stock:Dictionary)->Dictionary:
	var fish_list=sim.Fish.stock(stock)
	var groups={}
	var mature=false
	for fish in fish_list:
		var kind=str(sim.Fish.kinds()[fish.kind].name)
		groups[kind]=int(groups.get(kind,0))+1
		if float(fish.age)>=sim.FISH_SECONDS:mature=true
	var counts=PackedStringArray()
	for name_ in groups:counts.append("%s ×%d"%[name_,groups[name_]])
	var buttons=["stock_fry"]
	if int(stock.count)<24 and not sim.live_catches().is_empty():buttons.append("restock")
	if not fish_list.is_empty():buttons.append_array(["feed_fish","fish"])
	if mature:buttons.append("harvest_fish")
	return {"summary":"塘中 %d 条   %s"%[fish_list.size(),"、".join(counts)],"buttons":buttons}

static func bank_key(map:String, item:Dictionary)->String:
	var extra=str(item.get("extra",""))
	match str(item.kind):
		"meadow_fish":return "水湾"+extra
		"built_pond":return map+"@"+extra.replace(":",",")
	return ""

static func wanted(arg:String, keys:Array)->String:
	if keys.has(arg):return arg
	if arg.is_empty() or arg in ["水边","鱼塘","鱼苗","混合鱼苗","鱼饲料","最近"]:return ""
	if keys.size()==1 and arg=="水湾":return keys[0]
	return arg

static func banks(scene, start:Vector2, arg:String)->Array:
	if scene.get("open_meadow")!=true or scene.get("map_id")!="ranch":return []
	var rows=[]
	var keys=[]
	for item in scene.targets:
		var id=bank_key(str(scene.map_id),item)
		if id=="":continue
		if not keys.has(id):keys.append(id)
		rows.append({"id":id,"pos":item.pos})
	var requested=wanted(arg,keys)
	if requested!="":rows=rows.filter(func(r):return r.id==requested)
	rows.sort_custom(func(a,b):return start.distance_squared_to(a.pos)<start.distance_squared_to(b.pos))
	return rows

# Only ponds with physical banks on this farm can take actions while its scene is unloaded.
static func saved_keys(sim,map:String)->Array:
	return sim.pond_list().keys() if map=="meadow" else []
