extends RefCounted
## Apply one resident input. Boards are passed by value over the link, so a
## retried tick cannot score twice. VADS supplies the move its controller chose.
const Chess = preload("res://core/arcade_chess.gd")
const DIRECTIONS := {"up":[0,-1],"down":[0,1],"left":[-1,0],"right":[1,0]}
const PIECES := [[[1,1,1,1]],[[1,1],[1,1]],[[0,1,0],[1,1,1]],[[0,1,1],[1,1,0]],[[1,1,0],[0,1,1]],[[1,0,0],[1,1,1]],[[0,0,1],[1,1,1]]]

static func random_value(s: Dictionary) -> float:
	var seed := (int(s.seed) + 0x6d2b79f5) & 0xffffffff
	s.seed = seed
	var t := ((seed ^ (seed >> 15)) * (1 | seed)) & 0xffffffff
	t = (t ^ (t + ((t ^ (t >> 7)) * (61 | t)))) & 0xffffffff
	return float(t ^ (t >> 14)) / 4294967296.0

static func random_index(s: Dictionary, count: int) -> int:
	return int(random_value(s)*count)

static func finish(s: Dictionary, status: String, winner: Variant, reason: String) -> void:
	s.status = status
	s.winner = winner
	s.reason = reason

static func lobby(a: Dictionary) -> Dictionary:
	var members: Array = a.members.duplicate()
	if members.any(func(m): return m.seated and not m.valid):
		return {"action":"interrupt","reason":"有人离开了位置"}
	var dropped := []
	if a.now-a.createdAt>120000:
		for m in members:
			if not m.seated: dropped.append(m.id)
		members=members.filter(func(m): return m.seated)
	if members.is_empty(): return {"action":"empty","dropped":dropped}
	if members.any(func(m): return not m.seated) or (a.invited and a.now-maxf(a.invitedAt,a.seatedAt)<70000):
		return {"action":"wait","dropped":dropped}
	if a.atHome and members.size()<2:
		return {"action":"interrupt","dropped":dropped,"reason":"没有人一起下"}
	members.sort_custom(func(m,n): return m.seat<n.seat)
	var ids := members.map(func(m): return m.id)
	var skills := {"computer":0.68}
	for m in members: skills[m.id]=m.skill
	var opponent: bool = a.kind=="snake" and members.size()==1
	if opponent: ids.insert(0 if members[0].seat else 1,"computer")
	return {"action":"start","dropped":dropped,"passerby":opponent,"board":begin({"kind":a.kind,"seed":a.seed,"players":ids,"skill":skills})}

static func begin(a: Dictionary) -> Dictionary:
	var s := {"kind":a.kind,"players":a.players,"skill":a.skill,"seed":int(a.seed)&0xffffffff,
		"status":"playing","score":0,"ticks":0,"winner":null,"reason":""}
	match a.kind:
		"gomoku":s.merge(load("res://core/arcade_gomoku.gd").create(a.players))
		"snake":
			var duo: bool = a.players.size()>1
			s.merge({"w":18,"h":14,"duo":duo,"target":15 if duo else 12,"snakes":[]})
			for i in a.players.size():
				var body := [[14,10],[15,10],[16,10]] if i else ([[3,3],[2,3],[1,3]] if duo else [[4,7],[3,7],[2,7]])
				s.snakes.append({"id":a.players[i],"dir":"left" if i else "right","alive":true,"score":0,"body":body})
			place_food(s,s.snakes)
		"mines":
			s.merge({"w":9,"h":9,"mines":[],"open":[],"flags":[],"armed":false,"total":10})
		"blocks":
			s.merge({"w":10,"h":20,"board":[],"lines":0,"bag":[],"pieceNo":0,"fall":0,"target":30,"plan":null})
			for i in 20: s.board.append([0,0,0,0,0,0,0,0,0,0])
			refill(s)
			s.nextPiece=s.bag.pop_back()
			spawn_piece(s)
		"xiangqi":
			var board := []
			board.resize(90)
			for side in 2:
				for x in 9: board[(81 if side else 0)+x]={"side":side,"type":"rheakaehr"[x]}
				for x in [1,7]: board[(63 if side else 18)+x]={"side":side,"type":"c"}
				for x in [0,2,4,6,8]: board[(54 if side else 27)+x]={"side":side,"type":"p"}
			var sides: Array = a.players.duplicate()
			if sides.size()==1: sides.append("computer")
			if not random_index(s,2): sides.reverse()
			s.merge({"w":9,"h":10,"board":board,"turn":1,"moves":0,"halfmoves":0,"sides":sides,
				"seen":{Chess.key_of(board,1):1},"checkRun":[0,0],"last":null,"inCheck":false})
	return s

