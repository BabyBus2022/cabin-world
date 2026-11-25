extends "res://qingxi-live/village3d/village.gd"
const Plan=preload("res://qingxi-live/classic-outdoor/layout.gd")
const SAVE01="user://village-0.1-save.json"
var architecture
var landscape
var production
var active_spec={}
var targets=[]
var tutorial_view
var refresh_clock=0.0
var held_food=""
var art_style=0
var style_button:Button

func _ready():
 testing="--check-v01" in OS.get_cmdline_user_args() or "--capture-v01" in OS.get_cmdline_user_args() or get_tree().has_meta("test_v01")
 sim=preload("res://qingxi-live/classic-outdoor/state.gd").new()
 if not testing:sim.load_from(SAVE01);sim.settle()
 load_materials();make_light()
 for child in get_children():
  if child is DirectionalLight3D:sun=child
  if child is WorldEnvironment:ambient=child
 architecture=preload("res://qingxi-live/classic-outdoor/buildings.gd").new(self)
 landscape=preload("res://qingxi-live/classic-outdoor/landscape.gd").new(self);landscape.build()
 for spec in Plan.HOUSES:
  active_spec=spec;building_kind=spec.id
  var b=build_building(spec.at);b.spec=spec;buildings[spec.id]=b
  architecture.awning(b)
  var lamp=OmniLight3D.new();lamp.position=Vector3(0,2,spec.depth/2-.4);lamp.omni_range=7;lamp.light_color=Color("ffd8a0");b.root.add_child(lamp);lamps.append(lamp)
  if spec.id not in ["seed","livestock","fish"]:sign_at(spec.name,Vector3(0,2.8,spec.depth/2+.6),b.roof).font_size=25
 for p in Plan.SHEDS:
  var root=Node3D.new();root.position=p;add_child(root)
  architecture.exterior({"model":"shed","depth":3.03,"decorative":true},root)
  box(root,Vector3(0,1.6,0),Vector3(3.12,3.2,3.03),Color.WHITE,true).hide();decorative_centers.append(p)
 make_player();make_residents()
 for i in 2:
  var spec=Plan.HOUSES[i];var a=residents[i];a.name="团团 · "+("种子店主" if i==0 else "畜牧店主")
  a.body.position=spec.at+Vector3(1.3,.04,0);a.route=[Vector2(spec.at.x+1.3,spec.at.z),Vector2(spec.at.x+1.3,spec.at.z+1.2)]
 add_home_resident("fish","团团 · 鱼苗店主",0)
 residents[2].body.position=buildings.fish.origin+Vector3(1,.04,0);residents[2].route=[Vector2(29,-55),Vector2(29,-54)]
 add_home_resident("resident_a","团团 · 花篱住户",0);add_home_resident("resident_b","团团 · 溪风住户",0)
 for a in residents:
  for node in a.visual.get_children():
   if node is Label3D:node.text=a.name.trim_prefix("团团 · ")
 player.position=Plan.AREAS.village.at
 if not testing and sim.data.has("v01_position"):
  var p=sim.data.v01_position
  if p is Array and p.size()==3:player.position=Vector3(clampf(p[0],-80,80),clampf(p[1],0,LEVEL)+.04,clampf(p[2],-80,80))
 production=preload("res://qingxi-live/classic-outdoor/production.gd").new(self);production.build()
 targets.append({"kind":"guide","name":"村庄公告板","at":Vector3(-7,0,-3),"range":2.5})
 sim.data.map="village";view.pan_extent=Vector2(72,72);scene_title="小屋世界 · 村庄 0.1";compact_observers=true
 make_ui();make_village_ui();set_daylight();previous_position=player.position;update_view(1)
 pixel_world=preload("res://qingxi-live/village3d/pixel_world.gd").new();add_child(pixel_world);pixel_world.setup(self)
 tutorial_view=preload("res://qingxi-live/material-lab/tutorial_view.gd").new();add_child(tutorial_view);tutorial_view.setup(self)
 pixel_world.material_.shader=preload("res://qingxi-live/classic-outdoor/world_style.gdshader")
 pixel_world.material_.set_shader_parameter("actor_mask",pixel_world.mask_view.get_texture())
 pixel_world.material_.set_shader_parameter("world_image",tutorial_view.view.get_texture())
 style_button=Button.new();style_button.position=Vector2(575,8);style_button.add_theme_font_size_override("font_size",11)
 menu.get_parent().add_child(style_button);style_button.pressed.connect(show_styles);set_style(0)
 DisplayServer.window_set_title("小屋世界 · 村庄 0.1 · 01 像素童话")
 get_tree().auto_accept_quit=false
 say("欢迎来到村庄 · M 地图 / B 背包 / F10 测试工具")

