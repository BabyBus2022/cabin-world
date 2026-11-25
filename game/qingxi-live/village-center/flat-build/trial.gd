extends "res://qingxi-live/village-center/center.gd"
const Cottage=preload("res://qingxi-live/village-center/flat-build/cottage.gd")
const TRIAL_SAVE="user://flat-building-trial.json"
@export var open_meadow=false
const MEADOW_SAVE=PastureState.MEADOW_SAVE
var bridges
var bridge_direction=0
var erase_drag=""
var seated=false
var stand_point=Vector2.ZERO
var ground_tiles
var brush={}
var brush_last=Vector2i.ZERO
var brush_origin=Vector2i.ZERO
var brush_tool=""
var walk_zoom=Vector2.ONE
const WORKSITES=["field","ranch"]
var cottage
var waters={}
var stroke=""
var last_piece=""
var player_moving=false   # 2026-11-19 Claude: true only inside move_actor (player may swim in deep water)
var arrive_at_gate=false   # 2026-11-19 Claude: walked in from the village -> start on the gate lane

func _ready():
 legacy_split_maps=true
 set_meta("open_meadow",open_meadow)
 var via_village=open_meadow and bool(get_tree().get_meta("enter_meadow_from_village",false))
 if via_village:get_tree().remove_meta("enter_meadow_from_village")
 # 2026-11-19 Claude: only the walk from the village starts on the gate lane (not shop returns).
 arrive_at_gate=open_meadow and bool(get_tree().get_meta("meadow_via_gate",false))
 if get_tree().has_meta("meadow_via_gate"):get_tree().remove_meta("meadow_via_gate")
 var initial=PastureState.new()
 var loaded=open_meadow and SESSION.consume(get_tree(),initial)
 if not loaded and not ("--verify-center" in OS.get_cmdline_user_args()):loaded=initial.load_from(qingxi_save_path(MEADOW_SAVE if open_meadow else TRIAL_SAVE))
 if not loaded:
  initial.supplies()
  if open_meadow:
   initial.livestock.data.herd.clear()
   for kind in ["cow","sheep","chicken","pig"]:initial.data.bag[Book.young_key(kind,0,"f")]=1
  initial.data.bag.feeder_cow=8
 var start=str(initial.data.map)
 if open_meadow:start="ranch"
 SESSION.publish(get_tree(),initial,start if start in WORKSITES else "field")
 super._ready()
 if not get_tree().has_meta("qingxi_world_host"):DisplayServer.window_set_title("清溪村 · 平面搭建试玩")   # 2026-11-19 Claude (Cabin World host): inside Cabin World this would touch the whole app
 if open_meadow:
  MAP_NAMES.ranch="自家农场" if via_village else "自由地块"
  if not get_tree().has_meta("qingxi_world_host"):DisplayServer.window_set_title("清溪村 · "+MAP_NAMES.ranch)   # 2026-11-19 Claude (Cabin World host): inside Cabin World this would touch the whole app
  notify("按 G 进入格子编辑")
 elif not build_mode:toggle_build()

func save_progress():
 if testing or bool(get_tree().get_meta("center_testing",false)):return
 sim.settle()
 if open_meadow and map_id=="ranch" and is_instance_valid(player) and region!=null:
  var p=stand_point if seated else player.position
  if region.near_meadow_exit(p,0.0):p=region.meadow_gate_arrival()   # 2026-11-19 Claude: never save a spot that walks straight out
  region.saved().meadow_arrival=[p.x,p.y]
 if not sim.save_to(qingxi_save_path(MEADOW_SAVE if open_meadow else TRIAL_SAVE)):notify("搭建存档写入失败")

func travel(id:String):
 var host=get_tree().get_meta("qingxi_world_host",false)
 if host and not host.controls(self):transition_pending=false;return
 if open_meadow and (id=="room_private" or (id=="home" and map_id=="room_private")) and not MapLoading.quiet(get_tree()) and not MapLoading.loading(get_tree()):
  transition_pending=true
  await MapLoading.rebuild(get_tree(),"私人小屋" if id=="room_private" else "自家农场",travel.bind(id))
  transition_pending=false
  return
 if open_meadow and id=="room_private" and region!=null and region.saved().has("meadow_house"):
  seated=false;build_mode=false;build_map(id,Rooms.ENTRY-Vector2(0,55));close_menu();save_progress();return
 if open_meadow and id=="home" and map_id=="room_private":
  var door=sim.data.layout.meadow_house
  build_region("ranch",Vector2(door[0],door[1])+Vector2(0,54));close_menu();save_progress();return
 if open_meadow and id in ["room_private","room_private_up"] and rooms.contains(map_id):
  super.travel(id);return
 if open_meadow and id!="ranch" and barn_level(id)==0:
  show_map();return
 if id in WORKSITES or barn_level(id)>0:
  super.travel(id)
 else:
  transition_pending=false;portal_grace=.6;show_map()

func map_destination()->String:
 return "meadow" if open_meadow else super.map_destination()

func open_map_destination(id:String):
 if not open_meadow:
  super.open_map_destination(id);return
 close_menu()
 if id=="village":return_to_village()
 elif id in INTERIORS:leave_for_shop.call_deferred(id)

func observer_tab_destination(id:String):
 if not open_meadow:
  super.observer_tab_destination(id);return
 if transition_pending:return
 close_menu()
 if id=="village":_depart_for_village()
 elif id in INTERIORS:_depart_for_shop(id)

