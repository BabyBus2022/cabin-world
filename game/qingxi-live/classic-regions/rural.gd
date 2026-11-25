extends "res://qingxi-live/garden.gd"
const StateModel=preload("res://qingxi-live/rural_state.gd")
const Herd=preload("res://qingxi-live/livestock.gd")
const AnimalAI=preload("res://qingxi-live/farm_animals.gd")
var herd_ai
var layout=preload("res://qingxi-live/rural_layout.gd").new()
const Pond=preload("res://qingxi-live/living_pond.gd")
var living_pond
var villagers
const Villagers=preload("res://qingxi-live/village_npcs.gd")
var husbandry:Array[Texture2D]=[]
var held_food=""
const SAVE_PATH="user://classic-regions-save.json"
var rooms
const Rooms=preload("res://qingxi-live/classic-regions/rooms.gd")
var MAP_NAMES={"village":"村庄中心","field":"农田","ranch":"牧场","pond":"鱼塘","home":"村庄小屋","seedshop":"种子店","stockshop":"牲畜店"}
var LINKS={
 "village":[["field",Vector2(150,940)],["ranch",Vector2(1830,1160)],["pond",Vector2(1550,320)],["home",Vector2(920,1127)],["seedshop",Vector2(295,482)],["stockshop",Vector2(1075,507)]],
 "field":[["village",Vector2(1030,650)],["pond",Vector2(640,780)]],
 "ranch":[["village",Vector2(120,740)],["pond",Vector2(640,800)]],
 "pond":[["village",Vector2(640,240)],["field",Vector2(250,650)],["ranch",Vector2(1030,650)]],
 "home":[["village",Vector2(640,635)]],
 "seedshop":[["village",Vector2(640,635)]],
 "stockshop":[["village",Vector2(640,635)]]}
const ANIMAL_POS={"cow":Vector2(500,550),"sheep":Vector2(640,550),"pig":Vector2(780,550)}
var sim=StateModel.new()
var map_id="village"
var structures:Array[Texture2D]=[]
var animals_art:Array[Texture2D]=[]
var animal_sprites={}
var animal_tags={}
var targets:Array[Dictionary]=[]
var hud:Control
var heading:Label
var details:Label
var hint:Label
var overlay:PanelContainer
var overlay_body:VBoxContainer
var map_layer:Node2D
var state_tick=0.0
var save_tick=0.0
var energy_tick=0.0
var action_target={}
var testing=false
var open_menu=""
var light_preset=4
var portal_grace=0.0
var transition_pending=false
var rural_sky=[0.25,0.50,0.73,0.94]

func _ready():
 testing=get_tree().has_meta("classic_regions_test") or "--check-rural" in OS.get_cmdline_user_args() or "--capture-rural" in OS.get_cmdline_user_args() or "--check-handoff" in OS.get_cmdline_user_args()
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 load_assets();rooms=Rooms.new(self);structures.assign([rooms.houses[5],rooms.houses[3],rooms.houses[3],rooms.houses[4]])
 husbandry=parts("husbandry.png",true);herd_ai=AnimalAI.new(self);villagers=Villagers.new(self)
 var animal_img=full_image("farm-animals.png")
 var cell=Vector2i(animal_img.get_width()/3,animal_img.get_height()/2)
 for i in 6:
  animals_art.append(ImageTexture.create_from_image(trim_image(animal_img.get_region(Rect2i(Vector2i(i%3,i/3)*cell,cell)))))
 var offline=0.0
 if not testing and sim.load_from(SAVE_PATH):offline=sim.settle()
 map_id=str(sim.data.map) if MAP_NAMES.has(str(sim.data.map)) else "village"
 make_ui();build_map(map_id)
 get_tree().auto_accept_quit=false
 if offline>60:notify("离线 %.1f 小时：已结算生长，成熟产物不会腐烂"%(offline/3600.0))
 else:notify("1.0 风格村庄：中心连接各区域，镜头随你移动；M 地图，F10 快速测试")
 DisplayServer.window_set_title("小屋世界 · 1.0 风格村庄 · 七个独立区域")
 if "--check-rural" in OS.get_cmdline_user_args():run_rural_checks.call_deferred()
 if "--capture-rural" in OS.get_cmdline_user_args():capture_rural.call_deferred()

func make_ui():
 var layer=CanvasLayer.new();add_child(layer)
 hud=Control.new();hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(hud)
 var f=SystemFont.new();f.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","SimHei"]);hud.add_theme_font_override("font",f)
 var bar=PanelContainer.new();bar.position=Vector2(8,8);bar.custom_minimum_size=Vector2(752,36);bar.add_theme_stylebox_override("panel",panel());hud.add_child(bar)
 var row=HBoxContainer.new();bar.add_child(row)
 heading=label("",12);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(heading)
 row.add_child(button("M 地图",show_map))
 row.add_child(button("B 背包",show_bag))
 row.add_child(button("F10 测试",show_test))
 row.add_child(button("切换光照",func():light_preset=(light_preset+1)%5;set_light(sky_value());update_hud()))
 var info=PanelContainer.new();info.position=Vector2(8,52);info.custom_minimum_size=Vector2(202,0);info.add_theme_stylebox_override("panel",panel());hud.add_child(info)
 details=label("",10);info.add_child(details)
 var bottom=PanelContainer.new();bottom.position=Vector2(8,378);bottom.custom_minimum_size=Vector2(752,46);bottom.add_theme_stylebox_override("panel",panel());hud.add_child(bottom)
 var lines=VBoxContainer.new();bottom.add_child(lines)
 hint=label("",11);lines.add_child(hint)
 status=label("WASD 行走 · Shift 快走 · E 互动 · M 地图 · B 背包 · F10 测试",10);lines.add_child(status)
 overlay=PanelContainer.new();overlay.position=Vector2(154,62);overlay.custom_minimum_size=Vector2(460,0);overlay.add_theme_stylebox_override("panel",panel());overlay.visible=false;hud.add_child(overlay)
 var menu_scroll=ScrollContainer.new();menu_scroll.custom_minimum_size=Vector2(440,300);menu_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;overlay.add_child(menu_scroll)
 overlay_body=VBoxContainer.new();overlay_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;overlay_body.add_theme_constant_override("separation",6);menu_scroll.add_child(overlay_body)

