extends RefCounted
const Fish=preload("res://qingxi-live/village-center/pond_fish.gd")
const Livestock=preload("res://qingxi-live/livestock.gd")
## 2026-11-21 qingxi-farm：枯萎档位/产出比例/文案都来自可见数据文件 qingxi-live/village-center/farm_rules.json。
const FarmRules=preload("res://qingxi-live/village-center/farm_rules.gd")
var livestock=Livestock.new()
## Isolated rural-playtest economy. Production time is independent of sky time.
const CROP_SECONDS=5400.0
const Garden=preload("res://qingxi-live/village-center/harvest/garden_kitchen.gd")
## The farm has 48 plots (three 4x4 patches); older saves with 12 are padded on load.
const PLOTS=48
const FISH_SECONDS=28800.0
const GROWTH={"cow":172800.0,"sheep":86400.0,"pig":172800.0}
const OUTPUT={"cow":28800.0,"sheep":43200.0,"pig":0.0}
const ANIMAL_PRICE={"cow":60,"sheep":50,"pig":40}
const NAMES={"cow":"牛","sheep":"羊","pig":"猪"}
# 2026-11-21 ③.3（业主原则「中文只在 json」）：这张中文表以前硬编码在这里，现在读 farm_rules.json 的 item_names 段。
# 名字仍是 static var，所以所有使用点（ITEM_NAMES[key] / for key in ITEM_NAMES / StateModel.ITEM_NAMES）一行都不用改。
static var ITEM_NAMES:Dictionary={}
static func load_item_names()->Dictionary:
	if ITEM_NAMES.is_empty():
		var doc=JSON.parse_string(FileAccess.get_file_as_string('res://qingxi-live/village-center/farm_rules.json'))
		if doc is Dictionary and doc.get('item_names') is Dictionary:
			ITEM_NAMES=doc['item_names']
	return ITEM_NAMES
const PRICES={"seed":2,"hay":3,"pig_feed":4,"fish_feed":2,"wheat":2,"carrot":2,"fry":5,"cat_food":3,"dog_food":3,"tomato_seed":3,"eggplant_seed":3,"strawberry_seed":4,"watermelon_seed":5}
const SELL={"carrot":2,"wheat":2,"tomato":6,"eggplant":6,"strawberry":8,"watermelon":10,"veg":4,"milk":12,"wool":16,"fish":10}
var data:Dictionary={}
func _init():
	load_item_names()
	reset()
func reset():
	load_item_names()
	livestock=Livestock.new()
	data={"version":2,"coins":160,"bag":{},"storage":{},"crops":[],"livestock":livestock.data,"pond":{"count":0,"progress":0.0,"feed":0.0},"energy":100,"map":"village","last_wall":Time.get_unix_time_from_system(),"test_uses":0}
	for key in ITEM_NAMES:
		data.bag[key]=0;data.storage[key]=0
	data.bag.seed=6;data.bag.hay=6;data.bag.pig_feed=6;data.bag.fish_feed=4;data.bag.wheat=12;data.bag.carrot=12;data.bag.fry=2
	for i in PLOTS:data.crops.append({"planted":false,"progress":0.0,"water":0.0})
func advance(seconds:float):
	var dt=maxf(seconds,0.0)
	advance_farm(dt)
	livestock.advance(dt)
func advance_farm(dt:float):
	for c in data.crops:
		if c.planted and c.progress<CROP_SECONDS:
			var used=minf(CROP_SECONDS-float(c.progress),minf(dt,float(c.water)))
			c.progress=minf(CROP_SECONDS,c.progress+used);c.water=maxf(0,c.water-used)
			if c.progress>=CROP_SECONDS:c["ripe_seconds"]=float(c.get("ripe_seconds",0))+maxf(dt-used,0)
		elif c.planted:
			# 2026-11-21 qingxi-farm（业主："不种田菜就会枯萎"）：成熟之后 ripe_seconds 只增不减；
			# 什么时候开始枯、枯几档、产出剩多少，全由 farm_rules.json 的 wither 段决定。
			# 这里不写死任何阈值。她不在的时候挂着也会枯（settle()->advance() 走的就是这条）。
			c["ripe_seconds"]=float(c.get("ripe_seconds",0.0))+maxf(dt,0.0)
	for stock in data.get("layout",{}).get("meadow_ground",{}).get("stocks",{}).values():advance_pond(stock,dt)
	if data.get("layout",{}).has("meadow_ground"):
		for pool in data.layout.get("dug_ponds",{}).get("ranch",[]):advance_pond(pool.stock,dt)