func show_map():
 if open_meadow:
  super.show_map();return
 open_menu="map";clear_menu("选择搭建地点","map")
 for site in WORKSITES:
  var destination:String=site
  menu_button(str(MAP_NAMES[site]),func():close_menu();travel(destination))

func leave_for_shop(id:String):
 var host=get_tree().get_meta("qingxi_world_host",false)
 if transition_pending or (host and not host.controls(self)):return
 _depart_for_shop(id)

func _depart_for_shop(id:String):
 transition_pending=true
 save_progress()
 get_tree().set_meta("return_shop_to_meadow",MAP_NAMES.ranch=="自家农场")
 SESSION.publish(get_tree(),sim,"ranch")
 get_tree().set_meta("center_hour",sky_value()*24.0)
 get_tree().set_meta("center_cycle",center_cycle and light_preset==4)
 if await MapLoading.change(get_tree(),"res://qingxi-live/village-center/"+id+".tscn",MAP_NAMES[id])!=OK:
  get_tree().remove_meta("rural_handoff")
  get_tree().remove_meta("return_shop_to_meadow")
  transition_pending=false
  notify("商店加载失败")

func return_to_village():
 var host=get_tree().get_meta("qingxi_world_host",false)
 if host and not host.controls(self):return
 _depart_for_village()

func _depart_for_village():
 save_progress()
 get_tree().set_meta("center_hour",sky_value()*24.0)
 get_tree().set_meta("center_cycle",center_cycle and light_preset==4)
 if MAP_NAMES.ranch=="自家农场":get_tree().set_meta("meadow_return",true)
 transition_pending=true
 MapLoading.change.call_deferred(get_tree(),"res://qingxi-live/village-center/main.tscn","清溪村")

func region_arrival(to:String,from:String)->Vector2:
 if open_meadow and to=="ranch":
  var barn:Dictionary=sim.data.get("layout",{}).get("meadow_barn",{})
  if not barn.is_empty():return Vector2(barn.door[0],barn.door[1])+Vector2(0,64)
  return Vector2(1440,1008)
 return super.region_arrival(to,from)

func build_region(id:String,arrival:Vector2):
 ground_tiles=null;bridges=null;seated=false;brush.clear();brush_tool=""
 cottage=null;waters.clear();stroke="";last_piece="";drag_from=null;build_mode=false
 super.build_region(id,arrival)
 if id=="field":
  cottage=Cottage.new();map_layer.add_child(cottage);cottage.setup(self)
  # Put the builder beside a usable 3-by-2 patch, even with existing farm furnishings.
  var last=region.saved().get("build_site",[])
  if last.size()==2:player.position=Vector2(last[0],last[1])
  else:
   var origin=Vector2(1280,1024)
   var best=INF
   for y in range(3,27):
    for x in range(3,39):
     var p=Vector2(x,y)*64
     if p.distance_to(origin)>=best:continue
     if land_clear(Rect2(p,Vector2(192,128)),false) and not blocked(p+Vector2(96,145)):
      player.position=p+Vector2(96,145);best=p.distance_to(origin)
   region.saved().build_site=[player.position.x,player.position.y]
 elif id=="ranch":
  if open_meadow:refresh_water()
  if open_meadow and id=="ranch":
   ground_tiles=preload("res://qingxi-live/village-center/flat-build/meadow_ground.gd").new()
   map_layer.add_child(ground_tiles);ground_tiles.setup(self)
   bridges=preload("res://qingxi-live/village-center/flat-build/bridges.gd").new();map_layer.add_child(bridges);bridges.setup(self)
  if id=="ranch":region.refresh_ranch()
 if open_meadow and id=="ranch":
  var previous=region.saved().get("meadow_arrival",[])
  if arrival==Vector2.ZERO and previous.size()==2:player.position=Vector2(previous[0],previous[1])
  if arrive_at_gate:arrive_at_gate=false;player.position=region.meadow_gate_arrival();facing=1
  if blocked(player.position):
   var best=INF;var origin=player.position
   for y in range(region.rows().x,region.rows().y):
    for x in range(region.cols().x,region.cols().y):
     var p=region.cell_rect(Vector2i(x,y)).get_center()
     if origin.distance_squared_to(p)<best and not blocked(p):player.position=p;best=origin.distance_squared_to(p)
 update_camera(true)

func meadow_catalog()->Array:
 var list=[["plot","田地"],["fence","围栏"],["gate","栅门"],["path","小路"],["channel","河道"],["bridge","木桥"],["barn_unit","牧场屋"],["house_unit","我的小屋"]]+RANCH_TOOLS.slice(2)
 for prop in ["lantern","bench","well","pump","shipping_bin","beehive","drying_rack","scarecrow","mailbox","signpost","watering_can","wheelbarrow","compost","haystack","haybale","milk_cans","barrel","crate","cart","rod_rack","laundry","silo","windmill"]:
  list.append(["prop:"+prop,region.PROP_NAMES[prop]])
 return list

func build_tools()->Array:
 var list=super.build_tools()
 if open_meadow and map_id=="ranch":return meadow_catalog()
 if map_id=="field":return [["floor","地板"],["wall","墙"],["door","门洞"]]+list
 return list

func pools()->Array:
 var layout=region.saved()
 if not layout.has("dug_ponds"):layout.dug_ponds={}
 if not layout.dug_ponds.has(map_id):layout.dug_ponds[map_id]=[]
 return layout.dug_ponds[map_id]

func footprint(pool:Dictionary)->Rect2:
 return Rect2(pool.x,pool.y,pool.w,pool.h)

func water_overlaps(rect:Rect2)->bool:
 for pool in pools():
  if footprint(pool).intersects(rect):return true
 return false

