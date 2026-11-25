class_name ArcadeBoardView
extends Control
## Read-only renderer for the same public board on the cabinet and in the sidebar.
##
## 2026-11-21: the player panel hands `board.selected` down (see player_arcade.gd:145-148) but this
## renderer used to ignore it, so clicking a piece produced no visible change at all — you could not
## tell what was selected, nor which squares the piece was actually allowed to move to. The selection
## ring and the legal-move dots below are computed with the very same rules the game uses to accept a
## move (core/arcade_chess.gd), so what is drawn here is exactly what the game will allow.
const Chess = preload("res://core/arcade_chess.gd")
const COLORS := [Color("12192c"), Color("54e0d4"), Color("f6d04d"), Color("c98df2"), Color("70c879"), Color("e38470"), Color("71a4e6"), Color("f0a34e")]
const NUMBERS := [Color.BLACK,Color("2b6fd0"),Color("2c9a4a"),Color("d0413a"),Color("27388f"),Color("8a3b2a"),Color("2a8f93"),Color.BLACK,Color.GRAY]
const PIECES := [{"r":"車","h":"馬","e":"象","a":"士","k":"將","c":"砲","p":"卒"},{"r":"俥","h":"傌","e":"相","a":"仕","k":"帥","c":"炮","p":"兵"}]
var hover := Vector2i(-1,-1)
var selected := -1
var targets:Array=[]
var board := {}
var font: SystemFont
## last selection we computed legal moves for, so we don't recompute every redraw
var _sel_cache := -1
var _sel_key := ""
var _sel_moves: Array = []

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei"])
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func area() -> Rect2:
	return Rect2(Vector2(5,5),size-Vector2(10,10))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Hud.WOOD_D)
	draw_rect(Rect2(Vector2(2,2),size-Vector2(4,4)),Hud.WOOD_H)
	var area := area()
	if board.is_empty():
		draw_rect(area,Hud.PAPER_H)
		var mid := size/2
		# A small cabinet motif gives the idle scoreboard an intentional empty state.
		draw_rect(Rect2(mid+Vector2(-22,-48),Vector2(44,48)),Hud.WOOD)
		draw_rect(Rect2(mid+Vector2(-18,-44),Vector2(36,28)),Color("283b4b"))
		draw_rect(Rect2(mid+Vector2(-13,-37),Vector2(9,4)),Hud.GOLD)
		draw_line(mid+Vector2(-11,-10),mid+Vector2(-11,-4),Hud.PAPER,2)
		draw_circle(mid+Vector2(-11,-11),3,Hud.RED)
		draw_circle(mid+Vector2(10,-7),2,Hud.GOLD)
		text(self,font,"等一场好玩的对局",mid+Vector2(0,19),13,Hud.INK2)
	else:
		var shown := board
		if selected>=0:
			shown=board.duplicate();shown["selected"]=selected
		draw_board(self, shown, area, font)

static func text(canvas: CanvasItem, font_of: Font, value: String, at: Vector2, pixels: int, color: Color) -> void:
	if font_of == null: return
	var width := font_of.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	canvas.draw_string(font_of, at + Vector2(-width/2.0, pixels*0.35), value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, color)

