extends "res://qingxi-live/livestock.gd"
const Book=preload("res://qingxi-live/village-center/breed_catalog.gd")
# One husbandry day lasts 12 real minutes. Existing age and trough units stay in seconds.
const RATE=120.0
# The accelerated growth clock stays independent of meals and health.
const CARE_DIVISOR=60.0
const COST={"food":864.0,"drink":720.0}
const SEEK_AT=48.0
const CRITICAL_AT=10.0
const RECOVER_AT=65.0
const HUNGER_HP_PER_DAY=27.0
const THIRST_HP_PER_DAY=41.0
var visible_pasture=false
var advance_health=true
var births:Array=[]
var deaths:Array[String]=[]

func migrate():
	data.next_id=int(data.next_id)
	if not data.pens.has("chicken"):
		data.pens.chicken={"feed":43200.0,"water":0.0,"grass":0.0,"dirt":0.0}
	var indexes={}
	for a in data.herd:
		var index=int(indexes.get(a.kind,0))
		indexes[a.kind]=index+1
		if not a.has("genes"):founder(a,index%2,"f" if index%2==0 else "m")
		normalize_genes(a)
		a.hp=clampf(float(a.get("hp",Book.MAX_HP[a.kind])),1.0,float(Book.MAX_HP[a.kind]))
		if not a.pregnancy.is_empty():normalize_genes(a.pregnancy)

func normalize_genes(record:Dictionary):
	record.coat=int(record.coat)
	record.quality=int(record.quality)
	record.genes=[int(record.genes[0]),int(record.genes[1])]

func founder(a:Dictionary,coat:int,sex:String):
	a.merge({"genes":[coat,coat],"coat":coat,"sex":sex,"quality":1,"parents":[],"food":78.0,
		"drink":76.0,"hp":float(Book.MAX_HP[a.kind]),"mate":"","pregnancy":{},"auto_pair":true},true)

func add(kind:String)->Dictionary:
	if not Book.KIND.has(kind):return {}
	var a:Dictionary
	if kind=="chicken":
		var p=pen("pig").get_center()
		a={"id":str(data.next_id),"kind":kind,"pos":[p.x,p.y],"age":0.0,"progress":0.0,"ready":0,"shorn":false,"love":0.0,"cooldown":0.0}
		data.next_id+=1
		data.herd.append(a)
	else:
		a=super.add(kind)
	var index=members(kind).size()-1
	founder(a,index%2,"f" if index%2==0 else "m")
	return a

func adult(a:Dictionary)->bool:return a.age>=Book.MATURITY[a.kind]
func healthy(a:Dictionary)->bool:
	return a.food>=50 and a.drink>=50 and a.hp>=Book.MAX_HP[a.kind]*0.7
func can_produce(a:Dictionary)->bool:
	return Book.PRODUCT.has(a.kind) and (a.kind=="sheep" or a.sex=="f")
func grow_all():
	for a in data.herd:a.age=Book.MATURITY[a.kind]
func produce_all():
	for a in data.herd:
		if adult(a) and can_produce(a):
			a.ready=1
			a.shorn=false

func pool(a:Dictionary,need:String)->Dictionary:
	return data.pens.pig if a.kind=="chicken" and need=="drink" else data.pens[a.kind]
func creek(a:Dictionary)->bool:return bool(data.pens.get(a.kind,{}).get("creek",false))
func river_only(a:Dictionary)->bool:return bool(data.pens.get(a.kind,{}).get("river_only",false))
func available(a:Dictionary,need:String)->float:
	var p=pool(a,need)
	if need=="drink":
		if creek(a):return INF
		return 0.0 if river_only(a) else float(p.water)
	return float(p.feed)+(float(p.grass) if a.kind=="sheep" else 0.0)
func priority(a:Dictionary)->String:
	var needs=["drink","food"] if a.drink<=a.food else ["food","drink"]
	for need in needs:
		if a[need]<=SEEK_AT and available(a,need)>0:return need
	return ""
func consume_at_trough(a:Dictionary,need:String,points:float):
	var p=pool(a,need)
	var used=minf(points,minf(100.0-float(a[need]),available(a,need)/COST[need]))*COST[need]
	a[need]=minf(100.0,float(a[need])+used/COST[need])
	if need=="drink":
		if not creek(a):p.water=maxf(0.0,float(p.water)-used)
	else:
		if a.kind=="sheep":
			var grass=minf(float(p.grass),used)
			p.grass-=grass
			used-=grass
		p.feed=maxf(0.0,float(p.feed)-used)

