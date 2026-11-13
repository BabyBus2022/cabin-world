extends RefCounted
## Resident skill and the board seed drive the same controller for both
## residents and computer. Hidden mines never enter a guess.
const Board = preload("res://core/arcade_board.gd")
const Chess = preload("res://core/arcade_chess.gd")

static func skill(s: Dictionary, id: String) -> float:
	return s.skill.get(id,0.68 if id=="computer" else 0.7)

static func suggest(s: Dictionary) -> Dictionary:
	if s.status!="playing": return {}
	match s.kind:
		"gomoku":return load("res://core/arcade_gomoku.gd").suggest(s)
		"snake": return snake(s)
		"blocks": return blocks(s)
		"mines": return mines(s)
		"xiangqi":
			var id: String = s.sides[int(s.turn)]
			var level := skill(s,id)
			var depth := 3 if id!="computer" and level>=.75 and Board.random_value(s)<.5 else 2
			return chess(s,depth,30.0 if id=="computer" else (1-level)*300.0)
	return {}

static func snake(s: Dictionary) -> Dictionary:
	var taken := {}
	for a in s.snakes:
		if a.alive:
			for p in a.body.slice(0,a.body.size()-1): taken[Vector2i(p[0],p[1])]=true
	var bounds := Rect2i(0,0,s.w,s.h)
	var choices := {}
	for a in s.snakes:
		if not a.alive: continue
		var costs := []
		for direction in Board.DIRECTIONS:
			var v: Array = Board.DIRECTIONS[direction]
			var old: Array = Board.DIRECTIONS[a.dir]
			if v[0]==-old[0] and v[1]==-old[1]: continue
			var pos := Vector2i(a.body[0][0]+v[0],a.body[0][1]+v[1])
			var cost := 1000000
			if bounds.has_point(pos) and not taken.has(pos):
				var space := reachable(pos,bounds,taken,a.body.size()+6)
				cost=maxi(0,a.body.size()+2-space)*200
				for other in s.snakes:
					if other.alive and other.id!=a.id and absi(pos.x-other.body[0][0])+absi(pos.y-other.body[0][1])==1: cost+=120
				if s.food!=null: cost+=absi(pos.x-s.food[0])+absi(pos.y-s.food[1])
			# Insert after equal costs to preserve the original direction order.
			var j := costs.size()
			while j and costs[j-1][1]>cost: j-=1
			costs.insert(j,[direction,cost])
		var slip := Board.random_value(s)<(1.0-skill(s,a.id))*.09
		choices[a.id]=costs[Board.random_index(s,costs.size()) if slip else 0][0]
	return choices

static func reachable(start: Vector2i, bounds: Rect2i, taken: Dictionary, limit: int) -> int:
	var queue := [start]
	var seen := {start:true}
	var i := 0
	while i<queue.size() and queue.size()<limit:
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var p: Vector2i=queue[i]+d
			if bounds.has_point(p) and not taken.has(p) and not seen.has(p):
				seen[p]=true
				queue.append(p)
		i+=1
	return queue.size()

static func cell(s: Dictionary,k: int,flag:=false) -> Dictionary:
	var a := {"x":k%int(s.w),"y":floori(float(k)/s.w)}
	if flag: a.flag=true
	return a

static func mines(s: Dictionary) -> Dictionary:
	if not s.armed: return {"x":4,"y":4}
	var rows := []
	for k in s.open:
		var around := Board.neighbours(s,k)
		var closed := around.filter(func(n): return not s.open.has(n) and not s.flags.has(n))
		if not closed.is_empty():
			var left := around.filter(func(n): return s.mines.has(n)).size()-around.filter(func(n): return s.flags.has(n)).size()
			rows.append({"closed":closed,"left":left})
	var slip := Board.random_value(s)<(1-skill(s,s.players[0]))*.16
	if not slip:
		for r in rows:
			if r.left==0 or r.left==r.closed.size(): return cell(s,r.closed[0],r.left!=0)
		for a in rows:
			for b in rows:
				if not a.closed.all(func(n): return b.closed.has(n)): continue
				var rest: Array = b.closed.filter(func(n): return not a.closed.has(n))
				var left: int = b.left-a.left
				if not rest.is_empty() and (left==0 or left==rest.size()): return cell(s,rest[0],left!=0)
	var closed := []
	for k in int(s.w*s.h):
		if not s.open.has(k) and not s.flags.has(k): closed.append(k)
	var base := float(s.total-s.flags.size())/maxi(1,closed.size())
	var best := INF
	var choice := {}
	for k in closed:
		var p := base
		for r in rows:
			if r.closed.has(k): p=maxf(p,float(r.left)/r.closed.size())
		p+=Board.random_value(s)*(.6 if slip else .02)
		if p<best:
			best=p
			choice=cell(s,k)
	return choice

static func placement(s: Dictionary,piece: Array,x: int,y: int) -> float:
	var grid: Array=s.board.duplicate(true)
	for dy in piece.size():
		for dx in piece[dy].size():
			if piece[dy][dx]: grid[y+dy][x+dx]=1
	grid=grid.filter(func(r): return r.has(0))
	var lines := int(s.h)-grid.size()
	var sum := 0
	var bump := 0
	var holes := 0
	var last := 0
	for c in int(s.w):
		var height := 0
		for r in grid.size():
			if grid[r][c] and not height: height=grid.size()-r
			if height and not grid[r][c]: holes+=1
		sum+=height
		if c: bump+=absi(height-last)
		last=height
	return -.51*sum+.76*lines-.36*holes*3-.18*bump

