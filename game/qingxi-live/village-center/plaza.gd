extends RefCounted
const PAVING=Rect2(704,576,960,704)
const CORNER_RADIUS=24.0
const BENCHES=[Vector2(960,800),Vector2(1280,800),Vector2(960,1152),Vector2(1280,1152),Vector2(1472,1088)]
const LAMPS=[Vector2(800,736),Vector2(1440,736),Vector2(800,1152),Vector2(1568,1152)]
var world
var floor_material:ShaderMaterial
var lamp_sprites=[]
var furniture=[]
var rope:Node2D
var seat_index=-1
var stand_point=Vector2.ZERO
var eat_timer=0.0
var modes=[-1,-1,-1,-1]
func _init(host):world=host
func build():
 if world.sim.data.has("festival_lamps") and world.sim.data.festival_lamps.size()==4:modes=world.sim.data.festival_lamps.duplicate()
 var source=Image.load_from_file("res://qingxi-live/village-center/art/festival-props.png")
 var regions=[Rect2i(0,0,660,600),Rect2i(680,0,600,600),Rect2i(0,600,680,600),Rect2i(690,600,590,600)]
 var art=[]
 for rect in regions:art.append(ImageTexture.create_from_image(world.trim_image(source.get_region(rect))))
 var floor_=Polygon2D.new();floor_.polygon=PackedVector2Array([PAVING.position,Vector2(PAVING.end.x,PAVING.position.y),PAVING.end,Vector2(PAVING.position.x,PAVING.end.y)]);floor_.z_index=-9;world.map_layer.add_child(floor_)
 floor_material=ShaderMaterial.new();floor_material.shader=preload("res://qingxi-live/village-center/plaza_floor.gdshader");floor_material.set_shader_parameter("stone_tex",world.terrain_parts[2]);floor_.material=floor_material
 floor_material.set_shader_parameter("paving_rect",Vector4(PAVING.position.x,PAVING.position.y,PAVING.size.x,PAVING.size.y))
 world.surfaces.append(floor_material)
 for i in BENCHES.size():
  var p=BENCHES[i];furniture.append(world.object(art[0],p,128,Rect2(-64,-32,128,32)))
  world.add_target("bench",p+Vector2(0,29),"长凳 · 坐下",str(i))
 for i in LAMPS.size():
  var p=LAMPS[i];var sprite=world.object(art[1],p,64,Rect2(-10,-12,20,12))
  furniture.append(sprite)
  sprite.material.set_shader_parameter("festival_lamp",1.0);lamp_sprites.append(sprite)
  world.add_target("lamp",p+Vector2(0,25),"灯柱 · 开关与自动夜灯",str(i))
 furniture.append(world.object(art[2],Vector2(1472,992),160,Rect2(-80,-32,160,32)))
 world.add_target("refreshment",Vector2(1472,1030),"茶点桌 · 坐下吃点心")
 furniture.append(world.object(art[3],Vector2(800,928),128,Rect2(-48,-24,96,24)))
 world.add_target("notice",Vector2(800,959),"公告板 · 广场晚会")
 rope=Node2D.new();world.map_layer.add_child(rope)
 var line=Line2D.new();line.width=1.5;line.default_color=Color("785541");rope.add_child(line)
 for i in 49:
  var t=float(i)/48;line.add_point(Vector2(800+640*t,634+sin(t*PI)*42))
 for i in range(1,16):
  var t=float(i)/16;var p=Vector2(800+640*t,634+sin(t*PI)*42)
  var flag=Polygon2D.new();flag.polygon=PackedVector2Array([p-Vector2(8,0),p+Vector2(8,0),p+Vector2(1,16)])
  flag.color=[Color("d7aa72"),Color("8caca0"),Color("bc7c66")][i%3];rope.add_child(flag)