func dug_water(c:Vector2i)->bool:
 if open_meadow and map_id=="barn":
  var tiles:Dictionary=sim.data.get("layout",{}).get("meadow_ground",{}).get("cells",{})
  return tiles.get("%d:%d"%[c.x,c.y],"")=="channel"
 if map_id!="ranch" or region==null:return false
 if is_instance_valid(ground_tiles):return ground_tiles.cells.get(c,"")=="channel"
 var p=Vector2(c)*64+Vector2(32,32)
 for pool in pools():
  if footprint(pool).has_point(p):return true
 return false

func land_clear(rect:Rect2,keep_player:bool)->bool:
 if not world_bounds().grow(-36).encloses(rect):return false
 if region!=null and region.is_meadow() and region.MEADOW_EXIT_LANE.intersects(rect):return false   # 2026-11-19 Claude: keep the gate lane open
 if keep_player and rect.grow(10).has_point(player.position):return false
 for solid in solids:
  if solid.grow(3).intersects(rect):return false
 for field in fields:
  if field.rect.intersects(rect):return false
 for target in targets:
  if not str(target.kind) in ["animal","pen"] and rect.grow(18).has_point(target.pos):return false
 for y in range(int(rect.position.y)+4,int(rect.end.y),12):
  for x in range(int(rect.position.x)+4,int(rect.end.x),12):
   var p=Vector2(x,y)
   if region.data.water_blocks(p) or region.data.on_road(p,2):return false
   if map_id=="pond" and is_instance_valid(living_pond) and living_pond.blocks(p):return false
 if map_id=="ranch":
  for y in range(int(rect.position.y/64),ceili(rect.end.y/64)):
   for x in range(int(rect.position.x/64),ceili(rect.end.x/64)):
    var c=Vector2i(x,y)
    if not region.in_zone_cell(c) or region.barn_cell(c) or c==region.passage() or region.feeder_at(c)>=0:return false
  for edge in region.ranch().edges:
   if rect.grow(-4).has_point(region.edge_mid(edge)):return false
  for actor in herd_ai.actors.values():
   if actor.get("barn","out")=="out" and is_instance_valid(actor.node) and rect.grow(12).has_point(actor.node.position):return false
 return true

func pond_box(a:Vector2,b:Vector2)->Rect2:
 var first=(a/64).floor()*64;var last=(b/64).floor()*64
 return Rect2(first.min(last),(first-last).abs()+Vector2(64,64))

func water_error(r:Rect2)->String:
 if r.size.x<128 or r.size.y<128:return "拖出至少两格宽、两格深的水面"
 if not land_clear(r,true):return "池塘需要连续的空地"
 for pool in pools():
  if footprint(pool).grow(18).intersects(r):return "两口塘之间要留出岸边"
 var bank=Vector2(r.get_center().x,r.end.y+9)
 if blocked(bank):return "南岸需要留出投喂的位置"
 return ""

func change_water(r:Rect2)->String:
 if not open_meadow or map_id!="ranch":return "只能在自家农场挖塘"
 var error=water_error(r)
 if error!="":return error
 pools().append({"x":r.position.x,"y":r.position.y,"w":r.size.x,"h":r.size.y,"stock":{"count":0,"progress":0.0,"feed":0.0}})
 sim.recover_ponds()
 refresh_water()
 if map_id=="ranch":region.refresh_ranch()
 save_progress();return "ok"

func fill_water(p:Vector2)->String:
 for pool in pools():
  if not footprint(pool).has_point(p):continue
  if int(pool.stock.count)>0:return "先捕完塘里的鱼，再填土"
  pools().erase(pool);refresh_water()
  if map_id=="ranch":region.refresh_ranch()
  save_progress();return "ok"
 return ""

func refresh_water():
 targets=targets.filter(func(t):return t.kind!="built_pond")
 for pond in waters.values():pond.hide();pond.queue_free()
 waters.clear()
 for pool in pools():
  var r=footprint(pool);var pond=preload("res://qingxi-live/living_pond.gd").new()
  var points=PackedVector2Array()
  for factor in [Vector2(.14,.06),Vector2(.53,.03),Vector2(.84,.05),Vector2(.96,.19),Vector2(.97,.65),Vector2(.91,.86),Vector2(.75,.95),Vector2(.45,.97),Vector2(.17,.94),Vector2(.04,.81),Vector2(.03,.36),Vector2(.06,.16)]:
   points.append((r.position+r.size*factor).snapped(Vector2(2,2)))
  pond.shore=points;pond.dock=Rect2();pond.stock=pool.stock;pond.bank_center=r.get_center()
  pond.interaction=Vector2(r.get_center().x,r.end.y+9)
  map_layer.add_child(pond);pond.setup(self)
  var id="%d:%d"%[int(pool.x),int(pool.y)];waters[id]=pond
  add_target("built_pond",pond.interaction,"塘边 · 放苗 / 投喂 / 捕捞",id)

func blocked(p:Vector2)->bool:
 return terrain_blocks(p,false)

func livestock_blocked(p:Vector2)->bool:
 return terrain_blocks(p,true)

func deep_for_herd(p:Vector2)->bool:
 if is_instance_valid(bridges) and bridges.underfoot(p)==1:return false
 if is_instance_valid(ground_tiles) and ground_tiles.cell_depth.get(Cottage.cell_of(p),0.)>.4:return true
 for pond in waters.values():
  if not pond.blocks(p):continue
  var shore=pond.shore
  for i in shore.size():
   if p.distance_squared_to(Geometry2D.get_closest_point_to_segment(p,shore[i],shore[(i+1)%shore.size()]))<=128.*128.:return false
  return true
 return false

