extends Node2D
## Night fireflies: tiny additive sparks that drift and blink near the water and groves.
var lighting
var points=[]
func _ready():
 var m=CanvasItemMaterial.new();m.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;material=m;z_index=1
func _draw():
 if lighting==null or lighting.lamp_on<.3:return
 var t=lighting.clock;var a=clampf((lighting.lamp_on-.3)/.5,0,1)
 for i in points.size():
  var base:Vector2=points[i]
  var p=base+Vector2(sin(t*.6+i*1.7)*26,cos(t*.45+i*2.3)*16+sin(t*1.3+i)*6)
  var blink=clampf(sin(t*2.2+i*4.1)*1.6-.2,0,1)*a
  if blink<=0:continue
  p=p.snapped(Vector2(2,2))
  draw_rect(Rect2(p-Vector2(5,5),Vector2(10,10)),Color(.45,.6,.1,.18*blink))
  draw_rect(Rect2(p-Vector2(3,3),Vector2(6,6)),Color(.7,.9,.25,.35*blink))
  draw_rect(Rect2(p-Vector2(1,1),Vector2(2,2)),Color(1,1,.6,blink))