func material(color:Color)->StandardMaterial3D:
 var key=color.to_html()
 if mat_cache.has(key):return mat_cache[key]
 var m=StandardMaterial3D.new();m.albedo_color=color.darkened(.12);m.roughness=1;m.metallic_specular=0;m.diffuse_mode=BaseMaterial3D.DIFFUSE_LAMBERT;mat_cache[key]=m;return m

func make_ui():
 var layer=CanvasLayer.new();layer.layer=1;add_child(layer)
 var panel=PanelContainer.new();panel.position=Vector2(8,8);layer.add_child(panel)
 var rows=VBoxContainer.new();panel.add_child(rows)
 var title=Label.new();title.text=scene_title;title.add_theme_font_size_override("font_size",14);rows.add_child(title)
 info=Label.new();info.add_theme_font_size_override("font_size",11);rows.add_child(info)
 var expand=Button.new();expand.text="视角与操作 ▾";expand.add_theme_font_size_override("font_size",10);rows.add_child(expand)
 var more=VBoxContainer.new();rows.add_child(more);more.hide();expand.pressed.connect(func():more.visible=not more.visible)
 var help=Label.new();help.text="WASD 行走 · Shift 快走\nE 互动 · C 种子 · R 脱困\nP 玩家 · O 居民 · F 自由观察";help.add_theme_font_size_override("font_size",10);more.add_child(help)
 var buttons=HBoxContainer.new();more.add_child(buttons)
 for entry in [["player","玩家"],["free","自由"],["floor0","一楼"],["floor1","二楼"]]:
  var b=Button.new();b.text=entry[1];b.add_theme_font_size_override("font_size",10);b.pressed.connect(func():set_view(entry[0]));buttons.add_child(b);view_buttons[entry[0]]=b
 for a in residents:
  var b=Button.new();b.text=a.name;b.add_theme_font_size_override("font_size",10);b.pressed.connect(func():set_view(a.id));more.add_child(b);resident_buttons.append(b)

func build_building(origin:Vector3)->Dictionary:
 building_parent=Node3D.new();building_parent.position=origin;add_child(building_parent);levels=[];tall_walls=[]
 for index in int(active_spec.floors):
  var g=Node3D.new();g.name="Floor%d"%index;g.position.y=index*LEVEL;building_parent.add_child(g);levels.append(g);tall_walls.append([]);make_structure(g,index)
 if active_spec.id=="home":make_stairs();architecture.furniture.home(levels)
 elif active_spec.id in ["seed","livestock","fish"]:architecture.shop_furniture(active_spec,levels[0])
 else:architecture.cottage_furniture(levels[0])
 var wing=null
 if active_spec.id=="home":wing=architecture.wing(building_parent)
 roofs=architecture.exterior(active_spec,building_parent)
 return {"root":building_parent,"origin":origin,"levels":levels.duplicate(),"walls":tall_walls.duplicate(),"roof":roofs,"wing":wing}

func make_structure(g:Node3D,index:int):
 if active_spec.id=="home":super.make_structure(g,index);return
 var w=float(active_spec.width)/2;var d=float(active_spec.depth)/2
 slab(g,Rect2(-w,-d,w*2,d*2))
 wall(g,Vector2(-w,-d),Vector2(w,-d),index);wall(g,Vector2(-w,-d),Vector2(-w,d),index);wall(g,Vector2(w,-d),Vector2(w,d),index)
 door_wall(g,Vector2(-w,d),Vector2(w,d),0,1.8,index)

func slab(parent:Node3D,rect:Rect2):
 var n=box(parent,Vector3(rect.get_center().x,-.11,rect.get_center().y),Vector3(rect.size.x,.22,rect.size.y),Color("cbb48c"),true)
 # A ground-level floor stays visible outside; upper slabs retain floor filtering.
 if parent.position.y<.1:n.reparent(building_parent)
 var z=rect.position.y+.48
 while z<rect.end.y:
  var seam=box(parent,Vector3(rect.get_center().x,.003,z),Vector3(rect.size.x,.006,.015),Color("bda77f"))
  if parent.position.y<.1:seam.reparent(building_parent)
  z+=.48

