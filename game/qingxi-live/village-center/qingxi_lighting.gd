extends Node2D
## 清溪村 time-of-day lighting, layered on top of the world (below labels/HUD):
##   1. multiply layer  - ambient colour of the hour; lamps, door lights and the bonfire cut warm pools
##   2. additive layer  - glow halos and dawn / golden-hour haze
##   3. fireflies       - small additive sparks by the water and groves at night
## It also drives the sun: cast shadows of houses, trees, the player and villagers
## turn with the hour, lengthen at sunrise/sunset and fade to faint moon shadows.
const KEYS=[
 # hour, ambient (multiply), haze (add), lamps 0..1, name
 [0.0,"3a4791","000008",1.0,"深夜"],
 [3.5,"35428c","000008",1.0,"凌晨"],
 [4.9,"55599e","04040c",1.0,"凌晨"],
 [5.7,"b4acd6","0e0a14",.7,"拂晓"],
 [6.5,"ffe4d6","120a08",.1,"日出"],
 [8.0,"f4f9ff","04080c",0.0,"清晨"],
 [12.0,"ffffff","000000",0.0,"正午"],
 [15.0,"fff7ea","060400",0.0,"午后"],
 [16.9,"ffe2bc","140800",0.0,"傍晚"],
 [18.1,"e6b2bf","10060c",.45,"黄昏"],
 [19.2,"7576c0","02020a",1.0,"入夜"],
 [21.0,"44529a","000008",1.0,"夜晚"],
 [24.0,"3a4791","000008",1.0,"深夜"],
]
const SHADOW_INK=Color(.27,.22,.50)
var world
var dark:Polygon2D
var glow:Polygon2D
var flies:Node2D
var lamp_on=0.0
var hour=12.0
var clock=0.0
var fly_points=[]
var label="正午"
func setup(host):
 world=host;z_index=5
 var rect=PackedVector2Array([Vector2(-200,-200),Vector2(5000,-200),Vector2(5000,3560),Vector2(-200,3560)])
 dark=layer(rect,"mul",false);dark.visibility_layer=2
 glow=layer(rect,"add",true);glow.visibility_layer=2
 if world.is_barn_floor() or world.in_interior() or world.rooms.contains(world.map_id):return
 flies=preload("res://qingxi-live/village-center/qingxi_fireflies.gd").new();flies.lighting=self;flies.visibility_layer=2;add_child(flies)
 var rng=RandomNumberGenerator.new();rng.seed=4417
 while fly_points.size()<46:
  var b=world.world_bounds()
  var p=Vector2(rng.randf_range(300,b.size.x-300),rng.randf_range(300,b.size.y-260))
  var near_water=world.ground_data().creek_clearance(p)<120 and not world.ground_data().water_blocks(p)
  if near_water or rng.randf()<.08:fly_points.append(p)
 flies.points=fly_points
func layer(rect:PackedVector2Array,blend:String,add:bool)->Polygon2D:
 # The blend mode lives in the shader's render_mode: qingxi_light_mul / qingxi_light_add.
 var node=Polygon2D.new();node.polygon=rect
 var m=ShaderMaterial.new();m.shader=load("res://qingxi-live/village-center/qingxi_light_%s.gdshader"%blend)
 m.set_shader_parameter("additive",add)
 node.material=m;add_child(node)
 return node
func key_at(h:float)->Dictionary:
 h=fposmod(h,24.0)
 var i=0
 while i<KEYS.size()-2 and h>float(KEYS[i+1][0]):i+=1
 var a=KEYS[i];var b=KEYS[i+1];var t=inverse_lerp(float(a[0]),float(b[0]),h)
 t=t*t*(3.0-2.0*t)
 return {"ambient":Color(a[1]).lerp(Color(b[1]),t),"haze":Color(a[2]).lerp(Color(b[2]),t),"lamps":lerpf(a[3],b[3],t),"name":a[4] if t<.5 else b[4]}
