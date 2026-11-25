extends Node2D
const Sun=preload("res://core/daylight.gd")
const Loft=preload("res://qingxi-live/dorm_loft.gd")
const Glass=preload("res://qingxi-live/cottage_glass.gdshader")
const LOFT_PANES=[Rect2(555,119,101,91),Rect2(875,119,97,94),Rect2(169,252,103,87),Rect2(1392,524,73,107),Rect2(521,845,74,79),Rect2(649,845,165,79),Rect2(875,845,66,79)]
# Floor positions at the base of each window, width, and direction into the room.
const LOFT_CASTS=[[Vector2(505,237),77,1],[Vector2(774,237),73,1],[Vector2(176,331),68,1],[Vector2(1165,560),53,1],[Vector2(606,678),122,-1],[Vector2(462,678),42,-1],[Vector2(753,678),42,-1]]
static var mask:Texture2D
var world
var dorm:bool
var casts:Array
var glass:=ShaderMaterial.new()
var wait:=0.0
var light:Dictionary
var direct:=0.0
var weather_kind:=""
var diffuse:=Color.TRANSPARENT

func setup(scene,room:String):
 world=scene;dorm=room=="room_private_dorm";z_index=-5
 glass.shader=Glass
 if dorm:
  if not mask:
   var img:=Image.new()
   if img.load_png_from_buffer(FileAccess.get_file_as_bytes("res://qingxi-live/dorm-glass.png"))==OK:mask=ImageTexture.create_from_image(img)
  for pane in LOFT_PANES:
   var sprite:=Sprite2D.new()
   sprite.texture=mask;sprite.region_enabled=true;sprite.region_rect=pane
   sprite.centered=false;sprite.position=pane.position*5.0/6;sprite.scale=Vector2.ONE*5.0/6
   sprite.material=glass;add_child(sprite)
  casts=LOFT_CASTS
 else:
  for x in ([420,800] if room=="room_private_up" else [470,770]):
   for col in 2:
    for row in 2:
     var pane:=Polygon2D.new()
     var rect:=Rect2(x+2+col*32,207+row*18,28,14)
     pane.polygon=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
     pane.material=glass;add_child(pane)
   casts.append([Vector2(x+32,286),54,1])
 refresh()

func _process(dt):
 wait-=dt
 if wait<=0:
  wait=.75
  refresh()

func refresh():
 var host=world.time_host()
 var now:=Time.get_unix_time_from_system()*1000
 if host:now=get_node("/root/SharedFeed").now_ms()
 else:
  var difference:float=world.sky_value()*24-Sun.local_hour(now)
  now+=difference*3600000
 var weather:Dictionary=host.rural_weather() if host else {}
 light=Sun.reading(now)
 weather_kind=str(weather.get("kind","unknown"))
 var cloud:=float(weather.get("cloud",.4))
 var rain:=float(weather.get("rain",0))
 var snow:=weather_kind=="snow"
 direct=float(light.beamAlpha)*float(weather.get("sun",0.0))*(1.-smoothstep(.55,.84,cloud))
 var dark:=1.0-smoothstep(-9.,10.,float(light.elevation))
 var warmth:=1.0-smoothstep(4.,25.,float(light.elevation))
 var tint:=Color("ffa66a") if light.hour>12 else Color("ffc798")
 tint.a=warmth*(1-dark)*.37
 if snow:tint=Color(.80,.90,.99,.49)
 elif rain>0:tint=Color(.27,.37,.48,.33+rain*.24)
 elif weather_kind in ["cloudy","unknown"]:tint=Color(.48,.57,.65,.15+.21*cloud)
 tint=tint.lerp(Color(.045,.083,.18,.88),dark)
 glass.set_shader_parameter("sky_color",tint)
 glass.set_shader_parameter("rain",rain)
 glass.set_shader_parameter("snow",1. if snow else 0.)
 glass.set_shader_parameter("wind",float(weather.get("wind",0)))
 diffuse=Color(.75,.86,1.,(.115 if snow else .03*cloud)*(1.-dark))
 queue_redraw()

func _draw():
 if light.is_empty():return
 var rgb:Array=light.beam
 var beam:=Color.from_rgba8(int(rgb[0]),int(rgb[1]),int(rgb[2]))
 for cast in casts:
  var origin:Vector2=cast[0]
  var span:float=cast[1]
  var sign_y:float=cast[2]
  var ray:=Vector2(float(light.shift)*.70,float(light.length)*.64*sign_y)
  if dorm and origin.x>1000:ray=Vector2(-absf(ray.x)*.5-28,minf(ray.y,46))
  if dorm and origin.x<200:ray.y=minf(ray.y,85)
  if diffuse.a>.001:
   patch(origin,span,Vector2(0,42*sign_y),diffuse)
  if direct<.001:continue
  # Leave gaps for mullions and fade the projected panes at the far end.
  for col in 3:
   for row in 2:
    var near_:float=.12+row*.43
    var start:=origin+Vector2(span*(col/3.-.5),0)+ray*near_
    patch(start,span*.30,ray*.40,Color(beam,direct*(1.04-row*.21)),false)

func patch(start:Vector2,width_:float,ray:Vector2,color:Color,centered:=true):
 var p:=start-Vector2(width_*.5,0) if centered else start
 var q:=p+Vector2(width_,0)
 var end_color:=Color(color,color.a*.27)
 draw_polygon(PackedVector2Array([p,q,q+ray,p+ray]),PackedColorArray([color,color,end_color,end_color]))
