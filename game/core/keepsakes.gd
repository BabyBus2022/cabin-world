extends RefCounted
## Durable projects and room keepsakes. All changes commit inside Economy's
## existing transaction, so failed saves, retries and reconnects cannot duplicate them.
static var _data:Dictionary={}
static func data()->Dictionary:
	if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/keepsakes.json"))
	return _data
static func state(s:Dictionary)->Dictionary:
	var k:Dictionary=s.get("keepsakes",{}).duplicate(true)
	for field in ["fish","recipes","wall"]:
		if not k.get(field) is Dictionary:k[field]={}
	for field in ["paintings","notes"]:
		if not k.get(field) is Array:k[field]=[]
	return k
static func season(day:String)->String:
	var month:int=int(day.substr(5,2))
	return "spring" if month in [3,4,5] else "summer" if month in [6,7,8] else "autumn" if month in [9,10,11] else "winter"
static func calendar(day:String)->Dictionary:
	var id:String=season(day)
	return {"season":id,"name":data().seasons[id],"festivals":data().calendar.get(day,[])}
static func home(actor:String)->String:return str(Residents.person(actor).get("home",{}).get("scene",""))
static func has_aquarium(actor:String)->bool:
	return WorldData.scenes.get(home(actor),{}).get("modules",{}).values().any(func(m):return m.get("kind")=="seaside-tank")
static func present(actor:String,scene:String)->bool:
	var body=Economy.Social.body(actor)
	return body!=null and body.scene_id==scene and not body.is_walking() and not body.sleeping
static func error(message:String)->String:return message
static func change(s:Dictionary,actor:String,args:Dictionary,out:Dictionary)->String:
	var k:Dictionary=state(s);var use:String=str(args.get("use",""));var item:String=str(args.get("item","")).strip_edges();var text:String=str(args.get("feeling","")).strip_edges().substr(0,120)
	var now:float=SharedFeed.now_ms()
	match use:
		"birthday":
			if item!="":
				var parts:PackedStringArray=item.split("-")
				if parts.size()!=2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():return "生日请填 MM-DD，例如 06-18；留空可清除"
				var month:int=int(parts[0]);var date:int=int(parts[1])
				if month<1 or month>12 or date<1 or date>[31,29,31,30,31,30,31,31,30,31,30,31][month-1]:return "这个生日日期不存在"
				item="%02d-%02d"%[month,date]
			k.birthday=item;out.note="生日已记下" if item!="" else "生日已清除"
		"owner_post":
			var scene:String=str(args.get("scene",""));var kind:String=str(args.get("kind","note"))
			if not WorldData.scenes.has(scene) or not kind in ["note","gift","request"]:return "请选择房间和留言类型"
			if text=="" and kind!="gift":return "请写一点内容"
			if kind=="gift" and not Economy.catalog.has(item):return "请选择现有物品作为礼物"
			if k.notes.filter(func(n):return n.status in ["placed","found"]).size()>=12:return "未处理的留言已经有 12 条"
			k.notes.append({"id":str(args.id),"scene":scene,"kind":kind,"text":text,"product":item if kind=="gift" else "","status":"placed","at":now})
			if k.notes.size()>32:k.notes=k.notes.filter(func(n):return n.status in ["placed","found"])+k.notes.filter(func(n):return not n.status in ["placed","found"]).slice(-20)
			out.note="已留下，等她走进房间发现"
		"discover":
			var scene:String=str(args.get("scene",""))
			if not present(actor,scene):return "还没走进房间"
			out.discovered=[]
			for n in k.notes:
				if n.status=="placed" and n.scene==scene:
					n.status="found";n.foundAt=now;out.discovered.append(n.duplicate(true))
		"goal":
			if not data().goals.has(item):return "目标可选 save_frame / recipe / arcade"
			var old:Dictionary=k.get("goal",{})
			if old.get("kind")==item:return "已经在做这个目标了"
			k.goal={"kind":item,"started":now,"dish":str(args.get("dish","")),"claimed":false}
			out.note="记下了长期目标："+str(data().goals[item].name)
		"name_fish":
			if not has_aquarium(actor):return "这间小屋还没有鱼缸"
			if not present(actor,home(actor)):return "先回到自己家看鱼缸"
			if not item in data().fish or text=="":return "请指定鱼的编号（"+", ".join(data().fish)+"）和名字"
			k.fish[item]=text.substr(0,12);out.note="把这条鱼叫作「"+k.fish[item]+"」"
		"read_topic":
			if not data().books.has(item):return "没有这个书籍主题"
			k.selectedTopic=item;out.note="挑好了下次想读的主题："+str(data().books[item])
		"hang_painting":
			if not present(actor,home(actor)):return "先回自己家再挂画"
			var slot:int=int(args.get("slot",0));var slots:Array=data().wallSlots.get(home(actor),[])
			if slot<0 or slot>=slots.size():return "没有这个挂画位置"
			if not k.paintings.any(func(p):return p.id==item):return "还没有这幅画，完成画画后才会留下作品"
			k.wall[str(slot)]=item;out.note="把自己的画挂到了墙上"
		"receive","decline","acknowledge":
			var found:bool=false
			for note in k.notes:
				if note.id!=item:continue
				found=true
				if note.get("status")!="found":return "这份心意还没发现，或已经处理过了"
				if not present(actor,str(note.scene)):return "先走到放置这份心意的房间"
				if note.kind=="gift" and use=="acknowledge":return "礼物需要自己选择 receive 收下或 decline 婉拒"
				if note.kind!="gift" and use=="receive":return "这是一张留言卡"
				if use=="receive":
					if not Economy.catalog.has(note.product):return "这份礼物不在物品目录中"
					if Economy._bag_count(s)>=int(Economy.limits.bagSlots):return Economy.BAG_FULL
					s.bag[note.product]=int(s.bag.get(note.product,0))+1
					note.status="received"
				else:note.status="declined" if use=="decline" else "read"
				out.note="收下了主人留下的礼物" if use=="receive" else "婉拒了这份心意" if use=="decline" else "读到了主人留下的留言"
				break
			if not found:return "找不到这份留言"
		"claim_frame":
			var goal:Dictionary=k.get("goal",{})
			if goal.get("kind")!="save_frame" or goal.get("claimed",false):return "没有待完成的相框目标"
			if int(s.get("wallet",{}).get("coins",0))<60:return Economy.NO_MONEY
			s.wallet.coins-=60;goal.claimed=true;k.frame=true;out.note="用攒下的零花钱买了小相框"
		_ :return "不认识的纪念册操作"
	s.keepsakes=Economy._tidy(k)
	return ""