func apply(h:float):
 hour=fposmod(h,24.0)
 var k=key_at(hour);lamp_on=k.lamps;label=k.name
 # Indoors: warm and bright by day, cosy lamplight after dusk; no outdoor haze.
 if world.map_id in ["village_bath","village_store"]:
  k.ambient=Color.WHITE.lerp(Color("d4bfae"),lamp_on)
  k.haze=Color.BLACK
 elif world.rooms!=null and world.rooms.private_room(world.map_id):
  # Keep evening colour from the windows, while the occupied house has warm ambient lamplight.
  k.ambient=k.ambient.lerp(Color("d7c1ad"),lamp_on*.79)
  k.haze=k.haze.lerp(Color.BLACK,.6)
 elif world.in_interior():
  k.ambient=Color(1,.98,.94).lerp(Color("8a7a90"),lamp_on*.8);k.haze=Color.BLACK
 dark.material.set_shader_parameter("ambient",k.ambient)
 dark.material.set_shader_parameter("vignette",lerpf(.0,.22,lamp_on))
 glow.material.set_shader_parameter("haze",k.haze)
 # Hand the hour's colour to the light layers only: sprites keep their own palette.
 world.ground_tint=Color.WHITE;world.night_level=lamp_on;world.lighting_label=label
 var sun=sun_state(hour)
 for m in world.surfaces:
  m.set_shader_parameter("sky_tint",Color.WHITE);m.set_shader_parameter("night_level",lamp_on*.6)
  m.set_shader_parameter("sun_side",-sun.dir.x);m.set_shader_parameter("light_strength",lerpf(.55,.25,lamp_on))
  m.set_shader_parameter("sun_tint",Color(1.10,1.04,.92).lerp(Color(1.25,1.0,.78),sun.low));m.set_shader_parameter("shade_tint",Color(.74,.76,1.0))
 if world.in_interior():sun={"dir":Vector2(.2,.6).normalized(),"len":.12,"alpha":.12,"low":0.0}
 world.sun_dir=sun.dir;world.sun_len=sun.len;world.shadow_ink=Color(SHADOW_INK,sun.alpha)
 for item in world.cast_shadows:
  var points=PackedVector2Array()
  for q in item.outline:points.append((item.base+Vector2(q.x*item.width,0)-sun.dir*sun.len*q.y*item.height).snapped(Vector2(2,2)))
  item.polygon.polygon=points;item.polygon.color=world.shadow_ink
 update_lights()
## Sun from the east at 6:00 to the west at 18:00; shadows fall away from it and
## slightly south (toward the camera). Night keeps a faint, short moon shadow.
func sun_state(h:float)->Dictionary:
 var day=clampf((h-5.8)/12.6,0.0,1.0)
 var elevation=sin(day*PI)
 var up=h>5.8 and h<18.4
 if not up:return {"dir":Vector2(.35,.55).normalized(),"len":.28,"alpha":.13,"low":0.0}
 var a=day*PI
 var dir=Vector2(-cos(a)*1.0,.42).normalized()
 var low=pow(1.0-elevation,2.0)
 var fade=clampf(minf(h-5.8,18.4-h)/.7,0,1)
 return {"dir":dir,"len":.16+.72*low,"alpha":lerpf(.10,.20+.06*low,fade),"low":low}
func update_lights():
 var flick=sin(clock*11.0)*.5+sin(clock*17.3+1.2)*.3+sin(clock*5.1)*.2
 var pair=world.light_sources(lamp_on,flick)
 if pair.is_empty():return
 if is_instance_valid(world.placement):
  for lamp in world.placement.ranch_lamps.values():
   lamp.append_world_lights(pair[0],pair[1])
 push_lights(pair[0],pair[1])
## Village sources: bonfire, plaza lanterns, door and window light of every building.
func village_sources(flick:float)->Array:
 var list=[];var tints=[]
 var d=world.district
 if d==null:return [list,tints]
 if d.fire!=null and d.fire.lit:
  var flame:Vector2=d.fire.global_position+Vector2(0,-47)
  list.append(Vector4(flame.x,flame.y,490.+flick*8.,.86+flick*.032));tints.append(Vector4(1.,.77,.51,.42))
 for lamp in d.lamps:
  if not lamp.lit:continue
  var bulb=lamp.glass.to_global(Vector2(48,65))
  list.append(Vector4(bulb.x,bulb.y,182.,.85));tints.append(Vector4(1.,.88,.64,.66))
 for bulb in d.building_lamps:
  list.append(Vector4(bulb.x,bulb.y,116,.82*lamp_on));tints.append(Vector4(1.0,.87,.64,1))
 return [list,tints]
func push_lights(list:Array,tints:Array):
 # Only the sources near the camera; the shader loops over at most 40.
 var view=Rect2(world.camera.get_screen_center_position()-Vector2(900,600),Vector2(1800,1200))
 if world.camera.zoom.x<.9:view=Rect2(-400,-400,5600,4200)
 var keep=[];var keep_t=[]
 for i in list.size():
  if view.grow(list[i].z).has_point(Vector2(list[i].x,list[i].y)) and keep.size()<40:keep.append(list[i]);keep_t.append(tints[i])
 var count=keep.size()
 while keep.size()<40:keep.append(Vector4.ZERO);keep_t.append(Vector4.ZERO)
 for m in [dark.material,glow.material]:
  m.set_shader_parameter("lights",keep);m.set_shader_parameter("light_tints",keep_t);m.set_shader_parameter("light_count",count)
func _process(dt):
 clock+=dt
 update_lights()
 if is_instance_valid(flies):flies.queue_redraw()
 # Characters cast the same sun shadow as the scenery.
 if is_instance_valid(world.player) and world.has_meta("player_cast"):
  var s:Polygon2D=world.get_meta("player_cast")
  s.polygon=body_shadow(world.player.position,22,70);s.color=world.shadow_ink
func body_shadow(base:Vector2,width_:float,height:float)->PackedVector2Array:
 var tip=world.sun_dir*world.sun_len*height
 return PackedVector2Array([base+Vector2(-width_*.4,0),base+Vector2(width_*.4,0),base+tip+Vector2(width_*.32,0),base+tip+Vector2(-width_*.32,0)])
