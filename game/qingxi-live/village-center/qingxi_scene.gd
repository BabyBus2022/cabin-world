extends RefCounted
var world
var data
var art={}
var props=[]
var benches=[]
var lamps=[]
var building_lamps:Array[Vector2]=[]
const LAMP_PIXELS={
 "arcade":[Vector2(19,31),Vector2(50,31)],
 "bathhouse":[Vector2(55,82),Vector2(119,83)],
 "community_hall":[Vector2(75,62),Vector2(150,63)],
 "general_store":[Vector2(56,48),Vector2(101,50)],
 "house_b":[Vector2(51,49),Vector2(104,49)],
 "house_c":[Vector2(95,48),Vector2(149,48)],
 "house_d":[Vector2(42,48),Vector2(88,48)],
 "house_e":[Vector2(86,49),Vector2(143,48)],
 "tuantuan_home":[Vector2(106,50),Vector2(160,50)],
 "watermill":[Vector2(54,50)]
}
var fire
var seat=-1
var stand_point=Vector2.ZERO
var lamp_modes=[-1,-1,-1,-1]
var terrain
var strands=[]
func _init(host):world=host;data=host.qingxi
func atlas(name:String):
 if art.has(name):return art[name]
 var img=Image.load_from_file("res://qingxi-live/village-center/art/qingxi/"+name+".png")
 var cell=Vector2i(img.get_width()/2,img.get_height()/2);var result=[]
 for i in 4:
  var region=Rect2i(Vector2i(i%2,i/2)*cell,cell)
  # This atlas's lower hall silhouette crosses the nominal middle column.
  if name=="shops" and i==2:region=Rect2i(0,443,800,444)
  if name=="shops" and i==3:region=Rect2i(820,443,954,444)
  if name=="homes":region=Rect2i(0 if i%2==0 else 820,(i/2)*512,815 if i%2==0 else 716,512)
  if name=="finishing":region=Rect2i(0 if i%2==0 else 820,(i/2)*443,800 if i%2==0 else 954,444 if i>=2 else 443)
  var piece=img.get_region(region)
  result.append(ImageTexture.create_from_image(world.trim_image(piece)))
 art[name]=result;return result
func sprite(tex,p,width_,box=Rect2(),kind="prop"):
 var s=world.object(tex,p,width_,box,true,kind)
 s.material.shader=preload("res://qingxi-live/village-center/qingxi_sprite.gdshader")
 s.material.set_shader_parameter("native_grid",Vector2(roundf(width_/2),roundf(float(tex.get_height())*width_/tex.get_width()/2)))
 return s
func prop(kind:String,p:Vector2,box=Rect2(),size_=Vector2(80,40)):
 var node=preload("res://qingxi-live/village-center/qingxi_prop.gd").new();node.kind=kind;node.position=p;node.size_=size_;world.scenery.add_child(node);props.append(node)
 # Landmarks and plaza props drawn by tools/bake_landmarks.py, same 2x pixel scale as the houses.
 if kind in ["torii","bus","bench","lamp","well","board","mail","jizo","fire"]:
  var t=leaf_like("res://qingxi-live/village-center/art/jp/landmarks/"+kind+".png")
  var scale_=2.0
  if kind in ["well","board","mail","lamp","bench","jizo"]:
   var view="bench-back" if kind=="bench" and p.y>data.plaza.y else kind
   t=leaf_like("res://qingxi-live/village-center/art/refined/"+view+".png")
   scale_=.5
  var s=Sprite2D.new();s.texture=t;s.centered=false;s.scale=Vector2.ONE*scale_
  s.position=Vector2(-t.get_width()*.5,-t.get_height())*scale_
  s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;node.add_child(s);node.textured=true
  if kind=="lamp":
   var glass=Sprite2D.new()
   glass.texture=t;glass.centered=false
   glass.material=ShaderMaterial.new()
   glass.material.shader=preload("res://qingxi-live/village-center/lantern_glass.gdshader")
   s.add_child(glass);glass.hide();node.glass=glass
  if kind=="fire":
   var flame=ColorRect.new()
   flame.position=Vector2(-36,-110);flame.size=Vector2(72,88)
   flame.material=ShaderMaterial.new()
   flame.material.shader=preload("res://qingxi-live/village-center/village_embers.gdshader")
   flame.mouse_filter=Control.MOUSE_FILTER_IGNORE
   node.add_child(flame);node.flame_node=flame
  if box.size!=Vector2.ZERO:world.solids.append(Rect2(p+box.position,box.size))
  return node
 var mapping={"torii":["street",0,160],"bus":["street",1,180],"bench":["street",2,112],"lamp":["street",3,48],"arcade":["joinery",0,size_.x],"wall":["joinery",1,size_.x],"fence":["joinery",3,size_.x],"well":["village_props",0,66],"board":["village_props",1,96],"mail":["village_props",2,36],"jizo":["village_props",3,42]}
 mapping.merge({"fire":["finishing",0,84],"stonebridge":["finishing",1,size_.x],"woodbridge":["finishing",2,size_.x],"strand":["finishing",3,380]})
 if mapping.has(kind):
  var item=mapping[kind];var tex=atlas(item[0])[item[1]];var s=Sprite2D.new();s.texture=tex;s.centered=false
  var factor=float(item[2])/tex.get_width();s.scale=Vector2.ONE*factor;s.position=Vector2(-float(item[2])/2,-tex.get_height()*factor)
  if kind in ["wall","fence","arcade"]:
   var height_=40.0 if kind=="wall" else (24.0 if kind=="fence" else 94.0)
   s.scale.y=height_/tex.get_height();s.position.y=-height_
  var m=ShaderMaterial.new();m.shader=preload("res://qingxi-live/village-center/qingxi_sprite.gdshader");s.material=m
  m.set_shader_parameter("native_grid",Vector2(roundf(float(item[2])/2),roundf(-s.position.y/2)))
  node.add_child(s);node.textured=true
  if kind=="fire":
   var flame=preload("res://qingxi-live/village-center/qingxi_prop.gd").new();flame.kind="flame";node.add_child(flame);node.flame_node=flame
 if box.size!=Vector2.ZERO:world.solids.append(Rect2(p+box.position,box.size))
 return node
