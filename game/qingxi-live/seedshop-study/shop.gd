extends "res://qingxi-live/garden.gd"
## Independent classic-style shop. Reuses original CabinWorld art and furniture geometry.
# Connected rooms have a stepped outline, rather than a larger rectangular shell.
const ROOMS=[Rect2(32,336,704,320),Rect2(32,144,320,192),Rect2(352,208,384,128),Rect2(736,272,352,320),Rect2(256,656,320,96)]
const COUNTER=Vector2(576,344)
const SELLER=Vector2(576,284)
const START=Vector2(430,580)
const BODY=26.0
const STOCK={"seed":{"name":"白菜种子","price":2},"flower":{"name":"花种","price":3},"soil":{"name":"营养土","price":4}}
const DEMO_SAVE="user://seedshop-bitglow-study.json"
var classic=preload("res://qingxi-live/seedshop-study/classic_art.gd").new()
var rest_seat={}
var placements=[]
var placement_grid=false
var seated=false
var stand_point=Vector2.ZERO
var floor_layer:Node2D
var ambient:CanvasModulate
var lights=[]
var beams=[]
var lamp_switch=true
var preset=3
var shop_hud:Control
var info_line:Label
var prompt_line:Label
var menu:PanelContainer
var menu_body:VBoxContainer
var purse={"coins":160,"seed":0,"flower":0,"soil":0,"harvest":3}
var points=[]
var nearest=-1
var npc:Sprite2D
var npc_frames=[]
var windows=[]
var marker:Label
var test_mode=false
var study_font:FontFile
var pendants=[]
var cutaway_walls=[]
var nursery_pots=[]
var plant_watered=false
var room_line:Label
var hour=8.0
var cycle_running=true
var manual_lamps=false
var light_tick=0.0
var ground_shadows=[]
var floor_light_material:ShaderMaterial
var beam_material:ShaderMaterial
var clock_button:Button

func _ready():
 test_mode="--verify-study" in OS.get_cmdline_user_args() or "--capture-study" in OS.get_cmdline_user_args()
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 study_font=FontFile.new()
 study_font.load_dynamic_font("C:/Windows/Fonts/Deng.ttf")
 study_font.antialiasing=TextServer.FONT_ANTIALIASING_GRAY
 # Only the approved character pack is loaded; rejected village art is not used.
 load_character_assets()
 build_interior()
 make_actor();portrait.material=null;player.position=START;show_idle()
 build_hud();apply_time();update_camera(true)
 if not test_mode and FileAccess.file_exists(DEMO_SAVE):
  var saved=JSON.parse_string(FileAccess.get_file_as_string(DEMO_SAVE))
  if saved is Dictionary:
   for key in purse:
    if saved.has(key):purse[key]=maxi(0,int(saved[key]))
 refresh_wallet()
 if not get_tree().has_meta("qingxi_world_host"):DisplayServer.window_set_title("小屋世界 · 青芽种子店 · 专用家具试玩")   # 2026-11-19 Claude (Cabin World host): inside Cabin World this would touch the whole app
 print("SEEDSHOP_READY assets=seedshop-image-collection character=studio-whale isolated_save=true")
 if "--capture-study" in OS.get_cmdline_user_args():capture_study.call_deferred()
 if "--verify-study" in OS.get_cmdline_user_args():verify_study.call_deferred()

func ground_rect(rect:Rect2,color:Color):
 var q=Polygon2D.new();q.polygon=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]);q.color=color;floor_layer.add_child(q)

func classic_tile(file:String,region:Rect2i,area:Rect2,factor:float=.5):
 var tex=classic.texture(file,region)
 var step=Vector2(tex.get_size())*factor
 for y in range(int(area.position.y),int(area.end.y),int(step.y)):
  for x in range(int(area.position.x),int(area.end.x),int(step.x)):
   var q=Sprite2D.new();q.texture=tex;q.centered=false;q.position=Vector2(x,y);q.scale=Vector2.ONE*factor
   q.region_enabled=true;q.region_rect=Rect2(0,0,minf(tex.get_width(),(area.end.x-x)/factor),minf(tex.get_height(),(area.end.y-y)/factor));floor_layer.add_child(q)

func module_strip(name:String,box:Rect2,parent:Node):
 var tex=classic.texture("../specialized/"+name+".png")
 var width_=tex.get_width()*.5
 for x in range(int(box.position.x),int(box.end.x),int(width_)):
  var q=Sprite2D.new();q.texture=tex;q.centered=false;q.position=Vector2(x,box.position.y)
  q.scale=Vector2(.5,box.size.y/tex.get_height());q.region_enabled=true
  q.region_rect=Rect2(0,0,minf(tex.get_width(),(box.end.x-x)*2),tex.get_height());parent.add_child(q)

func rear_wall(x:float,y:float,width_:float):
 module_strip("wall",Rect2(x,y-90,width_,96),floor_layer)

