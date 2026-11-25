extends RefCounted
## Builds the farm (cottage + 48-plot field), ranch and pond maps from
## art/regions/<map>/layout.json, in the same style as the village. Gameplay stays in
## the shared systems: crops (sim.data.crops), herd (farm_animals.gd with pen
## overrides), pond (living_pond.gd with baked geometry).
const Herd=preload("res://qingxi-live/livestock.gd")
const FOLDERS={"field":"farm","ranch":"ranch","pond":"pond","barn":"barn","barn_up":"barn"}
const NAMES={"field":"自家农场","ranch":"牧场","pond":"鱼塘","barn":"畜舍"}
var world
var id:String
var folder:String
var data
var layout:Dictionary
var terrain
var props_meta:Dictionary
var art={}
var rng=RandomNumberGenerator.new()
var lamps=[]
var door_lights=[]
var meadow_building_nodes={}
func _init(host,map_id:String):
 world=host;id=map_id;folder="res://qingxi-live/village-center/art/regions/"+FOLDERS.get(id,"barn")+"/"
 if id=="ranch" and world.get_meta("open_meadow",false):folder="res://qingxi-live/village-center/art/regions/meadow/"
 data=preload("res://qingxi-live/village-center/region_data.gd").new(folder);layout=data.layout
 if is_meadow():
  layout.barn=saved().get("meadow_barn",{})
 if world.barn_level(id)>1:layout.props=[]
 props_meta=JSON.parse_string(FileAccess.get_file_as_string("res://qingxi-live/village-center/art/regions/props/props.json"))
 rng.seed=4100+id.length()*31
func is_meadow()->bool:return id=="ranch" and world.get_meta("open_meadow",false)
func size()->Vector2:return Vector2(layout.world[0],layout.world[1])
func tex(path:String)->Texture2D:
 if not art.has(path):art[path]=ImageTexture.create_from_image(Image.load_from_file(path))
 return art[path]
func prop_tex(name:String)->Texture2D:return tex("res://qingxi-live/village-center/art/regions/props/"+name+".png")
## Sprite anchored bottom-centre at `p` at the art's native 2x scale.
func place(name:String,p:Vector2,collision:=Rect2(),shadow:=true,kind:="prop")->Sprite2D:
 var t=prop_tex(name)
 var s=world.object(t,p,t.get_width()*2.0,collision,shadow,kind)
 s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 return s

func build():
 terrain=preload("res://qingxi-live/village-center/qingxi_terrain.gd").new();terrain.folder=folder;terrain.setup(world);world.map_layer.add_child(terrain)
 for b in layout.buildings:building(str(b.id),Vector2(b.door[0],b.door[1]))
 refresh_props()
 for row in layout.exits:
  world.add_target("exit",Vector2(row.pos[0],row.pos[1]),"→ "+str(row.name),str(row.to))
 if world.barn_level(id)==0:border_trees()
 for g in layout.groves:grove(Rect2(g[0],g[1],g[2],g[3]),str(g[4]),int(g[5]))
 if is_meadow():build_meadow_exit()   # 2026-11-19 Claude: after the trees (see tree())
 match id:
  "field":build_farm()
  "ranch":build_ranch()
  "pond":build_pond()
  _:
   if world.barn_level(id)>0:build_barn_inside()

# ---------------- movable props ----------------
## Every prop on the farm, ranch and pond belongs to the player: saved per map in
## sim.data.layout["props_<map>"] as [name, x, y, uid], seeded from layout.json once.
## In build mode (G) a prop can be picked up into the bag ("decor_<name>") and set down
## anywhere open; its use (well, shipping bin, beehive, drying rack, lantern light...)
## follows it. uid keeps station timers (honey, drying fish) across moves.
const PROP_NAMES={"well":"水井","shipping_bin":"出货箱","mailbox":"信箱","beehive":"蜂箱","drying_rack":"晾晒架","scarecrow":"稻草人",
 "pump":"手压水泵","lantern":"路灯","bench":"长凳","barrel":"木桶","crate":"木箱","haybale":"草捆","haystack":"草垛","compost":"堆肥箱",
 "laundry":"晾衣架","wheelbarrow":"手推车","watering_can":"水壶","cart":"板车","milk_cans":"奶桶","silo":"谷仓","windmill":"风车",
 "signpost":"路牌","rod_rack":"鱼竿架"}
const BOXES={"well":Rect2(-40,-30,80,30),"scarecrow":Rect2(-8,-6,16,8),"compost":Rect2(-34,-24,68,24),"barrel":Rect2(-18,-14,36,14),
  "shipping_bin":Rect2(-40,-26,80,26),"beehive":Rect2(-22,-14,44,14),"haystack":Rect2(-44,-30,88,30),"laundry":Rect2(),"lantern":Rect2(-8,-6,16,8),
  "silo":Rect2(-44,-40,88,40),"windmill":Rect2(-40,-30,80,30),"pump":Rect2(-14,-10,28,10),"cart":Rect2(-56,-24,112,24),"boat":Rect2(),
  "crate":Rect2(-20,-14,40,14),"bench":Rect2(-42,-14,84,14),"milk_cans":Rect2(-32,-14,64,14),"haybale":Rect2(-28,-14,56,14)}
var prop_nodes={}   # uid -> {"nodes":[Node],"solids":[Rect2],"targets":[Dictionary]}
func props()->Array:
 var s=saved();var key="props_"+id
 if not s.has(key):
  s[key]=[]
  for row in layout.props:s[key].append([str(row[0]),float(row[1]),float(row[2]),"%d:%d"%[row[1],row[2]]])
 return s[key]
func movable(name:String)->bool:return PROP_NAMES.has(name)
func refresh_props():
 for uid in prop_nodes:drop_nodes(prop_nodes[uid])
 prop_nodes.clear();lamps.clear()
 for row in props():make_prop(row)
func drop_nodes(entry:Dictionary):
 # Forget the cast shadows and lit materials of these nodes before freeing them.
 for i in range(world.cast_shadows.size()-1,-1,-1):
  if entry.nodes.has(world.cast_shadows[i].polygon):world.cast_shadows.remove_at(i)
 for n in entry.nodes:
  if not is_instance_valid(n):continue
  for item in [n]+n.find_children("*","CanvasItem",true,false):
   if item is CanvasItem and item.material!=null:world.surfaces.erase(item.material)
 for n in entry.nodes:
  if is_instance_valid(n):n.queue_free()
 for r in entry.solids:world.solids.erase(r)
 world.targets=world.targets.filter(func(t_):return not entry.targets.has(t_))
