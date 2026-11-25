extends Node2D
const ShoreArt=preload("res://qingxi-live/village-center/shore_art.gd")
var pond
func _draw():
	if pond==null:return
	var tint:Color=pond.world.ground_tint
	for i in range(1,pond.shore.size(),4):
		var edge:Vector2=pond.shore[i].lerp(pond.shore[(i+1)%pond.shore.size()],.45)
		var inward=edge.direction_to(pond.bank_center)
		ShoreArt.paint(self,"weeds",edge+inward*18,.75,Color(.54,.80,.75,.48)*tint)
	var fish=pond.world.sim.Fish.stock(pond.stock)
	for i in mini(fish.size(),pond.fish.size()):
		var motion:Dictionary=pond.fish[i]
		var center:Vector2=motion.pos
		var reach=pond.world.sim.Fish.pixels(fish[i])*.5+2.
		var along=Vector2.from_angle(motion.angle)*reach
		for shift in 10:
			if Geometry2D.is_point_in_polygon(center+along,pond.shore) and Geometry2D.is_point_in_polygon(center-along,pond.shore):break
			center=center.move_toward(pond.bank_center,reach*.2)
		pond.world.sim.Fish.draw_fish(self,fish[i],center,motion.angle,motion.phase,Color(0.77,0.91,0.92,0.88)*tint)
	for r in pond.ripples:
		if r.age<0:continue
		ShoreArt.ring(self,r.pos,5+r.age*14,r.age/3.,tint)
	for i in range(0,pond.shore.size(),3):
		var edge:Vector2=pond.shore[i]
		if pond.dock.has_area() and pond.dock.grow(32).has_point(edge):continue
		var inward=edge.direction_to(pond.bank_center)
		ShoreArt.paint(self,["reeds","stones","lilies"][i/3%3],edge+inward*(20 if i/3%3==2 else 2),.82,tint)
	# Baked maps paint their own reeds and dock.
	if pond.baked or pond.dock==Rect2():return
	# Bank clusters are placed deliberately, leaving the landing clear.
	for i in [0,3,7,10,12,16,19,22]:
		var p:Vector2=pond.SHORE[i]
		p+=(p-Vector2(744,447)).normalized()*10
		for j in 4:
			var b=p+Vector2(j*5-9,(j%2)*3)
			var sway=round(sin(pond.clock*0.8+i)*2)
			draw_line(b,b+Vector2(-3+sway,-13-j%3*3),Color("657c47")*tint,2)
			draw_line(b,b+Vector2(4+sway,-9-j%2*5),Color("85934d")*tint,2)
		for j in 2:
			var b=p+Vector2(j*13-7,4)
			draw_colored_polygon(PackedVector2Array([b+Vector2(-5,0),b+Vector2(-4,-4),b+Vector2(2,-5),b+Vector2(5,-2),b+Vector2(5,2),b+Vector2(-2,3)]),Color("a9ad91")*tint)
	# Walkable dock: one physical shape used by the collision query as well.
	var dock:Rect2=pond.DOCK
	draw_rect(Rect2(dock.position+Vector2(4,4),dock.size),Color(0.15,0.24,0.24,0.3))
	draw_rect(dock,Color("745c40")*tint)
	for y in range(int(dock.position.y)+2,int(dock.end.y),8):
		draw_rect(Rect2(dock.position.x+2,y,dock.size.x-4,6),Color("b59a65")*tint)
		draw_line(Vector2(dock.position.x+8,y+3),Vector2(dock.end.x-9,y+3),Color("a98b5a")*tint,1)
	for p in [dock.position+Vector2(1,7),dock.position+Vector2(dock.size.x-5,7),dock.end-Vector2(5,7),Vector2(dock.position.x+1,dock.end.y-7)]:
		draw_rect(Rect2(p-Vector2(0,5),Vector2(5,11)),Color("6b553c")*tint)
		draw_rect(Rect2(p-Vector2(0,6),Vector2(5,3)),Color("c4ac75")*tint)