static func draw_board(canvas: CanvasItem, game: Dictionary, area: Rect2, font_of: Font = null) -> void:
	canvas.draw_rect(area, Color("0b1020"))
	if game.is_empty(): return
	if game.kind=="gomoku":
		draw_gomoku(canvas,game,area);return
	if game.kind == "xiangqi":
		draw_chess(canvas, game, area, font_of)
		return
	var cols := int(game.get("w", 9))
	var rows := int(game.get("h", 9))
	var z := minf(area.size.x/cols, area.size.y/rows)
	var origin := area.position + (area.size - Vector2(cols,rows)*z)/2.0
	var cell := func(x,y,color): canvas.draw_rect(Rect2(origin+Vector2(x,y)*z, Vector2.ONE*maxf(1.0,z-(1.0 if z>6 else 0.0))), color)
	match game.kind:
		"snake":
			canvas.draw_rect(Rect2(origin,Vector2(cols,rows)*z),Color("02160c"))
			if game.get("food") is Array: cell.call(game.food[0],game.food[1],Color("ff5f73"))
			for i in game.get("snakes", []).size():
				var snake: Dictionary = game.snakes[i]
				for k in snake.body.size():
					cell.call(snake.body[k][0],snake.body[k][1],(Color.WHITE if k==0 else (Color("7be04a") if i==0 else Color("f2d347"))) if snake.alive else Color("55606a"))
		"mines":
			var tiles=mine_tiles(game)
			for k in tiles.size():
				var x:=k%cols
				var y:=k/cols
				var tile:int=tiles[k]
				var at:=origin+Vector2(x+0.5,y+0.5)*z
				cell.call(x,y,Color("923f48") if tile==-4 else (Color("c7d3de") if tile>=0 else Color("55688a")))
				if tile in [-1,-2] and z>=9:
					var corner:=origin+Vector2(x,y)*z
					var edge:=maxf(1.0,floorf(z*.07))
					canvas.draw_rect(Rect2(corner,Vector2(z-1,edge)),Color("9daec3"))
					canvas.draw_rect(Rect2(corner,Vector2(edge,z-1)),Color("92a6bb"))
					canvas.draw_rect(Rect2(corner+Vector2(0,z-edge-1),Vector2(z-1,edge)),Color("394d69"))
					canvas.draw_rect(Rect2(corner+Vector2(z-edge-1,0),Vector2(edge,z-1)),Color("394d69"))
				if tile==-3 or tile==-4:
					canvas.draw_circle(at,z*.22,Color("ff9a94") if tile==-4 else Color("1d2333"))
				elif tile==-2:
					canvas.draw_line(at+Vector2(-.16,-.25)*z,at+Vector2(-.16,.28)*z,Color("fff4db"),maxf(1,z*.055))
					canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(-.15,-.26)*z,at+Vector2(.25,-.11)*z,at+Vector2(-.15,.03)*z]),Color("ff9b89"))
				elif tile>0:
					text(canvas,font_of if font_of!=null else ThemeDB.fallback_font,str(tile),at,maxi(6,int(z*.62)),NUMBERS[tile])
		"blocks":
			var field=Rect2(origin,Vector2(cols,rows)*z)
			canvas.draw_rect(field,Color("243444"))
			for x in range(1,cols):
				canvas.draw_line(origin+Vector2(x*z,0),origin+Vector2(x*z,field.size.y),Color("354958"),1)
			for y in range(1,rows):
				canvas.draw_line(origin+Vector2(0,y*z),origin+Vector2(field.size.x,y*z),Color("354958"),1)
			var edge=clampf(z*.1,1,4)
			canvas.draw_rect(Rect2(origin-Vector2(edge,0),Vector2(edge,field.size.y)),Color("77acb1"))
			canvas.draw_rect(Rect2(origin+Vector2(field.size.x,0),Vector2(edge,field.size.y)),Color("d8b477"))
			for y in game.board.size():
				for x in game.board[y].size():
					var v := int(game.board[y][x])
					if v>0: cell.call(x,y,COLORS[clampi(v,0,7)])
			if game.status=="playing":
				for y in game.piece.size():
					for x in game.piece[y].size():
						if game.piece[y][x] and game.y+y>=0: cell.call(game.x+x,game.y+y,COLORS[clampi(int(game.color),0,7)])

