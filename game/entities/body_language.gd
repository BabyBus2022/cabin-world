class_name BodyLanguage
extends RefCounted
## Visual intent only; no arrival, task, economy or chat side effects.
static var _config:Dictionary={}
static var _textures:Dictionary={}
static var _seen:Dictionary={}
static var _pairs:Array=[]
var seed_value:int=1
var still_for:float=0
var next_idle:float=6
var idle_kind:String=""
var idle_at:float=-1
var pose:String=""
var transition:String=""
var transition_at:float=-1
var facing:int=0
var previous_facing:int=0
var turn_at:float=-1
var direction8:int=0
var was_busy:bool=false

static func config()->Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://assets/actors/body-language.json"))
	return _config

func initialize(resident:String)->void:
	seed_value=1
	for byte in resident.to_utf8_buffer():seed_value=(seed_value*31+int(byte))%2147483647
	next_idle=float(config().idleAfter)+random_unit()*4

func random_unit()->float:
	seed_value=(seed_value*48271)%2147483647
	return float(seed_value)/2147483647.0

static func mood(icon:String,word:String)->String:
	for id in ["tired","sad","happy"]:
		var rule:Dictionary=config().moods[id]
		if icon in rule.icons or word in rule.words:return id
	return ""

static func speed(icon:String,word:String)->float:
	return float(config().moods.get(mood(icon,word),{}).get("speed",1.0))

static func octant(vector:Vector2)->int:
	return posmod(roundi((vector.angle()-PI/2)/(PI/4)),8)

static func cardinal_between(from:int,to:int)->int:
	if [from,to] in [[0,3],[3,0]]:return 2
	if [from,to] in [[1,2],[2,1]]:return 0
	return to

func moving(vector:Vector2,now:float)->void:
	if vector.length_squared()<0.000001:return
	direction8=octant(vector)
	var next:int=(3 if vector.y<0 else 0) if absf(vector.y)>absf(vector.x) else (1 if vector.x<0 else 2)
	if next!=facing:previous_facing=facing;facing=next;turn_at=now

func tick(delta:float,now:float,posture:String,busy:bool,mood_kind:String,has_phone:bool)->void:
	if posture!=pose:
		transition=transition_for(pose,posture)
		transition_at=now if transition!="" else -1
		pose=posture
	if busy or posture!="standing":
		still_for=0;idle_kind=""
		if not was_busy:next_idle=float(config().idleAfter)+random_unit()*4
		was_busy=true
		return
	was_busy=false
	still_for+=delta
	if idle_kind!="" and now-idle_at>=duration(idle_kind):idle_kind=""
	if still_for>=next_idle and idle_kind=="":
		var choices:Array=["idle_look","idle_stretch"]
		if mood_kind=="tired":choices.append("idle_yawn")
		if has_phone:choices.append("idle_phone")
		idle_kind=choices[mini(choices.size()-1,int(random_unit()*choices.size()))];idle_at=now
		next_idle=still_for+9+random_unit()*11

static func transition_for(old:String,next:String)->String:
	if old=="":return ""
	if old=="lying" and next!="lying":return "get_up"
	if next=="lying":return "lie_down"
	if next=="seated" and old!="seated":return "sit_down"
	if old=="seated" and next!="seated":return "stand_up"
	if next=="pick":return "pick_up"
	return ""

static func duration(id:String)->float:
	var spec:Dictionary=config().sheets.get(id,{})
	return int(spec.get("frames",0))*float(spec.get("seconds",0))+float(spec.get("holdSeconds",0))

static func sample(art:String,id:String,row:int,elapsed:float,scale_of:float)->Dictionary:
	var spec:Dictionary=config().sheets.get(id,{})
	if spec.is_empty() or art=="" or elapsed<0:return {}
	var file:="res://assets/actors/motion/%s/%s.png"%[art,id]
	# Missing art never loads a texture, and is not cached as missing: a later import is picked up.
	if not ResourceLoader.exists(file):return {}
	if not _textures.has(file):
		var texture=load(file)
		if not texture is Texture2D or texture.get_size()!=Vector2(int(spec.frames)*314,int(spec.rows)*314):return {}
		_textures[file]=texture
	var length:=duration(id)
	if not spec.loop and elapsed>=length:return {}
	var time:float=fmod(elapsed,length) if spec.loop else elapsed
	var hold_start:float=(int(spec.get("holdFrame",0))+1)*float(spec.seconds)
	if spec.has("holdFrame") and time>hold_start:time=maxf(hold_start-.00001,time-float(spec.holdSeconds))
	var frame:=mini(int(spec.frames)-1,int(time/float(spec.seconds)))
	# The actual accessory is already in her hand. Use only the scroll frames;
	# decorative idling must not imply that an item was picked up or pocketed.
	if id=="idle_phone":frame=[3,4,5,4][frame%4]
	var direction:=clampi(row,0,int(spec.rows)-1)
	return {"id":id,"texture":_textures[file],"region":Rect2(frame*314,direction*314,314,314),"anchor":Vector2(157,290),"scale":scale_of}

static func note_history(history:Array,now_ms:float)->void:
	_pairs=_pairs.filter(func(p):return now_ms-float(p.at)<float(config().highFiveWindow)*1000)
	for record in history:
		if not record is Dictionary:continue
		var id:=str(record.get("matchId",""));var players=record.get("players",[])
		if id=="" or _seen.has(id):continue
		_seen[id]=true
		if players.size()!=2 or now_ms-float(record.get("at",0))>float(config().highFiveWindow)*1000 or float(record.get("at",0))>now_ms:continue
		if not players.all(func(p):return p is Dictionary and str(p.get("result","")) in ["won","lost","draw"]):continue
		var ids:Array=players.map(func(p):return str(p.get("id","")))
		if ids[0]=="" or ids[1]=="" or ids[0]==ids[1]:continue
		_pairs.append({"id":id,"ids":ids,"at":record.at,"start":-1.0})
	if _seen.size()>256:
		var keys:=_seen.keys()
		for i in keys.size()-128:_seen.erase(keys[i])

static func celebration(actor:String,peer:String,distance:float,now_ms:float,eligible:bool)->float:
	if not eligible or distance>float(config().highFiveDistance):return -1
	for pair in _pairs:
		if actor in pair.ids and peer in pair.ids and actor!=peer and now_ms-float(pair.at)<=float(config().highFiveWindow)*1000:
			if float(pair.start)<0:pair.start=now_ms
			var elapsed:float=(now_ms-float(pair.start))/1000.0
			return elapsed if elapsed<float(config().highFiveSeconds) else -1.0
	return -1
