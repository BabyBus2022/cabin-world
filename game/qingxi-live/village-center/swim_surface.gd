extends Node2D
var axis=Vector2.DOWN
var phase=0.0
var moving=false

func _draw():
 for i in 2:
  var spread=19.0+i*7.0
  var ring=PackedVector2Array()
  for j in range(17):
   var angle=j*TAU/16
   ring.append((Vector2(cos(angle)*spread,sin(angle)*(4+i*2))-axis*i*6).snapped(Vector2(2,2)))
  draw_polyline(ring,Color(.82,.95,.92,.47-i*.15),2.0)
 if not moving:return
 var splash=sin(phase)
 var side=Vector2(-axis.y,axis.x)
 for sign_ in [-1,1]:
  var p=(axis*9+side*sign_*(17+absf(splash)*5)).snapped(Vector2(2,2))
  draw_rect(Rect2(p,Vector2(4,2)),Color(.83,.96,.96,.76))
  draw_rect(Rect2(p-axis*5+side*sign_*6,Vector2(2,2)),Color(.83,.96,.96,.53))

