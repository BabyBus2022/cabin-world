extends SceneTree
const State=preload("res://qingxi-live/village-center/pasture_state.gd")
const Book=preload("res://qingxi-live/village-center/breed_catalog.gd")
var failures=[]
func check(ok:bool,msg:String):
	if not ok:failures.append(msg);push_error(msg)
func _initialize():run.call_deferred()
func find_purchase(shop,key:String)->Button:
	for b in shop.menu_body.find_children("*","Button",true,false):
		if b.get_meta("item","")==key:return b
	return null
func verify_model():
	var old=preload("res://qingxi-live/rural_state.gd").new()
	old.data.bag.milk=7
	var s=State.new()
	s.bind_snapshot(old.data.duplicate(true))
	var h=s.livestock
	check(h.data.herd.size()==6 and s.data.bag.milk==7,"migrate old stock and commodity")
	for kind in Book.KIND:
		var flock=h.members(kind)
		if flock.is_empty():h.add(kind);h.add(kind);flock=h.members(kind)
		var dam=flock[0];var sire=flock[1]
		h.founder(dam,2,"f");h.founder(sire,3,"m")
		dam.quality=3;sire.quality=3
		dam.age=Book.MATURITY[kind];sire.age=dam.age
		dam.drink=12.0;h.pair_available(false)
		check(dam.pregnancy.is_empty(),"thirst blocks pairing "+kind)
		dam.drink=88.0;h.pair_available(false)
		check(not dam.pregnancy.is_empty(),"natural pair "+kind)
		if dam.pregnancy.is_empty():continue
		var copy=State.new()
		s.save_to("user://test-pregnancy.json");copy.load_from("user://test-pregnancy.json")
		var loaded_pregnancy:Dictionary=copy.livestock.animal(dam.id).pregnancy.duplicate(true)
		var expected_pregnancy:Dictionary=dam.pregnancy.duplicate(true)
		var elapsed=float(expected_pregnancy.get("left",0))-float(loaded_pregnancy.get("left",0))
		loaded_pregnancy.erase("left");expected_pregnancy.erase("left")
		check(loaded_pregnancy==expected_pregnancy and elapsed>=0.0 and elapsed<h.RATE*1.0,"pregnancy roundtrip with offline progress")
		var genes=dam.pregnancy.genes.duplicate()
		h.advance(Book.TERM[kind]/h.RATE+1)
		flock=h.members(kind)
		var baby:Dictionary=flock.back()
		check(flock.size()==3 and baby.genes==genes and baby.parents==[dam.id,sire.id] and baby.quality>=3 and not h.adult(baby),"birth and inheritance "+kind)
		check(not h.compatible(baby,dam) and dam.cooldown>0,"family exclusions "+kind)
		var basic=baby.duplicate();basic.quality=1
		check(Book.live_price(baby)>Book.live_price(basic),"young price "+kind)
		if kind in Book.PRODUCT:
			h.produce_all()
			var key=Book.lot(Book.PRODUCT[kind],dam.quality)
			h.collect(dam.id,s.data.bag)
			var n=int(s.data.bag.get(key,0))
			var wallet=s.data.coins
			s.sell_lot(key);s.sell_lot(key)
			check(n>0 and s.data.coins==wallet+n*Book.price(key),"graded harvest and sale "+kind)
		var meat=Book.lot(Book.YIELD[kind][0],sire.quality)
		s.sell_stock(sire.id,true)
		check(s.data.bag.get(meat,0)>0 and h.animal(sire.id).is_empty(),"graded processing "+kind)
		sire=h.add(kind);h.founder(sire,0,"m");sire.age=Book.MATURITY[kind]
	var cow=h.members("cow")[0]
	cow.food=0;cow.drink=0;cow.hp=Book.MAX_HP.cow
	h.data.pens.cow.feed=0;h.data.pens.cow.water=0
	h.advance(60);check(cow.hp<Book.MAX_HP.cow,"empty troughs reduce HP")
	var hp=cow.hp
	h.feed_pen("cow",s.data.bag);h.water_pen("cow");h.advance(60)
	check(cow.hp>hp and cow.food>48 and cow.drink>48,"food and water restore HP")
func run():
	verify_model()
	change_scene_to_file("res://qingxi-live/village-center/main.tscn")
	await process_frame;await process_frame
	var world=current_scene
	world.set_physics_process(false)
	world.travel("livestockshop")
	for i in 5:await process_frame
	var shop=current_scene
	shop.set_physics_process(false);shop.stock_kind="chicken";shop.stock_sex="f";shop.open_shop()
	var key=Book.young_key("chicken",2,"f")
	var button=find_purchase(shop,key);check(button!=null,"real supplier counter")
	if button:button.pressed.emit()
	var purse=shop.sim.data.coins
	check(shop.sim.data.bag.get(key,0)==1 and purse==160-Book.stock_cost("chicken",2),"breed purchase")
	shop.return_to_center()
	for i in 5:await process_frame
	world=current_scene;world.set_physics_process(false);world.travel("ranch")
	world.release_young(key);world.close_menu()
	world.night_level=0.0
	var h=world.sim.livestock
	var chicken=h.members("chicken").front()
	check(chicken.coat==2 and chicken.sex=="f" and world.herd_ai.actors.has(chicken.id),"release specific chicken")
	for kind in Book.KIND:
		var a=h.members(kind).front()
		for need in ["drink","food"]:
			a.auto_pair=false;a.food=93.0;a.drink=93.0;a[need]=15.0
			var actor=world.herd_ai.actors[a.id]
			var goal=world.herd_ai.station_goal(a,need)
			for point in world.herd_ai.points[world.herd_ai.yard(kind)]:
				if point.distance_to(goal)>120:actor.node.position=point;break
			actor.path=PackedVector2Array();actor.need=""
			if need=="food":h.pool(a,need).feed=172800.0
			var stock=h.available(a,need)
			world.herd_ai.tick(.1)
			check(a[need]==15.0,"no refill at distance "+kind+need)
			for i in 1100:
				world.herd_ai.tick(.1)
				if a[need]>85:break
			if not (a[need]>85 and actor.node.position.distance_to(goal)<18 and (h.available(a,need)<stock or h.creek(a))):
				print("CARE DIAGNOSTIC ",kind," ",need," value ",a[need]," location ",actor.node.position," goal ",goal," mode ",actor.mode," stock ",stock," -> ",h.available(a,need)," meadow ",world.region.is_meadow()," clock ",world.sky_value()*24)
			check(a[need]>85 and actor.node.position.distance_to(goal)<18 and (h.available(a,need)<stock or h.creek(a)),"route to trough "+kind+" "+need)
	world.show_animal(chicken.id);world.show_pairing(chicken.id);world.stock_trade(chicken.id)
	world.show_pen("pig");world.show_bag();world.close_menu()
	chicken.age=Book.MATURITY.chicken;chicken.quality=4;chicken.ready=1
	world.perform(world.sim.animal_action(chicken.id))
	world.travel("livestockshop")
	for i in 5:await process_frame
	shop=current_scene;shop.set_physics_process(false);shop.open_shop()
	var lot=Book.lot("egg",4)
	button=find_purchase(shop,lot)
	check(button!=null,"graded egg on real shop counter")
	if button:button.pressed.emit()
	check(shop.sim.data.coins==purse+Book.price(lot)*2 and shop.sim.data.bag.get(lot,-1)==0,"shop pays quoted grade across scene handoff")
	print("BREEDING_VERIFY "+("PASS" if failures.is_empty() else "FAIL")+" "+JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)