## Builds one prop and remembers exactly which nodes, solids and targets it added.
func make_prop(row:Array):
 var name=str(row[0]);var p=Vector2(row[1],row[2]);var uid=str(row[3])
 var before=build_snapshot()
 var s=place(name,p,BOXES.get(name,Rect2(-16,-10,32,10)),name!="boat")
 if name=="lantern":lamps.append(p)
 if name=="boat":s.get_parent().z_index=-1
 prop_targets(name,p,uid)
 var added=build_additions(before)
 added.merge({"name":name,"pos":p})
 prop_nodes[uid]=added

func build_snapshot()->Array:
 return [world.scenery.get_child_count(),world.shadow_root.get_child_count(),world.map_layer.get_child_count(),world.solids.size(),world.targets.size(),door_lights.size()]

func build_additions(before:Array)->Dictionary:
 var nodes=world.scenery.get_children().slice(before[0])
 nodes.append_array(world.shadow_root.get_children().slice(before[1]))
 nodes.append_array(world.map_layer.get_children().slice(before[2]))
 return {"nodes":nodes,"solids":world.solids.slice(before[3]),"targets":world.targets.slice(before[4]),"lights":door_lights.slice(before[5])}
func prop_targets(name:String,p:Vector2,uid:String):
  match name:
   "bench":
    if is_meadow():world.add_target("meadow_seat",p+Vector2(0,18),"长凳 · 坐下",uid)
   "well":world.add_target("well",p+Vector2(0,24),"水井 · 打水")
   "shipping_bin":world.add_target("ship",p+Vector2(0,26),"出货箱 · 卖出农产品")
   "mailbox":world.add_target("note",p+Vector2(0,18),"信箱","信箱里还没有新来信。")
   "beehive":world.add_target("hive",p+Vector2(0,28),"蜂箱 · 取蜜","hive:"+uid)
   "drying_rack":world.add_target("dry_fish",p+Vector2(0,28),"晾晒架 · 挂鱼 / 收鱼干","rack:"+uid)
   "scarecrow":world.add_target("note",p+Vector2(0,16),"稻草人","稻草人守着田地，麻雀都不敢来。")
   "pump":world.add_target("well",p+Vector2(0,24),"手压水泵 · 装水")
## The movable prop under the mouse (its art's footprint), or "".
func prop_at(m:Vector2)->String:
 var best="";var dist=INF
 for uid in prop_nodes:
  var e=prop_nodes[uid]
  if not movable(e.name):continue
  var t=prop_tex(e.name);var w=t.get_width()*2.0;var h=t.get_height()*2.0
  var r=Rect2(e.pos.x-w/2,e.pos.y-h,w,h+6)
  if r.has_point(m) and m.distance_to(e.pos)<dist:dist=m.distance_to(e.pos);best=uid
 return best
func pick_prop(uid:String)->String:
 if not prop_nodes.has(uid):return ""
 var name=str(prop_nodes[uid].name)
 var timers:Dictionary=world.sim.data.get("farm_timers",{})
 if name=="drying_rack" and timers.has("rack:"+uid):return "架上还晾着鱼，先收鱼干"
 var list=props()
 for i in list.size():
  if str(list[i][3])==uid:list.remove_at(i);break
 timers.erase("hive:"+uid)
 drop_nodes(prop_nodes[uid]);prop_nodes.erase(uid)
 if name=="lantern":lamps.erase(Vector2(prop_nodes.get(uid,{}).get("pos",Vector2.ZERO)))
 lamps.clear()
 for e in prop_nodes.values():
  if e.name=="lantern":lamps.append(e.pos)
 var key="decor_"+name
 if not is_meadow():world.sim.data.bag[key]=int(world.sim.data.bag.get(key,0))+1
 return "ok"
## Can a prop of this kind stand with its base at p?
func prop_spot_ok(name:String,p:Vector2)->bool:
 var box:Rect2=BOXES.get(name,Rect2(-16,-10,32,10))
 var r=Rect2(p+box.position,box.size).grow(4)
 if not Rect2(Vector2(60,120),size()-Vector2(120,180)).has_point(p):return false
 for q in [r.position,r.end,Vector2(r.position.x,r.end.y),Vector2(r.end.x,r.position.y),p]:
  if world.blocked(q):return false
 for row in layout.exits:
  if p.distance_to(Vector2(row.pos[0],row.pos[1]))<120:return false
 if id=="field" or is_meadow():
  for q in plots():
   if Rect2(q[0],q[1],64,64).intersects(r):return false
 if is_meadow():
  if not zone().encloses(r) or world.facility_conflict(r) or r.grow(4).has_point(world.player.position):return false
  for entry in prop_nodes.values():
   if r.grow(10).has_point(entry.pos):return false
 return true
func put_prop(name:String,p:Vector2)->String:
 var key="decor_"+name
 if not is_meadow() and int(world.sim.data.bag.get(key,0))<=0:return "背包里没有"+PROP_NAMES.get(name,name)
 if not prop_spot_ok(name,p):return "这里放不下"
 if not is_meadow():world.sim.data.bag[key]=int(world.sim.data.bag[key])-1
 var s=saved();s.prop_serial=int(s.get("prop_serial",0))+1
 var row=[name,p.x,p.y,"n%d"%s.prop_serial]
 props().append(row);make_prop(row)
 return "ok"

