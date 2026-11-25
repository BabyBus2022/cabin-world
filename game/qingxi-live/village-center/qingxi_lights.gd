extends Node2D
var district
func _draw():
 if district==null:return
 if district.fire.lit:pool(district.data.plaza,145,Color(1,.58,.20,.15))
func pool(p:Vector2,r:float,c:Color):
 for level in 3:
  var polygon=PackedVector2Array();var radius=r-float(level)*r*.23
  for i in 32:polygon.append((p+Vector2(cos(i*TAU/32),sin(i*TAU/32)*.65)*radius).snapped(Vector2(4,4)))
  draw_colored_polygon(polygon,c)
