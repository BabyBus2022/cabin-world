extends "res://qingxi-live/rural.gd"
## New 2D village hub; ranch, pond and field run the existing rural implementation.
const PastureState=preload("res://qingxi-live/village-center/pasture_state.gd")
const Book=preload("res://qingxi-live/village-center/breed_catalog.gd")
const PastureAI=preload("res://qingxi-live/village-center/pasture_animals.gd")
const PET_RULES=preload("res://qingxi-live/village-center/pets_rules.gd")   # 2026-11-21 pets
const CONNECTED_SAVE="user://village-center-test.json"
const SESSION=preload("res://qingxi-live/village3d/session.gd")
const SEED_DOOR=Vector2(930,1440)
const CENTER_START=Vector2(930,1520)
var qingxi=preload("res://qingxi-live/village-center/qingxi_data.gd").new()
var district
var center_hour=8.0
var center_cycle=true
## Sun shared by every cast shadow (set by qingxi_lighting.gd each time the light changes).
var lighting
var sun_dir=Vector2(.4,.55)
var sun_len=.3
var shadow_ink=Color(.27,.22,.5,.3)
## Number keys: 1 拂晓 2 清晨 3 正午 4 午后 5 黄昏 6 夜晚 7 凌晨
const HOUR_PRESETS=[5.8,8.5,12.5,15.5,17.6,21.0,2.5]

var audio
var step_distance=0.0
var walking_in_shallows=false
var last_night=false
var last_place=""
var legacy_split_maps=false

func _ready():
 legacy_split_maps=legacy_split_maps or bool(get_tree().get_meta("legacy_split_maps",false)) or "--capture-regions" in OS.get_cmdline_user_args()
 sim=PastureState.new()
 audio=preload("res://qingxi-live/village-center/audio.gd").new();add_child(audio)
 MAP_NAMES.village="清溪村";MAP_NAMES.field="自家农场";MAP_NAMES.seedshop="青芽种子店";MAP_NAMES.livestockshop="牧铃畜牧铺"
 layout=preload("res://qingxi-live/village-center/layout.gd").new()
 var check="--verify-center" in OS.get_cmdline_user_args() or "--capture-center" in OS.get_cmdline_user_args() or "--capture-regions" in OS.get_cmdline_user_args()
 get_tree().set_meta("center_testing",check)
 get_tree().set_meta("continuous_rural",false)
 if not get_tree().has_meta("rural_handoff"):
  var initial=PastureState.new()
  if not check:
   var host=get_tree().get_meta("qingxi_world_host",null)
   var src=qingxi_save_path(CONNECTED_SAVE)
   if host!=null:
    var farm_path=host.profile_path("open-meadow.json")
    if FileAccess.file_exists(farm_path) and (not FileAccess.file_exists(src) or FileAccess.get_modified_time(farm_path)>FileAccess.get_modified_time(src)):src=farm_path
   if not initial.load_from(src):initial.load_from(qingxi_save_path(SAVE_PATH))
  SESSION.publish(get_tree(),initial,"village")
 center_hour=float(get_tree().get_meta("center_hour",8.0))
 center_cycle=bool(get_tree().get_meta("center_cycle",true))
 super._ready()
 if get_tree().has_meta("meadow_return"):
  get_tree().remove_meta("meadow_return")
  if map_id=="village":
   for e in qingxi.exits:
    if e.to=="meadow" and not e.get("reserved",false):
     player.position=e.pos+(CENTER_START-e.pos).normalized()*80.0
     update_camera(true);break
 if get_tree().has_meta("cottage_return"):
  get_tree().remove_meta("cottage_return")
  build_map("field",Vector2(1200,900));update_camera(true)
 if get_tree().has_meta("ranch_return"):
  var destination=str(get_tree().get_meta("ranch_return"));get_tree().remove_meta("ranch_return")
  if destination=="village":travel("village")
 MAP_NAMES.erase("home")   # merged into the farm map
 MAP_NAMES.barn="畜舍 · 一楼"
 MAP_NAMES.barn_up="畜舍 · 二楼"
 tidy_hud()
 edit_button=KIT.button("编辑  G",toggle_build)
 hud.add_child(edit_button)
 hotbar=preload("res://qingxi-live/village-center/flat-build/hotbar.gd").new()
 hud.add_child(hotbar);hotbar.setup(self)
 juice=preload("res://qingxi-live/village-center/juice.gd").new();add_child(juice);juice.setup(self)   # 2026-11-19 Claude
 testing=check
 if not get_tree().has_meta("qingxi_world_host"):DisplayServer.window_set_title("小屋世界 · 清溪村")   # 2026-11-19 Claude (Cabin World host): inside Cabin World this would touch the whole app
 # The village group chat (rolled-back QQ work) is not part of 清溪村 inside Cabin World.
 if not get_tree().has_meta("qingxi_world_host"):attach_chat.call_deferred()
 if get_tree().has_meta("qingxi_world_host"):
  weather_view=preload("res://qingxi-live/village-center/qingxi_weather.gd").new()
  add_child(weather_view);weather_view.setup(self)
 if check:set_physics_process(false)
 if "--capture-center" in OS.get_cmdline_user_args():capture_center.call_deferred()
 if "--capture-regions" in OS.get_cmdline_user_args():capture_regions.call_deferred()

var weather_view

func attach_chat():
 var tree=get_tree()
 if tree.has_meta("qingxi_chat"):return
 var chat=preload("res://qingxi-live/village-center/local_chat.gd").new()
 tree.root.add_child(chat);tree.set_meta("qingxi_chat",chat)
 chat.setup("user://qingxi-chat.json")

func refresh_life():
 refresh_feeder_stock()
 var losses=sim.livestock.take_deaths()
 if not losses.is_empty():
  notify(losses[0] if losses.size()==1 else "%s，另有 %d 只动物死亡"%[losses[0],losses.size()-1])
 if map_id=="barn":herd_ai.refresh();return
 if map_id!="ranch":super.refresh_life();return
 var born=sim.livestock.breed()
 herd_ai.refresh()
 if not born.is_empty():
  var last=sim.livestock.animal(str(born.back()))
  if not last.is_empty():notify("迎来%s幼崽 · %s" % [Book.breed_name(last),Book.GRADE[int(last.quality)-1]])
 queue_redraw()

func advance_hour():
 sim.settle()
 var live=sim.livestock.visible_pasture
 sim.livestock.visible_pasture=false
 # F8 advances other production one real hour, and livestock one husbandry hour.
 sim.advance_farm(3600.0)
 sim.livestock.advance(3600.0/sim.livestock.RATE)
 sim.livestock.visible_pasture=live
 sim.data.test_uses+=1;perform("农场和牧场时间已推进一小时")

func world_bounds()->Rect2:
 if map_id=="village_bath":return Bath.BOUNDS
 if map_id=="village_store":return Store.BOUNDS
 if map_id=="village":return Rect2(0,0,4800,3360)
 if region!=null and map_id==region.id:return Rect2(Vector2.ZERO,region.size())
 return super.world_bounds()

## Outer maps (farm = cottage + field, ranch, pond) are built by region.gd.
const REGIONS=["field","ranch"]
## Shops are separate scenes: the original seed shop (seedshop.tscn) and the livestock
## shop built on it (livestockshop.tscn). Their doors are entered walking up.
const INTERIORS=["seedshop","livestockshop"]
var region
var barn_editor
var placement
var barn_stairs
var hotbar
var edit_button:Button
var interior_walk_zoom=Vector2.ONE
const Grid=preload("res://qingxi-live/village-center/placement_grid.gd")
const MapLoading=preload("res://qingxi-live/village-center/map_loading.gd")

func layout_save()->Dictionary:
 if not sim.data.has("layout"):sim.data.layout={}
 return sim.data.layout

static func barn_level(id:String)->int:
 if id=="barn":return 1
 if id=="barn_up":return 2
 if id.begins_with("barn_floor_") and id.substr(11).is_valid_int():
  var level=int(id.substr(11))
  if level>=3 and id==barn_map(level):return level
 return 0

static func barn_map(level:int)->String:
 if level==1:return "barn"
 if level==2:return "barn_up"
 return "barn_floor_%d"%level

func is_barn_floor()->bool:return barn_level(map_id)>0

func mount_placement(area:Rect2):
 placement=Grid.new();map_layer.add_child(placement)
 placement.setup(self,area)

func is_stair_opening(rect:Rect2)->bool:
 return is_instance_valid(barn_stairs) and barn_stairs.opening_intersects(rect)

func in_interior()->bool:return false
func ground_data():return region.data if region!=null and map_id==region.id and region.data!=null else qingxi
func light_sources(lamp_on:float,flick:float)->Array:
 if map_id=="village_bath":return Bath.lights(lamp_on)
 if map_id=="village_store":return Store.lights(lamp_on)
 if map_id=="village" and lighting!=null:return lighting.village_sources(flick)
 var pair:Array=region.light_sources(lamp_on) if region!=null and map_id==region.id else [[],[]]
 # 2026-11-19 Claude: house lamps, so a room is not pitch dark at night (private cottage).
 if region==null and rooms!=null and rooms.has_method("room_lights") and rooms.contains(map_id):
  for lamp in rooms.room_lights(map_id):
   pair[0].append(Vector4(lamp.x,lamp.y,lamp.z,.85*lamp_on));pair[1].append(Vector4(1.0,.86,.6,1))
 if is_instance_valid(placement):
  for id in placement.nodes:
   var row:Array=placement.plan.furniture[id]
   if row[0]!="prop:lantern":continue
   var art:Rect2=placement.nodes[id].draw
   for x in [.21,.75]:
    var bulb=art.position+art.size*Vector2(x,.43)
    pair[0].append(Vector4(bulb.x,bulb.y,110,.82*lamp_on))
    pair[1].append(Vector4(1.0,.88,.64,1))
 return pair

func build_map(id:String,arrival=Vector2.ZERO):
 if id=="pond":id="village";arrival=CENTER_START
 if rooms and rooms.owner_bed!="" and map_id!=id:rooms.leave_bed()
 build_mode=false;placement=null;barn_stairs=null;barn_editor=null
 if not herd_ai is PastureAI:herd_ai=PastureAI.new(self)
 sim.livestock.visible_pasture=(id=="ranch")
 if id=="home":id="field"
 Herd.pen_override.clear()
 if id in REGIONS or barn_level(id)>0:
  build_region(id,arrival);return
 if id!="village":
  district=null;lighting=null;region=null
  if has_meta("player_cast"):remove_meta("player_cast")
  super.build_map(id,arrival)
  if rooms.contains(id):
   lighting=preload("res://qingxi-live/village-center/qingxi_lighting.gd").new()
   lighting.setup(self);map_layer.add_child(lighting);lighting.apply(sky_value()*24.0)
  return
 region=null
 portal_grace=.6;transition_pending=false;map_id=id;sim.data.map=id
 if is_instance_valid(map_layer):map_layer.free()
 if is_instance_valid(camera):camera.free()
 map_layer=Node2D.new();add_child(map_layer)
 surfaces.clear();cast_shadows.clear();trees.clear();solids.clear();fields.clear();tree_placements.clear();targets.clear();animal_sprites.clear();animal_tags.clear()
 active_action="";action_elapsed=0;idle_elapsed=0;selected_cell=-1;action_target={};herd_ai.reset();villagers.reset()
 villagers=preload("res://qingxi-live/village-center/neighbors.gd").new(self)
 LINKS.village=[]
 for e in qingxi.exits:
  if not e.get("reserved",false):LINKS.village.append([e.to,e.pos])
 make_ground();var floor_node=get_child(get_child_count()-1);floor_node.reparent(map_layer)
 ground_material.shader=preload("res://qingxi-live/village-center/qingxi_ground.gdshader")
 floor_node.polygon=PackedVector2Array([Vector2.ZERO,Vector2(4800,0),Vector2(4800,3360),Vector2(0,3360)])
 shadow_root=Node2D.new();map_layer.add_child(shadow_root)
 scenery=Node2D.new();scenery.y_sort_enabled=true;map_layer.add_child(scenery)
 district=preload("res://qingxi-live/village-center/qingxi_scene.gd").new(self);district.build()
 add_target("facility",qingxi.point([870,1110])+Vector2(0,28),"村井 · 打水","well")
 paddies=preload("res://qingxi-live/village-center/paddies.gd").new();map_layer.add_child(paddies);paddies.setup(self)   # 2026-11-19 Claude
 if not has_meta("route_geometry"):
  var life=preload("res://qingxi-live/village-center/critters.gd").new();map_layer.add_child(life);life.setup(self)   # 2026-11-19 Claude
 make_actor();player.position=arrival if arrival!=Vector2.ZERO else CENTER_START
 if get_tree().has_meta("center_from_shop"):
  player.position=SEED_DOOR+Vector2(0,42);get_tree().remove_meta("center_from_shop")
  if get_tree().has_meta("center_from_livestock"):
   get_tree().remove_meta("center_from_livestock")
   for b in qingxi.buildings:
    if b.id=="livestock_shop":player.position=b.pos+Vector2(0,42)
 # Expose walkable banks along the painted creek, plus the wooden bridge decks.
 for bridge in qingxi.bridges:
  add_target("river_fishing",bridge.pos,"小河 · 抛竿钓鱼")
 for i in range(1,qingxi.creek.size()):
  var a:Vector2=qingxi.creek[i-1];var b:Vector2=qingxi.creek[i]
  var steps=maxi(1,ceili(a.distance_to(b)/96.0))
  for j in steps:
   var mid=a.lerp(b,float(j)/steps)
   for side in [-1,1]:
    var normal=a.direction_to(b).orthogonal()*side
    for d in range(12,200,8):
     var bank=mid+normal*d
     if world_bounds().grow(-32).has_point(bank) and not blocked(bank) and not qingxi.on_bridge(bank):
      add_target("river_fishing",bank,"小河 · 抛竿钓鱼");break
 var cast=Polygon2D.new();shadow_root.add_child(cast);set_meta("player_cast",cast)
 lighting=preload("res://qingxi-live/village-center/qingxi_lighting.gd").new();lighting.setup(self);map_layer.add_child(lighting)
 show_idle();villagers.spawn();update_camera(true);set_light(sky_value());update_hud();queue_redraw();fade_in()