func terrain_blocks(p:Vector2,herd:bool)->bool:
 if is_instance_valid(bridges):
  var on_bridge=bridges.underfoot(p)
  if on_bridge!=0:return on_bridge<0 or super.blocked(p)
 # 2026-11-19 Claude (round 2): the player swims in any water 2x2 or larger, deep fish
 # ponds included; deep water still stops animals, fences and placing things.
 if herd:
  if deep_for_herd(p):return true
 elif is_instance_valid(ground_tiles) and ground_tiles.deep.has(Cottage.cell_of(p)) and ground_tiles.covers(p,"channel") and not player_moving:return true
 if is_instance_valid(cottage) and cottage.blocks(p):return true
 if not herd:
  for pond in waters.values():
   if pond.blocks(p):return true
 return super.blocked(p)

func interact():
 if open_meadow and build_mode:return
 if not overlay.visible and seated:
  stand_up();return
 if not overlay.visible and action_target.get("kind","")=="meadow_seat":
  var seat=region.prop_nodes.get(str(action_target.extra),{})
  if not seat.is_empty():
   stand_point=player.position;player.position=seat.pos+Vector2(0,1);seated=true
  return
 if selected_cell>=0 and selected_cell<fields.size() and action_target.get("kind","") in ["meadow_fish","built_pond"]:
  super.interact();return
 if not overlay.visible and action_target.get("kind","")=="meadow_fish" and is_instance_valid(ground_tiles):
  var id=str(action_target.extra)
  if not ground_tiles.state.stocks.has(id):ground_tiles.state.stocks[id]={"count":0,"progress":0.0,"feed":0.0}
  show_fish_pond(ground_tiles.state.stocks[id],ground_tiles.refresh_stock);return
 if not overlay.visible and action_target.get("kind","")=="exit" and str(action_target.get("extra",""))=="village" and open_meadow:
  return_to_village();return   # 2026-11-19 Claude: farm gate
 if not overlay.visible and action_target.get("kind","")=="built_pond":
  var pond=waters.get(action_target.extra)
  if is_instance_valid(pond):
   show_fish_pond(pond.stock,pond.splash)
  return
 super.interact()

func stand_up():
 if not seated:return
 seated=false;player.position=stand_point;contact_shadow.visible=true;show_idle()

func _physics_process(dt):
 super._physics_process(dt)
 if seated:
  show_action("sit-south",fmod(elapsed,1.7));portrait.position.y-=10;contact_shadow.visible=false
 if is_instance_valid(cottage):cottage.follow()
 for pond in waters.values():pond.tick(dt)
 # 2026-11-19 Claude: walking off the east end of the gate lane goes to the village.
 if open_meadow and map_id=="ranch" and region!=null and not build_mode and not seated and not transition_pending and not overlay.visible and is_instance_valid(player):
  var gate=region.MEADOW_EXIT
  if player.position.x>=gate.x+24 and absf(player.position.y-gate.y)<=44:return_to_village()

func _process(dt):
 super._process(dt)
 if build_mode and brush_tool!=build_tool:brush.clear();brush_tool=""

func clear_build_gesture():
 super.clear_build_gesture()
 stroke="";brush.clear();brush_tool="";erase_drag=""

func editor_hint()->String:
 if not editor_tool_available(build_tool):return super.editor_hint()
 if build_tool=="water":return "拖出水面 · 右键填塘"
 if open_meadow and map_id=="ranch":
  if build_tool=="barn_unit" and not region.layout.barn.is_empty():return "已放置 · 在屋上右键收回"
  if build_tool=="house_unit" and region.saved().has("meadow_house"):return "已放置 · 在屋上右键收回"
  if build_tool=="bridge":return "左键在水面逐格铺木桥 · 并排铺可加宽 · 右键收回"
  if build_tool=="plot":return "拖动开田 · 右键收空田"
  if build_tool in ["path","channel"]:return "拖动画线 · Shift 铺面 · 右键收回"
 return super.editor_hint()

func draw_build():
 var m=editor_pointer()
 if erase_drag in ["path","channel"]:
  for c in brush:draw_rect(region.cell_rect(c),Color(.94,.57,.38,.38))
  return
 if erase_drag=="plot" and drag_from!=null:
  draw_rect(pond_box(drag_from,m),Color(.94,.57,.38,.38));return
 if map_id=="ranch" and open_meadow and (build_tool in ["channel","path","barn_unit","house_unit","bridge","plot"] or build_tool.begins_with("prop:")):
  if build_tool in ["path","channel"]:
   var color=Color(.42,.82,.9,.42) if build_tool=="channel" else Color(.88,.71,.42,.45)
   if brush.is_empty():draw_rect(region.cell_rect(Cottage.cell_of(m)),color)
   for c in brush:draw_rect(region.cell_rect(c),color)
   return
  if build_tool=="plot":
   draw_rect(pond_box(m if drag_from==null else drag_from,m),Color(.75,.56,.29,.48));return
  if build_tool=="bridge":
   var span=bridges.candidate(m,bridge_direction)
   draw_rect(bridges.deck(span) if not span.is_empty() else region.cell_rect(region.cell_of(m)),Color(.82,.66,.38,.55) if not span.is_empty() else Color(.95,.4,.34,.35));return
  if build_tool in ["house_unit","barn_unit"]:
   draw_building_preview(m)
   return
 if build_tool=="water":
  var r=pond_box(m if drag_from==null else drag_from,m)
  var valid=drag_from==null or water_error(r)==""
  draw_rect(r,Color(.4,.81,.85,.28) if valid else Color(1,.4,.3,.28))
  draw_rect(r,Color("e0e8bd") if valid else Color("f88b68"),false,2)
 elif build_tool in ["floor","wall","door"]:
  var c=Cottage.cell_of(m);var cell=Rect2(Vector2(c)*64,Vector2(64,64))
  draw_rect(cell,Color(1,1,1,.35),false,2)
  if build_tool=="floor":draw_rect(cell.grow(-2),Color(.88,.76,.46,.28))
  else:draw_rect(Cottage.edge_box(nearest_edge(m)[1]),Color("efce8f"))
 else:super.draw_build()

