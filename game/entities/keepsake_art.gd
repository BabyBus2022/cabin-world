extends Node2D
## Small decorations use data placement, never weather or navigation masks.
var scene:String=""
var timer:float=0
static var textures:Dictionary={}
const Keepsakes=preload("res://core/keepsakes.gd")
static func texture(file:String)->Texture2D:
	if not ResourceLoader.exists(file):return null
	if not textures.has(file):textures[file]=load(file)
	return textures[file]
func _process(delta:float)->void:
	timer+=delta
	if timer>=1:timer=0;queue_redraw()
func icon(file:String,rect:Rect2)->void:
	var art:Texture2D=texture(file)
	if art!=null:draw_texture_rect(art,rect,false)
func _draw()->void:
	var room:Dictionary=WorldData.scenes.get(scene,{})
	if room.is_empty():return
	var cal:Dictionary=Keepsakes.calendar(Economy.today())
	var locations:Dictionary=Keepsakes.data().get("decorationPositions",{})
	var point:Array=locations.get(scene,[])
	if point.size()==2 and Features.on("seasons"): ## seasons module, core/features.gd
		icon("res://assets/seasons/"+str(cal.season)+"-decoration.png",Rect2(point[0],point[1],28,28))
		if not cal.festivals.is_empty():icon("res://assets/festivals/"+str(cal.festivals[0].id)+"-decoration.png",Rect2(point[0]+32,point[1],28,28))
	for actor in Economy.people:
		var k:Dictionary=Keepsakes.state(Economy.people[actor])
		if Keepsakes.home(actor)==scene:
			if point.size()==2 and k.get("birthday","")==Economy.today().substr(5):icon("res://assets/festivals/birthday-decoration.png",Rect2(point[0]+64,point[1],28,28))
			var slots:Array=Keepsakes.data().wallSlots.get(scene,[])
			for key in k.wall:
				var index:int=int(key)
				if index<0 or index>=slots.size():continue
				var paintings:Array=k.paintings.filter(func(p):return p.id==k.wall[key])
				if paintings.is_empty():continue
				var r:Array=slots[index];var box:=Rect2(r[0],r[1],r[2],r[3])
				icon("res://assets/paintings/style-"+str(paintings[0].motif)+".png",box.grow(-4))
				icon("res://assets/paintings/frame-s.png",box)
			if k.get("frame",false) and k.wall.is_empty() and not slots.is_empty():
				var r:Array=slots[0];icon("res://assets/paintings/frame-s.png",Rect2(r[0],r[1],r[2],r[3]))