func furnishing(id:String,face:String,p:Vector2)->Dictionary:
 var item=classic.furniture(id,face,p,scenery);solids.append(item.collision)
 placements.append({"id":id,"face":face,"position":p,"item":item})
 add_ground_shadow(item.collision)
 return item

func make_floor_material(is_beam=false)->ShaderMaterial:
 var mat=ShaderMaterial.new();mat.shader=preload("res://qingxi-live/seedshop-study/floor_light.gdshader")
 var bounds=PackedVector4Array()
 for r in ROOMS:bounds.append(Vector4(r.position.x,r.position.y,r.end.x,r.end.y))
 mat.set_shader_parameter("rooms",bounds);mat.set_shader_parameter("window_beam",is_beam)
 return mat

func add_ground_shadow(box:Rect2):
 var gradient=Gradient.new();gradient.offsets=PackedFloat32Array([0,.35,.72,1])
 gradient.colors=PackedColorArray([Color(1,1,1,.65),Color(1,1,1,.4),Color(1,1,1,.12),Color(1,1,1,0)])
 var tex=GradientTexture2D.new();tex.gradient=gradient;tex.width=128;tex.height=64
 tex.fill=GradientTexture2D.FILL_RADIAL;tex.fill_from=Vector2(.5,.5);tex.fill_to=Vector2(1,.5)
 var contact=Sprite2D.new();contact.texture=tex;contact.position=Vector2(box.get_center().x,box.end.y-2)
 contact.scale=Vector2((box.size.x+18)/128,maxf(12,box.size.y*.35)/64)
 contact.modulate=Color(.21,.17,.14,.4);contact.material=floor_light_material;shadow_root.add_child(contact)
 var layers=[]
 for i in 4:
  var shadow=Polygon2D.new();shadow.material=floor_light_material;shadow_root.add_child(shadow);layers.append(shadow)
 ground_shadows.append({"box":box,"layers":layers,"contact":contact})

func ornament(file:String,p:Vector2,height_:float,parent:Node=null)->Sprite2D:
 var tex=classic.texture(file+".png");var factor=height_/tex.get_height()
 var holder=Node2D.new();holder.position=p;scenery.add_child(holder)
 var sprite=classic.sprite(file+".png",holder,Vector2(-tex.get_width()*factor/2,-height_),Rect2i(),factor)
 if parent!=null:holder.reparent(parent,true)
 return sprite

func plaque(text_:String,p:Vector2,width_:float=84):
 var panel_=PanelContainer.new();panel_.position=p;panel_.custom_minimum_size=Vector2(width_,18)
 var style=panel();style.bg_color=Color("52402f");style.border_color=Color("c9a56b");panel_.add_theme_stylebox_override("panel",style)
 var l=label(text_,10,Color("f8e8bf"));l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;panel_.add_child(l);floor_layer.add_child(panel_)

func wall_segment(area:Rect2,height_:float=36):
 solids.append(area)
 var node=Node2D.new();node.position=area.position;node.z_index=8;add_child(node)
 if area.size.x<=8:
  var tex=classic.texture("../specialized/post.png")
  for y in range(-int(height_),int(area.size.y),80):
   var part=Sprite2D.new();part.texture=tex;part.centered=false;part.position=Vector2(-2,y);part.scale=Vector2(.5,.5)
   part.region_enabled=true;part.region_rect=Rect2(0,0,24,minf(160,(area.size.y-y)*2));node.add_child(part)
 else:
  module_strip("partition",Rect2(0,-height_,area.size.x,height_+area.size.y),node)
 cutaway_walls.append({"node":node,"area":area})

func add_window(p:Vector2):
 var s=classic.sprite("../lighting-refresh/window.png",floor_layer,p-Vector2(56,68))
 var mat=ShaderMaterial.new();mat.shader=preload("res://qingxi-live/seedshop-study/window_glass.gdshader");s.material=mat
 windows.append(s)