func clear_menu(title:String):
 overlay.visible=true
 for child in overlay_body.get_children():overlay_body.remove_child(child);child.queue_free()
 var row=HBoxContainer.new();overlay_body.add_child(row)
 var name_label=label(title,16);name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(name_label)
 row.add_child(button("关闭 · Esc",close_menu))
func close_menu():
 overlay.hide();open_menu=""
func menu_line(text_:String):
 overlay_body.add_child(label(text_,11))
func menu_button(text_:String,fn:Callable):
 overlay_body.add_child(button(text_,fn))
func show_map():
 open_menu="map";clear_menu("乡村地图")
 menu_line("中心连接各区；田地、牧场与鱼塘之间有近路。")
 menu_line("路口按 E 换区；店铺与小屋直接走过门槛。以下可快速前往。")
 for id in MAP_NAMES:
  
  var target_id=str(id)
  menu_button(("● " if id==map_id else "前往 · ")+str(MAP_NAMES[id]),func():close_menu();travel.call_deferred(target_id))
 menu_line("地图内镜头跟随角色；切图不会重置作物和动物。")
func show_bag():
 open_menu="bag";clear_menu("背包 · %d 币"%sim.data.coins)
 for item in StateModel.ITEM_NAMES:
  menu_line("%s：%d   ｜家中：%d"%[StateModel.ITEM_NAMES[item],sim.data.bag[item],sim.data.storage[item]])
 menu_button("吃一份家常菜 · 恢复 30 精力",func():perform(sim.eat());show_bag())
func show_test():
 open_menu="test";clear_menu("农村测试工具")
 menu_line("仅作用于这份农村测试存档，不改变真实时钟或天色。")
 menu_button("F6 当前区域：作物成熟 / 动物成年 / 鱼长成",func():perform(sim.quick_grow(map_id)))
 menu_button("F7 成年牛羊：各补一份产物",func():perform(sim.quick_produce()))
 menu_button("F8 所有地图：推进生长 1 小时",advance_hour)
 menu_button("F9 补给：零钱、种子、各类饲料和引导食物",func():perform(sim.supplies()))
 menu_button("重置这份测试存档…",confirm_reset)
 menu_line("正常周期：白菜 20 分钟；鱼 8 小时；羊 1 天，牛 2 天，猪 3 天。")
 menu_line("缺水或饲料会暂停生长；成熟不腐烂，动物不饿死。")
func confirm_reset():
 open_menu="reset";clear_menu("重置农村测试存档")
 menu_line("将清空本 Demo 的种植、动物、背包和家中储物。")
 menu_line("正式小屋世界与角色工坊不会受到影响。")
 menu_button("确认重置",func():sim.reset();close_menu();travel.call_deferred("village");save_progress();notify("测试存档已重置"))
func show_shop(category="seed"):
 var trade=preload("res://qingxi-live/village3d/trade.gd")
 if not trade.SHOPS.has(category):category="seed"
 open_menu="shop";clear_menu(trade.SHOPS[category].name)
 menu_line("零钱 %d 币；本店只收购对应类别的产物。"%sim.data.coins)
 for item in trade.SHOPS[category].buy:
  var key=str(item)
  menu_button(StateModel.ITEM_NAMES[key]+" · %d 币"%StateModel.PRICES[key],func():perform(sim.buy(key));show_shop(category))
 if category=="livestock":
  for kind in StateModel.NAMES:
   var key=str(kind)
   menu_button("幼%s · %d 币（送到牧场）"%[StateModel.NAMES[key],StateModel.ANIMAL_PRICE[key]],func():perform(sim.buy_animal(key));show_shop(category))
 var names=[]
 for item in trade.SHOPS[category].sell:names.append(StateModel.ITEM_NAMES[item])
 menu_button("出售："+"、".join(names),func():perform(trade.sell(sim,category));show_shop(category))
 if category=="livestock":menu_button("出售成年猪 · 90 币",func():perform(sim.sell_pig());show_shop(category))
func show_home():
 open_menu="home";clear_menu("村庄小屋 · 做饭与储物")
 menu_line("村庄的小厨房、储物柜和休息长椅；不重复原有的私人房间。")
 menu_button("做家常菜 · 白菜 ×2 → 菜 ×1",func():perform(sim.cook()))
 menu_button("吃家常菜 · 恢复 30 精力",func():perform(sim.eat()))
 menu_button("休息 · 恢复精力，不跳过现实时间",func():perform(sim.rest()))
 menu_button("全部背包物品存入家中",func():perform(sim.store_items(false)))
 menu_button("取回家中全部物品",func():perform(sim.store_items(true)))