func building(bid:String,door:Vector2):
 var info=props_meta[bid];var t=prop_tex(bid)
 var width_=t.get_width()*2.0
 var base=door+Vector2((t.get_width()/2.0-float(info.door_x))*2.0,6)
 var s=world.object(t,base,width_,Rect2(),true,"house");s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 preload("res://qingxi-live/village-center/garden_details.gd").apron(world,base,width_,door)
 var depth={"silo":40,"greenhouse":70}.get(bid,96)
 var left=base.x-width_*.4;var right=base.x+width_*.4
 world.solids.append(Rect2(left,base.y-depth-8,right-left,depth-30))
 world.solids.append(Rect2(left,base.y-40,door.x-26-left,30));world.solids.append(Rect2(door.x+26,base.y-40,right-door.x-26,30))
 world.solids.append(Rect2(door.x-26,base.y-40,52,22))
 door_lights.append(door)
 match bid:
  "cottage":
   world.solids.pop_back()   # the cottage door is a real opening into the house
   world.add_target("portal",door+Vector2(0,4),"走入 私人小屋","room_private")
   world.targets.back().merge({"half_width":38.0,"direction":-1.0,"approach":36.0})
   world.add_target("home",door+Vector2(70,40),"小屋檐下 · 做饭 / 储物 / 休息")
  "fry_shop":world.add_target("shop",door+Vector2(0,30),"鱼苗铺 · 鱼苗 / 饲料 / 收鱼","fish")
  "tool_shed":world.add_target("note",door+Vector2(0,30),"工具棚","锄头、水壶和镰刀都整齐挂在墙上。")
  "greenhouse":world.add_target("note",door+Vector2(0,30),"温室","温室里的花苗长得正好，以后可以在这里育苗。")
  "barn":world.add_target("note",door+Vector2(0,30),"牛舍","奶牛晚上回到牛舍里休息。")
 world.world_label({"cottage":"自家小屋","tool_shed":"工具棚","greenhouse":"温室","barn":"牛舍","sheep_shed":"羊舍","pig_sty":"猪舍","fry_shop":"鱼苗铺"}.get(bid,bid),door+Vector2(0,14))

# ---------------- trees ----------------
func leaf(name:String)->Texture2D:return tex("res://qingxi-live/village-center/art/jp/trees/"+name+".png")
func clear_spot(p:Vector2,margin:float)->bool:
 if not Rect2(Vector2.ZERO,size()).has_point(p):return false
 if data.on_road(p,margin) or data.water_blocks(p) or data.creek_clearance(p)<30:return false
 for box in world.solids:
  if box.grow(50).has_point(p):return false
 for row in layout.exits:
  if p.distance_to(Vector2(row.pos[0],row.pos[1]))<170:return false
 if id=="field":
  for q in plots():
   if Rect2(q[0],q[1],64,64).grow(50).has_point(p):return false
 if id=="ranch":
  if zone().grow(40).has_point(p) or Rect2(860,280,1180,520).has_point(p):return false
 return true
func tree(p:Vector2,palette:String):
 if not clear_spot(p,40):return
 if palette=="green" and rng.randf()<.25:palette="deep"
 var t=leaf("tree_%s_%d"%[palette,rng.randi_range(0,2)])
 # 2026-11-19 Claude: the random draws happen first, so leaving out the trees on the
 # village gate path does not move any other tree.
 if near_meadow_exit(p,165.0):rng.randf();return
 var s=world.object(t,p,t.get_width()*2.0,Rect2(-10,-8,20,16),true,"tree")
 s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;s.flip_h=rng.randf()<.5
 world.trees.append({"sprite":s,"base":p,"width":t.get_width()*2.0,"kind":0})
func bush(p:Vector2,flower:=false):
 if not clear_spot(p,26):return
 var t=leaf(("bush_flower_%d" if flower else "bush_%d")%rng.randi_range(0,5))
 if near_meadow_exit(p,80.0):rng.randf();return
 var s=world.object(t,p,t.get_width()*2.0,Rect2(),false,"tree");s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;s.flip_h=rng.randf()<.5

# ---------------- 2026-11-19 Claude: gate from the owner's farm to the village ----------------
## The open farm (meadow) had no way out on foot. A dirt lane now leaves the east edge,
## halfway down, with a signpost; walking to its end or pressing E there goes to 清溪村
## (the village's west street leads here). Arrivals from the village start on this lane.
const MEADOW_EXIT=Vector2(2800,1024)        # end of the lane at the east edge
const MEADOW_EXIT_LANE=Rect2(2560,984,320,80)
func near_meadow_exit(p:Vector2,margin:float)->bool:
 return is_meadow() and MEADOW_EXIT_LANE.grow(margin).has_point(p)
func meadow_gate_arrival()->Vector2:return MEADOW_EXIT-Vector2(150,0)
func build_meadow_exit():
 var r=MEADOW_EXIT_LANE
 var image=Image.new()
 if image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://qingxi-live/village-center/art/village-lane.png"))==OK:
  var lane=Sprite2D.new();lane.name="VillageLane";lane.centered=false;lane.z_index=-5
  lane.texture=ImageTexture.create_from_image(image);lane.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
  lane.position=r.position;lane.scale=r.size/Vector2(image.get_size())
  world.map_layer.add_child(lane)
 # 2026-11-19 Claude (round 2): the signpost is an ordinary movable prop (the owner wants to
 # lay such things out freely): put there once, then G + right click picks it up and the
 # 设施库 can place it (or more) anywhere.
 if not saved().get("gate_sign_seeded",false):
  saved().gate_sign_seeded=true
  var row=["signpost",r.position.x+70,r.position.y-6,"gate_sign"]
  props().append(row);make_prop(row)
 world.add_target("exit",MEADOW_EXIT-Vector2(58,0),"清溪村中心 →","village")
func grove(r:Rect2,palette:String,count:int):
 for i in count:
  var p=r.get_center()+Vector2(rng.randfn(0,.3)*r.size.x,rng.randfn(0,.3)*r.size.y)
  tree(p,palette)
  if i%3==0:bush(p+Vector2(rng.randf_range(-50,50),40),i%2==0)
func border_trees():
 var s=size()
 for x in range(20,int(s.x),72):
  for row in 2:
   tree(Vector2(x+rng.randi_range(-24,24)+row*36,100+row*66+rng.randi_range(-20,20)),"green")
   tree(Vector2(x+rng.randi_range(-24,24)+row*36,s.y-30-row*66+rng.randi_range(-16,16)),"green")
  if rng.randf()<.5:bush(Vector2(x,240+rng.randi_range(0,30)),rng.randf()<.25)
 for y in range(140,int(s.y)-20,66):
  for col in 2:
   tree(Vector2(40+col*72+rng.randi_range(-20,20),y+col*30),"green")
   tree(Vector2(s.x-40-col*72+rng.randi_range(-20,20),y+col*30),"green")

# ---------------- fences ----------------
## Pasture fences are laid edge by edge around painted cells (see build_ranch):
## fence_h along top/bottom edges, fence_v posts along the sides; each blocks feet.

# ---------------- player layout ----------------
## The player's own field plots and pens live in the save (sim.data.layout); the
## baked layout.json only supplies the starting arrangement.
func saved()->Dictionary:
 var d=world.sim.data
 if not d.has("layout"):d.layout={}
 return d.layout