func _unhandled_input(event):
 if overlay.visible or (is_instance_valid(hotbar) and hotbar.library.visible):return
 if build_mode and can_build() and universal_erase_input(event):return
 if build_mode and not editor_tool_available(build_tool):super._unhandled_input(event);return
 if open_meadow and map_id=="ranch" and build_mode and build_tool in ["path","channel"]:
  ground_input(event);return
 if open_meadow and map_id=="ranch" and build_mode and build_tool in ["plot","barn_unit","house_unit","bridge"]:
  meadow_input(event);return
 if not build_mode or build_tool not in ["floor","wall","door","water"]:
  stroke="";drag_from=null;super._unhandled_input(event);return
 if not event is InputEventMouse:return
 var p=get_global_transform_with_canvas().affine_inverse()*event.position
 if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
  var right=event.button_index==MOUSE_BUTTON_RIGHT;var result=""
  if build_tool=="water":
   if event.pressed:
    if right:drag_from=null;result=fill_water(p)
    else:drag_from=p
   elif not right and drag_from!=null:result=change_water(pond_box(drag_from,p));drag_from=null
  elif event.pressed:
   stroke="erase" if right else "place";last_piece="";result=piece_at(p)
  else:stroke="";last_piece=""
  if result!="" and result!="ok":notify(result)
  queue_redraw();get_viewport().set_input_as_handled()
 elif event is InputEventMouseMotion:
  if event.button_mask==0:stroke="";drag_from=null
  if stroke!="" and build_tool!="water":piece_at(p)
  queue_redraw()

func refresh_life():
 super.refresh_life()
 if open_meadow and map_id=="ranch":hydrate_plots();refresh_field_sprites()

## 2026-11-19 Claude (round 2), Minecraft farmland rule: a plot within HYDRATE_RANGE cells
## of river or pond water (counting diagonals, like Minecraft's 9x9 square) stays wet by
## itself, so planted crops there never need the watering can. Wet soil (hydrated or
## watered by hand) is drawn darker; dry soil keeps its light colour.
const HYDRATE_RANGE=4
func plot_hydrated(rect:Rect2)->bool:
 if not is_instance_valid(ground_tiles):return false
 var c=Cottage.cell_of(rect.get_center())
 for y in range(c.y-HYDRATE_RANGE,c.y+HYDRATE_RANGE+1):
  for x in range(c.x-HYDRATE_RANGE,c.x+HYDRATE_RANGE+1):
   if ground_tiles.cells.get(Vector2i(x,y),"")=="channel":return true
 return false
func hydrate_plots():
 var beds:Array=region.beds if region!=null else []
 for i in mini(fields.size(),sim.data.crops.size()):
  var crop:Dictionary=sim.data.crops[i]
  var wet=plot_hydrated(fields[i].rect)
  fields[i]["hydrated"]=wet
  if wet and crop.planted:crop.water=maxf(float(crop.water),14400.0)
  if i<beds.size() and is_instance_valid(beds[i]):
   beds[i].self_modulate=Color(.72,.62,.56) if wet or (crop.planted and float(crop.water)>0) else Color.WHITE

func release_young(key:String):
 if open_meadow and map_id!="ranch" and map_id!="barn":
  notify("带幼崽到自家牧场或牧场屋放养。");return
 super.release_young(key)

func building_blocks_facility(r:Rect2,keep_landing:=true)->bool:
 if region.saved().has("meadow_house"):
  var door=region.saved().meadow_house
  var anchor=Vector2(door[0],door[1])
  if house_footprint(anchor).intersects(r) or (keep_landing and building_landing(anchor).grow(-4).intersects(r)):return true
 if not region.layout.barn.is_empty():
  var anchor=region.barn_door()
  if barn_footprint(anchor).intersects(r) or (keep_landing and building_landing(anchor).grow(-4).intersects(r)):return true
 return false

func facility_conflict(r:Rect2,keep_landing:=true)->bool:
 if building_blocks_facility(r,keep_landing):return true
 if is_instance_valid(bridges) and bridges.overlaps(r):return true
 if is_instance_valid(ground_tiles):
  for c in ground_tiles.cells:
   if ground_tiles.cells[c]=="channel" and region.cell_rect(c).intersects(r):return true
 return false

func house_art_rect(door:Vector2)->Rect2:
 var t=region.prop_tex("cottage");var info=region.props_meta.cottage
 return Rect2(door+Vector2(-float(info.door_x)*2,6-t.get_height()*2),t.get_size()*2)

func house_footprint(door:Vector2)->Rect2:
 var r=house_art_rect(door)
 return Rect2(r.position.x,r.end.y-150,r.size.x,150)

func building_landing(door:Vector2)->Rect2:
 return Rect2(door+Vector2(-32,4),Vector2(64,64))

