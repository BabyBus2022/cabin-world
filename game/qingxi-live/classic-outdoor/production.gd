extends RefCounted
const Plan=preload("res://qingxi-live/classic-outdoor/layout.gd")
const Model=preload("res://qingxi-live/animal_model.gd")
var h
var crop_nodes=[]
var animals={}
var rng=RandomNumberGenerator.new()
var pond
var phase=0.0
func _init(host):h=host;rng.seed=1182
func ball(parent:Node3D,p:Vector3,size_:Vector3,color:Color)->MeshInstance3D:
 var mesh=SphereMesh.new();mesh.radial_segments=8;mesh.rings=4;mesh.radius=.5;mesh.height=1
 var n=MeshInstance3D.new();n.mesh=mesh;n.position=p;n.scale=size_;n.material_override=h.material(color);parent.add_child(n);return n
func build():
 # Connected soft-edged beds; individual crop slots remain exact and selectable.
 for i in 12:
  var p=Vector3(-63+(i%4)*2.15,.015,8+(i/4)*2.15)
  var soil=ball(h,p+Vector3(0,-.16,0),Vector3(2.5,.4,2.5),Color("997a53"))
  var root=Node3D.new();root.position=p;h.add_child(root);crop_nodes.append({"root":root,"soil":soil,"signature":""})
  h.targets.append({"kind":"crop","id":i,"name":"田块 %d"%(i+1),"at":p,"range":1.7})
 h.sign_at("青芽田地 · C 切换种子",Vector3(-59,1.8,5))
 h.targets.append({"kind":"pond","name":"投放 / 喂鱼 / 捕捞","at":Vector3(28,.05,-32),"range":3.0})
 pond=preload("res://qingxi-live/classic-outdoor/restored_pond.gd").new();pond.build(h)
 for kind in Plan.PENS:
  var r:Rect2=Plan.PENS[kind];var a=Vector3(r.position.x,0,r.position.y);var b=Vector3(r.end.x,0,r.end.y);var mid=(a.x+b.x)/2
  h.landscape.fence(a,Vector3(b.x,0,a.z));h.landscape.fence(a,Vector3(a.x,0,b.z));h.landscape.fence(Vector3(b.x,0,a.z),b)
  h.landscape.fence(Vector3(a.x,0,b.z),Vector3(mid-1.1,0,b.z));h.landscape.fence(Vector3(mid+1.1,0,b.z),b)
  var feed=Vector3(a.x+1,.35,b.z-1.1);var water_=Vector3(b.x-1,.35,b.z-1.1)
  h.box(h,feed,Vector3(1.2,.7,.7),Color("a78960"),true);h.box(h,feed+Vector3(0,.36,0),Vector3(1,.03,.5),Color("b4bc79"))
  h.box(h,water_,Vector3(1.2,.7,.7),Color("a78960"),true);h.box(h,water_+Vector3(0,.36,0),Vector3(1,.03,.5),Color("78a5a1"))
  var point=Vector3(mid,.05,b.z+1.0);h.sign_at(h.sim.NAMES[kind]+"圈",point+Vector3(0,1.8,0))
  h.targets.append({"kind":"pen","id":kind,"name":h.sim.NAMES[kind]+"圈照料","at":point,"range":2.5})
 refresh()
func refresh():
 for i in crop_nodes.size():
  var c=h.sim.data.crops[i];var spec=h.sim.CROPS.get(c.get("kind","cabbage"),h.sim.CROPS.cabbage)
  var level_=0 if not c.planted else (3 if c.progress>=spec.seconds else (2 if c.progress>spec.seconds*.4 else 1))
  var signature=str(c.get("kind","cabbage"))+str(level_)+str(c.water>0)
  if crop_nodes[i].signature==signature:continue
  crop_nodes[i].signature=signature
  var root=crop_nodes[i].root
  for child in root.get_children():root.remove_child(child);child.queue_free()
  crop_nodes[i].soil.material_override=h.material(Color("816647") if c.water>0 else Color("997a53"))
  if level_==0:continue
  var scale_=float(level_)/3.0
  if c.get("kind","cabbage")=="wheat":
   for n in 5:
    var p=Vector3(sin(n*2)*.4,.5*scale_,cos(n*2)*.4)
    h.box(root,p,Vector3(.05,1*scale_,.05),Color("9ca66b"))
    ball(root,p+Vector3(0,.5*scale_,0),Vector3(.17,.4,.17)*scale_,Color("d4bd75"))
  else:
   for n in 5:
    var a=n*TAU/5;var p=Vector3(cos(a)*.22*scale_,.25*scale_,sin(a)*.22*scale_)
    var leaf=ball(root,p,Vector3(.65,.6,.4)*scale_,Color("a9bd7a") if n%2 else Color("7eaa72"));leaf.rotation.y=-a
   if c.get("kind","")=="carrot":ball(root,Vector3(0,.1,0),Vector3(.32,.25,.32)*scale_,Color("c89c66"))
 refresh_animals()