func build_interior():
 floor_layer=Node2D.new();floor_layer.z_index=-10;add_child(floor_layer)
 ground_rect(Rect2(-1000,-1000,3200,2600),Color("292d36"))
 for area in ROOMS:
  ground_rect(area.grow(8),Color("624633"))
  classic_tile("../lighting-refresh/ash-oak.png",Rect2i(),area)
 # The original tiled shop floor marks the potting room and recessed entrance.
 for area in [ROOMS[3],ROOMS[4]]:classic_tile("tile-floor.png",Rect2i(),area)
 scenery=Node2D.new();scenery.y_sort_enabled=true;add_child(scenery)
 shadow_root=Node2D.new();shadow_root.z_index=-8;add_child(shadow_root)
 floor_light_material=make_floor_material();beam_material=make_floor_material(true)
 rear_wall(32,144,320);rear_wall(352,208,384);rear_wall(736,272,352)
 wall_segment(Rect2(24,144,8,512));wall_segment(Rect2(1088,272,8,320))
 wall_segment(Rect2(344,144,8,64));wall_segment(Rect2(344,208,8,128))
 wall_segment(Rect2(32,336,112,8));wall_segment(Rect2(256,336,96,8))
 wall_segment(Rect2(736,272,8,152));wall_segment(Rect2(736,536,8,120))
 wall_segment(Rect2(736,592,352,8),14)
 wall_segment(Rect2(32,656,224,8),14);wall_segment(Rect2(576,656,160,8),14)
 wall_segment(Rect2(248,656,8,96));wall_segment(Rect2(576,656,8,96))
 wall_segment(Rect2(256,752,120,8),14);wall_segment(Rect2(488,752,88,8),14)
 for r in [Rect2(144,332,112,12),Rect2(732,424,12,112),Rect2(376,744,112,16)]:ground_rect(r,Color("ad794c"))
 # Seed archive: dedicated packet cabinets and a real seed-sorting station.
 furnishing("seedshop--design-03","S",Vector2(64,176))
 furnishing("seedshop--design-01","S",Vector2(224,176))
 furnishing("seedshop--design-13","S",Vector2(64,240))
 plaque("种子库 · 分装",Vector2(96,64),120)
 add_window(Vector2(671,204))
 plaque("青 芽 种 子 铺",Vector2(494,123),134)
 furnishing("seedshop--design-05","S",Vector2(448,304))
 # Islands are made for this shop: samples, envelopes and botanical packets.
 furnishing("seedshop--design-04","S",Vector2(96,400))
 furnishing("seedshop--design-18","S",Vector2(288,432))
 furnishing("seedshop--design-17","S",Vector2(256,368))
 furnishing("seedshop--design-23","S",Vector2(384,240))
 furnishing("seedshop--design-14","S",Vector2(608,560))
 furnishing("seedshop--design-22","S",Vector2(480,560))
 # Real east-facing sofa: use its original seat, approach and footprint data.
 var rug=classic.sprite("rug.png",floor_layer,Vector2(59,523));rug.scale=Vector2(.45,.45)
 rest_seat=furnishing("xiaojingyu-home--xj-sofa","E",Vector2(76,530))
 var tea=furnishing("xiaojingyu-home--xj-accessory_table","S",Vector2(194,575))
 ornament("tea",Vector2(225,577),19,tea.node)
 ornament("lamp",Vector2(54,548),53)
 ornament("plant-large",Vector2(61,400),57)
 # Nursery workbenches include seedling trays, soil, pots and watering tools.
 add_window(Vector2(816,268));add_window(Vector2(1007,268))
 plaque("育 苗 间",Vector2(884,190),90)
 furnishing("seedshop--design-11","S",Vector2(768,304))
 furnishing("seedshop--design-10","S",Vector2(960,304))
 var nursery=furnishing("seedshop--design-24","S",Vector2(832,432))
 nursery_pots.append(nursery.sprite)
 furnishing("seedshop--design-15","S",Vector2(1024,432))
 furnishing("seedshop--design-20","S",Vector2(960,528))
 furnishing("seedshop--design-19","S",Vector2(1024,528))
 furnishing("xiaojingyu-home--xj-desk-chair","E",Vector2(780,542))
 var tea2=furnishing("xiaojingyu-home--xj-accessory_table","S",Vector2(844,550))
 ornament("tea",Vector2(877,552),17,tea2.node)
 # Entrance is a vestibule, leaving its central passage completely open.
 furnishing("seedshop--design-21","S",Vector2(256,688))
 ornament("plant-large",Vector2(547,715),58)
 points=[{"p":Vector2(576,386),"name":"团团 · 买种子 / 出售收成","type":"shop"},{"p":Vector2(900,520),"name":"育苗间 · 浇水照料","type":"grow"},{"p":Vector2(652,642),"name":"打包台 · 查看背包","type":"bag"},{"p":Vector2(165,604),"name":"坐下歇一会儿","type":"rest"},{"p":Vector2(208,272),"name":"种子库 · 查看库存","type":"stock"}]
 points.append({"p":Vector2(512,608),"name":"种子目录 · 查看商品","type":"catalog"})
 points.append({"p":Vector2(160,480),"name":"种子陈列 · 查看分类","type":"sample"})
 var sheet=Image.load_from_file("res://qingxi-live/assets/tuantuan-villagers.png")
 var cell=Vector2i(sheet.get_width()/4,sheet.get_height()/3)
 for col in [0,3]:
  var im=sheet.get_region(Rect2i(Vector2i(col,0)*cell,cell));npc_frames.append(ImageTexture.create_from_image(trim_image(im)))
 var holder=Node2D.new();holder.position=SELLER;scenery.add_child(holder)
 npc=Sprite2D.new();npc.texture=npc_frames[0];npc.centered=false;npc.scale=Vector2.ONE*60/npc.texture.get_height();npc.position=Vector2(-npc.texture.get_width()*npc.scale.x/2,-60);holder.add_child(npc)
 ambient=CanvasModulate.new();add_child(ambient)
 for p in [Vector2(670,204),Vector2(816,272),Vector2(1007,272)]:
  var beam=Polygon2D.new();beam.position=p;beam.uv=PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
  beam.material=beam_material;beam.z_index=-9;add_child(beam);beams.append(beam)
 # Every room has its own overhead pool; the ambient preserves legibility.
 for p in [Vector2(200,255),Vector2(560,400),Vector2(260,540),Vector2(924,450),Vector2(430,710)]:
  var g=Gradient.new();g.offsets=PackedFloat32Array([0,.22,.65,1]);g.colors=PackedColorArray([Color(1,1,1,1),Color(1,1,1,.85),Color(1,1,1,.24),Color(1,1,1,0)])
  var tex=GradientTexture2D.new();tex.gradient=g;tex.width=256;tex.height=256;tex.fill=GradientTexture2D.FILL_RADIAL;tex.fill_from=Vector2(.5,.5);tex.fill_to=Vector2(1,.5)
  var light=PointLight2D.new();light.texture=tex;light.position=p-Vector2(0,196);light.texture_scale=1.8;light.color=Color("fff2d9");add_child(light);lights.append(light)
  var fixture=Node2D.new();fixture.position=p-Vector2(0,200);fixture.z_index=15;add_child(fixture)
  var cable=Line2D.new();cable.points=PackedVector2Array([Vector2(0,-25),Vector2(0,-7)]);cable.width=1.5;cable.default_color=Color("80736a");fixture.add_child(cable)
  var shade=Sprite2D.new();shade.texture=classic.texture("pendant.png");shade.scale=Vector2(.45,.45);fixture.add_child(shade)
  var g2=Gradient.new();g2.colors=PackedColorArray([Color(1,.96,.85,.12),Color(1,.96,.85,0)])
  var halo=GradientTexture2D.new();halo.width=64;halo.height=64;halo.gradient=g2;halo.fill=GradientTexture2D.FILL_RADIAL;halo.fill_from=Vector2(.5,.5);halo.fill_to=Vector2(1,.5)
  var glow=Sprite2D.new();glow.texture=halo;glow.position.y=4;fixture.add_child(glow)
  var mat=CanvasItemMaterial.new();mat.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;glow.material=mat
  pendants.append({"node":fixture,"shade":shade,"glow":glow})
 marker=label("E",12,Color("fff5d8"));marker.add_theme_color_override("font_outline_color",Color("634d40"));marker.add_theme_constant_override("outline_size",4);marker.z_index=20;add_child(marker)

