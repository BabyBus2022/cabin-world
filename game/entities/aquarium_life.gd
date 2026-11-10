extends Node2D
## Fish are independent of the tank texture and move with their parent furniture.
var time:=0.0
var orange:Texture2D=preload("res://assets/seaside/fish-orange.png")
var blue:Texture2D=preload("res://assets/seaside/fish-blue.png")
var scene:=""
func _process(dt:float) -> void:time+=dt;queue_redraw()
func _draw() -> void:
	for i in 3:
		var phase:=time*.55+i*2.1
		var x:=48+sin(phase)*(26-i*3)
		var y:=36+cos(time*.35+i*1.7)*12
		var right:=cos(phase)>0
		draw_texture_rect(orange if i%2==0 else blue,Rect2(x+(11 if not right else 0),y,-11 if not right else 11,7),false)
	for i in 4:
		var rise:=fmod(time*.2+i*.25,1)
		draw_circle(Vector2(20+i*19+sin(time+i),57-rise*37),1,Color("b9f0f5a8"),false,.5)
	for actor in get_tree().get_nodes_in_group("world_residents"):
		if actor.scene_id==scene and actor._effect_active()=="fishfood":
			for i in 4:draw_rect(Rect2(24+i*13,24+fmod(time*7+i*5,20),1.5,1.5),Color("efc776"))
