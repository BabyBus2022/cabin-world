extends RefCounted
## Freestyle 15×15: black first, five or more connected stones wins. Local
## controller uses visible stones only; a move never needs a language-model call.
const SIZE:=15
const AXES:=[Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(1,-1)]
static func create(players:Array)->Dictionary:
	var sides:=players.duplicate()
	if sides.size()==1:sides.append("computer")
	var board:=[];board.resize(SIZE*SIZE);board.fill(-1)
	return {"w":SIZE,"h":SIZE,"board":board,"turn":0,"sides":sides,"moves":0,"last":null}
static func inside(x:int,y:int)->bool:return x>=0 and y>=0 and x<SIZE and y<SIZE
static func run_at(board:Array,k:int,side:int,axis:Vector2i)->Array:
	var count:=1;var open:=0
	for sign in [-1,1]:
		var x:int=k%SIZE+axis.x*sign;var y:int=k/SIZE+axis.y*sign
		while inside(x,y) and board[y*SIZE+x]==side:
			count+=1;x+=axis.x*sign;y+=axis.y*sign
		if inside(x,y) and board[y*SIZE+x]==-1:open+=1
	return [count,open]
static func step(s:Dictionary,a:Dictionary)->void:
	var value=a.get("at",-1)
	if not (value is int or value is float) or not is_finite(value) or value!=floorf(value):return
	var k:=int(value)
	if k<0 or k>=SIZE*SIZE or s.board[k]!=-1:return
	if a.has("player") and a.player!=s.sides[int(s.turn)]:return
	s.board[k]=int(s.turn);s.last=k;s.moves+=1
	for axis in AXES:
		if run_at(s.board,k,int(s.turn),axis)[0]>=5:
			s.status="won";s.winner=s.sides[int(s.turn)];s.reason="五子连珠";return
	if s.moves>=SIZE*SIZE:s.status="draw";s.winner=null;s.reason="棋盘已满，平局";return
	s.turn=1-int(s.turn)
static func score(board:Array,k:int,side:int)->float:
	var result:=0.0
	for axis in AXES:
		var line:=run_at(board,k,side,axis);var n:int=line[0];var ends:int=line[1]
		if n>=5:return 10000000.0
		if ends==0:continue
		result+=([0,2,30,600,25000][mini(n,4)] as float)*(3.0 if ends==2 else 1.0)
	return result
## The move for the side to play, at THAT side's skill (s.skill: the resident's from talent and mood, computer 0.68),
## with the board's seeded randomness (arcade_board.random_value), like 象棋. Fix 2026-11-12: before, both sides used
## one perfect deterministic defender, so every game was the same game and ended "棋盘已满，平局" (owner report).
## A winning move is always taken. Skill decides how often a move overlooks the opponent's threats (it then plays
## its own attack, as people do): (1 - skill) of moves, and a must-block is missed (1 - skill) * 0.35 of the
## time. Ordinary moves also get skill-scaled variety. So games end in wins and losses, and the stronger side wins more.
static func suggest(s:Dictionary)->Dictionary:
	var Board = load("res://core/arcade_board.gd")
	var id:String=str(s.sides[int(s.turn)]);var level:float=float(s.get("skill",{}).get(id,0.68 if id=="computer" else 0.7))
	if int(s.moves)==0:return {"at":112 if Board.random_value(s)<.6 else [96,97,98,111,113,126,127,128][int(Board.random_value(s)*8)%8]}
	var noise:=(1.0-level)*0.9;var miss_block:bool=Board.random_value(s)<(1.0-level)*0.35
	var guard:float=0.15 if Board.random_value(s)<(1.0-level)*1.0 else 0.78 ## how much this move minds the opponent's lines
	var best:=-INF;var pick:=-1
	for k in SIZE*SIZE:
		if s.board[k]!=-1:continue
		var nearby:=false
		for dy in range(-2,3):
			for dx in range(-2,3):
				var x:int=k%SIZE+dx;var y:int=k/SIZE+dy
				if inside(x,y) and s.board[y*SIZE+x]!=-1:nearby=true
		if not nearby:continue
		var attack:=score(s.board,k,int(s.turn));var defense:=score(s.board,k,1-int(s.turn))
		var value:float=(attack+defense*guard)*(1.0+(Board.random_value(s)-.5)*noise)-Vector2(k%SIZE-7,k/SIZE-7).length()*.1
		if attack>=10000000:value=20000000
		elif defense>=10000000 and not miss_block:value=10000000
		if value>best:best=value;pick=k
	return {"at":pick}
