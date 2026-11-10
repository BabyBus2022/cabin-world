class_name ArcadeBoardView
extends Control
## Read-only renderer for the same public board on the cabinet and in the sidebar.
const COLORS := [Color("12192c"), Color("54e0d4"), Color("f6d04d"), Color("c98df2"), Color("70c879"), Color("e38470"), Color("71a4e6"), Color("f0a34e")]
const NUMBERS := [Color.BLACK,Color("2b6fd0"),Color("2c9a4a"),Color("d0413a"),Color("27388f"),Color("8a3b2a"),Color("2a8f93"),Color.BLACK,Color.GRAY]
const PIECES := [{"r":"車","h":"馬","e":"象","a":"士","k":"將","c":"砲","p":"卒"},{"r":"俥","h":"傌","e":"相","a":"仕","k":"帥","c":"炮","p":"兵"}]
var board := {}
var font: SystemFont

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei"])
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Hud.WOOD_D)
	draw_rect(Rect2(Vector2(2,2),size-Vector2(4,4)),Hud.WOOD_H)
	var area := Rect2(Vector2(5,5),size-Vector2(10,10))
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
		draw_board(self, board, area, font)

static func text(canvas: CanvasItem, font_of: Font, value: String, at: Vector2, pixels: int, color: Color) -> void:
	if font_of == null: return
	var width := font_of.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	canvas.draw_string(font_of, at + Vector2(-width/2.0, pixels*0.35), value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, color)

static func draw_board(canvas: CanvasItem, game: Dictionary, area: Rect2, font_of: Font = null) -> void:
	canvas.draw_rect(area, Color("0b1020"))
	if game.is_empty(): return
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
			for k in cols*rows:
				var x := k%cols
				var y := k/cols
				var opened: bool = k in game.open
				var mine: bool = k in game.get("mines", [])
				cell.call(x,y,Color("c7d3de") if opened else (Color("7d2f3a") if mine else Color("55688a")))
				var at := origin+Vector2(x+0.5,y+0.5)*z
				if mine: canvas.draw_circle(at,z*0.22,Color("ff5f73"))
				elif k in game.flags: canvas.draw_rect(Rect2(at-Vector2.ONE*z*.2,Vector2.ONE*z*.4),Color("ff8ba7"))
				elif opened:
					var n := int(game.get("numbers",{}).get(str(k),game.get("numbers",{}).get(k,0)))
					if n>0:
						if font_of != null: text(canvas,font_of,str(n),at,maxi(9,int(z*.62)),NUMBERS[mini(n,8)])
						else: canvas.draw_circle(at,z*.15,NUMBERS[mini(n,8)])
		"blocks":
			for y in game.board.size():
				for x in game.board[y].size():
					var v := int(game.board[y][x])
					if v>0: cell.call(x,y,COLORS[clampi(v,0,7)])
			if game.status=="playing":
				for y in game.piece.size():
					for x in game.piece[y].size():
						if game.piece[y][x] and game.y+y>=0: cell.call(game.x+x,game.y+y,COLORS[clampi(int(game.color),0,7)])

static func draw_chess(canvas: CanvasItem, game: Dictionary, area: Rect2, font_of: Font) -> void:
	canvas.draw_rect(area,Color("e7c389"))
	var z := minf(area.size.x/8.8,area.size.y/9.8)
	var origin := area.get_center()-Vector2(4,4.5)*z
	var line := func(a,b): canvas.draw_line(origin+a*z,origin+b*z,Color("7a5328"),1)
	for y in 10: line.call(Vector2(0,y),Vector2(8,y))
	for x in 9:
		if x==0 or x==8: line.call(Vector2(x,0),Vector2(x,9))
		else:
			line.call(Vector2(x,0),Vector2(x,4))
			line.call(Vector2(x,5),Vector2(x,9))
	for p in [[3,0,5,2],[5,0,3,2],[3,7,5,9],[5,7,3,9]]: line.call(Vector2(p[0],p[1]),Vector2(p[2],p[3]))
	if game.get("last") is Dictionary:
		for k in [int(game.last.from),int(game.last.to)]: canvas.draw_rect(Rect2(origin+Vector2(k%9,k/9)*z-Vector2.ONE*z*.46,Vector2.ONE*z*.92),Color("2bb3a3"),false,2)
	for i in game.get("board",[]).size():
		var piece = game.board[i]
		if not piece is Dictionary: continue
		var at := origin+Vector2(i%9,i/9)*z
		var ink := Color("b53950") if piece.side else Color("253145")
		canvas.draw_circle(at,z*.42,Color("f8e8c6"))
		canvas.draw_arc(at,z*.42,0,TAU,24,ink,1)
		text(canvas,font_of,PIECES[int(piece.side)].get(piece.type,"?"),at,maxi(9,int(z*.56)),ink)