func refresh_animals():
 var ids=[]
 for a in h.sim.livestock.data.herd:
  ids.append(a.id)
  if animals.has(a.id):continue
  var rect:Rect2=Plan.PENS[a.kind].grow(-1.4)
  var p=Vector2(rect.position.x+rng.randf()*rect.size.x,rect.position.y+rng.randf()*rect.size.y)
  if a.has("v01pos"):p=Vector2(a.v01pos[0],a.v01pos[1]).clamp(rect.position,rect.end)
  var body=CharacterBody3D.new();body.position=Vector3(p.x,.1,p.y);body.collision_layer=4;body.collision_mask=1;body.floor_snap_length=.3;h.add_child(body)
  var shape=CapsuleShape3D.new();shape.radius=.34;shape.height=1.0;var c=CollisionShape3D.new();c.shape=shape;c.position.y=.5;body.add_child(c)
  var model=Model.new(body,a.kind);model.rig.reparent(body,false);model.viewport.queue_free()
  var tag=h.sign_at("",Vector3(0,2,0),body);tag.font_size=24
  animals[a.id]={"body":body,"model":model,"tag":tag,"goal":p,"pause":rng.randf(),"phase":rng.randf()*6,"travel":0.0,"mode":"闲逛"}
 for id in animals.keys():
  if id not in ids:animals[id].body.queue_free();animals.erase(id)
func tick(dt:float):
 phase+=dt
 pond.tick(dt)
 for a in h.sim.livestock.data.herd:
  if not animals.has(a.id):continue
  var actor=animals[a.id];var body:CharacterBody3D=actor.body;var rect:Rect2=Plan.PENS[a.kind].grow(-1.1)
  var point=Vector2(body.position.x,body.position.z);var direction=Vector2.ZERO
  actor.pause-=dt
  var desired_food="carrot" if a.kind=="pig" else "wheat"
  if h.held_food==desired_food and h.sim.data.bag.get(desired_food,0)>0 and body.position.distance_to(h.player.position)<7:
   actor.goal=Vector2(h.player.position.x,h.player.position.z).clamp(rect.position,rect.end);actor.pause=0
  if a.love>0:
   for other in h.sim.livestock.members(a.kind):
    if other.id!=a.id and other.love>0 and animals.has(other.id):actor.goal=Vector2(animals[other.id].body.position.x,animals[other.id].body.position.z);actor.pause=0;break
  if actor.pause<=0:
   if point.distance_to(actor.goal)<.22:
    actor.goal=rect.position+Vector2(rng.randf()*rect.size.x,rng.randf()*rect.size.y);actor.pause=rng.randf_range(1.5,4);actor.mode="拱地" if a.kind=="pig" else "吃草"
   else:direction=(actor.goal-point).normalized();actor.mode="闲逛"
  var before=body.position;body.velocity=Vector3(direction.x*.65,body.velocity.y-18*dt,direction.y*.65);body.move_and_slide()
  body.position.x=clampf(body.position.x,rect.position.x,rect.end.x);body.position.z=clampf(body.position.z,rect.position.y,rect.end.y)
  actor.travel+=body.position.distance_to(before)
  actor.model.animate(dt,direction.length()>0,actor.mode,bool(a.shorn),Vector2.ZERO)
  if direction.length()>0:actor.model.rig.rotation.y=lerp_angle(actor.model.rig.rotation.y,atan2(direction.y,-direction.x),dt*5)
  actor.model.rig.scale=Vector3.ONE*(.78 if h.sim.livestock.adult(a) else .53)
  actor.tag.text=("♥ " if a.love>0 else "")+h.sim.NAMES[a.kind]+" · "+actor.mode;actor.tag.visible=body.position.distance_to(h.player.position)<4.5
  a.v01pos=[body.position.x,body.position.z];a.pos=[body.position.x*12,body.position.z*12]
 var born=h.sim.livestock.breed()
 if not born.is_empty():refresh_animals();h.say("牧场迎来了新生幼崽")

