class_name ArcadeScreen
extends Node2D
var match_key := ""
var area := Rect2()
var table := false
var elapsed := 0.0

func _process(dt: float) -> void:
	elapsed += dt
	if elapsed >= .15:
		elapsed = 0
		queue_redraw()

func _draw() -> void:
	var row: Dictionary = VadsLink.arcade_view.get("sessions",{}).get(match_key,{})
	var game = row.get("game")
	if not game is Dictionary or row.get("status")=="interrupted" or not ArcadePanel.recent(row): return
	if table:
		_draw_table(game)
	else:
		ArcadeBoardView.draw_board(self,game,area)

func _table_point(u: float, v: float) -> Vector2:
	return area.position + Vector2(lerpf(lerpf(.20,.148,v),lerpf(.845,.888,v),u),lerpf(.20,.78,v))*area.size

func _chess_point(x: float, y: float) -> Vector2:
	return _table_point(.05+(1-y)*.9,.05+x*.9)

func _draw_table(game: Dictionary) -> void:
	draw_colored_polygon(PackedVector2Array([_table_point(0,0),_table_point(1,0),_table_point(1,1),_table_point(0,1)]),Color("e7c389"))
	for y in 10: draw_line(_chess_point(0,y/9.0),_chess_point(1,y/9.0),Color("7a5328"),.6)
	for x in 9:
		if x==0 or x==8: draw_line(_chess_point(x/8.0,0),_chess_point(x/8.0,1),Color("7a5328"),.6)
		else:
			draw_line(_chess_point(x/8.0,0),_chess_point(x/8.0,4.0/9),Color("7a5328"),.6)
			draw_line(_chess_point(x/8.0,5.0/9),_chess_point(x/8.0,1),Color("7a5328"),.6)
	for p in [[3,0,5,2],[5,0,3,2],[3,7,5,9],[5,7,3,9]]: draw_line(_chess_point(p[0]/8.0,p[1]/9.0),_chess_point(p[2]/8.0,p[3]/9.0),Color("7a5328"),.6)
	for i in game.get("board",[]).size():
		var piece = game.board[i]
		if not piece is Dictionary: continue
		var at := _chess_point((i%9)/8.0,(i/9)/9.0)
		draw_set_transform(at,0,Vector2(1,.67))
		draw_circle(Vector2.ZERO,3.6,Color("c9344a") if piece.side else Color("222c40"))
		draw_arc(Vector2.ZERO,3.6,0,TAU,16,Color("f6e6c4"),.5)
		draw_set_transform(Vector2.ZERO)

static func mount(room: Node2D, scene: String) -> void:
	if scene=="world-arcade":
		const SCREENS := {"blocks":[.2,.26,.62,.36],"mines":[.2,.26,.62,.36],"snake":[.178,.238,.646,.313]}
		for kind in ["blocks","mines","snake","xiangqi"]:
			if not WorldData.scenes[scene].modules.has("arcade_"+kind):continue
			var module: Dictionary = WorldData.scenes[scene].modules["arcade_"+kind]
			var screen := ArcadeScreen.new()
			screen.match_key = kind
			screen.position = Vector2(module.x,module.y+module.h)
			if kind=="xiangqi":
				screen.table = true
				screen.area = Rect2(0,-module.h,module.w,module.h)
			else:
				if module.has("screen"):
					var r:Array=module.screen
					screen.area=Rect2(r[0],r[1]-module.h,r[2],r[3])
				else:
					var r: Array = SCREENS[kind]
					screen.area = Rect2(module.w*r[0],module.h*(r[1]-1),module.w*r[2],module.h*r[3])
			room.add_child(screen)
	elif scene in ["qianxia-home","xiaojingyu-home"]:
		var screen := ArcadeScreen.new()
		var home: bool = scene=="qianxia-home"
		screen.match_key = "xiangqi@home" if home else "xiangqi@xjhome"
		screen.position = Vector2(78,324) if home else Vector2(204,270)
		screen.area = Rect2(0,-48,68,48) if home else Rect2(0,-50,64,50)
		room.add_child(screen)