func door_wall(parent:Node3D,a:Vector2,b:Vector2,center:float,width_:float,index:int):
 if active_spec.get("id","")=="home" and index==0 and a==Vector2(-6,5) and b==Vector2(6,5):
  super.door_wall(parent,a,Vector2(-1.7,5),-3.5,1.5,index);super.door_wall(parent,Vector2(-1.7,5),b,center,width_,index)
 else:super.door_wall(parent,a,b,center,width_,index)

func which_house(p:Vector3)->String:
 for id in buildings:
  var b=buildings[id];var q=p-b.origin
  if absf(q.x)<b.spec.width/2-.05 and absf(q.z)<b.spec.depth/2-.05:return id
  if id=="home" and Rect2(-6,5,5,6).has_point(Vector2(q.x,q.z)):return id
 return ""

func track_actor(id:String,p:Vector3):
 var b=which_house(p);building_locations[id]=b;view.track(id,p-buildings[b].origin if b!="" else Vector3(1000,0,1000),b)
 view.states[id].inside=b!=""
 if b!="home":view.states[id].upper=false;view.states[id].shared_stair=false

func update_view(dt:float):
 if not is_instance_valid(info):return
 track_actor("player",player.position);var p=player.position;var name_="玩家"
 for a in residents:
  track_actor(a.id,a.body.position)
  if view.mode==view.Mode.RESIDENT and view.resident_id==a.id:p=a.body.position;name_=a.name
 var state=view.snapshot();var chosen=str(state.get("building",""))
 if view.mode==view.Mode.FREE and (chosen=="" or not buildings.has(chosen)):chosen="home";view.free_house=chosen;state=view.snapshot()
 if chosen!="" and buildings[chosen].spec.floors==1 and view.mode==view.Mode.FREE:view.free_floor=0;state=view.snapshot()
 in_house=state.inside;on_upper=state.upper
 for id in buildings:
  var b=buildings[id];var cut=id==chosen and in_house
  b.roof.visible=not cut;b.levels[0].visible=cut
  if b.levels.size()>1:b.levels[1].visible=cut and on_upper
  if b.wing!=null:b.wing.visible=cut and not on_upper
  for ws in b.walls:
   for mesh in ws:mesh.visible=not cut
 portrait.visible=view.actor_visible("player",in_house)
 for i in residents.size():
  var a=residents[i];a.visual.visible=view.actor_visible(a.id,in_house);resident_buttons[i].text="观察 · "+a.name
 var focus=p+Vector3(0,1.8,-1.8);var zoom=20.0
 if chosen!="" and in_house:
  var b=buildings[chosen];zoom=18.0 if chosen=="home" else 12.0;focus=b.origin+Vector3(0,2.7 if on_upper else .6,.8)
  if chosen=="home" and p.z>b.origin.z+5:focus=b.origin+Vector3(-2,.8,6)
  if view.mode==view.Mode.FREE:focus+=Vector3(view.free_focus.x,0,view.free_focus.y)
 focus.x=clampf(focus.x,-73,73);focus.z=clampf(focus.z,-73,73)
 camera.size=zoom if testing else lerpf(camera.size,zoom,minf(1,dt*5))
 camera_focus=focus if testing else camera_focus.lerp(focus,minf(1,dt*5));camera.position=camera_focus+Vector3(0,17,19);camera.look_at(camera_focus)
 info.text=("自由观察" if view.mode==view.Mode.FREE else "跟随 "+name_)+" · "+(buildings[chosen].spec.name+(" / 二楼" if on_upper else " / 一楼") if chosen!="" else Plan.AREAS[Plan.area(p)].name)
 view_buttons.player.disabled=view.mode==view.Mode.PLAYER;view_buttons.free.disabled=view.mode==view.Mode.FREE;view_buttons.floor1.disabled=chosen!="" and buildings[chosen].spec.floors==1
 for sprite in billboards:
  var delta=p-sprite.position;sprite.modulate.a=.4 if delta.z<0 and delta.z>-4 and absf(delta.x)<1.8 else 1

func _physics_process(dt:float):
 super._physics_process(dt)
 if production==null:return
 production.tick(dt);refresh_clock+=dt
 if refresh_clock>1:refresh_clock=0;production.refresh()