func build_region(id:String,arrival:Vector2):
 portal_grace=.6;transition_pending=false;map_id=id;sim.data.map=id;district=null
 if barn_level(id)>0:MAP_NAMES[id]="畜舍 · %d 楼"%barn_level(id)
 build_mode=false;placement=null;barn_stairs=null;barn_editor=null
 if is_instance_valid(map_layer):map_layer.free()
 if is_instance_valid(camera):camera.free()
 map_layer=Node2D.new();add_child(map_layer)
 surfaces.clear();cast_shadows.clear();trees.clear();solids.clear();fields.clear();tree_placements.clear();targets.clear();animal_sprites.clear();animal_tags.clear()
 active_action="";action_elapsed=0;idle_elapsed=0;selected_cell=-1;action_target={};herd_ai.reset();villagers.reset();living_pond=null
 region=preload("res://qingxi-live/village-center/region.gd").new(self,id)
 var s=region.size()
 make_ground();var floor_node=get_child(get_child_count()-1);floor_node.reparent(map_layer)
 floor_node.polygon=PackedVector2Array([Vector2.ZERO,Vector2(s.x,0),s,Vector2(0,s.y)])
 shadow_root=Node2D.new();map_layer.add_child(shadow_root)
 scenery=Node2D.new();scenery.y_sort_enabled=true;map_layer.add_child(scenery)
 region.build()
 if barn_level(id)==0 and not has_meta("route_geometry"):   # 2026-11-19 Claude: butterflies, birds, fireflies, winter snow
  var life=preload("res://qingxi-live/village-center/critters.gd").new();map_layer.add_child(life);life.setup(self)
 mount_placement(Rect2(64,256,1152,512) if is_barn_floor() else world_bounds().grow(-64))
 if is_barn_floor():
  barn_stairs=preload("res://qingxi-live/village-center/barn_stairs.gd").new()
  map_layer.add_child(barn_stairs);barn_stairs.setup(self)
  barn_editor.refresh_beds()
 make_actor()
 if arrival!=Vector2.ZERO:player.position=arrival
 else:player.position=Vector2(region.layout.spawn[0],region.layout.spawn[1])
 if is_instance_valid(barn_stairs) and (arrival.x<0 or barn_level(id)>1):
  player.position=barn_stairs.arrival(arrival!=Vector2(-2,-2))
 var cast=Polygon2D.new();shadow_root.add_child(cast);set_meta("player_cast",cast)
 lighting=preload("res://qingxi-live/village-center/qingxi_lighting.gd").new();lighting.setup(self);map_layer.add_child(lighting)
 show_idle();update_camera(true);refresh_life();set_light(sky_value());update_hud();queue_redraw();fade_in()

func bus_point()->Vector2:
 for b in qingxi.buildings:
  if b.id=="bus_stop":return b.pos+Vector2(34,50)
 return CENTER_START

func bus_spawn():
 if map_id!="village":build_map("village",bus_point())
 else:player.position=bus_point();update_camera(true)

func zone_point(zone:String)->Vector2:
 match zone:
  "area_篝火广场","farm":return qingxi.plaza+Vector2(0,123)
  "area_车站":return bus_point()
  "area_西街":return Vector2(560,1500)
  "area_水车磨坊":
   for b in qingxi.buildings:
    if b.id=="watermill":return b.pos+Vector2(0,54)
 return Vector2.INF

func region_arrival(to:String,from:String)->Vector2:
 var layout_=JSON.parse_string(FileAccess.get_file_as_string("res://qingxi-live/village-center/art/regions/"+preload("res://qingxi-live/village-center/region.gd").FOLDERS[to]+"/layout.json"))
 var gate=layout_.gates.get(from,layout_.spawn)
 return Vector2(gate[0],gate[1])

## Same swept threshold test as rural.gd, but shop doors are exited walking down
## and entered walking up (rural.gd only knows its house rooms).
func check_portals(previous_position:Vector2):
 if portal_grace>0 or transition_pending or not owner_controls():return
 var movement=player.position-previous_position
 for target in targets:
  if target.kind!="portal":continue
  var to=str(target.extra)
  if build_mode:continue
  if not target.get("stairs",false) and outdoor_entry(target):continue   # 2026-11-19 Claude: E to enter
  if target.get("stairs",false):
   var axis:Vector2=target.stair_axis
   var flow=axis if not target.down else -axis
   var before=(previous_position-Vector2(target.pos)).dot(flow)
   var after=(player.position-Vector2(target.pos)).dot(flow)
   if before<=0.0 and after>=0.0 and after-before>0.001:
    var crossed=previous_position.lerp(player.position,-before/(after-before))
    if absf((crossed-Vector2(target.pos)).dot(axis.orthogonal()))<=24.0:
     transition_pending=true;travel.call_deferred(to);return
   continue
  var fallback=-1.0 if to in INTERIORS or to=="barn" else (1.0 if in_interior() or map_id=="barn" else rooms.portal_direction(map_id,to))
  var direction=float(target.get("direction",fallback))
  var width_=float(target.get("half_width",24.0))
  var reach=float(target.get("approach",0.0))
  var moving_in=movement.y*direction>0.001
  if reach>0.0:
   var toward_key=KEY_UP if direction<0 else KEY_DOWN
   var move_key=KEY_W if direction<0 else KEY_S
   var offset=player.position-Vector2(target.pos)
   var prior=previous_position-Vector2(target.pos)
   var entered=movement.length_squared()>0.001 and (absf(prior.x)>width_ or prior.y*direction<-reach)
   if (entered or moving_in or Input.is_physical_key_pressed(toward_key) or Input.is_physical_key_pressed(move_key)) and absf(offset.x)<=width_ and offset.y*direction>=-reach and offset.y*direction<=float(target.get("inside_reach",12.0)):
    transition_pending=true;travel.call_deferred(to);return
  if not moving_in:continue
  var plane=float(target.pos.y)-direction*reach
  var crossing=(previous_position.y-plane)*direction<=0 and (player.position.y-plane)*direction>=0
  var crossing_x=lerpf(previous_position.x,player.position.x,clampf((plane-previous_position.y)/movement.y,0,1))
  if crossing and absf(crossing_x-float(target.pos.x))<=width_:
   transition_pending=true;travel.call_deferred(to);return

func stair_in_reach()->Dictionary:
 if build_mode or not is_barn_floor() or not is_instance_valid(player):return {}
 for target in targets:
  if not target.get("stairs",false):continue
  var offset=player.position-Vector2(target.pos)
  var axis:Vector2=target.stair_axis
  var depth=-offset.dot(axis)
  if absf(offset.dot(axis.orthogonal()))<=24 and (depth>=-78 and depth<=16 if target.down else depth>=-8 and depth<=110):return target
 return {}

## 2026-11-19 Claude: doors work like Stardew Valley — stand anywhere in front of a door
## (a box about one cell deep and a little wider than the door) and press E. Walking into
## a building from outside no longer happens by itself (the old threshold was a thin
## line that was easy to miss). Leaving an interior still works by walking out, and E
## works there too. Stairs inside rooms use the same box.
const DOOR_REACH_SIDE=24.0   # added to the door's half width on each side
const DOOR_REACH_DEPTH=96.0  # how far in front of the door the player may stand
func portal_dir(target:Dictionary)->float:
 var to=str(target.extra)
 var fallback=-1.0 if to in INTERIORS or to=="barn" else (1.0 if in_interior() or map_id=="barn" else rooms.portal_direction(map_id,to))
 return float(target.get("direction",fallback))
func outdoor_entry(target:Dictionary)->bool:
 return portal_dir(target)<0 and not rooms.contains(map_id) and not in_interior() and barn_level(map_id)==0
func door_in_reach()->Dictionary:
 if build_mode or not is_instance_valid(player) or transition_pending:return {}
 var best={};var best_d=INF
 for target in targets:
  if target.kind!="portal" or target.get("stairs",false):continue
  var offset=player.position-Vector2(target.pos)
  var half=maxf(float(target.get("half_width",24.0)),24.0)+DOOR_REACH_SIDE
  var ahead=-offset.y*portal_dir(target)   # > 0 on the side the door is approached from
  if absf(offset.x)<=half and ahead>=-20.0 and ahead<=DOOR_REACH_DEPTH:
   var d=offset.length_squared()
   if d<best_d:best_d=d;best=target
 return best
## The door is used unless something else is nearer (a plot under the feet, a feeder,
## an animal...), so E next to a mailbox by the door still opens the door.
func door_wins(door:Dictionary)->bool:
 var d=player.position.distance_to(Vector2(door.pos))
 if selected_cell>=0 and d>=48.0:return false
 if not action_target.is_empty() and not str(action_target.kind) in ["portal","exit"]:
  return d<player.position.distance_to(Vector2(action_target.pos))
 return true
func door_label(target:Dictionary)->String:
 var name=str(target.name).replace(" · E","")
 if name=="直接走出大门" or name.begins_with("回到"):return "出门 · "+name.trim_prefix("回到") if name!="直接走出大门" else "出门"
 if name.begins_with("走入 "):return "进入 "+name.trim_prefix("走入 ")
 if name.begins_with("走入"):return "进入"+name.trim_prefix("走入")
 if name in ["走上楼梯","上楼"]:return "上楼"
 if name in ["走下楼梯","下楼"]:return "下楼"
 return name

## 2026-11-19 Claude: mouse farming like Stardew Valley — the plot under the cursor is
## chosen when it is within reach of the player (about 1.5 plots), and a left click
## plants / waters / harvests it. Further away, the plot in front of the player is used.
const MOUSE_PLOT_REACH=120.0
func mouse_plot()->int:
 if build_mode or overlay.visible or region==null or map_id!=region.id or fields.is_empty() or not is_instance_valid(player):return -1
 var vp=get_viewport()
 if not vp.get_visible_rect().has_point(vp.get_mouse_position()):return -1
 var i=cell_at(get_global_mouse_position())
 if i<0 or i>=fields.size():return -1
 return i if fields[i].rect.get_center().distance_to(player.position)<=MOUSE_PLOT_REACH else -1
func face_toward(p:Vector2):
 var v=p-player.position
 if v.length_squared()<1.0:return
 facing=(2 if v.x>0 else 1) if absf(v.x)>absf(v.y) else (0 if v.y>0 else 3)
func handle_garden_plot(i:int):
 sim.settle()
 if sim.data.crops[i].planted:
  perform(sim.crop_action(i));play_action("pick_up-%d"%facing);return
 open_menu="seeds";clear_menu("播种 · 第 %d 块田"%(i+1))
 var crops:Dictionary=sim.Garden.book().produce
 var grid=GridContainer.new()
 grid.name="SeedGrid";grid.columns=4
 grid.add_theme_constant_override("h_separation",5)
 grid.add_theme_constant_override("v_separation",5)
 overlay_body.add_child(grid)
 for key in crops:
  var count=int(sim.data.bag.get(key,0))
  var crop=str(crops[key])
  var title=sim.goods_name(crop)
  var card=button("",plant_selected.bind(i,key))
  card.name="Seed_"+str(key)
  card.custom_minimum_size=Vector2(95,83)
  card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  card.disabled=count<=0
  card.accessibility_name="%s · 种子 %d 份"%[title,count]
  card.tooltip_text=("%s · 点选播种，消耗 1 份"%title) if count>0 else ("%s · 缺少种子，可到青芽种子店购买"%title)
  for state in ["normal","hover","pressed","disabled"]:
   var frame="slot" if state=="normal" else ("slot_off" if state=="disabled" else "slot_hi")
   card.add_theme_stylebox_override(state,KIT.frame(frame))
  grid.add_child(card)
  var stack=VBoxContainer.new();card.add_child(stack)
  stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  stack.alignment=BoxContainer.ALIGNMENT_CENTER
  stack.add_theme_constant_override("separation",0)
  stack.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var art=KIT.icon(crop,1)
  art.custom_minimum_size=Vector2(33,33)
  art.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
  if card.disabled:art.modulate.a=0.52
  stack.add_child(art)
  var name_label=KIT.label(title,13,KIT.INK,true)
  name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;stack.add_child(name_label)
  var stock=KIT.label("种子 ×%d"%count if count>0 else "缺种",10,KIT.INK2 if count==0 else KIT.GRASS_D)
  stock.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  stock.mouse_filter=Control.MOUSE_FILTER_IGNORE;stack.add_child(stock)
 menu_line("青芽种子店可补种。保持湿润，约 %d 分钟成熟。"%roundi(sim.CROP_SECONDS/60.0))

func plant_selected(i:int,key:String):
 if open_menu!="seeds" or not overlay.visible or i>=fields.size() or fields[i].rect.get_center().distance_to(player.position)>MOUSE_PLOT_REACH:return
 close_menu()
 perform(sim.sow(i,key));play_action("pick_up-%d"%facing)

func click_plot(m:Vector2)->bool:
 if region==null or map_id!=region.id or fields.is_empty():return false
 var i=cell_at(m)
 if i<0 or i>=fields.size():return false
 if fields[i].rect.get_center().distance_to(player.position)>MOUSE_PLOT_REACH:
  notify("走近一点再点这块田");return true
 face_toward(fields[i].rect.get_center());selected_cell=i
 handle_garden_plot(i)
 queue_redraw();return true

# ---------------- layout mode (G): lay out your own fields and pastures ----------------
var build_mode=false
var build_kind="cow"
## Ranch build tools (G on the ranch): fence and gate go on grid edges, feeders on cells.
const RANCH_TOOLS=[["fence","栅栏"],["gate","门"],["feeder_cow","牧场食槽"]]
var build_tool="fence"
## Build-mode tools for this map: its own (plots / fences, gates, feeders), then
## 搬起 (pick up a prop) and every prop waiting in the bag ("prop:<name>").
func build_tools()->Array:
 if map_id=="barn" and is_instance_valid(barn_editor):return barn_editor.TOOLS
 var list=[]
 if map_id=="field":list.append(["plot","田地"])
 elif map_id=="ranch":list.append_array(RANCH_TOOLS)
 list.append(["pick","搬起"])
 for key in sim.data.bag:
  if str(key).begins_with("decor_") and int(sim.data.bag[key])>0:
   var name=str(key).substr(6);list.append(["prop:"+name,str(region.PROP_NAMES.get(name,name))])
 return list
func tool_name(tool:String)->String:
 if is_instance_valid(hotbar):return hotbar.names.get(tool,tool)
 for t_ in build_tools():
  if t_[0]==tool:return t_[1]
 return tool
func prop_spot(m:Vector2)->Vector2:return (m/16).round()*16
var drag_from=null
const PLOT_ORIGIN=Vector2(10,2)   # the 64px planting grid lines up with the starting field
func can_build()->bool:return is_instance_valid(placement)