func perform(message:String):
 notify(message);refresh_life();save_progress();update_hud()
func advance_hour():
 sim.settle();sim.advance(3600);sim.data.test_uses+=1;perform("测试：所有地图已推进 1 小时生长；缺水缺料仍然暂停")
func save_progress():
 if not testing:
  sim.settle()
  if not sim.save_to(SAVE_PATH):notify("测试存档保存失败，请检查目录是否可写")
func _notification(what):
 if what==NOTIFICATION_WM_CLOSE_REQUEST:
  sim.settle();save_progress();get_tree().quit()

func world_label(text_:String,p:Vector2)->Label:
 var tag=label(text_,10,Color("f8edcc"))
 tag.add_theme_color_override("font_shadow_color",Color("27372d"))
 tag.add_theme_constant_override("shadow_offset_x",1);tag.add_theme_constant_override("shadow_offset_y",1)
 var f=SystemFont.new();f.font_names=PackedStringArray(["Microsoft YaHei"]);tag.add_theme_font_override("font",f)
 tag.position=p-Vector2(64,0);tag.size=Vector2(128,18);tag.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;tag.z_index=6;map_layer.add_child(tag)
 return tag
func sky_value()->float:
 if light_preset<4:return rural_sky[light_preset]
 var now=Time.get_datetime_dict_from_system()
 return (float(now.hour)+float(now.minute)/60.0+float(now.second)/3600.0)/24.0
func add_target(kind:String,p:Vector2,title:String,extra=""):
 targets.append({"kind":kind,"pos":p,"name":title,"extra":extra})
 world_label(title,p+Vector2(0,10))
func build_map(id:String,arrival=Vector2.ZERO):
 portal_grace=0.55;transition_pending=false
 map_id=id;sim.data.map=id
 if is_instance_valid(map_layer):map_layer.free()
 if is_instance_valid(camera):camera.free()
 map_layer=Node2D.new();add_child(map_layer)
 surfaces.clear();cast_shadows.clear();trees.clear();solids.clear();fields.clear();tree_placements.clear();targets.clear();animal_sprites.clear();animal_tags.clear()
 active_action="";action_elapsed=0;idle_elapsed=0;selected_cell=-1;action_target={};herd_ai.reset();villagers.reset()
 # The inherited ground creator attaches to the root; move it into map lifetime.
 make_ground()
 var floor_node=get_child(get_child_count()-1)
 floor_node.reparent(map_layer)
 ground_material.set_shader_parameter("path_mask",layout.mask("home" if rooms.contains(id) else id))
 ground_material.set_shader_parameter("world_size",world_bounds().size)
 floor_node.polygon=PackedVector2Array([Vector2.ZERO,Vector2(world_bounds().size.x,0),world_bounds().size,Vector2(0,world_bounds().size.y)])
 shadow_root=Node2D.new();map_layer.add_child(shadow_root)
 scenery=Node2D.new();scenery.y_sort_enabled=true;map_layer.add_child(scenery)
 if rooms.contains(id):rooms.build(id,arrival);return
 var rng=RandomNumberGenerator.new();rng.seed=1300+int(MAP_NAMES.keys().find(id))*17
 var locations=layout.TREES[id]
 for i in locations.size():
  var pos:Vector2=locations[i]
  var w=rng.randi_range(110,145)
  var sprite=object(tree_texture[i%4],pos,w,Rect2(-8,-5,16,12),true,"tree")
  trees.append({"sprite":sprite,"base":pos,"width":w,"kind":i%4})
 if id in ["field","ranch","pond"]:make_region_edges(id)
 if id=="village":
  rooms.exterior()
  object(structures[3],Vector2(620,525),100,Rect2(-40,-25,80,25))
  object(structures[3],Vector2(465,580),64,Rect2(-25,-20,50,25))
  object(prop_texture[3],Vector2(699,650),60,Rect2(-24,-8,48,14))
  object(prop_texture[1],Vector2(1200,525),36,Rect2(-12,-6,24,12))
  add_target("well",Vector2(620,565),"村庄水井")
 elif id=="field":
  object(structures[1],Vector2(690,460),155,Rect2(-65,-45,130,45))
  object(structures[3],Vector2(750,590),58,Rect2(-25,-20,50,25))
  add_target("well",Vector2(750,610),"水井 · 浇水提示")
  for y in 3:
   for x in 4:
    var p=FARM_ORIGIN+Vector2(x,y)*CELL
    var plant=object(crop_texture[0],p+Vector2(16,28),29,Rect2(),false)
    fields.append({"rect":Rect2(p,Vector2(CELL,CELL)),"state":-1,"sprite":plant,"timer":0.0})
  world_label("白菜田 · 每格一株",FARM_ORIGIN+Vector2(64,-12))
 elif id=="ranch":
  for kind in Herd.NAMES:
   var pen:Rect2=Herd.PENS[kind];var center=pen.get_center().x
   var idx=int(["cow","sheep","pig"].find(kind))
   object(husbandry[idx],Vector2(center,pen.position.y+22),145 if kind=="cow" else 135,Rect2(-55,-30,110,30))
   object(husbandry[3],Vector2(pen.position.x+65,pen.position.y+83),68,Rect2(-31,-13,62,16))
   for box in [Rect2(pen.position,Vector2(pen.size.x,4)),Rect2(pen.position,Vector2(4,pen.size.y)),Rect2(pen.position+Vector2(pen.size.x-4,0),Vector2(4,pen.size.y)),Rect2(pen.position+Vector2(0,pen.size.y-4),Vector2(pen.size.x/2-36,4)),Rect2(Vector2(center+36,pen.end.y-4),Vector2(pen.size.x/2-36,4))]:solids.append(box)
   add_target("pen",Vector2(pen.position.x+65,pen.position.y+108),Herd.NAMES[kind]+"食槽 / 水槽",kind)
   world_label({"cow":"奶牛舍 · 挤奶","sheep":"羊草场 · 剪毛","pig":"猪圈 · 育肥"}[kind],Vector2(center,pen.end.y+17))
 elif id=="pond":
  living_pond=Pond.new();map_layer.add_child(living_pond);living_pond.setup(self)
  object(structures[0],Vector2(1100,467),116,Rect2(-42,-28,84,30))
  object(villagers.rows[2][0],Vector2(1065,505),36,Rect2(),false)
  add_target("shop",Vector2(1108,505),"鱼苗铺 · 鱼苗 / 饲料 / 收鱼","fish")
  object(prop_texture[3],Vector2(488,651),58,Rect2(-24,-8,48,14))
  object(prop_texture[2],Vector2(938,646),37,Rect2(-12,-7,24,12))
  add_target("pond",Pond.INTERACTION,"鱼塘码头 · 放苗 / 投喂 / 捕捞")
 elif id=="home":
  roof=object(ImageTexture.create_from_image(trim_image(full_image("house-modern-japanese.png"))),HOUSE_BASE,HOUSE_WIDTH,Rect2(),true,"house")
  solids.append(Rect2(578,410,72,66));solids.append(Rect2(650,410,174,73))
  roof.get_parent().position.y=476;roof.position.y+=16;roof.material.set_shader_parameter("emissive_mode",3.0)
  object(prop_texture[1],Vector2(500,510),48,Rect2(-18,-10,36,16))
  object(prop_texture[1],Vector2(840,510),48,Rect2(-18,-10,36,16))
  var lantern=object(prop_texture[2],Vector2(443,545),43,Rect2(-15,-9,30,14));lantern.material.set_shader_parameter("emissive_mode",2.0)

 for link in LINKS[id]:
  var portal=rooms.contains(link[0])
  add_target("portal" if portal else "exit",link[1],("走入 " if portal else "前往 ")+str(MAP_NAMES[link[0]])+("" if portal else " · E"),str(link[0]))
 # Scatter quiet decorations away from the main routes.
 for i in 20:
  var pos=Vector2(rng.randi_range(250,1080),rng.randi_range(300,760))
  if blocked(pos) or absf(pos.y-650)<36 or absf(pos.x-640)<36:continue
  if id=="ranch":continue
  if id=="field" and Rect2(FARM_ORIGIN-Vector2(24,24),Vector2(180,150)).has_point(pos):continue
  object(detail_texture[1 if i%4 else 2],pos,9,Rect2(),false)
 make_actor()
 player.position=arrival if arrival!=Vector2.ZERO else Vector2(640,740 if id=="ranch" else 650)
 if arrival==Vector2.ZERO and id=="field":player.position=Vector2(840,670)
 if arrival==Vector2.ZERO and id=="pond":player.position=Vector2(884,650)
 if id=="village":villagers.spawn()
 update_camera(true);refresh_life();set_light(sky_value());queue_redraw();update_hud()