func barn_art_rect(base:Vector2)->Rect2:
 var size_:Vector2=region.tex("res://qingxi-live/ranch-life/art/barn-exterior.png").get_size()*2
 return Rect2(base-Vector2(size_.x/2,size_.y),size_)

func barn_footprint(base:Vector2)->Rect2:
 var art=barn_art_rect(base)
 return Rect2(art.position.x+20,base.y-300,art.size.x-40,300)

func building_spot_issue(footprint_:Rect2,landing:Rect2)->String:
 if not world_bounds().grow(-36).encloses(footprint_) or not region.zone().encloses(landing):
  return "占地或入口超出了可建范围"
 if footprint_.grow(10).has_point(player.position):return "先走到建筑占地外"
 if region.MEADOW_EXIT_LANE.intersects(footprint_) or region.MEADOW_EXIT_LANE.intersects(landing):return "请给通往清溪村的小路留出位置"   # 2026-11-19 Claude
 if facility_conflict(footprint_) or facility_conflict(landing) or water_overlaps(footprint_) or water_overlaps(landing):
  return "建筑占地或入口压到了水面、桥或其他建筑"
 for solid in solids:
  if solid.grow(3).intersects(footprint_) or solid.grow(6).intersects(landing):
   return "建筑占地或入口被树木、围栏或设施挡住"
 for key in region.ranch().edges:
  var mid=region.edge_mid(key)
  if footprint_.has_point(mid) or landing.grow(-2).has_point(mid):return "请给建筑和入口留出围栏外的空间"
 for field in fields:
  if field.rect.intersects(footprint_) or field.rect.intersects(landing):return "建筑占地或入口压到了田地"
 for prop in region.prop_nodes.values():
  if footprint_.grow(12).has_point(prop.pos) or landing.grow(12).has_point(prop.pos):return "请先移开建筑或入口内的设施"
 if is_instance_valid(ground_tiles):
  for c in ground_tiles.cells:
   if ground_tiles.cells[c]=="path" and footprint_.intersects(region.cell_rect(c)):return "建筑占地压到了小路，门前可接路"
 for actor in herd_ai.actors.values():
  if actor.node.visible and footprint_.grow(12).has_point(actor.node.position):return "等动物离开占地再放置"
 return ""

func draw_building_preview(mouse:Vector2):
 var is_barn=build_tool=="barn_unit"
 if is_barn and not region.layout.barn.is_empty():return
 if not is_barn and region.saved().has("meadow_house"):return
 var anchor=barn_anchor(mouse)
 var art=barn_art_rect(anchor) if is_barn else house_art_rect(anchor)
 var footprint_=barn_footprint(anchor) if is_barn else house_footprint(anchor)
 var landing=building_landing(anchor)
 var ok=building_spot_issue(footprint_,landing)==""
 var tint=Color(.7,1,.7,.85) if ok else Color(1,.4,.32,.85)
 var texture_=region.tex("res://qingxi-live/ranch-life/art/barn-exterior.png") if is_barn else region.prop_tex("cottage")
 draw_texture_rect(texture_,art,false,Color(1,1,1,.55) if ok else Color(1,.5,.42,.5))
 draw_rect(footprint_,tint,false,2)
 draw_rect(landing,Color(tint,.25))
 draw_rect(landing,tint,false,2)

func change_house(p:Vector2,erase:bool)->String:
 var layout=region.saved();var door=barn_anchor(p)
 if erase:
  if not layout.has("meadow_house"):return ""
  var pos=layout.meadow_house
  if not house_art_rect(Vector2(pos[0],pos[1])).has_point(p):return ""
  layout.erase("meadow_house")
  region.remove_meadow_building("house")
 else:
  if layout.has("meadow_house"):return "已放置小屋，右键收回后可换位置"
  var issue=building_spot_issue(house_footprint(door),building_landing(door))
  if issue!="":return issue
  layout.meadow_house=[door.x,door.y]
  region.build_meadow_building("house")
 set_light(sky_value());save_progress();queue_redraw()
 return "ok"

func erase_edge_at(p:Vector2,edges:Dictionary)->String:
 # Raised rails are visible above their grid line. Prefer a direct hit on the foot.
 for offset in [0.,12.,23.]:
  var hit=nearest_edge(p+Vector2(0,offset))
  if hit[0]<=9 and edges.has(hit[1]):return hit[1]
 return ""

func universal_erase_input(event)->bool:
 if not event is InputEventMouse:return false
 var right=event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT
 if not right and not (event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT):return false
 var p=get_global_transform_with_canvas().affine_inverse()*event.position
 if right and event.pressed:
  clear_build_gesture()
  drag_from=null
  if not reclaim_furniture(p):
   var msg=erase_placed_at(p)
   if msg!="" and msg!="ok":notify(msg)
 elif erase_drag in ["path","channel"]:
  var c=Cottage.cell_of(p)
  extend_brush(c,event.shift_pressed)
  if right:
   var msg=ground_tiles.edit(erase_drag,brush,true)
   if msg!="" and msg!="ok":notify(msg)
 elif erase_drag=="plot" and right:
  if edit_plots(pond_box(drag_from,p),true)==0:notify("先收获作物，再收回田地")
 elif erase_drag=="edge" and not right:
  remove_hit_edge(p)
 if right and not event.pressed:
  clear_build_gesture()
  drag_from=null
 queue_redraw()
 get_viewport().set_input_as_handled()
 return true