var foliage={}
var tree_rng=RandomNumberGenerator.new()
func leaf_like(path:String)->Texture2D:
 if not foliage.has(path):foliage[path]=ImageTexture.create_from_image(Image.load_from_file(path))
 return foliage[path]
func leaf(name:String)->Texture2D:
 if not foliage.has(name):
  foliage[name]=ImageTexture.create_from_image(Image.load_from_file("res://qingxi-live/village-center/art/jp/trees/"+name+".png"))
 return foliage[name]
func clear_spot(p:Vector2,margin:float)->bool:
 if data.on_road(p,margin) or data.water_blocks(p) or data.creek_clearance(p)<40:return false
 for b in data.buildings:
  if Rect2(b.pos-Vector2(float(b.w)/2+50,float(b.h)+30),Vector2(float(b.w)+100,float(b.h)+110)).has_point(p):return false
 for e in data.exits:
  if p.distance_to(e.pos)<(238.0 if e.get("reserved",false) else 165.0):return false
 return true
# One Cainos silhouette family for every tree (recoloured by tools/bake_trees.py);
# kinds pick a palette, shapes and mirroring vary so groves never repeat.
func tree(p:Vector2,index:int,_width:float,zoom:=2.0):
 if not clear_spot(p,45):return
 var palette=["green","deep","green","fruit","sakura"][index]
 if index==0 and tree_rng.randf()<.25:palette="deep"
 var tex=leaf("tree_%s_%d"%[palette,tree_rng.randi_range(0,2)])
 var width_=tex.get_width()*zoom
 var s=world.object(tex,p,width_,Rect2(-10,-8,20,16),true,"tree")
 s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;s.flip_h=tree_rng.randf()<.5
 world.trees.append({"sprite":s,"base":p,"width":width_,"kind":index})
func bush(p:Vector2,flower:=false):
 if not clear_spot(p,30):return
 var tex=leaf(("bush_flower_%d" if flower else "bush_%d")%tree_rng.randi_range(0,5))
 var s=world.object(tex,p,tex.get_width()*2.0,Rect2(),false,"tree")
 s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;s.flip_h=tree_rng.randf()<.5