func advance_pond(pond:Dictionary,dt:float):
	Fish.grow(pond,dt)
func settle()->float:
	var now=Time.get_unix_time_from_system()
	var dt=maxf(0,now-float(data.last_wall))
	advance(dt);data.last_wall=now
	return dt
func sow(index:int,seed:String)->String:
	if index<0 or index>=data.crops.size() or data.crops[index].planted:return "这块田不能播种。"
	if not Garden.book().produce.has(seed) or int(data.bag.get(seed,0))<1:return "背包里没有这种种子。"
	var plot:Dictionary=data.crops[index]
	data.bag[seed]-=1
	plot.merge({"planted":true,"seed_key":seed,"progress":0.0,"water":0.0,"growth_version":2},true)
	plot.erase("ripe_seconds")
	return "已播种%s，湿润生长 90 分钟成熟。"%ITEM_NAMES[Garden.book().produce[seed]]
func crop_action(index:int)->String:
	var c:Dictionary=data.crops[index]
	if not c.planted:
		return sow(index,Garden.seed_for(data.bag,index))
	var seed=str(c.get("seed_key","seed"))
	var product=str(Garden.book().produce.get(seed,"veg"))
	var title=str(ITEM_NAMES[product])
	if c.progress>=CROP_SECONDS:
		# 2026-11-21 qingxi-farm：成熟太久会长枯。档位和产出比例读 farm_rules.json 的 wither 段。
		var tier:Dictionary=FarmRules.wither_tier(float(c.get("ripe_seconds",0.0)))
		var pct:=int(tier.get("yield_pct",100))
		if str(tier.get("id",""))=="withered":
			# 不是死局：铲掉枯苗，地块回到空地，可以立刻重新播种。
			c.planted=false;c.progress=0.0;c.water=0.0;c.erase("ripe_seconds")
			return "这块的菜已经%s，把枯苗铲掉了；收拾干净可以重新播种（不用再开垦）"%str(tier.get("name","枯了"))
		var veg:=int(floor(2.0*float(pct)/100.0+0.0001))
		var seeds:=1 if pct>=100 else 0
		data.bag[product]=int(data.bag.get(product,0))+veg
		data.bag[seed]=int(data.bag.get(seed,0))+seeds
		c.planted=false;c.progress=0.0;c.water=0.0;c.erase("ripe_seconds")
		if pct>=100: return "收获%s ×%d、%s ×1 留种。"%[title,veg,ITEM_NAMES[seed]]
		return "收获%s ×%d（%s：成熟后已 %.0f 小时，产出只剩 %d%%、没有种子）"%[title,veg,str(tier.get("name","")),float(tier.get("hours",0.0)),pct]
	c.water=14400.0
	return "浇水完成，可保持湿润 4 小时"
func buy(item:String)->String:
	if not PRICES.has(item):return "商品不存在"
	var price=int(PRICES[item])
	if data.coins<price:return "零钱不足"
	data.coins-=price;data.bag[item]=int(data.bag.get(item,0))+1
	return "买入%s ×1"%ITEM_NAMES[item]
func buy_animal(kind:String)->String:
	var price=int(ANIMAL_PRICE[kind])
	if data.coins<price:return "零钱不足"
	data.coins-=price;livestock.add(kind)
	return "买入幼%s，已送到牧场"%NAMES[kind]
func animal_action(id:String)->String:
	return livestock.collect(id,data.bag)
func sell_pig(id="")->String:
	var selected={}
	for a in livestock.members("pig"):
		if (id=="" or a.id==id) and livestock.adult(a):selected=a;break
	if selected.is_empty():return "没有可出售的成年猪"
	livestock.data.herd.erase(selected);data.coins+=90
	return "已出售成年猪，获得 90 币"