func plots()->Array:
 var s=saved()
 if not s.has("plots"):
  s.plots=[]
  for row in layout.get("plots",[]):s.plots.append([row[0],row[1]])
 var cells:Array=s.plots
 while world.sim.data.crops.size()<cells.size():world.sim.data.crops.append({"planted":false,"progress":0.0,"water":0.0})
 if not s.get("grid_v2",false):
  var seen={};var i=0
  while i<cells.size():
   var c=((Vector2(cells[i][0],cells[i][1])-PLOT_ORIGIN)/64).round()*64+PLOT_ORIGIN
   if seen.has(c):cells.remove_at(i);world.sim.data.crops.remove_at(i);continue
   seen[c]=true;cells[i]=[c.x,c.y];i+=1
  s.grid_v2=true
 return cells
const CELL=64
const PLOT_ORIGIN=Vector2(10,2)
## A plot cell (64px grid) is free if its ground is walkable grass: no path,
## water, building, prop or other plot.
func plot_free(cell:Vector2)->bool:
 var r=Rect2(cell,Vector2(64,64))
 if is_meadow():
  if is_instance_valid(world.ground_tiles) and world.ground_tiles.cells.has(cell_of(r.get_center())):return false
  if not zone().encloses(r) or world.facility_conflict(r) or world.water_overlaps(r) or feeder_at(cell_of(r.get_center()))>=0:return false
  if barn_cell(cell_of(r.get_center())) or passage()==cell_of(r.get_center()):return false
  if MEADOW_EXIT_LANE.intersects(r.grow(-2)):return false   # 2026-11-19 Claude: keep the village lane open
 if not Rect2(Vector2(140,260),size()-Vector2(280,420)).encloses(r):return false
 for q in plots():
  if Rect2(q[0],q[1],64,64).intersects(r.grow(-2)):return false
 for box in world.solids:
  if box.intersects(r):return false
 for p in [r.position+Vector2(8,8),r.position+Vector2(56,8),r.position+Vector2(8,56),r.position+Vector2(56,56),r.get_center()]:
  if data.on_road(p,4) or data.water_blocks(p) or data.creek_clearance(p)<20:return false
 for row in layout.exits:
  if r.grow(120).has_point(Vector2(row.pos[0],row.pos[1])):return false
 return true
# ---------------- farm ----------------
var beds=[]
func build_farm():
 world.fields.clear();beds.clear()
 for q in plots():make_plot(Vector2(q[0],q[1]))
func make_plot(cell:Vector2):
 var rect=Rect2(cell,Vector2(64,64))
 var bed=Sprite2D.new();bed.texture=prop_tex("plot_soil");bed.centered=false;bed.scale=Vector2(2,2);bed.position=rect.position;bed.z_index=-7
 bed.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;world.map_layer.add_child(bed);beds.append(bed)
 # A thin earthen bund around each bed, so every 64px plot reads as one unit.
 var rim=Line2D.new();rim.width=3;rim.default_color=Color(.36,.22,.13,.7);rim.closed=true;rim.z_index=-6
 rim.points=PackedVector2Array([Vector2(1.5,1.5),Vector2(62.5,1.5),Vector2(62.5,62.5),Vector2(1.5,62.5)]);rim.position=rect.position
 bed.set_meta("rim",rim);world.map_layer.add_child(rim)
 var plant=world.object(world.crop_texture[0],rect.position+Vector2(32,54),46,Rect2(),false)
 plant.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 world.fields.append({"rect":rect,"state":-1,"sprite":plant,"timer":0.0})
## Layout mode: till a new plot (appends its crop slot) or take an empty one back.
func add_plot(cell:Vector2,refresh:=true)->String:
 if not plot_free(cell):return "这里不能开垦：避开小路、水边、建筑和已有田格"
 plots().append([cell.x,cell.y])
 while world.sim.data.crops.size()<plots().size():world.sim.data.crops.append({"planted":false,"progress":0.0,"water":0.0})
 make_plot(cell)
 if refresh:world.refresh_life()
 return "开垦了一格田 · 共 %d 格"%plots().size()
func remove_plot(index:int,refresh:=true)->String:
 if world.sim.data.crops[index].planted:return "这格还种着作物，先收获再收回"
 plots().remove_at(index);world.sim.data.crops.remove_at(index)
 if world.sim.data.crops.size()<world.sim.PLOTS:world.sim.data.crops.append({"planted":false,"progress":0.0,"water":0.0})
 beds[index].get_meta("rim").queue_free();beds[index].queue_free();beds.remove_at(index)
 world.fields[index].sprite.get_parent().queue_free();world.fields.remove_at(index)
 world.selected_cell=-1
 if refresh:world.refresh_life()
 return "收回了一格田 · 共 %d 格"%plots().size()
func cell_at(p:Vector2)->int:
 for i in world.fields.size():
  if world.fields[i].rect.has_point(p):return i
 return -1

# ---------------- ranch ----------------
## The ranch is one claimable 64px grid (layout.zone). The player owns the layout,
## saved in sim.data.layout.ranch_v3:
##   edges    {"h:c:r" | "v:c:r": "fence" | "gate"}  h = top edge of cell (c,r), v = left edge
##   feeders  [[kind, c, r], ...]                     bought at 牧铃畜牧铺, placed in G mode
## The creek is shallow: people and animals wade across it and fences may cross it.
## Enclosures are worked out from fences, gates (closed to animals) and the barn walls
## (cells under the barn). Each kind lives in the enclosure holding its feeder; it drinks
## from the creek when its enclosure takes in some of it, and sleeps in the barn when the
## enclosure includes the cell in front of the barn door. Kinds with no placed feeder
## stay in the barn.
const KINDS=["cow","sheep","pig","chicken"]
const FEEDER_SIZE={"cow":136,"sheep":98,"pig":102,"chicken":48}
const FenceJoint=preload("res://qingxi-live/village-center/fence_joint.gd")
var fence_posts=[]
var fence_nodes={}     # edge key -> {"holder":Node2D,"solid":Rect2}
var feeder_nodes=[]    # [{"holder":Node2D,"solid":Rect2,"cell":Vector2i}]
var enclosures=[]      # [{"cells":{Vector2i:true},"creek":bool,"barn":bool,"bank":Array}]
var home={}            # kind -> enclosure index
var troughs={}         # kind -> {"food":Vector2,"drink":Vector2}
var water_cache={}
func zone()->Rect2:
 var z=layout.get("zone",layout.pasture_zones[0]);return Rect2(z[0],z[1],z[2],z[3])