func advance(dt:float):
	var remaining=maxf(0.0,dt)*RATE
	var detailed=minf(remaining,1209600.0)
	while detailed>0:
		var step=minf(1800.0,detailed)
		advance_step(step)
		detailed-=step
	var tail=maxf(0.,remaining-1209600.)
	# Keep checking the trough during long absences, including overnight.
	while tail>0:
		var chunk=tail if data.herd.is_empty() else minf(tail,3600.*CARE_DIVISOR)
		advance_step(chunk)
		tail-=chunk

func care_status(a:Dictionary)->String:
	var warnings:Array[String]=[]
	if a.food<=SEEK_AT:warnings.append("饥饿")
	if a.drink<=SEEK_AT:warnings.append("缺水")
	return " · ".join(warnings)

func resolve_health(a:Dictionary,previous_food:float,previous_drink:float,dt:float)->bool:
	if not advance_health:return true
	var starving=maxf(0.0,dt-maxf(0.0,previous_food-CRITICAL_AT)*COST.food) if a.food<CRITICAL_AT else 0.0
	var dehydrated=maxf(0.0,dt-maxf(0.0,previous_drink-CRITICAL_AT)*COST.drink) if a.drink<CRITICAL_AT else 0.0
	var damage=(starving*HUNGER_HP_PER_DAY+dehydrated*THIRST_HP_PER_DAY)/86400.0
	if damage>0:
		a.hp=maxf(0.0,float(a.hp)-damage)
		if a.hp<=0.0:
			var cause="饥饿和缺水" if starving>0 and dehydrated>0 else ("缺水" if dehydrated>0 else "饥饿")
			deaths.append("%s #%s 因%s死亡"%[Book.breed_name(a),a.id,cause])
			forget(a)
			return false
	elif minf(a.food,a.drink)>=RECOVER_AT:
		var limit=float(Book.MAX_HP[a.kind])
		a.hp=minf(limit,float(a.hp)+dt*limit/86400.0)
	return true

func take_deaths()->Array[String]:
	var result:=deaths.duplicate()
	deaths.clear()
	return result

func advance_step(dt:float):
	var care_dt=dt/CARE_DIVISOR
	data.pens.sheep.grass=minf(259200.0,float(data.pens.sheep.grass)+dt*.25)
	for a in data.herd.duplicate():
		a.cooldown=maxf(0.0,float(a.cooldown)-dt)
		a.love=maxf(0.0,float(a.love)-dt)
		var previous_food=float(a.food)
		var previous_drink=float(a.drink)
		a.food=maxf(0.0,previous_food-care_dt/COST.food)
		a.drink=maxf(0.0,previous_drink-care_dt/COST.drink)
		if not visible_pasture:
			for need in COST:
				if a[need]<=SEEK_AT:consume_at_trough(a,need,90.0-float(a[need]))
		if not resolve_health(a,previous_food,previous_drink,care_dt):continue
		if a.hp<float(Book.MAX_HP[a.kind])*.25 or minf(a.food,a.drink)<20:continue
		var active=dt*(.65 if a.kind=="pig" and data.pens.pig.dirt>=80 else 1.0)
		var growth_rate=1.25 if Book.breed_trait(a)=="growth" else 1.0
		var juvenile_time=minf(active,maxf(0.0,Book.MATURITY[a.kind]-float(a.age))/growth_rate)
		a.age=minf(Book.MATURITY[a.kind],float(a.age)+juvenile_time*growth_rate)
		if adult(a) and can_produce(a) and a.ready==0:
			var interval=Book.interval(a)
			a.progress=minf(interval,float(a.progress)+active-juvenile_time)
			if a.progress>=interval:a.ready=1;a.shorn=false
		if not a.pregnancy.is_empty():
			a.pregnancy.left=maxf(0.0,float(a.pregnancy.left)-dt)
			if a.pregnancy.left<=0:deliver(a)
	data.pens.pig.dirt=minf(100.0,float(data.pens.pig.dirt)+dt*members("pig").size()*15.0/86400.0)
	if not visible_pasture:pair_available(false)

func reserved(kind:String)->int:
	var total=members(kind).size()
	for a in members(kind):
		if not a.pregnancy.is_empty():total+=1
	return total
func compatible(a:Dictionary,b:Dictionary)->bool:
	if a==b or a.kind!=b.kind or a.sex==b.sex:return false
	if a.id in b.parents or b.id in a.parents:return false
	for id in a.parents:
		if id in b.parents:return false
	return true