func apply_elevation():
 var ratio=BODY/BODY_UNIT_ON_SCREEN
 portrait.scale*=ratio;portrait.position*=ratio;contact_shadow.scale=Vector2.ONE*ratio
 contact_shadow.position=Vector2.ZERO;contact_shadow.color=Color(0.20,0.17,0.24,.23)
func floor_height(_p:Vector2)->float:return 0.0
func blocked(p:Vector2)->bool:
 # Clearance is measured against the union, so shared thresholds stay open.
 for offset in [Vector2.ZERO,Vector2(-9,0),Vector2(9,0),Vector2(0,-9),Vector2(0,9)]:
  var inside=false
  for area in ROOMS:
   if area.has_point(p+offset):inside=true;break
  if not inside:return true
 for r in solids:
  if r.grow(9).has_point(p):return true
 return false
func update_camera(instant=false):
 var target=player.position+Vector2(0,-100)
 target.x=clampf(target.x,384,752);target.y=clampf(target.y,216,552)
 camera.position=target.round() if instant else camera.position.lerp(target,0.12).round()
 if is_instance_valid(room_line):room_line.text=room_name(player.position)
 update_cutaways(instant)

func update_cutaways(instant=false):
 for wall in cutaway_walls:
  var opacity=.23 if wall.area.grow(65).has_point(player.position) else 1.0
  wall.node.modulate.a=opacity if instant else lerpf(wall.node.modulate.a,opacity,.16)
 var actor_area=Rect2(player.position-Vector2(32,86),Vector2(64,90))
 for fixture in pendants:
  var overlaps=actor_area.intersects(Rect2(fixture.node.position-Vector2(20,30),Vector2(40,50)))
  fixture.node.modulate.a=.12 if overlaps else 1.0
func _draw():
 if not placement_grid:return
 for area in ROOMS:
  for x in range(int(area.position.x),int(area.end.x)+1,32):draw_line(Vector2(x,area.position.y),Vector2(x,area.end.y),Color(1,.95,.75,.4),1)
  for y in range(int(area.position.y),int(area.end.y)+1,32):draw_line(Vector2(area.position.x,y),Vector2(area.end.x,y),Color(1,.95,.75,.4),1)