func zones()->Array:return [zone()]
func cols()->Vector2i:
 var z=zone();return Vector2i(int(z.position.x/CELL),int(z.end.x/CELL))
func rows()->Vector2i:
 var z=zone();return Vector2i(int(z.position.y/CELL),int(z.end.y/CELL))
func cell_of(p:Vector2)->Vector2i:return Vector2i((p/CELL).floor())
func cell_rect(c:Vector2i)->Rect2:return Rect2(Vector2(c)*CELL,Vector2(CELL,CELL))
func in_zone_cell(c:Vector2i)->bool:return c.x>=cols().x and c.x<cols().y and c.y>=rows().x and c.y<rows().y
func passage()->Vector2i:
 if layout.barn.is_empty():return Vector2i(-1,-1)
 return Vector2i(int(layout.barn.passage[0]),int(layout.barn.passage[1]))
func barn_door()->Vector2:
 if layout.barn.is_empty():return Vector2(layout.spawn[0],layout.spawn[1])
 return Vector2(layout.barn.door[0],layout.barn.door[1])
## A cell is water when most of it is creek (stepping stones count as land).
func cell_water(c:Vector2i)->bool:
 if world.has_method("dug_water") and world.dug_water(c):return true
 if water_cache.has(c):return water_cache[c]
 var n=0;var o=Vector2(c)*CELL
 for q in [Vector2(32,32),Vector2(12,12),Vector2(52,12),Vector2(12,52),Vector2(52,52)]:
  if data.creek_clearance(o+q)<1.0:n+=1
 water_cache[c]=n>=3;return n>=3
func barn_cell(c:Vector2i)->bool:
 if layout.barn.is_empty():return false
 var r=layout.barn.rect;return Rect2(r[0],r[1],r[2],r[3]).has_point(Vector2(c)*CELL+Vector2(32,32))
func ranch()->Dictionary:
 var s=saved()
 if is_meadow():
  if not s.has("meadow_pen"):s.meadow_pen={"edges":{},"feeders":[]}
  return s.meadow_pen
 if not s.has("ranch_v3") or int(s.ranch_v3.get("v",0))!=int(layout.default_ranch.get("v",1)):
  var d=layout.default_ranch;var r=d.paddock
  var edges={}
  for c in range(r[0],r[0]+r[2]):
   if Vector2i(c,r[1])!=passage() and not barn_cell(Vector2i(c,r[1]-1)):edges["h:%d:%d"%[c,r[1]]]="fence"
   edges["h:%d:%d"%[c,r[1]+r[3]]]="fence"
  for row in range(r[1],r[1]+r[3]):
   edges["v:%d:%d"%[r[0],row]]="fence";edges["v:%d:%d"%[r[0]+r[2],row]]="fence"
  edges["h:%d:%d"%[r[0]+3,r[1]+r[3]]]="gate"
  var feeders=[]
  for f in d.feeders:feeders.append([str(f[0]),int(f[1]),int(f[2])])
  s.ranch_v3={"edges":edges,"feeders":feeders,"v":int(layout.default_ranch.get("v",1))}
 return s.ranch_v3
## Edge geometry: its midpoint and the two cells it separates.
func edge_cells(key:String)->Array:
 var p=key.split(":");var c=Vector2i(int(p[1]),int(p[2]))
 return [c-Vector2i(0,1),c] if p[0]=="h" else [c-Vector2i(1,0),c]
func edge_mid(key:String)->Vector2:
 var p=key.split(":");var o=Vector2(int(p[1]),int(p[2]))*CELL
 return o+(Vector2(32,0) if p[0]=="h" else Vector2(0,32))
func edge_water(key:String)->bool:
 var m=edge_mid(key);var along=Vector2(14,0) if key.begins_with("h") else Vector2(0,14)
 return data.water_blocks(m) or data.water_blocks(m-along) or data.water_blocks(m+along)
func edge_key_between(a:Vector2i,b:Vector2i)->String:
 if a.x==b.x:return "h:%d:%d"%[a.x,maxi(a.y,b.y)]
 return "v:%d:%d"%[maxi(a.x,b.x),a.y]
func edge_ok(key:String)->String:
 var cs=edge_cells(key)
 if not in_zone_cell(cs[0]) and not in_zone_cell(cs[1]):return "只能在牧场的格子里围栏"
 if barn_cell(cs[0]) or barn_cell(cs[1]):return "畜舍墙边不用围栏"
 if is_meadow():
  var mid=edge_mid(key)
  var size_=Vector2(64,8) if key.begins_with("h:") else Vector2(8,64)
  var edge=Rect2(mid-size_/2,size_)
  if world.building_blocks_facility(edge):return "围栏不能挡住建筑或入口"
  if is_instance_valid(world.bridges) and world.bridges.overlaps(edge):return "围栏不能挡住桥面"
 return ""
## Place ("fence" / "gate") or remove ("") one edge.
func set_edge(key:String,kind:String)->String:
 var edges:Dictionary=ranch().edges
 if kind=="":
  if not edges.has(key):return ""
  edges.erase(key);refresh_ranch();return "ok"
 if edges.get(key,"")==kind:return ""
 var why=edge_ok(key)
 if why!="":return why
 edges[key]=kind;refresh_ranch();return "ok"
func feeder_at(c:Vector2i)->int:
 var list:Array=ranch().feeders
 for i in list.size():
  if Vector2i(int(list[i][1]),int(list[i][2]))==c:return i
 return -1
func place_feeder(kind:String,c:Vector2i)->String:
 var bag=world.sim.data.bag;var key="feeder_cow"
 if int(bag.get(key,0))<=0:return "背包里没有"+world.sim.FEEDERS[kind]
 if is_meadow() and (not world.terrain_cell_free(c,"feeder") or (is_instance_valid(world.ground_tiles) and world.ground_tiles.cells.has(c)) or world.water_overlaps(cell_rect(c))):return "食槽需要一格空草地"
 if not in_zone_cell(c) or cell_water(c) or barn_cell(c):return "食槽要放在牧场的草地格子上"
 if feeder_at(c)>=0:return "这格已经有食槽了"
 if c==passage():return "这里是畜舍的通道"
 bag[key]=int(bag[key])-1
 ranch().feeders.append([kind,c.x,c.y]);refresh_ranch();return "ok"