func remove_hit_edge(p:Vector2)->String:
 if is_barn_floor():
  var key=erase_edge_at(p,barn_editor.plan.edges)
  if key!="":return barn_editor.edit("fence",barn_editor.region.edge_mid(key),true)
 elif map_id=="ranch" and region!=null:
  var key=erase_edge_at(p,region.ranch().edges)
  if key!="":
   var result=region.set_edge(key,"")
   if result=="ok":save_progress()
   return result
 return ""

func erase_placed_at(p:Vector2)->String:
 var c=Cottage.cell_of(p)
 var result=""
 if is_barn_floor():
  result=barn_stairs.edit(p,true)
  if result!="":return result
 if open_meadow and map_id=="ranch":
  result=change_house(p,true)
  if result!="":return result
  result=change_barn(p,true)
  if result!="":return result
 result=remove_hit_edge(p)
 if result!="":
  erase_drag="edge"
  return result
 if is_barn_floor():
  result=barn_editor.edit("feeder_all",p,true)
  if result!="":return result
 elif map_id=="ranch" and region!=null and region.feeder_at(c)>=0:
  result=region.take_feeder(c)
  if result=="ok":save_progress()
  return result
 if open_meadow and map_id=="ranch" and is_instance_valid(bridges):
  result=bridges.change(p,true,0)
  if result!="":return result
 if map_id=="field" and is_instance_valid(cottage):
  var key=erase_edge_at(p,cottage.plan.edges)
  if key!="":
   result=cottage.change("wall",Cottage.edge_box(key).get_center(),true)
  elif cottage.plan.floors.has(Cottage.key(c)):
   result=cottage.change("floor",p,true)
  if result!="":
   if result=="ok":save_progress()
   return result
 if placement.plan.tiles.has(Grid.key(c)):
  return placement.paint("",p,true)
 if region!=null and editor_tool_available("plot"):
  var i=region.cell_at(p)
  if i>=0:
   if open_meadow and map_id=="ranch":
    erase_drag="plot";drag_from=p
    return "ok"
   var msg=region.remove_plot(i)
   save_progress()
   return msg
 if open_meadow and map_id=="ranch" and is_instance_valid(ground_tiles):
  var layer=ground_tiles.cells.get(c,"")
  if layer in ["path","channel"]:
   erase_drag=layer
   brush_origin=c;brush_last=c;brush={c:true}
   return "ok"
 if region!=null and not waters.is_empty():return fill_water(p)
 return ""

func barn_anchor(p:Vector2)->Vector2:
 return (p/64).floor()*64+Vector2(32,60)

func change_barn(p:Vector2,erase:bool)->String:
 var layout=region.saved();var base=barn_anchor(p)
 if erase:
  var current:Dictionary=region.layout.barn
  if current.is_empty():return ""
  var pos=Vector2(current.base[0],current.base[1])
  if not barn_art_rect(pos).has_point(p):return ""
  layout.erase("meadow_barn")
  region.remove_meadow_building("barn")
 else:
  if not region.layout.barn.is_empty():return "已放置牧场屋，右键收回后可换位置"
  var footprint_=barn_footprint(base)
  var issue=building_spot_issue(footprint_,building_landing(base))
  if issue!="":return issue
  var gate=region.cell_of(base+Vector2(0,34))
  layout.meadow_barn={"base":[base.x,base.y],"door":[base.x,base.y],"rect":[footprint_.position.x,footprint_.position.y,footprint_.size.x,footprint_.size.y-6],"passage":[gate.x,gate.y]}
  region.build_meadow_building("barn")
 set_light(sky_value());save_progress();queue_redraw()
 return "ok"

func edit_plots(box:Rect2,erase:bool)->int:
 var clipped=box.intersection(region.zone())
 var count=0
 if not clipped.has_area():return count
 if erase:
  for i in range(fields.size()-1,-1,-1):
   if clipped.has_point(fields[i].rect.get_center()) and not sim.data.crops[i].planted:
    region.remove_plot(i,false);count+=1
 else:
  for y in range(int(clipped.position.y),int(clipped.end.y),64):
   for x in range(int(clipped.position.x),int(clipped.end.x),64):
    if region.add_plot(Vector2(x,y),false).begins_with("开垦"):count+=1
 if count>0:refresh_life();save_progress()
 return count

func meadow_input(event):
 if event is InputEventMouseMotion:
  queue_redraw();return
 if not event is InputEventMouseButton or event.button_index not in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:return
 var p=get_global_transform_with_canvas().affine_inverse()*event.position
 var erase=event.button_index==MOUSE_BUTTON_RIGHT
 if build_tool in ["barn_unit","house_unit","bridge"]:
  if event.pressed:
   var msg=""
   match build_tool:
    "barn_unit":msg=change_barn(p,erase)
    "house_unit":msg=change_house(p,erase)
    "bridge":msg=bridges.change(p,erase,bridge_direction)
   if msg!="" and msg!="ok":notify(msg)
 elif event.pressed:
  drag_from=p;stroke="erase" if erase else "place"
 elif drag_from!=null:
  var changed=edit_plots(pond_box(drag_from,p),erase)
  if changed==0:notify("只能收回空田" if erase else "请在空草地上开田")
  drag_from=null;stroke=""
 queue_redraw();get_viewport().set_input_as_handled()

func toggle_build():
 stand_up()
 var old_zoom=camera.zoom if is_instance_valid(camera) else Vector2.ONE
 super.toggle_build()
 if not open_meadow or map_id!="ranch" or not can_build():return
 if build_mode:
  walk_zoom=old_zoom;camera.zoom=Vector2.ONE*.65
  if is_instance_valid(hotbar):hotbar.select(hotbar.active)
 else:camera.zoom=walk_zoom
 brush.clear();brush_tool="";stroke="";drag_from=null
 update_camera(true)