func _physics_process(dt):
 if paused_for_capture:return
 elapsed+=dt
 if cycle_running:
  hour=fposmod(hour+dt*.1,24.0);light_tick+=dt
  if light_tick>=.1:light_tick=0;apply_time();refresh_wallet()
 if not menu.visible:
  var v=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
  if v!=Vector2.ZERO:
   if seated:leave_seat()
   active_action="";idle_elapsed=0;facing=(2 if v.x>0 else 1) if absf(v.x)>absf(v.y) else (0 if v.y>0 else 3)
   move_actor(v.normalized()*dt*(156 if Input.is_physical_key_pressed(KEY_SHIFT) else 105));animate_walk()
  elif seated:
   show_action("sit-east",fmod(elapsed,1.8));contact_shadow.visible=false
  elif active_action!="":
   action_elapsed+=dt
   if not show_action(active_action,action_elapsed):active_action=""
  else:show_idle()
 update_camera()
 nearest=-1;var distance=66.0
 for i in points.size():
  var d=player.position.distance_to(points[i].p)
  if d<distance:distance=d;nearest=i
 marker.visible=nearest>=0
 if nearest>=0:marker.position=points[nearest].p+Vector2(-4,-32)
 prompt_line.text=("E  "+str(points[nearest].name)) if nearest>=0 else "WASD / 方向键 行走   ·   Shift 快走   ·   E 互动   ·   R 回入口"
 if seated:prompt_line.text="E / 方向键  起身 · 原版沙发与右侧坐姿适配"
 if player.position.y>718 and absf(player.position.x-432)<60:prompt_line.text="店门 · 这版先试玩店内，村庄连接留待整体版本"
 npc.texture=npc_frames[1 if player.position.distance_to(COUNTER)<100 else 0]
func _unhandled_key_input(event):
 if not event is InputEventKey or not event.pressed or event.echo:return
 match event.physical_keycode:
  KEY_ESCAPE:
   if menu.visible:menu.hide()
   else:get_tree().quit()
  KEY_E:
   if seated:leave_seat()
   elif not menu.visible and nearest>=0:interact_point(str(points[nearest].type))
  KEY_B:open_bag()
  KEY_1:set_preset(0)
  KEY_2:set_preset(1)
  KEY_3:set_preset(2)
  KEY_4:set_preset(3)
  KEY_L:toggle_lamps()
  KEY_T:toggle_cycle()
  KEY_R:
   if seated:leave_seat()
   player.position=START;active_action="";show_idle();update_camera(true)
  KEY_H:shop_hud.visible=not shop_hud.visible
  KEY_G:placement_grid=not placement_grid;queue_redraw()

func room_name(p:Vector2)->String:
 if ROOMS[1].has_point(p):return "种子库 · 收藏与分装"
 if ROOMS[3].has_point(p):return "育苗间 · 窗边的绿色"
 if ROOMS[4].has_point(p):return "门厅 · 欢迎光临"
 return "售卖厅 · 随便逛逛"

func set_preset(value:int):
 preset=value;hour=[7.5,12.5,17.5,21.0][value];cycle_running=false;manual_lamps=false;apply_time();refresh_wallet()
func toggle_lamps():manual_lamps=true;lamp_switch=not lamp_switch;apply_time()
func toggle_cycle():cycle_running=not cycle_running;manual_lamps=false;apply_time();refresh_wallet()
func daylight_at(time:float)->float:return smoothstep(5.5,8.0,time)*(1.0-smoothstep(17.0,19.5,time))
func sky_color(time:float)->Color:
 var times=[0.0,5.0,7.5,12.5,16.0,18.0,20.0,24.0]
 var colors=[Color(.76,.78,.85),Color(.78,.81,.88),Color(.95,.96,1),Color(1,.99,.95),Color(1,.97,.90),Color(.98,.85,.76),Color(.76,.78,.85),Color(.76,.78,.85)]
 for i in range(times.size()-1):
  if time<=times[i+1]:return colors[i].lerp(colors[i+1],smoothstep(times[i],times[i+1],time))
 return colors[0]
func apply_time():
 var daylight=daylight_at(hour)
 var night=1.0-smoothstep(6.0,7.5,hour) if hour<12 else smoothstep(18.0,19.0,hour)
 if not manual_lamps:lamp_switch=night>.01
 var power=(1.0 if lamp_switch else 0.0) if manual_lamps else night
 ambient.color=sky_color(hour)
 if manual_lamps and not lamp_switch and daylight<.1:ambient.color=Color(.43,.46,.55)
 for light in lights:light.energy=.36*power
 var direction=lerpf(70,-70,clampf((hour-7)/11,0,1))
 var length_=lerpf(175,100,sin(clampf((hour-6)/13,0,1)*PI))
 for beam in beams:
  beam.visible=daylight>.01;beam.color=Color(.92,.97,1,.18*daylight) if hour<10 else (Color(1,.71,.39,.23*daylight) if hour>16 else Color(1,.98,.80,.13*daylight))
  beam.polygon=PackedVector2Array([Vector2(-43,0),Vector2(43,0),Vector2(47+direction,length_),Vector2(-47+direction,length_)])
 for window in windows:
  window.self_modulate=Color.WHITE
  var tint=Vector3(.25,.37,.62).lerp(Vector3(1,1,1),daylight)
  if hour>16 and hour<20:tint=tint.lerp(Vector3(1,.67,.40),sin((hour-16)/4*PI)*.55)
  window.material.set_shader_parameter("glass_tint",tint)
 for shadow in ground_shadows:
  var box:Rect2=shadow.box
  var offset=Vector2(direction*.23,lerpf(18,32,absf(direction)/70))
  for i in shadow.layers.size():
   var pad=float(i)*1.2
   var left=Vector2(box.position.x-pad,box.end.y-5);var right=Vector2(box.end.x+pad,box.end.y-5)
   shadow.layers[i].polygon=PackedVector2Array([left,right,right+offset+Vector2(pad,pad),left+offset+Vector2(-pad,pad)])
   shadow.layers[i].color=Color(.20,.18,.25,.032*daylight)
 for fixture in pendants:
  fixture.glow.visible=power>.01;fixture.glow.modulate.a=power
  fixture.shade.self_modulate=Color("b4a48d").lerp(Color("fff9e9"),power)