func editor_catalog()->Array:
 var tools=[["plot","田地"],["fence","围栏"],["gate","栅门"],["path","小路"],["channel","河道"],
  ["bridge","木桥"],["barn_unit","牧场屋"],["house_unit","我的小屋"],["water","挖塘"],
  ["floor","拼装地板"],["wall","墙段"],["door","门洞"],["pick","搬起"],["stairs","楼梯"]]+RANCH_TOOLS.slice(2)
 for id in Grid.FLOORS:tools.append([id,Grid.FLOORS[id][0]])
 for id in Grid.ITEMS:
  if id=="shared_chest" and not Features.on("sharedChest12"):continue
  tools.append(["furn:"+id,Grid.ITEMS[id][0]])
 var props=preload("res://qingxi-live/village-center/region.gd").PROP_NAMES
 for id in props:tools.append(["prop:"+id,props[id]])
 return tools

func clear_build_gesture():
 drag_from=null;painting=""

func editor_hint()->String:
 if build_tool in ["furn:ranch_lamp","furn:pasture_floodlight"]:return "R 旋转 · 左键放置 · 指向已放灯具按 R 可转向"
 if not editor_tool_available(build_tool):return "可从设施库换其他物件"
 if build_tool=="stairs":
  if barn_stairs.origin!=Vector2.ZERO:return "已搭好 · 右键收回楼梯"
  return "R 旋转 · 上行向"+barn_stairs.direction_name()+" · 左键放置"
 return "左键放置 · 右键拆除"

func editor_tool_available(tool:String)->bool:
 if Grid.FLOORS.has(tool) or tool.begins_with("furn:"):return true
 if is_barn_floor():
  return tool in ["stairs","fence","gate","pick"] or tool.begins_with("feeder_") or tool.begins_with("prop:")
 if tool.begins_with("prop:") or tool=="pick":return true
 if region==null:return false
 return build_tools().any(func(row):return row[0]==tool)

func toggle_build():
 if rooms and rooms.owner_bed!="":return
 if not can_build():return
 build_mode=not build_mode;clear_build_gesture()
 if is_barn_floor() or rooms.contains(map_id):
  if build_mode:
   interior_walk_zoom=camera.zoom
   camera.zoom=Vector2.ONE*.70
  else:camera.zoom=interior_walk_zoom
  update_camera(true)
 if build_mode and is_instance_valid(hotbar):hotbar.select(hotbar.active)
 if build_mode:
  if audio:audio.sfx("ui_open",-10)
 else:
  save_progress()
  if audio:audio.sfx("ui_close",-10)
  if map_id=="ranch":ranch_report()
 queue_redraw()
func plot_cell(p:Vector2)->Vector2:return ((p-PLOT_ORIGIN)/64).floor()*64+PLOT_ORIGIN
var painting=""   # "paint" / "erase" while a mouse button is held on the ranch
func reclaim_furniture(p:Vector2)->bool:
 var result=placement.edit_furniture("",p,true)
 if result=="" and region!=null:
  var id=region.prop_at(p)
  if id!="":result=region.pick_prop(id)
 if result=="":return false
 if result!="ok":notify(result)
 elif audio:audio.sfx("ui_close",-10)
 queue_redraw();get_viewport().set_input_as_handled()
 return true

func _unhandled_input(event):
 if room_camera_input(event):return
 # 2026-11-19 Claude: outside build mode a left click on a plot in reach farms it.
 if not build_mode and not overlay.visible and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and owner_controls() and not transition_pending:
  if click_plot(get_global_transform_with_canvas().affine_inverse()*event.position):get_viewport().set_input_as_handled()
  return
 if not build_mode or not can_build() or not event is InputEventMouse or overlay.visible or hotbar.library.visible:return
 var m=get_global_transform_with_canvas().affine_inverse()*event.position
 var pressed=event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]
 if pressed and event.button_index==MOUSE_BUTTON_RIGHT and reclaim_furniture(m):return
 if not editor_tool_available(build_tool):
  if pressed:notify("这里可以从设施库选其他材料和家具")
  return
 var on_barn=is_barn_floor()
 var shared_item=build_tool.begins_with("furn:") or (region==null or on_barn) and (build_tool.begins_with("prop:") or build_tool=="pick")
 if Grid.FLOORS.has(build_tool) or shared_item or (on_barn and (build_tool in ["stairs","fence","gate"] or build_tool.begins_with("feeder_"))):
  if pressed:
   var erase=event.button_index==MOUSE_BUTTON_RIGHT
   var message=""
   if Grid.FLOORS.has(build_tool):message=placement.paint(build_tool,m,erase)
   elif shared_item:
    if build_tool=="pick":reclaim_furniture(m)
    elif not erase:message=placement.edit_furniture(build_tool,m,false)
   elif build_tool=="stairs":message=barn_stairs.edit(m,erase)
   else:message=barn_editor.edit(build_tool,m,erase)
   if message not in ["","ok"]:notify(message)
   get_viewport().set_input_as_handled()
  queue_redraw();return
 if region==null:return
 # Props, on every map: right click (or the 搬起 tool) picks one up, a prop tool sets one down.
 if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
  if build_tool=="pick":
   reclaim_furniture(m);get_viewport().set_input_as_handled();return
  if event.button_index==MOUSE_BUTTON_LEFT and build_tool.begins_with("prop:"):
   var name=build_tool.substr(5)
   var r=region.put_prop(name,prop_spot(m))
   if r=="ok":
    if audio:audio.sfx("plant",-10)
    if not region.is_meadow() and int(sim.data.bag.get("decor_"+name,0))<=0:build_tool=build_tools()[0][0]
   else:notify(r)
   queue_redraw();get_viewport().set_input_as_handled();return
 if build_tool=="pick" or build_tool.begins_with("prop:") or map_id=="pond":
  if event is InputEventMouseMotion:queue_redraw()
  return
 if map_id=="ranch":
  if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
   painting=("paint" if event.button_index==MOUSE_BUTTON_LEFT else "erase") if event.pressed else ""
   if event.pressed:ranch_edit(m,true)
   get_viewport().set_input_as_handled()
  elif event is InputEventMouseMotion:
   if event.button_mask==0:painting=""
   if painting!="":ranch_edit(m,false)
   queue_redraw()
  return
 if event is InputEventMouseMotion:queue_redraw();return
 if not event is InputEventMouseButton or not event.pressed:return
 if event.button_index==MOUSE_BUTTON_LEFT and build_tool=="plot":
  var message=region.add_plot(plot_cell(m));notify(message)
  if audio:audio.sfx("plant" if message.begins_with("开垦") else "ui_close",-10)
 elif event.button_index==MOUSE_BUTTON_RIGHT:
  for i in fields.size():
   if fields[i].rect.has_point(m):
    notify(region.remove_plot(i))
    if audio:audio.sfx("ui_close",-10)
    break
 queue_redraw();get_viewport().set_input_as_handled()
func pasture_cell(p:Vector2)->Vector2:return (p/64).floor()*64
## The grid edge nearest the mouse ("h:c:r" top edge / "v:c:r" left edge of a cell).
func nearest_edge(p:Vector2)->Array:
 var c=Vector2i((p/64).floor());var l=p-Vector2(c)*64
 var options=[[l.y,"h:%d:%d"%[c.x,c.y]],[64-l.y,"h:%d:%d"%[c.x,c.y+1]],[l.x,"v:%d:%d"%[c.x,c.y]],[64-l.x,"v:%d:%d"%[c.x+1,c.y]]]
 options.sort_custom(func(a,b):return a[0]<b[0])
 return options[0]
## Left button places the current tool, right button removes (feeder under the mouse
## first, otherwise the nearest fence or gate). Fences and gates can be dragged.
var last_edit=""
func ranch_edit(p:Vector2,pressed:bool):
 var cell=Vector2i((p/64).floor());var edge=nearest_edge(p)
 var result=""
 if painting=="paint":
  if build_tool.begins_with("feeder_"):
   if not pressed:return
   result=region.place_feeder(build_tool.substr(7),cell)
  else:
   if edge[1]==last_edit and not pressed:return
   last_edit=edge[1];result=region.set_edge(edge[1],build_tool)
 else:
  if region.feeder_at(cell)>=0 and (pressed or edge[0]>16):result=region.take_feeder(cell)
  else:
   if edge[1]==last_edit and not pressed:return
   last_edit=edge[1];result=region.set_edge(edge[1],"")
 if result=="ok":
  if audio:audio.sfx("plant" if painting=="paint" else "ui_close",-14)
 elif result!="" and pressed:notify(result)
 queue_redraw()
## On leaving ranch build mode: say which animals have no feeder, water or barn.
func ranch_report():
 var notes=ranch_notes()
 if not notes.is_empty():notify(notes[0])

func ranch_notes()->Array:
 var notes=[]
 for k in region.KINDS:
  if sim.livestock.members(k).is_empty():continue
  var name=str(Book.KIND.get(k,k))
  if not region.troughs.has(k):
   notes.append("先放置牧场食槽，"+name+"就有地方吃食了")
  elif float(sim.livestock.data.pens[k].feed)<=0.:
   notes.append("牧场食槽里的"+str(StateModel.ITEM_NAMES[Herd.FOOD.get(k,"wheat")])+"用完了，记得给"+name+"添食")
  elif sim.livestock.data.pens[k].get("river_only",false) and herd_ai.drinking_spots.get(k,[]).is_empty() and herd_ai.natural_banks().is_empty():
   notes.append(name+"需要一处能走到的水岸")
 return notes
const KIND_COLOR={"cow":Color(1,.95,.75),"sheep":Color(.8,.95,1),"pig":Color(1,.75,.82),"chicken":Color(1,.9,.6)}
func draw_build():
 var m=editor_pointer()
 if not editor_tool_available(build_tool):return
 if Grid.FLOORS.has(build_tool) or build_tool.begins_with("furn:") or (region==null or is_barn_floor()) and build_tool.begins_with("prop:"):
  placement.preview(self,build_tool,m);return
 if is_barn_floor():
  if build_tool=="stairs":barn_stairs.draw_preview(self,m)
  elif build_tool in ["fence","gate"] or build_tool.begins_with("feeder_"):barn_editor.draw_preview(self,m)
  return
 if region==null:return
 # Prop tools: a ghost of the prop where it would stand; otherwise outline the prop under the mouse.
 if build_tool.begins_with("prop:"):
  var name=build_tool.substr(5);var t=region.prop_tex(name);var p=prop_spot(m)
  var w=t.get_width()*2.0;var h=t.get_height()*2.0;var good=region.prop_spot_ok(name,p)
  draw_texture_rect(t,Rect2(p-Vector2(w/2,h),Vector2(w,h)),false,Color(1,1,1,.7) if good else Color(1,.45,.4,.6))
  draw_circle(p,4,Color(.55,1,.6) if good else Color(1,.45,.4))
  return
 var hover=region.prop_at(m)
 if hover!="":
  var e=region.prop_nodes[hover];var t2=region.prop_tex(e.name)
  var w2=t2.get_width()*2.0;var h2=t2.get_height()*2.0
  draw_rect(Rect2(e.pos-Vector2(w2/2,h2),Vector2(w2,h2)).grow(3),Color("ffe08a"),false,2.0)
 if build_tool=="pick" or map_id=="pond":return
 var ok=Color(.55,1,.6,.9);var bad=Color(1,.45,.4,.9)
 if build_tool=="plot":
  var cell=plot_cell(m)
  for dx in range(-3,4):
   for dy in range(-2,3):
    draw_rect(Rect2(cell+Vector2(dx,dy)*64,Vector2(64,64)),Color(1,1,1,.12),false,1.0)
  var free=region.plot_free(cell)
  draw_rect(Rect2(cell,Vector2(64,64)).grow(-2),Color(ok if free else bad,.25),true)
  draw_rect(Rect2(cell,Vector2(64,64)).grow(-2),ok if free else bad,false,2.0)
 else:
  # Enclosures are tinted (green when they reach the creek, amber when not); open land stays clear.
  var homes={}
  for k in region.home:homes[region.home[k]]=k
  for i in region.enclosures.size():
   var e=region.enclosures[i]
   var tint=Color(.55,1,.6,.16) if e.creek else Color(1,.8,.4,.16)
   if not homes.has(i):tint=Color(1,1,1,.08)
   for c in e.cells:draw_rect(region.cell_rect(c).grow(-2),tint,true)
  var z=region.zone()
  for x in range(int(z.position.x),int(z.end.x)+1,64):draw_line(Vector2(x,z.position.y),Vector2(x,z.end.y),Color(1,1,1,.14),1.0)
  for y in range(int(z.position.y),int(z.end.y)+1,64):draw_line(Vector2(z.position.x,y),Vector2(z.end.x,y),Color(1,1,1,.14),1.0)
  var cell=Vector2i((m/64).floor())
  if build_tool.begins_with("feeder_"):
   var free=region.in_zone_cell(cell) and not region.cell_water(cell) and region.feeder_at(cell)<0
   draw_rect(region.cell_rect(cell).grow(-2),Color(ok if free else bad,.25),true)
   draw_rect(region.cell_rect(cell).grow(-2),ok if free else bad,false,2.0)
  else:
   var key=str(nearest_edge(m)[1]);var good=region.edge_ok(key)==""
   var mid=region.edge_mid(key);var along=Vector2(32,0) if key.begins_with("h") else Vector2(0,32)
   draw_line(mid-along,mid+along,Color(0,0,0,.35),7.0)
   draw_line(mid-along,mid+along,(Color("ffe08a") if build_tool=="gate" else ok) if good else bad,4.0)

var garden_soil:Texture2D
var crop_wind_shader:Shader
func refresh_crop(index:int):
 super.refresh_crop(index)
 if region!=null and index<region.beds.size():
  if garden_soil==null:
   var soil=Image.new()
   soil.load_png_from_buffer(FileAccess.get_file_as_bytes("res://qingxi-live/village-center/art/paddies/garden-bed.png"))
   garden_soil=ImageTexture.create_from_image(soil)
  var bed=region.beds[index]
  if bed.texture!=garden_soil:
   bed.texture=garden_soil
   bed.scale=fields[index].rect.size/garden_soil.get_size()
   if bed.has_meta("rim"):
    var rim=bed.get_meta("rim")
    rim.width=1.4;rim.default_color=Color(.36,.23,.16,.32)
 var crop=fields[index]
 if not crop.sprite.visible:return
 var plot:Dictionary=sim.data.crops[index]
 var product=str(sim.Garden.book().produce.get(plot.get("seed_key","seed"),"veg"))
 var plant=crop.sprite
 if product!="veg":
  if not plant.has_meta("old_crop_transform"):
   plant.set_meta("old_crop_transform",[plant.scale,plant.position])
   plant.scale=Vector2.ONE*46.0/36.0
   plant.position=Vector2(-23,-46)
  var stage=2 if crop.state==3 else 1 if crop.state==2 else 0
  plant.texture=sim.Garden.texture(product+"-"+str(stage))
 elif plant.has_meta("old_crop_transform"):
  var original=plant.get_meta("old_crop_transform")
  plant.scale=original[0];plant.position=original[1]
  plant.remove_meta("old_crop_transform")
 var material_:ShaderMaterial=crop.sprite.material
 if crop_wind_shader==null:
  crop_wind_shader=Shader.new()
  crop_wind_shader.code=FileAccess.get_file_as_string("res://qingxi-live/village-center/garden_crop.gdshader")
 if material_.shader!=crop_wind_shader:
  material_.shader=crop_wind_shader
  material_.set_shader_parameter("planted_at",crop.rect.get_center())