func terrain_cell_free(c:Vector2i,tool:String)->bool:
 if not region.in_zone_cell(c) or region.barn_cell(c) or region.feeder_at(c)>=0:return false
 var rect=region.cell_rect(c).grow(-9)
 if tool!="path" and region.MEADOW_EXIT_LANE.intersects(rect):return false   # 2026-11-19 Claude: gate lane
 if facility_conflict(rect,tool!="path"):return false
 for prop in region.prop_nodes.values():
  if rect.grow(10).has_point(prop.pos):return false
 for solid in solids:
  if rect.intersects(solid):return false
 for field in fields:
  if rect.intersects(field.rect):return false
 if tool=="channel":
  for actor in herd_ai.actors.values():
   if actor.node.visible and rect.has_point(actor.node.position):return false
 return true

## 2026-11-19 Claude: river sound for water painted on the owner's farm. Only the cells
## within 7 cells of the player are looked at, so a big river costs nothing extra.
func nearest_water_cell(p:Vector2,deep_only:bool)->float:
 if not is_instance_valid(ground_tiles):return INF
 var at=Cottage.cell_of(p);var best=INF
 for y in range(at.y-7,at.y+8):
  for x in range(at.x-7,at.x+8):
   var c=Vector2i(x,y)
   if ground_tiles.cells.get(c,"")!="channel":continue
   if deep_only and not ground_tiles.basin.has(c):continue   # round 2b: any fish water
   var r=Rect2(Vector2(c)*64,Vector2(64,64))
   var d=Vector2(maxf(0,maxf(r.position.x-p.x,p.x-r.end.x)),maxf(0,maxf(r.position.y-p.y,p.y-r.end.y))).length()
   best=minf(best,d)
 return best
func painted_water_distance(p:Vector2)->float:
 var best=nearest_water_cell(p,false)
 for pond in waters.values():best=minf(best,pond.bank_center.distance_to(p)-90.0)
 return maxf(best,0.0)
func fish_pond_distance(p:Vector2)->float:return nearest_water_cell(p,true)

func water_at(p:Vector2)->bool:
 if is_instance_valid(ground_tiles):
  return (not is_instance_valid(bridges) or bridges.underfoot(p)!=1) and ground_tiles.covers(p,"channel")
 return super.water_at(p)

func can_swim_at(p:Vector2)->bool:
 if is_instance_valid(ground_tiles):return ground_tiles.swim_cells.has(ground_tiles.cell(p))
 return super.can_swim_at(p)

func move_actor(delta:Vector2):
 if seated or (is_instance_valid(hotbar) and hotbar.library.visible):return
 if is_instance_valid(ground_tiles) and (not is_instance_valid(bridges) or bridges.underfoot(player.position)!=1):
  match ground_tiles.cells.get(Cottage.cell_of(player.position),""):
   "channel":
    if ground_tiles.covers(player.position,"channel"):delta*=.62
   "path":
    if ground_tiles.covers(player.position,"path"):delta*=1.15
 player_moving=true
 super.move_actor(delta)
 player_moving=false

func extend_brush(target:Vector2i,area:bool):
 if area:
  brush.clear()
  for y in range(mini(brush_origin.y,target.y),maxi(brush_origin.y,target.y)+1):
   for x in range(mini(brush_origin.x,target.x),maxi(brush_origin.x,target.x)+1):brush[Vector2i(x,y)]=true
 else:
  # Crossing a diagonal corner paints a connecting cardinal neighbor.
  var steps=maxi(1,maxi(absi(target.x-brush_last.x),absi(target.y-brush_last.y)))
  var prev=brush_last;brush[prev]=true
  for i in range(1,steps+1):
   var c=Vector2i(Vector2(brush_last).lerp(Vector2(target),i/float(steps)).round())
   if c.x!=prev.x and c.y!=prev.y:brush[Vector2i(c.x,prev.y)]=true
   brush[c]=true;prev=c
 brush_last=target

func ground_input(event):
 if not event is InputEventMouse:return
 var at=Cottage.cell_of(get_global_transform_with_canvas().affine_inverse()*event.position)
 if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
  if event.pressed:
   brush.clear();brush_tool=build_tool;brush_origin=at;brush_last=at;brush[at]=true
   stroke="erase" if event.button_index==MOUSE_BUTTON_RIGHT else "place"
  elif brush_tool==build_tool and not brush.is_empty():
   extend_brush(at,event.shift_pressed)
   var had_deep=ground_tiles.deep.size()
   var msg=ground_tiles.edit(build_tool,brush,stroke=="erase")
   if msg!="ok" and msg!="":notify(msg)
   elif build_tool=="channel" and msg=="ok":
    if ground_tiles.deep.size()>had_deep:notify("深水已形成，可以到塘边放鱼苗")
    elif ground_tiles.deep.size()<had_deep:notify("填土后，深水范围已缩小")
   brush.clear();brush_tool="";stroke=""
  queue_redraw();get_viewport().set_input_as_handled()
 elif event is InputEventMouseMotion:
  if event.button_mask==0:brush.clear();brush_tool=""
  elif brush_tool==build_tool:extend_brush(at,event.shift_pressed)
  queue_redraw()

func piece_at(p:Vector2)->String:
 var id=build_tool+(Cottage.key(Cottage.cell_of(p)) if build_tool=="floor" else str(nearest_edge(p)[1]))
 if last_piece==id:return ""
 last_piece=id
 var result=cottage.change(build_tool,p,stroke=="erase")
 if result=="ok":save_progress()
 return result

