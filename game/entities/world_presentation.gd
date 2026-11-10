class_name WorldPresentation
extends RefCounted
## Port of world-art.mjs/worldPresentation. Both residents use the same transforms.
static var data: Dictionary = {}

static func facts() -> Dictionary:
	if data.is_empty(): data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/visual-world.json"))
	return data

static func point(value: Dictionary) -> Vector2:
	return Vector2(value.x,value.y)

static func phase(time: float) -> float:
	return sin(time*2.4)*.19

static func mechanism_seat(m: Dictionary, kind: String, time: float, slot := "left") -> Vector2:
	var base := point(m)
	match kind:
		"swing":
			var a := phase(time)
			return base+Vector2(m.w/2+sin(a)*(m.h-18),9+cos(a)*(m.h-18))
		"seesaw":
			var a := phase(time)*.7
			return base+Vector2(m.w/2,m.h-14*.625)+Vector2((65 if slot=="right" else -65)*.625,-12*.625).rotated(a)
		"rider": return base+Vector2(m.w*.48,m.h*.38+sin(time*4)*2)
		"carousel": return base+Vector2(m.w/2+cos(time*1.2)*m.w*.22,m.h*.48+sin(time*1.2)*m.h*.1)
	return base+Vector2(m.w/2,m.h*.7)

static func eased(value: float) -> float:
	var p := clampf(value,0,1)
	return p*p*(3-2*p)

static func bed(scene: String,state: Dictionary) -> Dictionary:
	var module := {}
	for m in facts().scenes.get(scene,{}).get("modules",{}).values():
		if m.get("kind")=="bed":module=m;break
	if module.is_empty():return {}
	var base := point(module)
	var approach := base+point(module.anchors.approach)
	var edge := base+point(module.anchors.edge)
	var lying := base+point(module.anchors.lying)
	var phase := str(state.get("phase",""))
	var p := float(state.get("progress",0))
	match phase:
		"edge":return {"pose":"edge","feet":approach.lerp(edge,p) if state.get("plan",{}).get("steps",[]).any(func(s):return s[0]=="approaching") else edge}
		"leaving":return {"pose":"stand","feet":edge.lerp(approach,p)}
		"climbing":return {"pose":"climbing","feet":edge.lerp(lying,p)}
		"sitting_up":return {"pose":"waking","feet":lying.lerp(edge,p)}
		"reclining":return {"pose":"climbing" if p<.45 else "lying","feet":lying}
	return {"pose":"sleeping" if phase=="sleeping" or (phase=="waking" and p<.5) else "lying","feet":lying}

static func moment(scene: String, zone: String, effect: Dictionary, sec: float, time: float) -> Dictionary:
	var room: Dictionary = facts().scenes.get(scene,{})
	if not room.get("background",false) or not room.get("zones",{}).has(zone): return {}
	var z := point(room.zones[zone])
	var kind := str(effect.get("kind","")) if sec<float(effect.get("seconds",6)) else ""
	var m: Dictionary = room.modules.get(str(effect.get("module","")),{})
	if kind=="swim":
		var water: Dictionary = facts().water
		var a := sec*.16+fmod(float(effect.get("at",0)),628)/100
		var c := Vector2(water.x+cos(a)*water.rx,water.y+sin(a)*water.ry)
		return {"feet":z.lerp(c,eased(sec/2.5)),"robe_row":4,"water":true,"flip":-sin(a)<0,"snap":true}
	if kind=="soak" and facts().soak.has(zone):
		return {"feet":z.lerp(point(facts().soak[zone]),eased(sec/1.6)),"robe_row":5,"water":true,"snap":true}
	if kind=="shower": return {"feet":z,"hidden":true}
	if kind=="bench" and zone.begins_with("bench_"):
		var b: Dictionary = room.modules.get("long-bench",{})
		if not b.is_empty():
			return {"feet":z.lerp(Vector2(b.x+b.w*.5,z.y+6),eased(sec/1.2)),"row":1,"seat":true,"still":true,"sort":b.depth+.05,"snap":true}
	var seat = null
	var row := 0
	var flip := false
	var above := ""
	if not m.is_empty() and kind in ["swing","seesaw","rider","carousel"]:
		seat = mechanism_seat(m,kind,time,str(effect.get("slot","left")))
		row = 0 if kind=="swing" else 1
		flip = kind=="seesaw" and effect.get("slot")!="right"
		above = m.id
	elif kind=="fishing" and not m.is_empty():
		seat = Vector2(m.x+m.w-18,m.y+m.h*.62)
		row = 1
		flip = true
	elif zone=="bench" and not m.is_empty():
		seat = Vector2(m.x+m.w/2,m.y+m.h*.69)
		above = m.id
	elif kind=="slide" and not m.is_empty():
		var top := point(m)+point(m.anchors.top)
		var bottom := point(m)+point(m.anchors.bottom)
		var t := fmod(sec,6)
		seat = z.lerp(top,t/2) if t<2 else top.lerp(bottom,clampf((t-2)/2,0,1)) if t<4 else bottom.lerp(z,(t-4)/2)
		row = 1
		flip = true
		above = m.id
	if seat is Vector2:
		var feet := z.lerp(seat,eased(sec/1.2))
		return {"feet":feet,"row":row,"seat":true,"flip":flip,"sort":float(room.modules[above].depth)+.05 if above!="" else feet.y,"snap":true}
	if kind=="chess": return {"feet":z,"dir":{"chess_home_a":0,"chess_home_b":3,"chess_xj_a":2,"chess_xj_b":1}.get(zone,0),"animated":true}
	if scene=="world-arcade" and kind=="typing":
		var left := zone=="arcade_xiangqi_far"
		var right := zone=="arcade_xiangqi_near"
		var stool: Dictionary = room.modules.get("chess-far-seat" if left else "chess-near-seat",{}) if left or right else {}
		if not stool.is_empty(): return {"feet":z.lerp(Vector2(stool.x+stool.w/2,stool.y+stool.h*.22),eased(sec/.8)),"sort":stool.depth+.05,"row":1,"seat":true,"flip":left,"still":true,"snap":true}
		return {"feet":z,"dir":3,"still":true}
	# Idle placement remains the physical body position, including crowd clearance.
	if kind in ["pick","coins"]: return {"row":2 if kind=="pick" else 3}
	return {}