func cell_at(p:Vector2)->int:
 if region!=null and map_id==region.id and (map_id=="field" or region.is_meadow()):return region.cell_at(p)
 return super.cell_at(p)

func _draw():
 if build_mode and can_build() and not overlay.visible:
  var area:Rect2=placement.bounds
  var ink=Color(1.,.97,.79,.46)
  for x in range(ceili(area.position.x/64)*64,int(area.end.x)+1,64):
   draw_line(Vector2(x,area.position.y),Vector2(x,area.end.y),ink,1.6)
  for y in range(ceili(area.position.y/64)*64,int(area.end.y)+1,64):
   draw_line(Vector2(area.position.x,y),Vector2(area.end.x,y),ink,1.6)
  draw_build()
 if region!=null and map_id==region.id:
  # Selected plot: four small corner brackets, as in the original field.
  if selected_cell>=0 and selected_cell<fields.size():
   var r:Rect2=fields[selected_cell].rect.grow(-4)
   # 2026-11-19 Claude: each bracket now points into the plot from its own corner
   # (before, all four were drawn like the top-left one, so three pointed outward).
   var ink=Color(1,.96,.8,.95)
   for c in [r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]:
    var left=c.x<=r.position.x;var top=c.y<=r.position.y
    var x0=c.x if left else c.x-14.0;var y0=c.y if top else c.y-3.0
    draw_rect(Rect2(x0,y0,14,3),ink)
    draw_rect(Rect2(c.x if left else c.x-3.0,c.y if top else c.y-14.0,3,14),ink)
  return
 super._draw()

func set_light(value:float):
 super.set_light(value)
 if is_instance_valid(lighting):lighting.apply(value*24.0)
 var night=night_level>.5
 if audio!=null and (night!=last_night or map_id!=last_place):last_night=night;last_place=map_id;audio.place(map_id,night)

# ---------------- presentation ----------------
## Player-facing HUD: the test-tool and lighting buttons stay on their keys (F10, 1–7)
## but leave the top bar; a soft fade covers every map change.
var fade:ColorRect
var ui   # hud.gd: minimap, info cluster, prompt, toasts
func tidy_hud():
 # The old text bars give way to hud.gd; the menu panel (overlay) stays and is restyled.
 for child in hud.get_children():
  if child!=overlay:child.hide()
 hud.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 ui=preload("res://qingxi-live/village-center/hud.gd").new();hud.add_child(ui);hud.move_child(ui,0);ui.setup(self)
 overlay.add_theme_stylebox_override("panel",KIT.frame("window"))
 overlay.position=Vector2(174,40);overlay.custom_minimum_size=Vector2(420,0)
 KIT.style_scroll(overlay.get_child(0))
 var layer=CanvasLayer.new();layer.layer=10;add_child(layer)
 fade=ColorRect.new();fade.color=Color("1d1a24");fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 fade.mouse_filter=Control.MOUSE_FILTER_IGNORE;fade.modulate.a=0.0;layer.add_child(fade)
func _process(dt):
 if ui!=null and is_instance_valid(player):ui.refresh(dt)
 if is_instance_valid(weather_view):weather_view.visible=map_id in ["village","field","ranch","pond"]
 if region!=null and is_barn_floor():region.window_tick(sky_value()*24.0)
 if is_instance_valid(hotbar):
  hotbar.refresh()
  if hotbar.library.visible:ui.banner.hide()
 if is_instance_valid(edit_button):
  ui.actions.visible=not build_mode
  edit_button.visible=can_build() and not overlay.visible
  edit_button.text="完成  G" if build_mode else "编辑  G"
  edit_button.position=Vector2(get_viewport_rect().size.x-edit_button.size.x-8,60)
func notify(message:String):
 super.notify(message)
 if ui!=null:ui.toast(message)
## Windows share ui_kit.gd: wood frame, title plaque, pixel close button, pop-in.
const KIT=preload("res://qingxi-live/village-center/ui_kit.gd")
## Bag: slot grid with pixel icons and counts; hovering names the item, its home stock and price.
func show_bag():
 open_menu="bag";clear_menu("背包","bag")
 var head=HBoxContainer.new();overlay_body.add_child(head)
 head.add_child(KIT.label("随身携带",11,KIT.INK2));var gap=Control.new();gap.size_flags_horizontal=Control.SIZE_EXPAND_FILL;head.add_child(gap)
 head.add_child(KIT.coin_chip(sim.data.coins))
 var names=StateModel.ITEM_NAMES.duplicate();names.merge(StateModel.YOUNG_NAMES)
 for key in sim.data.bag:
  if key.begins_with("catch:"):names[key]=sim.goods_name(key)
  elif Book.price(key)>0 or key.begins_with("young_"):names[key]=Book.item_name(key)
  elif key.begins_with("feeder_"):names[key]=sim.FEEDERS.get(key.substr(7),key)
  elif key.begins_with("decor_"):names[key]=sim.goods_name(key)
 names.merge(sim.FARM_ITEMS)
 KIT.inventory(overlay_body,sim.data.bag,names,bag_detail,use_bag_item,can_use_bag_item)
func bag_detail(key:String)->String:
 if sim.Garden.edible(key):return "   · 点击食用"
 if key.begins_with("catch:"):return "   · 点击做鲜鱼料理；出货 %d 币"%sim.shipping_price(key)
 if key.begins_with("decor_"):return "   · 布置模式里摆放"
 if key.begins_with("feeder_"):return "   · 布置牧场时摆放"
 if key.begins_with("young_"):return "   · 在牧场或畜舍里点击放进去"
 if key=="well_water":return "   · 在田边点击，浇周围九格"
 if key in ["honey","dried_fish"]:return "   · 点击食用，也可出货 %d 币" % sim.shipping_price(key)
 var price=sim.shipping_price(key)
 return "   家中 %d"%int(sim.data.storage.get(key,0))+(("   收购 %d 币"%price) if price>0 else "")
func can_use_bag_item(key:String)->bool:
 if sim.Garden.edible(key):return true
 if key.begins_with("catch:") or key=="fish":return true
 if key=="well_water":return map_id=="field" or (region!=null and region.is_meadow())
 if key in ["honey","dried_fish"]:return true
 # 2026-11-19 Claude: young animals can also be let go inside the barn (畜舍 / 牧场屋).
 return key.begins_with("young_") and (map_id=="ranch" or map_id=="barn")
func use_bag_item(key:String):
 if sim.Garden.edible(key):perform(sim.Garden.eat(sim,key));show_bag();return
 if key.begins_with("catch:") or key=="fish":
  perform(sim.cook_catch(key));save_progress();show_bag();return
 if key.begins_with("young_"):release_young(key);return
 if not can_use_bag_item(key):return
 if key=="well_water":
  var cells=[]
  var center=plot_cell(player.position+facing_vector()*23)+Vector2(32,32)
  for i in fields.size():
   var offset=(fields[i].rect.get_center()-center).abs()
   if offset.x<=64 and offset.y<=64:cells.append(i)
  perform(sim.water_area(cells))
 else:perform(sim.eat_harvest(key))
 show_bag()
func release_young(key:String):
 var message=sim.release_young(key.substr(6))
 if message!="":notify(message)
 if audio:audio.sfx("moo",-8)
 refresh_life();save_progress();show_bag()
## Esc pauses instead of quitting straight away; H shows every key in one card.
func show_animal(id:String):
 var a=sim.livestock.animal(id)
 if a.is_empty():close_menu();return
 open_menu="animal"
 var nm:=str(a.get("name","")).strip_edges()
 var title:="%s #%s" % [Book.breed_name(a),id]
 if nm!="":title="「%s」%s" % [nm,title]
 clear_menu(title)
 var age="成年" if sim.livestock.adult(a) else "幼年 · %d%%" % int(100*a.age/Book.MATURITY[a.kind])
 menu_line("%s   %s   %s" % ["母" if a.sex=="f" else "公",age,Book.GRADE[int(a.quality)-1]])
 menu_line("饱食度 %d / 100     饮水 %d / 100     生命 %d / %d" % [roundi(a.food),roundi(a.drink),ceili(a.hp),Book.MAX_HP[a.kind]])
 var condition:String=sim.livestock.care_status(a)
 if condition!="":overlay_body.add_child(label(condition,11,Color("a3492c")))
 menu_line(Book.TRAIT_NAMES[Book.breed_trait(a)])
 menu_line("血统 · %s × %s" % [Book.BREEDS[a.kind][a.genes[0]],Book.BREEDS[a.kind][a.genes[1]]])
 if not a.parents.is_empty():menu_line("双亲 · #%s 和 #%s" % a.parents)
 if not a.pregnancy.is_empty():
  menu_line(("孵化" if a.kind=="chicken" else "待产")+" · 约 %d 分钟后迎来幼崽" % ceili(float(a.pregnancy.left)/sim.livestock.RATE/60))
 elif a.cooldown>0:menu_line("繁育休养 · 约 %d 分钟" % ceili(float(a.cooldown)/sim.livestock.RATE/60))
 if sim.livestock.can_produce(a) and sim.livestock.adult(a):
  var item=Book.PRODUCT[a.kind]
  if a.ready>0:
   menu_button("收取%s ×%d" % [Book.LABEL[item],Book.harvest_amount(a)],func():perform(sim.animal_action(id));show_animal(id))
  else:menu_line("%s · 照料良好时约 %d 分钟后可收" % [Book.LABEL[item],ceili((Book.interval(a)-a.progress)/sim.livestock.RATE/60)])
 menu_button("喂点心 · "+("胡萝卜" if a.kind=="pig" else "小麦"),func():perform(sim.livestock.treat(id,sim.data.bag));show_animal(id))
 menu_button("给它取个名字 / 改名",func():show_pet_name("animal",str(a.get("kind","")),id,func():show_animal(id)))
 menu_button("配对与血统",func():show_pairing(id))
 if a.pregnancy.is_empty():menu_button("出栏交易",func():stock_trade(id))

# ---------------- 2026-11-21 pets：农场上的猫和狗（主人端） ----------------
## 宠物角 · 领养小猫小狗。宠物没有数量上限，领养当场住进农场（不进背包）。
## 名字可以之后走近它按 E 取，或者让住户在那边取（同一套规则）。
## v2：按品种分按钮（价格 = 基础价 + 品种差价，全部来自 pets_rules.json 的 breeds 段）。
func show_pet_adopt():
 open_menu="pet_adopt"
 clear_menu("宠物角 · 领养小猫小狗")
 menu_line("领养的小猫小狗当场住进农场，不经过背包。宠物没有数量上限（钱是唯一的门槛）。")
 menu_line("每个品种脾气不一样：喂它/陪它玩/带回来的东西都会不一样（下面写了）。")
 menu_line("取名字：走近它按 E；只有领养人可以改名或叫它跟随。领养的是幼崽，3 天长大。")
 for kind in PET_RULES.kinds():
  for row in PET_RULES.breed_menu(str(kind)):
   var kk:=str(kind)                  # 每轮绑一个局部，闭包按它取（同 show_pairing 里 b 的写法）
   var bb:=str(row.get("key",""))
   var nm:=str(row.get("name",""))
   var price:=int(row.get("price",0))
   menu_button("%s · %d 币（现在有 %d 币）" % [nm,price,int(sim.data.coins)],func():
    adopt_at_player(kk,bb))
   menu_line("    %s" % str(row.get("note","")))
 if sim.pet_roster().count()>0:
  menu_line("农场里现在有 %d 只宠物。" % sim.pet_roster().count())

## 宠物不在圈里，也不进背包：按 E 就能看它、取名字、陪它玩、喂它、带狗出去走。
func adopt_at_player(kind:String,breed:String):
 var before={}
 for pet in sim.pet_roster().list():before[str(pet.id)]=true
 var message=sim.adopt_pet(kind,breed)
 for pet in sim.pet_roster().list():
  if before.has(str(pet.id)):continue
  var spot:Vector2=player.position
  for offset in [Vector2(26,8),Vector2(-26,8),Vector2(0,26),Vector2(0,-26),Vector2(16,0),Vector2(-16,0)]:
   if not blocked(player.position+offset) and herd_ai.clear_walk(player.position,player.position+offset):
    spot=player.position+offset;break
  pet.pos=[spot.x,spot.y]
  pet["adopted_here_until"]=Time.get_unix_time_from_system()+15.0
  save_progress();close_menu();refresh_life();perform(message)
  return
 perform(message);show_pet_adopt()

func pet_menu_now()->float:return Time.get_unix_time_from_system()
func pet_menu_hour()->float:return sky_value()*24.0   ## 场上的时钟（Cabin World 里跟着小屋世界走）