static func blocks(s: Dictionary) -> Dictionary:
	if s.plan==null or s.plan.id!=s.pieceNo:
		var best := -INF
		var piece: Array=s.piece
		s.plan={"id":s.pieceNo,"x":s.x,"rot":0,"tries":0}
		for rot in 4:
			for x in range(-2,int(s.w)):
				var y := int(s.y)
				if not Board.fits(s,piece,x,y): continue
				while Board.fits(s,piece,x,y+1): y+=1
				var v := placement(s,piece,x,y)+(Board.random_value(s)-.5)*(1-skill(s,s.players[0]))*14
				if v>best:
					best=v
					s.plan.x=x
					s.plan.rot=rot
			var rotated := []
			for x in piece[0].size():
				var row := []
				for y in range(piece.size()-1,-1,-1): row.append(piece[y][x])
				rotated.append(row)
			piece=rotated
	s.plan.tries+=1
	if s.plan.tries>14: return {"drop":true}
	if s.plan.rot>0:
		s.plan.rot-=1
		return {"rotate":true}
	if s.x!=s.plan.x: return {"move":"right" if s.x<s.plan.x else "left"}
	return {"drop":true}

const VALUE := {"k":20000,"r":900,"c":450,"h":420,"e":200,"a":200,"p":100}
const STRAIGHT := [[1,0],[-1,0],[0,1],[0,-1]]
const OFFSETS := {"h":[[1,2],[-1,2],[1,-2],[-1,-2],[2,1],[2,-1],[-2,1],[-2,-1]],"e":[[2,2],[2,-2],[-2,2],[-2,-2]],"a":[[1,1],[1,-1],[-1,1],[-1,-1]],"k":STRAIGHT}

static func moves(b: Array, side: int, ordered:=false) -> Array:
	var out := []
	var buckets := {}
	for i in 90:
		var p=b[i]
		if p==null or p.side!=side: continue
		var x := i%9
		var y := floori(float(i)/9)
		var slide: bool = p.type in ["r","c"]
		var dirs: Array = STRAIGHT if slide else OFFSETS.get(p.type,[[0,-1 if side else 1],[-1,0],[1,0]])
		for d in dirs:
			var xx: int=x+d[0]
			var yy: int=y+d[1]
			var screen := false
			while xx>=0 and yy>=0 and xx<9 and yy<10:
				var j := yy*9+xx
				var capture=b[j]
				var valid: bool
				if slide:
					valid=(not screen if capture==null else capture.side!=side and (p.type=="r" or screen))
				else:
					valid=Chess.reaches(b,i,j)
				if valid:
					var m := [i,j]
					if ordered:
						var v: int=VALUE[capture.type] if capture!=null else 0
						if not buckets.has(v): buckets[v]=[]
						buckets[v].append(m)
					else: out.append(m)
				if not slide: break
				if capture!=null:
					if screen or p.type=="r": break
					screen=true
				xx+=d[0]
				yy+=d[1]
	if ordered:
		for v in [20000,900,450,420,200,100,0]: out.append_array(buckets.get(v,[]))
	return out

static func evaluate(b: Array,side: int) -> int:
	var score := 0
	for i in 90:
		var p=b[i]
		if p==null: continue
		var y := floori(float(i)/9)
		var forward := 9-y if p.side else y
		var centre := 4-absi(i%9-4)
		var v: int=VALUE[p.type]
		if p.type=="p" and forward>=5: v+=70+centre*8+(-30 if forward>=8 else 0)
		elif p.type in ["h","c","r"]: v+=centre*3+mini(forward,5)*3
		score+=v if p.side==side else -v
	return score

static func search(b: Array,side: int,depth: int,alpha: float,beta: float,budget: Array) -> float:
	if depth<=0 or budget[0]<=0: return evaluate(b,side)
	var best := -INF
	for m in moves(b,side,true):
		var capture=b[m[1]]
		if capture!=null and capture.type=="k": return 15000+depth
		budget[0]-=1
		b[m[1]]=b[m[0]]
		b[m[0]]=null
		var v := -search(b,1-side,depth-1,-beta,-alpha,budget)
		b[m[0]]=b[m[1]]
		b[m[1]]=capture
		best=maxf(best,v)
		alpha=maxf(alpha,v)
		if alpha>=beta: break
	return -15000 if best==-INF else best

static func chess(s: Dictionary,depth: int,noise: float) -> Dictionary:
	var b: Array=s.board
	var side := int(s.turn)
	var budget := [30000]
	var score := -INF
	var best := {}
	for m in moves(b,side):
		if not Chess.legal(b,side,m[0],m[1]): continue
		var capture=b[m[1]]
		b[m[1]]=b[m[0]]
		b[m[0]]=null
		var v := -search(b,1-side,depth-1,-INF,INF,budget)
		if s.seen.has(Chess.key_of(b,1-side)): v-=40
		b[m[0]]=b[m[1]]
		b[m[1]]=capture
		v+=Board.random_value(s)*noise
		if v>score:
			score=v
			best={"from":m[0],"to":m[1]}
	return best
