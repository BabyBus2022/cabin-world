extends RefCounted
const Stay=preload("res://qingxi-live/cottage_lodging.gd")
var owner_bed := ""
const Loft=preload("res://qingxi-live/dorm_loft.gd")
const SIDE_DOOR=Vector2(630,311)
const HOUSES=[
	{"pos":Vector2(1080,500),"door":Vector2(1075,507),"width":272.0,"title":"青瓦双层民居","floors":2},
	{"pos":Vector2(360,475),"door":Vector2(295,482),"width":256.0,"title":"绿瓦庭院小屋","floors":1},
	{"pos":Vector2(1540,750),"door":Vector2(1520,757),"width":224.0,"title":"木香双层民居","floors":2},
	{"pos":Vector2(990,1120),"door":Vector2(920,1127),"width":270.0,"title":"暖瓦农家小屋","floors":1}]
const FLOOR=Rect2(250,280,780,440)
const ENTRY=Vector2(640,695)
## 2026-11-19 Claude: the private cottage (room_private / room_private_up) has its own look
## (room_private_canvas.gd), Cabin World furniture (placement_grid.gd cw_*), and a staircase
## built along the right wall instead of standing in the middle of the floor. Ground floor:
## the flight rises northwards over STAIR_RUN; upstairs: a landing north of a railed
## stairwell, walk south into it to go down. Village houses keep the old layout.
const PRIVATE_DESIGN=3   # 3 = round 2 (dining table and chairs)
const STAIR_RUN=Rect2(926,380,92,180)        # the flight (both floors)
const STAIR_LANDING=Rect2(926,290,92,90)     # upstairs: where you step off
const STAIR_UP_PORTAL=Vector2(972,450)       # ground floor: walk north past this (two thirds up)
const STAIR_DOWN_PORTAL=Vector2(972,392)     # upstairs: walk south past this
const STAIR_GROUND_ARRIVAL=Vector2(972,590)
const STAIR_UPPER_ARRIVAL=Vector2(972,340)
static func private_room(id:String)->bool:return id=="room_private" or id=="room_private_up" or id==Stay.DORM
func design_of(id:String)->int:return PRIVATE_DESIGN if private_room(id) else 1
var world
var art=[]
var houses=[]
var configs={}
var furniture_seed=[]
func _init(host):
	world=host
	var sheet=world.full_image("village-houses.png")
	for rect in [Rect2i(0,0,600,640),Rect2i(600,0,680,640),Rect2i(0,640,570,640),Rect2i(570,640,710,640)]:
		houses.append(ImageTexture.create_from_image(world.trim_image(sheet.get_region(rect))))
	sheet=world.full_image("interior-furniture.png")
	var cell=Vector2i(sheet.get_width()/4,sheet.get_height()/2)
	for i in 8:art.append(ImageTexture.create_from_image(world.trim_image(sheet.get_region(Rect2i(Vector2i(i%4,i/4)*cell,cell)))))
	for i in HOUSES.size():register("room%d"%i,HOUSES[i].title,"village",HOUSES[i].door,int(HOUSES[i].floors),i)
	if world.get("qingxi") != null:
		var style=0
		for house in world.qingxi.buildings:
			if house.id=="bathhouse":
				register("village_bath",house.name,"village",house.pos,1,0)
				world.MAP_NAMES.village_bath=house.name
				world.LINKS.village_bath=[["village",Bath.EXIT]]
			if house.id=="general_store":
				register("village_store",house.name,"village",house.pos,1,0)
				world.MAP_NAMES.village_store=house.name
				world.LINKS.village_store=[["village",Store.EXIT]]
			if house.kind!="home":continue
			var id="resident_"+str(house.id)
			register(id,house.name,"village",house.pos,1,style%5)
			configs[id]["residence"]=str(house.id)
			style+=1
	register("room_private","私人小屋","home",Vector2(620,486),2,4)
	configs[Stay.DORM]={"style":4,"up":true,"title":"多人宿舍","outside":Stay.UPPER}
	world.MAP_NAMES[Stay.DORM]="私人小屋 · 多人宿舍"
	world.LINKS[Stay.DORM]=[]
func register(id:String,title:String,outside:String,door:Vector2,floors:int,style:int):
	configs[id]={"style":style,"up":false,"title":title,"outside":outside}
	world.MAP_NAMES[id]=title+" · 一层"
	world.LINKS[outside].append([id,door])
	world.LINKS[id]=[[outside,ENTRY]]
	if floors==2:
		var upper=id+"_up"
		configs[upper]={"style":style,"up":true,"title":title,"outside":outside}
		world.MAP_NAMES[upper]=title+" · 二层"
		var private_=private_room(id)
		world.LINKS[id].append([upper,STAIR_UP_PORTAL if private_ else Vector2(880,572)])
		world.LINKS[upper]=[[id,STAIR_DOWN_PORTAL if private_ else Vector2(880,606)]]