func travel(id:String):
 sim.settle()
 var previous=map_id;var spawn=Vector2.ZERO
 for link in LINKS[id]:
  if str(link[0])==previous:
   spawn=link[1]+(Vector2(640,570)-link[1]).normalized()*55
 if rooms.contains(previous) or rooms.contains(id):spawn=rooms.arrival(previous,id)
 build_map(id,spawn);close_menu();save_progress()
func floor_height(p:Vector2)->float:
 if rooms!=null and rooms.contains(map_id):return rooms.floor_height(map_id,p)
 return 0.0
func apply_elevation():
 # One scene-wide body unit for idle, walk and all imported action clips.
 # Keep the pack's calibrated anchors; never normalize each pose to its bounds.
 var ratio=26.0/BODY_UNIT_ON_SCREEN
 portrait.scale*=ratio;portrait.position*=ratio
 super.apply_elevation()
 contact_shadow.scale=Vector2.ONE*ratio
func refresh_life():
 if map_id=="field":
  for i in fields.size():
   var c:Dictionary=sim.data.crops[i];var f:Dictionary=fields[i]
   f.state=-1 if not c.planted else (3 if c.progress>=StateModel.CROP_SECONDS else (2 if c.progress>StateModel.CROP_SECONDS*0.5 else (1 if c.water>0 else 0)))
   refresh_crop(i)
 if map_id=="ranch":
  herd_ai.refresh()
  var born=sim.livestock.breed()
  if not born.is_empty():herd_ai.refresh();notify("一只幼崽出生了！父母将休息 6 小时")
 queue_redraw()

