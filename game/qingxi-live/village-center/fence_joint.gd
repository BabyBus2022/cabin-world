extends Node2D
## Each grid vertex carries one post. The four bits select half-rails to the neighboring posts.
const NORTH=1
const EAST=2
const SOUTH=4
const WEST=8
const DARK=Color("563428")
const SHADE=Color("925436")
const WOOD=Color("b97546")
const TOP=Color("dda269")
var connections=0

func _draw():
 if connections & NORTH:draw_arm(Vector2.UP)
 if connections & WEST:draw_arm(Vector2.LEFT)
 if connections & EAST:draw_arm(Vector2.RIGHT)
 draw_rect(Rect2(-8,-40,16,43),DARK)
 draw_rect(Rect2(-6,-37,12,36),WOOD)
 draw_rect(Rect2(-6,-37,3,35),TOP)
 draw_rect(Rect2(2,-36,4,35),SHADE)
 draw_rect(Rect2(-9,-41,18,8),DARK)
 draw_rect(Rect2(-7,-40,14,4),TOP)
 draw_rect(Rect2(-7,-36,14,2),WOOD)
 for y in [-26,-12]:
  draw_rect(Rect2(-3,y,4,4),DARK)
  draw_rect(Rect2(-3,y,2,2),TOP)
 if connections & SOUTH:draw_arm(Vector2.DOWN)

func draw_arm(direction:Vector2):
 for y in [-29,-15]:
  var from=Vector2(0,y)+direction*5
  var to=Vector2(0,y)+direction*32
  if direction.x==0:
   var x=-9 if y==-29 else 0
   var r=Rect2(Vector2(x,minf(from.y,to.y)),Vector2(9,absf(to.y-from.y)))
   draw_rect(r,DARK)
   draw_rect(Rect2(r.position+Vector2(1,0),Vector2(7,r.size.y)),SHADE)
   draw_rect(Rect2(r.position+Vector2(2,0),Vector2(3,r.size.y)),TOP)
  else:
   var r=Rect2(Vector2(minf(from.x,to.x),y),Vector2(absf(to.x-from.x),10))
   draw_rect(r,DARK)
   draw_rect(Rect2(r.position+Vector2(0,2),Vector2(r.size.x,6)),WOOD)
   draw_rect(Rect2(r.position+Vector2(0,2),Vector2(r.size.x,2)),TOP)