static func paved_contains(point:Vector2,margin:float=0.0)->bool:
 var inner=PAVING.grow(-CORNER_RADIUS)
 var nearest=Vector2(clampf(point.x,inner.position.x,inner.end.x),clampf(point.y,inner.position.y,inner.end.y))
 return point.distance_to(nearest)<=CORNER_RADIUS-margin

func lighting(power:float):
 var levels=Color(0,0,0,0)
 for i in 4:
  levels[i]=power if modes[i]<0 else float(modes[i])
  lamp_sprites[i].material.set_shader_parameter("lamp_glow",levels[i])
 var positions=PackedVector2Array(LAMPS)
 for m in world.surfaces:
  m.set_shader_parameter("lantern_positions",positions);m.set_shader_parameter("lantern_power",levels)
 world.ground_material.set_shader_parameter("lantern_positions",positions);world.ground_material.set_shader_parameter("lantern_power",levels)
 rope.modulate=world.ground_tint

func set_lamp(index:int,value:int):
 modes[index]=value;world.sim.data.festival_lamps=modes.duplicate();world.save_progress();lighting(world.campfire.power)
 show_lamp(index)
func show_lamp(index:int):
 world.clear_menu("广场灯柱")
 world.menu_line("当前："+({-1:"随昼夜自动开关",0:"已手动关闭",1:"已手动打开"}[modes[index]]))
 world.menu_button("打开这盏灯",func():set_lamp(index,1))
 world.menu_button("关闭这盏灯",func():set_lamp(index,0))
 world.menu_button("恢复自动夜灯",func():set_lamp(index,-1))

func sit(index:int)->bool:
 if index<0 or index>=BENCHES.size():return false
 if seat_index>=0:stand()
 var p=world.player.position
 if world.blocked(p):return false
 stand_point=p;seat_index=index;world.player.position=BENCHES[index]+Vector2(0,1)
 world.active_action="";world.contact_shadow.visible=false;pose();world.close_menu();return true
func stand():
 if seat_index<0:return
 world.player.position=stand_point;seat_index=-1;eat_timer=0;world.contact_shadow.visible=true;world.show_idle()
func pose():
 if seat_index<0:return
 var key="sit-south" if seat_index<2 or seat_index==4 else "sit-north"
 if eat_timer>0:key="meal-eat-south" if seat_index<2 or seat_index==4 else "meal-eat-north"
 world.show_action(key,fmod(world.elapsed,1.7));world.contact_shadow.visible=false
func tick(dt:float):
 eat_timer=maxf(0,eat_timer-dt)
 if seat_index>=0:pose();world.hint.text="E / 方向键 · 起身";world.status.text="围坐歇一会儿 · 晚上可以看团团跳舞"

func snack()->bool:
 if world.sim.data.coins<2:return false
 if not sit(4):return false
 world.sim.data.coins-=2;world.sim.data.energy=mini(100,int(world.sim.data.energy)+15)
 world.sim.data.festival_food_eaten=int(world.sim.data.get("festival_food_eaten",0))+1
 eat_timer=3.6;pose();world.save_progress();world.notify("吃一份点心 · 2 币，精力恢复 15");return true

func interact(kind:String,extra:String)->bool:
 match kind:
  "bench":sit(int(extra))
  "lamp":show_lamp(int(extra))
  "refreshment":
   world.clear_menu("广场茶点")
   world.menu_line("一份茶点 2 币，精力恢复 15；坐到旁边的长凳慢慢吃。")
   var b=world.button("坐下吃点心 · 2 币",snack);b.disabled=world.sim.data.coins<2;world.overlay_body.add_child(b)
  "notice":
   world.clear_menu("村中公告")
   world.menu_line("篝火晚会：每天 19:00 开始，清晨散场。")
   world.menu_line("舞圈留给跳舞；长凳可以坐，茶点桌供应点心。")
   world.menu_line("灯柱入夜自动亮，也可在灯柱前手动开关。")
   world.menu_line("西侧种子店 · 东侧畜牧铺 · 路口通往鱼塘、牧场和农田。")
  _:return false
 return true
