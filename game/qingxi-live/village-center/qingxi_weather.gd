extends CanvasLayer
var world
var surface:Control
var time:=0.0
var weather:Dictionary={}
var rain_seeds=PackedVector4Array()
const NAMES={"light_rain":"小雨","heavy_rain":"大雨","cloudy":"阴","snow":"雪","clear":"晴"}

func setup(scene):
 world=scene
 var rng=RandomNumberGenerator.new()
 rng.seed=391739
 for i in 284:
  rain_seeds.append(Vector4(rng.randf(),rng.randf(),rng.randf(),rng.randf()))
 layer=0
 surface=Control.new();surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(surface);surface.draw.connect(paint)

func kind()->String:return str(weather.get("kind","unknown"))

func _process(dt:float):
 var host=get_tree().get_meta("qingxi_world_host",false)
 if not host:return
 weather=host.rural_weather()
 time+=dt
 surface.queue_redraw()

func paint():
 if world.is_barn_floor() or world.rooms.contains(world.map_id):return
 var state=kind()
 if state not in ["snow","cloudy","light_rain","heavy_rain"]:return
 var s=surface.size
 if s.x<1.0 or s.y<1.0:return
 var thick=state=="heavy_rain"
 var tint=Color(.39,.46,.54,.17)
 if state=="heavy_rain":tint=Color(.22,.34,.48,.28)
 if state=="light_rain":tint=Color(.38,.53,.63,.15)
 if state=="snow":tint=Color(.68,.80,.91,.23)
 surface.draw_rect(Rect2(Vector2.ZERO,s),tint)
 if state=="cloudy":return
 if state=="snow":
  for i in 155:
   var close=i%4==0
   var p=Vector2(fposmod(float(i)*73.1+sin(i+time*.9)*12,s.x),
    fposmod(float(i)*43.233+time*(11.0+float(i%5)*3.5),s.y)).floor()
   if close:
    surface.draw_rect(Rect2(p-Vector2.ONE,Vector2(4,4)),Color(.75,.86,.99,.27))
    surface.draw_rect(Rect2(p-Vector2(1,0),Vector2(4,2)),Color(.94,.98,1,.79))
   surface.draw_rect(Rect2(p,Vector2.ONE*(2 if close else 1)),Color(.96,.98,1,.90 if close else .65))
  return
 var speed=375.0 if thick else 235.0
 var wind=clampf(float(weather.get("wind",0.5)),.2,3.0)
 for i in (284 if thick else 118):
  var seed:Vector4=rain_seeds[i]
  var fall=time*speed*lerpf(.72,1.22,seed.z)/(s.y+18.)+seed.y
  var slant=wind*lerpf(.06,.16,seed.w)
  var y=lerpf(-9.,s.y+9.,fposmod(fall,1.))
  var x=fposmod((seed.x+floor(fall)*(.37+.39*seed.w))*s.x+y*slant,s.x)
  var length_px=lerpf(6.,15.,seed.z) if thick else lerpf(3.,8.,seed.z)
  var end=Vector2(x,y)-Vector2(slant,1.)*length_px
  var opacity=lerpf(.26,.57,seed.z) if thick else lerpf(.17,.39,seed.z)
  surface.draw_line(Vector2(x,y).floor(),end.floor(),Color(.68,.84,1.,opacity))

