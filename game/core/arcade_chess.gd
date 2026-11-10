extends RefCounted
## Board indices run left to right from Black's back rank. Home and arcade
## boards use exactly the same legality and repetition rules.

static func palace(x: int, y: int, side: int) -> bool:
	return x>=3 and x<=5 and (y>=7 if side else y<=2)

static func between(b: Array, origin: int, dest: int) -> int:
	var stride := signi(dest-origin) * (9 if origin%9==dest%9 else 1)
	var count := 0
	for i in range(origin+stride,dest,stride):
		if b[i]!=null: count+=1
	return count

static func reaches(b: Array, origin: int, dest: int) -> bool:
	if origin==dest: return false
	var p: Dictionary = b[origin]
	var side := int(p.side)
	if b[dest]!=null and b[dest].side==side: return false
	var x := origin%9
	var y := floori(float(origin)/9)
	var xx := dest%9
	var yy := floori(float(dest)/9)
	var dx := xx-x
	var dy := yy-y
	match p.type:
		"r","c":
			if dx and dy: return false
			var screens := between(b,origin,dest)
			return screens==(1 if p.type=="c" and b[dest]!=null else 0)
		"h":
			if absi(dx)*absi(dy)!=2: return false
			return b[origin+(signi(dx) if absi(dx)==2 else 9*signi(dy))]==null
		"e":
			return absi(dx)==2 and absi(dy)==2 and (yy>=5 if side else yy<=4) and b[(origin+dest)>>1]==null
		"a": return absi(dx)==1 and absi(dy)==1 and palace(xx,yy,side)
		"k": return absi(dx)+absi(dy)==1 and palace(xx,yy,side)
		"p": return (dx==0 and dy==(-1 if side else 1)) or (dy==0 and absi(dx)==1 and (y<=4 if side else y>=5))
	return false

static func attacked(b: Array, side: int) -> bool:
	var king := -1
	var foe := -1
	for i in 90:
		if b[i]!=null and b[i].type=="k":
			if b[i].side==side: king=i
			else: foe=i
	if king<0: return true
	if foe>=0 and foe%9==king%9 and between(b,king,foe)==0: return true
	for i in 90:
		if b[i]!=null and b[i].side!=side and reaches(b,i,king): return true
	return false

static func legal(b: Array, side: int, origin: int, dest: int) -> bool:
	if origin<0 or origin>=90 or dest<0 or dest>=90 or b[origin]==null or b[origin].side!=side or not reaches(b,origin,dest): return false
	var capture = b[dest]
	b[dest]=b[origin]
	b[origin]=null
	var ok := not attacked(b,side)
	b[origin]=b[dest]
	b[dest]=capture
	return ok

static func can_move(b: Array, side: int) -> bool:
	for i in 90:
		if b[i]==null or b[i].side!=side: continue
		for j in 90:
			if legal(b,side,i,j): return true
	return false

static func key_of(board: Array, turn: int) -> String:
	var key := ""
	for p in board:
		key += "." if p==null else (str(p.type).to_upper() if p.side else str(p.type))
	return key+str(turn)

static func step(s: Dictionary, a: Dictionary) -> void:
	for field in ["from","to"]:
		var v=a.get(field)
		if not (v is float or v is int) or v!=int(v): return
	var origin := int(a.get("from",-1))
	var dest := int(a.get("to",-1))
	var side := int(s.turn)
	if not legal(s.board,side,origin,dest): return
	var capture = s.board[dest]
	s.board[dest]=s.board[origin]
	s.board[origin]=null
	s.last={"from":origin,"to":dest,"capture":capture.type if capture!=null else null,"side":side}
	s.halfmoves=0 if capture!=null else int(s.halfmoves)+1
	s.moves+=1
	s.score=s.moves
	s.turn=1-side
	if capture!=null: s.seen={}
	s.inCheck=attacked(s.board,s.turn)
	s.checkRun[side]=int(s.checkRun[side])+1 if s.inCheck else 0
	if not can_move(s.board,s.turn):
		s.status="won"
		s.winner=s.sides[side]
		s.reason="将死" if s.inCheck else "对方无棋可走"
		return
	var key := key_of(s.board,int(s.turn))
	var attacker: bool = s.board.any(func(p): return p!=null and p.type in ["r","c","h","p"])
	s.seen[key]=int(s.seen.get(key,0))+1
	if s.seen[key]>=3:
		if s.checkRun[side]>=4 and s.checkRun[int(s.turn)]<4:
			s.status="won"
			s.winner=s.sides[int(s.turn)]
			s.reason="对方长将判负"
			return
		s.reason="三次重复局面"
	elif not attacker: s.reason="双方都没有进攻的子了"
	elif s.halfmoves>=120: s.reason="很久没有吃子"
	elif s.moves>=240: s.reason="下得太久，判和"
	else: return
	s.status="draw"
	s.winner=null