# The local player has a private board, spectators can receive a masked board.
# Both use the same visible tiles. Negative values encode covered, flag, mine and explosion.
static func mine_tiles(game:Dictionary)->PackedInt32Array:
	var revealed=PackedInt32Array(game.get("open",[]))
	var flags=PackedInt32Array(game.get("flags",[]))
	var mines=PackedInt32Array(game.get("mines",[]))
	var numbers:Dictionary=game.get("numbers",{})
	var tiles=PackedInt32Array()
	tiles.resize(int(game.w)*int(game.h));tiles.fill(-1)
	for k in revealed:
		if k<0 or k>=tiles.size():continue
		var value=numbers.get(str(k),numbers.get(k))
		if value==null:
			value=0
			for n in preload("res://core/arcade_board.gd").neighbours(game,k):
				if mines.has(n):value+=1
		tiles[k]=clampi(int(value),0,8)
	for k in flags:
		if k>=0 and k<tiles.size() and tiles[k]==-1:tiles[k]=-2
	if game.get("status") in ["lost","won"]:
		for k in mines:
			if k>=0 and k<tiles.size() and tiles[k]!=-2:tiles[k]=-4 if game.get("boom")==k else -3
	return tiles

static func draw_gomoku(canvas:CanvasItem,game:Dictionary,area:Rect2)->void:
	canvas.draw_rect(area,Color("dfb67b"))
	var step:=minf(area.size.x,area.size.y)/16.0
	var origin:=area.get_center()-Vector2.ONE*step*7
	for i in 15:
		canvas.draw_line(origin+Vector2(i*step,0),origin+Vector2(i*step,14*step),Color("80562f"),1)
		canvas.draw_line(origin+Vector2(0,i*step),origin+Vector2(14*step,i*step),Color("80562f"),1)
	for p in [Vector2(3,3),Vector2(11,3),Vector2(7,7),Vector2(3,11),Vector2(11,11)]:canvas.draw_circle(origin+p*step,step*.12,Color("80562f"))
	for k in game.get("board",[]).size():
		var side:int=game.board[k]
		if side<0:continue
		var at:=origin+Vector2(k%15,k/15)*step
		canvas.draw_circle(at,step*.43,Color("252735") if side==0 else Color("fff6e4"))
		canvas.draw_arc(at,step*.43,0,TAU,16,Color("866e50"),.7)
		if game.get("last")==k:canvas.draw_circle(at,step*.12,Color("c94b45"))

## Legal destinations for `origin` on `board`, computed with the game's own rules.
## A move is offered only when the game would actually accept it (Chess.legal includes the
## "you may not leave your own king in check" test), so the dots never lie.
static func legal_targets(board_arr: Array, origin: int) -> Array:
	var out: Array = []
	if origin < 0 or origin >= board_arr.size(): return out
	var piece = board_arr[origin]
	if not piece is Dictionary: return out
	var side := int(piece.side)
	for j in 90:
		if Chess.legal(board_arr, side, origin, j): out.append(j)
	return out