func contains(id:String)->bool:return configs.has(id)
func exterior():
	for i in HOUSES.size():
		var h:Dictionary=HOUSES[i]
		world.object(houses[i],h.pos,h.width,Rect2(),true,"house")
		var left=float(h.pos.x)-float(h.width)*0.40;var right=float(h.pos.x)+float(h.width)*0.40
		# A real opening in the footprint, not a trigger in front of a solid wall.
		world.solids.append(Rect2(left,h.pos.y-48,right-left,34))
		world.solids.append(Rect2(left,h.pos.y-14,h.door.x-24-left,14))
		world.solids.append(Rect2(h.door.x+24,h.pos.y-14,right-h.door.x-24,14))
func furniture(index:int,p:Vector2,width_:float,collision:Rect2,title="",action=""):
	if world.has_method("mount_placement"):
		var id=["bed","sofa","tea_table","cabinet","stove","chest","desk"][index]
		furniture_seed.append([id,p,width_,[collision.position.x,collision.position.y,collision.size.x,collision.size.y]])
		return
	world.object(art[index],p,width_,collision,false)
	if action!="":world.add_target("furniture",p+Vector2(0,18),title,action)
const Bath=preload("res://qingxi-live/village-center/village_bath.gd")
const Store=preload("res://qingxi-live/village-center/village_store.gd")
func build(id:String,arrival:Vector2):
	furniture_seed.clear()
	if id=="village_store":
		Store.build(world,arrival)
		return
	if id=="village_bath":
		Bath.build(world,arrival)
		return
	var conf:Dictionary=configs[id]
	var private_=private_room(id)
	var tuantuan=conf.get("residence","")=="tuantuan_home"
	var canvas=Node2D.new()
	var shell="res://qingxi-live/room_private_canvas.gd" if private_ else "res://qingxi-live/room_canvas.gd"
	if tuantuan:shell="res://qingxi-live/tuantuan_room_canvas.gd"
	canvas.set_script(load(shell));canvas.style=int(conf.style);canvas.upstairs=bool(conf.up)
	if private_:canvas.dorm=id==Stay.DORM
	canvas.z_index=-8;world.map_layer.add_child(canvas)
	if private_:
		var windows=preload("res://qingxi-live/cottage_windows.gd").new()
		world.map_layer.add_child(windows);windows.setup(world,id)
	if id!=Stay.DORM:
		world.solids.append(Rect2(250,260,780,30));world.solids.append(Rect2(250,280,14,440));world.solids.append(Rect2(1016,280,14,440))
		world.solids.append(Rect2(250,707,340,13));world.solids.append(Rect2(690,707,340,13))
	if id==Stay.DORM:
		for x in [400,632,864]:cw("cw_bed",Vector2(x,475),Rect2(-48,-105,96,105))
		cw("cw_side_table",Vector2(510,432),Rect2(-22,-18,44,18))
		cw("cw_side_table",Vector2(752,432),Rect2(-22,-18,44,18))
		cw("cw_album_cabinet",Vector2(327,340),Rect2(-36,-25,72,25))
	elif private_:build_private(bool(conf.up))
	elif tuantuan:build_tuantuan()
	elif conf.has("residence"):
		build_residence(conf.residence)
	elif conf.up:
		furniture(0,Vector2(420,480),94,Rect2(-40,-80,80,80),"床 · 休息","rest")
		furniture(6,Vector2(820,458),112,Rect2(-48,-38,96,38),"书桌 · 阅读","read")
		furniture(3,Vector2(710,392),72,Rect2(-30,-30,60,30))
		furniture(1,Vector2(541,605),122,Rect2(-52,-35,104,35),"沙发 · 歇一会儿","rest")
		furniture(5,Vector2(337,608),70,Rect2(-29,-29,58,29),"储物箱","storage")
	else:
		furniture(1,Vector2(450,468),140,Rect2(-61,-40,122,40),"沙发 · 歇一会儿","rest")
		furniture(2,Vector2(467,557),91,Rect2(-38,-25,76,25),"茶桌 · 吃饭","eat")
		furniture(3,Vector2(335,405),76,Rect2(-32,-30,64,30))
		if world.LINKS[id].size()>1:
			furniture(4,Vector2(838,414),145,Rect2(-61,-35,122,35),"灶台 · 做家常菜","cook")
			furniture(5,Vector2(739,585),72,Rect2(-30,-27,60,27),"储物箱","storage")
		else:
			furniture(0,Vector2(873,464),94,Rect2(-41,-80,82,80),"床 · 休息","rest")
			furniture(4,Vector2(855,622),131,Rect2(-56,-36,112,36),"灶台 · 做家常菜","cook")
			furniture(5,Vector2(582,401),72,Rect2(-30,-27,60,27),"储物箱","storage")
		# Short partition leaves a generous passage at its southern end.
		world.solids.append(Rect2(673,290,12,205))
	if not private_ and (conf.up or world.LINKS[id].size()>1):
		if not conf.up:
			var steps=world.object(art[7],Vector2(880,652),82,Rect2(),false)
			steps.get_parent().position.y=552;steps.position.y+=100
		world.solids.append(Rect2(841,560,12,103));world.solids.append(Rect2(907,560,12,103))
	for link in world.LINKS[id]:
		world.add_target("portal",link[1],("走下楼梯" if conf.up else "走上楼梯") if contains(link[0]) else "直接走出大门",str(link[0]))
		if private_ and contains(link[0]):world.targets.back()["half_width"]=STAIR_RUN.size.x/2.0   # 2026-11-19 Claude: the whole tread width
	if not conf.has("residence") and world.has_method("mount_placement"):
		world.mount_placement(Loft.SHELL if id==Stay.DORM else FLOOR.grow(-14))
		world.placement.seed_room(furniture_seed)
	var upper_spot=STAIR_UPPER_ARRIVAL if private_ else Vector2(880,543)
	if id==Stay.DORM:upper_spot=Loft.DOOR+Vector2(0,45)
	world.make_actor();world.player.position=arrival if arrival!=Vector2.ZERO else (upper_spot if conf.up else ENTRY-Vector2(0,55))
	if id==Stay.DORM and world.blocked(world.player.position):world.player.position=Loft.DOOR+Vector2(0,45)
	if tuantuan and world.blocked(world.player.position):
		world.player.position=ENTRY-Vector2(0,55)
	if private_:
		if id==Stay.UPPER or id==Stay.DORM:
			var label="回二楼卧室" if id==Stay.DORM else ("进入多人宿舍" if Stay.data(Stay.path_for(world)).get("expanded",false) else "扩建多人宿舍")
			world.add_target("furniture",Loft.DOOR if id==Stay.DORM else SIDE_DOOR,label,"cottage_door")
		var saved:String=Stay.data(Stay.path_for(world)).get("guests",{}).get("owner","")
		if saved.begins_with(id+"/") and world.placement.nodes.has(saved.get_slice("/",1)):
			owner_bed=saved
			world.player.position=world.placement.nodes[saved.get_slice("/",1)].target.pos
	world.show_idle();world.update_camera(true);world.set_light(world.sky_value());world.update_hud();world.queue_redraw()