static func record(s:Dictionary,op:String,frame:Dictionary)->void:
	if not (op=="life_event" or (op=="gift_in" and frame.get("source")=="restaurant_cook")):return
	var k:Dictionary=state(s)
	if op=="gift_in" and frame.get("source")=="restaurant_cook":
		var dish:String=str(frame.get("product",""));k.recipes[dish]=int(k.recipes.get(dish,0))+1
	if op=="life_event":
		var e:Dictionary=frame.get("event",{})
		if e.get("type")=="use" and e.get("use")=="browse_book" and e.get("objectId") in ["bookshelf","xj_bookshelf"]:
			var topic:String=str(k.get("selectedTopic","ocean"))
			if data().books.has(topic):k.topic={"id":topic,"name":data().books[topic],"until":SharedFeed.now_ms()+1800000}
		if e.get("type")=="use" and str(e.get("use","")) in ["paint","draw","sketch"] and e.get("objectId") in ["easel","xj_easel"]:
			var id:String=str(frame.id)
			if not k.paintings.any(func(p):return p.id==id):
				var motif:String=str(e.get("motif",""))
				if not motif in data().motifs:motif=data().motifs[absi(id.hash())%data().motifs.size()]
				k.paintings.append({"id":id,"motif":motif,"at":SharedFeed.now_ms()})
				if k.paintings.size()>24:
					var removable:Array=k.paintings.filter(func(p):return not p.id in k.wall.values())
					if not removable.is_empty():k.paintings.erase(removable[0])
	s.keepsakes=Economy._tidy(k)
