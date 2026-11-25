extends RefCounted
const Sprite=preload("res://qingxi-live/village-center/pet_sprite.gd")
const Rules=preload("res://qingxi-live/village-center/pets_rules.gd")
var records:Array=[]
var loaded=false
var actors={}

func remember(sim):
	records=sim.data.get("pets",{}).get("list",[])
	loaded=true

func leader(host,who:String):
	if who=="owner":
		var body=host.game.local_player
		if host.active and not host.spectator:
			return host.scene.get("player") if body.player_enabled and is_instance_valid(host.scene) else null
		return body if body.player_enabled else null
	var resident=host._resident(who)
	if not is_instance_valid(resident) or not resident.placed:return null
	if resident.scene_id==host.PLACE:
		if host.active and is_instance_valid(host.scene) and host.scene.get("placement")!=null:
			var guests=host.Stay.data(host.profile_path_cached()).get("guests",{})
			var bed=str(guests.get(who,""))
			if bed.get_slice("/",0)==host.scene.map_id and host.scene.placement.nodes.has(bed.get_slice("/",1)):
				return host.scene.placement.nodes[bed.get_slice("/",1)].holder
		var visit=host.visitors.get(who,{})
		return visit.get("node") if host.active else null
	return resident

func add_choices(host,controls,options:Array):
	for id in actors:
		var node=actors[id].sprite
		if not is_instance_valid(node) or not node.is_visible_in_tree():continue
		if node.get_parent()!=controls.player.get_parent():continue
		var found=records.filter(func(p):return str(p.id)==id)
		if not found.is_empty():controls.add_choice(options,node.position,Rules.name_text(found[0])+" · 宠物",show_pet.bind(host,controls,id))

func show_pet(host,controls,id:String):
	var farm=host._farm_sim()
	var sim=farm.sim
	var pet=sim.pet_roster().find(id)
	if pet.is_empty():return
	controls.show_panel(Rules.name_text(pet)+" · "+Rules.breed_cn(pet))
	var info=Label.new()
	info.text="主人："+sim.Ownership.caption(pet)+"　"+Rules.stage_text(pet,Time.get_unix_time_from_system())+"\n亲密 %d / 100　饱食度 %d / 100"%[roundi(Rules.bond_of(pet)),roundi(Rules.food_of(pet))]
	controls.rows.add_child(info)
	controls.option("摸摸 / 陪它玩",interact.bind(host,controls,id,"play"))
	if sim.pet_roster().feed_key_for(str(pet.kind),sim.data.bag)!="":controls.option("喂它",interact.bind(host,controls,id,"feed"))
	if Rules.is_dog(pet):controls.option("带它出去走走",interact.bind(host,controls,id,"walk"))
	if sim.Ownership.denied(pet,"owner")!="":return
	var field=LineEdit.new()
	field.max_length=int(Rules.naming().get("max_chars",12))
	field.text=str(pet.get("name",""))
	controls.rows.add_child(field)
	controls.option("保存名字",func():interact(host,controls,id,"name",field.text))
	controls.option("叫它留在农场",interact.bind(host,controls,id,"stay"))

func interact(host,controls,id:String,action:String,value:String=""):
	var farm=host._farm_sim()
	var sim=farm.sim
	var roster=sim.pet_roster()
	var pet=roster.find(id)
	if pet.is_empty():return
	var message=""
	match action:
		"play":message=roster.play(id)
		"walk":message=roster.walk(id)
		"feed":message=roster.feed(id,sim.data.bag)
		"name":message=sim.name_owned_pet(id,value,"owner").text
		"stay":message=sim.Ownership.follow(pet,"owner",false)
	host._farm_commit(farm)
	if action=="stay":controls.panel.hide()
	else:
		show_pet(host,controls,id)
		controls.note.text=message

# Bed numbers are local to a room. Allocate them in roster order so littermates
# keep their own places even when their distance to the baskets changes.
func sleep_spot(host,pet:Dictionary,resident)->Vector2:
	var who=str(pet.get("owner_id",""))
	if who in ["","owner"] or not is_instance_valid(resident) or not resident.sleeping:return Vector2.INF
	var home=str(Residents.person(who).get("home",{}).get("scene",""))
	if home=="" or resident.scene_id!=home:return Vector2.INF
	var beds=host.pet_beds.spots(home).values()
	var index=0
	for member in records:
		if str(member.get("owner_id",""))!=who:continue
		if str(member.id)==str(pet.id):return beds[index] if index<beds.size() else Vector2.INF
		index+=1
	return Vector2.INF