func _draw():
 if map_id=="field":super._draw()
 if map_id=="ranch":
  for kind in Herd.PENS:
   var pen:Rect2=Herd.PENS[kind];var center=pen.get_center().x
   if kind=="pig":
    var mud=PackedVector2Array()
    for i in 12:mud.append((pen.get_center()+Vector2(35,20)+Vector2(cos(i*TAU/12)*75,sin(i*TAU/12)*37)).snapped(Vector2(4,4)))
    draw_colored_polygon(mud,Color("a28b67")*ground_tint)
   var ink=Color("a17648")*ground_tint
   for span in [Rect2(pen.position,Vector2(pen.size.x,4)),Rect2(pen.position+Vector2(0,pen.size.y-4),Vector2(pen.size.x/2-36,4)),Rect2(Vector2(center+36,pen.end.y-4),Vector2(pen.size.x/2-36,4))]:
    draw_rect(span,ink);draw_rect(Rect2(span.position-Vector2(0,7),span.size),ink)
    for x in range(int(span.position.x),int(span.end.x),24):draw_rect(Rect2(x,span.position.y-13,5,19),Color("71583e")*ground_tint)
   for x in [pen.position.x,pen.end.x-4]:
    draw_rect(Rect2(x,pen.position.y,4,pen.size.y),ink)
    for y in range(int(pen.position.y),int(pen.end.y),24):draw_rect(Rect2(x-1,y-10,6,15),Color("71583e")*ground_tint)

func _physics_process(dt):
 if not is_instance_valid(player) or paused_for_capture:return
 elapsed+=dt;state_tick+=dt;save_tick+=dt;portal_grace=maxf(0,portal_grace-dt)
 var old_position=player.position
 if state_tick>=0.5:
  sim.settle();refresh_life();set_light(sky_value());state_tick=0
 if save_tick>=10:save_progress();save_tick=0
 var v=Vector2.ZERO
 if not overlay.visible and not transition_pending:
  v=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
 if v!=Vector2.ZERO:
  active_action="";idle_elapsed=0.0
  facing=(2 if v.x>0 else 1) if absf(v.x)>absf(v.y) else (0 if v.y>0 else 3)
  move_actor(v.normalized()*dt*(120 if Input.is_physical_key_pressed(KEY_SHIFT) else 77));animate_walk()
  energy_tick+=dt
  if energy_tick>40:sim.data.energy=maxi(0,int(sim.data.energy)-1);energy_tick=0
 else:
  idle_elapsed+=dt
  if active_action!="":
   action_elapsed+=dt
   if not show_action(active_action,action_elapsed):active_action="";idle_elapsed=0
  elif idle_elapsed>7:play_action("idle_look-%d"%facing)
  else:show_idle()
 update_camera()
 if not overlay.visible:check_portals(old_position)
 if map_id=="ranch":herd_ai.tick(dt)
 if map_id=="village":villagers.tick(dt)
 if map_id=="pond" and is_instance_valid(living_pond):living_pond.tick(dt)
 selected_cell=-1
 if map_id=="field":
  selected_cell=cell_at(player.position+facing_vector()*23)
  if selected_cell<0:selected_cell=cell_at(player.position)
 action_target={}
 var nearest=58.0
 for target in targets:
  var distance=player.position.distance_to(target.pos)
  if distance<nearest:nearest=distance;action_target=target
 for tree in trees:
  tree.sprite.self_modulate.a=0.5 if player.position.y<tree.base.y and player.position.y>tree.base.y-150 and absf(player.position.x-tree.base.x)<tree.width*0.45 else 1.0
 update_hud();queue_redraw()
func remaining(seconds:float)->String:
 if seconds<=0:return "已完成"
 if seconds<3600:return "%d 分钟"%int(ceil(seconds/60))
 return "%.1f 小时"%(seconds/3600)
func update_hud():
 if not is_instance_valid(heading):return
 heading.text="1.0 风格村庄 · %s   %d 币"%[MAP_NAMES[map_id],sim.data.coins]
 var summary=("现实" if light_preset==4 else "预览")+lighting_label+" / 独立生长"
 summary+="\n种子 %d   白菜 %d   精力 %d"%[sim.data.bag.seed,sim.data.bag.veg,sim.data.energy]
 summary+="\n干草 %d   猪料 %d   鱼料 %d"%[sim.data.bag.hay,sim.data.bag.pig_feed,sim.data.bag.fish_feed]
 summary+="\n牛奶 %d   羊毛 %d   鲜鱼 %d"%[sim.data.bag.milk,sim.data.bag.wool,sim.data.bag.fish]
 summary+="\nQ 手持："+("空手" if held_food=="" else StateModel.ITEM_NAMES[held_food]+" ×"+str(sim.data.bag[held_food]))
 if map_id=="ranch":summary+="\n牛羊跟小麦，猪跟胡萝卜\n靠近动物 / 食槽按 E\n各圈独立，最多各养 6 只"
 elif map_id=="field":summary+="\n白菜 20 分钟；收获返种子"
 elif map_id=="pond":summary+="\n养殖 %d 条 · %s\n%s"%[sim.data.pond.count,remaining(StateModel.FISH_SECONDS-sim.data.pond.progress),"缺鱼饲料" if sim.data.pond.feed<=0 else "已投喂"]
 elif map_id=="home":summary+="\n灶台、柜子和长椅前按 E"
 elif rooms.contains(map_id):summary+="\n独立店铺地图，柜台前按 E\n走出大门返回村庄中心"
 else:summary+="\n种子店 / 牲畜店分别进入\n中心连接鱼塘、农田、牧场"
 details.text=summary
 var prompt="走过门槛切换区域 · 柜台前按 E" if rooms.contains(map_id) else "沿小路探索 · 路口按 E 换图 · 房门直接走入"
 if selected_cell>=0:
  var c:Dictionary=sim.data.crops[selected_cell]
  prompt="E 播种白菜" if not c.planted else ("E 收获白菜 ×2 + 种子 ×1" if c.progress>=StateModel.CROP_SECONDS else "E 浇水 · 还需 "+remaining(StateModel.CROP_SECONDS-c.progress)+(" · 缺水暂停" if c.water<=0 else " · 湿润"))
 elif not action_target.is_empty():prompt=("" if action_target.kind=="portal" else "E · ")+str(action_target.name).replace(" · E","")
 hint.text=last_message if elapsed<message_until else prompt
 status.text=prompt+"    ｜ M 地图 · B 背包 · F10 测试" if elapsed<message_until else "WASD 行走 · E 互动 · Q 手持食物 · F6 成熟/成年 · F7 产物 · F8 生长+1h · F9 补给"

