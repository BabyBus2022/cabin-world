extends Node2D
## Small native pixel prop; media remains on the host's existing playback path.
var scene := ""
var time := 0.0
var playing := false
func setup(id: String,layer: Dictionary) -> void:
	scene=id;position=Vector2(layer.x,layer.depth)
func _process(dt: float) -> void:
	time+=dt;playing=false
	for actor in get_tree().get_nodes_in_group("world_residents"):
		if actor._home.get("scene")!=scene:continue
		playing=playing or actor._items().get("audio")=="playing" or actor.body.get("computer",{}).get("screen")=="video" or (actor.scene_id==scene and actor._effect_active()=="headphones")
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(0,-22,14,22),Color("25334a"))
	draw_rect(Rect2(1,-21,12,20),Color("967252"))
	draw_rect(Rect2(3,-20,10,18),Color("25334a"))
	draw_circle(Vector2(8,-15),2,Color("8296ad"))
	draw_circle(Vector2(8,-7),4,Color("526980"))
	draw_circle(Vector2(8,-7),2,Color("202c40"))
	draw_rect(Rect2(11,-3,1,1),Color("87daca") if playing else Color("74817e"))
	if playing:
		var rise:=fmod(time,1.8)*5
		draw_line(Vector2(16,-17-rise),Vector2(16,-22-rise),Color("9bdce4"),1)
		draw_rect(Rect2(14,-18-rise,2,2),Color("9bdce4"))