func tick(host,dt:float):
	if not loaded:
		var snapshot=host._farm_sim()
		remember(snapshot.sim)
	if host.active and is_instance_valid(host.scene) and host.scene.get("open_meadow")==true:remember(host.scene.sim)
	host.pet_beds.draw_rooms(host)
	var claimed={}
	var seen={}
	for pet in records:
		var who=str(pet.get("owner_id",""))
		var body=leader(host,who)
		var bedtime=sleep_spot(host,pet,host._resident(who))
		if bedtime==Vector2.INF:
			if not pet.get("follow",false) or not is_instance_valid(body) or not body.is_visible_in_tree():continue
		else:
			body=host._resident(who)
		var native=host.active and is_instance_valid(host.scene) and host.scene.get("herd_ai")!=null and host.scene.is_ancestor_of(body)
		if native:continue
		var parent=host.game.rooms.get(body.scene_id) if bedtime!=Vector2.INF else body.get_parent()
		if not is_instance_valid(parent):continue
		var room=host.game.rooms.find_key(parent)
		var nav=WorldData.nav(str(room)) if room!=null else null
		var feet:Vector2=body.feet if "feet" in body else body.position
		var id=str(pet.id)
		seen[id]=true
		var row=actors.get(id,{})
		if not is_instance_valid(row.get("sprite")) or row.sprite.get_parent()!=parent:
			if is_instance_valid(row.get("sprite")):row.sprite.queue_free()
			var sprite=Sprite.new(str(pet.kind),Rules.breed_of(pet),Rules.body_scale(pet),Rules.is_baby(pet))
			parent.add_child(sprite)
			sprite.position=feet
			if bedtime!=Vector2.INF:
				var door=WorldData.scenes[room].entries.get("door",{})
				if not door.is_empty():
					var arrival=Vector2(door.x,door.y)
					if nav.walkable(arrival):sprite.position=arrival
			row={"sprite":sprite,"last":feet,"trail":[],"direction":Vector2.DOWN}
			actors[id]=row
		var node=row.sprite
		var comfort=preload("res://core/pet_comfort.gd")
		var goal=comfort.follow_target(row,feet,pet,dt)
		if row.get("bedtime",false) and bedtime==Vector2.INF:
			row.waited=0.;row.trail.clear()
		row.bedtime=bedtime!=Vector2.INF
		if not claimed.has(room):claimed[room]={}
		var bed=bedtime if row.bedtime else comfort.choose_bed(host.pet_beds.spots(str(room)),claimed[room],row,feet,node.position)
		if bed!=Vector2.INF:goal=bed
		var previous:Vector2=node.position
		var next=goal
		if nav!=null:
			if row.bedtime and not nav.walkable(previous):
				var door=WorldData.scenes[room].entries.get("door",{})
				if not door.is_empty() and nav.walkable(Vector2(door.x,door.y)):
					previous=Vector2(door.x,door.y)
			if not nav.walkable(goal):goal=feet
			next=goal
			if not nav.clear_line(previous,goal):
				if row.trail.is_empty() or goal.distance_to(row.get("route_goal",Vector2.INF))>12:
					row.trail=nav.route(previous,goal);row.route_goal=goal
				while not row.trail.is_empty() and previous.distance_to(row.trail[0])<4:row.trail.pop_front()
				next=previous if row.trail.is_empty() else row.trail[0]
		elif host.active and is_instance_valid(host.scene) and host.scene.has_method("blocked"):
			var work=preload("res://core/qingxi_work.gd")
			if host.scene.blocked(next):next=feet
			if not work.direct(host.scene,previous,next):
				row.repath=float(row.get("repath",0.))-dt
				if row.repath<=0.:
					row.trail=Array(work.walking_path(host.scene,previous,next));row.repath=.4
				while not row.trail.is_empty() and previous.distance_to(row.trail[0])<4:row.trail.pop_front()
				next=previous if row.trail.is_empty() else row.trail[0]
		node.position=previous.move_toward(next,clampf(previous.distance_to(goal)*3.,40.,390.)*Rules.speed_mult(pet)*dt)
		var moving=previous.distance_to(node.position)>.05
		if moving:row.direction=previous.direction_to(node.position)
		node.animate(dt,moving,"睡觉" if bed!=Vector2.INF and node.position.distance_to(bed)<4 else "跟随",row.direction)
	for id in actors.keys():
		if seen.has(id):continue
		if is_instance_valid(actors[id].sprite):actors[id].sprite.queue_free()
		actors.erase(id)
