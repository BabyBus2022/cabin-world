extends RefCounted
const AnimalModel=preload("res://qingxi-live/animal_model.gd")
const Herd=preload("res://qingxi-live/livestock.gd")
var world
var rows:Array=[]
var actors={}
var rng=RandomNumberGenerator.new()
var clock=0.0
func _init(host):
	world=host;rng.seed=90871
func reset():
	actors.clear()
func movement_rect(kind:String)->Rect2:
	var p:Rect2=Herd.pen(kind)
	return Rect2(p.position+Vector2(42,40),p.size-Vector2(84,62))
func clamp_point(p:Vector2,kind:String)->Vector2:
	var r=movement_rect(kind)
	return p.clamp(r.position,r.end-Vector2.ONE)
func random_goal(kind:String)->Vector2:
	var r=movement_rect(kind)
	return Vector2(rng.randf_range(r.position.x,r.end.x),rng.randf_range(r.position.y,r.end.y))
func garden_model(node:Node2D,a:Dictionary):
	return preload("res://qingxi-live/village-center/garden_animal.gd").new(node,a.kind)
func refresh():
	var current_ids=[]
	for a in world.sim.livestock.data.herd:
		current_ids.append(a.id)
		if actors.has(a.id):continue
		var node=Node2D.new();node.position=clamp_point(Vector2(a.pos[0],a.pos[1]),a.kind);world.scenery.add_child(node)
		var shadow=Polygon2D.new();var points=PackedVector2Array()
		for i in 12:points.append(Vector2(cos(i*TAU/12)*13,sin(i*TAU/12)*4))
		shadow.polygon=points;shadow.color=Color(0.15,0.21,0.18,0.18);node.add_child(shadow)
		var sprite=Sprite2D.new();sprite.centered=false;sprite.material=ShaderMaterial.new();sprite.material.shader=load("res://qingxi-live/animal_pixel.gdshader");world.surfaces.append(sprite.material);node.add_child(sprite)
		var garden_art=world.has_method("ground_data") and world.herd_ai.has_method("on_ranch")
		var model=garden_model(node,a) if garden_art else AnimalModel.new(node,a.kind)
		if garden_art:
			sprite.material.shader=preload("res://qingxi-live/village-center/garden_animal.gdshader")
			sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		var tag=world.world_label("",Vector2.ZERO);tag.reparent(node);tag.position=Vector2(-64,-60)
		actors[a.id]={"node":node,"model":model,"sprite":sprite,"shadow":shadow,"tag":tag,"goal":random_goal(a.kind),"wait":rng.randf_range(0,2),"mode":"闲逛","phase":rng.randf()*4,"moving":false}
		world.targets.append({"kind":"animal","pos":node.position,"name":str(Herd.NAMES.get(a.kind,"鸡"))+" #"+a.id,"extra":a.id})
	for id in actors.keys():
		if not current_ids.has(id):
			world.surfaces.erase(actors[id].sprite.material)
			actors[id].node.queue_free();actors.erase(id)
			world.targets=world.targets.filter(func(t):return not (t.kind=="animal" and t.extra==id))
	update_sprites()
func update_sprites():
	for a in world.sim.livestock.data.herd:
		if not actors.has(a.id):continue
		var actor:Dictionary=actors[a.id]
		var adult=world.sim.livestock.adult(a)
		var texture:Texture2D=actor.model.texture()
		var width_=float({"cow":110,"sheep":99,"pig":100,"chicken":54}[a.kind])*(1.0 if adult else 0.62)
		var factor=width_/112.0
		actor.sprite.texture=texture;actor.sprite.scale=Vector2.ONE*factor
		actor.sprite.position=Vector2(-texture.get_width()*factor/2,-actor.model.foot_baseline*factor)
		actor.shadow.scale=Vector2.ONE*(1.0 if adult else 0.65)
		actor.tag.position.y=-texture.get_height()*factor-20
		actor.tag.text=("♥ " if a.love>0 else "")+str(Herd.NAMES.get(a.kind,"鸡"))+" #"+str(a.id)+" · "+str(actor.mode)
		actor.tag.visible=actor.node.position.distance_to(world.player.position)<145
		for target in world.targets:
			if target.kind=="animal" and target.extra==a.id:target.pos=actor.node.position
func tick(dt:float):
	clock+=dt
	for a in world.sim.livestock.data.herd:
		if not actors.has(a.id):continue
		var actor:Dictionary=actors[a.id];var node:Node2D=actor.node;var kind=str(a.kind)
		actor.model.animate(dt,actor.moving,str(actor.mode),bool(a.get("shorn",false)),actor.get("heading",Vector2.LEFT))
		var following=world.held_food==Herd.TREAT[kind] and world.sim.data.bag[world.held_food]>0 and node.position.distance_to(world.player.position)<165
		var mate={}
		if a.love>0:
			for candidate in world.sim.livestock.members(kind):
				if candidate.id!=a.id and candidate.love>0 and candidate.cooldown<=0:mate=candidate;break
		if following:
			actor.goal=clamp_point(world.player.position,kind);actor.wait=0
			actor.mode="跟随食物"
		elif not mate.is_empty():
			actor.goal=clamp_point(Vector2(mate.pos[0],mate.pos[1]),kind);actor.wait=0;actor.mode="靠近同伴"
		elif actor.wait>0:
			actor.wait-=dt;actor.moving=false;continue
		else:
			actor.mode="闲逛"
		var offset:Vector2=actor.goal-node.position
		var stop_distance=35.0 if following else (15.0 if not mate.is_empty() else 5.0)
		if offset.length()<stop_distance:
			actor.moving=false
			if not following and mate.is_empty():
				actor.wait=rng.randf_range(2.0,6.0)*(1.5 if world.night_level>0.8 else 1.0)
				actor.mode=("吃草" if kind!="pig" else "拱地") if rng.randf()<0.7 else "歇一会儿"
				actor.goal=random_goal(kind)
			continue
		var direction=offset.normalized()
		for other_id in actors:
			if other_id==a.id:continue
			var other:Vector2=actors[other_id].node.position
			var apart=node.position-other
			if apart.length()<30 and apart.length()>0.01:direction+=apart.normalized()*(1.0-apart.length()/30)*1.8
		var speed=float({"cow":20,"sheep":25,"pig":22}[kind])
		var step=direction.normalized()*dt*speed
		var before=node.position
		var next=clamp_point(node.position+Vector2(step.x,0),kind)
		if not world.blocked(next):node.position=next
		next=clamp_point(node.position+Vector2(0,step.y),kind)
		if not world.blocked(next):node.position=next
		actor.moving=node.position.distance_to(before)>0.01
		if actor.moving:
			actor.phase+=dt*7
			actor.heading=step.normalized();actor.sprite.flip_h=false
		elif not following:
			actor.goal=random_goal(kind);actor.wait=0.3
		a.pos=[node.position.x,node.position.y]
	update_sprites()