func show_pet(id:String):
 var roster=sim.pet_roster()
 var pet:Dictionary=roster.find(id)
 if pet.is_empty():close_menu();return
 var now:=pet_menu_now();var hour:=pet_menu_hour()
 open_menu="pet"
 clear_menu("%s · %s" % [PET_RULES.name_text(pet),PET_RULES.breed_cn(pet)])
 var nm:=str(pet.get("name","")).strip_edges()
 var by:=PET_RULES.named_by_cn(str(pet.get("named_by","")))
 menu_line("主人：%s" % sim.Ownership.caption(pet))
 var mine=sim.Ownership.denied(pet,"owner")==""
 if nm=="":menu_line("还没有名字（现在叫 %s）。" % PET_RULES.name_text(pet))
 else:menu_line("名字「%s」%s" % [nm,("是%s取的"%by) if by!="" else ""])
 menu_line("品种：%s      %s" % [PET_RULES.breed_cn(pet),PET_RULES.stage_text(pet,now)])
 var bnote:=PET_RULES.breed_note(pet)
 if bnote!="":menu_line("    %s" % bnote)
 menu_line("亲密 %d / 100      饱食度 %d / 100" % [roundi(PET_RULES.bond_of(pet)),roundi(PET_RULES.food_of(pet))])
 menu_line("现在：%s%s" % [PET_RULES.pet_state(pet,now,hour),"" if not PET_RULES.is_away(pet,now) else "（约 %s后回来）"%PET_RULES.minutes_text(PET_RULES.away_left(pet,now))])
 if int(pet.get("gifts",0))>0:menu_line("已经带回来 %d 次东西（真的进了农场背包）" % int(pet.get("gifts",0)))
 if PET_RULES.is_dog(pet) and int(pet.get("guards",0))>0:menu_line("已经看过 %d 夜家" % int(pet.get("guards",0)))
 var nxt:=PET_RULES.next_of(pet,now,hour)
 if nxt!="":menu_line(nxt)
 if mine:menu_button("给它取个名字 / 改名",func():show_pet_name("pet",str(pet.get("kind","")),id,func():show_pet(id)))
 menu_button("摸摸 / 陪它玩",func():perform(sim.pet_roster().play(id));save_progress();show_pet(id))
 var food_key = sim.pet_roster().feed_key_for(str(pet.get("kind","")),sim.data.bag)
 if food_key!="":
  menu_button("喂它 · %s ×%d" % [PET_RULES.feed_item_name(food_key),int(sim.data.bag.get(food_key,0))],func():perform(sim.pet_roster().feed(id,sim.data.bag));save_progress();refresh_life();show_pet(id))
 else:menu_line("背包里没有它吃的东西（牧铃畜牧铺出售猫粮和狗粮，每份 3 币）")
 if PET_RULES.is_dog(pet):
  menu_button("带它出去走走",func():perform(sim.pet_roster().walk(id));save_progress();show_pet(id))
 else:
  menu_line("猫自己出门玩时，有机会带东西回来。")
 if not mine:return
 var following:=PET_RULES.wants_follow(pet,now,hour)
 menu_button("叫它留在家里" if following else "叫它跟着我",func():
  sim.Ownership.follow(pet,"owner",not following)
  close_menu();herd_ai.pets_refresh();save_progress()
  notify(PET_RULES.name_text(pet)+("留在农场" if following else "开始跟着你了")))

## 取名 / 改名：三个玩家共用同一套规则（宠物与牲畜也是同一套字段与校验）。
## target = "pet"（宠物名册）或 "animal"（牲畜 herd 记录）；back 是提交后回到哪个菜单。
func show_pet_name(target:String,species:String,id:String,back:Callable):
 open_menu="pet_name"
 var max_chars:=int(PET_RULES.naming().get("max_chars",12))
 clear_menu("给它取个名字")
 menu_line("1–%d 个字；可以重名；留空 = 清除名字。" % max_chars)
 var pet:Dictionary={}
 var current:=""
 if target=="pet":
  pet=sim.pet_roster().find(id)
  current=str(pet.get("name",""))
 else:
  var a:Dictionary=sim.livestock.animal(id)
  current=str(a.get("name",""))
 var field:=LineEdit.new()
 field.max_length=max_chars
 field.placeholder_text="例如 咪咪"
 field.text=current
 field.add_theme_font_override("font",KIT.font())
 field.add_theme_font_size_override("font_size",17)
 field.add_theme_color_override("font_color",KIT.INK)
 field.add_theme_color_override("font_placeholder_color",KIT.INK2)
 field.add_theme_color_override("caret_color",KIT.INK)
 overlay_body.add_child(field)
 var submit:=func():
  var raw:String=field.text
  field.release_focus()
  perform(_submit_pet_name(target,species,id,raw))
  save_progress();refresh_life();back.call()
 field.text_submitted.connect(func(_t:String):submit.call())
 menu_button("就叫这个名字",submit)
 menu_button("返回",back)
 field.grab_focus()

## 提交名字（主人端）：返回一句回执，交给 perform 显示。校验全部来自数据文件。
func _submit_pet_name(target:String,species:String,id:String,raw:String)->String:
 var now:=pet_menu_now()
 var checked:=PET_RULES.name_ok(raw)
 if not bool(checked.get("ok",false)):return str(checked.get("why","这个名字不能用"))
 var cleaned:=str(checked.get("text",""))
 if target=="pet":
  var r = sim.name_owned_pet(id,cleaned,"owner",now)
  return str(r.get("text",""))
 var a:Dictionary=sim.livestock.animal(id)
 if a.is_empty():return "这只动物已经离开了"
 var wait:=PET_RULES.rename_wait(a,now)
 if wait>0.5:return "它刚改过名字，再等 %.0f 秒" % wait
 a["name"]=cleaned
 a["named_by"]="owner"
 a["named_at"]=now
 if cleaned=="":return "把名字清掉了，现在叫 %s #%s" % [PET_RULES.kind_cn(species),id]
 return "把它叫作「%s」了（主人取的，所有人都看得见）" % cleaned

func show_pairing(id:String):
 var a=sim.livestock.animal(id)
 if a.is_empty():close_menu();return
 clear_menu("%s #%s · 配对" % [Book.breed_name(a),id])
 menu_line("同类成年公母吃饱喝足后会自动配对。幼崽从双亲各继承一种毛色，异色血统和双亲点心都能提高升品机会。")
 menu_line("当前 · "+("暂停配对" if not a.auto_pair else ("自由配对" if a.mate=="" else "指定 #"+str(a.mate))))
 menu_button("自由配对",func():set_pair(a,{},true))
 menu_button("暂停这只的配对",func():set_pair(a,{},false))
 for other in sim.livestock.members(a.kind):
  if sim.livestock.compatible(a,other) and sim.livestock.adult(other):
   var b:Dictionary=other
   menu_button("选择 #%s · %s · %s" % [b.id,Book.breed_name(b),Book.GRADE[int(b.quality)-1]],func():set_pair(a,b,true))
 menu_button("返回",func():show_animal(id))
func set_pair(a:Dictionary,b:Dictionary,enabled:bool):
 if sim.pair_stock(a.id,str(b.get("id","")),enabled):save_progress()
 show_pairing(a.id)
func stock_trade(id:String):
 var a=sim.livestock.animal(id)
 if a.is_empty():close_menu();return
 clear_menu("出栏 · "+Book.breed_name(a)+" #"+id)
 menu_line("交易后这只动物会离开牧场。")
 menu_button("出售活畜 · %d 币" % Book.live_price(a),func():close_menu();perform(sim.sell_stock(id,false)))
 if sim.livestock.adult(a):
  var parts=[]
  for key in Book.YIELD[a.kind]:parts.append(Book.LABEL[key])
  menu_button("送去加工 · 取回"+"、".join(parts),func():close_menu();perform(sim.sell_stock(id,true)))
 menu_button("返回",func():show_animal(id))
var feeder_stock:Label
var feeder_kind=""

const CHEST_COLUMNS=9
const CHEST_ROWS=3
var chest_pages=[0,0]
var chest_key=""
var chest_side=0
var chest_quantity:SpinBox
var chest_transfer_button:Button
var chest_detail:Label
var chest_selected_slot:Button

func show_shared_chest(_take:bool=false):
 if not Features.on("sharedChest12"):notify("共用物资箱模块已关闭");return
 if open_menu!="shared_chest" or not overlay.visible:
  chest_pages=[0,0];chest_key=""
 open_menu="shared_chest";clear_menu("共用物资箱")
 overlay_body.add_theme_constant_override("separation",3)
 chest_selected_slot=null
 for side in 2:chest_grid(side)
 var footer=HBoxContainer.new()
 overlay_body.add_child(footer)
 chest_detail=KIT.label("点选物品",11,KIT.INK,true)
 chest_detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 chest_detail.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 footer.add_child(chest_detail)
 chest_quantity=SpinBox.new()
 chest_quantity.custom_minimum_size.x=59;chest_quantity.min_value=1
 chest_quantity.get_line_edit().add_theme_font_size_override("font_size",12)
 footer.add_child(chest_quantity)
 chest_transfer_button=button("转移",func():chest_transfer(chest_side,chest_key,int(chest_quantity.value)))
 footer.add_child(chest_transfer_button)
 overlay_body.add_child(KIT.label("右键移 1 件    Shift＋左键移整组",10,KIT.INK2))
 chest_selection()

func chest_stock(side:int)->Dictionary:
 return sim.data.get("shared_chest",{}) if side==0 else sim.data.bag

func chest_grid(side:int):
 var stock=chest_stock(side)
 var keys=stock.keys().filter(func(key):return int(stock[key])>0)
 keys.sort()
 var page_size=CHEST_COLUMNS*CHEST_ROWS
 var pages=maxi(1,ceili(float(keys.size())/page_size))
 var page=clampi(chest_pages[side],0,pages-1)
 chest_pages[side]=page
 var head=HBoxContainer.new()
 overlay_body.add_child(head)
 head.add_child(KIT.label("箱内物品" if side==0 else "随身背包",12,KIT.INK,true))
 var rule=ColorRect.new();rule.color=KIT.PAPER_D;rule.custom_minimum_size.y=2
 rule.size_flags_horizontal=Control.SIZE_EXPAND_FILL;rule.size_flags_vertical=Control.SIZE_SHRINK_CENTER;head.add_child(rule)
 if pages>1:
  for step in [-1,0,1]:
   if step==0:head.add_child(KIT.label("%d / %d"%[page+1,pages],10,KIT.INK2));continue
   var arrow=button("‹" if step<0 else "›",func():chest_pages[side]+=step;show_shared_chest())
   arrow.disabled=page+step<0 or page+step>=pages;head.add_child(arrow)
 var grid=GridContainer.new();grid.columns=CHEST_COLUMNS
 grid.add_theme_constant_override("h_separation",2);grid.add_theme_constant_override("v_separation",2)
 grid.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;overlay_body.add_child(grid)
 for i in page_size:
  var idx=page*page_size+i
  var key=str(keys[idx]) if idx<keys.size() else ""
  var slot=Button.new()
  slot.custom_minimum_size=Vector2(36,31);slot.disabled=key==""
  for state in ["normal","hover","pressed","disabled","focus"]:
   var frame="slot_off" if state=="disabled" else ("slot" if state=="normal" else "slot_hi")
   slot.add_theme_stylebox_override(state,KIT.frame(frame))
  grid.add_child(slot)
  if key=="":continue
  slot.set_meta("item",key);slot.set_meta("side",side)
  slot.tooltip_text="%s ×%d"%[sim.goods_name(key),stock[key]]
  slot.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
  var art=KIT.icon(chest_icon_key(key),1)
  slot.add_child(art);art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  art.offset_left=5;art.offset_right=-5;art.offset_top=3;art.offset_bottom=-5
  var amount=KIT.label(str(int(stock[key])),10,KIT.CREAM,true,KIT.WOOD_D)
  slot.add_child(amount);amount.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;amount.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM
  amount.offset_right=-3;amount.mouse_filter=Control.MOUSE_FILTER_IGNORE
  if key==chest_key and side==chest_side:
   chest_selected_slot=slot;slot.add_theme_stylebox_override("normal",KIT.frame("slot_hi"))
  slot.pressed.connect(func():chest_select(slot,side,key))
  slot.gui_input.connect(func(event):
   if event is InputEventMouseButton and event.pressed:
    if event.button_index==MOUSE_BUTTON_RIGHT:
     slot.accept_event();chest_transfer(side,key,1)
    elif event.button_index==MOUSE_BUTTON_LEFT and event.shift_pressed:
     slot.accept_event();chest_transfer(side,key,int(chest_stock(side).get(key,0))))

func chest_icon_key(key:String)->String:
 if key.begins_with("catch:"):return "fish"
 if key=="dog_food":return "pig_feed"
 if key=="cat_food":return "fish_feed"
 return key

func chest_select(slot:Button,side:int,key:String):
 if is_instance_valid(chest_selected_slot):chest_selected_slot.add_theme_stylebox_override("normal",KIT.frame("slot"))
 chest_selected_slot=slot;slot.add_theme_stylebox_override("normal",KIT.frame("slot_hi"))
 chest_side=side;chest_key=key;chest_selection()

func chest_selection():
 var count=int(chest_stock(chest_side).get(chest_key,0))
 chest_transfer_button.disabled=count<=0
 chest_quantity.editable=count>0;chest_quantity.max_value=maxi(1,count);chest_quantity.value=1
 chest_transfer_button.text="取出" if chest_side==0 else "存入"
 chest_detail.text=("%s ×%d"%[sim.goods_name(chest_key),count]) if count>0 else "点选物品"

func chest_transfer(side:int,key:String,count:int):
 if key=="" or count<1:return
 var result=sim.transfer_chest(side==0,key,count)
 save_progress();show_shared_chest();notify(result)


func show_pen(kind:String):
 if not sim.FEEDERS.has(kind):return
 open_menu="pen";clear_menu("牧场食槽")
 menu_line("牛、羊、猪、鸡都能来这里吃。")
 for species in ["cow","sheep","pig","chicken"]:
  var item:String=Herd.FOOD.get(species,"wheat")
  var carried=int(sim.data.bag.get(item,0))
  var caption="%s · 添加%s ×1　背包 %d　槽中 %.1f 份"%[sim.NAMES.get(species,"鸡"),StateModel.ITEM_NAMES[item],carried,float(sim.livestock.data.pens[species].feed)/86400.]
  var add=button(caption,func():perform(sim.livestock.feed_pen(species,sim.data.bag));save_progress();show_pen(species))
  add.disabled=carried<=0;overlay_body.add_child(add)

func refresh_feeder_stock():
 if open_menu!="pen" or not overlay.visible or not is_instance_valid(feeder_stock):return
 var item:String=Herd.FOOD.get(feeder_kind,"wheat")
 var portions=float(sim.livestock.data.pens[feeder_kind].feed)/86400.0
 feeder_stock.text="储存量 · %s %.2f 份" % [StateModel.ITEM_NAMES[item],portions]

func show_pause():
 open_menu="pause";clear_menu("暂停")
 var col=VBoxContainer.new();col.add_theme_constant_override("separation",6);overlay_body.add_child(col)
 for entry in [["继续游戏",close_menu,true],["地图",show_map,false],["按键",show_help,false],["乘公交回小屋世界",func():close_menu();save_progress();get_tree().get_meta("qingxi_world_host").owner_bus_home(),false] if get_tree().has_meta("qingxi_world_host") else ["保存并退出",func():save_progress();get_tree().quit(),false]]:   # 2026-11-19 Claude (Cabin World host): inside Cabin World this would touch the whole app
  var b=KIT.button(entry[0],entry[1],entry[2]);b.custom_minimum_size=Vector2(0,30);b.pressed.connect(func():if audio:audio.sfx("ui_click",-10));col.add_child(b)