func take_feeder(c:Vector2i)->String:
 var i=feeder_at(c)
 if i<0:return ""
 var key="feeder_cow"
 world.sim.data.bag[key]=int(world.sim.data.bag.get(key,0))+1
 ranch().feeders.remove_at(i);refresh_ranch();return "ok"
## Flood-fill the grid into enclosures; a region that reaches the edge of the grid
## (other than through the barn passage) is open land, not an enclosure.
func compute_enclosures():
 enclosures.clear();home.clear()
 var edges:Dictionary=ranch().edges
 var seen={}
 for y in range(rows().x,rows().y):
  for x in range(cols().x,cols().y):
   var start=Vector2i(x,y)
   if seen.has(start) or barn_cell(start):continue
   var cells={start:true};var queue=[start];var head=0
   var open=false;var creek=false;var barn=false;var bank=[]
   seen[start]=true
   while head<queue.size():
    var c:Vector2i=queue[head];head+=1
    if c==passage():barn=true
    for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
     var n:Vector2i=c+d
     if edges.has(edge_key_between(c,n)):continue
     if not in_zone_cell(n):
      open=true;continue
     if barn_cell(n):continue
     if not cell_water(c) and cell_water(n):
      bank.append([c,n]);creek=true
     if seen.has(n):continue
     seen[n]=true;cells[n]=true;queue.append(n)
   if not open:enclosures.append({"cells":cells,"creek":creek,"barn":barn,"bank":bank})
 for f in ranch().feeders:
  var c=Vector2i(int(f[1]),int(f[2]));var k=str(f[0])
  if home.has(k):continue
  for i in enclosures.size():
   if enclosures[i].cells.has(c):
    home[k]=i;break
 # Old dedicated pens retain their occupants. A single placed trough serves every unassigned species.
 if not home.is_empty():
  var first=home.values()[0]
  for kind in KINDS:
   if not home.has(kind):home[kind]=first
func enclosure_of(kind:String)->Dictionary:
 return enclosures[home[kind]] if home.has(kind) else {}
## pasture_animals.gd reads the cells each kind may walk on.
func pen_cells()->Dictionary:
 var out={}
 for k in KINDS:
  var list=[]
  for c in enclosure_of(k).get("cells",{}):list.append([c.x*CELL,c.y*CELL])
  out[k]=list
 return out
func pens()->Dictionary:
 var out={}
 for k in KINDS:
  var e=enclosure_of(k)
  if e.is_empty():continue
  var r=Rect2();var first=true
  for c in e.cells:
   r=cell_rect(c) if first else r.merge(cell_rect(c));first=false
  out[k]=r
 return out
func has_barn(kind:String)->bool:return enclosure_of(kind).get("barn",false)
func in_zone(cell:Vector2)->bool:return in_zone_cell(cell_of(cell+Vector2(1,1)))

func build_ranch():
 if is_meadow():
  build_farm()
  if not layout.barn.is_empty():build_meadow_building("barn")
  if saved().has("meadow_house"):build_meadow_building("house")
 elif not layout.barn.is_empty():build_barn()
 refresh_ranch()

func build_meadow_building(kind:String):
 var before=build_snapshot()
 if kind=="barn":
  layout.barn=saved().meadow_barn
  build_barn()
 else:
  var door=saved().meadow_house
  building("cottage",Vector2(door[0],door[1]))
 meadow_building_nodes[kind]=build_additions(before)
 if kind=="barn" and world.ground_tiles!=null:refresh_ranch()

func remove_meadow_building(kind:String):
 var entry=meadow_building_nodes[kind]
 for light in entry.lights:door_lights.erase(light)
 for node in entry.nodes:
  if node is CanvasItem:node.hide()
 drop_nodes(entry)
 meadow_building_nodes.erase(kind)
 if kind=="barn":
  layout.barn={}
  refresh_ranch()
func build_barn():
 var t=tex("res://qingxi-live/ranch-life/art/barn-exterior.png");var b=layout.barn
 var base=Vector2(b.base[0],b.base[1]);var w=t.get_width()*2.0
 # The doorway in the art is open: show the dim barn inside (straw floor fading into shade).
 var inside=Polygon2D.new();inside.z_index=-4
 inside.position=base
 inside.polygon=PackedVector2Array([Vector2(-68,-144),Vector2(68,-144),Vector2(68,-36),Vector2(-68,-36)])
 inside.vertex_colors=PackedColorArray([Color("1f1611"),Color("1f1611"),Color("6b5232"),Color("6b5232")])
 world.map_layer.add_child(inside)
 var s=world.object(t,base,w,Rect2(),true,"house");s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 var door=barn_door()
 # Walls either side of the open doorway; the dark doorway itself stops the player.
 var left=base.x-w/2+20;var right=base.x+w/2-20
 world.solids.append(Rect2(left,base.y-300,right-left,250))
 world.solids.append(Rect2(left,base.y-50,door.x-80-left,44))
 world.solids.append(Rect2(door.x+80,base.y-50,right-door.x-80,44))
 world.solids.append(Rect2(door.x-80,base.y-60,160,12))
 world.add_target("portal",door+Vector2(0,14),"进入畜舍","barn")
 world.targets.back().merge({"half_width":192.0,"direction":-1.0,"approach":36.0,"inside_reach":20.0})
 door_lights.append(door)