## 2026-11-19 Claude: private cottage. Ground floor = kitchen corner (tiled, left), dining
## table, living corner (right) and the wall staircase; upstairs = bedroom with a study
## corner. All furniture is Cabin World's (cw_*); every piece can still be moved with G.
func cw(id:String,p:Vector2,collision:Rect2):
	var Grid_=preload("res://qingxi-live/village-center/placement_grid.gd")
	furniture_seed.append([id,p,float(Grid_.ITEMS[id][2]),[collision.position.x,collision.position.y,collision.size.x,collision.size.y]])
func build_private(up:bool):
	# Staircase walls and rails (see room_private_canvas.gd for the drawing).
	var run=STAIR_RUN
	if up:
		world.solids.append(Rect2(590,707,100,13))   # upstairs has no front door
		world.solids.append(Rect2(run.position.x-12,run.position.y,10,run.size.y+10))   # west railing
		world.solids.append(Rect2(run.position.x-12,run.end.y,run.size.x+12,10))      # south railing
		world.solids.append(Rect2(run.position.x,run.position.y+40,run.size.x,run.size.y-40))   # the well itself
	else:
		world.solids.append(Rect2(run.position.x-8,run.position.y,8,run.size.y-26))   # banister, open at the foot
		world.solids.append(Rect2(run.position.x,283,run.size.x,run.position.y-283))   # under the upstairs landing
	if not world.has_method("mount_placement"):return
	if up:
		cw("cw_bed",Vector2(336,424),Rect2(-62,-112,124,112))
		cw("cw_writing_desk",Vector2(530,348),Rect2(-62,-30,124,30))
		cw("cw_chair_n",Vector2(530,404),Rect2(-17,-14,34,14))
		cw("cw_bookshelf",Vector2(706,346),Rect2(-62,-34,124,34))
		cw("cw_album_cabinet",Vector2(330,664),Rect2(-62,-30,124,30))
		cw("cw_sofa",Vector2(760,600),Rect2(-62,-32,124,32))
		cw("cw_side_table",Vector2(612,604),Rect2(-36,-22,72,22))
	else:
		cw("cw_cupboard",Vector2(312,346),Rect2(-42,-34,84,34))
		cw("cw_stove",Vector2(406,346),Rect2(-42,-30,84,30))
		cw("cw_sink",Vector2(500,346),Rect2(-42,-30,84,30))
		cw("cw_bookshelf",Vector2(660,346),Rect2(-62,-34,124,34))
		cw("cw_chair_e",Vector2(314,556),Rect2(-17,-14,34,14))
		cw("cw_table",Vector2(416,566),Rect2(-80,-40,160,40))
		cw("cw_chair_w",Vector2(518,556),Rect2(-17,-14,34,14))
		cw("cw_sofa",Vector2(800,520),Rect2(-62,-32,124,32))
		cw("cw_side_table",Vector2(800,614),Rect2(-36,-22,72,22))
		cw("cw_album_cabinet",Vector2(820,346),Rect2(-62,-30,124,30))