## Godot parses JSON numbers as floats. Array membership compares element
## types, so restore integer board coordinates before collision/flag lookups.
static func restore_numbers(value: Variant) -> Variant:
	if value is Array:
		for i in value.size(): value[i] = restore_numbers(value[i])
	elif value is Dictionary:
		for k in value: value[k] = restore_numbers(value[k])
	elif value is float and value == floorf(value):
		return int(value)
	return value

static func advance(s: Dictionary, action: Dictionary) -> Dictionary:
	restore_numbers(s)
	if s.status != "playing":
		return s
	s.ticks += 1
	match s.kind:
		"snake": snake(s, action)
		"mines": mines(s, action)
		"blocks": blocks(s, action)
		"xiangqi": Chess.step(s, action)
		"gomoku":load("res://core/arcade_gomoku.gd").step(s,action)
	return s

static func snake(s: Dictionary, action: Dictionary) -> void:
	var next := {}
	var dead := {}
	var living: Array = s.snakes.filter(func(a): return a.alive)
	for a in living:
		var direction = action.get(a.id, "")
		var old: Array = DIRECTIONS[a.dir]
		if DIRECTIONS.has(direction):
			var v: Array = DIRECTIONS[direction]
			if old[0] != -v[0] or old[1] != -v[1]:
				a.dir = direction
		var v: Array = DIRECTIONS[a.dir]
		next[a.id] = [int(a.body[0][0])+v[0], int(a.body[0][1])+v[1]]
	for a in living:
		var p: Array = next[a.id]
		if p[0]<0 or p[0]>=s.w or p[1]<0 or p[1]>=s.h:
			dead[a.id] = true
			continue
		for b in living:
			var q: Array = next[b.id]
			var occupied: Array = b.body if q == s.food else b.body.slice(0, b.body.size()-1)
			if occupied.has(p) or (a.id != b.id and (p == q or (p == b.body[0] and q == a.body[0]))):
				dead[a.id] = true
	var ate := false
	for a in living:
		if dead.has(a.id):
			a.alive = false
			continue
		a.body.push_front(next[a.id])
		if next[a.id] == s.food:
			a.score += 1
			s.score += 1
			ate = true
		else:
			a.body.pop_back()
	var alive := living.filter(func(a): return a.alive)
	if alive.is_empty():
		finish(s, "draw" if s.duo else "lost", null, "两条蛇同时撞了" if s.duo else "撞到了")
	elif s.duo and alive.size()==1:
		finish(s,"won",alive[0].id,"对方先撞了")
	else:
		var top := alive.filter(func(a): return a.score >= s.target)
		if top.size()==1:
			finish(s,"won",top[0].id,("先吃满了%d个" if s.duo else "吃满了%d个") % int(s.target))
		elif top.size()>1:
			finish(s,"draw",null,"同时吃满了")
		elif s.duo and s.ticks>=900:
			if alive[0].score==alive[1].score:
				finish(s,"draw",null,"时间到，分数一样")
			else:
				finish(s,"won",(alive[0] if alive[0].score>alive[1].score else alive[1]).id,"时间到，分数更高")
	if s.status=="playing" and ate:
		if not place_food(s,alive):
			finish(s,"draw" if s.duo else "won",null if s.duo else alive[0].id,"格子满了" if s.duo else "格子都占满了")

static func place_food(s: Dictionary, alive: Array) -> bool:
	var free := []
	for y in int(s.h):
		for x in int(s.w):
			if not alive.any(func(a): return a.body.has([x,y])):
				free.append([x,y])
	s.food = null if free.is_empty() else free[random_index(s,free.size())]
	return s.food!=null

static func neighbours(s: Dictionary, k: int) -> Array:
	var cells := []
	var w := int(s.w)
	for dy in range(-1,2):
		for dx in range(-1,2):
			var x := k%w+dx
			var y := floori(float(k)/w)+dy
			if (dx or dy) and x>=0 and y>=0 and x<w and y<s.h:
				cells.append(y*w+x)
	return cells