func label(text_:String,size_:int,color=Color("554a38"))->Label:
 var item=super.label(text_,size_,color)
 if study_font:item.add_theme_font_override("font",study_font)
 return item

func button(text_:String,fn:Callable)->Button:
 var item=super.button(text_,fn)
 if study_font:item.add_theme_font_override("font",study_font)
 return item

func panel()->StyleBoxFlat:
 var style=StyleBoxFlat.new();style.bg_color=Color(.97,.95,.86,.94);style.border_color=Color("ad9874");style.set_border_width_all(1);style.set_content_margin_all(4);return style

func build_hud():
 var layer=CanvasLayer.new();add_child(layer);shop_hud=Control.new();shop_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shop_hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(shop_hud)
 shop_hud.add_theme_font_override("font",study_font)
 var bar=PanelContainer.new();bar.position=Vector2(10,10);bar.custom_minimum_size=Vector2(250,24);bar.add_theme_stylebox_override("panel",panel());shop_hud.add_child(bar)
 var row=HBoxContainer.new();bar.add_child(row);row.add_child(label("青芽种子店",12));info_line=label("",10);info_line.size_flags_horizontal=Control.SIZE_EXPAND_FILL;info_line.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;row.add_child(info_line)
 room_line=label("",10);room_line.position=Vector2(14,43);room_line.add_theme_color_override("font_color",Color("f8efd7"));shop_hud.add_child(room_line)
 var tools=HBoxContainer.new();tools.position=Vector2(510,10);shop_hud.add_child(tools)
 tools.add_child(button("背包 B",open_bag));tools.add_child(button("光照",func():set_preset((preset+1)%4)))
 tools.add_child(button("吊灯 L",toggle_lamps));clock_button=button("昼夜 T",toggle_cycle);tools.add_child(clock_button)
 var bottom=PanelContainer.new();bottom.position=Vector2(10,400);bottom.custom_minimum_size=Vector2(748,22);bottom.add_theme_stylebox_override("panel",panel());shop_hud.add_child(bottom);prompt_line=label("",10);bottom.add_child(prompt_line)
 menu=PanelContainer.new();menu.position=Vector2(199,69);menu.custom_minimum_size=Vector2(370,0);menu.add_theme_stylebox_override("panel",panel());menu.visible=false;shop_hud.add_child(menu)
 menu_body=VBoxContainer.new();menu_body.add_theme_constant_override("separation",9);menu.add_child(menu_body)
func refresh_wallet():
 var period="清晨" if hour>=5.5 and hour<10 else ("白天" if hour>=10 and hour<16.5 else ("黄昏" if hour>=16.5 and hour<19.5 else "夜晚"))
 info_line.text="%s %02d:%02d · %d 币"%[period,int(hour),int(fmod(hour,1.0)*60),purse.coins]
 if is_instance_valid(clock_button):clock_button.text="暂停 T" if cycle_running else "昼夜 T"
func open_panel(title:String):
 for child in menu_body.get_children():menu_body.remove_child(child);child.queue_free()
 menu.show();var row=HBoxContainer.new();menu_body.add_child(row);var title_label=label(title,15);title_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(title_label);row.add_child(button("关闭",func():menu.hide()))