func cottage_details(id:String)->Array:
	match id:
		Stay.DORM:return [
			["house_fern",958,327],["cw_bookshelf",761,341],["house_lamp",309,584],
			["cw_sofa",402,612],["cw_side_table",406,675],["house_cushions",504,665],
			["cw_writing_desk",819,585],["cw_chair_n",820,622],["house_easel",935,640],
			["house_basket",555,340]]
		Stay.UPPER:return [
			["house_fern",852,340],["house_easel",404,625],["house_basket",493,652],
			["house_lamp",841,573],["house_cushions",679,659],["cw_side_table",318,486]]
		_:return [
			["house_leaf",890,350],["house_basket",312,410],["cw_writing_desk",359,663],
			["cw_chair_n",360,698],["house_fern",535,663],["house_lamp",879,493],
			["house_cushions",716,626]]
func build_tuantuan():
	# The jambs, stove tiles and dining mat use the positions in tuantuan_room_canvas.
	world.solids.append(Rect2(250,280,780,118))
	world.solids.append(Rect2(250,398,118,322))
	world.solids.append(Rect2(912,398,118,322))
	world.solids.append(Rect2(368,706,228,14))
	world.solids.append(Rect2(684,706,228,14))
	# Local village furniture atlas: quilt bed, tea table, kitchen range and storage.
	world.object(art[4],Vector2(437,461),96,Rect2(-42,-37,84,36),false)
	world.object(art[0],Vector2(842,489),71,Rect2(-29,-57,58,56),false)
	world.object(art[3],Vector2(707,432),45,Rect2(-20,-13,40,13),false)
	world.object(art[5],Vector2(841,546),53,Rect2(-22,-22,44,21),false)
	world.object(art[2],Vector2(550,576),76,Rect2(-34,-29,68,28),false)
	var grid=preload("res://qingxi-live/village-center/placement_grid.gd")
	for side in [["E",496],["W",604]]:
		var chair=grid.cabin_texture("xiaojingyu-home--xj-desk-chair",side[0])
		world.object(chair,Vector2(side[1],570),26,Rect2(-11,-13,22,13),false)
	for item in [["crate",Vector2(391,491),28],["watering_can",Vector2(719,676),26]]:
		var img=Image.new()
		img.load_png_from_buffer(FileAccess.get_file_as_bytes("res://qingxi-live/village-center/art/regions/props/%s.png"%item[0]))
		world.object(ImageTexture.create_from_image(img),item[1],item[2],Rect2(-10,-9,20,9),false)