func show_help():
 open_menu="help";clear_menu("按键","help")
 KIT.key_rows(overlay_body,[["W A S D","行走"],["Shift","快走"],["E","互动"],["Q","手持小麦 / 胡萝卜"],["B","背包"],["M","地图"],["G","编辑"],["Tab / 1–9","设施库 / 工具槽"],["1–7 T","时段 · 昼夜"],["Esc","关闭 · 暂停"]])
func animate_menu():
 KIT.pop_in(overlay)
func fade_in():
 if fade==null or paused_for_capture:return
 fade.modulate.a=1.0
 var t=create_tween();t.tween_interval(.05);t.tween_property(fade,"modulate:a",0.0,.45).set_trans(Tween.TRANS_SINE)

# ---------------- sound hooks ----------------
func button(text_:String,fn:Callable)->Button:
 var b=super.button(text_,fn);b.pressed.connect(func():if audio:audio.sfx("ui_click",-10))
 KIT.style_button(b);return b
func label(text_:String,size_:int,color=KIT.INK)->Label:
 if ui==null:return super.label(text_,size_,color)
 return KIT.label(text_,size_,KIT.INK if color==Color("554a38") else color)
func menu_line(text_:String):
 var l=label(text_,11);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;overlay_body.add_child(l)
func clear_menu(title:String,icon_name:=""):
 var opening=not overlay.visible
 if audio and opening:audio.sfx("ui_open",-10)
 overlay.visible=true
 for child in overlay_body.get_children():overlay_body.remove_child(child);child.queue_free()
 overlay_body.add_theme_constant_override("separation",8)
 overlay_body.add_child(KIT.header(title,close_menu,icon_name))
 fit_menu.call_deferred()
 if opening and ui!=null:animate_menu.call_deferred()
func fit_menu():
 var compact=open_menu=="pen"
 var scroller:ScrollContainer=overlay.get_child(0)
 overlay.custom_minimum_size.x=266.0 if compact else 420.0
 scroller.custom_minimum_size.x=246.0 if compact else 440.0
 KIT.fit(scroller,overlay_body,348.0 if open_menu=="map" else 330.0);overlay.reset_size()
 overlay.position.x=roundf((get_viewport_rect().size.x-overlay.size.x)/2.0) if compact else 174.0
func close_menu():
 if audio and overlay.visible:audio.sfx("ui_close",-12)
 super.close_menu()
var juice   # 2026-11-19 Claude: juice.gd (pops, bursts, fly-to-bag)
func perform(message:String):
 # 2026-11-19 Claude: every action also gets a small visible reaction where it happened.
 if is_instance_valid(juice) and is_instance_valid(player):
  var at=player.position-Vector2(0,30)
  if selected_cell>=0 and selected_cell<fields.size():
   at=fields[selected_cell].rect.get_center()
   var plant_sprite=fields[selected_cell].get("sprite")
   if is_instance_valid(plant_sprite):
    # Animate the plot's anchor. Each crop owns its texture scale, which can
    # change during the same interaction when sowing or harvesting.
    var anchor=plant_sprite.get_parent()
    var previous=anchor.get_meta("crop_pulse",null) if anchor.has_meta("crop_pulse") else null
    if previous is Tween:previous.kill()
    anchor.scale=Vector2.ONE
    var pulse=anchor.create_tween()
    anchor.set_meta("crop_pulse",pulse)
    pulse.tween_property(anchor,"scale",Vector2(1.25,.8),.07)
    pulse.tween_property(anchor,"scale",Vector2.ONE,.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
  juice.react(message,at)
 if audio:
  if "收获" in message or "捕捞" in message:audio.sfx("harvest",-8)
  elif "播种" in message:audio.sfx("plant",-8)
  elif "浇水" in message or "湿润" in message:audio.sfx("water",-8)
  elif "鱼苗" in message or "投喂" in message:audio.sfx("splash",-8)
  elif "币" in message:audio.sfx("coin",-8)
 super.perform(message)
## Ground under the feet decides the footstep sound.
func surface_at(p:Vector2)->String:
 if is_instance_valid(placement):
  match placement.plan.tiles.get(Grid.key(Grid.cell(p)),""):
   "wood_tile":return "wood"
   "stone_tile":return "stone"
 if is_barn_floor():return "wood"
 if in_interior() or rooms.contains(map_id):return "wood"
 var d=ground_data()
 if map_id=="village":
  if qingxi.on_bridge(p):
   for b in qingxi.bridges:
    if Rect2(b.pos-b.size/2,b.size).has_point(p):return "wood" if b.style=="wood" else "stone"
  if p.distance_to(qingxi.plaza)<140:return "stone"
 elif d!=null and d.creek_clearance(p)<=0:return "wood"   # decks and bridges over water
 if d!=null and d.on_road(p,0):return "dirt"
 return "grass"
## 2026-11-19 Claude: water the owner digs on the farm counts for the river sound too
## (before, only the baked creek did). The farm (flat-build/trial.gd) overrides these two.
func painted_water_distance(_p:Vector2)->float:return INF
func fish_pond_distance(_p:Vector2)->float:return INF
func footsteps(moved:float):
 if audio==null:return
 var viewer=time_host()
 if viewer and not viewer.controls(self):return
 var shallow=water_contact and not swimming
 if moved>.001 and not swimming:
  var stride:float=maxf(1.0,float(audio.wading.get("stride_pixels",19))) if shallow else 40.0
  if shallow!=walking_in_shallows:step_distance=stride if shallow else 0.0
  step_distance+=moved
  if step_distance>=stride:
   step_distance=fmod(step_distance,stride)
   audio.step("water" if shallow else surface_at(player.position))
 elif swimming:
  step_distance=0.0
 walking_in_shallows=shallow if moved>.001 else (walking_in_shallows and shallow)
 update_environment_audio(player.position)

func update_environment_audio(listener:Vector2):
 if not is_instance_valid(audio):return
 if not in_interior() and not rooms.contains(map_id):
  var d=ground_data()
  var creek=d.creek_clearance(listener) if d!=null else INF
  audio.set_water(minf(creek,painted_water_distance(listener)))
  audio.set_pond(fish_pond_distance(listener))
 else:audio.set_water(9999);audio.set_pond(9999)
 if map_id=="village" and district!=null:
  var in_plaza=listener.distance_to(qingxi.plaza)<(460.0 if audio.festival else 365.0)
  audio.set_festival(district.fire.lit and in_plaza)

func world_label(text_:String,p:Vector2)->Label:
 var tag=super.world_label(text_,p)
 tag.visibility_layer=2
 return tag

func place_house(index:int,p:Vector2,width_:float,door_x:float,title:String,open_door:bool):
 object(rooms.houses[index],p,width_,Rect2(),true,"house")
 var left=p.x-width_*.40;var right=p.x+width_*.40
 solids.append(Rect2(left,p.y-96,right-left,66))
 if open_door:
  solids.append(Rect2(left,p.y-30,door_x-27-left,24));solids.append(Rect2(door_x+27,p.y-30,right-door_x-27,24))
 else:solids.append(Rect2(left,p.y-30,right-left,24))
 world_label(title,Vector2(door_x,p.y+12))

func add_target(kind:String,p:Vector2,title:String,extra=""):
 # Village and outer maps only label exits; other targets show their name when you are close.
 # 2026-11-19 Claude: rooms too (no permanent "木椅 / 沙发" captions; the E prompt names it).
 if map_id!="village" and not (region!=null and map_id==region.id) and not rooms.contains(map_id):super.add_target(kind,p,title,extra);return
 targets.append({"kind":kind,"pos":p,"name":title,"extra":extra})
 if kind=="exit":world_label(title,p+Vector2(0,10))

func update_hud():
 super.update_hud()
 if not is_instance_valid(heading):return
 heading.text="%s  %02d:%02d  %d 币"%[MAP_NAMES[map_id],int(sky_value()*24),int(fmod(sky_value()*24,1)*60),sim.data.coins]
 details.get_parent().hide()
 status.text=status.text.replace("    ｜ M 地图 · B 背包 · F10 测试","").replace("    ｜ M 地图 · B 背包","")
 if map_id=="village" and elapsed>=message_until:status.text="WASD 行走 · E 互动 · M 地图 · B 背包 · 1 拂晓 2 清晨 3 正午 4 午后 5 黄昏 6 夜晚 7 凌晨 · T 昼夜流转"
 if can_build() and elapsed>=message_until:
  if build_mode:status.text=("布置模式 · 左键开垦 · 右键收回空田格 · G 完成" if map_id=="field" else "布置牧场 · "+tool_name(build_tool))
  else:status.text="WASD 行走 · E 互动 · G 布置"+("田地" if map_id=="field" else "牧场围栏")+" · M 地图 · B 背包"

var edit_pointer_local:=Vector2.INF
func editor_pointer()->Vector2:
 if not edit_pointer_local.is_finite():return get_global_mouse_position()
 return get_global_transform_with_canvas().affine_inverse()*edit_pointer_local

func _input(event):
 if event is InputEventMouse:
  edit_pointer_local=event.position
  if build_mode:queue_redraw()
 if not event is InputEventKey:return
 var viewer=time_host()
 if not viewer or not viewer.has_method("can_observer_edit") or not viewer.can_observer_edit():return
 if event.physical_keycode==KEY_G:
  if event.pressed and not event.echo:toggle_build()
  get_viewport().set_input_as_handled()

func _unhandled_key_input(event):
 if not owner_controls():
  var viewer=time_host()
  if not viewer or not viewer.has_method("can_observer_edit") or not viewer.can_observer_edit() or not build_mode:return
  if not event is InputEventKey or event.physical_keycode not in [KEY_TAB,KEY_ESCAPE,KEY_G,KEY_R,KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9]:return
 if rooms and rooms.owner_bed!="":
  if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_E:rooms.leave_bed()
  get_viewport().set_input_as_handled();return
 ## 2026-11-21 pets: 取名字时输入框有焦点，键位（WASD/E/TAB…）先归输入框，别被游戏抢走。
 if get_viewport().gui_get_focus_owner() is LineEdit:return
 if event is InputEventKey and event.pressed and not event.echo:
  if build_mode and is_instance_valid(hotbar) and not overlay.visible:
   if event.physical_keycode==KEY_TAB or (event.physical_keycode==KEY_ESCAPE and hotbar.library.visible):
    hotbar.toggle_library();get_viewport().set_input_as_handled();return
   if event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_9:
    hotbar.select(event.physical_keycode-KEY_1);get_viewport().set_input_as_handled();return
   if hotbar.library.visible and event.physical_keycode!=KEY_G:return
   if event.physical_keycode==KEY_R and build_tool in ["furn:ranch_lamp","furn:pasture_floodlight","pick"]:
    placement.rotate_lamp(editor_pointer(),build_tool!="pick")
    queue_redraw();get_viewport().set_input_as_handled();return
   if event.physical_keycode==KEY_R and build_tool=="stairs" and is_instance_valid(barn_stairs):
    barn_stairs.rotate_preview()
    queue_redraw();get_viewport().set_input_as_handled();return
  if event.physical_keycode==KEY_ESCAPE:
   if overlay.visible:close_menu()
   elif build_mode:toggle_build()
   else:show_pause()
   return
  if event.physical_keycode==KEY_H:
   if overlay.visible and open_menu=="help":close_menu()
   else:show_help()
   return
  if event.physical_keycode==KEY_B and overlay.visible and open_menu=="bag":close_menu();return
  if event.physical_keycode==KEY_M and overlay.visible and open_menu=="map":close_menu();return
  if event.physical_keycode==KEY_E and map_id=="village" and district!=null and district.seat>=0:district.stand();return
  # 2026-11-19 Claude (Cabin World host): time, season and light presets follow Cabin World there.
  if time_host() and event.physical_keycode in [KEY_F5,KEY_T,KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7] and not build_mode:
   notify("时间和天气跟随小屋世界");return
  if event.physical_keycode==KEY_F5 and map_id=="village":   # 2026-11-19 Claude: test key, next season
   next_day(Seasons.DAYS_PER_SEASON-(calendar_day()%Seasons.DAYS_PER_SEASON));return
  if event.physical_keycode==KEY_R and map_id=="village":district.stand();player.position=CENTER_START;update_camera(true);return
  if event.physical_keycode==KEY_G:toggle_build();return
  if event.physical_keycode in [KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7]:
   light_preset=4;center_hour=HOUR_PRESETS[event.physical_keycode-KEY_1];center_cycle=false;set_light(sky_value());return
  if event.physical_keycode==KEY_T:center_hour=sky_value()*24.0;light_preset=4;center_cycle=not center_cycle;return
 super._unhandled_key_input(event)

func show_idle():
 super.show_idle();portrait.flip_h=false;scale_actor()
func show_action(key:String,time_:float)->bool:
 if not clips.has(key):show_idle();return false
 var result=super.show_action(key,time_);portrait.flip_h=false;scale_actor();return result
func scale_actor():
 # Exactly the seed-shop body unit; frame calibration remains the pack's own.
 var elevation=floor_height(player.position)
 portrait.scale*=26.0/18.0
 portrait.position=(portrait.position+Vector2(0,elevation))*(26.0/18.0)-Vector2(0,elevation)

func sky_value()->float:
 var host=get_tree().get_meta("qingxi_world_host",false)
 # 2026-11-19 Claude (Cabin World host): inside Cabin World the sky is always Cabin World's hour.
 if host:return host.local_hour()/24.0
 return rural_sky[light_preset] if light_preset<4 else center_hour/24.0
var swim_surface
var swim_phase=0.0
var swimming=false
var water_contact=false
var swim_frames=[]

func show_swim(moving:bool):
 if character_source!=CHARACTER_ROOT:
  show_action("swim-%d"%facing if clips.has("swim-%d"%facing) else "walk-%d"%facing,swim_phase*.13)
  portrait.position.y+=10
  return
 if swim_frames.is_empty():
  var image_=Image.load_from_file("res://qingxi-live/assets/studio-whale/swim.png")
  var sheet=ImageTexture.create_from_image(image_)
  var cell_size=Vector2(sheet.get_width()/4.0,sheet.get_height()/3.0)
  for y in 3:
   var row=[]
   for x in 4:
    var frame=AtlasTexture.new()
    frame.atlas=sheet;frame.region=Rect2(Vector2(x,y)*cell_size,cell_size);frame.filter_clip=true
    row.append(frame)
   swim_frames.append(row)
 var row=0 if facing in [1,2] else (1 if facing==0 else 2)
 var frame=mini(3,int(fposmod(swim_phase,TAU)*4.0/TAU)) if moving else 3
 var anchor=[Vector2(202,304),Vector2(185,291),Vector2(183,295)][row]
 portrait.texture=swim_frames[row][frame]
 portrait.flip_h=facing==1
 if portrait.flip_h:anchor.x=portrait.texture.get_width()-anchor.x
 portrait.scale=Vector2.ONE*.178
 portrait.position=-anchor*.178+Vector2(0,floor(sin(swim_phase)*1.7))

func water_at(p:Vector2)->bool:
 if map_id=="village":return qingxi.wade_at(p)
 if map_id!="ranch" or region==null:return false
 if Rect2(1740,1565,150,40).has_point(p):return false
 return region.data.creek_clearance(p)<1.0

func can_swim_at(p:Vector2)->bool:
 if map_id=="village" or region==null:return false
 var here=region.cell_of(p)
 for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.UP,-Vector2i.ONE]:
  var corner=here+offset
  if region.cell_water(corner) and region.cell_water(corner+Vector2i.RIGHT) and region.cell_water(corner+Vector2i.DOWN) and region.cell_water(corner+Vector2i.ONE):return true
 return false