func closest_target()->Dictionary:
 var best={};var distance=INF
 for t in targets:
  var d=player.position.distance_to(t.at)
  if d<float(t.range) and d<distance:best=t;distance=d
 if production!=null:
  for id in production.animals:
   var a=production.animals[id];var d=player.position.distance_to(a.body.position)
   if d<1.8 and d<distance:best={"kind":"animal","id":id,"name":"照料动物"};distance=d
 return best
func interaction_hint()->String:
 if view.mode!=view.Mode.PLAYER:return "P 返回玩家 · O 切换居民 · F 自由观察"
 var id=which_house(player.position)
 if id in ["seed","livestock","fish"]:return "E 与店主交易 · 买入 / 出售 · B 背包"
 if id=="home":return "E 小屋生活 · 做饭 / 休息 / 储物"
 var t=closest_target()
 if not t.is_empty():return "E "+t.name+" · 当前种子："+sim.CROPS[sim.data.selected_crop].name
 return "WASD 行走 · Shift 快走 · M 地图 · B 背包 · C 种子 · L 光照 · F10 测试工具"
func interact():
 var id=which_house(player.position)
 if id in ["seed","livestock","fish"]:show_shop(id);return
 if id=="home":show_home();return
 var t=closest_target()
 if t.is_empty():
  for a in residents:
   if a.body.position.distance_to(player.position)<2:say(a.name+"：沿着小路走，田地在西边，牧场在东边，鱼塘在北边。");return
  return
 match t.kind:
  "crop":say(sim.crop_action(t.id));production.refresh()
  "pond":say(sim.pond_action());production.pond.splash()
  "pen":show_pen(t.id)
  "animal":show_animal(t.id)
  "guide":show_guide()
func show_shop(kind:String):
 var buying={"seed":["seed","wheat_seed","carrot_seed"],"livestock":["hay","pig_feed","wheat","carrot"],"fish":["fry","fish_feed"]}
 var selling={"seed":["veg","wheat","carrot"],"livestock":["milk","wool"],"fish":["fish"]}
 open_menu(buildings[kind].spec.name+" · %d 币"%sim.data.coins)
 for item in buying[kind]:menu_button(sim.label(item)+" · %d 币"%sim.price(item),func():say(sim.buy(item));show_shop(kind))
 if kind=="livestock":
  for animal in Sim.NAMES:menu_button("幼"+Sim.NAMES[animal]+" · %d 币"%Sim.ANIMAL_PRICE[animal],func():say(sim.buy_animal(animal));production.refresh_animals();show_shop(kind))
 menu_button("出售本店收购的产物",func():say(sim.sell_items(selling[kind]));show_shop(kind))
 if kind=="livestock":menu_button("出售成年猪 · 90 币",func():say(sim.sell_pig());production.refresh_animals();show_shop(kind))
func show_bag():
 open_menu("背包 · %d 币 · 体力 %d"%[sim.data.coins,sim.data.energy])
 for item in sim.data.bag:
  var label_=Label.new();label_.text=sim.label(item)+" ×%d"%sim.data.bag[item];label_.add_theme_font_size_override("font_size",11);menu_rows.add_child(label_)
func show_pen(kind:String):
 open_menu(Sim.NAMES[kind]+"圈 · %d / 6"%sim.livestock.members(kind).size())
 menu_button("补充饲料",func():say(sim.livestock.feed_pen(kind,sim.data.bag).replace("一天","约 2 小时")))
 menu_button("补充饮水",func():say(sim.livestock.water_pen(kind).replace("两天","约 4 小时")))
 menu_button("清理圈舍",func():say(sim.livestock.clean_pen(kind)))
 menu_button("拿出诱食 / 收起",func():held_food="" if held_food!="" else ("carrot" if kind=="pig" else "wheat");say("已收起诱食" if held_food=="" else "附近同类动物会跟随你手里的"+sim.label(held_food)))
func show_animal(id:String):
 open_menu("动物照料")
 menu_button("收取产物",func():say(sim.animal_action(id)))
 menu_button("喂零食（幼崽成长 / 成年繁育）",func():say(sim.livestock.treat(id,sim.data.bag)))
 menu_button("返回圈舍照料",func():
  for a in sim.livestock.data.herd:
   if a.id==id:show_pen(a.kind);return)
func show_guide():
 open_menu("村庄生活 · 初次体验")
 for entry in [["plant","播种并浇水"],["harvest","收获作物"],["sell","去相应商店出售产物"]]:menu_button(("✓ " if sim.data.guide_done.get(entry[0],false) else "○ ")+entry[1],func():pass)
 menu_button("生长时间：白菜 20 / 胡萝卜 25 / 小麦 30 分钟",func():pass)
 menu_button("幼牛 4 / 羊 2 / 猪 6 小时；鱼约 1 小时（需照料）",func():pass)