# Each interior is authored against the same door and partition. Positions mark the feet of furniture.
const RESIDENCES={
	"house_a":[["bookshelf",357,359],["bookshelf",512,359],["writing_desk",463,518],["chair_n",468,578],["bed",912,413],["side_table",768,403],["sofa",798,627]],
	"house_b":[["sink",339,357],["stove",445,357],["cupboard",550,357],["table",445,538],["chair_w",569,531],["bed",792,410],["album_cabinet",913,590]],
	"house_c":[["bed",389,413],["album_cabinet",553,365],["sofa",836,421],["side_table",844,508],["chair_e",751,552],["cupboard",934,635]],
	"house_d":[["writing_desk",369,353],["album_cabinet",547,357],["table",464,535],["chair_n",458,601],["bed",907,416],["bookshelf",761,363]],
	"house_e":[["bed",361,409],["side_table",505,401],["sofa",469,599],["bookshelf",777,359],["album_cabinet",931,359],["writing_desk",866,532],["chair_n",862,596]]
}
func build_residence(house:String):
	var grid=preload("res://qingxi-live/village-center/placement_grid.gd")
	world.solids.append(Rect2(670,282,18,215))
	for item in RESIDENCES.get(house,RESIDENCES.house_a):
		var model=grid.ITEMS["cw_"+str(item[0])]
		var tex=grid.cabin_texture(model[1])
		var w=float(model[2])
		var depth=80.0 if item[0]=="bed" else minf(35,w*.25)
		world.object(tex,Vector2(item[1],item[2]),w,Rect2(-w*.42,-depth,w*.84,depth),false)
## Warm lamp pools (x, y, radius) switched on with the other lamps at dusk.
func room_lights(id:String)->Array:
	if id=="resident_tuantuan_home":return [Vector3(438,436,180),Vector3(600,518,185)]
	if configs.get(id,{}).has("residence"):return [Vector3(435,445,245),Vector3(846,472,210)]
	if not private_room(id):return []
	if id==Stay.DORM:return [Vector3(444,560,180),Vector3(640,260,185),Vector3(1095,555,160)]
	if configs[id].up:return [Vector3(380,380,230),Vector3(700,540,250),Vector3(960,330,110)]
	return [Vector3(410,440,250),Vector3(800,500,240),Vector3(960,470,110)]
func floor_height(id:String,p:Vector2)->float:
	if private_room(id):   # 2026-11-19 Claude: lift the player step by step on the wall staircase
		if configs[id].up or not STAIR_RUN.has_point(p):return 0.0
		return floor((STAIR_RUN.end.y-p.y)/18.0)*3.0
	if configs[id].up or world.LINKS[id].size()<2:return 0.0
	if Rect2(853,560,54,100).has_point(p):return floor((660-p.y)/8)*3.0
	return 0.0
func portal_direction(from:String,to:String)->float:
	if not contains(from):return -1.0
	if not contains(to):return 1.0
	return 1.0 if configs[from].up else -1.0
func arrival(from:String,to:String)->Vector2:
	if to=="village_store":return Store.ENTRY
	if to=="village_bath":return Bath.ENTRY
	if to==Stay.DORM:return Loft.DOOR+Vector2(0,45)
	if contains(to):
		if not contains(from):return ENTRY-Vector2(0,55)
		if private_room(to):return STAIR_UPPER_ARRIVAL if configs[to].up else STAIR_GROUND_ARRIVAL   # 2026-11-19 Claude
		return Vector2(880,543) if configs[to].up else Vector2(880,678)
	for link in world.LINKS[to]:
		if link[0]==from:return link[1]+Vector2(0,33)
	return Vector2.ZERO
func leave_bed():
	if owner_bed=="":return
	if not Stay.wake(Stay.path_for(world),"owner"):
		world.notify("床位未能保存，请重试。");return
	owner_bed=""
	world.player.show()
	world.show_idle()
	world.perform(world.sim.rest())
func interact(action:String):
	if action.begins_with("cottage_sleep/"):
		var bed=action.trim_prefix("cottage_sleep/")
		var result=Stay.claim(Stay.path_for(world),"owner",world.map_id+"/"+bed)
		if result.has("error"):world.notify(result.error);return
		owner_bed=result.bed
		world.player.position=world.placement.nodes[bed].target.pos
		world.player.hide()
		world.notify("已经躺下休息，按 E 起床。")
		world.save_progress();return
	if action=="cottage_door":
		var dest=Stay.UPPER if world.map_id==Stay.DORM else Stay.DORM
		if dest==Stay.DORM and not Stay.expand(Stay.path_for(world)):
			world.notify("扩建未能保存，请重试。");return
		world.build_map(dest,(Loft.DOOR if dest==Stay.DORM else SIDE_DOOR)+Vector2(0,45))
		world.close_menu();world.save_progress();return
	match action:
		"warm_soak":
			world.sim.rest()
			world.perform("在暖汤屋泡过足汤，精力已恢复。")
		"rest":world.perform(world.sim.rest())
		"cook":world.sim.Garden.shelf(world,"肉菜")
		"eat":world.perform(world.sim.eat())
		"shared_chest":world.show_shared_chest()
		"storage":world.show_home()
		"read":world.notify("翻开乡村手记：水与饲料充足，动物才会继续长大。")