static func draw_chess(canvas: CanvasItem, game: Dictionary, area: Rect2, font_of: Font) -> void:
	canvas.draw_rect(area,Color("e7c389"))
	var layout:=geometry(game,area)
	var z:float=layout.z
	var origin:Vector2=layout.origin
	var line := func(a,b): canvas.draw_line(origin+a*z,origin+b*z,Color("7a5328"),1)
	for y in 10: line.call(Vector2(0,y),Vector2(8,y))
	for x in 9:
		if x==0 or x==8: line.call(Vector2(x,0),Vector2(x,9))
		else:
			line.call(Vector2(x,0),Vector2(x,4))
			line.call(Vector2(x,5),Vector2(x,9))
	for p in [[3,0,5,2],[5,0,3,2],[3,7,5,9],[5,7,3,9]]: line.call(Vector2(p[0],p[1]),Vector2(p[2],p[3]))
	canvas.draw_rect(Rect2(origin-Vector2.ONE*z*.07,Vector2(8.14,9.14)*z),Color("785129"),false,maxf(1.0,z*.045))
	for y in [2,3,6,7]:
		for x in ([1,7] if y in [2,7] else [0,2,4,6,8]):
			for dx in [-1,1]:
				if x+dx<0 or x+dx>8:continue
				for dy in [-1,1]:
					var elbow:=Vector2(x,y)+Vector2(dx,dy)*.075
					line.call(elbow,elbow+Vector2(dx*.14,0))
					line.call(elbow,elbow+Vector2(0,dy*.14))
	if z>=12:
		var river_font:=font_of if font_of!=null else ThemeDB.fallback_font
		text(canvas,river_font,"楚 河",origin+Vector2(2,4.5)*z,maxi(8,int(z*.47)),Color("79522d"))
		text(canvas,river_font,"汉 界",origin+Vector2(6,4.5)*z,maxi(8,int(z*.47)),Color("79522d"))
	var board_arr: Array = game.get("board", [])

	# 2026-11-21: legal-move dots under the pieces, so the highlighted square is never hidden.
	var sel := int(game.get("selected", -1))
	if sel >= 0 and sel < 90 and board_arr.size() == 90:
		for j in legal_targets(board_arr, sel):
			var at2 := origin+Vector2(j%9,j/9)*z
			canvas.draw_circle(at2,z*.14,Color(0.17,0.70,0.63,0.85))
			canvas.draw_arc(at2,z*.14,0,TAU,14,Color(0.05,0.20,0.30,0.55),1.0)

	if game.get("last") is Dictionary:
		for k in [int(game.last.from),int(game.last.to)]: canvas.draw_rect(Rect2(origin+Vector2(k%9,k/9)*z-Vector2.ONE*z*.46,Vector2.ONE*z*.92),Color("2bb3a3"),false,2)
	for i in board_arr.size():
		var piece = board_arr[i]
		if not piece is Dictionary: continue
		var at := origin+Vector2(i%9,i/9)*z
		var ink := Color("b53950") if piece.side else Color("253145")
		canvas.draw_circle(at,z*.42,Color("f8e8c6"))
		canvas.draw_arc(at,z*.42,0,TAU,24,ink,1)
		text(canvas,font_of,PIECES[int(piece.side)].get(piece.type,"?"),at,maxi(9,int(z*.56)),ink)

	# 2026-11-21: the selection ring goes on top of everything so it is visible on occupied squares too.
	if sel >= 0 and sel < 90:
		canvas.draw_rect(Rect2(origin+Vector2(sel%9,sel/9)*z-Vector2.ONE*z*.47,Vector2.ONE*z*.94),Color("f6d04d"),false,3)

static func geometry(game: Dictionary, area: Rect2) -> Dictionary:
	var kind: String = str(game.get("kind",""))
	if kind == "xiangqi":
		var z := minf(area.size.x/9.1, area.size.y/10.1)
		return {"z":z, "origin":area.get_center()-Vector2(4,4.5)*z, "cols":9, "rows":10, "grid":true}
	if kind == "gomoku":
		var step := minf(area.size.x, area.size.y)/16.0
		return {"z":step, "origin":area.get_center()-Vector2.ONE*step*7, "cols":15, "rows":15, "grid":true}
	var cols := int(game.get("w", 9))
	var rows := int(game.get("h", 9))
	var z := minf(area.size.x/cols, area.size.y/rows)
	return {"z":z, "origin":area.position + (area.size - Vector2(cols,rows)*z)/2.0, "cols":cols, "rows":rows, "grid":false}

static func cell_at(game: Dictionary, area: Rect2, at: Vector2) -> Vector2i:
	if game.is_empty(): return Vector2i(-1,-1)
	var g := geometry(game, area)
	var p: Vector2 = (at - g.origin) / g.z
	var cell := Vector2i(p.round()) if g.grid else Vector2i(p.floor())
	if g.grid and (p - Vector2(cell)).length() > 0.48: return Vector2i(-1,-1)
	return cell if Rect2i(0,0,g.cols,g.rows).has_point(cell) else Vector2i(-1,-1)