func interact_point(kind:String):
 match kind:
  "shop":open_shop()
  "bag":open_bag()
  "catalog":
   open_panel("青芽种子目录")
   for key in STOCK:menu_body.add_child(label("%s  ·  %d 币"%[STOCK[key].name,STOCK[key].price],12))
   menu_body.add_child(label("选好后去团团柜台购买。\n收获的白菜也可在柜台出售，每份 4 币。",11))
  "sample":
   open_panel("种子陈列")
   menu_body.add_child(label("阶梯架展示蔬菜、花卉和香草的种子包装。\n翻盖箱用于查看散装种子样本。\n\n这版试玩可购买白菜种子、花种和营养土；\n种植与成熟留在后续农田地图中进行。",11))
  "grow":
   plant_watered=true
   for pot in nursery_pots:pot.modulate=Color("e2f3dc")
   open_panel("育苗间 · 已浇水")
   menu_body.add_child(label("给窗边的幼苗补好水了。\n\n这里展示和照料幼苗；正式种植在农田进行。\n这版浇水只用于试玩互动，不计算成熟与产量。",11))
  "stock":
   open_panel("种子库 · 分装记录")
   menu_body.add_child(label("左架放蔬菜种子，右架放花种与香草种子。\n\n分装桌留在侧面，中间通路连接售卖厅。\n到团团的柜台可以购买和出售。",11))
  "rest":
   stand_point=player.position;seated=true
   var seat=rest_seat.view.seat
   player.position=rest_seat.origin+Vector2(seat.x,seat.y)
   player.z_index=1;show_action("sit-east",0);contact_shadow.visible=false
func leave_seat():
 seated=false;player.position=stand_point;player.z_index=0;contact_shadow.visible=true;show_idle()

func purchase(key:String)->bool:
 if not STOCK.has(key) or purse.coins<STOCK[key].price:return false
 purse.coins-=STOCK[key].price;purse[key]+=1;save_study();refresh_wallet();return true
func sell_harvest()->int:
 var earned=int(purse.harvest)*4;purse.coins+=earned;purse.harvest=0;save_study();refresh_wallet();return earned
func open_shop():
 open_panel("团团的种子铺")
 menu_body.add_child(label("挑一些种子吧，收获的蔬菜也可以卖给我。",11))
 for key in STOCK:
  var id=str(key);var b=button("%s   ·   %d 币    买一份"%[STOCK[id].name,STOCK[id].price],func():purchase(id);open_shop());b.disabled=purse.coins<STOCK[id].price;menu_body.add_child(b)
 var sell=button("出售白菜 ×%d   ·   每份 4 币"%purse.harvest,func():sell_harvest();open_shop());sell.disabled=purse.harvest==0;menu_body.add_child(sell)
 menu_body.add_child(label("试玩零钱 %d 币 · 独立保存，不影响正式游戏"%purse.coins,10))
func open_bag():
 open_panel("背包")
 for key in STOCK:menu_body.add_child(label("%s   ×%d"%[STOCK[key].name,purse[key]],12))
 menu_body.add_child(label("白菜   ×%d\n零钱   %d 币"%[purse.harvest,purse.coins],12))
func save_study():
 if test_mode:return
 var file=FileAccess.open(DEMO_SAVE,FileAccess.WRITE)
 if file:file.store_string(JSON.stringify(purse))