## Rebuild fences, gates and feeders from the saved layout (also live while editing).
func refresh_ranch():
 clear_fence_nodes()
 for f in feeder_nodes:
  f.holder.queue_free();world.solids.erase(f.solid)
 feeder_nodes.clear()
 world.targets=world.targets.filter(func(t):return t.kind!="pen")
 compute_enclosures()
 Herd.pen_override.clear()
 var boxes=pens();var shelter=Rect2(barn_door()+Vector2(-60,-40),Vector2(120,30))
 for k in ["cow","sheep","pig"]:Herd.pen_override[k]=boxes.get(k,shelter)
 draw_fences(ranch().edges)
 troughs.clear()
 for f in ranch().feeders:
  var k=str(f[0]);var c=Vector2i(int(f[1]),int(f[2]))
  var p=Vector2(c)*CELL+Vector2(32,46)
  var t=tex("res://qingxi-live/village-center/art/regions/props/feeders/feeder_%s.png"%k)
  var w=float(FEEDER_SIZE[k])
  var s=world.object(t,p,w,Rect2(),false)
  s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
  var solid=Rect2(p+Vector2(-w*.42,-14),Vector2(w*.84,14));world.solids.append(solid)
  feeder_nodes.append({"holder":s.get_parent(),"solid":solid,"cell":c})
  world.add_target("pen",p+Vector2(0,26),world.sim.FEEDERS[k],k)
  if not troughs.has(k) and home.has(k) and enclosures[home[k]].cells.has(c):
   troughs[k]={"food":p+Vector2(0,10),"drink":drink_point(k,p)}
 for k in KINDS:
  if not troughs.has(k):
   for f in ranch().feeders:
    var cell_=Vector2i(int(f[1]),int(f[2]))
    if home.has(k) and not enclosures[home[k]].cells.has(cell_):continue
    var at=Vector2(cell_)*CELL+Vector2(32,56)
    troughs[k]={"food":at,"drink":drink_point(k,at)};break
  if not world.sim.livestock.data.pens.has(k):continue
  var pen:Dictionary=world.sim.livestock.data.pens[k]
  pen.river_only=is_meadow()
  pen.creek=troughs.has(k) and not river_banks(k).is_empty()
 settle_animals()
 if world.herd_ai!=null and world.herd_ai.has_method("layout_changed"):world.herd_ai.layout_changed()
## Bank positions belong to the land cell, so the animals do not need to enter the water.
func river_banks(kind:String)->Array[Vector2]:
 var result:Array[Vector2]=[]
 for pair in enclosure_of(kind).get("bank",[]):
  var c:Vector2i=pair[0];var w:Vector2i=pair[1]
  var normal=Vector2(w-c)
  var center=cell_rect(c).get_center()+normal*20.0
  for lateral in [0.0,-21.0,21.0]:
   var p:Vector2=center+normal.orthogonal()*lateral
   if not world.blocked(p):result.append(p)
 return result

func drink_point(kind:String,feeder:Vector2)->Vector2:
 var banks=river_banks(kind)
 if banks.is_empty():return Vector2.INF if is_meadow() else feeder+Vector2(0,-30)
 banks.sort_custom(func(a,b):return a.distance_squared_to(feeder)<b.distance_squared_to(feeder))
 return banks[0]
## Animals standing outside their kind's enclosure (layout changed, old save) move in.
func settle_animals():
 for a in world.sim.livestock.data.herd:
  var e=enclosure_of(str(a.kind))
  if e.is_empty():continue
  var p=Vector2(a.pos[0],a.pos[1])
  if e.cells.has(cell_of(p)) and not cell_water(cell_of(p)):continue
  var spot:Vector2=troughs[a.kind].food if troughs.has(a.kind) else Vector2(e.cells.keys()[0])*CELL+Vector2(32,32)
  a.pos=[spot.x+rng.randf_range(-30,30),spot.y+rng.randf_range(16,30)]
func clear_fence_nodes():
 for post in fence_posts:post.queue_free()
 fence_posts.clear()
 for edge in fence_nodes.values():
  if edge.holder!=null:edge.holder.queue_free()
  if edge.solid.has_area():world.solids.erase(edge.solid)
 fence_nodes.clear()

func draw_fences(edges:Dictionary):
 var joints={}
 for key in edges:
  var fields_=str(key).split(":")
  var cell=Vector2i(int(fields_[1]),int(fields_[2]))
  var horizontal=fields_[0]=="h"
  var next=cell+(Vector2i.RIGHT if horizontal else Vector2i.DOWN)
  var holder:Node2D
  var solid=Rect2()
  if edges[key]=="fence":
   joints[cell]=int(joints.get(cell,0)) | (FenceJoint.EAST if horizontal else FenceJoint.SOUTH)
   joints[next]=int(joints.get(next,0)) | (FenceJoint.WEST if horizontal else FenceJoint.NORTH)
   solid=fence_collision(str(key));world.solids.append(solid)
  else:
   if not joints.has(cell):joints[cell]=0
   if not joints.has(next):joints[next]=0
   holder=gate_node(horizontal)
   holder.position=Vector2(cell)*CELL+(Vector2(32,2) if horizontal else Vector2(0,CELL))
   world.scenery.add_child(holder)
  fence_nodes[key]={"holder":holder,"solid":solid}
 for vertex in joints:
  var post=FenceJoint.new()
  post.connections=joints[vertex];post.position=Vector2(vertex)*CELL
  world.scenery.add_child(post);fence_posts.append(post)

func fence_collision(key:String)->Rect2:
 var midpoint=edge_mid(key)
 var dimensions=Vector2(CELL,12) if key.begins_with("h:") else Vector2(14,CELL)
 return Rect2(midpoint-dimensions/2,dimensions)
## A gate: two posts and a pale two-rail wooden leaf; the player walks through it.
func gate_node(horizontal:bool)->Node2D:
 var n=Node2D.new();var wood=Color("d9a865")
 if horizontal:
  for y in [-25,-13]:
   var rail=Polygon2D.new();rail.polygon=PackedVector2Array([Vector2(-26,y),Vector2(26,y),Vector2(26,y+4),Vector2(-26,y+4)]);rail.color=wood;n.add_child(rail)
  var brace=Line2D.new();brace.points=PackedVector2Array([Vector2(-24,-10),Vector2(24,-22)]);brace.width=3;brace.default_color=wood;n.add_child(brace)
 else:
  for x in [-1]:
   var rail=Polygon2D.new();rail.polygon=PackedVector2Array([Vector2(x-1,-CELL+4),Vector2(x+3,-CELL+4),Vector2(x+3,-6),Vector2(x-1,-6)]);rail.color=wood;n.add_child(rail)
   var rail2=Polygon2D.new();rail2.polygon=PackedVector2Array([Vector2(x-1,-CELL-8),Vector2(x+3,-CELL-8),Vector2(x+3,-18),Vector2(x-1,-18)]);rail2.color=wood;n.add_child(rail2)
 return n