func show_map():
 open_menu("乡村地图 · 沿道路可达，也可快速前往")
 for id in Plan.AREAS:menu_button(Plan.AREAS[id].name,func():travel_region(id))
 for spec in Plan.HOUSES:menu_button(spec.name,func():set_view("player");player.position=spec.at+Vector3(0,.04,spec.depth/2+2);player.velocity=Vector3.ZERO;menu.hide())
func travel_region(id:String):
 if not Plan.AREAS.has(id):return
 set_view("player");player.position=Plan.AREAS[id].at;player.velocity=Vector3.ZERO;menu.hide();save_village()
func show_test_tools():
 open_menu("0.1 测试工具（会保存结果）")
 menu_button("当前区域快速成熟",func():say(sim.quick_grow(Plan.area(player.position)));production.refresh())
 menu_button("动物立即成年",func():say(sim.quick_grow("ranch"));production.refresh())
 menu_button("动物立即产出",func():say(sim.quick_produce()))
 menu_button("生产推进 1 小时",func():sim.advance(3600);production.refresh();say("生产推进 1 小时"))
 menu_button("补充测试物资",func():say(sim.supplies()))
 menu_button("切换晨 / 昼 / 昏 / 夜",func():light_mode=(light_mode+1)%4;set_daylight())
 menu_button("回到村中心（脱困）",func():travel_region("village"))
func show_styles():
 open_menu("画风比较 · 不改变人物动作和碰撞")
 for i in 3:menu_button(["原版像素光照","柔和漫画 · 收住亮部与碎点","彩铅涂绘 · 暖纸色与浅排线"][i],func():set_style(i);menu.hide())
func set_style(index:int):
 art_style=clampi(index,0,2)
 if is_instance_valid(style_button):style_button.text="01 像素童话"+([""," · 漫画滤镜"," · 彩铅滤镜"][art_style])
 pixel_world.material_.set_shader_parameter("style_mode",art_style)
func save_village():
 if testing or not is_instance_valid(player):return
 sim.settle();sim.data.v01_position=[player.position.x,player.position.y,player.position.z];sim.save_to(SAVE01)
func set_daylight():
 if not is_instance_valid(sun):return
 sun.rotation_degrees=Vector3([-25,-58,-18,-48][light_mode],[-60,-35,65,-40][light_mode],0)
 sun.light_color=[Color("ffedce"),Color("fff6e6"),Color("ffc391"),Color("a4b6de")][light_mode];sun.light_energy=[.7,.75,.65,.13][light_mode]
 ambient.environment.ambient_light_energy=[.3,.36,.26,.15][light_mode]
 for lamp in lamps:lamp.light_energy=.85 if light_mode==3 else .05
 if architecture!=null:
  for m in architecture.cache.values():m.set_shader_parameter("night_glow",.22 if light_mode==3 else 0.0)
func _unhandled_key_input(e:InputEvent):
 if not e.is_pressed() or e.is_echo():return
 match e.keycode:
  KEY_ESCAPE:
   if menu.visible:menu.hide()
   else:save_village();get_tree().quit()
  KEY_M:show_map()
  KEY_B:show_bag()
  KEY_F10:show_test_tools()
  KEY_L:light_mode=(light_mode+1)%4;set_daylight()
  KEY_P:set_view("player")
  KEY_F:set_view("free")
  KEY_1:set_view("floor0")
  KEY_2:set_view("floor1")
  KEY_O:
   var index=0
   for i in residents.size():
    if view.resident_id==residents[i].id:index=(i+1)%residents.size()
   set_view(residents[index].id)
  KEY_C:
   var kinds=sim.CROPS.keys();sim.data.selected_crop=kinds[(kinds.find(sim.data.selected_crop)+1)%kinds.size()];say("选择种子："+sim.CROPS[sim.data.selected_crop].name)
  KEY_E:
   if not menu.visible and view.mode==view.Mode.PLAYER:interact()
  KEY_R:travel_region("village")
  KEY_F6:say(sim.quick_grow(Plan.area(player.position)));production.refresh()
  KEY_F7:say(sim.quick_produce())
  KEY_F8:sim.advance(3600);production.refresh();say("生产推进 1 小时")
  KEY_F9:say(sim.supplies())

