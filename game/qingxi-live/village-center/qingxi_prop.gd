extends Node2D
var kind=""
var size_=Vector2(80,40)
var lit=false
var phase=0
var textured=false
var flame_node
var glass:Sprite2D
func rect(x,y,w,h,c):draw_rect(Rect2(x,y,w,h),Color(c))
func _draw():
 if textured:return
 match kind:
  "flame":
   if lit:
    var sway=(phase-1)*4
    draw_colored_polygon(PackedVector2Array([Vector2(-18,-22),Vector2(-24,-34),Vector2(-16,-48),Vector2(-10,-40),Vector2(-6+sway,-62),Vector2(2,-50),Vector2(8+sway,-76),Vector2(16,-56),Vector2(12,-40),Vector2(22,-48),Vector2(24,-30),Vector2(16,-22)]),Color("e8823a"))
    draw_colored_polygon(PackedVector2Array([Vector2(-12,-22),Vector2(-14,-34),Vector2(-6,-46),Vector2(0,-38),Vector2(8,-56),Vector2(14,-34),Vector2(10,-22)]),Color("ffc977"))
  "bench":
   rect(-48,-8,8,10,"6b4a33");rect(40,-8,8,10,"6b4a33")
   rect(-56,-24,112,16,"6b4a33");rect(-54,-24,108,5,"b48a5e");rect(-54,-17,108,5,"a08a5e")
   rect(-52,-26,104,2,"d9bc8c")
  "lamp":
   rect(-10,-5,20,8,"8e8a7e");rect(-3,-92,6,90,"6b4a33");rect(-19,-95,38,5,"6b4a33")
   rect(-13,-86,26,28,"b48a5e");rect(-11,-84,22,24,"ffc977" if lit else "ede4d0")
   for y in [-80,-72,-64]:rect(-11,y,22,2,"c9a874")
   rect(-8,-56,16,3,"6b4a33")
  "fire":
   for i in 12:
    var p=Vector2(cos(i*TAU/12)*38,sin(i*TAU/12)*19).snapped(Vector2(2,2))
    draw_rect(Rect2(p-Vector2(7,5),Vector2(14,10)),Color("8e8a7e"));draw_rect(Rect2(p-Vector2(7,5),Vector2(12,4)),Color("b5ad9c"))
   draw_line(Vector2(-25,-6),Vector2(25,8),Color("6b4a33"),10);draw_line(Vector2(-25,8),Vector2(25,-6),Color("b48a5e"),8)
   if lit:
    for i in 5:
     var h=26+((i*13+phase*7)%23);rect(-20+i*8,-h,8,h,"e8823a");rect(-16+i*7,-h+10,6,h-10,"ffc977")
  "torii":
   rect(-60,-104,12,104,"b2573f");rect(48,-104,12,104,"b2573f");rect(-60,-104,4,98,"d2553a");rect(48,-104,4,98,"d2553a")
   rect(-80,-110,160,10,"3a2a22");rect(-76,-100,152,10,"d2553a");rect(-70,-75,140,8,"b2573f");rect(-9,-100,18,29,"6b4a33")
   rect(-65,-5,22,8,"a59e90");rect(43,-5,22,8,"a59e90")
  "wall":
   rect(-size_.x/2,-28,size_.x,28,"a59e90");rect(-size_.x/2,-48,size_.x,24,"ede4d0");rect(-size_.x/2-5,-54,size_.x+10,8,"4e5a68")
   for x in range(-int(size_.x/2),int(size_.x/2),40):rect(x,-28,2,28,"8e8a7e")
  "arcade":
   rect(-size_.x/2,-5,size_.x,5,"a59e90");rect(-size_.x/2,-16,size_.x,10,"b48a5e")
   for x in range(-int(size_.x/2),int(size_.x/2)+1,40):rect(x,-74,5,60,"6b4a33")
   rect(-size_.x/2-7,-88,size_.x+14,16,"4e5a68");rect(-size_.x/2-3,-88,size_.x+6,5,"6c7a89")
  "well":
   rect(-29,-25,58,25,"8e8a7e");rect(-33,-32,66,10,"b5ad9c");rect(-22,-27,44,10,"6d6a62")
   rect(-25,-68,6,50,"6b4a33");rect(19,-68,6,50,"6b4a33");rect(-34,-72,68,8,"b48a5e");rect(-2,-66,2,42,"d9bc8c")
  "board":
   rect(-40,-58,6,58,"6b4a33");rect(34,-58,6,58,"6b4a33");rect(-47,-72,94,52,"6b4a33");rect(-43,-68,86,44,"b48a5e")
   for x in [-34,-10,15]:rect(x,-62,18,30,"ede4d0");rect(x+3,-57,11,2,"8e8a7e");rect(x+3,-50,9,2,"8e8a7e")
   rect(-52,-78,104,7,"4e5a68")
  "mail":
   rect(-5,-25,10,25,"6b4a33");rect(-16,-62,32,38,"b2573f");rect(-13,-59,26,8,"d2553a");rect(-10,-49,20,4,"3a2a22");rect(-5,-38,10,6,"ede4d0")
  "jizo":
   rect(-15,-6,30,6,"8e8a7e");rect(-9,-28,18,22,"a59e90");rect(-7,-40,14,14,"b5ad9c");rect(-9,-26,18,5,"b2573f")
  "bus":
   rect(-70,-8,140,8,"a59e90");rect(-64,-78,6,70,"6b4a33");rect(58,-78,6,70,"6b4a33");rect(-64,-60,128,35,"b48a5e")
   rect(-75,-87,150,12,"6c7a89");rect(-70,-91,140,4,"9aa6b2");rect(-48,-26,96,9,"6b4a33");rect(-44,-17,5,10,"6b4a33");rect(39,-17,5,10,"6b4a33")
   rect(82,-75,4,75,"6b4a33");rect(73,-88,22,22,"ede4d0");rect(76,-85,16,5,"3e5a86");rect(80,-70,10,20,"ede4d0")
  "fence":
   for y in [-22,-12]:rect(-size_.x/2,y,size_.x,5,"b48a5e")
   for x in range(-int(size_.x/2),int(size_.x/2)+1,24):rect(x,-30,6,32,"6b4a33");rect(x,-30,4,25,"b48a5e")
  "jetty":
   rect(-size_.x/2,-size_.y,size_.x,size_.y,"6b4a33")
   for y in range(-int(size_.y)+2,0,8):rect(-size_.x/2+2,y,size_.x-4,6,"b48a5e")
  "flowers":
   for i in 80:
    var p=Vector2((i*37)%int(size_.x),(i*59)%int(size_.y))-size_/2
    draw_rect(Rect2(p,Vector2(2,6)),Color("6e9152"));draw_rect(Rect2(p-Vector2(2,2),Vector2(6,4)),[Color("f3e6a2"),Color("f2b8c6"),Color("e9eef5")][i%3])