# ---------------- barn interior ----------------
## Inside the big barn (art/regions/barn): straw bays for each kind off a stone aisle.
## Animals that sleep in the barn (pasture_animals.gd) lie in their bay; the hay rack
## feeds the ones kept indoors. The ranch layout is read (not built) to know who is in.
var ranch_info
func build_barn_inside():
 var s=size()
 for r in [Rect2(0,0,s.x,250),Rect2(0,0,40,s.y),Rect2(s.x-40,0,40,s.y),Rect2(0,s.y-34,574,34),Rect2(706,s.y-34,s.x-706,34)]:world.solids.append(r)
 world.barn_editor=preload("res://qingxi-live/village-center/barn_editor.gd").new()
 world.map_layer.add_child(world.barn_editor)
 world.barn_editor.setup(world,self)
 if world.barn_level(id)>1:
  var loft_void=Polygon2D.new();loft_void.z_index=-7
  loft_void.polygon=PackedVector2Array([Vector2(37,236),Vector2(1243,236),Vector2(1243,803),Vector2(37,803)])
  loft_void.color=Color("322a31");world.map_layer.add_child(loft_void)
  ranch_info=get_script().new(world,"ranch");ranch_info.compute_enclosures()
  return
 # Lanterns hang from the rafters on a cord above each light (see light_sources).
 for l in layout.lights:
  var lamp=Node2D.new();lamp.position=Vector2(l[0],l[1]-60);lamp.z_index=20;world.map_layer.add_child(lamp)
  var cord=Line2D.new();cord.points=PackedVector2Array([Vector2(0,-90),Vector2(0,-8)]);cord.width=2;cord.default_color=Color("3b2416");lamp.add_child(cord)
  var cap=Polygon2D.new();cap.polygon=PackedVector2Array([Vector2(-7,-10),Vector2(7,-10),Vector2(9,-6),Vector2(-9,-6)]);cap.color=Color("3b2416");lamp.add_child(cap)
  var glass=Polygon2D.new();glass.polygon=PackedVector2Array([Vector2(-7,-6),Vector2(7,-6),Vector2(6,8),Vector2(-6,8)]);glass.color=Color("ffd27a");lamp.add_child(glass)
  ceiling_emitters.append(Vector4(lamp.position.x,lamp.position.y+1,float(l[2]),.83))
  var foot=Polygon2D.new();foot.polygon=PackedVector2Array([Vector2(-8,8),Vector2(8,8),Vector2(6,11),Vector2(-6,11)]);foot.color=Color("3b2416");lamp.add_child(foot)
 world.add_target("portal",Vector2(640,809),"回到牧场","ranch")
 world.targets.back().merge({"half_width":53.0,"direction":1.0,"approach":24.0})
 window_light()
 ranch_info=get_script().new(world,"ranch")
 ranch_info.compute_enclosures()
## Window light: each back-wall window throws a slanting shaft and a four-pane patch onto
## the floor (the dark cross between panes is the frame's shadow). Warm by day, a faint
## blue at night; window_tick() follows the clock.
const WINDOWS=[150,380,900,1130]
var beams=[]
var ceiling_emitters:Array[Vector4]=[]
func window_light():
 var add=CanvasItemMaterial.new();add.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
 for wx in WINDOWS:
  var holder=Node2D.new();holder.z_index=-5;holder.material=add;world.map_layer.add_child(holder)
  var shift=-46.0   # morning sun from the east: shafts lean west
  var shaft=Polygon2D.new();shaft.use_parent_material=true
  shaft.polygon=PackedVector2Array([Vector2(wx-44,140),Vector2(wx+44,140),Vector2(wx+64+shift,430),Vector2(wx-64+shift,430)])
  shaft.vertex_colors=PackedColorArray([Color(1,1,1,.55),Color(1,1,1,.55),Color(1,1,1,0),Color(1,1,1,0)])
  holder.add_child(shaft)
  for pane in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
   var c=Vector2(wx+shift+pane.x*33,370+pane.y*26)
   var q=Polygon2D.new();q.use_parent_material=true
   q.polygon=PackedVector2Array([c+Vector2(-29,-22),c+Vector2(29,-22),c+Vector2(31,22),c+Vector2(-31,22)])
   holder.add_child(q)
  beams.append(holder)
 window_tick(world.sky_value()*24.0)
func window_tick(hour:float):
 var day=smoothstep(5.5,8.0,hour)*(1.0-smoothstep(17.0,19.5,hour))
 var warm=Color(1.0,.86,.58).lerp(Color(1.0,.95,.82),smoothstep(8.0,11.0,hour)*(1.0-smoothstep(15.0,17.5,hour)))
 var tint=Color(.45,.55,.85).lerp(warm,day)
 for b in beams:b.modulate=Color(tint.r,tint.g,tint.b,lerpf(.10,.34,day))
## Sleeping spot for the n-th animal of a kind inside its bay.
func bay_spot(kind:String,n:int)->Vector2:
 var b=layout.bays[kind];var cols_=3 if kind!="chicken" else 5
 if n>=cols_*2:
  return Vector2(b[0]+b[2]*(.12+.76*fmod(n*.618034,1.)),b[1]+70+(b[3]-70)*(.12+.76*fmod(n*.414214,1.)))
 var gap=Vector2(b[2]/float(cols_+1),(b[3]-70)/2.0)
 return Vector2(b[0],b[1]+70)+Vector2((n%cols_+1)*gap.x,(n/cols_)*gap.y+gap.y*.6)

# ---------------- pond ----------------
func build_pond():
 var pond=preload("res://qingxi-live/living_pond.gd").new()
 pond.baked=true
 var shore=PackedVector2Array()
 for p in layout.shore:shore.append(Vector2(p[0],p[1]))
 pond.shore=shore
 var d=layout.dock;pond.dock=Rect2(d[0],d[1],d[2],d[3])
 pond.interaction=Vector2(layout.interaction[0],layout.interaction[1])
 world.living_pond=pond;world.map_layer.add_child(pond);pond.setup(world)
 world.add_target("pond",pond.interaction,"码头 · 放苗 / 投喂 / 捕捞")
 for w in layout.willows:tree(Vector2(w[0],w[1]),"deep")

# ---------------- lights ----------------
func light_sources(lamp_on:float)->Array:
 var list=[];var tints=[]
 for p in lamps:
  for offset in [Vector2(-13,-68),Vector2(11,-68)]:
   var bulb:Vector2=p+offset
   list.append(Vector4(bulb.x,bulb.y,108,.74*lamp_on));tints.append(Vector4(1.0,.88,.64,1))
 for source in ceiling_emitters:
  list.append(Vector4(source.x,source.y,source.z,source.w*lamp_on))
  tints.append(Vector4(1.0,.84,.58,1))
 return [list,tints]
