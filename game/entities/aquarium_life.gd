extends Node2D
## Fish are independent of the tank texture and move with their parent furniture.
var time:=0.0
var orange:Texture2D=preload("res://assets/seaside/fish-orange.png")
var blue:Texture2D=preload("res://assets/seaside/fish-blue.png")
var scene:=""
var names:Control
const SPECIES:=["clown","tang","guppy","goldfish","betta","whale_toy"]
var fish_art:Array=[]
var name_timer:float=1
const Keepsakes=preload("res://core/keepsakes.gd")
func _ready()->void:
	for id in SPECIES:
		var file:String="res://assets/aquarium/fish-"+str(id)+".png"
		fish_art.append(load(file) if ResourceLoader.exists(file) else null)
	names=Control.new();names.position=Vector2(8,12);names.size=Vector2(86,55);names.mouse_filter=Control.MOUSE_FILTER_PASS;add_child(names)
func _process(dt:float) -> void:
	time+=dt;queue_redraw()
	name_timer+=dt
	if names!=null and name_timer>=1:
		name_timer=0
		var labels:PackedStringArray=[]
		for actor in Economy.people:
			if Keepsakes.home(actor)==scene:
				var fish:Dictionary=Economy.people[actor].get("keepsakes",{}).get("fish",{})
				for id in fish:labels.append(str(fish[id]))
		names.tooltip_text="鱼缸 · "+("、".join(labels) if not labels.is_empty() else "还没有给小鱼取名字，可在纪念册里记下")
func _draw() -> void:
	for i in 6:
		var phase:=time*.55+i*2.1
		var x:=48+sin(phase)*(26-i*3)
		var y:=26+(i%3)*10+cos(time*.35+i*1.7)*4
		var right:=cos(phase)>0
		var art:Texture2D=fish_art[i] if fish_art.size()>i else null
		if art!=null:
			draw_set_transform(Vector2(x+6,y+3),0,Vector2(1 if right else -1,1))
			draw_texture_rect_region(art,Rect2(-6,-3,12,6),Rect2((int(time/.15)%4)*32,0,32,16));draw_set_transform(Vector2.ZERO)
		elif i<3:draw_texture_rect(orange if i%2==0 else blue,Rect2(x+(11 if not right else 0),y,-11 if not right else 11,7),false)
	for i in 4:
		var rise:=fmod(time*.2+i*.25,1)
		draw_circle(Vector2(20+i*19+sin(time+i),57-rise*37),1,Color("b9f0f5a8"),false,.5)
	for actor in get_tree().get_nodes_in_group("world_residents"):
		if actor.scene_id==scene and actor._effect_active()=="fishfood":
			for i in 4:draw_rect(Rect2(24+i*13,24+fmod(time*7+i*5,20),1.5,1.5),Color("efc776"))