func verify_study():
 paused_for_capture=true
 var failures=[]
 var expected_rooms=[Rect2(32,336,704,320),Rect2(32,144,320,192),Rect2(352,208,384,128),Rect2(736,272,352,320),Rect2(256,656,320,96)]
 if ROOMS!=expected_rooms:failures.append("owner room geometry changed")
 for placed in placements:
  if not placed.id.begins_with("seedshop--"):continue
  var v=placed.item.view;var f=v.footprint;var at=placed.position-Vector2(0,16)
  if fmod(at.x,32)!=0 or fmod(at.y,32)!=0:failures.append("furniture off grid "+placed.id)
  if v.collision.w!=f.w*32 or v.collision.h!=f.h*32:failures.append("footprint mismatch "+placed.id)
  if placed.item.sprite.texture.get_size()*.5!=Vector2(v.art.w,v.art.h):failures.append("art scale mismatch "+placed.id)
  var occupied:Rect2=placed.item.collision
  for corner in [occupied.position+Vector2(.1,.1),occupied.end-Vector2(.1,.1),Vector2(occupied.position.x+.1,occupied.end.y-.1),Vector2(occupied.end.x-.1,occupied.position.y+.1)]:
   var inside=false
   for room in ROOMS:
    if room.has_point(corner):inside=true;break
   if not inside:failures.append("furniture outside rooms "+placed.id)
 for i in placements.size():
  var a=placements[i]
  if not a.id.begins_with("seedshop--design-"):continue
  for j in range(i+1,placements.size()):
   var b=placements[j]
   if b.id.begins_with("seedshop--design-") and a.item.collision.intersects(b.item.collision):failures.append("overlapping footprints "+a.id+" / "+b.id)
  if a.id=="seedshop--design-05" and SELLER.y-19>a.position.y+a.item.view.art.y:failures.append("counter covers seller face")

 if blocked(START):failures.append("spawn blocked")
 # Reachability checks include feet-radius clearance around every furniture group.
 var grid=AStarGrid2D.new();grid.region=Rect2i(0,0,140,98);grid.cell_size=Vector2(8,8);grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update()
 for y in 98:
  for x in 140:grid.set_point_solid(Vector2i(x,y),blocked(Vector2(x*8,y*8)))
 for point in points:
  var path=grid.get_point_path(Vector2i(START/8),Vector2i(point.p/8))
  if path.is_empty():failures.append("unreachable "+point.type)
  else:
   player.position=START
   for p in path:move_actor(p-player.position)
   if player.position.distance_to(point.p)>14:failures.append("movement blocked "+point.type)
 # Doorways must work in both directions, not just be visible openings.
 for passage in [[Vector2(200,320),Vector2(200,376)],[Vector2(700,480),Vector2(780,480)],[Vector2(430,624),Vector2(430,710)]]:
  for reverse in 2:
   player.position=passage[reverse];move_actor(passage[1-reverse]-player.position)
   if player.position.distance_to(passage[1-reverse])>1:failures.append("doorway crossing")
 for outside in [Vector2(900,660),Vector2(100,700),Vector2(900,220)]:
  if not blocked(outside):failures.append("escaped stepped outline")
 for fixture in pendants:
  var face_area=Rect2(SELLER-Vector2(25,62),Vector2(50,43))
  if face_area.intersects(Rect2(fixture.node.position-Vector2(17,17),Vector2(34,34))):failures.append("pendant covers seller")
 player.position=pendants[2].node.position+Vector2(0,45);update_cutaways(true)
 if pendants[2].node.modulate.a>.2:failures.append("pendant does not fade")
 player.position=Vector2(576,386);move_actor(Vector2(0,-100))
 if player.position.y<377:failures.append("walked through counter")
 player.position=START;show_idle();var h=visible_height()
 for direction in 4:
  var key="walk-%d"%direction;var t=0.0;var low=9.0;var high=0.0
  for duration in clips[key].durationsMs:
   show_action(key,t+float(duration)/2000.0);t+=float(duration)/1000.0
   var ratio=visible_height()/h;low=minf(low,ratio);high=maxf(high,ratio)
   var anchor=clips[key].sizeCalibration.anchor
   if (portrait.position+Vector2(anchor[0],anchor[1])*portrait.scale).length()>0.01:failures.append("anchor drift "+key)
  print("STUDY_WALK ",key," min=",low," max=",high)
  if low<.80 or high>1.20:failures.append("size discontinuity "+key)
 player.position=Vector2(165,604);interact_point("rest")
 if not seated or portrait.texture==idle_texture:failures.append("seat pose not applied")
 leave_seat()
 if blocked(player.position):failures.append("seat exit blocked")
 var before=purse.duplicate();purchase("seed")
 if purse.seed!=before.seed+1 or purse.coins!=before.coins-2:failures.append("purchase")
 purse.coins=0
 if purchase("seed"):failures.append("negative balance")
 purse=before;var earned=sell_harvest()
 if earned!=12 or purse.harvest!=0:failures.append("sale")
 purse=before
 open_shop();if not menu.visible:failures.append("shop UI")
 interact_point("stock");if not menu.visible:failures.append("stock UI")
 interact_point("catalog");if not menu.visible:failures.append("catalog UI")
 interact_point("sample");if not menu.visible:failures.append("sample UI")
 interact_point("grow");if not plant_watered:failures.append("nursery interaction")
 for value in 4:set_preset(value)
 manual_lamps=true
 lamp_switch=false;apply_time();var dark=ambient.color.r
 lamp_switch=true;apply_time()
 if ambient.color.r<.75 or ambient.color.r<=dark:failures.append("night light readability")
 print("SEEDSHOP_VERIFY ","PASS" if failures.is_empty() else "FAIL"," ",failures)
 get_tree().quit(0 if failures.is_empty() else 1)

func capture_study():
 paused_for_capture=true;player.position=Vector2(430,510);update_camera(true);show_idle()
 for value in [0,1,2,3]:
  set_preset(value)
  for i in 5:await get_tree().process_frame
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/seedshop-study/reports/"+["morning","day","sunset","night"][value]+".png"))
 set_preset(1)
 for shot in [{"name":"nursery","p":Vector2(908,520),"time":1},{"name":"archive","p":Vector2(208,272),"time":1},{"name":"entry","p":START,"time":1},{"name":"windows-night","p":Vector2(908,400),"time":3}]:
  set_preset(shot.time)
  player.position=shot.p;update_camera(true);show_idle()
  await get_tree().process_frame;await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/seedshop-study/reports/"+shot.name+".png"))
 # Overview is an inspection view, not the scale used for playing.
 set_preset(1)
 camera.zoom=Vector2(.62,.62);camera.position=Vector2(560,390);shop_hud.hide()
 await get_tree().process_frame;await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/seedshop-study/reports/overview.png"))
 camera.zoom=Vector2.ONE;shop_hud.show()
 player.position=Vector2(165,604);interact_point("rest");update_camera(true)
 await get_tree().process_frame;await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/seedshop-study/reports/seated.png"))
 leave_seat()
 set_preset(3);player.position=Vector2(576,386);update_camera(true);show_idle();open_shop()
 await get_tree().process_frame;await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://qingxi-live/seedshop-study/reports/shop.png"))
 print("SEEDSHOP_CAPTURE_PASS");get_tree().quit()
