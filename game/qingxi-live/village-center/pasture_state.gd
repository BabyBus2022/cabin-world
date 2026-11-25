extends "res://qingxi-live/rural_state.gd"
const Ownership=preload("res://core/pet_owner.gd")
const Pasture=preload("res://qingxi-live/village-center/pasture_herd.gd")
const Book=preload("res://qingxi-live/village-center/breed_catalog.gd")
const Pets=preload("res://qingxi-live/village-center/pets.gd")
const PetRules=preload("res://qingxi-live/village-center/pets_rules.gd")
const MEADOW_SAVE="user://open-meadow.json"
## 2026-11-21 pets: 宠物名册。data.pets 是懒迁移出来的（**不**在 rural_state.reset() 的必需键里，
## 否则旧存档会整档读不出来）；_pets 只是绑定缓存，data 换了就重建。
var _pets=null

func reset():
	super.reset()
	livestock=Pasture.new()
	data.livestock=livestock.data
	livestock.migrate()
	merge_feeders(data.bag)
	_pets=null

func load_from(path:String)->bool:
	if not super.load_from(path):return false
	# Advance stores and production across closed sessions without applying lethal damage.
	livestock.advance_health=false
	settle()
	livestock.advance_health=true
	return true

func bind_snapshot(snapshot:Dictionary):
	super.bind_snapshot(snapshot)
	for pet in data.get("pets",{}).get("list",[]):Ownership.restore(pet)
	livestock.migrate()
	merge_feeders(data.bag)
	_pets=null   ## 换了一份存档：宠物名册重新绑定（data.pets 会懒补）

# ---------------- 2026-11-21 pets ----------------
## 宠物名册（懒绑定 data.pets；旧存档第一次用到才补结构，不缺字段也不覆盖已有值）。
func pet_roster():
	if _pets == null or _pets.data != data:
		_pets=Pets.new(data)
	return _pets

## 领养：先按数据文件的价格扣钱，再当场住进农场（不经过背包）。返回人话回执。
## v2：可选品种（"橘猫"/"orange"/"cat-orange" 都认）。不写 = 这种的默认品种。
## 价格 = 基础价 + 品种差价，全部来自 pets_rules.json（adopt.price / breeds.*.price_offset）。
func name_owned_pet(id:String, raw:String, who:String, now:=Time.get_unix_time_from_system())->Dictionary:
	var pet:Dictionary=pet_roster().find(id)
	if pet.is_empty():return {"ok":false,"text":"没有这只宠物。"}
	var why=Ownership.denied(pet,who)
	if why!="":return {"ok":false,"text":why}
	return pet_roster().name(id,raw,who,now)

func adopt_pet(kind:String, breed:String="", who:String="owner")->String:
	var k:=PetRules.kind_of(kind)
	if k=="":return "要领养猫还是狗？（写 猫 / 狗，也可以写 猫:橘猫 这种带品种的）"
	if not PetRules.ok():return "宠物规则文件没装好（pets_rules.json）：先别领养"
	var b:=PetRules.breed_key_of(k,breed)
	if b=="":
		var names:=PetRules.breed_menu(k).map(func(r):return str(r.get("name","")))
		return "没有这个品种：%s（%s 现在有 %s）" % [str(breed),PetRules.kind_cn(k),"、".join(names)]
	var price:=PetRules.adopt_price_of(k,b)
	if int(data.coins)<price:return "零钱不足：领养%s要 %d 币，现在有 %d 币" % [PetRules.breed_cn({"kind":k,"breed":b}),price,int(data.coins)]
	var pet:Dictionary=pet_roster().adopt_of(k,b)
	if pet.is_empty():return "没领养成，过一会儿再试"
	pet.owner_id=who
	pet.follow=false
	data.coins=int(data.coins)-price
	return "领养了一只%s，%s（%s；还没取名，可以给它取个名字：name_pet %s:名字）" % [PetRules.breed_cn(pet),PetRules.name_text(pet),PetRules.stage_text(pet,Time.get_unix_time_from_system()),str(pet.get("id",""))]


## Feeders are bought at 牧铃畜牧铺 into the bag ("feeder_cow" …) and placed on the
## ranch grid in build mode (region.gd). Each kind eats from its own feeder.
const FEEDERS={"cow":"牧场食槽","sheep":"牧场食槽","pig":"牧场食槽","chicken":"牧场食槽"}
const FEEDER_PRICE={"cow":20,"sheep":20,"pig":20,"chicken":20}
# Keep feeder_cow as the canonical item id so old editors, icons and save files stay compatible.
static func merge_feeders(bag:Dictionary):
	for key in ["feeder_sheep","feeder_pig","feeder_chicken"]:
		if bag.has(key):
			bag.feeder_cow=int(bag.get("feeder_cow",0))+int(bag[key]);bag.erase(key)
func buy_feeder(kind:String)->String:
	if not FEEDERS.has(kind):return "没有这种食槽"
	if data.coins<20:return "零钱不足"
	data.coins-=20
	data.bag.feeder_cow=int(data.bag.get("feeder_cow",0))+1
	return "牧场食槽放进了背包"

