extends Node2D
var world
var flames:Polygon2D
var base:Sprite2D
var clock=0.0
var power=0.0
var light_energy=0.0
var sparks=[]
func setup(host,p:Vector2):
 world=host;position=p
 var img=Image.load_from_file("res://qingxi-live/village-center/art/campfire-unlit.png")
 img=world.trim_image(img)
 base=Sprite2D.new();base.texture=ImageTexture.create_from_image(img);base.centered=false
 base.scale=Vector2.ONE*84.0/img.get_width();base.position=Vector2(-42,-img.get_height()*base.scale.y+19)
 base.material=world.light_material();add_child(base)
 flames=Polygon2D.new();flames.polygon=PackedVector2Array([Vector2(-33,-78),Vector2(33,-78),Vector2(33,-4),Vector2(-33,-4)])
 var white=Image.create(1,1,false,Image.FORMAT_RGBA8);white.fill(Color.WHITE);flames.texture=ImageTexture.create_from_image(white)
 flames.uv=PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
 var material_=ShaderMaterial.new();material_.shader=preload("res://qingxi-live/village-center/fire.gdshader");flames.material=material_;add_child(flames)
 for i in 7:
  var spark=Polygon2D.new();spark.polygon=PackedVector2Array([Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)])
  spark.color=Color("ffd68b");add_child(spark);sparks.append(spark)
 tick(0)
func night_strength(hour:float)->float:
 if hour>=18.5:return smoothstep(18.5,19.0,hour)
 if hour<=6.0:return 1.0-smoothstep(5.0,6.0,hour)
 return 0.0
func tick(dt:float):
 clock+=dt;power=night_strength(world.sky_value()*24.0)
 light_energy=power*(.92+.045*sin(clock*5.7)+.035*sin(clock*9.3+1.4))
 flames.visible=power>.001;flames.material.set_shader_parameter("fire_clock",clock);flames.material.set_shader_parameter("power",power)
 for i in sparks.size():
  var phase=fposmod(clock*.46+float(i)/sparks.size(),1.0)
  sparks[i].visible=power>.001
  sparks[i].position=Vector2(sin(phase*8+i*2)*12+sin(i*3.1)*8,-22-phase*88).snapped(Vector2(2,2))
  sparks[i].color.a=power*(1.0-phase)*.8
