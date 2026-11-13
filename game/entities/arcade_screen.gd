class_name ArcadeScreen
extends Node2D
var match_key := ""
var area := Rect2()
var table := false
var board_quad: Array = []
var board_paper: Array = []
var elapsed := 0.0
var home_board:=false

func _process(dt: float) -> void:
	elapsed += dt
	if elapsed >= .15:
		elapsed = 0
		queue_redraw()

func _draw() -> void:
	var row: Dictionary = VadsLink.arcade_view.get("sessions",{}).get(match_key,{})
	if match_key.begins_with("xiangqi"):
		var other:Dictionary=VadsLink.arcade_view.get("sessions",{}).get(match_key.replace("xiangqi","gomoku"),{})
		if ArcadePanel.recent(other):row=other
	var game = row.get("game")
	if not game is Dictionary or row.get("status")=="interrupted" or not ArcadePanel.recent(row): return
	if home_board:
		# A small readable prop is enough at room scale; the sidebar owns live moves.
		var prop:Dictionary=game.duplicate(true)
		if prop.kind=="gomoku":prop.board=[];prop.board.resize(225);prop.board.fill(-1);prop.board[112]=0;prop.board[113]=1;prop.last=null
		ArcadeBoardView.draw_board(self,prop,area);return
	if table:
		_draw_table(game)
	else:
		ArcadeBoardView.draw_board(self,game,area)

func _chess_point(x: float, y: float) -> Vector2:
	if board_quad.size() == 4:
		var a := Vector2(board_quad[0][0],board_quad[0][1]).lerp(Vector2(board_quad[3][0],board_quad[3][1]),y)
		var b := Vector2(board_quad[1][0],board_quad[1][1]).lerp(Vector2(board_quad[2][0],board_quad[2][1]),y)
		return area.position + a.lerp(b,x)
	# The current wooden table is 158 x 147, with its board ABOVE the apron.
	# Match the printed grid's four corners; the old neon-cabinet ratios shifted
	# the overlay downward and also rotated it 90 degrees.
	var left:=Vector2(24,11).lerp(Vector2(17,91),y)
	var right:=Vector2(135,11).lerp(Vector2(142,91),y)
	return area.position+left.lerp(right,x)/Vector2(158,147)*area.size

func _draw_table(game: Dictionary) -> void:
	# Repaint the playable grid inside the printed parchment, using the SAME
	# projection as its pieces. The wooden rim and table art stay untouched.
	var paper:=PackedVector2Array()
	if board_paper.size() == 4:
		for point in board_paper:paper.append(area.position+Vector2(point[0],point[1]))
	else:
		for point in [Vector2(18,8),Vector2(140,8),Vector2(145,95),Vector2(13,95)]:paper.append(area.position+point/Vector2(158,147)*area.size)
	draw_colored_polygon(paper,Color("e6b975"))
	if game.get("kind")=="gomoku":
		for i in 15:
			draw_line(_chess_point(i/14.0,0),_chess_point(i/14.0,1),Color("815c34"),.5)
			draw_line(_chess_point(0,i/14.0),_chess_point(1,i/14.0),Color("815c34"),.5)
		for k in game.get("board",[]).size():
			if game.board[k]<0:continue
			draw_circle(_chess_point((k%15)/14.0,(k/15)/14.0),minf(area.size.x,area.size.y)*.023,Color("222b35") if game.board[k]==0 else Color("fff6e4"))
		return
	for y in 10:draw_line(_chess_point(0,y/9.0),_chess_point(1,y/9.0),Color("815c34"),.5)
	for x in 9:
		if x==0 or x==8:draw_line(_chess_point(x/8.0,0),_chess_point(x/8.0,1),Color("815c34"),.5)
		else:
			draw_line(_chess_point(x/8.0,0),_chess_point(x/8.0,4.0/9),Color("815c34"),.5)
			draw_line(_chess_point(x/8.0,5.0/9),_chess_point(x/8.0,1),Color("815c34"),.5)
	for p in [[3,0,5,2],[5,0,3,2],[3,7,5,9],[5,7,3,9]]:draw_line(_chess_point(p[0]/8.0,p[1]/9.0),_chess_point(p[2]/8.0,p[3]/9.0),Color("815c34"),.5)
	var radius:=minf(area.size.x*.032,area.size.y*.035)
	for i in game.get("board",[]).size():
		var piece = game.board[i]
		if not piece is Dictionary: continue
		var at := _chess_point((i%9)/8.0,(i/9)/9.0)
		draw_set_transform(at,0,Vector2(1,.67))
		draw_circle(Vector2.ZERO,radius,Color("c9344a") if piece.side else Color("222c40"))
		draw_arc(Vector2.ZERO,radius,0,TAU,16,Color("f6e6c4"),.5)
		draw_set_transform(Vector2.ZERO)

static func mount(room: Node2D, scene: String) -> void:
	if scene=="world-arcade":
		const SCREENS := {"blocks":[.2,.26,.62,.36],"mines":[.2,.26,.62,.36],"snake":[.178,.238,.646,.313]}
		for cabinet in ["blocks","blocks_2","mines","snake","xiangqi"]:
			var kind: String = "blocks" if cabinet=="blocks_2" else cabinet
			if not WorldData.scenes[scene].modules.has("arcade_"+cabinet):continue
			var module: Dictionary = WorldData.scenes[scene].modules["arcade_"+cabinet]
			if not module.get("screenVisible",true) and kind!="xiangqi":continue
			var screen := ArcadeScreen.new()
			screen.match_key = "blocks@second" if cabinet=="blocks_2" else kind
			screen.position = Vector2(module.x,module.y+module.h)
			if kind=="xiangqi":
				screen.table = true
				screen.area = Rect2(0,-module.h,module.w,module.h)
				screen.board_quad = module.get("boardQuad",[])
				screen.board_paper = module.get("boardPaper",[])
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
		screen.home_board=true
		screen.position = Vector2(78,324) if home else Vector2(204,270)
		screen.area = Rect2(0,-48,68,48) if home else Rect2(0,-50,64,50)
		room.add_child(screen)
