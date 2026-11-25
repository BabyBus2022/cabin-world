extends RefCounted
const ART="res://assets/pet-furniture/wicker-bed.png"
static var bed_texture:Texture2D

static func texture()->Texture2D:
	if bed_texture==null:bed_texture=ImageTexture.create_from_image(Image.load_from_file(ART))
	return bed_texture

# Keep a stable place behind a moving owner. At rest take an occasional short sniffing walk.
static func follow_target(row:Dictionary,feet:Vector2,pet:Dictionary,dt:float)->Vector2:
	var id=absi(hash(str(pet.id)))
	if not row.has("leader_at"):
		row.leader_at=feet;row.waited=0.;row.stride=Vector2.DOWN;row.sniff=-1
	var delta:Vector2=feet-row.leader_at
	if delta.length()>2.5:
		row.stride=delta.normalized();row.leader_at=feet;row.waited=0.;row.sniff=-1
	else:row.waited+=dt
	var side=1. if id%2==0 else -1.
	var gap=(28. if pet.kind=="dog" else 23.)+(id%7)
	var aim=feet-row.stride*gap+Vector2(row.stride).orthogonal()*side*(10.+id%9)
	if row.waited>1.5:
		var hop=floori((row.waited-1.5)/(3.4+float(id%7)*.20))
		var angle=TAU*float(absi(hash(Vector2i(id%10007,hop)))%1024)/1024.
		aim=feet+Vector2(cos(angle)*1.15,sin(angle)*.8)*(gap+7.)
		row.sniff=hop
	return aim

static func choose_bed(beds:Dictionary,claimed:Dictionary,row:Dictionary,feet:Vector2,pos:Vector2,reach:=210.0)->Vector2:
	if row.waited<6.:return Vector2.INF
	var near=Vector2.INF
	var key=""
	for id in beds:
		var p:Vector2=beds[id]
		if claimed.has(id) or feet.distance_to(p)>reach:continue
		if pos.distance_squared_to(p)<pos.distance_squared_to(near):near=p;key=id
	if key!="":claimed[key]=true
	return near