func pond_action()->String:
	return "请到自家农场建好的鱼塘边操作。"
func tend_pond(p:Dictionary)->String:
	if not is_home_pond(p):return "只能在自家农场建好的鱼塘操作。"
	if p.count==0: return stock_fry(p)
	if p.feed>=14400:return "鱼饲料充足。可以继续放苗，或抛竿钓鱼。"
	if data.bag.fish_feed<1:return "没有鱼饲料，去青芽种子店购买鱼饲料。"
	data.bag.fish_feed-=1
	p.feed+=43200.0
	return "已投喂，可供 12 小时生长。"

func stock_fry(p:Dictionary)->String:
	if not is_home_pond(p):return "只能在自家农场建好的鱼塘操作。"
	var n=mini(5,mini(int(data.bag.fry),24-int(p.count)))
	if n<=0:return "鱼塘已满" if p.count>=24 else "需要鱼苗，去青芽种子店买鱼苗。"
	var list=Fish.stock(p)
	for i in n:list.append(Fish.new_fish())
	data.bag.fry-=n
	p.count=list.size()
	return "放入混合鱼苗 ×%d。" % n

func keep_catch(kind:String,cm:float)->String:
	if not Fish.kinds().has(kind) or cm<=0:return ""
	var key="catch:%s:%d"%[kind,roundi(cm*10.)]
	data.bag[key]=int(data.bag.get(key,0))+1
	return key

func wild_catch()->String:
	var f=Fish.new_fish()
	return keep_catch(f.kind,f.cm)

func live_catches()->Array:
	return data.bag.keys().filter(func(k):return str(k).begins_with("catch:") and int(data.bag[k])>0 and Fish.kinds().has(k.get_slice(":",1)) and k.get_slice(":",2).is_valid_int() and int(k.get_slice(":",2))>0)

func restock(p:Dictionary,key:String)->String:
	if not is_home_pond(p):return "只有自家农场的鱼塘可以放养。"
	if int(p.count)>=24:return "鱼塘已满。"
	var options=live_catches()
	if key=="" and not options.is_empty():key=options[0]
	if not options.has(key):return "背包里没有这条鱼。"
	var kind=key.get_slice(":",1)
	var cm=float(key.get_slice(":",2))/10.0
	var adult=maxf(cm,minf(float(Fish.kinds()[kind].max),cm*1.4))
	var age=Fish.HOURS*clampf((cm/adult-.25)/.75,0,1)
	var school=Fish.stock(p)
	school.append({"kind":kind,"cm":adult,"age":age})
	p.count=school.size();p.progress=maxf(float(p.progress),age)
	data.bag[key]-=1
	if int(data.bag[key])==0:data.bag.erase(key)
	return "已放养"+Fish.label(key)+"。"

func catch_fish(p:Dictionary)->String:
	if not is_home_pond(p):return ""
	if int(p.count)<=0:return ""
	var list=Fish.stock(p)
	return land_fish(p,randi_range(0,list.size()-1))

func land_fish(p:Dictionary,index:int)->String:
	if not is_home_pond(p):return ""
	var list=Fish.stock(p)
	var f:Dictionary=list.pop_at(index)
	p.count=list.size()
	p.progress=0.0
	for other in list:p.progress=maxf(p.progress,other.age)
	if list.is_empty():p.feed=0.0
	var key=Fish.key_for(f)
	data.bag[key]=int(data.bag.get(key,0))+1
	return key

func harvest_pond(p:Dictionary)->String:
	if not is_home_pond(p):return "只能在自家农场建好的鱼塘操作。"
	var list=Fish.stock(p)
	var catches=PackedStringArray()
	for i in range(list.size()-1,-1,-1):
		if float(list[i].age)>=FISH_SECONDS:catches.append(Fish.label(land_fish(p,i)))
	return "收获成鱼："+ "、".join(catches) if not catches.is_empty() else "鱼还没养成，可继续投喂或在塘边垂钓。"

