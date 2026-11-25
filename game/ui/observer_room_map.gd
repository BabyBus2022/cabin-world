extends Control
var game
var room_id:=""
var ground:Texture2D
var elapsed:=0.0

func setup(host):
	game=host
	size=Vector2(112,66)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	clip_contents=true
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST

func _process(dt):
	visible=game.observing and not game.qingxi_busy()
	if not visible:return
	position=game._view.position+Vector2(8,48)
	elapsed-=dt
	if room_id!=game.view_scene:
		room_id=game.view_scene
		var data:Dictionary=WorldData.layers.get(room_id,{}).get("ground",{})
		ground=load("res://assets/baked/"+str(data.file)) if data.has("file") else null
		elapsed=0
	if elapsed<=0:
		elapsed=.15
		queue_redraw()

func _draw():
	if not is_instance_valid(game) or not game.rooms.has(room_id):return
	var room=game.rooms[room_id]
	var extent:=Vector2(room.width,room.height)
	var k:=minf((size.x-8)/extent.x,(size.y-8)/extent.y)
	var frame:=Rect2((size-extent*k)*.5,extent*k)
	draw_rect(Rect2(Vector2.ZERO,size),Color("664728"))
	draw_rect(Rect2(Vector2.ONE*2,size-Vector2.ONE*4),Color("32372c"))
	if ground:draw_texture_rect(ground,frame,false)
	for exit in WorldData.scenes[room_id].exits:
		draw_circle(frame.position+WorldData.point(exit)*k,1.6,Color("e7c582"))
	for c in game.characters:
		if c.placed and c.scene_id==room_id and c!=game.local_player:
			var p:Vector2=frame.position+c.feet*k
			draw_circle(p,2.7,Color("42382f"))
			draw_circle(p,1.8,Color("ffd375") if game.follow>=0 and game.follow<game.characters.size() and c==game.characters[game.follow] else Color("bfeafa"))
	var kstage:Vector2=game._stage.scale
	var seen:=Rect2(-game._stage.position/kstage,game._view.size/kstage).intersection(Rect2(Vector2.ZERO,extent))
	draw_rect(Rect2(frame.position+seen.position*k,seen.size*k),Color("f4ebd1"),false,1)