func update_swim(dt:float,moving:bool):
 if not is_instance_valid(player) or not is_instance_valid(portrait):return
 var was_wet=water_contact
 water_contact=water_at(player.position)
 if not water_contact:
  if was_wet:
   portrait.material.set_shader_parameter("swim_waterline",100000.0)
   if is_instance_valid(swim_surface):swim_surface.hide()
   contact_shadow.show()
  swimming=false;return
 if not is_instance_valid(swim_surface):
  swim_surface=preload("res://qingxi-live/village-center/swim_surface.gd").new()
  player.add_child(swim_surface)
  player.move_child(swim_surface,1)
 swim_surface.show()
 swimming=can_swim_at(player.position)
 swim_phase+=dt*(8.5 if moving else 2.5)
 if swimming:show_swim(moving)
 else:portrait.position.y+=3
 portrait.material.set_shader_parameter("swim_waterline",player.global_position.y+2.0)
 contact_shadow.hide()
 swim_surface.axis=facing_vector()
 swim_surface.phase=swim_phase
 swim_surface.scale=Vector2.ONE*(1.0 if swimming else .58)
 swim_surface.moving=swimming and moving
 swim_surface.queue_redraw()

func _physics_process(dt):
 if rooms and rooms.owner_bed!="" and is_instance_valid(player):
  player.hide()
  update_camera()
  state_tick+=dt
  if state_tick>=.5:
   state_tick=0;sim.settle();set_light(sky_value())
  return
 var time_host=get_tree().get_meta("qingxi_world_host",false)
 if time_host:center_hour=time_host.local_hour()   # 2026-11-19 Claude: Cabin World's clock (calendar from its date)
 elif center_cycle and light_preset==4:
  var before_hour=center_hour
  center_hour=fposmod(center_hour+dt*.1,24.0)
  if center_hour<before_hour:next_day()   # 2026-11-19 Claude: passed midnight (seasons.gd)
 if map_id=="village" and district!=null and district.seat>=0:
  elapsed+=dt
  if [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT].any(func(key):return Input.is_physical_key_pressed(key)):district.stand()
  else:
   # 2026-11-19 Claude: the world keeps living while the owner sits on a bench
   # (团团 walk on, crops and clock settle); before, this early return froze them.
   state_tick+=dt;save_tick+=dt
   if state_tick>=0.5:sim.settle();refresh_life();set_light(sky_value());state_tick=0
   if save_tick>=10:save_progress();save_tick=0
   villagers.tick(dt);herd_ai.pets_tick(dt)
   district.pose();district.tick();update_hud();return
 var before=player.position if is_instance_valid(player) else Vector2.ZERO
 super._physics_process(dt)
 var hover=mouse_plot()   # 2026-11-19 Claude: plot under the cursor wins when in reach
 if hover>=0 and hover!=selected_cell:selected_cell=hover;queue_redraw()
 if is_instance_valid(player):
  var traveled=player.position.distance_to(before)
  update_swim(dt,traveled>.05)
  footsteps(traveled)   # 2026-11-19 Claude: also while wading (water step sound)
 if map_id=="village" and district!=null:
  district.tick();district.dance_player(dt)
 if map_id=="barn":herd_ai.tick(dt)
 elif map_id!="ranch":herd_ai.pets_tick(dt)

## 2026-11-19 Claude: calendar (seasons.gd). The day count lives in the save.
const Seasons=preload("res://qingxi-live/village-center/seasons.gd")
func calendar_day()->int:return int(Seasons.calendar(sim.data).day)
## Inside Cabin World the season and date are Cabin World's (the real date); standalone keeps its own calendar.
func time_host():return get_tree().get_meta("qingxi_world_host",false)
func season()->int:return time_host().season_index() if time_host() else Seasons.season(calendar_day())
func season_progress()->float:return time_host().season_progress() if time_host() else Seasons.progress(calendar_day(),center_hour)
func season_label()->String:return time_host().date_label() if time_host() else Seasons.label(calendar_day())
func next_day(days:=1):
 var before=season()
 Seasons.calendar(sim.data).day=calendar_day()+days
 if season()!=before:notify("%s到了"%Seasons.LONG[season()])
 if is_instance_valid(paddies):paddies.season_changed()
var paddies   # 2026-11-19 Claude: the village rice paddies (paddies.gd), village map only
## Markers for the minimap and the M map: [{"pos","label","color"}].
func map_markers()->Array:
 var list=[]
 if map_id=="village" and is_instance_valid(paddies):list.append_array(paddies.markers())
 return list

func travel(id:String):
 if id=="pond":transition_pending=false;return
 var host=get_tree().get_meta("qingxi_world_host",false)
 if host and not host.controls(self):transition_pending=false;return
 _travel_to(id)

func observer_tab_destination(id:String):
 if transition_pending or id not in ["village","meadow","seedshop","livestockshop"]:return
 close_menu()
 _travel_to(id)

func _travel_to(id:String):
 if id==map_id:transition_pending=false;return
 if id not in INTERIORS and id!="meadow" and not MapLoading.quiet(get_tree()) and not MapLoading.loading(get_tree()):
  transition_pending=true
  await MapLoading.rebuild(get_tree(),MAP_NAMES.get(id,"小屋世界"),_travel_to.bind(id))
  transition_pending=false
  return
 var floor_to=barn_level(id)
 var floor_from=barn_level(map_id)
 if floor_to>1 or (floor_to==1 and floor_from>1):
  if abs(floor_to-floor_from)!=1 or floor_from==0 or not barn_stairs.has_connection(id):
   transition_pending=false;return
  var up=floor_to>floor_from
  sim.settle();build_map(id,Vector2(-1,-1) if up else Vector2(-2,-2));close_menu()
  if up and placement.plan.tiles.is_empty():notify("按 G 用木地板或石砖铺这一层")
  save_progress();return
 if id=="meadow":
  close_menu()
  save_progress()
  get_tree().set_meta("enter_meadow_from_village",true)
  get_tree().set_meta("meadow_via_gate",true)   # 2026-11-19 Claude: arrive on the farm's village lane
  if await MapLoading.change(get_tree(),"res://qingxi-live/village-center/flat-build/meadow.tscn","自家农场")!=OK:
   get_tree().remove_meta("enter_meadow_from_village")
   get_tree().remove_meta("meadow_via_gate")
   transition_pending=false
   notify("自家农场加载失败")
  return
 if id=="country_home":id="room_private"
 # Shops are their own scenes (original seed shop; livestock shop built on it).
 if id in INTERIORS:
  if transition_pending and get_tree().has_meta("rural_handoff"):return
  transition_pending=true;save_progress()
  get_tree().set_meta("center_hour",sky_value()*24.0);get_tree().set_meta("center_cycle",center_cycle and light_preset==4)
  SESSION.publish(get_tree(),sim,"village")
  if await MapLoading.change(get_tree(),"res://qingxi-live/village-center/"+id+".tscn",MAP_NAMES[id])!=OK:
   get_tree().remove_meta("rural_handoff");transition_pending=false;notify("商店加载失败")
  return
 # The cottage and the field are one map now: "home" (village south road, or
 # leaving the cottage interior) lands on the farm.
 if id=="home" or id in REGIONS or floor_to==1:
  var to="field" if id=="home" else id
  sim.settle()
  var from="room_private" if map_id=="room_private" else ("home" if id=="home" and map_id=="village" else map_id)
  build_map(to,region_arrival(to,from));close_menu();save_progress();return
 if id=="village":
  var arrival=CENTER_START
  var from=map_id
  for link in LINKS.village:
   if link[0]==from:arrival=link[1]+(Vector2(0,50) if from.begins_with("resident_") or from in ["village_bath","village_store"] else (CENTER_START-link[1]).normalized()*60)
  build_map(id,arrival);close_menu();save_progress();return
 super.travel(id)

## Map: one button per place, the current one marked; music credit in small print.
func map_destination()->String:
 return map_id if not rooms.contains(map_id) and not is_barn_floor() else ""

func open_map_destination(id:String):
 close_menu()
 if id!=map_destination():travel.call_deferred(id)

func show_map():
 open_menu="map";clear_menu("清溪村地图","map")
 var grid=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",6);overlay_body.add_child(grid)
 var places=["village","seedshop","livestockshop","meadow"]
 if legacy_split_maps and not get_meta("open_meadow",false):places.append_array(REGIONS)
 var current=map_destination()
 for id in places:
  var target_id:String=id
  var here=id==current
  var name_="自家农场" if id=="meadow" else str(MAP_NAMES[id])
  var b=KIT.button(name_,func():open_map_destination(target_id),here)
  b.custom_minimum_size=Vector2(124,30)
  if here:b.icon=KIT.icon_texture("pin")
  b.pressed.connect(func():if audio:audio.sfx("ui_click",-10))
  grid.add_child(b)
 if is_instance_valid(ui):ui.add_expanded_map(overlay_body)
 var credit=KIT.label("音乐 · Apple Cider、Shepherd Dog（Zane Little Music，CC0）\n\"Cozy Music Sampler\" by Spaceyyy（aquumgifts.itch.io，CC-BY 4.0）",9,KIT.INK2)
 overlay_body.add_child(credit)

func save_progress():
 if testing or bool(get_tree().get_meta("center_testing",false)):return
 sim.settle()
 if not sim.save_to(qingxi_save_path(CONNECTED_SAVE)):notify("清溪村存档保存失败")

const Loft=preload("res://qingxi-live/dorm_loft.gd")
const Bath=preload("res://qingxi-live/village-center/village_bath.gd")
const Store=preload("res://qingxi-live/village-center/village_store.gd")
func blocked(p:Vector2)->bool:
 if map_id=="village_bath":return Bath.blocks(p)
 if map_id=="village_store":return Store.blocks(p,solids)
 if map_id=="room_private_dorm":
  for offset in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
   if not Loft.inside(p+offset*6):return true
  for solid in solids:
   if solid.grow(6).has_point(p):return true
  return false
 if super.blocked(p):return true
 if barn_level(map_id)>1 and is_instance_valid(placement) and is_instance_valid(barn_stairs):
  return not (barn_stairs.walkable(p) or placement.supports(Grid.cell(p)))
 if region!=null and map_id==region.id:return map_id!="ranch" and region.data!=null and region.data.water_blocks(p)
 return map_id=="village" and ((qingxi.water_blocks(p) and not qingxi.wade_at(p)) or (district!=null and district.works_block(p)))

var cottage_camera_id:=0
var cottage_camera_room:=""
var cottage_panning:=false
var cottage_focus:=Vector2.ZERO
var cottage_feet:=Vector2.ZERO

func room_camera_area()->Rect2:
 return Loft.SHELL if map_id=="room_private_dorm" else Rect2(228,164,824,578)

func update_camera(instant=false):
 var host=time_host()
 if not instant and host and host.active and host.spectator and host.scene==self:return
 if rooms==null or not rooms.private_room(map_id):
  cottage_camera_room=""
  super.update_camera(instant)
  return
 var area:=room_camera_area()
 if cottage_camera_id!=camera.get_instance_id() or cottage_camera_room!=map_id:
  cottage_camera_id=camera.get_instance_id()
  cottage_camera_room=map_id
  cottage_panning=false
  camera.zoom=Vector2.ONE
  instant=true
 if player.position.distance_to(cottage_feet)>1:cottage_panning=false
 cottage_feet=player.position
 var extent:Vector2=get_viewport_rect().size/camera.zoom
 var frame:=Rect2(area.get_center()-area.size.max(extent)*.5,area.size.max(extent))
 var half:=extent*.5
 var focus:Vector2=cottage_focus if cottage_panning else player.position-Vector2(0,22)
 var target:=focus.clamp(frame.position+half,frame.end-half)
 if cottage_panning:cottage_focus=target
 camera.limit_left=floori(frame.position.x);camera.limit_top=floori(frame.position.y)
 camera.limit_right=ceili(frame.end.x);camera.limit_bottom=ceili(frame.end.y)
 camera.position=target if instant or cottage_panning else camera.position.lerp(target,.2)
 camera.enabled=true
 if not camera.is_current():camera.make_current()
 camera.force_update_scroll()

func room_camera_input(event)->bool:
 if not (event is InputEventMouse) or build_mode or overlay.visible or not owner_controls():return false
 if rooms==null or not rooms.private_room(map_id):return false
 if event is InputEventMouseMotion and event.button_mask & (MOUSE_BUTTON_MASK_LEFT|MOUSE_BUTTON_MASK_MIDDLE|MOUSE_BUTTON_MASK_RIGHT):
  if not cottage_panning:cottage_focus=camera.get_screen_center_position()
  cottage_focus-=event.relative/camera.zoom
  cottage_panning=true
 elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
  var area:=room_camera_area()
  var fit:Vector2=get_viewport_rect().size/area.size
  var factor:=1.16 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.16
  camera.zoom=Vector2.ONE*clampf(camera.zoom.x*factor,minf(1,minf(fit.x,fit.y)),2.4)
 else:return false
 update_camera(true)
 get_viewport().set_input_as_handled()
 return true

func camera_lead()->float:
 if build_mode and (is_barn_floor() or rooms.contains(map_id)):return 30.0
 return super.camera_lead()

func floor_height(p:Vector2)->float:
 if is_instance_valid(barn_stairs):return barn_stairs.elevation(p)
 return 0.0 if map_id=="village" else super.floor_height(p)