func pond_list()->Dictionary:
	var ponds={}
	var layout:Dictionary=data.get("layout",{})
	var ground:Dictionary=layout.get("meadow_ground",{})
	if not ground.is_empty():
		var parser=load("res://qingxi-live/village-center/flat-build/meadow_ground.gd")
		var tiles={}
		for k in ground.get("cells",{}):tiles[parser.coord(k)]=ground.cells[k]
		if not ground.has("stocks"):ground.stocks={}
		for id in parser.topology(tiles).basin.values():
			if not ground.stocks.has(id):ground.stocks[id]={"count":0,"progress":0.0,"feed":0.0}
			ponds["水湾"+str(id)]=ground.stocks[id]
	if layout.has("meadow_ground"):
		for pool in layout.get("dug_ponds",{}).get("ranch",[]):
			ponds["ranch@%d,%d"%[pool.x,pool.y]]=pool.stock
	return ponds

func is_home_pond(stock:Dictionary)->bool:
	for real_stock in pond_list().values():
		if is_same(stock,real_stock):return true
	return false

# Keep surplus legacy fish in their source record until a built pond has room.
# Both sides change in the same snapshot, so reopening never transfers a fish twice.
func recover_ponds():
	var sources=[data.pond]
	var layout:Dictionary=data.get("layout",{})
	for site in layout.get("dug_ponds",{}):
		if site!="ranch":
			for pool in layout.dug_ponds[site]:sources.append(pool.stock)
	if not sources.any(func(p):return int(p.get("count",0))>0):return
	var ponds=pond_list()
	if ponds.is_empty():return
	var pond_ids=ponds.keys()
	pond_ids.sort()
	for source in sources:
		if int(source.count)<=0:continue
		var old=Fish.stock(source)
		for id in pond_ids:
			var dest=ponds[id]
			var n=mini(old.size(),24-int(dest.count))
			if n<=0:continue
			var feed=float(source.feed)*float(n)/old.size()
			var fish=Fish.stock(dest)
			for i in n:
				var moved=old.pop_back()
				fish.append(moved)
				dest.progress=maxf(float(dest.progress),float(moved.age))
			dest.count=fish.size()
			dest.feed+=feed
			source.count=old.size()
			source.feed=maxf(0,float(source.feed)-feed)
			source.progress=0.0
			for remaining in old:source.progress=maxf(float(source.progress),float(remaining.age))
			if old.is_empty():break

func cook_catch(key:String)->String:
	if key.is_empty():
		for item in data.bag:
			if str(item).begins_with("catch:") and int(data.bag[item])>0:
				key=item;break
		if key.is_empty():key="fish"
	if not (key=="fish" or key.begins_with("catch:")) or int(data.bag.get(key,0))<=0:return "背包里没有这条鱼。"
	data.bag[key]-=1
	data.bag.meal+=1
	return "用%s做了一份鲜鱼料理，已放进背包。" % ("鲜鱼" if key=="fish" else Fish.label(key))

func sell_all()->String:
	var earned=0
	for key in SELL:
		earned+=int(data.bag[key])*int(SELL[key]);data.bag[key]=0
	data.coins+=earned
	return "出售农产品，获得 %d 币"%earned if earned>0 else "背包里还没有可出售的农产品"
func cook()->String:
	if data.bag.veg<2:return "做一份家常菜需要白菜 ×2"
	data.bag.veg-=2;data.bag.meal+=1
	return "做好家常菜 ×1，存入背包"
func eat()->String:
	if data.bag.meal<1:return "背包里没有家常菜"
	data.bag.meal-=1;data.energy=mini(100,int(data.energy)+30)
	return "吃完家常菜，精力恢复 30"
func store_items(take:bool)->String:
	var from:Dictionary=data.storage if take else data.bag
	var to:Dictionary=data.bag if take else data.storage
	var total=0
	for key in ITEM_NAMES:
		total+=int(from[key]);to[key]+=int(from[key]);from[key]=0
	return "%s %d 件物品"%["从家中取回" if take else "存入家中",total]
func rest()->String:
	data.energy=100
	return "休息好了，精力已恢复；现实时间不会跳到第二天"