## Place a baked building so its door lands on `door` (the plan's door point).
## Returns the sprite's world width; the side wing adds a solid of its own.
func house(id:String,door:Vector2,meta:Dictionary)->float:
 var info=meta[id]
 var path="res://qingxi-live/village-center/art/jp/houses/"+id+("-river" if id=="watermill" else "")+".png"
 var tex=leaf_like(path)
 var width_=float(tex.get_width())*2.0
 var base=door+Vector2((float(tex.get_width())/2.0-float(info.door_x))*2.0,6)
 var s=world.object(tex,base,width_,Rect2(),true,"house")
 s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 if id=="watermill":
  var wheel=preload("res://qingxi-live/village-center/waterwheel.gd").new()
  wheel.position=s.position+Vector2(232,74);s.get_parent().add_child(wheel)
 for bulb in LAMP_PIXELS.get(id,[]):building_lamps.append(base+s.position+bulb*2.0)
 # Feet are blocked by the whole footprint (wings included); the front row
 if not id in ["fire_tower","watermill","arcade"]:
  preload("res://qingxi-live/village-center/garden_details.gd").apron(world,base,width_,door)
 # leaves a lane at the door so the seed shop can still be walked into.
 var left=base.x-width_*.44;var right=base.x+width_*.44
 if id=="arcade":
  world.solids.append(Rect2(left,base.y-70,right-left,26));return width_
 world.solids.append(Rect2(left,base.y-104,right-left,66))
 world.solids.append(Rect2(left,base.y-40,door.x-28-left,30));world.solids.append(Rect2(door.x+28,base.y-40,right-door.x-28,30))
 if not id in ["seed_shop","livestock_shop"] and not world.rooms.contains("resident_"+id):world.solids.append(Rect2(door.x-28,base.y-40,56,24))
 return width_