func buy_stock(kind:String,coat:int,sex:String)->String:
	if not Book.KIND.has(kind) or coat<0 or coat>=Book.BREEDS[kind].size() or sex not in ["f","m"]:return "没有这个品种"
	var cost=Book.stock_cost(kind,coat)
	if data.coins<cost:return "零钱不足"
	var key=Book.young_key(kind,coat,sex)
	data.coins-=cost
	data.bag[key]=int(data.bag.get(key,0))+1
	return "买入"+Book.item_name(key)

func release_young(spec:String)->String:
	var kind=spec.get_slice(":",0)
	var key="young_"+spec
	if int(data.bag.get(key,0))<=0 or not Book.KIND.has(kind):return ""
	var a=livestock.add(kind)
	if a.is_empty():return "无法放养这种动物"
	if ":" in spec:livestock.founder(a,int(spec.get_slice(":",1)),spec.get_slice(":",2))
	data.bag[key]-=1
	return "放养了"+Book.breed_name(a)

const FARM_ITEMS={"well_water":"壶里的水","honey":"蜂蜜","dried_fish":"鱼干"}
const FARM_PRICES={"honey":8,"dried_fish":15}
const MILL_INPUT={"pig_feed":{"veg":1,"wheat":1},"fish_feed":{"wheat":2}}
const HONEY_TIME=1200.0
const DRY_TIME=600.0

func advance_farm(dt:float):
	super.advance_farm(dt)
	var timers:Dictionary=data.get("farm_timers",{})
	for station in timers:
		timers[station]=maxf(0.0,float(timers[station])-dt)
	## 2026-11-21 pets: 宠物也随时间走（闭式算术，见 pets.gd）。旧存档没有 pets 键时一个字节都不加。
	if data.has("pets"):
		var roster=pet_roster()
		var now=Time.get_unix_time_from_system()
		for pet in roster.list():
			if PetRules.is_cat(pet) and pet.get("follow",false):
				pet["last_away"]=now;pet["away_until"]=0.0
		roster.advance(dt)

func fill_can()->String:
	data.bag.well_water=3
	return "水壶已装满。到田边点背包里的水，可以连浇附近几格地。"

func water_area(indices:Array)->String:
	if int(data.bag.get("well_water",0))<=0:return "水壶空了"
	var watered=0
	for index in indices:
		if index<0 or index>=data.crops.size():continue
		var c:Dictionary=data.crops[index]
		if c.planted and c.water<CROP_SECONDS-float(c.progress):
			c.water=14400.0
			watered+=1
	if watered==0:return "身边没有需要浇水的作物"
	data.bag.well_water-=1
	return "浇好了 %d 格田，壶里还剩 %d 份水" % [watered,int(data.bag.well_water)]

func mill_feed(output:String)->String:
	if not MILL_INPUT.has(output):return "没有这个配方"
	var recipe:Dictionary=MILL_INPUT[output]
	for key in recipe:
		if int(data.bag.get(key,0))<recipe[key]:return "原料不足，还需要"+ITEM_NAMES[key]
	for key in recipe:data.bag[key]-=recipe[key]
	data.bag[output]=int(data.bag.get(output,0))+1
	return "磨好了一袋"+ITEM_NAMES[output]

func take_honey(station:String)->String:
	var timers:Dictionary=data.get_or_add("farm_timers",{})
	var wait=float(timers.get(station,0))
	if wait>0:return "蜂蜜还在酿，约 %d 分钟后可以再取" % ceili(wait/60)
	data.bag.honey=int(data.bag.get("honey",0))+1
	timers[station]=HONEY_TIME
	return "取到一罐蜂蜜，可以吃，也可以出货"

func dry_fish(station:String)->String:
	var timers:Dictionary=data.get_or_add("farm_timers",{})
	if timers.has(station):
		if timers[station]>0:return "鱼还在晾，约 %d 分钟后晒好" % ceili(float(timers[station])/60)
		data.bag.dried_fish=int(data.bag.get("dried_fish",0))+1
		timers.erase(station)
		return "收下一条鱼干，可以吃，也可以出货"
	if data.bag.fish<1:return "带一条鲜鱼来，可以挂在这里晾成鱼干"
	data.bag.fish-=1
	timers[station]=DRY_TIME
	return "挂好了一条鲜鱼，约 10 分钟后可以收鱼干"

func tea_break()->String:
	if int(data.coins)<2:return "零钱不足"
	if data.energy>=100:return "精力已满"
	data.coins-=2
	data.energy=mini(100,int(data.energy)+15)
	return "吃过茶点，精力 %d / 100"%data.energy

func eat_harvest(key:String)->String:
	if Garden.edible(key):return Garden.eat(self,key)
	if key not in ["honey","dried_fish"] or int(data.bag.get(key,0))<1:return "背包里没有这份食物"
	if data.energy>=100:return "精力已满，留着待会儿吃"
	var gain=mini(100-int(data.energy),12 if key=="honey" else 20)
	data.energy+=gain
	data.bag[key]-=1
	return "吃了%s，恢复 %d 点精力" % [FARM_ITEMS[key],gain]