func interact():
 if overlay.visible:return
 sim.settle()
 if selected_cell>=0:
  perform(sim.crop_action(selected_cell));play_action("pick_up-%d"%facing);return
 if action_target.is_empty():notify("靠近商摊、田格、动物、码头或路口，再按 E");return
 match str(action_target.kind):
  "shop":show_shop(str(action_target.get("extra","seed")))
  "villager":show_villager(int(action_target.extra))
  "home":show_home()
  "furniture":rooms.interact(str(action_target.extra))
  "portal":notify("直接走过门槛，不需要按 E")
  "exit":travel.call_deferred(str(action_target.extra))
  "animal":show_animal(str(action_target.extra))
  "pen":show_pen(str(action_target.extra))
  "pond":
   var message=sim.pond_action();perform(message)
   if message.begins_with("投喂完成") or message.begins_with("放入鱼苗") or message.begins_with("捕捞"):living_pond.splash()
   play_action("pick_up-%d"%facing)
  "well":notify("初版水源免费：在已播种田格前按 E 即可浇水")
func _unhandled_key_input(event):
 if not event is InputEventKey or not event.pressed or event.echo:return
 match event.physical_keycode:
  KEY_ESCAPE:
   if overlay.visible:close_menu()
   else:save_progress();get_tree().quit()
  KEY_M:show_map()
  KEY_B:show_bag()
  KEY_Q:
   var food_options=["","wheat","carrot"]
   held_food=food_options[(food_options.find(held_food)+1)%3]
   notify("手持 "+("空手" if held_food=="" else StateModel.ITEM_NAMES[held_food])+"：靠近圈内动物，喜欢它的动物会跟随")
  KEY_E:interact()
  KEY_F6:perform(sim.quick_grow(map_id))
  KEY_F7:perform(sim.quick_produce())
  KEY_F8:advance_hour()
  KEY_F9:perform(sim.supplies())
  KEY_F10:show_test()
  KEY_R:
   player.position=(Vector2(880,543) if rooms.configs[map_id].up else Rooms.ENTRY-Vector2(0,55)) if rooms.contains(map_id) else (Vector2(884,650) if map_id=="pond" else Vector2(640,740 if map_id=="ranch" else 650))
   portal_grace=0.55;update_camera(true)

func run_rural_checks():
 print("Use res://qingxi-live/classic-regions/verify.gd for this demo's checks")
 get_tree().quit()

func _physics_process_for_check():
 paused_for_capture=false;_physics_process(0.0);paused_for_capture=true
func walk_check(keycode:int,seconds:float):
 var event=InputEventKey.new();event.physical_keycode=keycode;event.pressed=true;Input.parse_input_event(event)
 for i in int(seconds*60):
  paused_for_capture=false;_physics_process(1.0/60.0);paused_for_capture=true
  await get_tree().process_frame
 event=InputEventKey.new();event.physical_keycode=keycode;event.pressed=false;Input.parse_input_event(event)
func check_portals(previous_position:Vector2):
 if portal_grace>0 or transition_pending:return
 var movement=player.position-previous_position
 for target in targets:
  if target.kind!="portal":continue
  var direction=rooms.portal_direction(map_id,str(target.extra))
  if movement.y*direction<=0.001:continue
  # Swept crossing also catches a threshold crossed during a slow frame.
  var plane=float(target.pos.y)
  var crossing=(previous_position.y-plane)*direction<=0 and (player.position.y-plane)*direction>=0
  var fraction=(plane-previous_position.y)/movement.y
  var crossing_x=lerpf(previous_position.x,player.position.x,clampf(fraction,0,1))
  if crossing and absf(crossing_x-float(target.pos.x))<=20:
   transition_pending=true;travel.call_deferred(str(target.extra));return