func build():
 # Bridges, paths, water and plaza paving are painted into the baked ground.
 terrain=preload("res://qingxi-live/village-center/qingxi_terrain.gd").new();terrain.setup(world);world.map_layer.add_child(terrain)
 # Houses, shops, hall and bathhouse are drawn by tools/bake_houses.py in the same
 # pixel scale as the ground; homes are main house + wing in one connected sprite.
 var house_meta=JSON.parse_string(FileAccess.get_file_as_string("res://qingxi-live/village-center/art/jp/houses/houses.json"))
 # A covered walkway joins the general store to the seed shop.
 house("arcade",Vector2(670,1438),house_meta)
 for b in data.buildings:
  var tex
  var width_=float(b.w)
  if house_meta.has(str(b.id)):
   house(str(b.id),b.pos,house_meta)
  else:
   match str(b.id):
    "shrine":tex=atlas("landmarks")[0]
    "watermill":tex=atlas("landmarks")[2]
    "fire_tower":tex=atlas("landmarks")[3]
    "bus_stop":
     prop("bus",b.pos,Rect2(-70,-55,140,40))
     if world.get_tree().has_meta("qingxi_world_host"):world.add_target("cabin_bus",b.pos+Vector2(0,35),"乘公交回小屋世界")
     continue
   if b.id=="fire_tower":width_=106
   sprite(tex,b.pos,width_,Rect2(),"house")
   # Landmarks block feet across their base.
   var left=b.pos.x-width_*.40;var body=width_*.80
   world.solids.append(Rect2(left,b.pos.y-100,body,65));world.solids.append(Rect2(left,b.pos.y-35,body,27))
  if b.kind=="home":
   var room_id="resident_"+str(b.id)
   world.add_target("portal",b.pos,"进入"+str(b.name),room_id)
   world.LINKS.village.append([room_id,b.pos])
  elif b.id=="seed_shop":
   world.add_target("portal",b.pos,"走入青芽种子店","seedshop")
  elif b.id=="general_store":
   world.add_target("portal",b.pos,"走入小铃杂货","village_store")
   world.LINKS.village.append(["village_store",b.pos])
  elif b.id=="bathhouse":
   world.add_target("portal",b.pos,"走入暖汤屋","village_bath")
   world.LINKS.village.append(["village_bath",b.pos])
  elif b.id=="livestock_shop":
   world.add_target("portal",b.pos,"走入牧铃畜牧铺","livestockshop")
  else:
   world.add_target("shop" if b.id=="livestock_shop" else "facility",b.pos+Vector2(0,25),str(b.name),"livestock" if b.id=="livestock_shop" else str(b.id))
  world.world_label(str(b.name),b.pos+Vector2(0,18))
 # Four arcs sit wholly inside the round earth plaza; cardinal lanes stay open.
 for offset in [Vector2(-138,-138),Vector2(138,-138),Vector2(-138,138),Vector2(138,138)]:
  var p=data.plaza+offset;benches.append(p);prop("bench",p,Rect2(-55,-25,110,25))
  world.add_target("qingxi_bench",p+Vector2(0,26),"长凳 · 坐下",str(benches.size()-1))
 for offset in [Vector2(-190,-190),Vector2(190,-190),Vector2(-190,190),Vector2(190,190)]:
  var p=data.plaza+offset;lamps.append(prop("lamp",p,Rect2(-8,-7,16,14)));world.add_target("qingxi_lamp",p+Vector2(0,12),"广场灯柱 · 开关",str(lamps.size()-1))
 # The pit art sits above its anchor; drop it so it lands on the paved centre.
 fire=prop("fire",data.plaza+Vector2(0,28),Rect2(-36,-19,72,38));world.add_target("qingxi_fire",data.plaza+Vector2(0,65),"篝火庆典 · 加入跳舞")
 if world.sim.data.has("qingxi_lamps"):lamp_modes=world.sim.data.qingxi_lamps.duplicate()
 prop("torii",data.point([770,560]),Rect2())
 world.solids.append(Rect2(data.point([770,560])+Vector2(-65,-8),Vector2(24,16)));world.solids.append(Rect2(data.point([770,560])+Vector2(41,-8),Vector2(24,16)))
 for row in [["well",870,1110],["board",1275,795],["mail",1600,830],["jizo",1110,1330],["jizo",1880,1060]]:
  var p=data.point([row[1],row[2]]);prop(row[0],p,Rect2(-20,-18,40,18))
  if row[0]!="well":world.add_target("facility",p+Vector2(0,28),{"board":"村庄公告","mail":"村邮筒","jizo":"路边地藏"}[row[0]],row[0])
 var rng=RandomNumberGenerator.new();rng.seed=17317
 tree_rng.seed=24117
 # Forest edges: two staggered rows with jitter, bushes along the inner edge.
 for x in range(20,4800,70):
  for row in 2:
   tree(Vector2(x+rng.randi_range(-24,24)+row*35,110+row*70+rng.randi_range(-26,26)),0,0)
   tree(Vector2(x+rng.randi_range(-24,24)+row*35,3330-row*70+rng.randi_range(-20,20)),0,0)
  if rng.randf()<.55:bush(Vector2(x+rng.randi_range(-20,20),250+rng.randi_range(0,40)),rng.randf()<.2)
  if rng.randf()<.55:bush(Vector2(x+rng.randi_range(-20,20),3170+rng.randi_range(-30,10)),rng.randf()<.2)
 for y in range(130,3330,66):
  for col in 2:
   tree(Vector2(40+col*75+rng.randi_range(-22,22),y+col*30+rng.randi_range(-18,18)),0,0)
   tree(Vector2(4760-col*75+rng.randi_range(-22,22),y+col*30+rng.randi_range(-18,18)),0,0)
  if rng.randf()<.5:bush(Vector2(190+rng.randi_range(0,40),y),rng.randf()<.2)
  if rng.randf()<.5:bush(Vector2(4610-rng.randi_range(0,40),y),rng.randf()<.2)
 # Groves: clustered around their centres, with bushes at their feet.
 for row in [[1900,250,400,300,1],[2450,600,400,250,3],[180,300,250,250,0],[2400,1550,460,320,0],[320,1650,120,200,0],[1800,1950,180,200,0]]:
  var centre=data.point([row[0]+row[2]/2.0,row[1]+row[3]/2.0]);var spread=Vector2(row[2],row[3])*.75
  for i in 18:
   var offset=Vector2(rng.randfn(0,.33),rng.randfn(0,.33))*spread
   tree(centre+offset,int(row[4]),0)
   if i%3==0:bush(centre+offset*1.25+Vector2(rng.randf_range(-40,40),40),i%2==0)
 for p in data.plan.vegetation.cedar:tree(data.point(p),1,0)
 for p in data.plan.vegetation.persimmon:tree(data.point(p),3,0)
 for p in data.plan.vegetation.sakura:tree(data.point(p),4,0);bush(data.point(p)+Vector2(60,30),true)
 var camphor=data.point([960,790])
 var cs=world.object(leaf("tree_green_0"),camphor,leaf("tree_green_0").get_width()*3.0,Rect2(-20,-10,40,20),true,"tree")
 cs.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 world.trees.append({"sprite":cs,"base":camphor,"width":cs.texture.get_width()*3.0,"kind":0})
 for e in data.exits:
  if e.get("reserved",false):
   add_roadworks(e.pos)
  else:
   world.add_target("exit",e.pos,"→ "+str(e.name),str(e.to))

var roadworks=[]
func add_roadworks(exit:Vector2):
 var toward=(exit-Vector2(2400,1680)).normalized()
 var axis=toward
 var nearest=INF;var width=135.0
 for road in data.roads:
  for i in range(road.points.size()-1):
   var a:Vector2=road.points[i];var b:Vector2=road.points[i+1]
   var distance=Geometry2D.get_closest_point_to_segment(exit,a,b).distance_squared_to(exit)
   if distance>=nearest:continue
   nearest=distance;width=road.width
   axis=(b-a).normalized()
 if axis.dot(toward)<0:axis=-axis
 var work=preload("res://qingxi-live/village-center/roadworks.gd").new()
 work.position=(exit-axis*108).snapped(Vector2(2,2))
 world.scenery.add_child(work);work.setup(axis,width,roadworks.size())
 roadworks.append(work)