func shipping_price(key:String)->int:
	if key.begins_with("catch:"):return Fish.price(key)
	return maxi(Book.price(key),int(FARM_PRICES.get(key,SELL.get(key,0))))

func goods_name(key:String)->String:
	if key.begins_with("decor_"):return str(load("res://qingxi-live/village-center/region.gd").PROP_NAMES.get(key.substr(6),key))
	if key.begins_with("catch:"):return Fish.label(key)
	if Book.price(key)>0:return Book.item_name(key)
	## 2026-11-21 batch10：先查 farm_rules.json 里的中文名（feeder_* / feed_* / seed），
	## 以前 feeder_cow 这类没有中文名就原样把英文 id 递给她。中文只在 json，代码不写死。
	var named:=FarmRules.goods_label(key)
	if named!="":return named
	return FARM_ITEMS.get(key,ITEM_NAMES.get(key,key))

func ship_goods(key:String,quantity:int)->String:
	var price=shipping_price(key)
	if price<=0 or quantity<=0 or quantity>int(data.bag.get(key,0)):return "这批货的数量不足"
	data.bag[key]-=quantity
	data.coins+=price*quantity
	return "售出%s ×%d，收入 %d 币" % [goods_name(key),quantity,price*quantity]

func sell_lot(key:String)->String:
	var cost=Book.price(key)
	var count=int(data.bag.get(key,0))
	if cost<=0 or count<=0:return "背包里没有这批货"
	return ship_goods(key,count)

func pair_stock(id:String,mate:String,enabled:bool)->bool:
	var current=livestock.animal(id)
	if current.is_empty():return false
	var partner=livestock.animal(mate)
	if mate!="" and (not enabled or partner.is_empty() or not livestock.adult(partner) or not livestock.compatible(current,partner)):
		return false
	clear_pair(current)
	current.auto_pair=enabled
	if not partner.is_empty():
		clear_pair(partner)
		current.mate=partner.id
		partner.mate=current.id
		partner.auto_pair=true
	return true

func clear_pair(animal:Dictionary):
	var partner=livestock.animal(str(animal.mate))
	if not partner.is_empty() and partner.mate==animal.id:partner.mate=""
	animal.mate=""

func sell_stock(id:String,process_meat:bool)->String:
	var a=livestock.animal(id)
	if a.is_empty():return "这只动物已离开"
	if not a.pregnancy.is_empty():return "等幼崽出生后再出栏"
	if process_meat and not livestock.adult(a):return "请等它成年后再出栏"
	if process_meat:
		var labels=[]
		for item in Book.YIELD[a.kind]:
			var key=Book.lot(item,a.quality)
			var amount=2 if item==Book.YIELD[a.kind][0] else 1
			if Book.breed_trait(a)=="yield" and Book.SPECIALTY[a.kind][a.coat]==item:amount+=1
			data.bag[key]=int(data.bag.get(key,0))+amount
			labels.append("%s ×%d" % [Book.item_name(key),amount])
		livestock.forget(a)
		return "已入袋："+"、".join(labels)
	var cost=Book.live_price(a)
	data.coins+=cost
	livestock.forget(a)
	return "已出售%s，收入 %d 币" % [Book.breed_name(a),cost]

func sell_pig(id="")->String:
	for a in livestock.members("pig"):
		if (id=="" or id==a.id) and livestock.adult(a) and a.pregnancy.is_empty():return sell_stock(a.id,false)
	return "没有可以出售的成年猪"

# All placed shared chests in this farm access one persistent inventory.
func shared_chest_rooms()->Array:
	var rooms=[]
	var plans:Dictionary=data.get("layout",{}).get("placement_by_map",{})
	for room in plans:
		for furniture in plans[room].get("furniture",{}).values():
			if furniture[0]=="shared_chest":
				rooms.append(room)
				break
	return rooms

func transfer_chest(take:bool,key:String,quantity:int)->String:
	var chest:Dictionary=data.get("shared_chest",{})
	var source:Dictionary=chest if take else data.bag
	var target:Dictionary=data.bag if take else chest
	if quantity<=0 or not source.has(key) or int(source[key])<quantity:
		return "数量不足，请重新查看箱子和背包。"
	source[key]=int(source[key])-quantity
	target[key]=int(target.get(key,0))+quantity
	if take and source[key]==0:source.erase(key)
	data.shared_chest=chest
	return "%s%s ×%d"%["从共用箱取出" if take else "存入共用箱：",goods_name(key),quantity]

func store_items(take:bool)->String:
	var source:Dictionary=data.storage if take else data.bag
	var target:Dictionary=data.bag if take else data.storage
	var total=0
	for key in source:
		var count=int(source[key])
		if count<=0:continue
		target[key]=int(target.get(key,0))+count
		source[key]=0
		total+=count
	return ("%s %d 件物品" % ["从家中取回" if take else "存入家中",total])