static func mines(s: Dictionary, a: Dictionary) -> void:
	if not a.has("x") or not a.has("y"):
		return
	if not (a.x is float or a.x is int) or not (a.y is float or a.y is int): return
	var x := int(a.x)
	var y := int(a.y)
	var w := int(s.w)
	if x!=a.x or y!=a.y or x<0 or y<0 or x>=w or y>=s.h:
		return
	var k := y*w+x
	if a.get("flag") and not s.open.has(k):
		if s.flags.has(k): s.flags.erase(k)
		else: s.flags.append(k)
		return
	if s.flags.has(k) or s.open.has(k):
		return
	if not s.armed:
		var candidates := []
		for i in int(w*s.h):
			if absi(i%w-x)>1 or absi(floori(float(i)/w)-y)>1:
				candidates.append(i)
		while s.mines.size()<s.total:
			s.mines.append(candidates.pop_at(random_index(s,candidates.size())))
		s.armed = true
	if s.mines.has(k):
		s.boom = k
		finish(s,"lost",null,"翻到了雷")
		return
	var queue := [k]
	while not queue.is_empty():
		var v: int = queue.pop_back()
		if s.open.has(v) or s.flags.has(v): continue
		s.open.append(v)
		var near := neighbours(s,v)
		if not near.any(func(n): return s.mines.has(n)):
			queue.append_array(near.filter(func(n): return not s.open.has(n)))
	s.score = s.open.size()
	if s.score==w*s.h-s.total: finish(s,"won",s.players[0],"所有安全格都翻开了")

static func fits(s: Dictionary, piece: Array, x: int, y: int) -> bool:
	for dy in piece.size():
		for dx in piece[dy].size():
			if piece[dy][dx] and (x+dx<0 or x+dx>=s.w or y+dy<0 or y+dy>=s.h or s.board[y+dy][x+dx]):
				return false
	return true

static func lock(s: Dictionary) -> void:
	for y in s.piece.size():
		for x in s.piece[y].size():
			if s.piece[y][x]: s.board[int(s.y)+y][int(s.x)+x]=s.color
	var rows: Array = s.board.filter(func(row): return row.has(0))
	var n := int(s.h)-rows.size()
	s.lines += n
	s.score += [0,100,300,500,800][n]
	for i in n:
		var row := []
		row.resize(int(s.w))
		row.fill(0)
		rows.push_front(row)
	s.board = rows
	if s.lines>=s.target:
		finish(s,"won",s.players[0],"消满了%d行" % int(s.target))
		return
	spawn_piece(s)

static func refill(s: Dictionary) -> void:
	if s.bag.is_empty():
		s.bag = [0,1,2,3,4,5,6]
		for i in range(6,0,-1):
			var j := random_index(s,i+1)
			var tmp = s.bag[i]
			s.bag[i] = s.bag[j]
			s.bag[j] = tmp

static func spawn_piece(s: Dictionary) -> void:
	var id := int(s.nextPiece)
	refill(s)
	s.nextPiece = s.bag.pop_back()
	s.color = id+1
	s.piece = PIECES[id].duplicate(true)
	s.x = floori((s.w-s.piece[0].size())/2.0)
	s.y = 0
	s.fall = 0
	s.pieceNo += 1
	if not fits(s,s.piece,int(s.x),0): finish(s,"lost",null,"堆到顶了")

static func blocks(s: Dictionary, a: Dictionary) -> void:
	if a.get("move") in ["left","right"]:
		var dx := -1 if a.move=="left" else 1
		if fits(s,s.piece,int(s.x)+dx,int(s.y)): s.x+=dx
	if a.get("rotate"):
		var rotated := []
		for x in s.piece[0].size():
			var row := []
			for y in range(s.piece.size()-1,-1,-1): row.append(s.piece[y][x])
			rotated.append(row)
		for dx in [0,-1,1,-2,2]:
			if fits(s,rotated,int(s.x)+dx,int(s.y)):
				s.piece = rotated
				s.x += dx
				break
	if a.get("drop"):
		while fits(s,s.piece,int(s.x),int(s.y)+1): s.y+=1
		lock(s)
	else:
		s.fall += 1
		if s.fall>=maxi(1,6-floori(s.lines/3.0)):
			s.fall = 0
			if fits(s,s.piece,int(s.x),int(s.y)+1): s.y+=1
			else: lock(s)