static func progress(s:Dictionary,actor:String)->Dictionary:
	var k:Dictionary=state(s);var goal:Dictionary=k.get("goal",{})
	if goal.is_empty():return {}
	var kind:String=str(goal.get("kind",""));var spec:Dictionary=data().goals.get(kind,{})
	if spec.is_empty():return {}
	var have:int=0;var detail:String=""
	if kind=="save_frame":have=60 if goal.get("claimed",false) else int(s.get("wallet",{}).get("coins",0))
	elif kind=="recipe":
		for id in k.recipes:
			if str(goal.get("dish",""))!="" and goal.dish!=id:continue
			if int(k.recipes[id])>have:have=int(k.recipes[id]);detail=str(Economy.catalog.get(id,{}).get("name",id))
	elif kind=="arcade":
		var mine:Dictionary=s.get("life",{}).get("records",{}).get("arcade",{})
		for peer in Economy.people:
			if peer==actor:continue
			var theirs:Dictionary=Economy.people[peer].get("life",{}).get("records",{}).get("arcade",{})
			for game in mine:
				if theirs.has(game) and mine[game] is Dictionary and theirs[game] is Dictionary and float(mine[game].get("best",0))>float(theirs[game].get("best",0)) and float(theirs[game].get("best",0))>0:have=1;detail=game
	if goal.get("done",false):have=maxi(have,int(spec.need));detail=str(goal.get("detail",detail))
	return {"kind":kind,"name":spec.name,"have":mini(have,int(spec.need)),"need":spec.need,"detail":detail,"done":have>=int(spec.need),"claimed":goal.get("claimed",false)}
static func remember_progress(s:Dictionary,actor:String)->void:
	var p:Dictionary=progress(s,actor)
	if p.get("done",false) and s.get("keepsakes",{}).get("goal",{}).get("kind")!="save_frame":
		s.keepsakes.goal.done=true;s.keepsakes.goal.detail=p.detail
static func valid(k:Dictionary)->bool:
	for field in ["fish","recipes","wall","goal","topic"]:
		if k.has(field) and not k[field] is Dictionary:return false
	for field in ["fish","wall"]:
		for value in k.get(field,{}).values():
			if not value is String:return false
	for key in k.get("wall",{}):
		if not str(key).is_valid_int():return false
	for field in ["selectedTopic","birthday"]:
		if k.has(field) and not k[field] is String:return false
	if k.has("frame") and not k.frame is bool:return false
	var goal:Dictionary=k.get("goal",{})
	if not goal.is_empty():
		if not goal.get("kind") is String or not data().goals.has(goal.kind):return false
		if goal.has("started") and not valid_number(goal.started):return false
		for field in ["claimed","done"]:
			if goal.has(field) and not goal[field] is bool:return false
	var topic:Dictionary=k.get("topic",{})
	if not topic.is_empty() and (not topic.get("id") is String or not topic.get("name") is String or not valid_number(topic.get("until"))):return false
	for value in k.get("recipes",{}).values():
		if not (value is int or value is float) or not is_finite(float(value)) or float(value)<0:return false
	for field in ["paintings","notes"]:
		if k.has(field) and not k[field] is Array:return false
	for p in k.get("paintings",[]):
		if not p is Dictionary or not p.get("id") is String or not p.get("motif") is String or not valid_number(p.get("at")):return false
	for n in k.get("notes",[]):
		if not n is Dictionary:return false
		for field in ["id","scene","kind","text","product","status"]:
			if not n.get(field) is String:return false
		if not n.status in ["placed","found","received","declined","read"] or not n.kind in ["note","gift","request"]:return false
		if not valid_number(n.get("at")) or (n.has("foundAt") and not valid_number(n.foundAt)):return false
	return true
static func valid_number(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value))
static func view(s:Dictionary,actor:String,now:float)->Dictionary:
	var k:Dictionary=state(s);var topic:Dictionary=k.get("topic",{})
	return {"goal":progress(s,actor),"fish":k.fish,"paintings":k.paintings.slice(-6),"wall":k.wall,"notes":k.notes.filter(func(n):return n.get("status")=="found").slice(-3),"topic":topic if float(topic.get("until",0))>now else {},"calendar":calendar(Economy.today()),"tool":"world_use objectId=world_journal；use=goal(item=save_frame/recipe/arcade)、name_fish(item=鱼编号,feeling=名字)、read_topic(item=主题)、hang_painting(item=画ID)、receive/decline/acknowledge(item=留言ID)、claim_frame"}
static func note(s:Dictionary,actor:String,now:float)->String:
	var v:Dictionary=view(s,actor,now);var parts:PackedStringArray=[]
	if not v.goal.is_empty():parts.append("长期目标：%s %s/%s"%[v.goal.name,v.goal.have,v.goal.need])
	if not v.notes.is_empty():
		var n:Dictionary=v.notes[-1];parts.append("发现主人的%s[%s]：%s"%[{"note":"留言","gift":"礼物","request":"小请求"}.get(n.kind,"留言"),n.id,str(n.text).substr(0,70)])
	if not v.topic.is_empty():parts.append("刚翻看的书："+str(v.topic.name))
	return "；".join(parts).substr(0,230)