func works_block(p:Vector2)->bool:
 for work in roadworks:
  if work.blocks(p):return true
 return false

func tick():
 var night=world.night_level>.4
 for target in world.targets:
  if target.kind=="qingxi_fire":
   target.pos=data.plaza+Vector2(0,65) if night_festival() else Vector2(-900,-900)
   target.name="篝火庆典 · 退出跳舞" if dancing else "篝火庆典 · 加入跳舞"
 terrain.modulate=world.ground_tint
 for node in props:node.modulate=world.ground_tint
 for i in lamps.size():
  lamps[i].lit=night if lamp_modes[i]<0 else lamp_modes[i]==1
  lamps[i].glass.visible=lamps[i].lit
  if lamps[i].lit:lamps[i].modulate=Color.WHITE
  lamps[i].queue_redraw()
 fire.lit=night_festival();fire.phase=int(world.elapsed*5)%3;fire.modulate=Color.WHITE if fire.lit else world.ground_tint;fire.queue_redraw()
 fire.flame_node.visible=fire.lit
 for i in strands.size():
  if lamps[i*2].lit or lamps[i*2+1].lit:strands[i].modulate=Color.WHITE
var dancing=false
var dance_phase=0.0

func night_festival()->bool:
 var hour:float=world.sky_value()*24.0
 return hour>=19.0 or hour<5.0

func dance_point(offset:float)->Vector2:
 var angle=world.elapsed*.34+offset
 return data.plaza+Vector2(cos(angle)*125,sin(angle)*108)

func toggle_dance():
 if dancing:
  dancing=false
  return
 var p:Vector2=world.player.position-data.plaza
 dance_phase=atan2(p.y/108.0,p.x/125.0)-world.elapsed*.34
 dancing=true

func dance_player(dt:float):
 if not dancing:return
 if not fire.lit or [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT].any(func(key):return Input.is_physical_key_pressed(key)):
  dancing=false
  return
 var motion:Vector2=dance_point(dance_phase)-world.player.position
 if motion.length_squared()>1:
  world.move_actor(motion.limit_length(dt*95))
  world.facing=(1 if motion.x<0 else 2) if absf(motion.x)>absf(motion.y) else (3 if motion.y<0 else 0)
 var dance_key="dance-%d"%world.facing
 if world.clips.has(dance_key):world.show_action(dance_key,world.elapsed)
 elif motion.length_squared()>1:world.animate_walk()
 world.portrait.position.y-=pow(maxf(0,sin(world.elapsed*TAU*104.0/60.0)),2)*5.0

func sit(index:int):
 dancing=false
 stand_point=world.player.position;seat=index
 world.player.position=benches[index]+Vector2(0,-29 if seat>=2 else 1)
 world.close_menu();pose()
func pose():
 var north=seat>=2
 world.show_action("sit-north" if north else "sit-south",fmod(world.elapsed,1.7))
 world.portrait.position.y-=5.0 if north else 10.0
 world.contact_shadow.visible=false
func stand():
 if seat<0:return
 world.player.position=stand_point;seat=-1;world.contact_shadow.visible=true;world.show_idle()
func interact(kind:String,extra:String):
 match kind:
  "qingxi_bench":sit(int(extra))
  "qingxi_lamp":
   show_lamp(int(extra))
  "qingxi_fire":if fire.lit:toggle_dance()

func show_lamp(i:int):
 world.clear_menu("广场灯柱")
 world.menu_line("目前"+("亮着" if lamps[i].lit else "熄着")+" · "+("随昼夜自动" if lamp_modes[i]<0 else "手动控制"))
 world.menu_button("打开这盏灯",set_lamp.bind(i,1))
 world.menu_button("关闭这盏灯",set_lamp.bind(i,0))
 world.menu_button("随昼夜自动开关",set_lamp.bind(i,-1))

func set_lamp(i:int,mode:int):
 lamp_modes[i]=mode
 world.sim.data.qingxi_lamps=lamp_modes.duplicate()
 tick()
 if world.lighting:world.lighting.update_lights()
 world.save_progress();world.close_menu()
 world.notify({-1:"灯柱已恢复自动",0:"灯柱已关闭",1:"灯柱已打开"}[mode])