func capture_rural():
 paused_for_capture=true
 light_preset=1
 sim.data.coins=300
 sim.quick_grow("ranch");sim.quick_produce()
 for i in [0,1,4,5,8]:
  sim.crop_action(i);sim.crop_action(i)
 sim.advance(700);sim.data.crops[0].progress=1200
 sim.pond_action();sim.pond_action()
 for id in MAP_NAMES:
  build_map(id)
  if id=="field":player.position=Vector2(840,670)
  elif id=="home":player.position=Vector2(620,530)
  elif id=="ranch":player.position=Vector2(665,730)
  elif id=="pond":player.position=Vector2(884,619);living_pond.tick(1.0)
  else:player.position=Vector2(640,635)
  show_idle();update_camera(true);set_light(0.50);last_message="";message_until=0;update_hud()
  await get_tree().process_frame;await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/preview-"+id+".png"))
 build_map("home");player.position=Vector2(620,530);update_camera(true);set_light(0.94);await get_tree().process_frame;await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/preview-home-night.png"))
 show_shop();await get_tree().process_frame;await get_tree().process_frame;await RenderingServer.frame_post_draw
 assert(overlay.position.y+overlay.size.y<=432)
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/preview-shop-menu.png"))
 close_menu();build_map("ranch");player.position=Vector2(665,730);update_camera(true);set_light(0.5)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qingxi-live/motion"))
 for i in 24:
  for step in 4:herd_ai.tick(0.125)
  await get_tree().process_frame;await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/motion/%03d.png"%i))
 build_map("pond");player.position=Vector2(884,619);update_camera(true);set_light(0.5);living_pond.splash()
 var previous_water=PackedByteArray()
 for i in 3:
  living_pond.tick(0.8)
  await get_tree().process_frame;await RenderingServer.frame_post_draw
  var water_shot=get_viewport().get_texture().get_image()
  water_shot.save_png(ProjectSettings.globalize_path("res://qingxi-live/preview-water-%d.png"%i))
  var size_=water_shot.get_size();var patch=water_shot.get_region(Rect2i(Vector2i(size_.x*0.30,size_.y*0.30),Vector2i(size_.x*0.25,size_.y*0.20))).get_data()
  if i>0:assert(patch!=previous_water,"Water shader did not animate")
  previous_water=patch
 build_map("room0");player.position=Vector2(880,615);show_idle();update_camera(true);hud.hide()
 await get_tree().process_frame;await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/preview-stairs.png"))
 hud.show()
 build_map("village");hud.hide();camera.zoom=Vector2.ONE*0.5;camera.position=Vector2(1024,768);set_light(0.50)
 await get_tree().process_frame;await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/preview-village-overview.png"))
 hud.show();build_map("ranch");set_light(0.50)
 for kind in Herd.NAMES:
  var a=sim.livestock.members(kind)[0];var model=herd_ai.actors[a.id].model
  model.animate(0.1,false,"歇一会儿",false)
  await get_tree().process_frame;await RenderingServer.frame_post_draw
  model.texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/model-"+kind+".png"))
 print("RURAL_CAPTURE_PASS five_maps=true interiors=8 night=true animated_water=true articulated_models=true motion_frames=24")
 get_tree().quit()


func show_animal(id:String):
 var a=sim.livestock.animal(id)
 if a.is_empty():close_menu();return
 open_menu="animal";clear_menu(Herd.NAMES[a.kind]+" #"+id)
 menu_line(("成年" if sim.livestock.adult(a) else "幼年 · 成长 %d%%"%int(a.age/Herd.GROWTH[a.kind]*100))+"   ｜同种 %d 只"%sim.livestock.members(a.kind).size())
 var p:Dictionary=sim.livestock.data.pens[a.kind]
 menu_line("圈内食物 %s · 饮水 %s"%["充足" if p.feed+p.grass>0 else "不足","充足" if p.water>0 else "不足"])
 menu_button("喂"+("小麦" if a.kind!="pig" else "胡萝卜")+" · 幼崽助长 / 成年后亲近同伴",func():perform(sim.livestock.treat(id,sim.data.bag));show_animal(id))
 if a.kind=="cow":
  menu_line("干草和饮水维持生长；成年后积累乳量，每 8 小时可挤奶。")
  menu_button("使用奶桶挤奶"+(" · 已可挤奶" if a.ready>0 else " · 尚未准备好"),func():perform(sim.animal_action(id));show_animal(id))
 elif a.kind=="sheep":
  menu_line("会在草场吃草；剪毛后变短毛，照料约 24 小时重新长齐。")
  menu_button("使用剪刀剪毛"+(" · 已长齐" if a.ready>0 else " · 羊毛仍在生长"),func():perform(sim.animal_action(id));show_animal(id))
 else:
  menu_line("当前约 %d kg；吃猪饲料育肥，成年约 100 kg 后可出售。"%sim.livestock.weight(a))
  menu_button("出售这只成年猪 · 90 币",func():perform(sim.sell_pig(id));close_menu())
 menu_line("同圈两只成年动物都喂食、食水充足且靠近后繁殖。")
 menu_line("出生后休息 6 小时。奶桶和剪刀为测试赠送。")
func show_pen(kind:String):
 open_menu="pen";clear_menu(Herd.NAMES[kind]+"圈舍")
 var p:Dictionary=sim.livestock.data.pens[kind];var count=maxi(1,sim.livestock.members(kind).size())
 menu_line("当前 %d 只 · 食槽可供 %.1f 小时 · 水槽 %.1f 小时"%[sim.livestock.members(kind).size(),p.feed/count/3600,p.water/count/3600])
 menu_button("食槽加"+("干草" if kind!="pig" else "猪饲料")+" ×1",func():perform(sim.livestock.feed_pen(kind,sim.data.bag));show_pen(kind))
 menu_button("给水槽加满饮水（免费）",func():perform(sim.livestock.water_pen(kind));show_pen(kind))
 if kind=="sheep":menu_line("草场另有约 %.1f 小时牧草，会缓慢再生；牧草也能喂羊。"%(p.grass/count/3600))
 if kind=="pig":
  menu_line("脏污 %d%%：超过 80%% 时育肥变慢。"%int(p.dirt))
  menu_button("清理猪圈",func():perform(sim.livestock.clean_pen(kind));show_pen(kind))
 menu_line("不同圈舍的饲料和饮水独立，不会互相挪用。")