func show_mill():
 open_menu="mill";clear_menu("水车磨坊")
 for output in sim.MILL_INPUT:
  var product=str(output)
  var parts=[]
  var enough=true
  for item in sim.MILL_INPUT[product]:
   var required=int(sim.MILL_INPUT[product][item])
   parts.append("%s ×%d" % [StateModel.ITEM_NAMES[item],required])
   if int(sim.data.bag.get(item,0))<required:enough=false
  var b=button("%s → %s ×1" % [" + ".join(parts),StateModel.ITEM_NAMES[product]],func():perform(sim.mill_feed(product));show_mill())
  b.disabled=not enough;overlay_body.add_child(b)
 menu_line("随身原料 · 白菜 %d  小麦 %d" % [sim.data.bag.veg,sim.data.bag.wheat])

func show_shipping():
 open_menu="shipping";clear_menu("农场出货箱")
 menu_line("零钱 %d 币" % sim.data.coins)
 var listed=false
 for item in sim.data.bag:
  var key=str(item);var count=int(sim.data.bag[key]);var price=sim.shipping_price(key)
  if count<=0 or price<=0:continue
  listed=true
  menu_line("%s ×%d · 每件 %d 币" % [sim.goods_name(key),count,price])
  var row=HBoxContainer.new();overlay_body.add_child(row)
  row.add_child(button("卖 1 件",func():perform(sim.ship_goods(key,1));show_shipping()))
  if count>1:row.add_child(button("卖这批 · %d 币" % (count*price),func():perform(sim.ship_goods(key,count));show_shipping()))
 if not listed:menu_line("可以在这里卖白菜、蜂蜜、鱼和畜产。")

func interact():
 if rooms and rooms.owner_bed!="":rooms.leave_bed();return
 if not overlay.visible and not build_mode and action_target.get("kind","")=="pond":
  return
 if overlay.visible or transition_pending or build_mode:return
 if map_id=="village" and district.dancing:district.toggle_dance();return
 var doorway=stair_in_reach()
 if not doorway.is_empty():
  transition_pending=true;travel.call_deferred(str(doorway.extra));return
 # 2026-11-19 Claude: E in front of any door enters / leaves (a plot under the feet wins
 # unless the player is right at the door).
 var door=door_in_reach()
 if not door.is_empty() and door_wins(door):
  transition_pending=true
  if audio:audio.sfx("door",-12)
  travel.call_deferred(str(door.extra));return
 if selected_cell>=0 and selected_cell<fields.size():handle_garden_plot(selected_cell);return
 if selected_cell<0 and not action_target.is_empty():
  match str(action_target.kind):
   "furniture":
    if action_target.extra=="shared_chest":show_shared_chest();return
   "shop_shelf":Store.open_shelf(self,action_target);return
   "river_fishing":cast_line({},Callable());return
   "pet":show_pet(str(action_target.extra));return   # 2026-11-21 pets: 农场上的猫和狗
   "pet_adopt":show_pet_adopt();return               # 2026-11-21 pets: 宠物角 · 领养
   "note":notify(str(action_target.extra));return
   "ship":show_shipping();return
   "well":perform(sim.fill_can());return
   "hive":perform(sim.take_honey(str(action_target.extra)));return
   "dry_fish":perform(sim.dry_fish(str(action_target.extra)));return
   "portal":
    if action_target.has("approach"):return
 if map_id=="village" and not action_target.is_empty():
  if action_target.kind=="cabin_bus":
   var host=get_tree().get_meta("qingxi_world_host",false)
   if host:host.owner_bus_home()
   return
  var kind=str(action_target.kind);var extra=str(action_target.get("extra",""))
  if kind=="paddy" and is_instance_valid(paddies):notify(paddies.talk(extra));return   # 2026-11-19 Claude
  if kind.begins_with("qingxi_"):district.interact(kind,extra);return
  if kind=="facility":
   if extra=="watermill":show_mill();return
   if extra=="well":perform(sim.fill_can());return
   clear_menu(str(action_target.name))
   match extra:
    "fire_tower":menu_line("望火台 · 傍晚会敲响钟声。")
    "board","community_hall":menu_line("清溪村 · 西街通往自家农场。\n农田、小屋、牧场和鱼塘都在同一片地里。" if not legacy_split_maps else "清溪村 · 西街通农田。")
    "mail":menu_line("村邮筒 · 今天还没有新来信。")
    "shrine":menu_line("稻荷小祠 · 沿参道上山，神社院落可散步。")
    "jizo":menu_line("桥边的地藏，守着往来的村民。")
    _:menu_line("院子里晾着衣服，屋里飘出饭香。")
   return
 super.interact()

func capture_center():
 paused_for_capture=true;light_preset=4;center_cycle=false
 var shots=[{"p":Vector2(1815,1530),"hour":12.0,"name":"qingxi-plaza-day"},{"p":Vector2(1815,1530),"hour":21.0,"name":"qingxi-plaza-night"},{"p":Vector2(760,1500),"hour":12.0,"name":"qingxi-west-street"},{"p":Vector2(2660,1500),"hour":12.0,"name":"qingxi-stone-bridge"},{"p":Vector2(1900,960),"hour":12.0,"name":"qingxi-homes"},{"p":Vector2(3700,1600),"hour":12.0,"name":"qingxi-livestock-shop"},{"p":Vector2(3150,1560),"hour":12.0,"name":"qingxi-bridge-east"}]
 # Time-of-day sweep over the plaza and the west street.
 for pair in [[5.8,"dawn"],[6.6,"sunrise"],[8.5,"morning"],[12.5,"noon"],[15.5,"afternoon"],[17.4,"golden"],[18.4,"dusk"],[19.6,"bluehour"],[21.0,"night"],[2.5,"smallhours"]]:
  shots.append({"p":Vector2(1700,1580),"hour":pair[0],"name":"light-plaza-"+pair[1]})
 for pair in [[8.5,"morning"],[17.4,"golden"],[21.0,"night"]]:
  shots.append({"p":Vector2(760,1500),"hour":pair[0],"name":"light-street-"+pair[1]})
 for shot in shots:
  player.position=shot.p;center_hour=shot.hour;show_idle();set_light(sky_value());district.tick();update_camera(true);update_hud()
  await get_tree().process_frame;district.tick();lighting.update_lights();await get_tree().process_frame;await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/village-center/reports/"+shot.name+".png"))
 # UI: prompt near a bench, the bag, the help card.
 player.position=district.benches[0]+Vector2(0,40);center_hour=12;set_light(sky_value());update_camera(true);selected_cell=-1
 action_target={"kind":"qingxi_bench","pos":district.benches[0],"name":"长凳 · 坐下","extra":"0"};ui.refresh(0.1);notify("收获白菜 ×2、种子 ×1；可以卖菜或回家做饭")
 for i in 12:await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/village-center/reports/ui-hud.png"))
 sim.data.bag.meal=2;show_bag()
 for i in 30:await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/village-center/reports/ui-bag.png"))
 show_help()
 for i in 20:await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/village-center/reports/ui-help.png"));close_menu()
 player.position=district.benches[0]+Vector2(0,36);district.sit(0);center_hour=12;set_light(sky_value());district.tick();update_camera(true)
 await get_tree().process_frame;await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/village-center/reports/qingxi-seat.png"));district.stand()
 hud.hide();center_hour=12;set_light(sky_value());district.tick()
 get_tree().root.content_scale_size=Vector2i(2400,1680);get_window().size=Vector2i(2400,1680)
 camera.zoom=Vector2.ONE*.5;camera.position=Vector2(2400,1680);camera.force_update_scroll()
 await get_tree().process_frame;await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/village-center/reports/qingxi-overview.png"))
 print("QINGXI_CAPTURE_PASS");get_tree().quit()

## --capture-regions: close-ups (noon / dusk / night) and a full overview of each outer map.
func capture_regions():
 paused_for_capture=true;light_preset=4;center_cycle=false
 var spots={
  "field":[[1200,900,"cottage"],[1200,1250,"field"],[1800,1050,"well"],[2200,1000,"bridge"]],
  "ranch":[[910,1000,"barn"],[1760,1050,"sheep"],[1780,1250,"pigs"],[700,1100,"windmill"]],
  "pond":[[1150,1150,"dock"],[1700,1200,"shop"],[600,1180,"bridge"],[900,700,"water"]]}
 for id in spots:
  build_map(id)
  for s in spots[id]:
   for hour in [12.5,17.6,21.0]:
    if hour!=12.5 and s!=spots[id][0]:continue
    player.position=Vector2(s[0],s[1]);center_hour=hour;show_idle();set_light(sky_value());update_camera(true);update_hud()
    await get_tree().process_frame;lighting.update_lights();await get_tree().process_frame;await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/village-center/reports/region-%s-%s-%d.png"%[id,s[2],int(hour)]))
 hud.hide()
 for id in spots:
  build_map(id);center_hour=12.5;set_light(sky_value())
  var s=region.size()
  get_tree().root.content_scale_size=Vector2i(s/2);get_window().size=Vector2i(s/2)
  camera.zoom=Vector2.ONE*.5;camera.limit_right=int(s.x);camera.limit_bottom=int(s.y);camera.position=s/2;camera.force_update_scroll()
  await get_tree().process_frame;lighting.update_lights();await get_tree().process_frame;await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/village-center/reports/region-%s-overview.png"%id))
 print("REGION_CAPTURE_PASS");get_tree().quit()

class FloatView extends Control:
 var cast_at:float
 var delay:float
 func _process(_dt):queue_redraw()
 func _draw():
  var t=Time.get_ticks_msec()/1000.0-cast_at
  draw_rect(Rect2(Vector2.ZERO,size),Color("#345d66"))
  for i in 4:
   var pos=Vector2(fmod(i*79.0+t*5,size.x+20)-15,13+fmod(i*13,32))
   draw_line(pos,pos+Vector2(16,0),Color("#60868a"),1)
  var bite=t>=delay
  var pos=Vector2(size.x*.54,24+sin(t*3)*2+(12+sin(t*16)*3 if bite else 0))
  draw_line(Vector2(0,2),pos,Color("#d3d9b8"),1)
  draw_arc(pos+Vector2(0,7),7+fmod(t*8,8),0,TAU,24,Color(.75,.93,.91,.45),1)
  draw_rect(Rect2(pos+Vector2(-2,-7),Vector2(5,8)),Color("#e77d62"))
  draw_rect(Rect2(pos+Vector2(-2,1),Vector2(5,6)),Color("#fff2c7"))
var rod_started:float
var rod_delay:float
var rod_ticket:int

func show_fish_pond(p:Dictionary,refresh:Callable=Callable()):
 if not get_meta("open_meadow",false) or map_id!="ranch" or not sim.is_home_pond(p):return
 open_menu="pond"
 clear_menu("鱼塘 · 水边")
 var pond_ui=preload("res://core/pond_interaction.gd")
 var choices=pond_ui.menu(sim,p)
 menu_line(choices.summary)
 for key in choices.buttons:
  var title=pond_ui.LABELS[key]
  match key:
   "restock":
    for item in sim.live_catches():
     menu_button("放养 "+sim.Fish.label(item)+" ×"+str(sim.data.bag[item]),func():perform(sim.restock(p,item));save_progress();refresh_pond_view(p,refresh))
   "stock_fry":menu_button(title,func():perform(sim.stock_fry(p));save_progress();refresh_pond_view(p,refresh))
   "feed_fish":menu_button(title,func():perform(sim.tend_pond(p));save_progress();refresh_pond_view(p,refresh))
   "fish":menu_button(title,func():cast_line(p,refresh))
   "harvest_fish":menu_button(title,func():perform(sim.harvest_pond(p));save_progress();refresh_pond_view(p,refresh))

func refresh_pond_view(p:Dictionary,refresh:Callable):
 if refresh.is_valid():refresh.call()
 show_fish_pond(p,refresh)

func cast_line(p:Dictionary,refresh:Callable):
 rod_ticket+=1
 var ticket=rod_ticket
 rod_started=Time.get_ticks_msec()/1000.0
 rod_delay=sim.Fish.bite_delay()
 open_menu="rod"
 clear_menu("垂钓")
 var float_view=FloatView.new()
 float_view.custom_minimum_size=Vector2(260,52)
 float_view.cast_at=rod_started;float_view.delay=rod_delay;float_view.mouse_filter=Control.MOUSE_FILTER_IGNORE
 overlay_body.add_child(float_view)
 var notice=KIT.label("○  浮漂在水面轻轻晃动……",16,KIT.INK2)
 overlay_body.add_child(notice)
 menu_line("浮漂沉下时收竿。过早提竿或错过鱼讯，鱼都会游走。")
 menu_button("提竿",func():reel_line(p,refresh))
 var reel_button=overlay_body.get_child(-1)
 if reel_button is BaseButton:reel_button.grab_focus()
 await get_tree().create_timer(rod_delay).timeout
 if not is_instance_valid(notice) or open_menu!="rod" or ticket!=rod_ticket:return
 notice.text="▼  浮漂沉下去了！现在提竿！"
 if audio:audio.sfx("splash",-8)
 await get_tree().create_timer(sim.Fish.BITE_WINDOW).timeout
 if is_instance_valid(notice) and open_menu=="rod" and ticket==rod_ticket:reel_line(p,refresh)

func reel_line(p:Dictionary,refresh:Callable):
 if open_menu!="rod":return
 rod_ticket+=1
 var t=Time.get_ticks_msec()/1000.0-rod_started
 var key=(sim.wild_catch() if p.is_empty() and map_id=="village" else sim.catch_fish(p)) if sim.Fish.hooked(t,rod_delay) else ""
 if refresh.is_valid():refresh.call()
 open_menu="rod_result"
 clear_menu("起竿")
 if key=="":
  menu_line("提早了，鱼还没咬钩。" if t<rod_delay else "鱼游走了。")
 else:
  save_progress()
  var im=Image.load_from_file(sim.Fish.DIR+"art/pond-fish/"+key.get_slice(":",1)+".png")
  if im!=null and not im.is_empty():
   var picture=TextureRect.new()
   picture.texture=ImageTexture.create_from_image(im);picture.custom_minimum_size=Vector2(100,60)
   picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;overlay_body.add_child(picture)
  menu_line("钓到了%s！"%sim.goods_name(key))
  menu_button("带走 · 可放养或做菜",close_menu)
  menu_button("卖掉 · %d 币"%sim.shipping_price(key),func():perform(sim.ship_goods(key,1));save_progress();close_menu())
 menu_button("再钓一竿",func():cast_line(p,refresh)) if p.is_empty() else menu_button("返回鱼塘",func():show_fish_pond(p,refresh))

func make_actor():
 super.make_actor()
 var host=get_tree().get_meta("qingxi_world_host",false)
 if host and host.spectator:player.hide()