func willing(a:Dictionary)->bool:
	return adult(a) and healthy(a) and a.cooldown<=0 and a.pregnancy.is_empty() and a.auto_pair
func partner(a:Dictionary)->Dictionary:
	if not willing(a):return {}
	for b in members(a.kind):
		if not willing(b) or not compatible(a,b):continue
		if (a.mate!="" and a.mate!=b.id) or (b.mate!="" and b.mate!=a.id):continue
		return b
	return {}
func pair_available(nearby:bool):
	for a in data.herd:
		if a.sex!="f":continue
		var b=partner(a)
		if b.is_empty():continue
		if nearby and Vector2(a.pos[0],a.pos[1]).distance_to(Vector2(b.pos[0],b.pos[1]))>48:continue
		# Roll once, at conception. A saved pregnancy retains the same offspring.
		var genes=[a.genes[randi_range(0,1)],b.genes[randi_range(0,1)]]
		var q=roundi((float(a.quality)+b.quality)/2.0)
		var chance=.18+(.15 if genes[0]!=genes[1] else 0.0)+(.18 if a.love>0 and b.love>0 else 0.0)
		if Book.breed_trait(a)=="line" or Book.breed_trait(b)=="line":chance+=.12
		if randf()<chance:q=mini(4,q+1)
		a.pregnancy={"left":Book.TERM[a.kind]*(.75 if Book.breed_trait(a)=="term" else 1.0),"sire":b.id,"genes":genes,"coat":genes[randi_range(0,1)],"sex":"f" if randf()<.5 else "m","quality":q}
		a.love=0;b.love=0;b.cooldown=21600.0
func deliver(a:Dictionary):
	var litter:Dictionary=a.pregnancy
	var baby=add(a.kind)
	if baby.is_empty():return
	baby.parents=[a.id,litter.sire]
	baby.genes=litter.genes.duplicate()
	baby.coat=litter.coat
	baby.sex=litter.sex
	baby.quality=litter.quality
	baby.pos=[a.pos[0]+12.0,a.pos[1]+8.0]
	a.pregnancy={}
	a.cooldown=21600.0
	births.append(baby.id)
func breed()->Array:
	pair_available(visible_pasture)
	var result=births.duplicate()
	births.clear()
	return result
func forget(a:Dictionary):
	data.herd.erase(a)
	for other in data.herd:
		if other.mate==a.id:other.mate=""
func treat(id:String,bag:Dictionary)->String:
	var a=animal(id)
	if a.is_empty():return "动物已离开"
	var food="carrot" if a.kind=="pig" else "wheat"
	if bag.get(food,0)<1:return "需要胡萝卜" if food=="carrot" else "需要小麦"
	if adult(a) and a.love>0:return "它已经吃过点心了"
	bag[food]-=1
	a.food=minf(100.0,float(a.food)+12)
	if adult(a):a.love=14400.0
	else:a.age=minf(Book.MATURITY[a.kind],float(a.age)+Book.MATURITY[a.kind]*.08)
	return "点心吃完了，配对时更容易育出优良后代" if adult(a) else "幼崽吃得很香，长大了一点"
func collect(id:String,bag:Dictionary)->String:
	var a=animal(id)
	if a.is_empty() or not can_produce(a) or not adult(a) or a.ready<=0:return "目前没有可以收取的产物"
	var key=Book.lot(Book.PRODUCT[a.kind],a.quality)
	var amount=Book.harvest_amount(a)
	bag[key]=int(bag.get(key,0))+amount
	a.ready=0;a.progress=0.0;a.shorn=a.kind=="sheep"
	return "收获%s ×%d" % [Book.item_name(key),amount]
func water_pen(kind:String)->String:
	if kind in ["chicken","pig"]:
		data.pens.pig.water=maxi(1,members("chicken").size()+members("pig").size())*172800.0
		return "水槽已加满"
	return super.water_pen(kind)
func feed_pen(kind:String,bag:Dictionary)->String:
	if kind!="chicken":return super.feed_pen(kind,bag).get_slice("：",0)
	if bag.wheat<=0:return "背包里缺少小麦"
	if data.pens.chicken.feed>=(members(kind).size()+1)*86400.0:return "槽里的谷物还很充足"
	bag.wheat-=1
	data.pens.chicken.feed+=86400.0
	return "添了一份小麦"