func show_villager(role:int):
 if role==0:
  open_menu="villager";clear_menu("团团 · 村庄向导");menu_line("种子去青芽种子店，幼崽和饲料去牧铃牲畜店。两个店门都可以直接走进去。");menu_button("查看乡村地图",show_map);return
 open_menu="villager";clear_menu("团团 · "+Villagers.ROLES[role])
 if role==1:
  menu_line("先播种，再浇水。白菜照料 20 分钟就能收获。")
  menu_line("一格一株；成熟会一直等你，收获还会留下种子。")
  menu_line("牧场的牛羊爱小麦，猪爱胡萝卜；按 Q 拿在手上。")
 else:
  menu_line("鱼塘先放鱼苗，再投喂鱼饲料；长成后到码头收鱼。")
  menu_line("这里的天色跟随现实，生产进度单独加快。")
  menu_line("想快速验收就按 F10；不会改动现实时间。")
 menu_button("看看乡村地图",show_map)


func world_bounds()->Rect2:
 return Rect2(0,0,2048,1536) if map_id=="village" else WORLD
func blocked(p:Vector2)->bool:
 if not world_bounds().grow(-20).has_point(p):return true
 if rooms!=null and rooms.contains(map_id) and not Rooms.FLOOR.grow(-8).has_point(p):return true
 for box in solids:
  if box.grow(6).has_point(p):return true
 return map_id=="pond" and is_instance_valid(living_pond) and living_pond.blocks(p)
func update_camera(instant=false):
 var bounds=Rect2(112,90,1056,578) if rooms.contains(map_id) else world_bounds()
 # Derive the visible world extent from this viewport, including non-default zoom.
 var extent=get_viewport_rect().size
 var fit=maxf(extent.x/bounds.size.x,extent.y/bounds.size.y)
 camera.zoom=camera.zoom.max(Vector2.ONE*fit)
 var half=extent/camera.zoom*0.5
 var target=player.position+Vector2(0,-65 if rooms!=null and rooms.contains(map_id) else -125)
 target.x=clampf(target.x,bounds.position.x+half.x,bounds.end.x-half.x);target.y=clampf(target.y,bounds.position.y+half.y,bounds.end.y-half.y)
 camera.position=target.round() if instant else camera.position.lerp(target,0.16).round()
 camera.limit_left=int(bounds.position.x);camera.limit_top=int(bounds.position.y)
 camera.limit_right=int(bounds.end.x);camera.limit_bottom=int(bounds.end.y)
 camera.enabled=true;camera.force_update_scroll()

func make_region_edges(id:String):
 # Deliberate woodland belts close formerly empty margins; all region exits stay open.
 var rng=RandomNumberGenerator.new();rng.seed=8137+id.length()
 var points=[]
 for y in range(150,880,78):
  for x in [55,135,1200]:points.append(Vector2(x+rng.randf_range(-18,18),y+rng.randf_range(-20,20)))
 for x in range(200,1190,95):
  points.append(Vector2(x,145+rng.randf_range(-18,18)))
  points.append(Vector2(x,870+rng.randf_range(-12,12)))
 for p in points:
  var near_exit=false
  for link in LINKS[id]:
   if p.distance_to(link[1])<105:near_exit=true
  if near_exit:continue
  var kind=rng.randi_range(0,3);var w=rng.randi_range(116,158)
  var tree=object(tree_texture[kind],p,w,Rect2(-9,-6,18,12),true,"tree")
  trees.append({"sprite":tree,"base":p,"width":w,"kind":kind})
 # Turn the west-side void into a sheltered work clearing, connected to the field lane.
 if id=="field":
  object(structures[1],Vector2(340,580),125,Rect2(-48,-32,96,32))
  object(structures[3],Vector2(410,610),52,Rect2(-20,-16,40,16))
  for i in 6:object(prop_texture[0],Vector2(285+i*30,685),35,Rect2(-8,-4,16,8))
  for i in 5:object(prop_texture[1],Vector2(270,520+i*28),29,Rect2(-7,-4,14,8))
 elif id=="pond":
  object(prop_texture[3],Vector2(215,540),58,Rect2(-24,-8,48,14))
  for i in 6:object(prop_texture[1],Vector2(150+i*22,575),31,Rect2(-7,-4,14,8))
func set_light(value:float):
 super.set_light(value)
 if rooms!=null and rooms.contains(map_id):
  lighting_label="室内暖光"
  for material in surfaces:
   material.set_shader_parameter("sky_tint",Color(1.0,0.97,0.9));material.set_shader_parameter("light_strength",0.12);material.set_shader_parameter("night_level",0.0)

func make_ground():
 var floor_=Polygon2D.new();floor_.polygon=PackedVector2Array([Vector2.ZERO,Vector2(1280,0),Vector2(1280,900),Vector2(0,900)])
 ground_material=ShaderMaterial.new();ground_material.shader=preload("res://qingxi-live/classic-regions/ground.gdshader")
 for pair in [["grass_tex","ground-grass"],["dirt_tex","ground-sand"],["stone_tex","ground-path"]]:
  var image=Image.load_from_file("res://qingxi-live/classic-regions/art/"+pair[1]+".png");ground_material.set_shader_parameter(pair[0],ImageTexture.create_from_image(image))
 ground_material.set_shader_parameter("paving",1.0 if map_id=="village" else 0.0)
 floor_.material=ground_material;floor_.z_index=-10;add_child(floor_)
