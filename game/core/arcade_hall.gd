extends RefCounted
## The active match clock is in memory. A host restart interrupts the match;
## results survive in ArcadeRecords. A game reconnect imports the live mirror.
const NAMES := {"snake":"贪吃蛇","blocks":"俄罗斯方块","mines":"扫雷","xiangqi":"象棋"}
const INTERVAL := {"snake":0.260,"blocks":0.220,"mines":0.650,"xiangqi":1.4}
const LIMIT := {"snake":240000,"blocks":300000,"mines":180000,"xiangqi":600000}
const SEATS := {"xiangqi":["arcade_xiangqi_far","arcade_xiangqi_near"],"snake":["arcade_snake_left","arcade_snake_right"]}
var sessions := {}

static func profiles() -> Dictionary:
	var rows := {}
	for resident in Residents.people():
		if resident.has("arcade"): rows[resident.key]=resident.arcade
	return rows

static func seat(a: Dictionary) -> Dictionary:
	var kind: String=a.key.split("@")[0]
	if not NAMES.has(kind): return {"error":"没有这个游戏："+kind}
	if "@" in a.key and a.mode=="solo": return {"error":"家里的棋盘要两个人才能下"}
	if a.mine!="": return {"error":"已经在玩%s了"%NAMES[a.mine]}
	var duo := kind in ["snake","xiangqi"]
	var names := []
	var taken := []
	for m in a.members:
		names.append(m.name)
		taken.append(int(m.seat))
	if a.status in ["waiting","playing"]:
		if a.status!="waiting" or not duo or names.size()>=2 or a.mode in ["solo","alone"]:
			return {"error":"%s机台%s正在用，等一等或者玩别的"%[NAMES[kind],"、".join(names)]}
	elif a.mode=="invited": return {"error":"对方已经开局了"}
	var index := maxi(0,a.residents.find(a.actor))%2 if duo else 0
	if index in taken: index=1-index
	var zones: Array=SEATS.get(a.key,["arcade_"+kind])
	if "@" in a.key:
		for profile in profiles().values():
			if profile.get("board")==a.key:
				zones=profile.seats
				break
	return {"seat":index,"zone":zones[index] if index<zones.size() else zones[0],
		"invite":duo and names.is_empty() and not a.mode in ["solo","invited","alone"]}

func watch(f: Dictionary) -> void:
	if not INTERVAL.has(f.kind): return
	var current: Dictionary=sessions.get(f.key,{})
	if current.get("id")==f.matchId and current.get("phase")==f.status: return
	if f.status in ["waiting","playing"]:
		var interval: float=INTERVAL[f.kind] if f.status=="playing" else .4
		sessions[f.key]={"id":f.matchId,"phase":f.status,"interval":interval,"left":interval,
			"board":f.get("board"),"startedAt":f.get("startedAt",0)}
	elif current.get("id")==f.matchId: sessions.erase(f.key)

func match_for(args: Dictionary) -> Dictionary:
	var row: Dictionary=sessions.get(args.get("key",""),{})
	return row if row.get("id","") == args.get("matchId") and row.get("phase")=="playing" else {}

func advance(dt: float) -> void:
	for key in sessions:
		var s: Dictionary=sessions[key]
		s.left-=dt
		if s.left<=0:
			s.left=s.interval
			VadsLink.send({"type":"arcade.pulse","key":key,"matchId":s.id,"status":s.phase})