func quick_grow(map_id:String)->String:
	data.test_uses+=1
	if map_id=="field":
		for c in data.crops:
			if c.planted:c.progress=CROP_SECONDS
		return "测试：当前已播种作物全部成熟"
	for pool in data.get("layout",{}).get("dug_ponds",{}).get(map_id,[]):
		if pool.stock.count>0:pool.stock.progress=FISH_SECONDS
	if map_id=="ranch":
		for stock in data.get("layout",{}).get("meadow_ground",{}).get("stocks",{}).values():
			if stock.count>0:stock.progress=FISH_SECONDS
		livestock.grow_all()
		return "测试：牧场现有幼畜全部成年"
	if map_id=="pond":
		if data.pond.count>0:data.pond.progress=FISH_SECONDS
		return "测试：鱼塘现有鱼苗全部长成"
	return "去田地、牧场或鱼塘使用 F6"
func quick_produce()->String:
	data.test_uses+=1
	livestock.produce_all()
	return "测试：成年牛羊各增加一份产物"
func supplies()->String:
	data.test_uses+=1;data.coins+=100;data.bag.seed+=5;data.bag.hay+=5;data.bag.pig_feed+=5;data.bag.fish_feed+=5;data.bag.wheat+=6;data.bag.carrot+=6;data.bag.fry+=2
	return "测试补给：100 币、种子、各类饲料、小麦、胡萝卜与鱼苗"
var commit_hook:Callable ## 2026-11-19 bag unification: core/bag_bridge.gd sets this; writes the bound person's bag/coins back to Economy
var cabin_wallet
func save_to(path:String):
	if cabin_wallet!=null:return cabin_wallet.save(self,path)
	return write_farm_file(path)

func write_farm_file(path:String):
	if commit_hook.is_valid():commit_hook.call()
	data.last_wall=Time.get_unix_time_from_system()
	var f=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if f==null:return false
	f.store_string(JSON.stringify(data));f.flush()
	var wrote=f.get_error()==OK
	f.close()
	if not wrote:return false
	return DirAccess.rename_absolute(path+".tmp",path)==OK
func load_from(path:String)->bool:
	if not FileAccess.file_exists(path):return false
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or int(parsed.get("version",0))!=2:return false
	for key in data:
		if key=="cabinCoinReceipt":continue # Optional on saves made before wallet unification.
		if not parsed.has(key):return false
	if not parsed.crops is Array or parsed.crops.size()<12:return false
	while parsed.crops.size()<PLOTS:parsed.crops.append({"planted":false,"progress":0.0,"water":0.0})
	bind_snapshot(parsed);return true

func bind_snapshot(snapshot:Dictionary):
	data=snapshot
	for plot in data.crops:
		if plot.planted and int(plot.get("growth_version",1))<2:
			plot.progress=clampf(float(plot.progress)/1200.0,0,1)*CROP_SECONDS
			plot.growth_version=2
			plot.seed_key="seed"
	for key in ITEM_NAMES:
		if not data.bag.has(key):data.bag[key]=0
		if not data.storage.has(key):data.storage[key]=0
	livestock.data=data.livestock
	recover_ponds()

## Young animals bought at 牧铃畜牧铺 travel in the bag ("young_cow" …) until the player
## lets them into their pen at the ranch. Kept outside ITEM_NAMES so older saves load as-is.
const YOUNG={"cow":"young_cow","sheep":"young_sheep","pig":"young_pig"}
const YOUNG_NAMES={"young_cow":"幼牛","young_sheep":"幼羊","young_pig":"幼猪"}
func buy_young(kind:String)->String:
	var price=int(ANIMAL_PRICE[kind])
	if data.coins<price:return "零钱不足"
	data.coins-=price;data.bag[YOUNG[kind]]=int(data.bag.get(YOUNG[kind],0))+1
	return "幼%s放进了背包"%NAMES[kind]
func release_young(kind:String)->String:
	var key=YOUNG[kind]
	if int(data.bag.get(key,0))<=0:return ""
	if livestock.add(kind).is_empty():return NAMES[kind]+"圈满了"
	data.bag[key]=int(data.bag[key])-1
	return "幼%s跑进了%s圈"%[NAMES[kind],NAMES[kind]]
